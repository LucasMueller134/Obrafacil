// Capturas da MaqueteObra na imagem de reserva (o que aparece sem Flutter
// GPU, com "reduzir animações" e enquanto o 3D carrega), claro e escuro.
//
//   CAPTURAR=maquete flutter test test/design/maquete/captura_maquete_test.dart
//
// grava os PNG em docs/redesign/maquete/ (a pasta é sempre essa; o valor de
// CAPTURAR só liga a gravação). Sem CAPTURAR, os testes são pulados.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/maquete.dart';

import '../../visual/suporte/fontes.dart';

final bool _capturando =
    (Platform.environment['CAPTURAR'] ?? '').trim().isNotEmpty;

const double _largura = 390;
const double _pixelRatio = 3;

/// Papel da spec (fundo das telas), claro e escuro.
const _papel = {
  Brightness.light: Color(0xFFF4F5F3),
  Brightness.dark: Color(0xFF121315),
};

class _Caso {
  const _Caso(this.nome, this.progresso, {this.altura = 220});

  final String nome;
  final ProgressoMaquete progresso;
  final double altura;
}

final _casos = [
  _Caso('estado_00_sem_cronograma', ProgressoMaquete.vazio),
  _Caso(
    'estado_02_alvenaria_em_andamento',
    ProgressoMaquete.fases([1, 1, 0.38], percentualObra: 38),
  ),
  _Caso('estado_05_eletrica_pronta', ProgressoMaquete.estado(5)),
  _Caso('estado_10_obra_pronta', ProgressoMaquete.estado(10)),
  _Caso(
    'estado_02_altura_144',
    ProgressoMaquete.fases([1, 1, 0.38], percentualObra: 38),
    altura: 144,
  ),
];

Directory _pasta() {
  var dir = Directory.current.absolute;
  while (true) {
    final redesign = Directory('${dir.path}/docs/redesign');
    if (redesign.existsSync()) return Directory('${redesign.path}/maquete');
    final pai = dir.parent;
    if (pai.path == dir.path) {
      throw StateError('docs/redesign/ não encontrado acima de '
          '${Directory.current.path}');
    }
    dir = pai;
  }
}

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
  fail('as imagens de reserva não decodificaram');
}

void main() {
  setUpAll(() async {
    if (_capturando) await carregarFontes();
  });

  for (final brilho in [Brightness.light, Brightness.dark]) {
    final tema = brilho == Brightness.dark ? 'escuro' : 'claro';
    for (final caso in _casos) {
      testWidgets('maquete_${tema}_${caso.nome}', (tester) async {
        final view = tester.view
          ..devicePixelRatio = _pixelRatio
          ..physicalSize = const Size(_largura, 400) * _pixelRatio;
        addTearDown(view.reset);
        final papel = _papel[brilho]!;
        final moldura = GlobalKey();

        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: brilho),
          home: Scaffold(
            backgroundColor: papel,
            body: Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                key: moldura,
                child: SizedBox(
                  width: _largura,
                  child: ColoredBox(
                    color: papel,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MaqueteObra(
                        progresso: caso.progresso,
                        altura: caso.altura,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        // O caminho de verdade: sem Impeller no teste, a maquete cai na
        // imagem (e não fica em "carregando").
        expect(MaqueteObra.diagnosticoGlobal.value.modo, ModoMaquete.imagem);
        await _carregarImagens(tester);
        expect(tester.takeException(), isNull);
        expect(familiasNaoCarregadas(), isEmpty);

        final arquivo =
            File('${_pasta().path}/maquete_${tema}_${caso.nome}.png');
        await tester.runAsync(() async {
          final limite = moldura.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final imagem = await limite.toImage(pixelRatio: _pixelRatio);
          final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
          imagem.dispose();
          arquivo.parent.createSync(recursive: true);
          arquivo.writeAsBytesSync(png!.buffer.asUint8List());
        });
      }, skip: !_capturando);
    }
  }
}
