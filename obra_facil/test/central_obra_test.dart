// Central da obra (/obras/:id): o que a tela faz, não como ela aparece.
//
// O redesenho mexeu só na interface. Estes testes conferem que as mesmas
// chamadas ao FirestoreService saem com os mesmos argumentos e nas mesmas
// condições de antes (menu do dono, excluir com confirmação, convites), que
// cada botão e linha abre a mesma rota de antes, e que as duas leituras novas
// (cronograma e diário) não reabrem o listener a cada mudança nos
// lançamentos. Usam os falsos e os dados de exemplo das capturas.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obra_facil/design/maquete/maquete.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';

import 'visual/suporte/captura.dart';
import 'visual/suporte/dados_exemplo.dart';
import 'visual/suporte/fakes.dart';
import 'visual/suporte/plataforma.dart';

/// Uma consulta que entrega o valor atual a cada ouvinte novo (como o
/// `snapshots()`) e que o teste pode fazer emitir de novo.
class _Fonte<T> {
  _Fonte(this.valor);

  T valor;
  final _ouvintes = <MultiStreamController<T>>[];

  late final Stream<T> stream = Stream<T>.multi((c) {
    _ouvintes.add(c);
    c.onCancel = () => _ouvintes.remove(c);
    c.add(valor);
  });

  void emitir(T novo) {
    valor = novo;
    for (final c in [..._ouvintes]) {
      c.add(novo);
    }
  }
}

/// O falso das capturas, anotando o que a central pede ao serviço.
class _DbEspiao extends FirestoreFalso {
  _DbEspiao() : super(DadosExemplo.padrao());

  final chamadas = <String>[];
  final _lancamentos = <String, _Fonte<List<LancamentoModel>>>{};

  /// Os lançamentos da obra emitem de novo (como quando alguém lança ou
  /// aprova um gasto em outro aparelho).
  void emitirLancamentos(String obraId, List<LancamentoModel> novos) =>
      _lancamentos[obraId]!.emitir(novos);

  int vezes(String prefixo) =>
      chamadas.where((c) => c.startsWith(prefixo)).length;

  @override
  Stream<ObraModel?> obra(String obraId) {
    chamadas.add('obra $obraId');
    return super.obra(obraId);
  }

  @override
  Stream<List<LancamentoModel>> lancamentos(String obraId) {
    chamadas.add('lancamentos $obraId');
    return _lancamentos.putIfAbsent(obraId, () {
      return _Fonte(List<LancamentoModel>.of(
          dados.lancamentos[obraId] ?? const <LancamentoModel>[])
        ..sort((a, b) => b.data.compareTo(a.data)));
    }).stream;
  }

  /// Com um controlador aqui, o cronograma só chega quando o teste mandar
  /// (como a primeira leitura do Firestore, que nunca vem no mesmo quadro).
  StreamController<List<CronogramaFaseModel>>? cronogramaSegurado;

  @override
  Stream<List<CronogramaFaseModel>> cronograma(String obraId) {
    chamadas.add('cronograma $obraId');
    return cronogramaSegurado?.stream ?? super.cronograma(obraId);
  }

  @override
  Stream<List<DiarioEntradaModel>> diario(String obraId) {
    chamadas.add('diario $obraId');
    return super.diario(obraId);
  }

  @override
  Future<void> atualizarObra(ObraModel obra) {
    chamadas.add('atualizarObra ${obra.id} ${obra.status.name}');
    return super.atualizarObra(obra);
  }

  @override
  Future<void> excluirObra(String obraId) {
    chamadas.add('excluirObra $obraId');
    return super.excluirObra(obraId);
  }

  @override
  Future<void> garantirConvites(ObraModel obra) {
    chamadas.add('garantirConvites ${obra.id}');
    return super.garantirConvites(obra);
  }

  @override
  Future<String> codigoDoClienteDaObra(ObraModel obra) {
    chamadas.add('codigoDoClienteDaObra ${obra.id}');
    return super.codigoDoClienteDaObra(obra);
  }
}

/// A central aberta como no app: router de verdade, perfil de verdade.
class _Central {
  _Central(this.tester, this.db, this.auth, this.router);

  final WidgetTester tester;
  final _DbEspiao db;
  final AuthProvider auth;
  final GoRouter router;

  /// O que foi copiado para a área de transferência.
  final copiado = <String>[];

  /// A rota no topo da pilha (a do último `go` ou `push`).
  String get rota => router.state.uri.toString();

  static Future<_Central> abrir(
    WidgetTester tester,
    UsuarioModel usuario, {
    String obraId = IdsExemplo.obra,
    bool segurarCronograma = false,
  }) async {
    final view = tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(390, 844) * 3;
    addTearDown(view.reset);
    instalarPluginsFalsos();
    final db = _DbEspiao();
    if (segurarCronograma) {
      final controle = db.cronogramaSegurado =
          StreamController<List<CronogramaFaseModel>>.broadcast();
      addTearDown(controle.close);
    }
    final auth = AuthProvider(AuthServiceFalso(usuario));
    final router = criarRouter(auth);
    final central = _Central(tester, db, auth, router);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (chamada) async {
        if (chamada.method == 'Clipboard.setData') {
          central.copiado.add((chamada.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(AppDeCaptura(auth: auth, db: db, router: router));
    await assentar(tester);
    router.go('/obras/$obraId');
    await assentar(tester);
    expect(central.rota, '/obras/$obraId');
    return central;
  }

  Future<void> fechar() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    router.dispose();
    auth.dispose();
  }

  /// Rola a lista da central até [alvo] aparecer.
  Future<void> rolarAte(Finder alvo) async {
    final lista = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(alvo, 200, scrollable: lista.first);
    await assentar(tester, total: const Duration(milliseconds: 400));
  }

  Future<void> tocar(Finder alvo) async {
    await tester.tap(alvo);
    await assentar(tester);
  }

  /// Volta para a central depois de abrir outra rota.
  Future<void> voltar() async {
    router.pop();
    await assentar(tester);
  }

  /// Abre o menu do AppBar e devolve os textos dos itens.
  Future<List<String>> itensDoMenu() async {
    await tocar(find.byTooltip('Ações da obra'));
    return [
      for (final item in tester.widgetList<PopupMenuItem<String>>(
          find.byType(PopupMenuItem<String>)))
        item.value!,
    ];
  }
}

const _base = '/obras/${IdsExemplo.obra}';

void main() {
  setUpAll(prepararCapturas);

  testWidgets('abre as mesmas leituras, na mesma ordem, e as novas uma vez só',
      (tester) async {
    final c = await _Central.abrir(tester, UsuariosExemplo.dono);
    // A ordem em que cada leitura foi pedida pela primeira vez.
    final daCentral = <String>[];
    for (final ch in c.db.chamadas) {
      if (ch.endsWith(IdsExemplo.obra) && !daCentral.contains(ch)) {
        daCentral.add(ch);
      }
    }
    // Antes: obra e, com a obra carregada, lançamentos. Depois: as mesmas,
    // seguidas das duas leituras novas.
    expect(daCentral.take(4).toList(), [
      'obra ${IdsExemplo.obra}',
      'lancamentos ${IdsExemplo.obra}',
      'cronograma ${IdsExemplo.obra}',
      'diario ${IdsExemplo.obra}',
    ]);
    expect(find.text('Revisar 3 gastos'), findsOneWidget);

    // Um gasto pendente some da lista (foi aprovado em outro aparelho): a
    // tela redesenha com os lançamentos novos, sem reabrir o cronograma e o
    // diário.
    final antes = c.db.dados.lancamentos[IdsExemplo.obra]!;
    final primeiroPendente =
        antes.firstWhere((l) => l.status == StatusLancamento.pendente);
    c.db.emitirLancamentos(IdsExemplo.obra, [
      for (final l in antes)
        if (l.id != primeiroPendente.id) l,
    ]);
    await assentar(c.tester);
    expect(find.text('Revisar 2 gastos'), findsOneWidget);
    expect(c.db.vezes('cronograma'), 1);
    expect(c.db.vezes('diario'), 1);
    await c.fechar();
  });

  testWidgets('a maquete só monta com o cronograma: nunca abre vazia',
      (tester) async {
    final c = await _Central.abrir(tester, UsuariosExemplo.dono,
        segurarCronograma: true);
    // Sem o cronograma, a maquete vazia diria "sem cronograma" e trocaria
    // para o avanço de verdade logo depois. Fica só o papel.
    expect(find.byType(MaqueteObra), findsNothing);
    expect(find.text('…'), findsOneWidget); // a célula FASE
    expect(find.textContaining('da obra'), findsNothing);

    c.db.cronogramaSegurado!.add(c.db.dados.cronograma[IdsExemplo.obra]!);
    // O evento chega numa microtarefa; o quadro seguinte já o desenha.
    await tester.pump();
    await tester.pump();
    // A maquete monta já com o avanço de verdade.
    final maquete = tester.widget<MaqueteObra>(find.byType(MaqueteObra));
    expect(maquete.progresso.semCronograma, isFalse);
    expect(maquete.progresso.percentualObra, 26);
    expect(find.text('Alvenaria'), findsOneWidget);
    await c.fechar();
  });

  testWidgets('cronograma com erro: a maquete aparece e a fase vira o status',
      (tester) async {
    final c = await _Central.abrir(tester, UsuariosExemplo.dono,
        segurarCronograma: true);
    c.db.cronogramaSegurado!.addError(StateError('sem permissão'));
    await assentar(tester);
    expect(find.byType(MaqueteObra), findsOneWidget);
    expect(find.text('…'), findsNothing);
    expect(find.text(StatusObra.emAndamento.label), findsOneWidget);
    await c.fechar();
  });

  testWidgets('o título de cada seção é um cabeçalho só com o título',
      (tester) async {
    final semantica = tester.ensureSemantics();
    final c = await _Central.abrir(tester, UsuariosExemplo.mestre);
    // Sem nó próprio, o "cabeçalho" subia para a seção inteira e o leitor
    // de tela lia o orçamento todo como título.
    await c.rolarAte(find.text('ORÇAMENTO'));
    expect(
      tester.getSemantics(find.text('ORÇAMENTO')),
      matchesSemantics(label: 'Orçamento', isHeader: true),
    );
    semantica.dispose();
    await c.fechar();
  });

  group('dono', () {
    testWidgets('o menu tem os mesmos itens e chama atualizarObra igual',
        (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.dono);
      // Obra em andamento: concluir, pausar e excluir (sem retomar).
      expect(await c.itensDoMenu(), ['concluir', 'pausar', 'excluir']);
      await c.tocar(find.text('Pausar obra'));
      expect(c.db.chamadas.last, 'atualizarObra ${IdsExemplo.obra} pausada');

      await c.itensDoMenu();
      await c.tocar(find.text('Marcar como concluída'));
      expect(c.db.chamadas.last, 'atualizarObra ${IdsExemplo.obra} concluida');
      await c.fechar();
    });

    testWidgets('obra pausada: retomar volta para em andamento',
        (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.dono,
          obraId: IdsExemplo.obraReforma);
      expect(await c.itensDoMenu(), ['concluir', 'retomar', 'excluir']);
      await c.tocar(find.text('Retomar obra'));
      expect(c.db.chamadas.last,
          'atualizarObra ${IdsExemplo.obraReforma} emAndamento');
      await c.fechar();
    });

    testWidgets('obra concluída: só retomar e excluir', (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.dono,
          obraId: IdsExemplo.obraConcluida);
      expect(await c.itensDoMenu(), ['retomar', 'excluir']);
      await c.fechar();
    });

    testWidgets('excluir pede confirmação; cancelar não exclui',
        (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.dono);
      await c.itensDoMenu();
      await c.tocar(find.text('Excluir obra'));
      expect(find.text('Excluir obra?'), findsOneWidget);
      await c.tocar(find.text('Cancelar'));
      expect(c.db.vezes('excluirObra'), 0);
      expect(c.rota, _base);

      await c.itensDoMenu();
      await c.tocar(find.text('Excluir obra'));
      await c.tocar(find.text('Excluir'));
      expect(c.db.chamadas.last, 'excluirObra ${IdsExemplo.obra}');
      expect(c.rota, '/obras');
      await c.fechar();
    });

    testWidgets('convites: equipe republica e copia; cliente gera e copia',
        (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.dono);
      await c.rolarAte(find.text('Código da equipe'));
      await c.tocar(find.text('Código da equipe'));
      expect(c.db.chamadas.last, 'garantirConvites ${IdsExemplo.obra}');
      expect(c.copiado.last, 'VZ4K7P');
      expect(find.text('Código copiado! Envie para o mestre de obras.'),
          findsOneWidget);

      await c.tocar(find.text('Código do cliente'));
      expect(c.db.chamadas.last, 'codigoDoClienteDaObra ${IdsExemplo.obra}');
      expect(c.copiado.last, 'CL8M2R');
      // O aviso do cliente entra na fila do ScaffoldMessenger, depois do da
      // equipe (4 s), como antes.
      await assentar(tester, total: const Duration(seconds: 5));
      expect(find.textContaining('Código do cliente: CL8M2R (copiado)'),
          findsOneWidget);
      await c.fechar();
    });

    testWidgets('cada ação abre a mesma rota de antes', (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.dono);
      // O "Revisar" de antes abria a lista de lançamentos; agora abre a
      // mesma lista já no filtro dos pendentes (pedido do redesenho).
      await c.tocar(find.text('Revisar 3 gastos'));
      expect(c.rota, '$_base/lancamentos?filtro=pendentes');
      await c.voltar();

      await c.tocar(find.text('Bloco cerâmico 9 furos'));
      expect(c.rota, '$_base/lancamentos?filtro=pendentes');
      await c.voltar();

      // O cabeçalho da folha dos pendentes abre a mesma fila.
      await c.tocar(find.text('3 gastos para aprovar'));
      expect(c.rota, '$_base/lancamentos?filtro=pendentes');
      await c.voltar();

      // O "+" faz o que fazia o botão flutuante "Lançar gasto".
      await c.tocar(find.byTooltip('Lançar gasto'));
      expect(c.rota, '$_base/lancamentos/novo');
      await c.voltar();

      for (final (modulo, caminho) in [
        ('Lançamentos', 'lancamentos'),
        ('Diário', 'diario'),
        ('Cronograma', 'cronograma'),
        ('Estoque', 'estoque'),
        ('Galeria', 'galeria'),
        ('Relatório da semana', 'relatorio'),
      ]) {
        await c.rolarAte(find.text(modulo));
        await c.tocar(find.text(modulo));
        expect(c.rota, '$_base/$caminho', reason: modulo);
        await c.voltar();
        expect(c.rota, _base);
      }
      await c.fechar();
    });

    testWidgets('sem pendentes, o rodapé é "Lançar gasto"', (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.dono);
      c.db.emitirLancamentos(IdsExemplo.obra, [
        for (final l in c.db.dados.lancamentos[IdsExemplo.obra]!)
          if (l.status != StatusLancamento.pendente) l,
      ]);
      await assentar(tester);
      expect(find.textContaining('Revisar'), findsNothing);
      expect(find.textContaining('para aprovar'), findsNothing);
      await c.tocar(find.text('Lançar gasto'));
      expect(c.rota, '$_base/lancamentos/novo');
      await c.fechar();
    });
  });

  group('mestre', () {
    testWidgets('sem menu, sem convites e sem revisar', (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.mestre);
      expect(find.byTooltip('Ações da obra'), findsNothing);
      expect(find.textContaining('Revisar'), findsNothing);
      await c.rolarAte(find.text('GASTOS POR SEMANA'));
      expect(find.text('Código da equipe'), findsNothing);
      expect(c.db.vezes('garantirConvites'), 0);
      await c.fechar();
    });

    testWidgets('o rodapé lança gasto e abre o diário', (tester) async {
      final c = await _Central.abrir(tester, UsuariosExemplo.mestre);
      expect(find.text('LANÇADOS POR VOCÊ'), findsOneWidget);
      await c.tocar(find.text('Lançar gasto'));
      expect(c.rota, '$_base/lancamentos/novo');
      await c.voltar();
      await c.tocar(find.text('Diário de hoje'));
      expect(c.rota, '$_base/diario');
      await c.fechar();
    });
  });
}
