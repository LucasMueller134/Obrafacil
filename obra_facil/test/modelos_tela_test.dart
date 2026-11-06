// Os modelos prontos nas telas: montar pelo modelo (com prévia e
// desfazer), o pedido impossível, o seletor de pavimento do sobrado, a
// unidade-tipo do geminado no cliente, o 360° de um quarto do andar de
// cima e a nova obra com o tipo da construção.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obra_facil/design/design.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';
import 'package:obra_facil/screens/planta/modelo_planta.dart';
import 'package:obra_facil/screens/planta/vista_360_screen.dart';

import 'visual/suporte/captura.dart';
import 'visual/suporte/dados_exemplo.dart';
import 'visual/suporte/fakes.dart';
import 'visual/suporte/plataforma.dart';

const _obra = '/obras/${IdsExemplo.obra}';

class _App {
  _App(this.db, this.auth, this.router);

  final FirestoreFalso db;
  final AuthProvider auth;
  final GoRouter router;
}

Future<_App> _abrir(WidgetTester tester, String rota,
    {DadosExemplo? dados, UsuarioModel? usuario}) async {
  final view = tester.view
    ..devicePixelRatio = 2
    ..physicalSize = const Size(390, 844) * 2;
  addTearDown(view.reset);
  instalarPluginsFalsos();
  final db = FirestoreFalso(dados ?? DadosExemplo.padrao());
  final auth = AuthProvider(AuthServiceFalso(usuario ?? UsuariosExemplo.dono));
  final router = criarRouter(auth);
  await tester.pumpWidget(AppDeCaptura(auth: auth, db: db, router: router));
  await assentar(tester);
  router.go(rota);
  await assentar(tester);
  return _App(db, auth, router);
}

Future<void> _fechar(WidgetTester tester, _App app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  app.router.dispose();
  app.auth.dispose();
}

Future<void> _rolarAte(WidgetTester tester, Finder alvo,
    {double passo = 200}) async {
  await tester.scrollUntilVisible(alvo, passo,
      scrollable: find.byType(Scrollable).first);
  await tester.pump();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await assentar(tester);
}

DadosExemplo _comModelo(PedidoModelo p) =>
    DadosExemplo.padrao().comPlantaDe(ModelosPlanta.montar(p));

void main() {
  setUpAll(prepararCapturas);

  testWidgets('sem planta: montar pelo modelo grava o prédio', (tester) async {
    final app = await _abrir(tester, '$_obra/planta');
    await _tocar(tester, find.text('Montar pelo modelo'));
    expect(find.text('Usar este modelo'), findsOneWidget);
    // Prédio: 12 apartamentos em 4 andares.
    await _tocar(tester, find.bySemanticsLabel('Prédio'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Apartamentos'), '12');
    await tester.enterText(find.widgetWithText(TextField, 'Andares'), '4');
    await assentar(tester);
    await _tocar(tester, find.text('Usar este modelo'));
    expect(app.db.escritas,
        contains('salvarPlanta ${IdsExemplo.obra} Prédio de 12 apartamentos'));
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  testWidgets('pedido impossível: diz o que corrigir e não deixa usar',
      (tester) async {
    final app = await _abrir(tester, '$_obra/planta');
    await _tocar(tester, find.text('Montar pelo modelo'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Área da casa'), '20');
    await assentar(tester);
    await _rolarAte(tester, find.textContaining('35 m²', findRichText: true));
    final botao = tester.widget<BotaoPrincipal>(
        find.widgetWithText(BotaoPrincipal, 'Usar este modelo'));
    expect(botao.aoTocar, isNull);
    await _fechar(tester, app);
  });

  testWidgets('sobrado: a planta tem o térreo e o superior', (tester) async {
    final app = await _abrir(tester, '$_obra/planta',
        dados: _comModelo(const PedidoModelo(
            tipo: TipoModelo.casa, area: 150, quartos: 3, sobrado: true)));
    expect(find.textContaining('Sobrado · 150 m²'), findsOneWidget);
    await _rolarAte(tester, find.text('Lavabo'));
    await _rolarAte(tester, find.bySemanticsLabel('Superior'), passo: -200);
    await _tocar(tester, find.bySemanticsLabel('Superior'));
    await _rolarAte(tester, find.text('Quarto 3'));
    expect(find.text('Lavabo'), findsNothing);
    // O 360° de um quarto do andar de cima abre (no teste, as paredes).
    await _tocar(tester, find.text('Quarto 3'));
    await _tocar(tester, find.text('Ver em 360°').last);
    expect(app.router.state.uri.toString(), contains('/360'));
    await assentar(tester);
    // A ficha embaixo é a do quarto do andar de cima (as medidas dele).
    expect(find.text('Quarto 3'), findsWidgets);
    expect(find.byType(Interior360), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  testWidgets('cliente com geminado: a casa-tipo por dentro', (tester) async {
    final app = await _abrir(tester, '/cliente/${IdsExemplo.obra}',
        usuario: UsuariosExemplo.cliente,
        dados: _comModelo(const PedidoModelo(
            tipo: TipoModelo.geminado, area: 70, quartos: 2, unidades: 3)));
    await _rolarAte(
        tester, find.textContaining('Mostrando: Casa 1', findRichText: true));
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  testWidgets('nova obra: escolher prédio mostra os números e o resumo',
      (tester) async {
    final app = await _abrir(tester, '/obras/nova');
    await _rolarAte(tester, find.bySemanticsLabel('Prédio'));
    await _tocar(tester, find.bySemanticsLabel('Prédio'));
    expect(find.widgetWithText(TextField, 'Apartamentos'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Andares'), findsOneWidget);
    await _tocar(tester, find.bySemanticsLabel('Projeto real'));
    expect(find.widgetWithText(TextField, 'Apartamentos'), findsNothing);
    expect(find.textContaining('envie a planta'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  test('o pedido inicial de cada tipo monta sem problema', () {
    for (final t in TipoModelo.values) {
      final p = pedidoInicial(t);
      expect(p.problema, isNull, reason: t.name);
      expect(ModelosPlanta.montar(p).problemas(), isEmpty);
    }
  });
}
