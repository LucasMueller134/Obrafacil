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
}
