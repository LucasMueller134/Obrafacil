// Cronograma da obra (/obras/:id/cronograma), onde o mestre atualiza o
// avanço de cada fase (e a maquete da central acompanha).
//
//   CAPTURAR=depois flutter test test/visual/depois_cronograma_test.dart
//
// grava em docs/redesign/depois/ o cronograma do mestre (11_cronograma_mestre)
// e a folha de atualizar uma fase (11b_cronograma_fase_mestre), no tema
// claro e no escuro. O antes foi gravado no commit 8ed2c5b. O teste de
// 360 dp com fonte 130% roda sempre.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';
import 'suporte/fakes.dart';
import 'suporte/plataforma.dart';

const _rota = '/obras/${IdsExemplo.obra}/cronograma';

/// A Alvenaria da lista (o carimbo também diz "Alvenaria", como fase
/// atual, e vem antes).
Finder get _linhaAlvenaria => find.text('Alvenaria').last;

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
      '11_cronograma_mestre$sufixo',
      usuario: UsuariosExemplo.mestre,
      rota: _rota,
      brilho: brilho,
    ));
    capturarCena(Cena(
      '11b_cronograma_fase_mestre$sufixo',
      usuario: UsuariosExemplo.mestre,
      rota: _rota,
      brilho: brilho,
      acao: (tester) => tester.tap(_linhaAlvenaria),
    ));
  }

  testWidgets('cabe em 360 dp com fonte 130%, com a folha da fase aberta',
      (tester) async {
    final view = tester.view
      ..devicePixelRatio = pixelRatioCaptura
      ..physicalSize = const Size(360, 640) * pixelRatioCaptura;
    addTearDown(view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    instalarPluginsFalsos();
    final auth = AuthProvider(AuthServiceFalso(UsuariosExemplo.mestre));
    final router = criarRouter(auth);
    await tester.pumpWidget(AppDeCaptura(
      auth: auth,
      db: FirestoreFalso(DadosExemplo.padrao()),
      router: router,
    ));
    await assentar(tester);
    // A lista de obras (/obras) vem antes: ela também não pode dar erro.
    expect(tester.takeException(), isNull);
    router.go(_rota);
    await assentar(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(_linhaAlvenaria);
    await assentar(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    router.dispose();
    auth.dispose();
  });
}
