import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/services/ia/perguntas_obra_service.dart';

final _ref = DateTime(2026, 8, 21);

/// Dados como o app monta para o cliente: obra, cronograma e diário.
/// Lançamento, estoque e movimento vão vazios de propósito — é a primeira
/// barreira contra vazar custo, antes mesmo das regras do Firestore.
DadosObraChat _dadosDoCliente({
  List<LancamentoModel> lancamentos = const [],
  String descricaoDiario = 'Assentamos 500 tijolos na parede dos fundos',
}) {
  final obra = ObraModel(
    id: 'o1',
    nome: 'Casa do Sr. João',
    endereco: 'Rua das Pedras, 123 — CEP 89250-000',
    orcamento: 250000,
    dataInicio: _ref.subtract(const Duration(days: 60)),
    previsaoTermino: _ref.add(const Duration(days: 120)),
    donoId: 'dono',
    codigoConvite: 'ABC123',
    codigoCliente: 'XYZ789',
    criadoEm: _ref.subtract(const Duration(days: 60)),
  );

  return DadosObraChat(
    obra: obra,
    lancamentos: lancamentos,
    diario: [
      DiarioEntradaModel(
        id: 'd1',
        obraId: 'o1',
        descricao: descricaoDiario,
        fase: 'Alvenaria',
        numeroPessoas: 5,
        clima: 'Ensolarado',
        registradoPorId: 'u1',
        registradoPorNome: 'Mestre',
        data: _ref.subtract(const Duration(days: 2)),
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
        dataFim: _ref.subtract(const Duration(days: 20)),
        percentualConcluido: 100,
      ),
      CronogramaFaseModel(
        id: 'f2',
        obraId: 'o1',
        nome: 'Alvenaria',
        ordem: 1,
        dataInicio: _ref.subtract(const Duration(days: 15)),
        dataFim: _ref.add(const Duration(days: 30)),
        percentualConcluido: 40,
      ),
    ],
    estoque: const [],
    movimentos: const [],
  );
}

/// Nenhum número com cara de dinheiro pode aparecer na resposta.
void _semDinheiro(String resposta) {
  expect(resposta, isNot(contains('R\$')));
  expect(resposta, isNot(matches(RegExp(r'\d+,\d{2}'))));
}

void main() {
  setUpAll(() async {
    // As respostas formatam datas em pt-BR.
    await initializeDateFormatting('pt_BR');
  });

  String responder(String pergunta, {DadosObraChat? dados}) =>
      PerguntasObraService.responder(
        pergunta,
        dados ?? _dadosDoCliente(),
        agora: _ref,
        modoCliente: true,
      ).texto;

  group('Modo cliente — dinheiro fica de fora', () {
    test('pergunta de gasto é devolvida ao responsável', () {
      for (final pergunta in [
        'quanto já foi gasto na obra?',
        'qual o orçamento?',
        'quanto custou o material?',
        'me manda a nota fiscal',
        'quem é o fornecedor do cimento?',
        'tem lançamento pendente?',
      ]) {
        final r = responder(pergunta);
        expect(r.toLowerCase(), contains('responsável'),
            reason: 'falhou em: $pergunta');
        _semDinheiro(r);
      }
    });

    test('mesmo com lançamento em mãos, o valor não sai', () {
      // Cinto e suspensório: se algum dia a tela passar lançamentos por
      // engano, a resposta ainda não pode citar valor.
      final dados = _dadosDoCliente(lancamentos: [
        LancamentoModel(
          id: 'l1',
          obraId: 'o1',
          descricao: 'Cimento',
          valor: 3500,
          categoria: CategoriaCusto.material,
          status: StatusLancamento.aprovado,
          data: _ref.subtract(const Duration(days: 3)),
          criadoPorId: 'u1',
          criadoPorNome: 'Mestre',
          criadoEm: _ref,
        ),
      ]);
      final r = responder('quanto gastei essa semana?', dados: dados);
      expect(r.toLowerCase(), contains('responsável'));
      expect(r, isNot(contains('3500')));
      expect(r, isNot(contains('3.500')));
    });

    test('"gostei" não é confundido com "gastei"', () {
      final r = responder('gostei do acabamento, como está a obra?');
      expect(r.toLowerCase(), isNot(contains('responsável')));
    });

    test('"quanto falta da obra" é andamento, não dinheiro', () {
      final r = responder('quanto falta da obra?');
      expect(r.toLowerCase(), isNot(contains('responsável')));
    });
  });

  group('Modo cliente — o que ele pode saber', () {
    test('resumo traz prazo, avanço e previsão, sem valor', () {
      final r = responder('como está a obra?');
      expect(r, contains('Casa do Sr. João'));
      expect(r, contains('%'));
      expect(r.toLowerCase(), contains('entrega'));
      _semDinheiro(r);
    });

    test('fase atual aparece no resumo', () {
      final r = responder('em que fase está?');
      expect(r.toLowerCase(), contains('alvenaria'));
      _semDinheiro(r);
    });

    test('materiais vêm do diário, sem preço nem estoque', () {
      final r = responder('que material está sendo usado?');
      expect(r.toLowerCase(), contains('tijolo'));
      _semDinheiro(r);
    });

    test('sem diário, avisa em vez de inventar', () {
      final dados = DadosObraChat(
        obra: _dadosDoCliente().obra,
        lancamentos: const [],
        diario: const [],
        cronograma: const [],
        estoque: const [],
        movimentos: const [],
      );
      final r = responder('o que foi feito essa semana?', dados: dados);
      expect(r.toLowerCase(), contains('registro'));
    });

    test('o canteiro do dia é respondido pelo diário', () {
      final r = responder('quantas pessoas trabalharam?');
      _semDinheiro(r);
      expect(r, isNotEmpty);
    });

    test('pergunta fora do assunto sugere o que ele pode perguntar', () {
      final resposta = PerguntasObraService.responder(
        'qual a cor do céu?',
        _dadosDoCliente(),
        agora: _ref,
        modoCliente: true,
      );
      expect(resposta.sugestoes, PerguntasObraService.sugestoesCliente);
      expect(resposta.sugestoes.join(' ').toLowerCase(),
          isNot(contains('gastei')));
    });
  });

  group('Modo equipe segue completo', () {
    test('a mesma pergunta de gasto responde normalmente para a equipe', () {
      final dados = _dadosDoCliente(lancamentos: [
        LancamentoModel(
          id: 'l1',
          obraId: 'o1',
          descricao: 'Cimento',
          valor: 3500,
          categoria: CategoriaCusto.material,
          status: StatusLancamento.aprovado,
          data: _ref.subtract(const Duration(days: 3)),
          criadoPorId: 'u1',
          criadoPorNome: 'Mestre',
          criadoEm: _ref,
        ),
      ]);
      final r = PerguntasObraService.responder(
        'quanto já foi gasto?',
        dados,
        agora: _ref,
      ).texto;
      expect(r.toLowerCase(), isNot(contains('não passa por aqui')));
      expect(r, contains('R\$'));
    });
  });
}
