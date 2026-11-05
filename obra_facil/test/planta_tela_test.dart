// A planta da obra nas telas: central (maquete da planta), tela da planta
// (/obras/:id/planta) e vista 360° (/obras/:id/planta/:comodo/360).
//
// Nos testes não há Flutter GPU: a maquete da planta e a vista 360° ficam
// na reserva (a planta desenhada e as paredes desdobradas), que é o que
// estes testes conferem.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obra_facil/design/maquete/maquete.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';
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

  String get rota => router.state.uri.toString();
}

Future<_App> _abrir(WidgetTester tester, String rota,
    {required bool comPlanta, UsuarioModel? usuario}) async {
  final view = tester.view
    ..devicePixelRatio = 2
    ..physicalSize = const Size(390, 844) * 2;
  addTearDown(view.reset);
  instalarPluginsFalsos();
  final dados = DadosExemplo.padrao();
  final db = FirestoreFalso(comPlanta ? dados.comPlanta() : dados);
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

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await assentar(tester);
}

void main() {
  setUpAll(prepararCapturas);

  testWidgets('central com planta: a maquete é a da planta', (tester) async {
    final app = await _abrir(tester, _obra, comPlanta: true);
    final maquete = tester.widget<MaqueteObra>(find.byType(MaqueteObra));
    expect(maquete.fonte, isA<FontePlanta>());
    // Sem GPU, a reserva é a planta desenhada.
    expect(find.byKey(const ValueKey('maquete-planta')), findsOneWidget);
    // O módulo da planta resume o que ela tem.
    await tester.scrollUntilVisible(find.text('Planta da obra'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('15 cômodos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  testWidgets('central sem planta: a casa-padrão de sempre', (tester) async {
    final app = await _abrir(tester, _obra, comPlanta: false);
    final maquete = tester.widget<MaqueteObra>(find.byType(MaqueteObra));
    expect(maquete.fonte, isA<FontePadrao>());
    await _fechar(tester, app);
  });

  testWidgets('sem planta, o dono usa a de exemplo e pode desfazer',
      (tester) async {
    final app = await _abrir(tester, '$_obra/planta', comPlanta: false);
    expect(find.text('Sem planta ainda'), findsOneWidget);
    expect(find.text('Enviar a planta'), findsOneWidget);
    await _tocar(tester, find.text('Usar a casa de exemplo (7 × 20 m)'));
    expect(app.db.escritas,
        contains('salvarPlanta ${IdsExemplo.obra} Casa térrea 7 x 20'));
    await tester.tap(find.text('Desfazer'));
    await assentar(tester);
    expect(app.db.escritas, contains('excluirPlanta ${IdsExemplo.obra}'));
    await _fechar(tester, app);
  });

  testWidgets('o mestre vê a planta, mas não troca', (tester) async {
    final app = await _abrir(tester, '$_obra/planta',
        comPlanta: false, usuario: UsuariosExemplo.mestre);
    expect(find.text('O dono da obra ainda não enviou a planta.'),
        findsOneWidget);
    expect(find.text('Enviar a planta'), findsNothing);
    await _fechar(tester, app);
  });

  testWidgets('tocar num cômodo abre a ficha com as medidas da planta',
      (tester) async {
    final app = await _abrir(tester, '$_obra/planta', comPlanta: true);
    expect(find.byType(PlantaDesenhada), findsOneWidget);
    expect(find.text('15 CÔMODOS'), findsOneWidget);
    await _tocar(tester, find.text('Quarto 2'));
    // "3,23 × 4,10" na planta; a porta de correr e a janela do quarto.
    expect(find.text('3,23 × 4,10 m'), findsWidgets);
    expect(find.text('13,2 m²'), findsWidgets);
    expect(find.text('1 porta · 1 janela'), findsOneWidget);
    await _tocar(tester, find.text('Ver em 360°'));
    expect(app.rota, '$_obra/planta/quarto-2/360');
    await _fechar(tester, app);
  });

  testWidgets('360° sem 3D: as quatro paredes, com as medidas certas',
      (tester) async {
    final app = await _abrir(tester, '$_obra/planta/quarto-2/360',
        comPlanta: true);
    await assentar(tester);
    expect(find.text('Quarto 2'), findsWidgets);
    expect(find.byType(ParedesDoComodo), findsOneWidget);
    expect(find.text('FUNDO · 3,23 m'), findsOneWidget);
    // Os lados seguintes, rolando de lado (como quem gira no cômodo).
    final faixa = find
        .descendant(
            of: find.byType(ParedesDoComodo),
            matching: find.byType(Scrollable))
        .first;
    for (final lado in ['DIREITA · 4,10 m', 'FRENTE · 3,23 m', 'ESQUERDA · 4,10 m']) {
      await tester.scrollUntilVisible(find.text(lado), 200, scrollable: faixa);
      expect(find.text(lado), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  test('vãos de um cômodo: porta de correr e janela do quarto 2', () {
    final p = DadosExemplo.plantaExemplo();
    final quarto = p.comodos.firstWhere((c) => c.id == 'quarto-2');
    final tipos = p.aberturasDo(quarto).map((a) => a.tipo).toSet();
    expect(tipos, {TipoAbertura.portaCorrer, TipoAbertura.janela});
  });
}
