import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/lancamento_model.dart';
import 'package:obra_facil/models/obra_model.dart';
import 'package:obra_facil/services/ia/previsao_orcamento_service.dart';

ObraModel _obra({double orcamento = 100000}) {
  final inicio = DateTime.now().subtract(const Duration(days: 30));
  return ObraModel(
    id: 'o1',
    nome: 'Obra teste',
    endereco: 'Rua X',
    orcamento: orcamento,
    dataInicio: inicio,
    previsaoTermino: inicio.add(const Duration(days: 180)),
    donoId: 'dono',
    codigoConvite: 'ABC123',
    criadoEm: inicio,
  );
}

LancamentoModel _gasto(ObraModel obra, int diasAposInicio, double valor,
    {StatusLancamento status = StatusLancamento.aprovado}) {
  return LancamentoModel(
    id: 'l$diasAposInicio',
    obraId: obra.id,
    descricao: 'gasto',
    valor: valor,
    categoria: CategoriaCusto.material,
    status: status,
    data: obra.dataInicio.add(Duration(days: diasAposInicio)),
    criadoPorId: 'u1',
    criadoPorNome: 'Mestre',
    criadoEm: DateTime.now(),
  );
}

void main() {
  group('Previsão de estouro de orçamento (regressão linear)', () {
    test('poucos dados: não arrisca previsão', () {
      final obra = _obra();
      final p = PrevisaoOrcamentoService.calcular(
        obra: obra,
        lancamentos: [_gasto(obra, 1, 500)],
      );
      expect(p.dadosSuficientes, isFalse);
      expect(p.risco, NivelRisco.ok);
    });

    test('ritmo alto de gastos indica estouro antes do fim', () {
      final obra = _obra(orcamento: 10000);
      // R$ 1.000 a cada 5 dias → R$ 36.000 projetado em 180 dias.
      final lancamentos = [
        for (var d = 0; d <= 30; d += 5) _gasto(obra, d, 1000),
      ];
      final p = PrevisaoOrcamentoService.calcular(
          obra: obra, lancamentos: lancamentos);

      expect(p.risco, NivelRisco.alto);
      expect(p.dataEstouroPrevista, isNotNull);
      expect(p.dataEstouroPrevista!.isBefore(obra.previsaoTermino), isTrue);
      expect(p.gastoProjetadoFinal, greaterThan(obra.orcamento));
    });

    test('ritmo saudável fica sob controle', () {
      final obra = _obra(orcamento: 100000);
      // R$ 500 a cada 5 dias → ~R$ 18.000 projetado em 180 dias.
      final lancamentos = [
        for (var d = 0; d <= 30; d += 5) _gasto(obra, d, 500),
      ];
      final p = PrevisaoOrcamentoService.calcular(
          obra: obra, lancamentos: lancamentos);

      expect(p.risco, NivelRisco.ok);
      expect(p.dataEstouroPrevista == null ||
          p.dataEstouroPrevista!.isAfter(obra.previsaoTermino), isTrue);
    });

    test('lançamentos pendentes e rejeitados não entram no cálculo', () {
      final obra = _obra();
      final p = PrevisaoOrcamentoService.calcular(
        obra: obra,
        lancamentos: [
          _gasto(obra, 1, 99999, status: StatusLancamento.pendente),
          _gasto(obra, 2, 99999, status: StatusLancamento.rejeitado),
        ],
      );
      expect(p.gastoAtual, 0);
    });

    test('gasto já acima do orçamento é risco alto imediato', () {
      final obra = _obra(orcamento: 1000);
      final lancamentos = [
        _gasto(obra, 1, 600),
        _gasto(obra, 5, 300),
        _gasto(obra, 10, 200),
      ];
      final p = PrevisaoOrcamentoService.calcular(
          obra: obra, lancamentos: lancamentos);
      expect(p.gastoAtual, 1100);
      expect(p.risco, NivelRisco.alto);
    });
  });
}
