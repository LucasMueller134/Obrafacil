import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/diario_entrada_model.dart';
import 'package:obra_facil/models/estoque_item_model.dart';
import 'package:obra_facil/models/movimento_estoque_model.dart';
import 'package:obra_facil/services/ia/previsao_estoque_service.dart';

final _ref = DateTime(2026, 7, 3);

EstoqueItemModel _item(double qtd) => EstoqueItemModel(
      id: 'e1',
      obraId: 'o1',
      material: 'Cimento',
      quantidade: qtd,
      unidade: 'sc',
      quantidadeMinima: 5,
      atualizadoEm: _ref,
    );

MovimentoEstoqueModel _saida(int diasAtras, double qtd) =>
    MovimentoEstoqueModel(
      id: 'm$diasAtras',
      obraId: 'o1',
      material: 'Cimento',
      tipo: TipoMovimentoEstoque.saida,
      quantidade: qtd,
      unidade: 'sc',
      origem: 'manual',
      data: _ref.subtract(Duration(days: diasAtras)),
    );

DiarioEntradaModel _dia(int diasAtras, int pessoas) => DiarioEntradaModel(
      id: 'd$diasAtras',
      obraId: 'o1',
      descricao: 'trabalho normal',
      fase: 'Alvenaria',
      numeroPessoas: pessoas,
      clima: 'Ensolarado',
      registradoPorId: 'u1',
      registradoPorNome: 'Mestre',
      data: _ref.subtract(Duration(days: diasAtras)),
      criadoEm: _ref,
    );

void main() {
  group('Previsão de término de material', () {
    test('sem histórico suficiente não arrisca previsão', () {
      final p = PrevisaoEstoqueService.calcular(
        item: _item(50),
        movimentos: [_saida(3, 5)],
        diario: const [],
        referencia: _ref,
      );
      expect(p, isNull);
    });

    test('consumo constante projeta data de término coerente', () {
      // ~2 sc/dia nos últimos 20 dias, 30 sc em estoque → ~15 dias.
      final movimentos = [
        for (var d = 20; d >= 2; d -= 2) _saida(d, 4),
      ];
      final p = PrevisaoEstoqueService.calcular(
        item: _item(30),
        movimentos: movimentos,
        diario: const [],
        referencia: _ref,
      )!;
      expect(p.diasRestantes, inInclusiveRange(10, 20));
      expect(p.dataTermino.isAfter(_ref), isTrue);
      expect(p.consideraEquipe, isFalse);
    });

    test('equipe maior que a média acelera a previsão', () {
      final movimentos = [
        for (var d = 20; d >= 2; d -= 2) _saida(d, 4),
      ];
      // média do período ~4 pessoas; equipe recente com 8 → consome mais.
      final diario = [
        _dia(20, 4), _dia(16, 4), _dia(12, 4),
        _dia(8, 8), _dia(5, 8), _dia(3, 8), _dia(1, 8),
      ];
      final semEquipe = PrevisaoEstoqueService.calcular(
        item: _item(30),
        movimentos: movimentos,
        diario: const [],
        referencia: _ref,
      )!;
      final comEquipe = PrevisaoEstoqueService.calcular(
        item: _item(30),
        movimentos: movimentos,
        diario: diario,
        referencia: _ref,
      )!;
      expect(comEquipe.consideraEquipe, isTrue);
      expect(comEquipe.diasRestantes, lessThan(semEquipe.diasRestantes));
    });

    test('estoque zerado não gera previsão', () {
      final p = PrevisaoEstoqueService.calcular(
        item: _item(0),
        movimentos: [_saida(5, 2), _saida(2, 2)],
        diario: const [],
        referencia: _ref,
      );
      expect(p, isNull);
    });
  });
}
