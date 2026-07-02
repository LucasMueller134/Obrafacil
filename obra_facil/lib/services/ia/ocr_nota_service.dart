import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
}

/// IA on-device nº 2 — OCR de notas fiscais.
///
/// Usa o Google ML Kit Text Recognition (modelo TensorFlow Lite embarcado,
/// funciona 100% offline) para extrair o texto da foto, e um parser de
/// heurísticas/regex específico para o formato de cupons e notas brasileiras.
class OcrNotaService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<NotaFiscalExtraida> lerNota(String caminhoImagem) async {
    final input = InputImage.fromFilePath(caminhoImagem);
    final resultado = await _recognizer.processImage(input);
    return parsearTexto(resultado.text);
  }

  void dispose() => _recognizer.close();

  // ------------------------------------------------------------- Parser

  static final RegExp _regexCnpj =
      RegExp(r'\b\d{2}\.?\d{3}\.?\d{3}\s*/?\s*\d{4}\s*-?\s*\d{2}\b');
  static final RegExp _regexData =
      RegExp(r'\b(\d{2})/(\d{2})/(\d{2,4})\b');

  /// Valores monetários BR: 1.234,56 | 1234,56 | R$ 350,00
  static final RegExp _regexValor =
      RegExp(r'(?:R\$\s*)?(\d{1,3}(?:\.\d{3})+|\d+),(\d{2})\b');

  /// Palavras que indicam a linha do valor total do documento.
  static const List<String> _marcadoresTotal = [
    'TOTAL A PAGAR',
    'VALOR TOTAL',
    'VALOR A PAGAR',
    'TOTAL R\$',
    'VL TOTAL',
    'VL. TOTAL',
    'TOTAL',
  ];

  /// Parser puro (testável sem ML Kit): recebe o texto OCR cru e
  /// extrai fornecedor, CNPJ, total e data.
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
      // Nota com data futura provavelmente é leitura errada.
      if (data.isAfter(DateTime.now().add(const Duration(days: 1)))) continue;
      return data;
    }
    return null;
  }

  static double? _extrairTotal(List<String> linhas, String textoCompleto) {
    // 1º: procura valor na mesma linha (ou na seguinte) de um marcador de total.
    for (final marcador in _marcadoresTotal) {
      for (var i = 0; i < linhas.length; i++) {
        final linha = linhas[i].toUpperCase();
        if (!linha.contains(marcador)) continue;
        final naLinha = _valoresDa(linhas[i]);
        if (naLinha.isNotEmpty) return naLinha.last;
        if (i + 1 < linhas.length) {
          final naSeguinte = _valoresDa(linhas[i + 1]);
          if (naSeguinte.isNotEmpty) return naSeguinte.first;
        }
      }
    }
    // 2º: sem marcador, assume o maior valor monetário do documento
    // (numa nota, o total é normalmente o maior número impresso).
    final todos = _valoresDa(textoCompleto);
    if (todos.isEmpty) return null;
    todos.sort();
    return todos.last;
  }

  static List<double> _valoresDa(String texto) {
    return _regexValor.allMatches(texto).map((m) {
      final inteiro = m.group(1)!.replaceAll('.', '');
      return double.parse('$inteiro.${m.group(2)}');
    }).toList();
  }

  /// O nome do estabelecimento costuma ser uma das primeiras linhas,
  /// em caixa alta, sem ser CNPJ/endereço/data.
  static String? _extrairFornecedor(List<String> linhas) {
    for (final linha in linhas.take(5)) {
      if (linha.length < 4 || linha.length > 60) continue;
      if (_regexCnpj.hasMatch(linha)) continue;
      if (_regexData.hasMatch(linha)) continue;
      if (_regexValor.hasMatch(linha)) continue;
      final letras = linha.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
      if (letras.length < 4) continue;
      final upper = linha.toUpperCase();
      if (upper.contains('CUPOM') ||
          upper.contains('NOTA FISCAL') ||
          upper.contains('DANFE') ||
          upper.contains('SAT') ||
          upper.contains('EXTRATO')) {
        continue;
      }
      return _capitalizar(linha);
    }
    return null;
  }

  static String _capitalizar(String s) => s
      .toLowerCase()
      .split(' ')
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join(' ');
}
