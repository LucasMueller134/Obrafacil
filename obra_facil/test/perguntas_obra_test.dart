import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/services/ia/perguntas_obra_service.dart';

final _ref = DateTime(2026, 7, 9);

DadosObraChat _dados() {
  final obra = ObraModel(
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

  LancamentoModel lanc(String id, int diasAtras, double valor,
          CategoriaCusto cat,
          {String? fornecedor,
          List<ItemMaterialModel> itens = const [],
          StatusLancamento status = StatusLancamento.aprovado}) =>
      LancamentoModel(
        id: id,
        obraId: 'o1',
        descricao: 'Compra $id',
        valor: valor,
        categoria: cat,
        status: status,
        fornecedorNome: fornecedor,
        itens: itens,
        data: _ref.subtract(Duration(days: diasAtras)),
        criadoPorId: 'u1',
        criadoPorNome: 'Mestre',
        criadoEm: _ref.subtract(Duration(days: diasAtras)),
      );

  return DadosObraChat(
    obra: obra,
    lancamentos: [
      lanc('a', 3, 3000, CategoriaCusto.material,
          fornecedor: 'Depósito São José',
          itens: const [
            ItemMaterialModel(
                material: 'Cimento', quantidade: 10, unidade: 'sc'),
          ]),
      lanc('b', 10, 1500, CategoriaCusto.maoDeObra),
      lanc('c', 1, 800, CategoriaCusto.material,
          status: StatusLancamento.pendente),
    ],
    diario: [
      for (final (d, pessoas, clima) in [
        (1, 6, 'Chuvoso'),
        (3, 4, 'Ensolarado'),
        (5, 5, 'Ensolarado'),
      ])
        DiarioEntradaModel(
          id: 'd$d',
          obraId: 'o1',
          descricao: 'Trabalho na alvenaria',
          fase: 'Alvenaria',
          numeroPessoas: pessoas,
          clima: clima,
          registradoPorId: 'u1',
          registradoPorNome: 'Mestre',
          data: _ref.subtract(Duration(days: d)),
          criadoEm: _ref,
        ),
    ],
    cronograma: [
      CronogramaFaseModel(
        id: 'f1',
        obraId: 'o1',
        nome: 'Fundação',
        ordem: 0,
        dataInicio: _ref.subtract(const Duration(days: 60)),
        dataFim: _ref.subtract(const Duration(days: 5)),
        percentualConcluido: 50, // passou do prazo sem terminar
      ),
      CronogramaFaseModel(
        id: 'f2',
        obraId: 'o1',
        nome: 'Alvenaria',
        ordem: 1,
        dataInicio: _ref.subtract(const Duration(days: 10)),
        dataFim: _ref.add(const Duration(days: 30)),
        percentualConcluido: 30,
      ),
    ],
    estoque: [
      EstoqueItemModel(
        id: 'e1',
        obraId: 'o1',
        material: 'Cimento',
        quantidade: 20,
        unidade: 'sc',
        quantidadeMinima: 5,
        atualizadoEm: _ref,
      ),
    ],
    movimentos: [
      for (final d in [8, 4])
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
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  RespostaObra r(String pergunta) =>
      PerguntasObraService.responder(pergunta, _dados(), agora: _ref);

  group('Assistente de perguntas da obra', () {
    test('gasto total', () {
      final resposta = r('Quanto já gastei?');
      expect(resposta.texto, contains('4.500,00'));
      expect(resposta.texto, contains('orçamento'));
    });

    test('gasto por categoria', () {
      expect(r('quanto gastei com material?').texto, contains('3.000,00'));
      expect(r('quanto gastei com mão de obra?').texto,
          contains('1.500,00'));
    });

    test('gasto por período (últimos 7 dias)', () {
      final resposta = r('quanto gastei essa semana?');
      expect(resposta.texto, contains('3.000,00'));
      expect(resposta.texto, contains('últimos 7 dias'));
    });

    test('orçamento com projeção', () {
      final resposta = r('como está o orçamento?');
      expect(resposta.texto, contains('%'));
      expect(resposta.texto, contains('Restam'));
    });

    test('quantidade de material no estoque', () {
      final resposta = r('quanto tem de cimento?');
      expect(resposta.texto, contains('20 sc'));
    });

    test('previsão de término de material', () {
      final resposta = r('quando acaba o cimento?');
      expect(resposta.texto, contains('deve acabar'));
    });

    test('pendências', () {
      final resposta = r('tem lançamento pendente?');
      expect(resposta.texto, contains('1 lançamento'));
      expect(resposta.texto, contains('800,00'));
    });

    test('maior fornecedor', () {
      expect(r('qual meu maior fornecedor?').texto,
          contains('Depósito São José'));
    });

    test('gasto com fornecedor específico', () {
      final resposta = r('quanto gastei no depósito são josé?');
      expect(resposta.texto, contains('Depósito São José'));
      expect(resposta.texto, contains('3.000,00'));
    });

    test('cronograma e atraso', () {
      final resposta = r('estamos atrasados?');
      expect(resposta.texto, contains('%'));
      expect(resposta.texto, contains('Fundação'));
    });

    test('equipe do canteiro', () {
      final resposta = r('quantas pessoas trabalharam na obra?');
      expect(resposta.texto, contains('equipe média'));
      expect(resposta.texto, contains('chuva'));
    });

    test('maior gasto', () {
      final resposta = r('qual foi o maior gasto?');
      expect(resposta.texto, contains('3.000,00'));
    });

    test('pergunta sem sentido cai no fallback com sugestões', () {
      final resposta = r('qual a cor do cavalo branco de napoleão?');
      expect(resposta.sugestoes, isNotEmpty);
      expect(resposta.texto, contains('sei responder'));
    });
  });

  group('Conversa natural e tolerância a erros', () {
    test('saudação pura recebe resposta cordial', () {
      final resposta = r('Boa tarde!');
      expect(resposta.texto, contains('Boa tarde'));
      expect(resposta.texto, contains('Casa Teste'));
      expect(resposta.sugestoes, isNotEmpty);
    });

    test('a pergunta do print: saudação + contexto + erro de digitação', () {
      final resposta =
          r('Boa tarde como está o contexto da minha olha?');
      expect(resposta.texto, contains('Panorama'));
      expect(resposta.texto, contains('%'));
    });

    test('"como está a obra?" traz o resumo executivo', () {
      final resposta = r('como está a obra?');
      expect(resposta.texto, contains('Panorama'));
      expect(resposta.texto, contains('orçamento'));
    });

    test('agradecimento', () {
      expect(r('valeu!').texto, contains('junto'));
    });

    test('erro de digitação no material ("cimeto")', () {
      expect(r('quanto tem de cimeto?').texto, contains('20 sc'));
    });

    test('erro de digitação na intenção ("orsamento")', () {
      expect(r('como ta o orsamento?').texto, contains('Restam'));
    });

    test('"a obra tá em dia?" cai no cronograma', () {
      final resposta = r('a obra tá em dia?');
      expect(resposta.texto, contains('%'));
    });

    test('gasto ligado a um material específico', () {
      final resposta = r('quanto gastei com cimento?');
      expect(resposta.texto, contains('3.000,00'));
      expect(resposta.texto, contains('Cimento'));
    });
  });
}
