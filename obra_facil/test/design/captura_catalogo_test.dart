// Captura do catálogo do design system, claro e escuro, com as fontes de
// verdade (as do pubspec e os ícones Material, pelo carregarFontes() das
// capturas de test/visual). Só roda com a variável CAPTURAR definida:
//
//   CAPTURAR=1 flutter test test/design/captura_catalogo_test.dart
//
// Grava docs/redesign/catalogo/catalogo_{claro,escuro}.png (na raiz do
// repositório), com a página inteira, sem rolagem. Com LARGURA=360 (ou
// outra), captura nessa largura em dp e grava catalogo_{tema}_360.png, para
// conferir o celular estreito.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/catalogo_design.dart';
import 'package:obra_facil/design/tato.dart';

import '../visual/suporte/fontes.dart';

final double _largura =
    double.tryParse(Platform.environment['LARGURA'] ?? '') ?? 390;
final String _sufixo = _largura == 390 ? '' : '_${_largura.round()}';
const _altura = 844.0;
const _densidade = 2.0;
const _pasta = '../docs/redesign/catalogo';

final bool _capturar = Platform.environment.containsKey('CAPTURAR');

void main() {
  setUpAll(() async {
    Tato.ativo = false;
    if (_capturar) await carregarFontes();
  });

  for (final brilho in Brightness.values) {
    final nome = brilho == Brightness.dark ? 'escuro' : 'claro';
    testWidgets('captura do catálogo ($nome)', (tester) async {
      // O flutter_test troca sombra por contorno preto; a captura quer ver
      // se sobrou alguma sombra de verdade (não deveria).
      debugDisableShadows = false;
      try {
        await _capturarCatalogo(tester, brilho, nome);
      } finally {
        debugDisableShadows = true;
      }
    }, skip: !_capturar);
  }
}

Future<void> _capturarCatalogo(
  WidgetTester tester,
  Brightness brilho,
  String nome,
) async {
  final moldura = GlobalKey();
  final view = tester.view;
  view.devicePixelRatio = _densidade;
  view.physicalSize = Size(_largura, _altura) * _densidade;
  addTearDown(view.reset);

  // A maquete de reserva é decodificada de verdade antes de entrar.
  await tester.pumpWidget(const SizedBox());
  final contexto = tester.element(find.byType(SizedBox));
  await tester.runAsync(() => precacheImage(
        AssetImage('assets/3d/reserva/$nome/estado_04.webp'),
        contexto,
      ));

  await tester.pumpWidget(RepaintBoundary(
    key: moldura,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CatalogoDesign(brilho: brilho),
    ),
  ));
  await tester.pump(const Duration(seconds: 1));

  // Estica a tela até caber o catálogo inteiro.
  final rolagem = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final sobra = rolagem.position.maxScrollExtent;
  view.physicalSize = Size(_largura, _altura + sobra) * _densidade;
  await tester.pump(const Duration(seconds: 1));
  // Instante da foto: a varredura (ida e volta em 3,2 s) passa pelo meio
  // do cupom e o indicador de carregamento (ciclo de 1,33 s) está aberto,
  // longe do ponto em que o arco quase some.
  await tester.pump(const Duration(milliseconds: 8400));

  expect(tester.takeException(), isNull);
  expect(familiasNaoCarregadas(), isEmpty,
      reason: 'texto fora das fontes carregadas (sairia em blocos)');

  await tester.runAsync(() async {
    final limite =
        moldura.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagem = await limite.toImage(pixelRatio: _densidade);
    final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
    imagem.dispose();
    Directory(_pasta).createSync(recursive: true);
    File('$_pasta/catalogo_$nome$_sufixo.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}
