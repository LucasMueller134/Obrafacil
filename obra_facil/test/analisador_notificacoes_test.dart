import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/services/notificacoes/analisador_notificacoes.dart';

final _agora = DateTime(2026, 7, 10, 12);
final _ultimaChecagem = DateTime(2026, 7, 10, 11);

final _dono = UsuarioModel(
    id: 'dono1',
    nome: 'Dono',
    email: 'd@x.com',
    perfil: PerfilUsuario.dono,
    criadoEm: _agora);
final _mestre = UsuarioModel(
    id: 'mestre1',
    nome: 'Mestre',
    email: 'm@x.com',
    perfil: PerfilUsuario.mestre,
    criadoEm: _agora);

ObraModel _obra({double orcamento = 100000}) => ObraModel(
      id: 'o1',
      nome: 'Casa Teste',
      endereco: 'Rua X',
      orcamento: orcamento,
      dataInicio: _agora.subtract(const Duration(days: 30)),
      previsaoTermino: _agora.add(const Duration(days: 150)),
      donoId: 'dono1',
      equipeIds: const ['mestre1'],
      codigoConvite: 'ABC123',
      criadoEm: _agora,
    );

LancamentoModel _lanc({
  required String id,
  double valor = 100,
  StatusLancamento status = StatusLancamento.pendente,
  DateTime? criadoEm,
  DateTime? moderadoEm,
  String criadoPor = 'mestre1',
  String? motivo,
}) =>
    LancamentoModel(
      id: id,
      obraId: 'o1',
      descricao: 'Compra $id',
      valor: valor,
      categoria: CategoriaCusto.material,
      status: status,
      motivoRejeicao: motivo,
      moderadoEm: moderadoEm,
      data: _agora,
      criadoPorId: criadoPor,
      criadoPorNome: 'Mestre',
      criadoEm: criadoEm ?? _agora,
    );

List<NotificacaoPendente> _analisar({
  required UsuarioModel usuario,
  List<LancamentoModel> lancamentos = const [],
  List<EstoqueItemModel> estoque = const [],
  List<CronogramaFaseModel> cronograma = const [],
  Set<String> jaNotificadas = const {},
  ObraModel? obra,
}) =>
    AnalisadorNotificacoes.analisar(
      usuario: usuario,
      obras: [obra ?? _obra()],
      lancamentosPorObra: {'o1': lancamentos},
      estoquePorObra: {'o1': estoque},
      movimentosPorObra: const {'o1': []},
      diarioPorObra: const {'o1': []},
      cronogramaPorObra: {'o1': cronograma},
      ultimaChecagem: _ultimaChecagem,
      chavesJaNotificadas: jaNotificadas,
      agora: _agora,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('Verificador de notificações', () {
    test('dono é avisado de lançamento pendente novo (e só do novo)', () {
      final notifs = _analisar(usuario: _dono, lancamentos: [
        _lanc(id: 'novo', criadoEm: _agora.subtract(const Duration(minutes: 10))),
        _lanc(id: 'velho', criadoEm: _agora.subtract(const Duration(hours: 3))),
      ]);
      expect(notifs, hasLength(1));
      expect(notifs.first.titulo, contains('aprovar'));
      expect(notifs.first.corpo, contains('Compra novo'));
    });

    test('muitos pendentes viram uma notificação agregada', () {
      final notifs = _analisar(usuario: _dono, lancamentos: [
        for (var i = 0; i < 5; i++)
          _lanc(
              id: 'p$i',
              valor: 100,
              criadoEm: _agora.subtract(const Duration(minutes: 5))),
      ]);
      expect(notifs, hasLength(1));
      expect(notifs.first.titulo, contains('5 lançamentos'));
      expect(notifs.first.corpo, contains('500,00'));
    });

    test('mestre é avisado da aprovação e da rejeição com motivo', () {
      final notifs = _analisar(usuario: _mestre, lancamentos: [
        _lanc(
            id: 'ap',
            status: StatusLancamento.aprovado,
            moderadoEm: _agora.subtract(const Duration(minutes: 5))),
        _lanc(
            id: 'rj',
            status: StatusLancamento.rejeitado,
            motivo: 'valor não confere',
            moderadoEm: _agora.subtract(const Duration(minutes: 5))),
      ]);
      expect(notifs, hasLength(2));
      expect(notifs[0].titulo, contains('✅'));
      expect(notifs[1].titulo, contains('❌'));
      expect(notifs[1].corpo, contains('valor não confere'));
    });

    test('moderação antiga não notifica de novo', () {
      final notifs = _analisar(usuario: _mestre, lancamentos: [
        _lanc(
            id: 'ap',
            status: StatusLancamento.aprovado,
            moderadoEm: _agora.subtract(const Duration(hours: 2))),
      ]);
      expect(notifs, isEmpty);
    });

    test('estoque abaixo do mínimo alerta, e a dedupe segura a repetição',
        () {
      final estoque = [
        EstoqueItemModel(
          id: 'e1',
          obraId: 'o1',
          material: 'Cimento',
          quantidade: 2,
          unidade: 'sc',
          quantidadeMinima: 5,
          atualizadoEm: _agora,
        ),
      ];
      final primeira = _analisar(usuario: _mestre, estoque: estoque);
      expect(primeira, hasLength(1));
      expect(primeira.first.titulo, contains('Cimento'));

      final repetida = _analisar(
        usuario: _mestre,
        estoque: estoque,
        jaNotificadas: {primeira.first.chave},
      );
      expect(repetida, isEmpty);
    });

    test('orçamento em 90% e estourado avisam o dono (e não o mestre)', () {
      final quaseLa = _analisar(
        usuario: _dono,
        obra: _obra(orcamento: 1000),
        lancamentos: [
          _lanc(
              id: 'g',
              valor: 920,
              status: StatusLancamento.aprovado,
              criadoEm: _agora.subtract(const Duration(days: 2))),
        ],
      );
      expect(quaseLa.single.titulo, contains('92%'));

      final estourado = _analisar(
        usuario: _dono,
        obra: _obra(orcamento: 1000),
        lancamentos: [
          _lanc(
              id: 'g',
              valor: 1100,
              status: StatusLancamento.aprovado,
              criadoEm: _agora.subtract(const Duration(days: 2))),
        ],
      );
      expect(estourado.single.titulo, contains('estourado'));

      final mestreNaoVe = _analisar(
        usuario: _mestre,
        obra: _obra(orcamento: 1000),
        lancamentos: [
          _lanc(
              id: 'g',
              valor: 920,
              status: StatusLancamento.aprovado,
              criadoEm: _agora.subtract(const Duration(days: 2))),
        ],
      );
      expect(mestreNaoVe, isEmpty);
    });

    test('fase atrasada gera alerta para o dono', () {
      final notifs = _analisar(usuario: _dono, cronograma: [
        CronogramaFaseModel(
          id: 'f1',
          obraId: 'o1',
          nome: 'Fundação',
          ordem: 0,
          dataInicio: _agora.subtract(const Duration(days: 30)),
          dataFim: _agora.subtract(const Duration(days: 3)),
          percentualConcluido: 60,
        ),
      ]);
      expect(notifs.single.titulo, contains('Fase atrasada'));
      expect(notifs.single.corpo, contains('Fundação'));
    });
  });
}
