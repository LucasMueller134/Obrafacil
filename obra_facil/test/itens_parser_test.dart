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
      final itens = ItensParser.deTexto('5 barras de ferro e 2 latas de tinta');
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

    test('"300 reais de cimento" é dinheiro, não 300 sacos', () {
      final itens = ItensParser.deTexto('gastei 300 reais de cimento na obra');
      expect(itens, isEmpty);
    });

    test('"e meio" soma meia unidade, antes ou depois da unidade', () {
      expect(ItensParser.deTexto('2 sacos e meio de cimento').first.quantidade,
          2.5);
      expect(
          ItensParser.deTexto('comprei 1 e meia lata de tinta')
              .first
              .quantidade,
          1.5);
    });
  });

  group('ItensParser — unidade falada por extenso', () {
    test('metros cúbicos, quadrados e lineares', () {
      final areia = ItensParser.deTexto('comprei 3 metros cúbicos de areia');
      expect(areia.single.material, 'Areia');
      expect(areia.single.quantidade, 3);
      expect(areia.single.unidade, 'm³');

      expect(ItensParser.deTexto('20 metros quadrados de piso').single.unidade,
          'm²');
      expect(
          ItensParser.deTexto('um metro cúbico de brita').single.unidade, 'm³');
      expect(ItensParser.deTexto('15 metros lineares de rodapé').single.unidade,
          'm');
    });

    test('milheiro e dúzia multiplicam a quantidade', () {
      final tijolo = ItensParser.deTexto('2 milheiros de tijolo').single;
      expect(tijolo.quantidade, 2000);
      expect(tijolo.unidade, 'un');
    });

    test('milhar com ponto é mil, não um vírgula dois', () {
      expect(ItensParser.deTexto('1.200 tijolos').single.quantidade, 1200);
    });

    test('recipiente só vira item com material conhecido', () {
      expect(ItensParser.deTexto('3 rolos de fio').single.material,
          'Fio elétrico');
      expect(ItensParser.deTexto('1 caminhão de entulho'), isEmpty);
    });
  });

  group('ItensParser — onde o nome do material termina', () {
    test('palavra de fala grudada não entra no nome', () {
      expect(
          ItensParser.deTexto('aluguei 10 peças de andaime tá').single.material,
          'Andaime');
      expect(
          ItensParser.deTexto('10 peças de andaime a 15 cada').single.material,
          'Andaime');
    });

    test('verbo conjugado encerra o nome', () {
      expect(
          ItensParser.deTexto('10 peças de forma paguei 350').single.material,
          'Forma');
    });

    test('unidade sem material não vira item', () {
      // Antes saía um item chamado "Por".
      expect(ItensParser.deTexto('10 sacos por 350'), isEmpty);
    });

    test('sem unidade, o material tem de vir logo depois do número', () {
      // O 250 é do pedreiro; o cimento é outra parcela.
      expect(ItensParser.deTexto('paguei o pedreiro 250 e o cimento 300'),
          isEmpty);
      expect(ItensParser.deTexto('500 tijolos').single.material, 'Tijolo');
      expect(ItensParser.deTexto('10 de cimento').single.material, 'Cimento');
    });

    test('bitola e medida não viram item', () {
      final itens =
          ItensParser.deTexto('5 barras de ferro de 8 mm por 40 cada');
      expect(itens, hasLength(1));
      expect(itens.single.quantidade, 5);
      expect(ItensParser.deTexto('comprei cano de 100'), isEmpty);
    });
  });

  group('ItensParser — posição dos itens na frase', () {
    test('localizar diz onde está a quantidade e o nome', () {
      const frase = 'comprei 10 sacos de cimento a 35 cada';
      final item = ItensParser.localizar(frase).single;
      expect(frase.substring(item.inicio, item.fimQuantidade), '10 sacos');
      expect(frase.substring(item.inicio, item.fim), '10 sacos de cimento');
      expect(item.quantidadeClara, isTrue);
    });

    test('"300 de cimento" é quantidade só talvez — pode ser dinheiro', () {
      final item = ItensParser.localizar('gastei 300 de cimento').single;
      expect(item.quantidadeClara, isFalse);
      expect(
          ItensParser.localizar('500 tijolos').single.quantidadeClara, isTrue);
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

    test('a nota não muda com as regras da fala', () {
      // "cal" curto só vale na fala; na nota o nome lido continua inteiro.
      final itens = ItensParser.deNotaOcr('2 SC CAL HIDRATADA 12,00 24,00');
      expect(itens.single.material, 'Cal hidratada');
    });
  });

  group('ItensParser — jeitos de falar a quantidade', () {
    String resumo(String frase) => ItensParser.deTexto(frase)
        .map((i) => '${i.quantidade} ${i.unidade} ${i.material}')
        .join(' | ');

    test('a segunda quantidade herda a unidade da primeira', () {
      expect(
          resumo('2 sacos de cal e 3 de areia'), '2.0 sc Cal | 3.0 sc Areia');
      expect(resumo('4 metros cúbicos de areia e 3 de brita'),
          '4.0 m³ Areia | 3.0 m³ Brita');
      // milheiro herdado multiplica também
      expect(resumo('2 milheiros de tijolo e 1 de telha'),
          '2000.0 un Tijolo | 1000.0 un Telha');
    });

    test('contagem própria não herda unidade', () {
      expect(resumo('10 sacos de cimento e 20 tijolos'),
          '10.0 sc Cimento | 20.0 un Tijolo');
      // com outra coisa entre os dois, a unidade não é presumida
      expect(resumo('10 sacos de cimento pro reboco e 5 de areia'),
          isNot(contains('5.0 sc')));
    });

    test('material dito antes da quantidade', () {
      expect(resumo('comprei porcelanato 40 metros quadrados'),
          '40.0 m² Piso cerâmico');
      expect(resumo('areia 3 metros cúbicos por 450'), '3.0 m³ Areia');
      expect(resumo('cimento 10 sacos'), '10.0 sc Cimento');
      // sem unidade continua sendo preço, não quantidade
      expect(resumo('cimento 300 areia 150'), '');
    });

    test('a 2ª palavra da unidade nunca vira o material', () {
      expect(resumo('40 metros quadrados'), '');
      expect(resumo('3 metros cúbicos'), '');
    });

    test('"cal" por palavra inteira, sem pegar "calçada"', () {
      expect(resumo('2 de cal'), '2.0 un Cal');
      expect(resumo('2 sacos de cal hidratada'), '2.0 sc Cal');
      expect(
          resumo('fizemos a calçada com 3 sacos de cimento'), '3.0 sc Cimento');
    });

    test('"meia" tonelada, dúzia e metro cúbico', () {
      expect(resumo('meia tonelada de ferro'), '500.0 kg Vergalhão de aço');
      expect(resumo('meia dúzia de portas'), '6.0 un Porta');
      expect(resumo('meio metro cúbico de areia'), '0.5 m³ Areia');
    });

    test('areia e brita "por metro" são m³', () {
      expect(resumo('2 metros de areia'), '2.0 m³ Areia');
      expect(resumo('meio metro de brita'), '0.5 m³ Brita');
      // o que se compra por metro linear continua em metro
      expect(resumo('10 metros de fio'), '10.0 m Fio elétrico');
    });

    test('a unidade dita fica guardada para o preço "o galão"', () {
      final item = ItensParser.localizar('3 galões de tinta').single;
      expect(item.item.unidade, 'un');
      expect(item.unidadeFalada, 'galoes');
    });
  });
}
