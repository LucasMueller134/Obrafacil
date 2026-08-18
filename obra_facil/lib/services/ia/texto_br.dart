/// Normalização de texto em português — base comum das IAs do app.
///
/// Duas fontes de erro se repetiam nos parsers: acento (a transcrição de voz
/// escreve "diaria" tanto quanto "diária") e casamento por pedaço de palavra
/// (`'calçada'.contains('cal')` classificava calçada como o material cal).
/// Aqui o texto é comparado sem acento e sempre por palavra inteira,
/// aceitando o plural — que é como as pessoas realmente falam e escrevem.
abstract class TextoBr {
  static const String _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñýÿ';
  static const String _semAcento = 'aaaaaeeeeiiiiooooouuuucnyy';

  /// Minúsculas e sem acento — a forma em que os parsers comparam.
  static String normalizar(String texto) {
    final lower = texto.toLowerCase();
    final buffer = StringBuffer();
    for (final unidade in lower.runes) {
      final char = String.fromCharCode(unidade);
      final indice = _comAcento.indexOf(char);
      buffer.write(indice == -1 ? char : _semAcento[indice]);
    }
    return buffer.toString();
  }

  /// `true` se [termo] aparece em [texto] como palavra inteira, aceitando o
  /// plural em "s" ou "es". Ambos precisam vir de [normalizar].
  ///
  /// "comprei cal" casa com "cal"; "fizemos a calçada" não.
  static bool contemPalavra(String texto, String termo) {
    if (termo.isEmpty) return false;
    var i = texto.indexOf(termo);
    while (i != -1) {
      if (_fronteiraAntes(texto, i) &&
          _fronteiraDepois(texto, i + termo.length)) {
        return true;
      }
      i = texto.indexOf(termo, i + 1);
    }
    return false;
  }

  /// Quantos dos [termos] aparecem no [texto] como palavra inteira.
  static int quantosCasam(String texto, Iterable<String> termos) =>
      termos.where((t) => contemPalavra(texto, t)).length;

  /// O primeiro dos [termos] que aparece no [texto], ou null.
  static String? primeiroQueCasa(String texto, Iterable<String> termos) {
    for (final termo in termos) {
      if (contemPalavra(texto, termo)) return termo;
    }
    return null;
  }

  static bool _fronteiraAntes(String texto, int inicio) =>
      inicio == 0 || !_ehLetraOuDigito(texto.codeUnitAt(inicio - 1));

  /// Aceita o fim da palavra, o plural ("sacos", "canais") e a pontuação.
  static bool _fronteiraDepois(String texto, int fim) {
    if (fim >= texto.length) return true;
    if (!_ehLetraOuDigito(texto.codeUnitAt(fim))) return true;
    // plural: "s" ou "es" seguido de fronteira
    if (texto[fim] == 's') return _fronteiraDepois(texto, fim + 1);
    if (texto[fim] == 'e' && fim + 1 < texto.length && texto[fim + 1] == 's') {
      return fim + 2 >= texto.length ||
          !_ehLetraOuDigito(texto.codeUnitAt(fim + 2));
    }
    return false;
  }

  static bool _ehLetraOuDigito(int code) {
    // a-z, 0-9 e as letras acentuadas que sobrevivem a uma normalização parcial
    return (code >= 97 && code <= 122) ||
        (code >= 48 && code <= 57) ||
        (code >= 192 && code <= 255);
  }

  /// Corrige as letras que o OCR troca por dígito em campos numéricos.
  ///
  /// "R$ 35O,OO" vira "R$ 350,00". Só deve ser aplicado a trechos que já se
  /// sabe serem números — em texto comum destruiria palavras.
  static String corrigirDigitos(String trecho) {
    const trocas = {
      'O': '0', 'o': '0', 'D': '0', 'Q': '0',
      'I': '1', 'l': '1', '|': '1',
      'S': '5', 's': '5',
      'B': '8',
      'Z': '2', 'z': '2',
      'G': '6',
      'T': '7',
    };
    final buffer = StringBuffer();
    for (final char in trecho.split('')) {
      buffer.write(trocas[char] ?? char);
    }
    return buffer.toString();
  }
}
