// Cronograma (/obras/:id/cronograma) e lista de obras (/obras): o que o
// redesenho promete.
//
// Cronograma
// - Tocar numa fase abre a folha de atualizar; "−" e "+" andam de 5 em 5
//   parando nos múltiplos de 5; "Fase pronta" vai a 100%.
// - "Salvar" grava a fase com o novo percentual (o mesmo salvarFase de
//   antes) e mostra o aviso com Desfazer, que grava a fase como era.
// - Sem mudança, "Salvar" fica desabilitado e nada é gravado.
// - "Excluir fase" exclui (o mesmo excluirFase) e o Desfazer grava a mesma
//   fase de novo, com o mesmo id.
// - A situação da fase vem em texto (não só na cor).
//
// Lista de obras
// - Cada folha mostra a fase atual e o avanço da obra, com a mesma conta
//   da central; tocar abre a central.
// - O dono tem "Nova obra" no rodapé; o mestre, "Entrar com código".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obra_facil/design/design.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';

import 'visual/suporte/captura.dart';
import 'visual/suporte/dados_exemplo.dart';
import 'visual/suporte/fakes.dart';
import 'visual/suporte/plataforma.dart';

const _cronograma = '/obras/${IdsExemplo.obra}/cronograma';

/// O falso das capturas, guardando as fases gravadas inteiras.
class _DbFases extends FirestoreFalso {
  _DbFases() : super(DadosExemplo.padrao());

  final salvas = <CronogramaFaseModel>[];
  final excluidas = <String>[];

  @override
  Future<void> salvarFase(CronogramaFaseModel fase) async => salvas.add(fase);

  @override
  Future<void> excluirFase(String obraId, String id) async =>
      excluidas.add(id);
}

class _App {
  _App(this.db, this.auth, this.router);

  final _DbFases db;
  final AuthProvider auth;
  final GoRouter router;

  /// A rota no topo da pilha (a do último `go` ou `push`).
  String get rota => router.state.uri.toString();
}

Future<_App> _abrir(
  WidgetTester tester,
  UsuarioModel usuario, {
  String? rota,
}) async {
  final view = tester.view
    ..devicePixelRatio = 2
    ..physicalSize = const Size(390, 844) * 2;
  addTearDown(view.reset);
  instalarPluginsFalsos();
  final db = _DbFases();
  final auth = AuthProvider(AuthServiceFalso(usuario));
  final router = criarRouter(auth);
  await tester.pumpWidget(AppDeCaptura(auth: auth, db: db, router: router));
  await assentar(tester);
  if (rota != null) {
    router.go(rota);
    await assentar(tester);
  }
  return _App(db, auth, router);
}

Future<void> _fechar(WidgetTester tester, _App app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  app.router.dispose();
  app.auth.dispose();
}

/// A Alvenaria da lista (o carimbo também diz "Alvenaria", como fase
/// atual, e vem antes).
Finder get _alvenaria => find.text('Alvenaria').last;

Future<void> _abrirAlvenaria(WidgetTester tester) async {
  await tester.ensureVisible(_alvenaria);
  await tester.tap(_alvenaria);
  await assentar(tester);
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await assentar(tester);
}

void main() {
  setUpAll(prepararCapturas);

  group('Cronograma', () {
    testWidgets('carimbo com o avanço da obra e a fase atual', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.mestre,
          rota: _cronograma);
      expect(find.text('CRONOGRAMA'), findsOneWidget);
      expect(find.text('Sobrado Vila Izabel'), findsOneWidget);
      // Fundação 100 + Estrutura 100 + Alvenaria 60, de 10 fases: 26%.
      expect(find.text('26%'), findsOneWidget);
      expect(find.text('10 FASES'), findsOneWidget);
      // A situação em texto, não só na cor.
      expect(find.textContaining('Concluída'), findsNWidgets(2));
      expect(find.textContaining('Em andamento'), findsOneWidget);
      await _fechar(tester, app);
    });

    testWidgets('+5 e salvar grava a fase; desfazer grava como era',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.mestre,
          rota: _cronograma);
      await _abrirAlvenaria(tester);
      expect(find.text('FASE 03'), findsOneWidget);
      expect(find.text('60%'), findsWidgets);

      await _tocar(tester, find.bySemanticsLabel('Mais 5%'));
      await _tocar(tester, find.bySemanticsLabel('Mais 5%'));
      await _tocar(tester, find.text('Salvar 70%'));

      expect(app.db.salvas, hasLength(1));
      final salva = app.db.salvas.single;
      expect(salva.id, 'fase-2');
      expect(salva.nome, 'Alvenaria');
      expect(salva.percentualConcluido, 70);
      expect(find.text('Alvenaria em 70%.'), findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await assentar(tester);
      expect(app.db.salvas, hasLength(2));
      expect(app.db.salvas.last.id, 'fase-2');
      expect(app.db.salvas.last.percentualConcluido, 60);
      await _fechar(tester, app);
    });

    testWidgets('− e + param nos múltiplos de 5', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.mestre,
          rota: _cronograma);
      await _abrirAlvenaria(tester);
      // Leva a 100 e volta: 100 → 95 → 90.
      await _tocar(tester, find.text('Fase pronta (100%)'));
      expect(find.text('100%'), findsWidgets);
      expect(find.text('Fase pronta (100%)'), findsNothing);
      await _tocar(tester, find.bySemanticsLabel('Menos 5%'));
      await _tocar(tester, find.bySemanticsLabel('Menos 5%'));
      expect(find.text('Salvar 90%'), findsOneWidget);
      await _fechar(tester, app);
    });

    testWidgets('sem mudança, Salvar fica desabilitado', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.mestre,
          rota: _cronograma);
      await _abrirAlvenaria(tester);
      final salvar = tester.widget<BotaoPrincipal>(
          find.widgetWithText(BotaoPrincipal, 'Salvar'));
      expect(salvar.aoTocar, isNull);
      // Muda e volta: desabilita de novo.
      await _tocar(tester, find.bySemanticsLabel('Mais 5%'));
      await _tocar(tester, find.bySemanticsLabel('Menos 5%'));
      expect(
        tester
            .widget<BotaoPrincipal>(
                find.widgetWithText(BotaoPrincipal, 'Salvar'))
            .aoTocar,
        isNull,
      );
      expect(app.db.salvas, isEmpty);
      await _fechar(tester, app);
    });

    testWidgets('excluir a fase; desfazer grava a mesma fase de novo',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.mestre,
          rota: _cronograma);
      await _abrirAlvenaria(tester);
      await _tocar(tester, find.text('Excluir fase'));
      expect(app.db.excluidas, ['fase-2']);
      expect(find.text('Fase "Alvenaria" excluída.'), findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await assentar(tester);
      final volta = app.db.salvas.single;
      expect(volta.id, 'fase-2');
      expect(volta.nome, 'Alvenaria');
      expect(volta.percentualConcluido, 60);
      expect(volta.ordem, 2);
      await _fechar(tester, app);
    });

    testWidgets('nova fase sugere as fases padrão que faltam', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.mestre,
          rota: _cronograma);
      await _tocar(tester, find.text('Adicionar fase'));
      expect(find.text('Nova fase'), findsOneWidget);
      // O cronograma de exemplo já tem as 10 fases padrão.
      expect(find.text('FASES PADRÃO QUE FALTAM'), findsNothing);
      await _fechar(tester, app);
    });
  });

  group('Lista de obras', () {
    testWidgets('cada obra mostra a fase atual e o avanço; tocar abre',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono);
      expect(app.rota, '/obras');
      expect(find.text('Olá, Marina'), findsOneWidget);
      expect(find.text('3 OBRAS'), findsOneWidget);
      // O Sobrado: a mesma fase e o mesmo avanço da central.
      expect(find.text('Alvenaria'), findsOneWidget);
      expect(find.text('26%'), findsOneWidget);
      expect(find.text('Sem cronograma'), findsWidgets);
      expect(find.text('Nova obra'), findsOneWidget);

      await _tocar(tester, find.text('Sobrado Vila Izabel'));
      expect(app.rota, '/obras/${IdsExemplo.obra}');
      await _fechar(tester, app);
    });

    testWidgets('o mestre entra numa obra com o código', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.mestre);
      expect(find.text('Nova obra'), findsNothing);
      await _tocar(tester, find.text('Entrar com código'));
      expect(find.text('Entrar numa obra'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ZZZ999');
      await _tocar(tester, find.text('Entrar'));
      // O diálogo fecha (o campo some na animação de saída sem erro) e o
      // aviso diz o que aconteceu.
      expect(find.text('Entrar numa obra'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Código não encontrado'), findsOneWidget);
      await _fechar(tester, app);
    });

    testWidgets('"Sair da conta" fica no menu, com confirmação',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono);
      expect(find.byTooltip('Sair'), findsNothing);
      await _tocar(tester, find.byTooltip('Conta'));
      await _tocar(tester, find.text('Sair da conta'));
      expect(find.text('Sair da conta?'), findsOneWidget);
      await _tocar(tester, find.text('Cancelar'));
      expect(app.rota, '/obras');
      await _fechar(tester, app);
    });
  });
}
