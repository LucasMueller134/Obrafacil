import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/numero_extenso.dart';

void main() {
  group('Números por extenso (pt-BR) → dígitos', () {
    test('centenas compostas', () {
      expect(NumeroExtenso.normalizar('trezentos e cinquenta reais'),
          '350 reais');
    });

    test('milhares', () {
      expect(NumeroExtenso.normalizar('mil e duzentos'), '1200');
      expect(
          NumeroExtenso.normalizar('dois mil quinhentos e trinta e cinco'),
          '2535');
    });

    test('cem e cento', () {
      expect(NumeroExtenso.normalizar('cem reais'), '100 reais');
      expect(NumeroExtenso.normalizar('cento e vinte tijolos'),
          '120 tijolos');
    });

    test('quantidades no meio da frase', () {
      expect(
        NumeroExtenso.normalizar(
            'comprei dez sacos de cimento e duas latas de tinta'),
        'comprei 10 sacos de cimento e 2 latas de tinta',
      );
    });

    test('reais e centavos', () {
      expect(
          NumeroExtenso.normalizar('vinte e cinco reais e cinquenta centavos'),
          '25 reais e 50 centavos');
    });

    test('"e" comum não vira número', () {
      expect(NumeroExtenso.normalizar('areia e brita'), 'areia e brita');
    });

    test('dígitos existentes passam intactos', () {
      expect(NumeroExtenso.normalizar('350 reais na loja'),
          '350 reais na loja');
    });
  });
}
