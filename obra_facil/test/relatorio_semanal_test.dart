import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/services/ia/relatorio_semanal_service.dart';

final _ref = DateTime(2026, 7, 3);

ObraModel _obra() => ObraModel(
      id: 'o1',
      nome: 'Casa Teste',
      endereco: 'Rua X',
      orcamento: 100000,
      dataInicio: _ref.subtract(const Duration(days: 60)),
      previsaoTermino: _ref.add(const Duration(days: 120)),
      donoId: 'dono',
      codigoConvite: 'ABC123',
      criadoEm: _ref.subtract(const Duration(days: 60)),
    );

LancamentoModel _lanc(int diasAtras, double valor,
        {StatusLancamento status = StatusLancamento.aprovado}) =>
    LancamentoModel(
      id: 'l$diasAtras-$valor',
      obraId: 'o1',
      descricao: 'Compra de material',
      valor: valor,
      categoria: CategoriaCusto.material,
      status: status,
      data: _ref.subtract(Duration(days: diasAtras)),
      criadoPorId: 'u1',
      criadoPorNome: 'Mestre',
      criadoEm: _ref.subtract(Duration(days: diasAtras)),
    );

CronogramaFaseModel _fase(String nome, int pct) => CronogramaFaseModel(
      id: nome,
      obraId: 'o1',
      nome: nome,
      ordem: 0,
      dataInicio: _ref.subtract(const Duration(days: 60)),
      dataFim: _ref.add(const Duration(days: 30)),
      percentualConcluido: pct,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('Relatório semanal', () {
    test('detecta gasto correndo à frente do avanço físico', () {
      final r = RelatorioSemanalService.gerar(
        obra: _obra(),
        lancamentos: [
          _lanc(40, 20000),
          _lanc(20, 15000),
          _lanc(3, 10000),
        ], // 45% do orçamento
        diario: const [],
        cronograma: [_fase('Fundação', 40), _fase('Estrutura', 20)], // 30%
        referencia: _ref,
      );

      expect(r.secoes.first.tipo, TipoSecao.visaoGeral);
      expect(r.secoes.first.paragrafos.join(' '), contains('45%'));
      expect(r.acoes.any((a) => a.contains('Investigar')), isTrue);
    });

    test('pendências e estoque crítico viram ações concretas', () {
      final r = RelatorioSemanalService.gerar(
        obra: _obra(),
        lancamentos: [
          _lanc(3, 5000),
          _lanc(5, 800, status: StatusLancamento.pendente),
        ],
        diario: const [],
        cronograma: const [],
        estoque: [
          EstoqueItemModel(
            id: 'e1',
            obraId: 'o1',
            material: 'Cimento',
            quantidade: 10,
            unidade: 'sc',
            quantidadeMinima: 2,
            atualizadoEm: _ref,
          ),
        ],
        movimentos: [
          for (final d in [10, 6, 3])
            MovimentoEstoqueModel(
              id: 'm$d',
              obraId: 'o1',
              material: 'Cimento',
              tipo: TipoMovimentoEstoque.saida,
              quantidade: 4,
              unidade: 'sc',
              origem: 'manual',
              data: _ref.subtract(Duration(days: d)),
            ),
        ],
        referencia: _ref,
      );

      expect(r.acoes.any((a) => a.contains('Revisar 1 lançamento')), isTrue);
      expect(r.acoes.any((a) => a.contains('Cimento')), isTrue);
      expect(r.textoCompartilhavel, contains('O QUE FAZER AGORA'));
    });

    test('obra recém-criada gera relatório sem erros e sem frases soltas',
        () {
      final r = RelatorioSemanalService.gerar(
        obra: _obra(),
        lancamentos: const [],
        diario: const [],
        cronograma: const [],
        referencia: _ref,
      );
      expect(r.secoes, isNotEmpty);
      expect(r.acoes, isNotEmpty); // mensagem padrão de "continue registrando"
      // sem seção financeira vazia falando de "nenhum gasto"
      expect(
          r.secoes.any((s) => s.tipo == TipoSecao.financeiro), isFalse);
    });
  });
}
