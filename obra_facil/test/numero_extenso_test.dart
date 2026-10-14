import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/numero_extenso.dart';

void main() {
  group('Números por extenso (pt-BR) → dígitos', () {
    test('centenas compostas', () {
      expect(
          NumeroExtenso.normalizar('trezentos e cinquenta reais'), '350 reais');
    });

    test('milhares', () {
      expect(NumeroExtenso.normalizar('mil e duzentos'), '1200');
      expect(NumeroExtenso.normalizar('dois mil quinhentos e trinta e cinco'),
          '2535');
    });

    test('cem e cento', () {
      expect(NumeroExtenso.normalizar('cem reais'), '100 reais');
      expect(NumeroExtenso.normalizar('cento e vinte tijolos'), '120 tijolos');
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
      expect(
          NumeroExtenso.normalizar('350 reais na loja'), '350 reais na loja');
    });
  });

  group('Dígito com escala falada ("2 mil")', () {
    test('dígito seguido de "mil" vira um número só', () {
      expect(NumeroExtenso.normalizar('2 mil reais'), '2000 reais');
      expect(NumeroExtenso.normalizar('paguei R\$ 3 mil'), 'paguei R\$ 3000');
      expect(NumeroExtenso.normalizar('10 mil tijolos'), '10000 tijolos');
    });

    test('decimal antes da escala', () {
      expect(NumeroExtenso.normalizar('1,5 mil'), '1500');
      expect(NumeroExtenso.normalizar('2,3 mil'), '2300');
      // ponto decimal do inglês, que o reconhecedor às vezes usa
      expect(NumeroExtenso.normalizar('1.5 mil'), '1500');
    });

    test('parte menor depois da escala, com ou sem "e"', () {
      expect(NumeroExtenso.normalizar('2 mil e 500'), '2500');
      expect(NumeroExtenso.normalizar('dois mil e 500 reais'), '2500 reais');
      expect(NumeroExtenso.normalizar('2 mil e quinhentos'), '2500');
      expect(NumeroExtenso.normalizar('2 mil 500'), '2500');
    });

    test('número pequeno depois da escala sem "e" é outro número', () {
      expect(NumeroExtenso.normalizar('2 mil 3 sacos'), '2000 3 sacos');
      expect(NumeroExtenso.normalizar('mil reais e 3 sacos'),
          '1000 reais e 3 sacos');
    });

    test('milhar escrito com ponto não é mexido', () {
      expect(NumeroExtenso.normalizar('R\$ 2.000'), 'R\$ 2.000');
      expect(NumeroExtenso.normalizar('2.000 reais'), '2.000 reais');
    });
  });

  group('Cada casa do número uma vez só', () {
    test('palavras-número em sequência não são somadas', () {
      expect(NumeroExtenso.normalizar('dez quinze sacos'), '10 15 sacos');
      expect(NumeroExtenso.normalizar('vinte trinta'), '20 30');
      expect(NumeroExtenso.normalizar('um dois três'), '1 2 3');
    });

    test('composições legítimas continuam inteiras', () {
      expect(NumeroExtenso.normalizar('cento e vinte e cinco'), '125');
      expect(NumeroExtenso.normalizar('cento e quinze'), '115');
      expect(NumeroExtenso.normalizar('um milhão e duzentos mil'), '1200000');
    });

    test('"e" que não continua o número fica no texto', () {
      expect(NumeroExtenso.normalizar('duzentos e o ajudante'),
          '200 e o ajudante');
      expect(NumeroExtenso.normalizar('paguei duzentos e'), 'paguei 200 e');
    });
  });

  group('Decimal e pontuação', () {
    test('decimal falado depois de dígito ou de extenso', () {
      expect(NumeroExtenso.normalizar('35 vírgula 50'), '35,50');
      expect(NumeroExtenso.normalizar('trinta e cinco vírgula cinquenta'),
          '35,50');
      expect(NumeroExtenso.normalizar('dois vírgula zero cinco'), '2,05');
    });

    test('pontuação colada no número é mantida', () {
      // Sem a vírgula, "250, o ajudante 150" viraria uma coisa só.
      expect(
          NumeroExtenso.normalizar(
              'o pedreiro duzentos e cinquenta, o ajudante cento e cinquenta'),
          'o pedreiro 250, o ajudante 150');
    });
  });

  group('"um" que não é número', () {
    test('"cada um" é pronome', () {
      expect(NumeroExtenso.normalizar('10 sacos, cada um trinta e cinco'),
          '10 sacos, cada um 35');
      expect(
          NumeroExtenso.normalizar('cada uma saiu vinte'), 'cada uma saiu 20');
    });

    test('"um" de quantidade continua virando 1', () {
      expect(NumeroExtenso.normalizar('comprei um saco de cimento'),
          'comprei 1 saco de cimento');
      expect(NumeroExtenso.normalizar('cada saco um real'), 'cada saco 1 real');
    });
  });
}
