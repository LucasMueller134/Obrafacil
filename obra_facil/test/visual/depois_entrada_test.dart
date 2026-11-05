// Abertura e login, a entrada do app.
//
//   CAPTURAR=depois flutter test test/visual/depois_entrada_test.dart
//
// grava em docs/redesign/depois/ a abertura (13_abertura) e o login
// (12_login), no tema claro e no escuro. O antes destas telas foi gravado
// no commit 8ed2c5b (CAPTURAR=antes, só o escuro, que era o único tema).
// O teste de 360 dp com fonte 130% roda sempre. Ver
// docs/redesign/LEIA-ME-capturas.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';
import 'suporte/fakes.dart';
import 'suporte/plataforma.dart';

void main() {
  // O antes destas telas foi gravado no commit 8ed2c5b (antes do
  // redesenho delas). Agora, com CAPTURAR=antes, estes testes gravariam o
  // visual novo por cima.
  if (serieDeCaptura == 'antes') {
    test('capturas do antes', () {},
        skip: 'o antes destas telas foi gravado no commit 8ed2c5b');
    return;
  }
  setUpAll(prepararCapturas);

  for (final (sufixo, brilho) in [
    ('', Brightness.light),
    ('_escuro', Brightness.dark),
  ]) {
    capturarCena(Cena(
      '12_login$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '/login',
      brilho: brilho,
      situacao: SituacaoLogin.deslogado,
      acao: carregarImagens,
    ));
    capturarCena(Cena(
      '13_abertura$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '/splash',
      brilho: brilho,
      situacao: SituacaoLogin.abrindo,
      acao: carregarImagens,
    ));
  }

  testWidgets('login cabe em 360 dp com fonte 130%, com o teclado aberto',
      (tester) async {
    final view = tester.view
      ..devicePixelRatio = pixelRatioCaptura
      ..physicalSize = const Size(360, 640) * pixelRatioCaptura;
    addTearDown(view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    instalarPluginsFalsos();
    final auth = AuthProvider(AuthServiceDeslogado(UsuariosExemplo.dono));
    final router = criarRouter(auth);
    await tester.pumpWidget(AppDeCaptura(
      auth: auth,
      db: FirestoreFalso(DadosExemplo.padrao()),
      router: router,
    ));
    await assentar(tester);
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
    expect(tester.takeException(), isNull);

    // Teclado aberto (uns 280 dp): a tela rola e nada estoura.
    view.viewInsets = const FakeViewPadding(bottom: 280 * pixelRatioCaptura);
    await assentar(tester, total: const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Entrar'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    router.dispose();
    auth.dispose();
  });
}
