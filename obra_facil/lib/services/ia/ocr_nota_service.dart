import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import 'texto_br.dart';

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

  const NotaFiscalExtraida({
    this.fornecedorNome,
    this.cnpj,
    this.valorTotal,
    this.data,
    required this.textoCompleto,
    this.passes = 1,
  });

  bool get encontrouAlgo =>
      fornecedorNome != null || cnpj != null || valorTotal != null;

  bool get completa => fornecedorNome != null && valorTotal != null;

  /// Combina dois resultados, preferindo os campos do primeiro.
  NotaFiscalExtraida mesclar(NotaFiscalExtraida outra) => NotaFiscalExtraida(
        fornecedorNome: fornecedorNome ?? outra.fornecedorNome,
        cnpj: cnpj ?? outra.cnpj,
        valorTotal: valorTotal ?? outra.valorTotal,
        data: data ?? outra.data,
        textoCompleto: textoCompleto.length >= outra.textoCompleto.length
            ? textoCompleto
            : outra.textoCompleto,
        passes: passes + outra.passes,
      );
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
/// Usa o Google ML Kit Text Recognition (modelo TensorFlow Lite embarcado,
/// 100% offline) e um parser de heurísticas para notas brasileiras.
///
/// A leitura acontece em cascata: lê a foto original e, enquanto faltar
/// algum campo essencial, tenta de novo com a imagem realçada, binarizada
/// e — se quase nada foi lido — girada. Cada passe só acrescenta o que
/// ainda faltava, então uma foto ruim de um lado e boa do outro ainda
/// produz um resultado completo. Manuscrito continua sendo o limite do
/// modelo.
class OcrNotaService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<NotaFiscalExtraida> lerNota(String caminhoImagem) async {
    final textoOriginal = await _reconhecer(caminhoImagem);
    var resultado = parsearTexto(textoOriginal);
    if (resultado.completa) return resultado;

    // Texto quase vazio: a foto provavelmente está deitada — girar vem
    // antes de qualquer realce, porque realçar imagem de lado não adianta.
    final variantes = textoOriginal.trim().length < 25
        ? const [
            _Variante.girada90,
            _Variante.girada270,
            _Variante.realce,
            _Variante.binarizada,
          ]
        : const [_Variante.realce, _Variante.binarizada];

    for (final variante in variantes) {
      final caminho = await _gerarVariante(caminhoImagem, variante);
      if (caminho == null) continue;
      try {
        resultado = resultado.mesclar(parsearTexto(await _reconhecer(caminho)));
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

  Future<String> _reconhecer(String caminho) async {
    final resultado =
        await _recognizer.processImage(InputImage.fromFilePath(caminho));
    return resultado.text;
  }

  /// Gera a variação num isolate e devolve o caminho do arquivo temporário.
  static Future<String?> _gerarVariante(
      String caminho, _Variante variante) async {
    try {
      final bytes = await File(caminho).readAsBytes();
      final tratada = await Isolate.run(() => _tratar(bytes, variante));
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
        imagem = img.adjustColor(
            img.grayscale(_ampliar(imagem)),
            contrast: 1.35);
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

  void dispose() => _recognizer.close();

  // ------------------------------------------------------------- Parser

  static final RegExp _regexCnpj =
      RegExp(r'\b\d{2}\.?\d{3}\.?\d{3}\s*/?\s*\d{4}\s*-?\s*\d{2}\b');
  static final RegExp _regexData =
      RegExp(r'\b(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})\b');

  /// Valores monetários BR com centavos: 1.234,56 | 1234,56 | R$ 350,00
  static final RegExp _regexValor =
      RegExp(r'(?:R\$\s*)?(\d{1,3}(?:\.\d{3})+|\d+),(\d{2})(?![\d,])');

  /// O OCR troca a vírgula decimal por ponto em papel gasto ("350.00").
  /// Só vale sem separador de milhar junto, para não quebrar "1.234".
  /// As âncoras dos dois lados impedem que a data "05.06.26" vire R$ 6,26.
  static final RegExp _regexValorPonto =
      RegExp(r'(?<![\d.,])(?:R\$\s*)?(\d{1,6})\.(\d{2})(?![\d.,])');

  /// Valores inteiros com R$ explícito ("R$ 350"), comuns em nota de mão.
  static final RegExp _regexValorInteiroComRs =
      RegExp(r'R\$\s*(\d{1,3}(?:\.\d{3})+|\d+)(?![\d,])');

  /// Valores inteiros sem R$ — aceitos apenas em linhas com marcador de total.
  static final RegExp _regexValorInteiro =
      RegExp(r'(?<![:\d,])(\d{1,3}(?:\.\d{3})+|\d+)(?![\d,:])');

  /// Trecho numérico com letra no meio ("35O,OO", "1.2S0,00"): o OCR
  /// confunde O/0, S/5, I/1. É reescrito como número antes do parser.
  static final RegExp _numeroSujo = RegExp(
      r'(?<![A-Za-zÀ-ÿ])[\dOoIlSsBZzGT]{1,3}(?:\.[\dOoIlSsBZzGT]{3})*'
      r',[\dOoIlSsBZzGT]{2}(?![A-Za-zÀ-ÿ0-9])');

  static final RegExp _temLetra = RegExp(r'[A-Za-z]');

  /// Marcadores de total, do mais específico para o mais genérico —
  /// "TOTAL A PAGAR" vale mais que um "TOTAL" solto no meio do cupom.
  static const List<List<String>> _marcadoresTotal = [
    [
      'TOTAL A PAGAR',
      'VALOR A PAGAR',
      'VALOR TOTAL',
      'TOTAL DA NOTA',
      'TOTAL GERAL',
      'TOTAL LIQUIDO',
      'TOTAL LÍQUIDO',
      'VALOR LIQUIDO',
      'VALOR LÍQUIDO',
      'TOTAL DA COMPRA',
      'TOTAL DO PEDIDO',
    ],
    ['VL TOTAL', 'VL. TOTAL', 'TOTAL'],
    ['SUBTOTAL', 'SUB TOTAL', 'SUB-TOTAL', 'SOMA'],
  ];

  /// Linhas que contêm "total" mas cujo número não é o valor da compra:
  /// "TOTAL DE ITENS: 5" é contagem, "TROCO 12,00" é o que voltou.
  static const List<String> _marcadoresFalsos = [
    'TOTAL DE ITENS', 'TOTAL ITENS', 'TOTAL DE PECAS', 'TOTAL DE PEÇAS',
    'TOTAL DE VOLUMES', 'QTD TOTAL', 'QUANTIDADE TOTAL', 'ITENS:',
    'TROCO', 'DESCONTO', 'ACRESCIMO', 'ACRÉSCIMO', 'ECONOMIA',
    'TOTAL DE TRIBUTOS', 'TRIBUTOS', 'IMPOSTO', 'FRETE',
  ];

  /// Rótulos que antecedem a data de emissão.
  static const List<String> _rotulosData = [
    'EMISSAO', 'EMITIDA', 'DATA', 'DT ', 'DT.', 'VENDA EM',
  ];

  /// Rótulos que antecedem o nome do estabelecimento.
  static final RegExp _rotuloFornecedor = RegExp(
      r'^(raz[aã]o social|nome fantasia|emitente|empresa|fornecedor|loja)'
      r'\s*[:\-]\s*',
      caseSensitive: false);

  /// Palavras que indicam fortemente um nome de empresa.
  static const List<String> _palavrasEmpresa = [
    'LTDA', 'EIRELI', ' EPP', ' ME', ' MEI', 'S/A', ' SA ',
    'COMERCIO', 'COMÉRCIO', 'COMERCIAL',
    'MATERIAIS', 'MATERIAL', 'DEPOSITO', 'DEPÓSITO',
    'CONSTRUCAO', 'CONSTRUÇÃO', 'CONSTRUCOES', 'CONSTRUÇÕES',
    'MADEIREIRA', 'FERRAGENS', 'FERRAGEM', 'ATACADO', 'ATACADAO',
    'MERCADO', 'LOJA', 'CASA DO', 'AGROPECUARIA', 'AGROPECUÁRIA',
    'TINTAS', 'ELETRICA', 'ELÉTRICA', 'HIDRAULICA', 'HIDRÁULICA',
    'DISTRIBUIDORA', 'INDUSTRIA', 'INDÚSTRIA', 'SERRALHERIA',
    'VIDRACARIA', 'VIDRAÇARIA', 'MARMORARIA',
  ];

  /// Redes de material de construção: quando aparecem, são o fornecedor.
  static const List<String> _redesConhecidas = [
    'LEROY MERLIN', 'TELHANORTE', 'OBRAMAX', 'CASSOL', 'BALAROTI',
    'TUMELERO', 'CHATUBA', 'DICICO', 'SODIMAC', 'FERREIRA COSTA',
    'TENDA ATACADO', 'HOMECENTER', 'HOME CENTER', 'CONSTRUFACIL',
  ];

  /// Linhas que nunca são o nome do fornecedor.
  static const List<String> _linhasIgnoradas = [
    'CUPOM', 'NOTA FISCAL', 'DANFE', 'SAT', 'EXTRATO', 'DOCUMENTO',
    'AUXILIAR', 'CNPJ', 'INSCR', 'I.E', 'IE:', 'CEP', 'TEL', 'FONE',
    'CAIXA', 'PDV', 'OPERADOR', 'VENDEDOR', 'CLIENTE', 'CONSUMIDOR',
    'ITEM', 'QTD', 'DESCRICAO', 'DESCRIÇÃO', 'ORCAMENTO', 'ORÇAMENTO',
    'PEDIDO', 'RECIBO', 'CHAVE DE ACESSO', 'PROTOCOLO', 'AUTORIZACAO',
    'AUTORIZAÇÃO', 'CONSULTE PELA', 'WWW.', 'HTTP', 'OBRIGADO',
    'VOLTE SEMPRE', 'SEM VALOR FISCAL',
  ];

  static const List<String> _prefixosEndereco = [
    'RUA ', 'R. ', 'AV ', 'AV. ', 'AVENIDA', 'ROD ', 'ROD. ', 'RODOVIA',
    'ESTRADA', 'TRAVESSA', 'ALAMEDA', 'PRACA', 'PRAÇA', 'BAIRRO',
    'LOTE ', 'QUADRA',
  ];

  /// Parser puro (testável sem ML Kit).
  static NotaFiscalExtraida parsearTexto(String texto) {
    final limpo = _corrigirNumeros(texto);
    final linhas = limpo
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return NotaFiscalExtraida(
      fornecedorNome: _extrairFornecedor(linhas),
      cnpj: _extrairCnpj(limpo),
      valorTotal: _extrairTotal(linhas, limpo),
      data: _extrairData(linhas),
      // O texto devolvido é o original: quem for conferir na tela precisa
      // ver o que o OCR leu, não a nossa correção.
      textoCompleto: texto,
    );
  }

  /// Reescreve como número os trechos em que o OCR trocou dígito por
  /// letra ("35O,OO" → "350,00").
  static String _corrigirNumeros(String texto) =>
      texto.replaceAllMapped(_numeroSujo, (m) {
        final trecho = m.group(0)!;
        // sem letra no meio já é número — mexer só arriscaria estragar
        return _temLetra.hasMatch(trecho)
            ? TextoBr.corrigirDigitos(trecho)
            : trecho;
      });

  static String? _extrairCnpj(String texto) {
    String? primeiro;
    for (final m in _regexCnpj.allMatches(texto)) {
      final digitos = m.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digitos.length != 14) continue;
      primeiro ??= _formatarCnpj(digitos);
      // Uma nota traz vários CNPJ (emitente, contador, software). O
      // primeiro válido é quase sempre o do emitente; um inválido é
      // dígito lido errado e não deveria virar cadastro de fornecedor.
      if (cnpjValido(digitos)) return _formatarCnpj(digitos);
    }
    return primeiro;
  }

  static String _formatarCnpj(String d) =>
      '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/'
      '${d.substring(8, 12)}-${d.substring(12)}';

  /// Confere os dois dígitos verificadores do CNPJ.
  static bool cnpjValido(String digitos) {
    if (digitos.length != 14) return false;
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

  /// Data de emissão. Uma nota traz várias datas (vencimento, impressão,
  /// validade do certificado): pontua as candidatas em vez de ficar com a
  /// primeira que aparecer.
  static DateTime? _extrairData(List<String> linhas) {
    DateTime? melhor;
    var melhorPontos = -1;

    for (final linha in linhas) {
      final upper = TextoBr.normalizar(linha).toUpperCase();
      for (final m in _regexData.allMatches(linha)) {
        final data = _montarData(m);
        if (data == null) continue;

        var pontos = 0;
        final antes = upper.substring(0, m.start.clamp(0, upper.length));
        if (_rotulosData
            .any((r) => antes.contains(TextoBr.normalizar(r).toUpperCase()))) {
          pontos += 3;
        }
        // a data de emissão costuma vir acompanhada da hora
        if (RegExp(r'^\s*\d{1,2}:\d{2}').hasMatch(linha.substring(m.end))) {
          pontos += 2;
        }
        if (upper.contains('VENCIMENTO') || upper.contains('VALIDADE')) {
          pontos -= 3;
        }
        if (pontos > melhorPontos) {
          melhorPontos = pontos;
          melhor = data;
        }
      }
    }
    return melhor;
  }

  static DateTime? _montarData(RegExpMatch m) {
    final dia = int.parse(m.group(1)!);
    final mes = int.parse(m.group(2)!);
    var ano = int.parse(m.group(3)!);
    if (ano < 100) ano += 2000;
    if (dia < 1 || dia > 31 || mes < 1 || mes > 12) return null;
    if (ano < 2000 || ano > DateTime.now().year + 1) return null;
    final data = DateTime(ano, mes, dia);
    if (data.day != dia || data.month != mes) return null; // 31/02
    if (data.isAfter(DateTime.now().add(const Duration(days: 1)))) return null;
    return data;
  }

  static double? _extrairTotal(List<String> linhas, String textoCompleto) {
    // 1º: marcador de total, do mais específico para o mais genérico.
    for (final grupo in _marcadoresTotal) {
      final achado = _totalPorMarcadores(linhas, grupo);
      if (achado != null) return achado;
    }
    // 2º: maior valor com centavos do documento.
    final decimais = _valoresDa(textoCompleto);
    if (decimais.isNotEmpty) {
      decimais.sort();
      return decimais.last;
    }
    // 3º: nota informal sem centavos — maior valor inteiro com R$ explícito.
    final inteiros = _regexValorInteiroComRs
        .allMatches(textoCompleto)
        .map((m) => double.parse(m.group(1)!.replaceAll('.', '')))
        .where(_valorPlausivel)
        .toList();
    if (inteiros.isEmpty) return null;
    inteiros.sort();
    return inteiros.last;
  }

  static double? _totalPorMarcadores(
      List<String> linhas, List<String> marcadores) {
    for (var i = 0; i < linhas.length; i++) {
      final linha = linhas[i].toUpperCase();
      if (_marcadoresFalsos.any((m) => _contemMarcador(linha, m))) continue;
      if (!marcadores.any((m) => _contemMarcador(linha, m))) continue;

      final naLinha = _valoresDa(linhas[i], aceitarInteiros: true);
      if (naLinha.isNotEmpty) return naLinha.last;
      // rótulo e valor em linhas separadas (layout de duas colunas)
      if (i + 1 < linhas.length) {
        final seguinte = _valoresDa(linhas[i + 1], aceitarInteiros: true);
        if (seguinte.isNotEmpty) return seguinte.first;
      }
      if (i > 0) {
        final anterior = _valoresDa(linhas[i - 1], aceitarInteiros: true);
        if (anterior.isNotEmpty) return anterior.last;
      }
    }
    return null;
  }

  /// Marcador tem de ser palavra inteira: senão o "TOTAL" dentro de
  /// "SUBTOTAL" faria o subtotal passar por total da compra.
  static bool _contemMarcador(String linha, String marcador) {
    var i = linha.indexOf(marcador);
    while (i != -1) {
      final fim = i + marcador.length;
      if (!_ehLetra(linha, i - 1) && !_ehLetra(linha, fim)) return true;
      i = linha.indexOf(marcador, i + 1);
    }
    return false;
  }

  static bool _ehLetra(String texto, int posicao) {
    if (posicao < 0 || posicao >= texto.length) return false;
    final code = texto.codeUnitAt(posicao);
    return (code >= 65 && code <= 90) || (code >= 192 && code <= 221);
  }

  static bool _valorPlausivel(double v) => v > 0 && v < 10000000;

  static List<double> _valoresDa(String texto, {bool aceitarInteiros = false}) {
    final valores = _regexValor
        .allMatches(texto)
        .map((m) =>
            double.parse('${m.group(1)!.replaceAll('.', '')}.${m.group(2)}'))
        .where(_valorPlausivel)
        .toList();

    if (valores.isEmpty) {
      // vírgula decimal lida como ponto ("350.00")
      valores.addAll(_regexValorPonto
          .allMatches(texto)
          .map((m) => double.parse('${m.group(1)}.${m.group(2)}'))
          .where(_valorPlausivel));
    }
    if (valores.isEmpty && aceitarInteiros) {
      valores.addAll(_regexValorInteiro
          .allMatches(texto)
          .map((m) => double.parse(m.group(1)!.replaceAll('.', '')))
          .where(_valorPlausivel));
    }
    return valores;
  }

  // ------------------------------------------------------------ Fornecedor

  static String? _extrairFornecedor(List<String> linhas) {
    final candidatas = linhas.take(15).toList();

    // 1º: rede conhecida em qualquer lugar do topo da nota.
    for (final linha in candidatas) {
      final upper = TextoBr.normalizar(linha).toUpperCase();
      for (final rede in _redesConhecidas) {
        if (upper.contains(TextoBr.normalizar(rede).toUpperCase())) {
          return _capitalizar(rede);
        }
      }
    }

    // 2º: rótulo explícito ("Razão Social: ...").
    for (final linha in candidatas) {
      final m = _rotuloFornecedor.firstMatch(linha);
      if (m != null) {
        final nome = _limparNome(linha.substring(m.end));
        if (nome.length >= 3) return _capitalizar(nome);
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
      final upper = linha.toUpperCase();
      if (_palavrasEmpresa.any(upper.contains)) pontos += 4;
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
      // Exige pelo menos 1 ponto para não confundir linha de produto
      // ("CIMENTO CP-II 50KG") com o nome do estabelecimento.
      if (pontos >= 1 && pontos > melhorPontos) {
        melhorPontos = pontos;
        melhor = linha;
      }
    }
    if (melhor != null) return _capitalizar(melhor);

    // 4º: linha imediatamente acima do CNPJ (razão social vem antes).
    for (var i = 1; i < linhas.length; i++) {
      if (_regexCnpj.hasMatch(linhas[i]) && _podeSerFornecedor(linhas[i - 1])) {
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
    final upper = linha.toUpperCase();
    if (_linhasIgnoradas.any(upper.contains)) return false;
    if (_prefixosEndereco.any(upper.startsWith)) return false;
    return true;
  }

  static const Set<String> _minusculasNoNome = {
    'de', 'do', 'da', 'dos', 'das', 'e',
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
