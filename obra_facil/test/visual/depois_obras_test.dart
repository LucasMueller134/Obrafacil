// Lista de obras (/obras), a primeira tela depois do login.
//
//   CAPTURAR=depois flutter test test/visual/depois_obras_test.dart
//
// grava em docs/redesign/depois/ a lista do dono (01_obras_dono) e a do
// mestre (01_obras_mestre), no tema claro e no escuro. O antes do mestre
// foi gravado no commit 8ed2c5b; o do dono é o de sempre (abfbef5). O
// teste de 360 dp com fonte 130% roda sempre.

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
    for (final (nome, usuario) in [
      ('01_obras_dono', UsuariosExemplo.dono),
      ('01_obras_mestre', UsuariosExemplo.mestre),
    ]) {
      capturarCena(Cena(
        '$nome$sufixo',
        usuario: usuario,
        rota: '/obras',
        brilho: brilho,
      ));
    }
  }

  for (final usuario in [UsuariosExemplo.dono, UsuariosExemplo.mestre]) {
    testWidgets('cabe em 360 dp com fonte 130% (${usuario.perfil.name})',
        (tester) async {
      final view = tester.view
        ..devicePixelRatio = pixelRatioCaptura
        ..physicalSize = const Size(360, 640) * pixelRatioCaptura;
      addTearDown(view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      instalarPluginsFalsos();
      final auth = AuthProvider(AuthServiceFalso(usuario));
      final router = criarRouter(auth);
      await tester.pumpWidget(AppDeCaptura(
        auth: auth,
        db: FirestoreFalso(DadosExemplo.padrao()),
        router: router,
      ));
      await assentar(tester);
      expect(
          router.routerDelegate.currentConfiguration.uri.toString(), '/obras');
      // Antes do redesenho, a linha de datas e orçamento estourava aqui.
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
      router.dispose();
      auth.dispose();
    });
  }
}
