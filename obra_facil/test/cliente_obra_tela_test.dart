// Acompanhamento do cliente (/cliente/:id): o que o redesenho promete.
//
// - Carimbo com a fase atual, o avanço, a entrega e o prazo.
// - A maquete "Hoje" (o avanço do cronograma) e "Pronta" (todas as fases).
// - Com planta: a casa por dentro, com a ficha de cada cômodo e a vista
//   360°, na rota do cliente.
// - Sem planta: nada de "por dentro" (e a casa-padrão na maquete).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obra_facil/design/maquete/maquete.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';

import 'visual/suporte/captura.dart';
import 'visual/suporte/dados_exemplo.dart';
import 'visual/suporte/fakes.dart';
import 'visual/suporte/plataforma.dart';

const _rota = '/cliente/${IdsExemplo.obra}';

class _App {
  _App(this.auth, this.router);

  final AuthProvider auth;
  final GoRouter router;

  String get rota => router.state.uri.toString();
}

Future<_App> _abrir(WidgetTester tester, {required bool comPlanta}) async {
  final view = tester.view
    ..devicePixelRatio = 2
    ..physicalSize = const Size(390, 844) * 2;
  addTearDown(view.reset);
  instalarPluginsFalsos();
  final dados = DadosExemplo.padrao();
  final db = FirestoreFalso(comPlanta ? dados.comPlanta() : dados);
  final auth = AuthProvider(AuthServiceFalso(UsuariosExemplo.cliente));
  final router = criarRouter(auth);
  await tester.pumpWidget(AppDeCaptura(auth: auth, db: db, router: router));
  await assentar(tester);
  router.go(_rota);
  await assentar(tester);
  return _App(auth, router);
}

Future<void> _fechar(WidgetTester tester, _App app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  app.router.dispose();
  app.auth.dispose();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await assentar(tester);
}

void main() {
  setUpAll(prepararCapturas);

  testWidgets('carimbo com a fase e o avanço; maquete hoje e pronta',
      (tester) async {
    final app = await _abrir(tester, comPlanta: true);
    expect(app.rota, _rota);
    expect(find.text('SUA OBRA'), findsOneWidget);
    expect(find.text('Alvenaria'), findsOneWidget);
    expect(find.text('26%'), findsOneWidget);

    MaqueteObra maquete() => tester.widget<MaqueteObra>(find.byType(MaqueteObra));
    expect(maquete().fonte, isA<FontePlanta>());
    expect(maquete().progresso.concluida, isFalse);
    await _tocar(tester, find.bySemanticsLabel('Pronta'));
    expect(maquete().progresso.concluida, isTrue);
    expect(find.text('Como a casa fica pronta.'), findsOneWidget);
    await _tocar(tester, find.bySemanticsLabel('Hoje'));
    expect(maquete().progresso.percentualObra, 26);
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  testWidgets('a casa por dentro: ficha do cômodo e vista 360°',
      (tester) async {
    final app = await _abrir(tester, comPlanta: true);
    expect(find.text('A CASA POR DENTRO'), findsOneWidget);
    await _tocar(tester, find.text('Quarto 2'));
    expect(find.text('3,23 × 4,10 m'), findsWidgets);
    await _tocar(tester, find.text('Ver em 360°'));
    expect(app.rota, '$_rota/planta/quarto-2/360');
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  testWidgets('sem planta, sem "por dentro"', (tester) async {
    final app = await _abrir(tester, comPlanta: false);
    expect(find.text('A CASA POR DENTRO'), findsNothing);
    expect(tester.widget<MaqueteObra>(find.byType(MaqueteObra)).fonte,
        isA<FontePadrao>());
    expect(find.text('Perguntar sobre a obra'), findsOneWidget);
    await _fechar(tester, app);
  });
}
