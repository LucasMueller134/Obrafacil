// Custo de desenho da maquete da abertura e do login.
//
// No Impeller não há cache de rasterização: tudo que a maquete desenha
// é refeito a cada quadro da tela. Desfoque e recorte são os comandos
// caros (cada um vira passes fora da tela), e com o Impeller em OpenGL,
// como em muitos celulares MediaTek, 200 deles por quadro travavam o
// login. Estes testes contam os comandos de um quadro.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/widgets/tres_d/cena_obra_3d.dart';

/// Canvas que só conta o que a maquete pede para desenhar.
class _CanvasContador implements Canvas {
  final chamadas = <String, int>{};
  var desfoques = 0;

  int de(String nome) => chamadas[nome] ?? 0;

  @override
  dynamic noSuchMethod(Invocation chamada) {
    final nome = chamada.memberName
        .toString()
        .replaceAll('Symbol("', '')
        .replaceAll('")', '');
    chamadas[nome] = (chamadas[nome] ?? 0) + 1;
    for (final argumento in chamada.positionalArguments) {
      if (argumento is Paint &&
          (argumento.maskFilter != null || argumento.imageFilter != null)) {
        desfoques++;
      }
    }
    return null;
  }
}

Widget _cena({required bool animando}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 320,
          child: CenaObraTresD(animando: animando),
        ),
      ),
    );

Finder get _pintura => find.descendant(
      of: find.byType(CenaObraTresD),
      matching: find.byType(CustomPaint),
    );

void main() {
  testWidgets('girando, um quadro tem um desfoque só e nenhum recorte',
      (tester) async {
    await tester.pumpWidget(_cena(animando: true));
    for (var segundo = 0; segundo < 4; segundo++) {
      await tester.pump(const Duration(seconds: 3));
      final pintor = tester.widget<CustomPaint>(_pintura.first).painter!;
      final canvas = _CanvasContador();
      pintor.paint(canvas, const Size(360, 320));

      // A maquete continua lá (faces, sombra e textura)...
      expect(canvas.de('drawPath'), greaterThan(100));
      // ...mas a sombra vai numa camada com um desfoque para tudo,
      expect(canvas.desfoques, 1);
      expect(canvas.de('saveLayer'), 1);
      // a textura não recorta a face,
      expect(canvas.de('clipPath'), 0);
      // e cada grupo de linhas da textura é um traço só.
      expect(canvas.de('drawLine'), 0);
    }
    // Para o teste terminar sem animação pendente.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('parada, a maquete vira imagem e não é redesenhada',
      (tester) async {
    await tester.pumpWidget(_cena(animando: false));

    final imagem = find.descendant(
      of: find.byType(CenaObraTresD),
      matching: find.byType(RawImage),
    );
    expect(imagem, findsOneWidget);
    // Nenhuma pintura ao vivo: o quadro só copia a imagem pronta.
    expect(
      tester.widgetList<CustomPaint>(_pintura).where((p) => p.painter != null),
      isEmpty,
    );

    // Outro quadro da tela (cursor, teclado) reaproveita a mesma imagem.
    final antes = tester.widget<RawImage>(imagem).image;
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<RawImage>(imagem).image, same(antes));

    // Imagem na resolução da tela, para não sair borrada.
    final densidade = tester.view.devicePixelRatio;
    expect(antes!.width, (360 * densidade).ceil());
    expect(antes.height, (320 * densidade).ceil());
  });

  testWidgets('parada, muda de tamanho e a imagem acompanha', (tester) async {
    await tester.pumpWidget(_cena(animando: false));
    final imagem = find.descendant(
      of: find.byType(CenaObraTresD),
      matching: find.byType(RawImage),
    );
    final antes = tester.widget<RawImage>(imagem).image!;

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 170,
          child: CenaObraTresD(animando: false),
        ),
      ),
    ));
    final depois = tester.widget<RawImage>(imagem).image!;
    expect(depois, isNot(same(antes)));
    expect(depois.height, (170 * tester.view.devicePixelRatio).ceil());
  });
}
