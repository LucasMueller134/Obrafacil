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
  });
}
