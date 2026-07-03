import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

/// Dados extraídos de uma nota fiscal / cupom fiscal fotografado.
class NotaFiscalExtraida {
  final String? fornecedorNome;
  final String? cnpj;
  final double? valorTotal;
  final DateTime? data;
  final String textoCompleto;

  const NotaFiscalExtraida({
    this.fornecedorNome,
    this.cnpj,
    this.valorTotal,
    this.data,
    required this.textoCompleto,
  });

  bool get encontrouAlgo =>
      fornecedorNome != null || cnpj != null || valorTotal != null;

  bool get completa =>
      fornecedorNome != null && valorTotal != null;

  /// Combina dois resultados, preferindo os campos do primeiro.
  NotaFiscalExtraida mesclar(NotaFiscalExtraida outra) => NotaFiscalExtraida(
        fornecedorNome: fornecedorNome ?? outra.fornecedorNome,
        cnpj: cnpj ?? outra.cnpj,
        valorTotal: valorTotal ?? outra.valorTotal,
        data: data ?? outra.data,
        textoCompleto: textoCompleto.length >= outra.textoCompleto.length
            ? textoCompleto
            : outra.textoCompleto,
      );
}

/// IA on-device nº 2 — OCR de notas fiscais.
///
/// Usa o Google ML Kit Text Recognition (modelo TensorFlow Lite embarcado,
/// 100% offline) e um parser de heurísticas para notas brasileiras.
///
/// Estratégia em dois passes: se a leitura da foto original não encontrar
/// os dados principais, a imagem é realçada (escala de cinza + contraste +
/// ampliação) e lida de novo — ajuda em notas apagadas, amassadas ou
/// fotografadas com pouca luz. Manuscrito continua sendo o limite do
/// modelo, mas o realce recupera muitos casos de impressão fraca.
class OcrNotaService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<NotaFiscalExtraida> lerNota(String caminhoImagem) async {
    final passe1 = parsearTexto(await _reconhecer(caminhoImagem));
    if (passe1.completa) return passe1;

    // 2º passe com imagem realçada.
    final caminhoRealce = await _gerarImagemRealcada(caminhoImagem);
    if (caminhoRealce == null) return passe1;
    try {
      final passe2 = parsearTexto(await _reconhecer(caminhoRealce));
      return passe1.mesclar(passe2);
    } finally {
      try {
        await File(caminhoRealce).delete();
      } catch (_) {}
    }
  }

  Future<String> _reconhecer(String caminho) async {
    final resultado =
        await _recognizer.processImage(InputImage.fromFilePath(caminho));
    return resultado.text;
  }

  /// Escala de cinza + contraste + ampliação, num isolate.
  static Future<String?> _gerarImagemRealcada(String caminho) async {
    try {
      final bytes = await File(caminho).readAsBytes();
      final realcada = await Isolate.run(() => _realcar(bytes));
      if (realcada == null) return null;
      final destino = '$caminho.realce.jpg';
      await File(destino).writeAsBytes(realcada);
      return destino;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _realcar(Uint8List bytes) {
    final original = img.decodeImage(bytes);
    if (original == null) return null;
    var imagem = original;
    if (imagem.width < 1400) {
      imagem = img.copyResize(imagem, width: 1600);
    }
    imagem = img.grayscale(imagem);
    imagem = img.adjustColor(imagem, contrast: 1.35);
    return Uint8List.fromList(img.encodeJpg(imagem, quality: 95));
  }

  void dispose() => _recognizer.close();

  // ------------------------------------------------------------- Parser

  static final RegExp _regexCnpj =
      RegExp(r'\b\d{2}\.?\d{3}\.?\d{3}\s*/?\s*\d{4}\s*-?\s*\d{2}\b');
  static final RegExp _regexData =
      RegExp(r'\b(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})\b');

  /// Valores monetários BR com centavos: 1.234,56 | 1234,56 | R$ 350,00
  static final RegExp _regexValor =
      RegExp(r'(?:R\$\s*)?(\d{1,3}(?:\.\d{3})+|\d+),(\d{2})\b');

  /// Valores inteiros com R$ explícito ("R$ 350"), comuns em nota de mão.
  static final RegExp _regexValorInteiroComRs =
      RegExp(r'R\$\s*(\d{1,3}(?:\.\d{3})+|\d+)(?![\d,])');

  /// Valores inteiros sem R$ — aceitos apenas em linhas com marcador de total.
  static final RegExp _regexValorInteiro =
      RegExp(r'(?<![:\d,])(\d{1,3}(?:\.\d{3})+|\d+)(?![\d,:])');

  static const List<String> _marcadoresTotal = [
    'TOTAL A PAGAR',
    'VALOR TOTAL',
    'VALOR A PAGAR',
    'TOTAL R\$',
    'VL TOTAL',
    'VL. TOTAL',
    'TOTAL',
  ];

  /// Rótulos que antecedem o nome do estabelecimento.
  static final RegExp _rotuloFornecedor = RegExp(
      r'^(raz[aã]o social|nome fantasia|emitente|empresa|fornecedor)\s*[:\-]\s*',
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
  ];

  /// Linhas que nunca são o nome do fornecedor.
  static const List<String> _linhasIgnoradas = [
    'CUPOM', 'NOTA FISCAL', 'DANFE', 'SAT', 'EXTRATO', 'DOCUMENTO',
    'AUXILIAR', 'CNPJ', 'INSCR', 'I.E', 'IE:', 'CEP', 'TEL', 'FONE',
    'CAIXA', 'PDV', 'OPERADOR', 'VENDEDOR', 'CLIENTE', 'CONSUMIDOR',
    'ITEM', 'QTD', 'DESCRICAO', 'DESCRIÇÃO', 'ORCAMENTO', 'ORÇAMENTO',
    'PEDIDO', 'RECIBO',
  ];

  static const List<String> _prefixosEndereco = [
    'RUA ', 'R. ', 'AV ', 'AV. ', 'AVENIDA', 'ROD ', 'ROD. ', 'RODOVIA',
    'ESTRADA', 'TRAVESSA', 'ALAMEDA', 'PRACA', 'PRAÇA', 'BAIRRO',
  ];

  /// Parser puro (testável sem ML Kit).
  static NotaFiscalExtraida parsearTexto(String texto) {
    final linhas = texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return NotaFiscalExtraida(
      fornecedorNome: _extrairFornecedor(linhas),
      cnpj: _extrairCnpj(texto),
      valorTotal: _extrairTotal(linhas, texto),
      data: _extrairData(texto),
      textoCompleto: texto,
    );
  }

  static String? _extrairCnpj(String texto) {
    final m = _regexCnpj.firstMatch(texto);
    if (m == null) return null;
    final digitos = m.group(0)!.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 14) return null;
    return '${digitos.substring(0, 2)}.${digitos.substring(2, 5)}.'
        '${digitos.substring(5, 8)}/${digitos.substring(8, 12)}-'
        '${digitos.substring(12)}';
  }

  static DateTime? _extrairData(String texto) {
    for (final m in _regexData.allMatches(texto)) {
      final dia = int.parse(m.group(1)!);
      final mes = int.parse(m.group(2)!);
      var ano = int.parse(m.group(3)!);
      if (ano < 100) ano += 2000;
      if (dia < 1 || dia > 31 || mes < 1 || mes > 12) continue;
      if (ano < 2000 || ano > DateTime.now().year + 1) continue;
      final data = DateTime(ano, mes, dia);
      if (data.isAfter(DateTime.now().add(const Duration(days: 1)))) continue;
      return data;
    }
    return null;
  }

  static double? _extrairTotal(List<String> linhas, String textoCompleto) {
    // 1º: valor na mesma linha (ou na seguinte) de um marcador de total.
    for (final marcador in _marcadoresTotal) {
      for (var i = 0; i < linhas.length; i++) {
        final linha = linhas[i].toUpperCase();
        if (!linha.contains(marcador)) continue;
        final naLinha = _valoresDa(linhas[i], aceitarInteiros: true);
        if (naLinha.isNotEmpty) return naLinha.last;
        if (i + 1 < linhas.length) {
          final naSeguinte = _valoresDa(linhas[i + 1], aceitarInteiros: true);
          if (naSeguinte.isNotEmpty) return naSeguinte.first;
        }
      }
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
        .where((v) => v > 0 && v < 10000000)
        .toList();
    if (inteiros.isEmpty) return null;
    inteiros.sort();
    return inteiros.last;
  }

  static List<double> _valoresDa(String texto, {bool aceitarInteiros = false}) {
    final valores = _regexValor.allMatches(texto).map((m) {
      final inteiro = m.group(1)!.replaceAll('.', '');
      return double.parse('$inteiro.${m.group(2)}');
    }).toList();

    if (valores.isEmpty && aceitarInteiros) {
      valores.addAll(_regexValorInteiro
          .allMatches(texto)
          .map((m) => double.parse(m.group(1)!.replaceAll('.', '')))
          .where((v) => v > 0 && v < 10000000));
    }
    return valores;
  }

  // ------------------------------------------------- Fornecedor

  static String? _extrairFornecedor(List<String> linhas) {
    final candidatas = linhas.take(15).toList();

    // 1º: rótulo explícito ("Razão Social: ...").
    for (final linha in candidatas) {
      final m = _rotuloFornecedor.firstMatch(linha);
      if (m != null) {
        final nome = linha.substring(m.end).trim();
        if (nome.length >= 3) return _capitalizar(nome);
      }
    }

    // 2º: pontua as primeiras linhas válidas.
    String? melhor;
    var melhorPontos = -1;
    for (var i = 0; i < candidatas.length; i++) {
      final linha = candidatas[i];
      if (!_podeSerFornecedor(linha)) continue;

      var pontos = 0;
      final upper = linha.toUpperCase();
      if (_palavrasEmpresa.any(upper.contains)) pontos += 4;
      if (i <= 2) pontos += 2; // topo do documento
      // a razão social costuma vir colada ao CNPJ
      if (i + 1 < linhas.length && _regexCnpj.hasMatch(linhas[i + 1])) {
        pontos += 3;
      } else if (i + 2 < linhas.length &&
          _regexCnpj.hasMatch(linhas[i + 2])) {
        pontos += 2;
      }
      // caixa alta é típico de razão social impressa
      final letras = linha.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      if (letras.isNotEmpty &&
          letras == letras.toUpperCase() &&
          letras.length >= 5) {
        pontos += 1;
      }
      // Exige pelo menos 1 ponto para não confundir linha de produto
      // ("CIMENTO CP-II 50KG") com o nome do estabelecimento.
      if (pontos >= 1 && pontos > melhorPontos) {
        melhorPontos = pontos;
        melhor = linha;
      }
    }
    if (melhor != null) return _capitalizar(melhor);

    // 3º: linha imediatamente acima do CNPJ (razão social costuma vir antes).
    for (var i = 1; i < linhas.length; i++) {
      if (_regexCnpj.hasMatch(linhas[i]) &&
          _podeSerFornecedor(linhas[i - 1])) {
        return _capitalizar(linhas[i - 1]);
      }
    }
    return null;
  }

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

  static String _capitalizar(String s) => s
      .toLowerCase()
      .split(' ')
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join(' ');
}
