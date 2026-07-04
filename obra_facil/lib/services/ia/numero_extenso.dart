/// Converte números falados por extenso (pt-BR) em dígitos.
///
/// O reconhecedor de voz do Android costuma transcrever valores como
/// palavras ("trezentos e cinquenta reais"). Este normalizador reescreve
/// o texto com dígitos ("350 reais") antes dos parsers de valor e de
/// materiais — é o que faz a IA de voz entender qualquer jeito de falar.
abstract class NumeroExtenso {
  static const Map<String, int> _unidades = {
    'zero': 0, 'um': 1, 'uma': 1, 'dois': 2, 'duas': 2,
    'tres': 3, 'três': 3, 'quatro': 4, 'cinco': 5, 'seis': 6,
    'sete': 7, 'oito': 8, 'nove': 9, 'dez': 10, 'onze': 11,
    'doze': 12, 'treze': 13, 'catorze': 14, 'quatorze': 14,
    'quinze': 15, 'dezesseis': 16, 'dezessete': 17, 'dezoito': 18,
    'dezenove': 19,
  };

  static const Map<String, int> _dezenas = {
    'vinte': 20, 'trinta': 30, 'quarenta': 40, 'cinquenta': 50,
    'sessenta': 60, 'setenta': 70, 'oitenta': 80, 'noventa': 90,
  };

  static const Map<String, int> _centenas = {
    'cem': 100, 'cento': 100,
    'duzentos': 200, 'duzentas': 200,
    'trezentos': 300, 'trezentas': 300,
    'quatrocentos': 400, 'quatrocentas': 400,
    'quinhentos': 500, 'quinhentas': 500,
    'seiscentos': 600, 'seiscentas': 600,
    'setecentos': 700, 'setecentas': 700,
    'oitocentos': 800, 'oitocentas': 800,
    'novecentos': 900, 'novecentas': 900,
  };

  /// Reescreve todo número por extenso do texto como dígitos.
  static String normalizar(String texto) {
    final tokens = texto.split(RegExp(r'\s+'));
    final saida = <String>[];
    var i = 0;
    while (i < tokens.length) {
      final numero = _lerNumero(tokens, i);
      if (numero != null) {
        saida.add(numero.$1.toString());
        i = numero.$2;
      } else {
        saida.add(tokens[i]);
        i++;
      }
    }
    return saida.join(' ');
  }

  static bool _ehPalavraNumero(String w) =>
      _unidades.containsKey(w) ||
      _dezenas.containsKey(w) ||
      _centenas.containsKey(w) ||
      w == 'mil';

  static String _limpa(String token) =>
      token.toLowerCase().replaceAll(RegExp(r'[^\wà-ÿ]'), '');

  /// Lê uma sequência de palavras-número a partir de [inicio].
  /// Retorna (valor, índice seguinte) ou null se não houver número ali.
  static (int, int)? _lerNumero(List<String> tokens, int inicio) {
    var i = inicio;
    var total = 0;
    var corrente = 0;
    var achou = false;

    while (i < tokens.length) {
      final w = _limpa(tokens[i]);
      // "e" só faz parte do número entre duas palavras-número
      // ("trezentos E cinquenta"), nunca no começo.
      if (w == 'e' &&
          achou &&
          i + 1 < tokens.length &&
          _ehPalavraNumero(_limpa(tokens[i + 1]))) {
        i++;
        continue;
      }
      if (w == 'mil') {
        total += (corrente == 0 ? 1 : corrente) * 1000;
        corrente = 0;
        achou = true;
        i++;
        continue;
      }
      if (_centenas.containsKey(w)) {
        corrente += _centenas[w]!;
        achou = true;
        i++;
        continue;
      }
      if (_dezenas.containsKey(w)) {
        corrente += _dezenas[w]!;
        achou = true;
        i++;
        continue;
      }
      if (_unidades.containsKey(w)) {
        corrente += _unidades[w]!;
        achou = true;
        i++;
        continue;
      }
      break;
    }

    if (!achou) return null;
    return (total + corrente, i);
  }
}
