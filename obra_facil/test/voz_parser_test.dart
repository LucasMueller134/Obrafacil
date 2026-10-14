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
      final r =
          VozService.interpretar('paguei 150 reais a diária do pedreiro João');
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

    test('preço unitário: "por 40 reais cada" multiplica pela quantidade', () {
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
      expect(dataDe('comprei cimento hoje por 50 reais'), DateTime(2026, 7, 6));
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
      expect(dataDe('primeiro de julho comprei cimento'), DateTime(2026, 7, 1));
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
      expect(dataDe('sexta passada aluguei a betoneira'), DateTime(2026, 7, 3));
      expect(dataDe('no sábado comprei areia'), DateTime(2026, 7, 4));
      // Falado na própria segunda: "na segunda" é hoje, "passada" recua 7.
      expect(dataDe('paguei na segunda'), DateTime(2026, 7, 6));
      expect(
          dataDe('segunda passada paguei o servente'), DateTime(2026, 6, 29));
    });

    test('semana passada e mês passado', () {
      expect(dataDe('aluguei o andaime semana passada'), DateTime(2026, 6, 29));
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
      expect(
          VozService.interpretar('paguei 180 reais a diaria do pedreiro')
              .categoria,
          CategoriaCusto.maoDeObra);
      expect(
          VozService.interpretar('comprei fio para a instalacao eletrica')
              .categoria,
          CategoriaCusto.material);
    });

    test('plural do material é reconhecido', () {
      expect(
          VozService.interpretar('comprei 20 tijolos por 60 reais').categoria,
          CategoriaCusto.material);
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

    test('unidade falada por extenso vai certa ao estoque', () {
      final item =
          VozService.interpretar('comprei 3 metros cúbicos de areia por 450')
              .itens
              .single;
      expect(item.material, 'Areia');
      expect(item.quantidade, 3);
      expect(item.unidade, 'm³');
    });

    test('aluguel de equipamento não é item de estoque', () {
      final r = VozService.interpretar('aluguei 10 peças de andaime tá');
      expect(r.itens, isEmpty);
      expect(r.categoria, CategoriaCusto.equipamento);
      expect(r.descricao, '10 peças de andaime');
    });

    test('no aluguel, o material comprado junto continua indo', () {
      final r = VozService.interpretar(
          'aluguei a betoneira e comprei 10 sacos de cimento');
      expect(r.itens.single.material, 'Cimento');
    });

    test('dinheiro dito como "300 de cimento" não vira 300 sacos', () {
      final r = VozService.interpretar('gastei 300 de cimento e 150 de areia');
      expect(r.valor, 450);
      expect(r.itens, isEmpty);
    });

    test('quantidade com "de" continua quantidade sem verbo de gasto', () {
      final r = VozService.interpretar(
          'comprei 10 de cimento e 5 de areia por 80 reais');
      expect(r.valor, 80);
      expect(r.itens.map((i) => i.quantidade), [10, 5]);
    });
  });

  group('Valor sem a palavra "reais"', () {
    double? valorDe(String frase) => VozService.interpretar(frase).valor;

    test('depois de verbo de pagamento', () {
      expect(valorDe('paguei o pedreiro 250'), 250);
      expect(valorDe('gastei 80 de frete'), 80);
      expect(valorDe('o eletricista cobrou 400 pela fiação'), 400);
      expect(valorDe('cobraram 1.200 pela laje'), 1200);
      expect(valorDe('dei 50 pro ajudante'), 50);
      expect(valorDe('o serralheiro fez por 900 o portão'), 900);
      expect(valorDe('saiu 150 o frete'), 150);
    });

    test('solto no fim da frase', () {
      final r = VozService.interpretar(
          'comprei 10 sacos de cimento na casa do construtor 520');
      expect(r.valor, 520);
      expect(r.fornecedorNome, 'Casa do Construtor');
      expect(r.itens.single.quantidade, 10);
      expect(valorDe('paguei a conta de luz da obra 230'), 230);
      expect(valorDe('paguei 350 no pix'), 350);
    });

    test('parcelas ligadas por "e" são somadas', () {
      expect(
          valorDe('o pedreiro 250 e o ajudante 150 e o eletricista 200'), 600);
      expect(
          valorDe('paguei o pedreiro 250 e o ajudante 150 e o eletricista 200'),
          600);
      expect(valorDe('paguei 300 mais 50 de frete'), 350);
      expect(valorDe('paguei 50 reais de gasolina e 30 de almoço'), 80);
    });

    test('lista ditada sem "e" também soma', () {
      expect(valorDe('cimento 300 areia 150 brita 200'), 650);
    });

    test('quantidade, unidade e material não são dinheiro', () {
      expect(valorDe('comprei 10 sacos de cimento'), isNull);
      expect(valorDe('comprei 3 metros cúbicos de areia'), isNull);
      expect(valorDe('comprei 500 tijolos na olaria'), isNull);
      expect(valorDe('comprei 2 portas'), isNull);
    });

    test('pessoas, dias, horas e parcelas não são dinheiro', () {
      expect(valorDe('paguei 3 pedreiros'), isNull);
      expect(valorDe('trabalharam 3 pedreiros hoje'), isNull);
      expect(valorDe('aluguei a betoneira por 3 dias'), isNull);
      expect(valorDe('o pedreiro trabalhou das 7 às 17'), isNull);
      expect(valorDe('paguei a parcela 2 do empreiteiro'), isNull);
    });

    test('bitola e medida não são dinheiro', () {
      expect(valorDe('comprei 5 barras de ferro de 8 mm'), isNull);
      expect(valorDe('comprei cano de 100'), isNull);
      expect(valorDe('comprei ferro 8 e ferro 10'), isNull);
      expect(valorDe('comprei 3 latas de tinta de 18 litros'), isNull);
      // sem o "de" e fora das bitolas comerciais, é preço
      expect(valorDe('o ferro 450 e o cimento 300'), 750);
    });

    test('endereço, número e data não são dinheiro', () {
      expect(valorDe('comprei na rua 15'), isNull);
      expect(valorDe('paguei dia 5'), isNull);
      expect(valorDe('comprei o kit número 3'), isNull);
      expect(valorDe('comprei 10 sacos de cimento cp 2'), isNull);
    });

    test('profissão no singular antes do número é o preço dela', () {
      expect(valorDe('pedreiro 150 servente 100'), 250);
    });
  });

  group('"mil" com dígito', () {
    double? valorDe(String frase) => VozService.interpretar(frase).valor;

    test('"2 mil", "1,5 mil" e "2 mil e 500"', () {
      expect(valorDe('paguei 2 mil reais pro empreiteiro'), 2000);
      expect(valorDe('paguei 1,5 mil pro empreiteiro'), 1500);
      expect(valorDe('o telhado saiu 2 mil e 500'), 2500);
    });

    test('o que já funcionava continua', () {
      expect(valorDe('R\$ 2.000 de material'), 2000);
      expect(valorDe('2.000 reais de areia'), 2000);
      expect(valorDe('paguei dois mil e quinhentos reais'), 2500);
    });
  });

  group('Preço unitário', () {
    double? valorDe(String frase) => VozService.interpretar(frase).valor;

    test('"a 35 cada", "a R\$ 38,50 cada", "35 o saco"', () {
      expect(valorDe('comprei 10 sacos a 35 cada'), 350);
      expect(valorDe('comprei 4 latas de tinta a R\$ 38,50 cada'), 154);
      expect(valorDe('comprei 10 sacos de cimento 35 o saco'), 350);
      expect(valorDe('comprei 5 sacos de cimento por 40 reais cada'), 200);
    });

    test('multiplica pela quantidade do item a que o preço se refere', () {
      expect(
          valorDe('comprei 10 sacos de cimento a 35 e 5 latas de tinta a 80'),
          750);
      expect(
          valorDe('comprei 20 metros de fio de 2,5 por 4 reais o metro'), 80);
      expect(valorDe('comprei 2 milheiros de tijolo a 800 o milheiro'), 1600);
    });

    test('diária e dia contam pela quantidade de dias ou de gente', () {
      expect(valorDe('paguei 3 diárias de 150 pro servente'), 450);
      expect(valorDe('aluguei a betoneira 3 dias a 50 por dia'), 150);
      expect(valorDe('o pedreiro cobrou 150 a diária e trabalhou 3 dias'), 450);
      expect(valorDe('paguei 2 serventes 120 cada'), 240);
      // "a diária" sozinha é uma diária
      expect(valorDe('paguei a diária do pedreiro 150'), 150);
    });
  });

  group('Desconto e negociação', () {
    double? valorDe(String frase) => VozService.interpretar(frase).valor;

    test('o valor final negociado vence', () {
      expect(valorDe('a nota deu R\$ 1.230 mas ele deixou por 1.200'), 1200);
      expect(valorDe('deu 1.230 mas com desconto paguei 1.200'), 1200);
      expect(valorDe('custou 300, quer dizer, 280'), 280);
    });

    test('"de desconto" é abatido do total', () {
      expect(valorDe('a nota deu 1.230 com 30 de desconto'), 1200);
    });

    test('contraste sem negociação continua somando', () {
      expect(valorDe('paguei 250 pro pedreiro mas o ajudante cobrou 150'), 400);
      expect(
          valorDe('paguei 300 de cimento mas paguei também 50 de frete'), 350);
    });

    test('a negociação sai da descrição', () {
      final r = VozService.interpretar(
          'comprei 10 sacos de cimento, deu 380 mas ele deixou por 350');
      expect(r.valor, 350);
      expect(r.descricao, '10 sacos de cimento');
    });
  });

  group('Fornecedor no meio da frase', () {
    test('o nome para no verbo seguinte', () {
      final r = VozService.interpretar(
          'lá na madeireira do zé peguei a madeira do telhado por 800');
      expect(r.fornecedorNome, 'Madeireira do Zé');
      expect(r.valor, 800);
    });

    test('nome antes do tipo', () {
      final r = VozService.interpretar(
          'comprei na silva materiais de construção 10 sacos de cimento');
      expect(r.fornecedorNome, 'Silva Materiais de Construção');
      expect(r.descricao, '10 sacos de cimento');
    });

    test('nome com "do" + nome próprio', () {
      expect(
          VozService.interpretar('comprei na loja do joão 2 sacos de cimento')
              .fornecedorNome,
          'Loja do João');
    });

    test('tipo sozinho ainda não é fornecedor', () {
      expect(
          VozService.interpretar('comprei areia no depósito ontem')
              .fornecedorNome,
          isNull);
    });
  });

  group('Ruído do reconhecedor no vocabulário de obra', () {
    test('palavra partida ou homófona é corrigida antes do parser', () {
      final ferro = VozService.interpretar('comprei 10 barras de verga lhão');
      expect(ferro.itens.single.material, 'Vergalhão de aço');
      expect(ferro.categoria, CategoriaCusto.material);

      final cimento = VozService.interpretar('comprei 10 sacos de semento');
      expect(cimento.itens.single.material, 'Cimento');
      expect(cimento.descricao, '10 sacos de cimento');
    });

    test('dia da semana homófono vira data', () {
      final r = VozService.interpretar('paguei 20 de gasolina na cesta feira',
          agora: DateTime(2026, 7, 6));
      expect(r.data, DateTime(2026, 7, 3));
      expect(r.valor, 20);
    });

    test('a transcrição original é preservada', () {
      expect(VozService.interpretar('comprei semento').transcricao,
          'comprei semento');
    });
  });

  group('Hipóteses do reconhecedor', () {
    test('troca a 1ª cortada por uma alternativa completa', () {
      final r = VozService.interpretarHipoteses([
        ('paguei o aluguel da caçamba duzentos e', 0.8),
        ('paguei o aluguel da caçamba duzentos e oitenta', 0.6),
      ]);
      expect(r.valor, 280);
      expect(r.transcricao, 'paguei o aluguel da caçamba duzentos e oitenta');
    });

    test('sem confiança informada, decide só pelo que o parser entende', () {
      final r = VozService.interpretarHipoteses([
        ('paguei o aluguel da caçamba duzentos e', -1),
        ('paguei o aluguel da caçamba duzentos e oitenta', -1),
      ]);
      expect(r.valor, 280);
    });

    test('alternativa só um pouco diferente não tira a 1ª', () {
      expect(
          VozService.interpretarHipoteses([
            ('paguei 150 ao pedreiro', 0.9),
            ('paguei 115 ao pedreiro', 0.4),
          ]).valor,
          150);
      expect(
          VozService.interpretarHipoteses([
            ('comprei 10 sacos de cimento', 0.9),
            ('comprei 10 sacos de cimento 100', 0.2),
          ]).valor,
          isNull);
    });

    test('1ª vazia ou lista vazia', () {
      expect(
          VozService.interpretarHipoteses([
            ('', 0),
            ('paguei 50 de frete', 0.5),
          ]).valor,
          50);
      expect(VozService.interpretarHipoteses([]).transcricao, '');
    });

    test('uma hipótese só é o mesmo que interpretar', () {
      final r = VozService.interpretarHipoteses([('frete 80', 0.9)]);
      expect(r.valor, 80);
      expect(r.transcricao, 'frete 80');
    });

    test('confiança só na principal (como o Android manda) não trava a troca',
        () {
      final r = VozService.interpretarHipoteses([
        ('paguei o aluguel da caçamba duzentos e', 0.9),
        ('paguei o aluguel da caçamba duzentos e oitenta', 0),
      ]);
      expect(r.valor, 280);
    });

    test('confiança só na alternativa não tira a principal', () {
      expect(
          VozService.interpretarHipoteses([
            ('paguei 150 ao pedreiro', -1),
            ('paguei 115 ao pedreiro', 0.6),
          ]).valor,
          150);
    });

    test('alternativa com material conhecido vence palavra estranha', () {
      final r = VozService.interpretarHipoteses([
        ('comprei 10 sacos de sedimento', 0.8),
        ('comprei 10 sacos de cimento', 0),
      ]);
      expect(r.itens.single.material, 'Cimento');
    });
  });

  group('Quantidade dita pela metade', () {
    test('a segunda quantidade herda a unidade da primeira', () {
      final r = VozService.interpretar(
          'comprei 4 metros cúbicos de areia e 3 de brita por 900');
      expect(r.valor, 900);
      expect(r.itens.map((i) => '${i.quantidade} ${i.unidade} ${i.material}'),
          ['4.0 m³ Areia', '3.0 m³ Brita']);

      final sacos = VozService.interpretar(
          'comprei 10 sacos de cimento e 5 de areia por 80 reais');
      expect(sacos.itens.map((i) => i.unidade), ['sc', 'sc']);
    });

    test('material dito antes da quantidade', () {
      final piso =
          VozService.interpretar('comprei porcela nato 40 metros quadrados');
      expect(piso.itens.single.material, 'Piso cerâmico');
      expect(piso.itens.single.unidade, 'm²');
      expect(piso.itens.single.quantidade, 40);

      final areia =
          VozService.interpretar('comprei areia 3 metros cúbicos por 450');
      expect(areia.valor, 450);
      expect(areia.itens.single.unidade, 'm³');
    });
  });

  group('Preço unitário de recipiente e "cada um"', () {
    double? valorDe(String frase) => VozService.interpretar(frase).valor;

    test('o preço do galão, do caminhão, multiplica pela quantidade', () {
      expect(valorDe('comprei 3 galões de tinta a 120 o galão'), 360);
      expect(valorDe('comprei 2 caminhões de areia a 700 o caminhão'), 1400);
    });

    test('"cada um" e "cada saco" antes do preço', () {
      final r =
          VozService.interpretar('comprei 10 sacos de cimento, cada um 35');
      expect(r.valor, 350);
      expect(r.descricao, '10 sacos de cimento');
      expect(valorDe('comprei 10 sacos de cimento cada saco 35'), 350);
    });

    test('"cada" sem nada contado antes não inventa multiplicação', () {
      expect(valorDe('paguei cada um 50'), 50);
    });
  });

  group('Base do preço unitário', () {
    double? valorDe(String frase) => VozService.interpretar(frase).valor;

    test('o tamanho de cada saco não é a quantidade comprada', () {
      expect(valorDe('comprei 10 sacos de cimento de 50 kg a 35 reais'), 350);
      // sem "de", o peso dito é a quantidade
      expect(valorDe('comprei arame, 50 kg a 12'), 600);
    });

    test('tempo de trabalho: por dia e por pessoa', () {
      expect(valorDe('paguei 3 diárias do pedreiro de 150'), 450);
      expect(valorDe('paguei 2 pedreiros a 150 a diária por 3 dias'), 900);
      // viagem é do caminhão, não de quem foi junto
      expect(
          valorDe('comprei 3 viagens de areia a 200 a viagem com 2 ajudantes'),
          600);
    });

    test('o metro da areia é o m³ do item', () {
      expect(valorDe('comprei 2 metros de areia a 150 o metro'), 300);
    });

    test('número depois de "pregos" é preço, não bitola', () {
      expect(valorDe('comprei pregos 25'), 25);
      expect(valorDe('comprei cano 25'), isNull);
    });
  });

  group('Negociação depois do "mas"', () {
    double? valorDe(String frase) => VozService.interpretar(frase).valor;

    test('quem já estava na conversa cobrando menos', () {
      expect(valorDe('o frete era 100 mas ele cobrou só 80'), 80);
      expect(valorDe('o orçamento deu 2.500 mas ele fez por 2.300'), 2300);
    });

    test('outra pessoa depois do "mas" é outro gasto', () {
      expect(valorDe('paguei 250 pro pedreiro mas o ajudante cobrou 150'), 400);
    });
  });

  group('Fornecedor genérico', () {
    String? fornecedorDe(String frase) =>
        VozService.interpretar(frase).fornecedorNome;

    test('tipo de loja sem nome não é fornecedor', () {
      expect(fornecedorDe('comprei na madeireira'), isNull);
      expect(
          fornecedorDe(
              'comprei na loja de material de construção 2 sacos de cimento'),
          isNull);
      expect(fornecedorDe('comprei na ferragista do bairro 2 caixas de prego'),
          isNull);
    });

    test('com nome continua fornecedor', () {
      expect(fornecedorDe('comprei na madeireira do zé'), 'Madeireira do Zé');
      expect(fornecedorDe('comprei no depósito do carlos 20 sacos de cimento'),
          'Depósito do Carlos');
    });

    test('rede conhecida leva a preposição junto da descrição', () {
      final r = VozService.interpretar(
          'fui na casa do construtor e comprei 2 sacos de cal');
      expect(r.fornecedorNome, 'Casa do Construtor');
      expect(r.descricao.toLowerCase(), isNot(contains(' na ')));
      expect(r.itens.single.material, 'Cal');
    });
  });

  group('Fala grudada no fim', () {
    test('"tá bom", "e tal", "lá" saem da descrição', () {
      expect(
          VozService.interpretar('comprei 5 sacos de cimento tá bom').descricao,
          '5 sacos de cimento');
      expect(VozService.interpretar('comprei 5 sacos de cimento lá').descricao,
          '5 sacos de cimento');
      expect(
          VozService.interpretar('comprei 5 sacos de cimento e tal').descricao,
          '5 sacos de cimento');
    });
  });
}
