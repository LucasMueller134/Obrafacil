// Central da obra (/obras/:id) depois do redesenho.
//
//   CAPTURAR=depois flutter test test/visual/depois_central_obra_test.dart
//
// grava em docs/redesign/depois/ as mesmas cenas do "antes" desta tela
// (02_obra_dono e 03_obra_mestre, celular e _longa), as versões _escuro e
// a mesma tela rolada até o fim (_fim), com os mesmos dados de exemplo.
// Sem CAPTURAR, as capturas são puladas; o teste de layout em 360 dp roda
// sempre. Ver docs/redesign/LEIA-ME-capturas.md.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';
import 'suporte/fakes.dart';
import 'suporte/plataforma.dart';

const _obra = '/obras/${IdsExemplo.obra}';

/// Espera a imagem de reserva da maquete decodificar (no teste não há
/// Impeller, então a maquete fica na imagem; a decodificação do webp roda
/// fora do tempo falso).
Future<void> _carregarImagens(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    final pendentes = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .where((r) => r.image == null);
    if (pendentes.isEmpty) {
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  fail('a imagem da maquete não decodificou');
}

/// Rola a lista da central até o fim (a lista é preguiçosa: o fim só é
/// conhecido depois de montar o que falta, daí as voltas).
Future<void> _rolarAteOFim(WidgetTester tester) async {
  final lista = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  final posicao = tester.state<ScrollableState>(lista.first).position;
  for (var i = 0; i < 10; i++) {
    final fim = posicao.maxScrollExtent;
    posicao.jumpTo(fim);
    await tester.pump();
    if (posicao.maxScrollExtent == fim) break;
  }
}

Future<void> _imagensEFim(WidgetTester tester) async {
  await _carregarImagens(tester);
  await _rolarAteOFim(tester);
}

/// Grava a [moldura] em `docs/redesign/<série>/<nome>.png` (as cenas de 360 dp
/// não passam pelo `capturarCena`, que só tem os tamanhos de 390 dp).
Future<void> _gravar(
    WidgetTester tester, GlobalKey moldura, String nome) async {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/docs/redesign').existsSync()) {
    dir = dir.parent;
  }
  final arquivo = File('${dir.path}/docs/redesign/$serieDeCaptura/$nome.png');
  await tester.runAsync(() async {
    final limite =
        moldura.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagem = await limite.toImage(pixelRatio: pixelRatioCaptura);
    final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
    imagem.dispose();
    arquivo.parent.createSync(recursive: true);
    arquivo.writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  // Sempre: o teste de layout em 360 dp também mede com as fontes de
  // verdade e formata datas em pt_BR.
  setUpAll(prepararCapturas);

  for (final (sufixo, brilho) in [
    ('', Brightness.light),
    ('_escuro', Brightness.dark),
  ]) {
    for (final (nome, usuario) in [
      ('02_obra_dono', UsuariosExemplo.dono),
      ('03_obra_mestre', UsuariosExemplo.mestre),
    ]) {
      capturarCena(Cena(
        '$nome$sufixo',
        usuario: usuario,
        rota: _obra,
        brilho: brilho,
        acao: _carregarImagens,
      ));
      capturarCena(Cena(
        '${nome}_fim$sufixo',
        usuario: usuario,
        rota: _obra,
        brilho: brilho,
        acao: _imagensEFim,
      ));
    }
  }

  // Celular pequeno (360 x 640) com a fonte do sistema em 130%: nada
  // estoura, do topo ao fim, para o dono e para o mestre. Com CAPTURAR, a
  // tela também é gravada (02_obra_dono_360_fonte130 e _fim, idem mestre).
  for (final (nome, usuario) in [
    ('02_obra_dono', UsuariosExemplo.dono),
    ('03_obra_mestre', UsuariosExemplo.mestre),
  ]) {
    testWidgets('cabe em 360 dp com fonte 130% (${usuario.perfil.name})',
        (tester) async {
      final view = tester.view
        ..devicePixelRatio = pixelRatioCaptura
        ..physicalSize = const Size(360, 640) * pixelRatioCaptura;
      addTearDown(view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      instalarPluginsFalsos();
      final db = FirestoreFalso(DadosExemplo.padrao());
      final auth = AuthProvider(AuthServiceFalso(usuario));
      final router = criarRouter(auth);

      final moldura = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: moldura,
        child: AppDeCaptura(auth: auth, db: db, router: router),
      ));
      await assentar(tester);
      // O que veio antes é a lista de obras (/obras), outra tela: ela
      // estoura em 360 dp com fonte 130% (obras_screen.dart, a linha de
      // datas e orçamento do cartão), defeito anterior ao redesenho desta
      // tela. Aqui só a central conta; coberta pela central, a lista não é
      // mais pintada e não reporta de novo.
      tester.takeException();
      router.go(_obra);
      await assentar(tester);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), _obra);
      expect(tester.takeException(), isNull);

      // O perfil decide o rodapé (e o rodapé está sempre à vista).
      final ehDono = usuario.perfil == PerfilUsuario.dono;
      if (ehDono) {
        expect(find.text('Revisar 3 gastos'), findsOneWidget);
      } else {
        expect(find.text('Lançar gasto'), findsOneWidget);
        expect(find.text('Diário de hoje'), findsOneWidget);
      }
      if (capturando) {
        await _carregarImagens(tester);
        await _gravar(tester, moldura, '${nome}_360_fonte130');
      }

      await _rolarAteOFim(tester);
      await assentar(tester, total: const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      if (capturando) {
        await _gravar(tester, moldura, '${nome}_360_fonte130_fim');
      }
      // O fim da página: os convites do dono; os gráficos do mestre (que
      // não vê convites).
      expect(find.text('Código da equipe'),
          ehDono ? findsOneWidget : findsNothing);
      if (!ehDono) {
        expect(find.text('GASTOS POR SEMANA'), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
      router.dispose();
      auth.dispose();
    });
  }
}
