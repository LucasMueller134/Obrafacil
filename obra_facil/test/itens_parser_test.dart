import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/itens_parser.dart';

void main() {
  group('ItensParser — texto livre (voz/descrição)', () {
    test('frase de voz completa vira item de estoque', () {
      final itens = ItensParser.deTexto(
          'comprei 10 sacos de cimento por 350 reais no Depósito São José');
      expect(itens, hasLength(1));
      expect(itens.first.material, 'Cimento');
      expect(itens.first.quantidade, 10);
      expect(itens.first.unidade, 'sc');
    });

    test('vários materiais na mesma frase', () {
      final itens =
          ItensParser.deTexto('5 barras de ferro e 2 latas de tinta');
      expect(itens, hasLength(2));
      expect(itens[0].material, 'Vergalhão de aço');
      expect(itens[0].unidade, 'br');
      expect(itens[1].material, 'Tinta');
      expect(itens[1].unidade, 'lt');
    });

    test('quantidade sem unidade só vale para material conhecido', () {
      final itens = ItensParser.deTexto('comprei 500 tijolos na olaria');
      expect(itens, hasLength(1));
      expect(itens.first.material, 'Tijolo');
      expect(itens.first.quantidade, 500);
    });

    test('valores em reais não viram material', () {
      final itens =
          ItensParser.deTexto('paguei 150 reais a diária do pedreiro');
      expect(itens, isEmpty);
    });
  });

  group('ItensParser — linhas de nota fiscal (OCR)', () {
    test('linhas de cupom com quantidade, unidade e preço', () {
      const texto = '''
DEPOSITO SAO JOSE LTDA
10 SC CIMENTO CP-II 32,50 325,00
2 M3 AREIA MEDIA 90,00 180,00
TOTAL R\$ 505,00
''';
      final itens = ItensParser.deNotaOcr(texto);
      expect(itens, hasLength(2));
      expect(itens[0].material, 'Cimento');
      expect(itens[0].quantidade, 10);
      expect(itens[0].unidade, 'sc');
      expect(itens[1].material, 'Areia');
      expect(itens[1].unidade, 'm³');
    });

    test('linhas sem preço não viram item', () {
      final itens = ItensParser.deNotaOcr('10 SC CIMENTO');
      expect(itens, isEmpty);
    });
  });
}
