import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/hipoteses_voz.dart';

void main() {
  group('Hipótese cortada', () {
    test('termina em conector ou preposição', () {
      expect(HipotesesVoz.pareceCortada('paguei duzentos e'), isTrue);
      expect(HipotesesVoz.pareceCortada('comprei 10 sacos de'), isTrue);
      expect(HipotesesVoz.pareceCortada('paguei R\$'), isTrue);
      expect(HipotesesVoz.pareceCortada('custou trinta vírgula'), isTrue);
    });

    test('frase inteira não é cortada', () {
      expect(HipotesesVoz.pareceCortada('paguei duzentos e oitenta'), isFalse);
      expect(HipotesesVoz.pareceCortada('comprei cimento'), isFalse);
      expect(HipotesesVoz.pareceCortada(''), isFalse);
    });
  });

  group('Escolha entre hipóteses', () {
    // Parser de mentira: pontua pelo tamanho da frase, para isolar a regra
    // de escolha do que o parser real entende.
    String escolher(List<(String, double)> hipoteses) =>
        HipotesesVoz.escolher<String>(
          hipoteses,
          interpretar: (t) => t,
          pontuar: (r, _) => r.split(' ').length.toDouble(),
        );

    test('a 1ª fica quando ninguém é claramente melhor', () {
      expect(escolher([('a b c', 0.9), ('a b c d', 0.5)]), 'a b c');
    });

    test('outra vence com vantagem acima da margem', () {
      expect(escolher([('a b', 0.9), ('a b c d', 0.9)]), 'a b c d');
    });

    test('a confiança do reconhecedor entra na conta', () {
      // Mesma pontuação do parser: a confiança muito maior decide.
      expect(escolher([('a b', 0.1), ('c d', 0.9)]), 'c d');
      // Confiança indisponível (<= 0) não pesa contra nem a favor.
      expect(escolher([('a b', -1), ('c d', -1)]), 'a b');
    });

    test('confiança de um lado só não pesa', () {
      // O Android informa a da principal e manda 0 nas alternativas: a
      // comparação fica só no que o parser entendeu.
      expect(escolher([('a b', 0.9), ('a b c', 0)]), 'a b c');
      // ... e a alternativa com confiança contra a principal sem ela
      // também não ganha só por isso.
      expect(escolher([('a b', -1), ('c d', 0.9)]), 'a b');
    });

    test('hipóteses vazias são ignoradas', () {
      expect(escolher([('', 0.9), ('a b', 0.2)]), 'a b');
      expect(escolher([]), '');
    });
  });
}
