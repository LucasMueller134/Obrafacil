import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import 'chave_acesso.dart';
import 'linhas_ocr.dart';
import 'texto_br.dart';

// Quem usa o OCR monta a entrada e lê a chave com estes tipos.
export 'chave_acesso.dart';
export 'linhas_ocr.dart';

/// Dados extraídos de uma nota fiscal / cupom fiscal fotografado.
class NotaFiscalExtraida {
  final String? fornecedorNome;
  final String? cnpj;
  final double? valorTotal;
  final DateTime? data;
  final String textoCompleto;

  /// Quantos passes de imagem foram necessários (1 = leu de primeira).
  /// A tela usa para avisar que a foto estava difícil de ler.
  final int passes;

  /// Chave de acesso (44 dígitos, DV conferido), lida do QR Code, do
  /// código de barras do DANFE ou do texto.
  final String? chaveAcesso;

  /// O texto remontado linha a linha pela posição na foto; null quando o
  /// OCR não informou a geometria. É o que a tela deve usar para tirar os
  /// itens, porque junta o nome do produto ao preço da outra coluna.
  final String? textoReconstruido;

  const NotaFiscalExtraida({
    this.fornecedorNome,
    this.cnpj,
    this.valorTotal,
    this.data,
    required this.textoCompleto,
    this.passes = 1,
    this.chaveAcesso,
    this.textoReconstruido,
  });

  bool get encontrouAlgo =>
      fornecedorNome != null || cnpj != null || valorTotal != null;

  bool get completa => fornecedorNome != null && valorTotal != null;

  /// O CNPJ é o que está na chave de acesso — conferido por dígito
  /// verificador, e não só lido do papel.
  bool get cnpjDaChave {
    final chave = chaveAcesso;
    final c = cnpj;
    if (chave == null || c == null || chave.length != 44) return false;
    return c.replaceAll(RegExp(r'\D'), '') == chave.substring(6, 20);
  }

  /// Combina dois resultados, preferindo os campos do primeiro — exceto
  /// onde a chave de acesso (de qualquer um dos dois) decide: o CNPJ dela
  /// vence o lido no texto, e a data tem de cair no mês dela.
  NotaFiscalExtraida mesclar(NotaFiscalExtraida outra) {
    final digitosChave = chaveAcesso ?? outra.chaveAcesso;
    final chave =
        digitosChave == null ? null : ChaveAcesso.validar(digitosChave);
    final cnpjDaChave = chave != null && OcrNotaService.cnpjValido(chave.cnpj)
        ? OcrNotaService._formatarCnpj(chave.cnpj)
        : null;

    bool valido(String? c) =>
        c != null && OcrNotaService.cnpjValido(c.replaceAll(RegExp(r'\D'), ''));
    // um CNPJ que não fecha o DV nunca vence um que fecha
    final cnpjLido = valido(cnpj)
        ? cnpj
        : (valido(outra.cnpj) ? outra.cnpj : cnpj ?? outra.cnpj);

    bool bate(DateTime? d) => d != null && (chave == null || chave.mesmoMes(d));
    final usarEste = textoCompleto.length >= outra.textoCompleto.length;

    return NotaFiscalExtraida(
      fornecedorNome: fornecedorNome ?? outra.fornecedorNome,
      cnpj: cnpjDaChave ?? cnpjLido,
      valorTotal: valorTotal ?? outra.valorTotal,
      data: bate(data) ? data : (bate(outra.data) ? outra.data : null),
      textoCompleto: usarEste ? textoCompleto : outra.textoCompleto,
      textoReconstruido: usarEste
          ? textoReconstruido ?? outra.textoReconstruido
          : outra.textoReconstruido ?? textoReconstruido,
      chaveAcesso: digitosChave,
      passes: passes + outra.passes,
    );
  }
}

/// Variações da foto tentadas quando a leitura direta não resolve.
enum _Variante {
  /// Cinza + contraste + ampliação: recupera impressão fraca e foto escura.
  realce,

  /// Preto e branco por limiar de Otsu: recupera cupom térmico apagado e
  /// nota amassada, onde o cinza médio confunde o reconhecedor.
  binarizada,

  /// A foto foi tirada com o celular deitado.
  girada90,
  girada270,
}

/// IA on-device nº 2 — OCR de notas fiscais.
///
/// Usa o Google ML Kit Text Recognition e o Barcode Scanning (modelos
/// TensorFlow Lite embarcados, 100% offline) e um parser de heurísticas
/// para notas brasileiras.
///
/// A leitura acontece em cascata: lê a foto original e, enquanto faltar
/// algum campo essencial, tenta de novo com a imagem realçada, binarizada
/// e — se quase nada foi lido — girada. Cada passe só acrescenta o que
/// ainda faltava, então uma foto ruim de um lado e boa do outro ainda
/// produz um resultado completo. O QR Code da NFC-e e o código de barras
/// do DANFE são lidos uma vez, na foto original: deles vem a chave de
/// acesso, que confere CNPJ e data. Manuscrito continua sendo o limite do
/// modelo.
class OcrNotaService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final BarcodeScanner _leitorCodigos = BarcodeScanner(
      formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128]);

  /// Limites por passe. O ML Kit costuma responder em 1–3 s; um passe que
  /// trava (foto enorme, aparelho sem memória) não pode prender a tela.
  static const Duration _limiteReconhecimento = Duration(seconds: 20);
  static const Duration _limiteCodigos = Duration(seconds: 10);
  static const Duration _limiteVariante = Duration(seconds: 20);

  /// Depois disto não começa outro passe: o que já foi lido é devolvido.
  static const Duration _limiteTotal = Duration(seconds: 60);

  Future<NotaFiscalExtraida> lerNota(String caminhoImagem) async {
    final relogio = Stopwatch()..start();
    // O código não depende do texto: lê em paralelo com o OCR.
    final codigosFuturo = _lerCodigos(caminhoImagem);

    List<BlocoOcr>? blocos;
    Object? erro;
    StackTrace? pilha;
    try {
      blocos = await _reconhecer(caminhoImagem);
    } catch (e, s) {
      erro = e;
      pilha = s;
    }
    final codigos = await codigosFuturo;
    // Sem texto, o QR ainda dá chave, CNPJ e — offline — data e valor.
    if (blocos == null && codigos.isEmpty) {
      Error.throwWithStackTrace(erro!, pilha!);
    }

    var resultado =
        interpretar(EntradaOcr(blocos ?? const [], codigos: codigos));
    // Se o reconhecedor falhou na original, falharia nas variantes também.
    if (blocos == null || resultado.completa) return resultado;

    // Texto quase vazio: a foto provavelmente está deitada — girar vem
    // antes de qualquer realce, porque realçar imagem de lado não adianta.
    final variantes = resultado.textoCompleto.trim().length < 25
        ? const [
            _Variante.girada90,
            _Variante.girada270,
            _Variante.realce,
            _Variante.binarizada,
          ]
        : const [_Variante.realce, _Variante.binarizada];

    for (final variante in variantes) {
      if (relogio.elapsed > _limiteTotal) break;
      final caminho = await _gerarVariante(caminhoImagem, variante);
      if (caminho == null) continue;
      try {
        final lidos = await _reconhecer(caminho);
        resultado =
            resultado.mesclar(interpretar(EntradaOcr(lidos, codigos: codigos)));
      } catch (_) {
        // um passe que falha não invalida os anteriores
      } finally {
        try {
          await File(caminho).delete();
        } catch (_) {}
      }
      if (resultado.completa) break;
    }
    return resultado;
  }

  /// Texto com a caixa de cada linha, para remontar as colunas depois.
  /// Vão os quatro cantos de cada linha, e não a caixa reta: com eles a
  /// inclinação da foto é desfeita antes da remontagem.
  Future<List<BlocoOcr>> _reconhecer(String caminho) async {
    final resultado = await _recognizer
        .processImage(InputImage.fromFilePath(caminho))
        .timeout(_limiteReconhecimento);
    return blocosEndireitados([
      for (final bloco in resultado.blocks)
        [
          for (final l in bloco.lines)
            (
              l.text,
              l.cornerPoints.length == 4
                  ? l.cornerPoints
                  : [
                      // sem os cantos (algumas versões do iOS), a caixa reta
                      l.boundingBox.topLeft,
                      l.boundingBox.topRight,
                      l.boundingBox.bottomRight,
                      l.boundingBox.bottomLeft,
                    ].map((o) => math.Point(o.dx, o.dy)).toList(),
            ),
        ],
    ]);
  }

  Future<List<CodigoLido>> _lerCodigos(String caminho) async {
    try {
      final lidos = await _leitorCodigos
          .processImage(InputImage.fromFilePath(caminho))
          .timeout(_limiteCodigos);
      return [
        for (final c in lidos)
          if ((c.rawValue ?? c.displayValue ?? '').isNotEmpty)
            CodigoLido(
              switch (c.format) {
                BarcodeFormat.qrCode => 'qr',
                BarcodeFormat.code128 => 'code128',
                final outro => outro.name,
              },
              (c.rawValue ?? c.displayValue)!,
            ),
      ];
    } catch (_) {
      // sem código a leitura segue só pelo texto, como antes
      return const [];
    }
  }

  /// Gera a variação num isolate e devolve o caminho do arquivo temporário.
  static Future<String?> _gerarVariante(
      String caminho, _Variante variante) async {
    try {
      final bytes = await File(caminho).readAsBytes();
      final tratada = await Isolate.run(() => _tratar(bytes, variante))
          .timeout(_limiteVariante);
      if (tratada == null) return null;
      final destino = '$caminho.${variante.name}.jpg';
      await File(destino).writeAsBytes(tratada);
      return destino;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _tratar(Uint8List bytes, _Variante variante) {
    final decodificada = img.decodeImage(bytes);
    if (decodificada == null) return null;
    // O JPEG que geramos não carrega o EXIF do original: sem assar a
    // orientação aqui, uma foto de retrato voltaria deitada.
    var imagem = img.bakeOrientation(decodificada);

    switch (variante) {
      case _Variante.girada90:
        imagem = img.copyRotate(imagem, angle: 90);
      case _Variante.girada270:
        imagem = img.copyRotate(imagem, angle: 270);
      case _Variante.realce:
        imagem =
            img.adjustColor(img.grayscale(_ampliar(imagem)), contrast: 1.35);
      case _Variante.binarizada:
        imagem = _binarizar(img.grayscale(_ampliar(imagem)));
    }
    return Uint8List.fromList(img.encodeJpg(imagem, quality: 95));
  }

  static img.Image _ampliar(img.Image imagem) =>
      imagem.width < 1400 ? img.copyResize(imagem, width: 1600) : imagem;

  /// Preto e branco pelo limiar de Otsu — o corte que melhor separa a
  /// tinta do papel na distribuição de luminância desta foto.
  static img.Image _binarizar(img.Image cinza) {
    final limiar = _limiarOtsu(cinza);
    for (var y = 0; y < cinza.height; y++) {
      for (var x = 0; x < cinza.width; x++) {
        final v = cinza.getPixel(x, y).r <= limiar ? 0 : 255;
        cinza.setPixelRgb(x, y, v, v, v);
      }
    }
    return cinza;
  }

  static int _limiarOtsu(img.Image cinza) {
    final histograma = List<int>.filled(256, 0);
    for (final pixel in cinza) {
      histograma[pixel.r.toInt().clamp(0, 255)]++;
    }
    final total = cinza.width * cinza.height;
    var somaTotal = 0.0;
    for (var i = 0; i < 256; i++) {
      somaTotal += i * histograma[i];
    }

    var somaFundo = 0.0;
    var pesoFundo = 0;
    var melhorVariancia = -1.0;
    var limiar = 128;
    for (var i = 0; i < 256; i++) {
      pesoFundo += histograma[i];
      if (pesoFundo == 0) continue;
      final pesoFrente = total - pesoFundo;
      if (pesoFrente == 0) break;
      somaFundo += i * histograma[i];
      final mediaFundo = somaFundo / pesoFundo;
      final mediaFrente = (somaTotal - somaFundo) / pesoFrente;
      final diferenca = mediaFundo - mediaFrente;
      final variancia = pesoFundo * pesoFrente * diferenca * diferenca;
      if (variancia > melhorVariancia) {
        melhorVariancia = variancia;
        limiar = i;
      }
    }
    return limiar;
  }

  void dispose() {
    _recognizer.close();
    _leitorCodigos.close();
  }

  /// O aviso que a tela mostra depois da leitura: o que fazer quando nada
  /// foi lido, e o quanto confiar no que foi.
  static String avisoDaLeitura(NotaFiscalExtraida nota) {
    if (!nota.encontrouAlgo) {
      return 'Não consegui ler os dados desta nota (a foto ficou anexada). '
          'Notas impressas funcionam melhor que manuscritas — tente '
          'fotografar de frente, com boa luz e sem sombra.';
    }
    return [
      nota.passes > 1
          ? 'A foto estava difícil de ler: recuperei os dados '
              'realçando a imagem. Confira campo a campo.'
          : 'Dados extraídos da nota pelo OCR — confira antes de salvar.',
      // O CNPJ não aparece no formulário: quando ele veio da chave de
      // acesso (conferida por dígito verificador), vale dizer qual é.
      if (nota.cnpjDaChave)
        'CNPJ ${nota.cnpj} conferido pela chave de acesso da nota.',
    ].join(' ');
  }

  /// Mensagem para o usuário quando a leitura falha — o erro técnico não
  /// ajuda quem está no canteiro a decidir o que fazer.
  static String mensagemDeErro(Object erro) {
    if (erro is TimeoutException) {
      return 'A leitura da nota demorou demais. Tente de novo com a nota '
          'bem iluminada e o celular parado, ou preencha os campos à mão.';
    }
    if (erro is MissingPluginException) {
      return 'A leitura de notas não está disponível neste aparelho. '
          'Preencha os campos à mão.';
    }
    if (erro is FileSystemException) {
      return 'Não consegui abrir a foto da nota. Tire a foto de novo ou '
          'preencha os campos à mão.';
    }
    if (erro is PlatformException) {
      return 'O leitor do aparelho não conseguiu processar esta foto. '
          'Tente outra foto ou preencha os campos à mão.';
    }
    return 'Não consegui ler esta nota. Tente outra foto, de frente e com '
        'boa luz, ou preencha os campos à mão.';
  }

  // ------------------------------------------------------------- Parser

  static final RegExp _regexCnpj =
      RegExp(r'\b\d{2}\.?\d{3}\.?\d{3}\s*/?\s*\d{4}\s*-?\s*\d{2}\b');

  /// CNPJ com letra no lugar de dígito ("12.345.67B/0001-9O"). Só com a
  /// pontuação completa, que garante que é CNPJ e não uma palavra.
  static final RegExp _regexCnpjSujo =
      RegExp(r'(?<![\dA-Za-z])[\dOoIlSB]{2}\.[\dOoIlSB]{3}\.[\dOoIlSB]{3}/'
          r'[\dOoIlSB]{4}-[\dOoIlSB]{2}(?![\dA-Za-z])');

  static final RegExp _regexData =
      RegExp(r'\b(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})\b');

  /// Data com letra no lugar de dígito ("27/O6/2026", "2O/O6/2O26").
  static final RegExp _dataSuja =
      RegExp(r'(?<![A-Za-z0-9])[0-9OoIlSB]{1,2}[/.\-][0-9OoIlSB]{1,2}[/.\-]'
          r'(?:[0-9OoIlSB]{4}|[0-9OoIlSB]{2})(?![A-Za-z0-9])');

  /// Valores monetários BR com centavos: 1.234,56 | 1234,56 | R$ 350,00
  static final RegExp _regexValor = RegExp(
      r'(?<![\d,])(?:R\$\s*)?(\d{1,3}(?:\.\d{3})+|\d+),(\d{2})(?![\d,])');

  /// Ponto de milhar lido como vírgula ("1,250,00").
  static final RegExp _regexValorMilharVirgula =
      RegExp(r'(?<![\d.,])(\d{1,3}(?:,\d{3})+),(\d{2})(?![\d.,])');

  /// O OCR troca a vírgula decimal por ponto em papel gasto ("350.00").
  /// Só vale sem separador de milhar junto, para não quebrar "1.234".
  /// As âncoras dos dois lados impedem que a data "05.06.26" vire R$ 6,26.
  static final RegExp _regexValorPonto =
      RegExp(r'(?<![\d.,])(?:R\$\s*)?(\d{1,6})\.(\d{2})(?![\d.,])');

  /// Vírgula decimal lida como ponto com milhar junto: "1.250.00" e
  /// "1,250.00" são R$ 1.250,00 — o grupo de 3 dígitos é o milhar.
  static final RegExp _regexValorPontoMilhar =
      RegExp(r'(?<![\d.,])(\d{1,3}(?:[.,]\d{3})+)\.(\d{2})(?![\d.,])');

  /// Valores inteiros com R$ explícito ("R$ 350"), comuns em nota de mão.
  static final RegExp _regexValorInteiroComRs =
      RegExp(r'R\$\s*(\d{1,3}(?:\.\d{3})+|\d+)(?![\d,]|\.\d)');

  /// Valores inteiros sem R$ — aceitos apenas junto de rótulo de total.
  /// Não pode ser pedaço de data, hora, código ("50KG") nem percentual.
  static final RegExp _regexValorInteiro =
      RegExp(r'(?<![A-Za-z:\d,./])(\d{1,3}(?:\.\d{3})+|\d+)'
          r'(?![A-Za-z\d,:/%]|\.\d|\s*%)');

  /// Trecho numérico com letra no meio ("35O,OO", "1.2S0,00"): o OCR
  /// confunde O/0, S/5, I/1. É reescrito como número antes do parser.
  static final RegExp _numeroSujo =
      RegExp(r'(?<![A-Za-zÀ-ÿ])[\dOoIlSsBZzGT]{1,3}(?:\.[\dOoIlSsBZzGT]{3})*'
          r',[\dOoIlSsBZzGT]{2}(?![A-Za-zÀ-ÿ0-9])');

  /// O mesmo com ponto decimal ("517.8O", "35O.OO"). Exige dígito de
  /// verdade na parte inteira: sem ele, "S.OS" viraria R$ 5,05.
  static final RegExp _numeroSujoPonto = RegExp(
      r'(?<![A-Za-zÀ-ÿ\d.,])[\dOoIlSsBZzGT]{1,3}(?:\.[\dOoIlSsBZzGT]{3})*'
      r'\.[\dOoIlSsBZzGT]{2}(?![A-Za-zÀ-ÿ0-9.,])');

  static final RegExp _temLetra = RegExp(r'[A-Za-z]');

  /// Parser puro (testável sem ML Kit) para texto sem geometria.
  static NotaFiscalExtraida parsearTexto(String texto) =>
      interpretar(EntradaOcr.deTexto(texto));

  /// Parte pura da leitura: combina o texto corrido, as linhas remontadas
  /// pela posição (quando houver) e os códigos lidos na foto.
  ///
  /// Cada campo vem da fonte mais confiável que o tiver: o código (QR /
  /// barras) antes do texto, e o texto remontado antes do corrido — o
  /// corrido junta rótulo e valor de colunas diferentes.
  static NotaFiscalExtraida interpretar(EntradaOcr entrada) {
    final corridas = _linhasCorridas(entrada.texto);
    final visuais = entrada.linhasVisuais;
    final remontadas = visuais == null ? null : _linhasRemontadas(visuais);

    final codigo = _dadosDosCodigos(entrada.codigos);
    final reconstruido = entrada.textoReconstruido;
    final chave = codigo?.chave ??
        ChaveAcesso.procurarNoTexto(reconstruido ?? entrada.texto) ??
        (reconstruido == null
            ? null
            : ChaveAcesso.procurarNoTexto(entrada.texto));

    final fornecedor = remontadas == null
        ? _extrairFornecedor(corridas.map((l) => l.texto).toList())
        : _extrairFornecedor([
              for (final l in remontadas)
                for (final t in l.trechos) l.texto.substring(t.inicio, t.fim),
            ]) ??
            _extrairFornecedor(corridas.map((l) => l.texto).toList());

    return NotaFiscalExtraida(
      fornecedorNome: fornecedor,
      cnpj: _escolherCnpj(chave, remontadas ?? corridas) ??
          (remontadas == null ? null : _escolherCnpj(chave, corridas)),
      valorTotal: codigo?.valorTotal ?? _extrairTotal(remontadas, corridas),
      data: codigo != null
          ? _dataDoCodigo(codigo) ?? _extrairData(remontadas, corridas, chave)
          : _extrairData(remontadas, corridas, chave),
      // O texto devolvido é o original: quem for conferir na tela precisa
      // ver o que o OCR leu, não a nossa correção.
      textoCompleto: entrada.texto,
      chaveAcesso: chave?.digitos,
      textoReconstruido: reconstruido,
    );
  }

  static List<_Linha> _linhasCorridas(String texto) => [
        for (final l in _corrigirNumeros(texto).split('\n'))
          if (l.trim().isNotEmpty) _Linha(l.trim()),
      ];

  /// Cada linha impressa vira uma linha de texto, lembrando de onde veio
  /// cada trecho para achar o valor que está embaixo de um rótulo.
  static List<_Linha> _linhasRemontadas(List<LinhaVisual> visuais) {
    final linhas = <_Linha>[];
    for (final v in visuais) {
      final buffer = StringBuffer();
      final trechos = <_Trecho>[];
      for (final t in v.trechos) {
        final texto = _corrigirNumeros(t.texto.trim());
        if (texto.isEmpty) continue;
        if (buffer.isNotEmpty) buffer.write(' ');
        final inicio = buffer.length;
        buffer.write(texto);
        trechos.add(_Trecho(inicio, buffer.length, t));
      }
      if (trechos.isNotEmpty) {
        linhas.add(_Linha(buffer.toString(), trechos: trechos));
      }
    }
    return linhas;
  }

  /// Reescreve como número os trechos em que o OCR trocou dígito por
  /// letra ("35O,OO" → "350,00", "27/O6/2026" → "27/06/2026").
  static String _corrigirNumeros(String texto) => texto
          // a data primeiro: "27.O6.2O26" não pode virar o valor 27,06
          .replaceAllMapped(_dataSuja, (m) {
        final trecho = m.group(0)!;
        final letras = trecho.replaceAll(RegExp(r'[\d/.\-]'), '').length;
        final digitos = trecho.replaceAll(RegExp(r'\D'), '').length;
        // Até três trocas: "2O/O6/2O26" é comum em cupom térmico gasto, e
        // com quatro dígitos de verdade o desenho de data já é inequívoco.
        return letras > 0 && letras <= 3 && digitos >= 4
            ? TextoBr.corrigirDigitos(trecho)
            : trecho;
      }).replaceAllMapped(_numeroSujo, (m) {
        final trecho = m.group(0)!;
        // sem letra no meio já é número — mexer só arriscaria estragar
        return _temLetra.hasMatch(trecho)
            ? TextoBr.corrigirDigitos(trecho)
            : trecho;
      }).replaceAllMapped(_numeroSujoPonto, (m) {
        final trecho = m.group(0)!;
        final inteira = trecho.substring(0, trecho.lastIndexOf('.'));
        return _temLetra.hasMatch(trecho) && RegExp(r'\d').hasMatch(inteira)
            ? TextoBr.corrigirDigitos(trecho)
            : trecho;
      });

  /// Maiúsculas sem acento, caractere por caractere: as posições batem com
  /// as do texto original, e um rótulo achado aqui aponta para o valor lá.
  static String _maiusculaSemAcento(String texto) {
    final buffer = StringBuffer();
    for (final c in texto.codeUnits) {
      if (c < 128) {
        buffer.writeCharCode(c >= 97 && c <= 122 ? c - 32 : c);
        continue;
      }
      final original = String.fromCharCode(c);
      final trocado = TextoBr.normalizar(original).toUpperCase();
      buffer.write(trocado.length == 1 ? trocado : original);
    }
    return buffer.toString();
  }

  // ------------------------------------------------------------ Códigos

  /// Junta o que os códigos da foto dizem da mesma nota (o QR e o código
  /// de barras do DANFE trazem a mesma chave, cada um com seus extras).
  static DadosDoCodigo? _dadosDosCodigos(List<CodigoLido> codigos) {
    DadosDoCodigo? dados;
    for (final c in codigos) {
      final lido = DadosDoCodigo.ler(c.valor);
      if (lido == null) continue;
      if (dados == null) {
        dados = lido;
      } else if (lido.chave == dados.chave) {
        dados = DadosDoCodigo(
          dados.chave,
          diaEmissao: dados.diaEmissao ?? lido.diaEmissao,
          dataEmissao: dados.dataEmissao ?? lido.dataEmissao,
          valorTotal: dados.valorTotal ?? lido.valorTotal,
        );
      }
    }
    return dados;
  }

  /// Data que o código informa: completa (SAT, QR v1) ou só o dia (QR
  /// offline), que com o ano e o mês da chave fecha a data de emissão.
  static DateTime? _dataDoCodigo(DadosDoCodigo codigo) {
    final chave = codigo.chave;
    final dia = codigo.diaEmissao;
    final data = codigo.dataEmissao ??
        (dia == null ? null : DateTime(chave.ano, chave.mes, dia));
    if (data == null) return null;
    if (dia != null && data.day != dia) return null; // 31 num mês de 30
    if (!chave.mesmoMes(data) || !_dataPlausivel(data)) return null;
    return data;
  }

  // --------------------------------------------------------------- CNPJ

  static String? _escolherCnpj(ChaveAcesso? chave, List<_Linha> linhas) {
    // O da chave foi conferido pelo DV da chave inteira: vence o lido no
    // papel, onde o OCR erra um dígito sem ninguém notar.
    if (chave != null && cnpjValido(chave.cnpj)) {
      return _formatarCnpj(chave.cnpj);
    }

    final candidatos = <_CandidatoCnpj>[
      // Chave sem CNPJ válido (dado de teste ou CPF): fica atrás de
      // qualquer CNPJ válido, mas à frente dos inválidos do texto.
      if (chave != null && !chave.cnpj.startsWith('000'))
        _CandidatoCnpj(chave.cnpj, -1),
    ];
    var secaoDeTerceiro = false;
    for (var i = 0; i < linhas.length; i++) {
      final linha = linhas[i];
      if (_cabecalhoDeTerceiro.hasMatch(linha.chave)) secaoDeTerceiro = true;
      // a ordem dos blocos do OCR pode pôr o quadro do emitente depois
      if (_mencionaEmitente.hasMatch(linha.chave)) secaoDeTerceiro = false;

      var fimAnterior = 0;
      final achados = [
        for (final m in _regexCnpj.allMatches(linha.texto))
          (m.start, m.end, m.group(0)!.replaceAll(RegExp(r'\D'), '')),
        for (final m in _regexCnpjSujo.allMatches(linha.texto))
          if (_temLetra.hasMatch(m.group(0)!))
            (
              m.start,
              m.end,
              TextoBr.corrigirDigitos(m.group(0)!).replaceAll(RegExp(r'\D'), '')
            ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));

      for (final (inicio, fim, digitos) in achados) {
        if (digitos.length != 14) continue;
        final antes = linha.chave.substring(fimAnterior, inicio);
        fimAnterior = fim;
        // "CNPJ:" sozinho na frente: quem diz de quem é a linha de cima
        final soRotulo = antes
            .replaceAll(RegExp(r'\b(CNPJ|CPF|MF|C\.N\.P\.J\.?)\b'), '')
            .replaceAll(RegExp(r'[^A-Z]'), '')
            .isEmpty;
        bool menciona(RegExp quem) =>
            quem.hasMatch(antes) ||
            (soRotulo && i > 0 && quem.hasMatch(linhas[i - 1].chave));
        final emitente = menciona(_mencionaEmitente);
        final terceiro =
            !emitente && (secaoDeTerceiro || menciona(_mencionaTerceiro));
        candidatos.add(
            _CandidatoCnpj(digitos, i, terceiro: terceiro, emitente: emitente));
      }
    }
    if (candidatos.isEmpty) return null;

    // Uma nota traz vários CNPJ (emitente, contador, software house,
    // destinatário). Um inválido é dígito lido errado e nunca vence um
    // válido; entre os válidos, o rotulado como emitente, depois os sem
    // dono declarado (o emitente está no topo) e por último os de
    // terceiros.
    int peso(_CandidatoCnpj c) =>
        (cnpjValido(c.digitos) ? 0 : 3) +
        (c.emitente ? 0 : (c.terceiro ? 2 : 1));
    candidatos.sort((a, b) {
      final porPeso = peso(a).compareTo(peso(b));
      return porPeso != 0 ? porPeso : a.ordem.compareTo(b.ordem);
    });
    return _formatarCnpj(candidatos.first.digitos);
  }

  static final RegExp _mencionaEmitente = RegExp(r'\bEMITENTE\b');

  /// Quem não é o emitente e também tem CNPJ impresso na nota.
  static final RegExp _mencionaTerceiro = RegExp(
      r'\b(DESTINATARIO|REMETENTE|TRANSPORTADOR\w*|CONSUMIDOR|CLIENTE|'
      r'TOMADOR|ADQUIRENTE|INTERMEDIADOR|CONTADOR|CONTABIL\w*|CRC|'
      r'SOFTWARE|DESENVOLVID\w*|DESENVOLVEDOR\w*|AUTOMACAO|AUTORIZAD\w*)\b');

  /// Título de seção (curto, no começo da linha) a partir do qual os dados
  /// são de outra pessoa: "DESTINATÁRIO / REMETENTE" no DANFE.
  static final RegExp _cabecalhoDeTerceiro =
      RegExp(r'^\W*(DESTINATARIO|REMETENTE|TRANSPORTADOR\w*|CONSUMIDOR|TOMADOR)'
          r'\b[\sA-Z/\-]{0,40}$');

  static String _formatarCnpj(String d) =>
      '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/'
      '${d.substring(8, 12)}-${d.substring(12)}';

  /// Confere os dois dígitos verificadores do CNPJ.
  static bool cnpjValido(String digitos) {
    if (digitos.length != 14) return false;
    if (!RegExp(r'^\d{14}$').hasMatch(digitos)) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(digitos)) return false;
    const pesos = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    for (var rodada = 0; rodada < 2; rodada++) {
      final tamanho = 12 + rodada;
      final pesosDaRodada = pesos.sublist(13 - tamanho);
      var soma = 0;
      for (var i = 0; i < tamanho; i++) {
        soma += int.parse(digitos[i]) * pesosDaRodada[i];
      }
      final resto = soma % 11;
      final esperado = resto < 2 ? 0 : 11 - resto;
      if (int.parse(digitos[tamanho]) != esperado) return false;
    }
    return true;
  }

  // --------------------------------------------------------------- Data

  static final RegExp _horaEmSeguida =
      RegExp(r'^\s*(?:[-–,|]|[aà]s)?\s*\d{1,2}[:h]\d{2}', caseSensitive: false);

  /// Rótulos que dizem que a data seguinte é a da emissão.
  static final RegExp _rotuloEmissao = RegExp(
      r'(?<![A-Z])(EMISSAO|EMITIDA|EMITIDO|DATA|DT|VENDA EM|COMPRA)(?![A-Z])');

  /// Rótulos de outras datas da nota, que nunca são a da compra.
  static final RegExp _rotuloOutraData =
      RegExp(r'(?<![A-Z])(VENCIMENTO|VENCTO|VENC|VALIDADE|VALIDO ATE|ENTREGA|'
          r'IMPRESSAO|IMPRESSO|IMPRESSA|SAIDA|ENTRADA|RECEBIMENTO|PREVISAO|'
          r'NASCIMENTO)(?![A-Z])');

  /// Datas que costumam ser as da emissão, mas nem sempre: a autorização
  /// do protocolo sai minutos depois — ou dias, na contingência. Perdem
  /// para qualquer data sem rótulo, mas ainda servem se não houver outra.
  static final RegExp _rotuloDataPosterior =
      RegExp(r'(?<![A-Z])(PROTOCOLO|AUTORIZACAO|AUTORIZADA|AUTORIZADO)'
          r'(?![A-Z])');

  /// Data de emissão. Uma nota traz várias datas (vencimento, entrega,
  /// impressão, validade do certificado): pontua as candidatas em vez de
  /// ficar com a primeira que aparecer. Com a chave de acesso, só vale a
  /// que cai no ano e mês dela.
  static DateTime? _extrairData(
      List<_Linha>? remontadas, List<_Linha> corridas, ChaveAcesso? chave) {
    DateTime? melhor;
    // abaixo disto só ficam as datas de outro evento (vencimento, entrega)
    var melhorPontos = -2;

    void avaliar(List<_Linha> linhas, {required bool vizinhas}) {
      for (var i = 0; i < linhas.length; i++) {
        final linha = linhas[i];
        var fimAnterior = 0;
        for (final m in _regexData.allMatches(linha.texto)) {
          final antes = linha.chave.substring(fimAnterior, m.start);
          fimAnterior = m.end;
          final data = _montarData(m);
          if (data == null) continue;
          if (chave != null && !chave.mesmoMes(data)) continue;

          // vale o rótulo mais próximo da data, à esquerda dela
          var pontos = _pontosDoRotulo(antes, emissao: 3);
          if (pontos == 0) {
            pontos = _pontosDoRotuloAcima(linhas, i, m.start, vizinhas);
          }
          // vencimento, entrega, impressão: nem com hora vira emissão
          if (pontos <= -3) continue;
          // a data de emissão costuma vir acompanhada da hora
          // ("15/06/2026 14:32", "15/06/2026 - 14:32", "15/06/26 às 14h32")
          if (_horaEmSeguida.hasMatch(linha.texto.substring(m.end))) {
            pontos += 2;
          }
          if (pontos > melhorPontos) {
            melhorPontos = pontos;
            melhor = data;
          }
        }
      }
    }

    // As remontadas primeiro: no empate, fica a delas.
    if (remontadas != null) avaliar(remontadas, vizinhas: true);
    avaliar(corridas, vizinhas: remontadas == null);
    return melhor;
  }

  /// +[emissao] se o último rótulo de data em [texto] é de emissão, -3 se
  /// é de outra data, -1 se é do protocolo de autorização, 0 sem rótulo.
  static int _pontosDoRotulo(String texto, {required int emissao}) {
    final positivo = _rotuloEmissao.allMatches(texto).lastOrNull;
    final negativo = _rotuloOutraData.allMatches(texto).lastOrNull;
    final posterior = _rotuloDataPosterior.allMatches(texto).lastOrNull;
    final ultimo = [positivo, negativo, posterior]
        .whereType<RegExpMatch>()
        .fold<RegExpMatch?>(
            null, (a, b) => a == null || b.end >= a.end ? b : a);
    if (ultimo == null) return 0;
    if (identical(ultimo, negativo)) return -3;
    if (identical(ultimo, posterior)) return -1;
    return emissao;
  }

  /// Rótulo na linha de cima ("DATA DA EMISSÃO" com a data embaixo, como
  /// no DANFE). Com geometria, só o trecho que está acima da data; sem
  /// ela, a linha anterior se não tiver data própria.
  static int _pontosDoRotuloAcima(
      List<_Linha> linhas, int i, int posicao, bool vizinhas) {
    if (i == 0) return 0;
    final linha = linhas[i];
    final acima = linhas[i - 1];
    if (linha.temGeometria && acima.temGeometria) {
      final trecho = linha.trechoEm(posicao);
      if (trecho == null) return 0;
      if (trecho.caixa.topo - acima.base > trecho.caixa.altura * _folgaAbaixo) {
        return 0;
      }
      for (final t in acima.trechos) {
        if (t.caixa.direita < trecho.caixa.esquerda ||
            t.caixa.esquerda > trecho.caixa.direita) {
          continue;
        }
        final pontos =
            _pontosDoRotulo(acima.chave.substring(t.inicio, t.fim), emissao: 2);
        if (pontos != 0) return pontos;
      }
      return 0;
    }
    if (!vizinhas || _regexData.hasMatch(acima.texto)) return 0;
    return _pontosDoRotulo(acima.chave, emissao: 2);
  }

  static DateTime? _montarData(RegExpMatch m) {
    final dia = int.parse(m.group(1)!);
    final mes = int.parse(m.group(2)!);
    var ano = int.parse(m.group(3)!);
    if (ano < 100) ano += 2000;
    if (dia < 1 || dia > 31 || mes < 1 || mes > 12) return null;
    final data = DateTime(ano, mes, dia);
    if (data.day != dia || data.month != mes) return null; // 31/02
    return _dataPlausivel(data) ? data : null;
  }

  static bool _dataPlausivel(DateTime data) =>
      data.year >= 2000 &&
      data.year <= DateTime.now().year + 1 &&
      !data.isAfter(DateTime.now().add(const Duration(days: 1)));

  // -------------------------------------------------------------- Total

  static const int _rotuloFalso = -1;

  /// Rótulos de valor e seu nível — 0 é o mais forte. O que foi cobrado
  /// (com desconto e frete) vale mais que o "total" solto, que vale mais
  /// que a soma dos produtos. Nível -1: rótulo cujo número nunca é o total
  /// (contagem, troco, imposto, pagamento) — ele é "dono" do número que o
  /// segue, para que esse número não seja atribuído a outro rótulo.
  static const Map<String, int> _rotulosValor = {
    'VALOR A PAGAR': 0, 'TOTAL A PAGAR': 0, 'VALOR TOTAL A PAGAR': 0,
    'VLR A PAGAR': 0, 'VL A PAGAR': 0,
    'VALOR TOTAL DA NOTA': 0, 'VALOR DA NOTA': 0, 'TOTAL DA NOTA': 0,
    'VL TOTAL DA NOTA': 0, 'VLR TOTAL DA NOTA': 0, 'VL. TOTAL DA NOTA': 0,
    'TOTAL LIQUIDO': 0, 'VALOR LIQUIDO': 0, 'TOTAL GERAL': 0,
    'VALOR COBRADO': 0,
    //
    'VALOR TOTAL': 1, 'TOTAL DA COMPRA': 1, 'TOTAL DO PEDIDO': 1,
    'TOTAL DO CUPOM': 1, 'TOTAL DA VENDA': 1, 'VALOR DA COMPRA': 1,
    'VALOR DO PEDIDO': 1,
    //
    'TOTAL': 2, 'VL TOTAL': 2, 'VL. TOTAL': 2, 'VLR TOTAL': 2,
    'VLR. TOTAL': 2, 'V. TOTAL': 2,
    //
    'SUBTOTAL': 3, 'SUB TOTAL': 3, 'SUB-TOTAL': 3, 'SOMA': 3,
    'TOTAL DOS PRODUTOS': 3, 'VALOR TOTAL DOS PRODUTOS': 3,
    'VL TOTAL DOS PRODUTOS': 3, 'VALOR DOS PRODUTOS': 3,
    'TOTAL PRODUTOS': 3, 'TOTAL DE PRODUTOS': 3,
    //
    'TOTAL DE ITENS': -1, 'TOTAL ITENS': -1, 'QTD TOTAL': -1,
    'QTDE TOTAL': -1, 'QTD. TOTAL': -1, 'QTDE. TOTAL': -1,
    'QUANTIDADE TOTAL': -1, 'TOTAL DE PECAS': -1, 'TOTAL DE VOLUMES': -1,
    'ITENS': -1, 'TROCO': -1, 'DESCONTO': -1, 'DESCONTOS': -1, 'DESC': -1,
    'ACRESCIMO': -1, 'ACRESCIMOS': -1, 'ECONOMIA': -1, 'JUROS': -1,
    'MULTA': -1, 'TRIBUTOS': -1, 'TRIBUTO': -1, 'TRIB': -1, 'IMPOSTO': -1,
    'IMPOSTOS': -1, 'FRETE': -1, 'VALOR DO FRETE': -1, 'SEGURO': -1,
    'VALOR DO SEGURO': -1, 'OUTRAS DESPESAS': -1,
    'DESPESAS ACESSORIAS': -1, 'ICMS': -1, 'IPI': -1, 'ISS': -1,
    'ISSQN': -1, 'PIS': -1, 'COFINS': -1, 'BASE DE CALCULO': -1,
    'BASE DE CALC': -1, 'BASE CALC': -1, 'VALOR TOTAL DO IPI': -1,
    'VALOR DO IPI': -1, 'VALOR DO ICMS': -1, 'VALOR TOTAL DOS TRIBUTOS': -1,
    'VALOR APROXIMADO DOS TRIBUTOS': -1, 'VALOR APROX': -1,
    'DINHEIRO': -1, 'CARTAO': -1, 'CREDITO': -1, 'DEBITO': -1, 'PIX': -1,
    'CHEQUE': -1, 'VALOR PAGO': -1, 'VALOR RECEBIDO': -1, 'RECEBIDO': -1,
    'PESO': -1, 'PESO TOTAL': -1, 'PESO BRUTO': -1, 'PESO LIQUIDO': -1,
  };

  static const int _nivelMaisFraco = 3;

  /// Todos os rótulos numa expressão só, do mais longo para o mais curto:
  /// em "VALOR TOTAL DOS PRODUTOS" casa o rótulo inteiro, e não o
  /// "VALOR TOTAL" que está dentro dele.
  static final RegExp _regexRotulos = RegExp(
    '(?<![A-Z])(?:${(_rotulosValor.keys.toList()..sort((a, b) => b.length.compareTo(a.length))).map(_padraoRotulo).join('|')})(?![A-Z])',
  );

  /// Espaço opcional entre as palavras ("VALORTOTAL") e ponto opcional
  /// depois de cada uma: o cupom abrevia como quer ("VL. A PAGAR", "VLR
  /// TOTAL.") e a lista não precisa trazer cada grafia.
  static String _padraoRotulo(String rotulo) => rotulo
      .split(' ')
      .map((p) => '${RegExp.escape(p.replaceAll('.', ''))}\\.?')
      .join(r'\s*');

  /// Palavras que, coladas a um "TOTAL", dizem que ele é de outra coisa:
  /// "TOTAL DO IPI", "VALOR TOTAL DOS TRIBUTOS", "QTDE. TOTAL".
  static const Set<String> _qualificamDepois = {
    'ITENS',
    'ITEM',
    'PECAS',
    'PECA',
    'VOLUMES',
    'VOLUME',
    'IPI',
    'ICMS',
    'ISS',
    'ISSQN',
    'PIS',
    'COFINS',
    'TRIBUTOS',
    'TRIBUTO',
    'TRIB',
    'IMPOSTOS',
    'IMPOSTO',
    'FRETE',
    'SEGURO',
    'APROX',
    'APROXIMADO',
    'KG',
    'PESO',
    'QTD',
    'QTDE',
    // o "total" do pagamento inclui o troco; o do desconto é o abatido
    'PAGO',
    'RECEBIDO',
    'DINHEIRO',
    'TROCO',
    'DESCONTO',
    'DESCONTOS',
    'DESC',
    'ACRESCIMO',
    'ACRESCIMOS',
    'ECONOMIA',
    'APROXIMADOS',
    'APROXIMADA',
  };
  static const Set<String> _qualificamAntes = {
    'QTD',
    'QTDE',
    'QUANT',
    'QUANTIDADE',
    'DESCONTO',
    'DESCONTOS',
    'DESC',
    'FRETE',
    'TRIBUTOS',
    'TRIB',
    'IMPOSTOS',
    'ICMS',
    'IPI',
    'PESO',
    'ECONOMIA',
    'ACRESCIMO',
    'TROCO',
  };

  /// "TOTAL COM FRETE" é o total, com o frete dentro.
  static const Set<String> _incluem = {'COM', 'C', 'INCL', 'INCLUSO'};

  /// Depois de um "TOTAL" genérico, dizem que ele é só a soma dos
  /// produtos ("V. TOTAL PRODUTOS", sem o frete e o desconto)...
  static const Set<String> _soDosProdutos = {
    'PRODUTOS',
    'PRODUTO',
    'PROD',
    'MERCADORIAS',
    'MERCADORIA',
  };

  /// ... ou que ele é o da nota inteira ("V. TOTAL DA NOTA", "VLR TOTAL
  /// NF-E"), com tudo dentro. O DANFE abrevia o rótulo de muitos jeitos, e
  /// a lista fixa não cobre todos.
  static const Set<String> _daNotaInteira = {'NOTA', 'NF', 'NFE', 'NFCE'};

  /// Os rótulos de valor da linha. [inicios] são as posições onde começa
  /// cada trecho do OCR (linha remontada): as palavras que qualificam um
  /// rótulo só valem dentro do trecho dele — no DANFE, o "DESCONTO" da
  /// célula do lado não faz do "VALOR TOTAL DA NOTA" um desconto.
  static List<_Rotulo> _rotulosDe(String chave,
      {List<int> inicios = const []}) {
    final rotulos = <_Rotulo>[];
    for (final m in _regexRotulos.allMatches(chave)) {
      final texto = m.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
      final nivel = _rotulosValor[texto] ?? _nivelDoCasamento(texto);
      final de = inicios.where((i) => i <= m.start).fold(0, math.max);
      final ate = inicios.where((i) => i >= m.end).fold(chave.length, math.min);
      final antes = chave.substring(de, m.start);
      // "TOTAL COM DESCONTO", "TOTAL C/ FRETE": o desconto e o frete ali
      // descrevem o total logo antes, não são rótulos com valor próprio.
      // "TOTAL SEM DESCONTO" diz que aquele total ainda não é o cobrado.
      final anterior = rotulos.lastOrNull;
      if (nivel == _rotuloFalso &&
          anterior != null &&
          anterior.nivel != _rotuloFalso &&
          anterior.fim >= de) {
        final entre = _palavra
            .allMatches(chave.substring(anterior.fim, m.start))
            .map((p) => p.group(0))
            .toList();
        if (entre.length == 1 && _incluem.contains(entre.single)) continue;
        if (entre.length == 1 && entre.single == 'SEM') {
          rotulos.last =
              _Rotulo(anterior.inicio, anterior.fim, _nivelMaisFraco);
          continue;
        }
      }
      rotulos.add(_Rotulo(m.start, m.end,
          _nivelQualificado(antes, chave.substring(m.end, ate), nivel)));
    }
    return rotulos;
  }

  /// O casamento pode ter espaço ou ponto diferente do rótulo
  /// ("VALORTOTAL", "VL. A PAGAR").
  static int _nivelDoCasamento(String casado) {
    String compacto(String s) => s.replaceAll(RegExp(r'[\s.]'), '');
    final procurado = compacto(casado);
    for (final e in _rotulosValor.entries) {
      if (compacto(e.key) == procurado) return e.value;
    }
    return _rotuloFalso;
  }

  static final RegExp _palavra = RegExp(r'[A-Z0-9$]+');

  /// O nível do rótulo depois de olhar as palavras em volta: "TOTAL" de
  /// imposto ou de itens vira rótulo falso; um "TOTAL" genérico (níveis 1 e
  /// 2) sobe para o da nota ou desce para o dos produtos.
  static int _nivelQualificado(String antesDele, String depoisDele, int nivel) {
    if (nivel == _rotuloFalso) return nivel;
    final depois = _palavra.allMatches(depoisDele).take(3);
    for (final p in depois) {
      final w = p.group(0)!;
      if (RegExp(r'[\d$]').hasMatch(w) || _incluem.contains(w)) break;
      if (_qualificamDepois.contains(w)) return _rotuloFalso;
      if (nivel == 1 || nivel == 2) {
        if (_soDosProdutos.contains(w)) return _nivelMaisFraco;
        if (_daNotaInteira.contains(w)) return 0;
      }
    }
    final antes = _palavra.allMatches(antesDele).toList();
    for (final p in antes.reversed.take(2)) {
      final w = p.group(0)!;
      if (RegExp(r'[\d$]').hasMatch(w)) break;
      if (_qualificamAntes.contains(w)) return _rotuloFalso;
    }
    return nivel;
  }

  /// Cabeçalho da tabela de itens ("ITEM CÓD DESCRIÇÃO QTD UN VL TOTAL"):
  /// o "VL TOTAL" dele é o nome da coluna, e o número embaixo é de um item.
  static final RegExp _palavraDeCabecalho =
      RegExp(r'(?<![A-Z])(QTDE?|QUANT|QUANTIDADE|UN|UND|UNID|UNIDADE|DESCRICAO|'
          r'DISCRIMINACAO|PRODUTO|CODIGO|COD|ITEM|UNIT|UNITARIO|PRECO|NCM|'
          r'CFOP|CST|REF|REFERENCIA)(?![A-Z])');

  static bool _cabecalhoDeTabela(_Linha linha) {
    if (linha.valores.any((v) => v.tipo <= 1)) return false;
    return _palavraDeCabecalho
            .allMatches(linha.chave)
            .map((m) => m.group(1))
            .toSet()
            .length >=
        2;
  }

  static double? _extrairTotal(
      List<_Linha>? remontadas, List<_Linha> corridas) {
    // 1º: rótulo de total, do nível mais forte ao mais fraco. Em cada
    // nível, as linhas remontadas primeiro; no texto corrido, quando há
    // geometria, só vale valor na mesma linha do rótulo — a "linha de
    // baixo" ali pode ser de outra coluna.
    for (var nivel = 0; nivel <= _nivelMaisFraco; nivel++) {
      if (remontadas != null) {
        final achado = _totalNoNivel(remontadas, nivel, vizinhas: false);
        if (achado != null) return achado;
      }
      final achado =
          _totalNoNivel(corridas, nivel, vizinhas: remontadas == null);
      if (achado != null) return achado;
    }

    // 2º: maior valor com centavos do documento que não seja de troco,
    // imposto ou pagamento — nem ao lado do rótulo, nem embaixo dele (no
    // DANFE, o "30,00" embaixo de "VALOR DO FRETE" é do frete).
    final linhas = remontadas ?? corridas;
    final livres = [
      for (var j = 0; j < linhas.length; j++)
        for (final v in linhas[j].valores)
          if (linhas[j].donoDe(v)?.nivel != _rotuloFalso &&
              _donoAcima(linhas, j, v)?.nivel != _rotuloFalso)
            v,
    ];
    for (final tipo in const [_Valor.virgula, _Valor.ponto]) {
      final doTipo = livres.where((v) => v.tipo == tipo).map((v) => v.valor);
      if (doTipo.isNotEmpty) return doTipo.reduce((a, b) => a > b ? a : b);
    }
    // 3º: nota informal sem centavos — maior valor inteiro com R$ explícito.
    final inteiros =
        livres.where((v) => v.tipo == _Valor.inteiroComRs).map((v) => v.valor);
    if (inteiros.isEmpty) return null;
    return inteiros.reduce((a, b) => a > b ? a : b);
  }

  static double? _totalNoNivel(List<_Linha> linhas, int nivel,
      {required bool vizinhas}) {
    for (var i = 0; i < linhas.length; i++) {
      final linha = linhas[i];
      final doNivel = linha.rotulos.where((r) => r.nivel == nivel);
      if (doNivel.isEmpty || _cabecalhoDeTabela(linha)) continue;

      for (final rotulo in doNivel) {
        final naLinha = _melhorValor(linha.valoresDe(rotulo));
        if (naLinha != null) return naLinha.valor;

        if (linha.temGeometria) {
          final abaixo = _valorAbaixo(linhas, i, rotulo);
          if (abaixo != null) return abaixo;
          continue;
        }
        if (!vizinhas) continue;
        // rótulo e valor em linhas separadas (layout de duas colunas)
        if (i + 1 < linhas.length) {
          final seguinte = _valorDaFileira(linha, rotulo, linhas[i + 1]);
          if (seguinte != null) return seguinte.valor;
        }
        // O valor acima do rótulo só faz sentido com o rótulo sozinho na
        // linha: numa fileira de campos, a linha de cima é a fileira de
        // valores anterior, de outros campos.
        if (i > 0 && linha.rotulosSemValor.length == 1) {
          final anterior =
              _melhorValor(linhas[i - 1].valoresParaVizinho.reversed);
          if (anterior != null) return anterior.valor;
        }
      }
    }
    return null;
  }

  /// O valor da linha de baixo que corresponde ao rótulo, sem geometria.
  ///
  /// Rótulo sozinho na linha: o melhor valor de baixo ("TOTAL A PAGAR" e,
  /// embaixo, "R\$ 1.480,00"). Numa fileira de campos lida como uma linha
  /// só ("VALOR DO FRETE ... V. TOTAL DA NOTA" e, embaixo, "30,00 ...
  /// 380,00"), o k-ésimo rótulo fica com o k-ésimo número; se faltar ou
  /// sobrar número, só o primeiro e o último campo ainda se alinham com
  /// segurança — no meio, melhor deixar vazio que pegar o valor do vizinho.
  static _Valor? _valorDaFileira(_Linha linha, _Rotulo rotulo, _Linha abaixo) {
    final livres = abaixo.valoresParaVizinho;
    final campos = linha.rotulosSemValor;
    if (campos.length <= 1) return _melhorValor(livres);
    final numeros = livres.where((v) => v.tipo <= _Valor.ponto).toList();
    return _alinhado(campos, numeros, campos.indexOf(rotulo));
  }

  /// O item [k] de [a] alinhado a [b] numa fileira: pela posição quando
  /// as duas têm o mesmo tamanho; senão só as pontas se correspondem.
  static T? _alinhado<T>(List<Object> a, List<T> b, int k) {
    if (k < 0 || b.isEmpty) return null;
    if (a.length == b.length) return b[k];
    if (k == a.length - 1) return b.last;
    if (k == 0) return b.first;
    return null;
  }

  /// O primeiro valor do tipo mais confiável: com vírgula, com ponto,
  /// inteiro com R$ e, por último, inteiro solto.
  static _Valor? _melhorValor(Iterable<_Valor> valores) {
    _Valor? melhor;
    for (final v in valores) {
      if (melhor == null || v.tipo < melhor.tipo) melhor = v;
    }
    return melhor;
  }

  /// Até onde, abaixo do rótulo, ainda é a mesma célula — em alturas da
  /// linha do rótulo. No DANFE o valor fica logo embaixo do nome do campo;
  /// mais longe que isso, o número é de outra linha da nota (numa nota de
  /// duas colunas, o valor do rótulo seguinte).
  static const double _folgaAbaixo = 1.5;

  /// Valor impresso embaixo do rótulo, na mesma célula (DANFE: "VALOR
  /// TOTAL DA NOTA" com "380,00" embaixo, ao lado de frete e seguro).
  static double? _valorAbaixo(List<_Linha> linhas, int i, _Rotulo rotulo) {
    final linha = linhas[i];
    final trecho = linha.trechoEm(rotulo.inicio);
    if (trecho == null) return null;
    final celula = _Celula.doRotulo(linha, rotulo);

    for (var j = i + 1; j < linhas.length && j <= i + 2; j++) {
      final abaixo = linhas[j];
      if (abaixo.topo - linha.base > trecho.caixa.altura * _folgaAbaixo) {
        break;
      }
      final naCelula = abaixo.valoresParaVizinho
          .where((v) => celula.contem(abaixo.centroDe(v)));
      final achado = _melhorValor(naCelula);
      if (achado != null) return achado.valor;
      // outra linha de rótulos no caminho: o valor não está mais embaixo
      if (abaixo.rotulos.isNotEmpty) break;
    }
    return null;
  }

  /// O rótulo da linha de cima em cuja célula o valor está — o dono do
  /// número quando o DANFE imprime o nome do campo em cima e o valor
  /// embaixo. Null sem geometria ou sem rótulo logo acima.
  static _Rotulo? _donoAcima(List<_Linha> linhas, int j, _Valor valor) {
    if (j == 0) return null;
    final linha = linhas[j];
    final acima = linhas[j - 1];
    // rótulo que já tem o número ao lado não é dono do de baixo
    final campos = acima.rotulosSemValor;
    if (campos.isEmpty) return null;

    if (linha.temGeometria && acima.temGeometria) {
      final altura = acima.trechos.map((t) => t.caixa.altura).reduce(math.min);
      if (linha.topo - acima.base > altura * _folgaAbaixo) return null;
      final x = linha.centroDe(valor);
      for (final r in campos) {
        if (_Celula.doRotulo(acima, r).contem(x)) return r;
      }
      return null;
    }
    // Sem geometria, a fileira de valores embaixo da fileira de campos:
    // o mesmo alinhamento que dá o total dá o dono dos outros números.
    if (linha.rotulos.isNotEmpty) return null;
    if (campos.length == 1) return campos.single;
    final numeros =
        linha.valoresLivres.where((v) => v.tipo <= _Valor.ponto).toList();
    return _alinhado(numeros, campos, numeros.indexOf(valor));
  }

  static bool _valorPlausivel(double v) => v > 0 && v < 10000000;

  static List<_Valor> _valoresDe(String texto) {
    final achados = <_Valor>[];
    void coletar(RegExp regex, int tipo, double Function(RegExpMatch) valor) {
      for (final m in regex.allMatches(texto)) {
        final v = valor(m);
        if (!_valorPlausivel(v)) continue;
        // o mesmo número achado por duas regras fica com a mais confiável
        if (achados.any((a) => m.start < a.fim && a.inicio < m.end)) continue;
        achados.add(_Valor(m.start, m.end, v, tipo));
      }
    }

    double milhar(String s) => double.parse(s.replaceAll(RegExp('[.,]'), ''));
    coletar(_regexValor, _Valor.virgula,
        (m) => double.parse('${milhar(m.group(1)!).toInt()}.${m.group(2)}'));
    coletar(_regexValorMilharVirgula, _Valor.virgula,
        (m) => double.parse('${milhar(m.group(1)!).toInt()}.${m.group(2)}'));
    coletar(_regexValorPontoMilhar, _Valor.ponto,
        (m) => double.parse('${milhar(m.group(1)!).toInt()}.${m.group(2)}'));
    coletar(_regexValorPonto, _Valor.ponto,
        (m) => double.parse('${m.group(1)}.${m.group(2)}'));
    coletar(_regexValorInteiroComRs, _Valor.inteiroComRs,
        (m) => milhar(m.group(1)!));
    coletar(_regexValorInteiro, _Valor.inteiro, (m) => milhar(m.group(1)!));
    return achados..sort((a, b) => a.inicio.compareTo(b.inicio));
  }

  // ------------------------------------------------------------ Fornecedor

  /// Rótulos que antecedem o nome do estabelecimento.
  static final RegExp _rotuloFornecedor = RegExp(
      r'^(raz[aã]o social|nome fantasia|emitente|empresa|fornecedor|loja)'
      r'\s*[:\-]\s*',
      caseSensitive: false);

  /// Canhoto do DANFE: "RECEBEMOS DE `EMITENTE` OS PRODUTOS...". O nome é
  /// o casamento inteiro (o resto fica nos lookarounds) para que as
  /// posições dele apontem direto para o texto original.
  static final RegExp _canhotoDanfe =
      RegExp(r'(?<=RECEBEMOS\s+DE\s+).{3,60}?(?=\s+(?:OS|AS)\s+'
          r'(?:PRODUTOS|MERCADORIAS|SERVICOS))');

  /// Palavras que indicam fortemente um nome de empresa (palavra inteira:
  /// o " ME" antigo casava com "MEDIA").
  static final RegExp _palavraEmpresa =
      RegExp(r'(?<![A-Z])(LTDA|EIRELI|EPP|ME|MEI|S/A|S\.A|COMERCIO|COMERCIAL|'
          r'MATERIAL|MATERIAIS|DEPOSITO|CONSTRU[A-Z]*|MADEIREIRA|MADEIRAS|'
          r'FERRAGEM|FERRAGENS|FERRAGISTA|ATACADO|ATACADAO|ATACADISTA|'
          r'SUPERMERCADO|MERCADO|LOJA|LOJAS|CASA D(?:O|A|OS|AS)|AGROPECUARIA|'
          r'TINTAS|ELETRICA|ELETRICOS|HIDRAULICA|DISTRIBUIDORA|DISTRIBUIDOR|'
          r'INDUSTRIA|SERRALHERIA|VIDRACARIA|MARMORARIA|CIA|COMPANHIA)'
          r'(?![A-Z])');

  /// Redes de material de construção: quando aparecem, são o fornecedor.
  static const List<String> _redesConhecidas = [
    'LEROY MERLIN',
    'TELHANORTE',
    'OBRAMAX',
    'CASSOL',
    'BALAROTI',
    'TUMELERO',
    'CHATUBA',
    'DICICO',
    'SODIMAC',
    'FERREIRA COSTA',
    'TENDA ATACADO',
    'HOMECENTER',
    'HOME CENTER',
    'CONSTRUFACIL',
  ];

  /// Linhas que nunca são o nome do fornecedor — por palavra inteira:
  /// "TEL" não pode derrubar "CASTELO MATERIAIS".
  static final RegExp _linhaIgnorada =
      RegExp(r'(?<![A-Z])(CUPOM|NOTA FISCAL|DANFE|SAT|NFC|NFCE|NFE|NF|EXTRATO|'
          r'DOCUMENTO|AUXILIAR|CNPJ|CPF|INSCR[A-Z]*|I\.E|IE|CEP|TEL|TELEFONE|'
          r'FONE|FONES|FAX|CEL|CELULAR|WHATSAPP|CAIXA|PDV|OPERADOR[A-Z]*|'
          r'VENDEDOR[A-Z]*|ATENDENTE|CLIENTE|CONSUMIDOR|ITEM|ITENS|QTDE?|'
          r'QUANT[A-Z]*|DESCRICAO|DISCRIMINACAO|ORCAMENTO|PEDIDO|PED|RECIBO|'
          r'ROMANEIO|CHAVE DE ACESSO|PROTOCOLO|AUTORIZACAO|CONSULTE|CONSULTA|'
          r'OBRIGADO|VOLTE SEMPRE|SEM VALOR FISCAL|EMISSAO|SERIE|FOLHA|PAGINA|'
          r'UF|DESTINATARIO|REMETENTE|'
          r'TRANSPORTADOR[A-Z]*|NATUREZA DA OPERACAO|IDENTIFICACAO|TOTAL|'
          r'SUBTOTAL|VALOR|TROCO|DINHEIRO|PAGAMENTO|CONTINGENCIA|HOMOLOGACAO|'
          r'TRIBUTOS|RECEBEMOS|ASSINATURA|WWW|HTTPS?)(?![A-Z])');

  /// Rótulo de campo de endereço ("Município: Recife"). Só como rótulo:
  /// "CIDADE DAS TINTAS LTDA" é nome de loja.
  static final RegExp _rotuloDeEndereco =
      RegExp(r'(?<![A-Z])(MUNICIPIO|CIDADE|ENDERECO|LOGRADOURO)\s*[:\-]');

  static const List<String> _prefixosEndereco = [
    'RUA ',
    'R. ',
    'AV ',
    'AV. ',
    'AVENIDA',
    'ROD ',
    'ROD. ',
    'RODOVIA',
    'ESTRADA',
    'EST. ',
    'TRAVESSA',
    'TV. ',
    'ALAMEDA',
    'AL. ',
    'PRACA',
    'BAIRRO',
    'LOTE ',
    'QUADRA',
    'QD. ',
    'LOTEAMENTO',
  ];

  static const Set<String> _ufs = {
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  };

  /// "Recife - PE", "SAO PAULO/SP": a cidade do endereço, não o nome.
  static final RegExp _cidadeUf =
      RegExp(r'^([A-Z][A-Z .\x27\-]{1,40}?)[\s\-/,]+([A-Z]{2})\.?$');

  static String? _extrairFornecedor(List<String> todas) {
    // Da seção do destinatário em diante os nomes são de quem comprou.
    final fim = todas.indexWhere(
        (l) => _cabecalhoDeTerceiro.hasMatch(_maiusculaSemAcento(l)));
    final linhas = fim == -1 ? todas : todas.sublist(0, fim);
    final candidatas = linhas.take(15).toList();

    // 1º: rede conhecida em qualquer lugar do topo da nota.
    for (final linha in candidatas) {
      final upper = _maiusculaSemAcento(linha);
      for (final rede in _redesConhecidas) {
        if (upper.contains(rede)) return _capitalizar(rede);
      }
    }

    // 2º: rótulo explícito ("Razão Social: ...", canhoto do DANFE,
    // "IDENTIFICAÇÃO DO EMITENTE" com o nome na linha seguinte).
    for (var i = 0; i < candidatas.length; i++) {
      final linha = candidatas[i];
      final m = _rotuloFornecedor.firstMatch(linha);
      if (m != null) {
        final nome = _limparNome(linha.substring(m.end));
        if (nome.length >= 3 && _legivel(nome)) return _capitalizar(nome);
      }
      final upper = _maiusculaSemAcento(linha);
      final canhoto = _canhotoDanfe.firstMatch(upper);
      if (canhoto != null) {
        final nome = _limparNome(linha.substring(canhoto.start, canhoto.end));
        if (_podeSerFornecedor(nome)) return _capitalizar(nome);
      }
      if (upper.contains('IDENTIFICACAO DO EMITENTE') &&
          i + 1 < candidatas.length) {
        final nome = _limparNome(candidatas[i + 1]);
        if (_podeSerFornecedor(nome)) return _capitalizar(nome);
      }
    }

    // 3º: pontua as primeiras linhas válidas.
    String? melhor;
    var melhorPontos = -1;
    for (var i = 0; i < candidatas.length; i++) {
      // A limpeza vem antes da validação: "CONSTRUMAIS LTDA - CNPJ 11.222…"
      // é um nome perfeito assim que o CNPJ sai da frente.
      final linha = _limparNome(candidatas[i]);
      if (!_podeSerFornecedor(linha)) continue;

      var pontos = 0;
      final upper = _maiusculaSemAcento(linha);
      if (_palavraEmpresa.hasMatch(upper)) pontos += 4;
      if (i <= 2) pontos += 2; // topo do documento
      // a razão social costuma vir colada ao CNPJ
      if (_regexCnpj.hasMatch(candidatas[i])) {
        pontos += 3;
      } else if (i + 1 < linhas.length && _regexCnpj.hasMatch(linhas[i + 1])) {
        pontos += 3;
      } else if (i + 2 < linhas.length && _regexCnpj.hasMatch(linhas[i + 2])) {
        pontos += 2;
      }
      // caixa alta é típico de razão social impressa
      final letras = linha.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      if (letras.isNotEmpty &&
          letras == letras.toUpperCase() &&
          letras.length >= 5) {
        pontos += 1;
      }
      // linha cheia de número é código de barras, telefone ou endereço
      if (linha.replaceAll(RegExp(r'\D'), '').length > linha.length * 0.3) {
        pontos -= 3;
      }
      // Só o topo não basta: exige uma evidência de empresa (palavra de
      // empresa, CNPJ ao lado ou razão social em caixa alta). Linha de
      // produto ("CIMENTO CP-II 50KG") e manuscrito mal lido ficam de fora
      // — campo vazio o usuário preenche; nome errado ele pode não notar.
      if (pontos >= 3 && pontos > melhorPontos) {
        melhorPontos = pontos;
        melhor = linha;
      }
    }
    if (melhor != null) return _capitalizar(melhor);

    // 4º: linha imediatamente acima do CNPJ (razão social vem antes).
    for (var i = 1; i < linhas.length; i++) {
      if (_regexCnpj.hasMatch(linhas[i]) &&
          _podeSerFornecedor(_limparNome(linhas[i - 1]))) {
        return _capitalizar(_limparNome(linhas[i - 1]));
      }
    }
    return null;
  }

  /// Tira o que costuma vir grudado no nome na mesma linha
  /// ("CONSTRUMAIS LTDA - CNPJ 12.345.678/0001-95").
  static String _limparNome(String linha) => linha
      .replaceAll(_regexCnpj, '')
      .replaceFirst(
          RegExp(r'\s*[-–|]?\s*(cnpj|cpf|insc\w*|i\.?e\.?)\s*:?.*$',
              caseSensitive: false),
          '')
      .replaceFirst(RegExp(r'[\s\-–|,;:.]+$'), '')
      .trim();

  static bool _podeSerFornecedor(String linha) {
    if (linha.length < 4 || linha.length > 60) return false;
    if (_regexCnpj.hasMatch(linha)) return false;
    if (_regexData.hasMatch(linha)) return false;
    if (_regexValor.hasMatch(linha)) return false;
    final letras = linha.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letras.length < 4) return false;
    final upper = _maiusculaSemAcento(linha);
    if (_linhaIgnorada.hasMatch(upper)) return false;
    if (_rotuloDeEndereco.hasMatch(upper)) return false;
    if (_prefixosEndereco.any(upper.startsWith)) return false;
    if (_ehCidade(upper)) return false;
    if (_palavraDeCabecalho
            .allMatches(upper)
            .map((m) => m.group(1))
            .toSet()
            .length >=
        2) {
      return false;
    }
    return _legivel(linha);
  }

  static bool _ehCidade(String upper) {
    final m = _cidadeUf.firstMatch(upper.trim());
    return m != null &&
        _ufs.contains(m.group(2)) &&
        !_palavraEmpresa.hasMatch(m.group(1)!);
  }

  static const Set<String> _conectivos = {
    'DE',
    'DO',
    'DA',
    'DOS',
    'DAS',
    'E',
  };

  /// Texto que parece escrito, e não ruído de manuscrito mal lido: poucos
  /// pedaços misturando letra e dígito ("1Om", "3sc"), poucas "palavras"
  /// sem vogal ("CMNT") e não só fragmentos de uma ou duas letras.
  static bool _legivel(String linha) {
    final palavras = RegExp(r'[A-Za-zÀ-ÿ0-9]+')
        .allMatches(_maiusculaSemAcento(linha))
        .map((m) => m.group(0)!)
        .toList();
    if (palavras.isEmpty) return false;
    var ruins = 0;
    var curtas = 0;
    var comLetra = 0;
    for (final p in palavras) {
      final temLetra = RegExp(r'[A-Z]').hasMatch(p);
      if (!temLetra) continue;
      comLetra++;
      if (RegExp(r'\d').hasMatch(p)) {
        ruins++;
      } else if (p.length >= 3 && !RegExp('[AEIOUY]').hasMatch(p)) {
        ruins++;
      } else if (p.length <= 2 && !_conectivos.contains(p)) {
        curtas++;
      }
    }
    if (comLetra == 0) return false;
    return ruins * 3 <= palavras.length && curtas * 3 <= comLetra * 2;
  }

  static const Set<String> _minusculasNoNome = {
    'de',
    'do',
    'da',
    'dos',
    'das',
    'e',
  };

  static String _capitalizar(String s) => s
      .toLowerCase()
      .split(' ')
      .map((p) => p.isEmpty || _minusculasNoNome.contains(p)
          ? p
          : p[0].toUpperCase() + p.substring(1))
      .join(' ')
      .trim();
}

/// Uma linha que o parser percorre — do texto corrido (sem geometria) ou
/// remontada pela posição na foto (com os trechos de onde veio).
class _Linha {
  /// O texto com os números já corrigidos.
  final String texto;

  /// [texto] em maiúsculas sem acento, com as mesmas posições.
  final String chave;

  /// De onde veio cada pedaço de [texto]; vazio sem geometria.
  final List<_Trecho> trechos;

  _Linha(this.texto, {this.trechos = const []})
      : chave = OcrNotaService._maiusculaSemAcento(texto);

  bool get temGeometria => trechos.isNotEmpty;

  late final List<_Rotulo> rotulos = OcrNotaService._rotulosDe(chave,
      inicios: [for (final t in trechos) t.inicio]);
  late final List<_Valor> valores = OcrNotaService._valoresDe(texto);

  double get topo => trechos.map((t) => t.caixa.topo).reduce(_menor);
  double get base => trechos.map((t) => t.caixa.base).reduce(_maior);

  /// O rótulo que vem logo antes do valor na linha — é dele o número.
  _Rotulo? donoDe(_Valor valor) =>
      rotulos.where((r) => r.fim <= valor.inicio).lastOrNull;

  /// Valores entre o rótulo e o próximo rótulo da linha.
  Iterable<_Valor> valoresDe(_Rotulo rotulo) {
    final proximo =
        rotulos.where((r) => r.inicio >= rotulo.fim).firstOrNull?.inicio ??
            texto.length;
    return valores.where((v) => v.inicio >= rotulo.fim && v.fim <= proximo);
  }

  /// Rótulos sem número ao lado na própria linha — os que esperam o valor
  /// embaixo (fileira de campos do DANFE, rótulo sozinho na linha).
  List<_Rotulo> get rotulosSemValor =>
      rotulos.where((r) => valoresDe(r).isEmpty).toList();

  /// Os livres que podem ser o valor de um rótulo de outra linha: número
  /// solto sem centavos nem R\$ ("2", "5") numa linha só sua é contagem
  /// de itens ou quantidade da coluna ao lado — era assim que o total da
  /// nota em duas colunas saía 5,00.
  List<_Valor> get valoresParaVizinho =>
      valoresLivres.where((v) => v.tipo < _Valor.inteiro).toList();

  /// Valores que nenhum rótulo da linha reivindica.
  List<_Valor> get valoresLivres =>
      valores.where((v) => donoDe(v) == null).toList();

  _Trecho? trechoEm(int posicao) =>
      trechos
          .where((t) => posicao >= t.inicio && posicao < t.fim)
          .firstOrNull ??
      trechos.where((t) => t.inicio <= posicao).lastOrNull;

  /// Posição horizontal aproximada de um caractere na foto, pela fração
  /// do trecho em que ele está — o ML Kit só dá a caixa da linha inteira.
  double xDe(int posicao) {
    final t = trechoEm(posicao);
    if (t == null) return 0;
    final fracao = t.fim == t.inicio
        ? 0.0
        : ((posicao - t.inicio) / (t.fim - t.inicio)).clamp(0.0, 1.0);
    return t.caixa.esquerda + fracao * t.caixa.largura;
  }

  double centroDe(_Valor v) => (xDe(v.inicio) + xDe(v.fim - 1)) / 2;

  static double _menor(double a, double b) => a < b ? a : b;
  static double _maior(double a, double b) => a > b ? a : b;
}

/// A faixa horizontal de um rótulo numa linha de rótulos lado a lado
/// ("VALOR DO FRETE | VALOR DO SEGURO | VALOR TOTAL DA NOTA"): começa no
/// rótulo e vai até o começo do rótulo ou trecho de texto seguinte. O valor
/// impresso embaixo pertence à célula em que cai.
class _Celula {
  final double esquerda;
  final double direita;

  /// A primeira célula da linha também fica com o que está à esquerda
  /// dela (valor que começa um pouco antes do rótulo).
  final bool primeira;

  const _Celula(this.esquerda, this.direita, {required this.primeira});

  factory _Celula.doRotulo(_Linha linha, _Rotulo rotulo) {
    final inicios = <double>{
      for (final t in linha.trechos)
        if (OcrNotaService._temLetra
            .hasMatch(linha.texto.substring(t.inicio, t.fim)))
          t.caixa.esquerda,
      for (final r in linha.rotulos) linha.xDe(r.inicio),
    }.toList()
      ..sort();
    final esquerda = linha.xDe(rotulo.inicio);
    return _Celula(
      esquerda,
      inicios.firstWhere((x) => x > esquerda + 1,
          orElse: () => double.infinity),
      primeira: inicios.isEmpty || esquerda <= inicios.first + 1,
    );
  }

  bool contem(double x) => x < direita && (x >= esquerda - 1 || primeira);
}

class _Trecho {
  final int inicio;
  final int fim;
  final LinhaOcr caixa;

  const _Trecho(this.inicio, this.fim, this.caixa);
}

class _Rotulo {
  final int inicio;
  final int fim;

  /// 0 (mais forte) a 3; -1 para rótulo que nunca é o total.
  final int nivel;

  const _Rotulo(this.inicio, this.fim, this.nivel);
}

class _Valor {
  static const int virgula = 0;
  static const int ponto = 1;
  static const int inteiroComRs = 2;
  static const int inteiro = 3;

  final int inicio;
  final int fim;
  final double valor;

  /// Confiança na leitura: vírgula decimal (0) a inteiro solto (3).
  final int tipo;

  const _Valor(this.inicio, this.fim, this.valor, this.tipo);
}

class _CandidatoCnpj {
  final String digitos;
  final int ordem;

  /// Rotulado como de destinatário, contador, software house...
  final bool terceiro;

  /// Rotulado como do emitente ("EMITENTE ... CNPJ").
  final bool emitente;

  const _CandidatoCnpj(this.digitos, this.ordem,
      {this.terceiro = false, this.emitente = false});
}
