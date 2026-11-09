// O 3D de verdade em imagem: a maquete e a vista 360° desenhadas pelo
// flutter_scene (Impeller com Vulkan por software), em PNG. Para conferir
// luz, sombra e móveis sem celular. Pulado sem RENDER_3D.
//
//   apt-get install mesa-vulkan-drivers   # o Vulkan por software (lavapipe)
//   RENDER_3D=1 SAIDA=/pasta JOBS=ext:gem160:0 flutter test \
//     --enable-impeller --enable-flutter-gpu test/visual/render_3d_test.dart
//
// Uma vista por processo (a segunda casa gerada no mesmo processo de teste
// fica carregando). JOBS:
//   ext:<modelo>:<giro>[:escuro]            a maquete pronta, vista de fora
//   int:<modelo>:<cômodo>[:<giro>[:noite]]  o 360° do cômodo (o widget)
// Modelos: gem160 (geminado de sobrados), casa120 (térrea), predio.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/design.dart';
import 'package:obra_facil/design/maquete/cena_maquete.dart';
import 'package:obra_facil/design/maquete/fonte_maquete.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';
import 'package:obra_facil/design/maquete/progresso_maquete.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/screens/planta/vista_360_screen.dart';

import 'suporte/captura.dart';

PlantaObra _modelo(String chave) => switch (chave) {
      'gem160' => ModelosPlanta.montar(const PedidoModelo(
          tipo: TipoModelo.geminado,
          area: 160,
          quartos: 3,
          unidades: 2,
          sobrado: true)),
      'casa120' => ModelosPlanta.montar(
          const PedidoModelo(tipo: TipoModelo.casa, area: 120, quartos: 3)),
      'predio' => ModelosPlanta.montar(
          const PedidoModelo(tipo: TipoModelo.predio, area: 60, quartos: 2)),
      _ => throw ArgumentError(chave),
    };

Future<void> _esperar(WidgetTester tester, int vezes) async {
  for (var i = 0; i < vezes; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _gravar(
    WidgetTester tester, GlobalKey chave, String arquivo, double razao) async {
  final bytes = await tester.runAsync(() async {
    final ro =
        chave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: razao);
    return (await img.toByteData(format: ui.ImageByteFormat.png))!;
  });
  File(arquivo).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  final saida = Platform.environment['SAIDA'] ?? '/tmp';
  final jobs = (Platform.environment['JOBS'] ?? 'ext:gem160:0').split(',');
  final largura = double.parse(Platform.environment['LARGURA'] ?? '400');
  final altura = double.parse(Platform.environment['ALTURA'] ?? '300');
  final razao = double.parse(Platform.environment['RAZAO'] ?? '2');

  setUpAll(prepararCapturas);
  final pular = Platform.environment['RENDER_3D'] == null;
  for (final job in jobs) {
    testWidgets(skip: pular, job, (tester) async {
      FontePlanta.esquecer();
      final view = tester.view
        ..devicePixelRatio = razao
        ..physicalSize = Size(largura, altura) * razao;
      addTearDown(view.reset);
      final partes = job.split(':');
      final planta = _modelo(partes[1]);
      final arquivo = '$saida/${partes.join('_')}.png';
      final chave = GlobalKey();
      final cronometro = Stopwatch()..start();
      if (partes[0] == 'ext') {
        final escuro = partes.length > 3 && partes[3] == 'escuro';
        final cena = (await tester.runAsync(() => CenaMaquete.carregarDaPlanta(
            tema: TemaMaquete.de(escuro: escuro),
            fonte: FontePlanta(planta))))!;
        cena.aplicar(PlanoMaquete.calcular(
            List<double>.filled(ProgressoMaquete.totalFases, 1)));
        await tester.pumpWidget(ColoredBox(
          color: escuro ? const Color(0xFF1B1D1F) : const Color(0xFFF4F5F3),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: chave,
              child: cena.vista(
                  proporcao: largura / altura,
                  giro: double.parse(partes[2]),
                  aoDesenhar: () {},
                  aoFalhar: (e) => debugPrint('FALHA $e')),
            ),
          ),
        ));
        await _esperar(tester, 60);
        debugPrint('$job: ${cena.ultimoQuadro} '
            '${cronometro.elapsedMilliseconds} ms');
        await _gravar(tester, chave, arquivo, razao);
        cena.descartar();
      } else {
        final comodo =
            planta.todosOsComodos.firstWhere((c) => c.id == partes[2]);
        final indice = planta.plantaDoComodo(comodo.id);
        await tester.pumpWidget(MaterialApp(
          theme: TemaPrancheta.claro,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: chave,
              child: Interior360(
                planta: planta,
                comodo: comodo,
                pavimento: planta.pavimentoDaPlanta(math.max(0, indice)),
                giroInicial: partes.length > 3 ? double.parse(partes[3]) : null,
                noiteInicial: partes.length > 4 && partes[4] == 'noite',
              ),
            ),
          ),
        ));
        // Gerar a casa mobiliada (isolate) e aquecer os shaders.
        for (var i = 0;
            i < 400 && find.byType(IndicadorCarregando).evaluate().isNotEmpty;
            i++) {
          await _esperar(tester, 1);
        }
        await _esperar(tester, 60);
        debugPrint('$job: ${cronometro.elapsedMilliseconds} ms');
        await _gravar(tester, chave, arquivo, razao);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      await _esperar(tester, 5);
    });
  }
}
