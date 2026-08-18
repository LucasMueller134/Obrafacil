import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/lancamento_model.dart';
import 'package:obra_facil/services/ia/voz_service.dart';

void main() {
  group('Parser de lançamento por voz', () {
    test('frase completa: valor, categoria material e fornecedor', () {
      final r = VozService.interpretar(
          'comprei 10 sacos de cimento por 350 reais no Depósito São José');

      expect(r.valor, 350);
      expect(r.categoria, CategoriaCusto.material);
      expect(r.fornecedorNome, isNotNull);
      expect(r.descricao.toLowerCase(), contains('cimento'));
    });

    test('valor com centavos falado como decimal', () {
      final r = VozService.interpretar('paguei 89,90 reais de tinta');
      expect(r.valor, 89.90);
      expect(r.categoria, CategoriaCusto.material);
    });

    test('mão de obra: diária de pedreiro', () {
      final r = VozService.interpretar(
          'paguei 150 reais a diária do pedreiro João');
      expect(r.valor, 150);
      expect(r.categoria, CategoriaCusto.maoDeObra);
    });

    test('equipamento: aluguel de betoneira', () {
      final r = VozService.interpretar(
          'aluguel da betoneira por 200 reais essa semana');
      expect(r.valor, 200);
      expect(r.categoria, CategoriaCusto.equipamento);
    });

    test('sem valor identificável retorna null no valor', () {
      final r = VozService.interpretar('comprei umas coisas na loja');
      expect(r.valor, isNull);
    });

    test('frase neutra cai em outros', () {
      final r = VozService.interpretar('taxa da prefeitura 75 reais');
      expect(r.categoria, CategoriaCusto.outros);
    });

    test('valor falado por extenso é entendido', () {
      final r = VozService.interpretar(
          'comprei dez sacos de cimento por trezentos e cinquenta reais '
          'no Depósito São José');
      expect(r.valor, 350);
      expect(r.categoria, CategoriaCusto.material);
      expect(r.itens, hasLength(1));
      expect(r.itens.first.quantidade, 10);
      expect(r.itens.first.material, 'Cimento');
    });

    test('reais e centavos por extenso', () {
      final r = VozService.interpretar(
          'paguei vinte e cinco reais e cinquenta centavos de parafuso');
      expect(r.valor, 25.50);
      expect(r.categoria, CategoriaCusto.material);
    });

    test('milhar por extenso com mão de obra', () {
      final r = VozService.interpretar(
          'gastei mil e duzentos reais com o pedreiro João');
      expect(r.valor, 1200);
      expect(r.categoria, CategoriaCusto.maoDeObra);
    });
  });

  group('Interpretação da frase como um todo', () {
    test('descrição sai limpa: sem valor, fornecedor nem verbo', () {
      final r = VozService.interpretar(
          'comprei 10 sacos de cimento por 350 reais no Depósito São José');
      expect(r.descricao, '10 sacos de cimento');
    });

    test('fornecedor minúsculo no meio da frase', () {
      final r = VozService.interpretar(
          'comprei no depósito são josé 10 sacos de cimento por 350 reais');
      expect(r.fornecedorNome, 'Depósito São José');
      expect(r.valor, 350);
      expect(r.itens, hasLength(1));
    });

    test('fornecedor "na casa do construtor"', () {
      final r = VozService.interpretar(
          'comprei 3 latas de tinta por 90 reais na casa do construtor');
      expect(r.fornecedorNome, 'Casa do Construtor');
    });

    test('preço unitário: "por 40 reais cada" multiplica pela quantidade',
        () {
      final r = VozService.interpretar(
          'comprei 5 sacos de cimento por 40 reais cada');
      expect(r.valor, 200);
      expect(r.itens.first.quantidade, 5);
    });

    test('vários valores na frase são somados', () {
      final r = VozService.interpretar(
          'gastei 300 reais de cimento e 150 reais de areia');
      expect(r.valor, 450);
      expect(r.categoria, CategoriaCusto.material);
    });

    test('"2 sacos e meio" vira 2,5 no estoque', () {
      final r = VozService.interpretar(
          'comprei 2 sacos e meio de cimento por 100 reais');
      expect(r.itens.first.quantidade, 2.5);
    });

    test('abertura "anota aí" some da descrição', () {
      final r = VozService.interpretar('anota aí 100 reais de brita');
      expect(r.valor, 100);
      expect(r.descricao.toLowerCase(), isNot(contains('anota')));
    });

    test('profissão pesa mais que material citado de passagem', () {
      final r = VozService.interpretar(
          'paguei a diária do pedreiro João e comprei 2 sacos de cimento '
          'por 80 reais');
      expect(r.categoria, CategoriaCusto.maoDeObra);
      expect(r.itens.any((i) => i.material == 'Cimento'), isTrue);
    });

    test('data falada some da descrição', () {
      final r = VozService.interpretar(
          'comprei 2 latas de tinta dia 5 de julho por 90 reais',
          agora: DateTime(2026, 7, 10));
      expect(r.data, DateTime(2026, 7, 5));
      expect(r.descricao.toLowerCase(), isNot(contains('julho')));
      expect(r.descricao, contains('tinta'));
    });

    test('"na obra" não vira fornecedor', () {
      final r = VozService.interpretar('gastei 50 reais na obra');
      expect(r.fornecedorNome, isNull);
    });
  });

  group('Data falada no lançamento por voz', () {
    // Segunda-feira, 6 de julho de 2026 — fixa o "hoje" dos testes.
    final agora = DateTime(2026, 7, 6);

    DateTime? dataDe(String frase) =>
        VozService.interpretar(frase, agora: agora).data;

    test('sem data falada fica null (tela mantém hoje)', () {
      expect(dataDe('comprei 10 sacos de cimento por 350 reais'), isNull);
    });

    test('hoje, ontem e anteontem', () {
      expect(dataDe('comprei cimento hoje por 50 reais'),
          DateTime(2026, 7, 6));
      expect(dataDe('ontem paguei o pedreiro'), DateTime(2026, 7, 5));
      expect(dataDe('anteontem comprei areia'), DateTime(2026, 7, 4));
    });

    test('há N dias / N dias atrás, com número por extenso', () {
      expect(dataDe('paguei há 3 dias'), DateTime(2026, 7, 3));
      expect(dataDe('comprei tinta três dias atrás'), DateTime(2026, 7, 3));
    });

    test('dia do mês corrente já passado', () {
      expect(dataDe('paguei a diária dia 3'), DateTime(2026, 7, 3));
    });

    test('dia que ainda não chegou cai no mês anterior', () {
      expect(dataDe('comprei brita no dia 25'), DateTime(2026, 6, 25));
    });

    test('dia e mês por nome, inclusive por extenso', () {
      expect(dataDe('comprei telha dia 5 de julho'), DateTime(2026, 7, 5));
      expect(dataDe('paguei vinte e três de junho'), DateTime(2026, 6, 23));
      expect(dataDe('primeiro de julho comprei cimento'),
          DateTime(2026, 7, 1));
    });

    test('mês que ainda não chegou cai no ano anterior', () {
      expect(dataDe('paguei no dia 10 de dezembro'), DateTime(2025, 12, 10));
    });

    test('dia e mês numéricos: "dia 5 do 7" e "05/07"', () {
      expect(dataDe('comprei ferro dia 5 do 7'), DateTime(2026, 7, 5));
      expect(dataDe('nota de 05/07 de 200 reais'), DateTime(2026, 7, 5));
      expect(dataDe('nota de 05/07/2025'), DateTime(2025, 7, 5));
    });

    test('dias da semana', () {
      expect(dataDe('paguei o pedreiro na sexta'), DateTime(2026, 7, 3));
      expect(dataDe('comprei cimento sexta-feira'), DateTime(2026, 7, 3));
      expect(dataDe('sexta passada aluguei a betoneira'),
          DateTime(2026, 7, 3));
      expect(dataDe('no sábado comprei areia'), DateTime(2026, 7, 4));
      // Falado na própria segunda: "na segunda" é hoje, "passada" recua 7.
      expect(dataDe('paguei na segunda'), DateTime(2026, 7, 6));
      expect(dataDe('segunda passada paguei o servente'),
          DateTime(2026, 6, 29));
    });

    test('semana passada e mês passado', () {
      expect(dataDe('aluguei o andaime semana passada'),
          DateTime(2026, 6, 29));
      expect(dataDe('paguei o sinal mês passado'), DateTime(2026, 6, 6));
    });

    test('não confunde diária, meio-dia nem ordinais com data', () {
      expect(dataDe('paguei 150 reais a diária do pedreiro'), isNull);
      expect(dataDe('marmita do meio dia 25 reais'), isNull);
      expect(dataDe('paguei a segunda parcela do empreiteiro'), isNull);
    });

    test('data futura explícita é descartada', () {
      expect(dataDe('vence dia 20 de dezembro de 2026'), isNull);
    });

    test('data não atrapalha o resto da interpretação', () {
      final r = VozService.interpretar(
          'ontem comprei dez sacos de cimento por trezentos e cinquenta '
          'reais no Depósito São José',
          agora: agora);
      expect(r.data, DateTime(2026, 7, 5));
      expect(r.valor, 350);
      expect(r.categoria, CategoriaCusto.material);
      expect(r.itens, hasLength(1));
      expect(r.descricao.toLowerCase(), isNot(startsWith('ontem')));
    });
  });

  group('Jeitos de falar o preço', () {
    test('sem a palavra "reais": custou, saiu, ficou em, deu', () {
      expect(VozService.interpretar('a areia custou 320').valor, 320);
      expect(VozService.interpretar('o frete saiu 150').valor, 150);
      expect(VozService.interpretar('a tinta ficou em 89,90').valor, 89.90);
      expect(VozService.interpretar('deu 45 no cimento').valor, 45);
      expect(VozService.interpretar('no valor de 1200').valor, 1200);
    });

    test('milhar com ponto não vira número quebrado', () {
      expect(VozService.interpretar('paguei 1.200 reais ao empreiteiro').valor,
          1200);
      expect(VozService.interpretar('a nota deu R\$ 1.234,56').valor, 1234.56);
    });

    test('decimal falado com "vírgula"', () {
      expect(
          VozService.interpretar('a tinta custou trinta e cinco vírgula '
                  'cinquenta')
              .valor,
          35.50);
    });

    test('milhão por extenso', () {
      final r = VozService.interpretar('o terreno custou um milhão e '
          'duzentos mil reais');
      expect(r.valor, 1200000);
    });

    test('gíria de dinheiro', () {
      expect(VozService.interpretar('paguei 80 mango de frete').valor, 80);
      expect(VozService.interpretar('foram 200 pila de areia').valor, 200);
    });

    test('total anunciado não é somado com as parcelas', () {
      final r = VozService.interpretar(
          'gastei 300 de cimento e 150 de areia, no total 450 reais');
      expect(r.valor, 450);
    });

    test('valor que é a soma dos outros é reconhecido como total', () {
      final r = VozService.interpretar(
          'comprei 200 reais de tinta, 100 reais de massa e 50 reais de '
          'lixa, 350 reais no cartão');
      expect(r.valor, 350);
    });

    test('preço unitário multiplica pela quantidade', () {
      final r = VozService.interpretar('comprei 5 sacos de cimento por 40 '
          'reais cada');
      expect(r.valor, 200);
      expect(r.itens.first.quantidade, 5);
    });

    test('"a unidade" também marca preço unitário', () {
      final r = VozService.interpretar('peguei 3 latas de tinta por 90 reais '
          'a unidade');
      expect(r.valor, 270);
    });
  });

  group('Palavra inteira e sem acento na classificação', () {
    test('calçada não é classificada como o material cal', () {
      final r = VozService.interpretar('paguei 500 reais para fazer a calçada');
      expect(r.categoria, isNot(CategoriaCusto.material));
    });

    test('acento errado na transcrição não atrapalha', () {
      // O reconhecedor escreve "diaria" e "eletrica" sem acento.
      expect(VozService.interpretar('paguei 180 reais a diaria do pedreiro')
          .categoria, CategoriaCusto.maoDeObra);
      expect(VozService.interpretar('comprei fio para a instalacao eletrica')
          .categoria, CategoriaCusto.material);
    });

    test('plural do material é reconhecido', () {
      expect(VozService.interpretar('comprei 20 tijolos por 60 reais')
          .categoria, CategoriaCusto.material);
    });

    test('locação de equipamento continua sendo equipamento', () {
      final r = VozService.interpretar(
          'aluguei a placa vibratória por 250 reais no sábado');
      expect(r.categoria, CategoriaCusto.equipamento);
    });
  });

  group('Fornecedor', () {
    test('rede conhecida é entendida mesmo sem preposição', () {
      final r = VozService.interpretar('comprei tinta na leroy merlin por 200 '
          'reais');
      expect(r.fornecedorNome, 'Leroy Merlin');
    });

    test('palavra genérica sozinha não vira fornecedor', () {
      expect(VozService.interpretar('gastei 100 reais em casa').fornecedorNome,
          isNull);
      expect(VozService.interpretar('paguei 90 reais na obra').fornecedorNome,
          isNull);
    });
  });

  group('Materiais para o estoque', () {
    test('"meio saco de cimento" vira 0,5 no estoque', () {
      final itens =
          VozService.interpretar('usei meio saco de cimento hoje').itens;
      expect(itens, hasLength(1));
      expect(itens.first.quantidade, 0.5);
      expect(itens.first.material, 'Cimento');
    });
  });
}
