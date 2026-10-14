import 'texto_br.dart';

/// Escolhe entre as hipóteses do reconhecedor de voz.
///
/// O Android devolve até 10 transcrições alternativas, cada uma com a sua
/// confiança, e a primeira nem sempre é a melhor para a obra: com barulho
/// ela pode vir cortada ("paguei o aluguel da caçamba duzentos e") enquanto
/// uma alternativa ouviu a frase inteira ("…duzentos e oitenta"). Cada
/// hipótese é interpretada e pontuada pelo que o parser entende dela, mais
/// a confiança do reconhecedor.
///
/// A primeira só perde quando outra é claramente melhor: na dúvida, vale o
/// que o reconhecedor achou mais provável — trocar por uma alternativa
/// parecida só arriscaria um erro novo.
abstract class HipotesesVoz {
  /// Quanto a confiança do reconhecedor (0..1) pesa na pontuação.
  static const double pesoConfianca = 2;

  /// Desconto para a hipótese que termina no meio de uma frase.
  static const double penalidadeCortada = 2;

  /// Vantagem mínima para trocar a primeira hipótese por outra.
  static const double margem = 1;

  /// Palavras que não terminam uma frase falada inteira.
  static const Set<String> _finaisDeCorte = {
    'e',
    'de',
    'do',
    'da',
    'dos',
    'das',
    'por',
    'com',
    'o',
    'a',
    'os',
    'as',
    'no',
    'na',
    'nos',
    'nas',
    'em',
    'pra',
    'pro',
    'para',
    'um',
    'uma',
    'mais',
    'que',
    'ou',
    'r\$',
    'ao',
    'aos',
    'pelo',
    'pela',
    'vírgula',
    'virgula',
  };

  /// A hipótese parece ter sido cortada antes do fim ("…duzentos e").
  static bool pareceCortada(String texto) {
    final palavras = TextoBr.normalizar(texto.trim())
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (palavras.isEmpty) return false;
    final ultima = palavras.last.replaceAll(RegExp(r'[,;:]+$'), '');
    return _finaisDeCorte.contains(ultima);
  }

  /// Interpreta as [hipoteses] (texto, confiança — a primeira é a
  /// principal; confiança <= 0 quando o aparelho não informa) e devolve a
  /// interpretação da melhor. [pontuar] diz quanto o parser entendeu.
  ///
  /// A confiança só entra na comparação quando as duas hipóteses a têm. O
  /// Android costuma informar a da principal e mandar 0 nas alternativas:
  /// contar 0,9 contra "não sei" daria à principal uma vantagem que o
  /// reconhecedor nunca deu (e o contrário, à alternativa).
  static T escolher<T>(
    List<(String, double)> hipoteses, {
    required T Function(String texto) interpretar,
    required double Function(T resultado, String texto) pontuar,
  }) {
    final validas = [
      for (final h in hipoteses)
        if (h.$1.trim().isNotEmpty) h,
    ];
    if (validas.isEmpty) {
      return interpretar(hipoteses.isEmpty ? '' : hipoteses.first.$1);
    }

    double semConfianca((String, double) h, T r) =>
        pontuar(r, h.$1) - (pareceCortada(h.$1) ? penalidadeCortada : 0);
    double? confianca((String, double) h) =>
        h.$2 > 0 ? h.$2.clamp(0, 1).toDouble() : null;

    final principal = interpretar(validas.first.$1);
    final basePrincipal = semConfianca(validas.first, principal);
    final confiancaPrincipal = confianca(validas.first);
    var melhor = principal;
    var melhorVantagem = 0.0;
    for (final h in validas.skip(1)) {
      final r = interpretar(h.$1);
      var vantagem = semConfianca(h, r) - basePrincipal;
      final c = confianca(h);
      if (c != null && confiancaPrincipal != null) {
        vantagem += pesoConfianca * (c - confiancaPrincipal);
      }
      if (vantagem > melhorVantagem) {
        melhor = r;
        melhorVantagem = vantagem;
      }
    }
    return melhorVantagem >= margem ? melhor : principal;
  }
}
