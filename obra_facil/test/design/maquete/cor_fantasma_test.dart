// Mede a cor do traço do fantasma nas imagens de reserva (estado_00, a casa
// toda em desenho) e confere que o TemaMaquete.fantasma, a cor que o 3D usa,
// é a mesma: o 3D entra por cima da imagem, e o traço não pode mudar de cor
// na troca. Se as imagens forem renderizadas de novo com outro traço, este
// teste avisa.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/maquete_obra.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';

/// Miolo dos traços: o pixel mais escuro (claro) ou mais claro (escuro) de
/// uma linha da imagem, com vizinhos a 2 px bem mais claros (escuros) dos
/// dois lados. Uma em cada 3 linhas da imagem. Devolve a mediana de R, G, B.
List<int> _miolo(Uint8List rgba, int w, int h, {required bool escuro}) {
  double l(int x, int y) {
    final i = (y * w + x) * 4;
    return (rgba[i] + rgba[i + 1] + rgba[i + 2]) / 3;
  }

  final canais = [<int>[], <int>[], <int>[]];
  for (var y = 0; y < h; y += 3) {
    for (var x = 2; x < w - 2; x++) {
      final v = l(x, y), a = l(x - 2, y), b = l(x + 2, y);
      final miolo = escuro
          ? v > 120 &&
              a < v - 60 &&
              b < v - 60 &&
              v >= l(x - 1, y) &&
              v >= l(x + 1, y)
          : v < 140 &&
              a > v + 60 &&
              b > v + 60 &&
              v <= l(x - 1, y) &&
              v <= l(x + 1, y);
      if (!miolo) continue;
      final i = (y * w + x) * 4;
      for (var c = 0; c < 3; c++) {
        canais[c].add(rgba[i + c]);
      }
    }
  }
  expect(canais[0].length, greaterThan(300),
      reason: 'poucos traços achados: a medição não vale');
  return [
    for (final c in canais) (c..sort())[c.length ~/ 2],
  ];
}

Future<(Uint8List, int, int)> _decodificar(String caminho) async {
  final dados = await rootBundle.load(caminho);
  final codec = await ui.instantiateImageCodec(dados.buffer.asUint8List());
  final quadro = await codec.getNextFrame();
  final img = quadro.image;
  final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final r = (bytes!.buffer.asUint8List(), img.width, img.height);
  img.dispose();
  codec.dispose();
  return r;
}

List<int> _rgb(ui.Color c) => [
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final manifesto = jsonDecode(
    File('assets/3d/maquete.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final opaco = (manifesto['fantasma_opaco'] as Map).cast<String, String>();

  for (final escuro in [false, true]) {
    final nome = escuro ? 'escuro' : 'claro';
    final tema = TemaMaquete.de(escuro: escuro);

    test('traço do fantasma ($nome) = o das imagens de reserva', () async {
      final (rgba, w, h) = await _decodificar(
        MaqueteObra.caminhoReserva(estado: 0, escuro: escuro),
      );
      expect((w, h), (1080, 720));
      final medido = _miolo(rgba, w, h, escuro: escuro);
      final usado = _rgb(tema.fantasma);
      for (var c = 0; c < 3; c++) {
        expect(usado[c], closeTo(medido[c], 8),
            reason: 'canal $c: imagem $medido, app $usado');
      }

      // Controle: o fantasma_opaco do manifesto NÃO é o que a imagem
      // mostra (por isso não é usado). Se a imagem passar a mostrá-lo,
      // é hora de voltar a ele.
      final hex = opaco[nome]!;
      final manifestoRgb = [
        for (var i = 1; i < 7; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
      expect((manifestoRgb[0] - medido[0]).abs(), greaterThan(15),
          reason: 'imagem $medido, manifesto $manifestoRgb');
    });
  }

  test('controle do medidor: acha a cor de traços conhecidos e nada no liso',
      () {
    const w = 300, h = 90;
    Uint8List imagem({required bool comTracos}) {
      final rgba = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final traco = comTracos && x % 20 >= 9 && x % 20 <= 10;
          final i = (y * w + x) * 4;
          rgba
            ..[i] = traco ? 40 : 240
            ..[i + 1] = traco ? 50 : 240
            ..[i + 2] = traco ? 60 : 236
            ..[i + 3] = 255;
        }
      }
      return rgba;
    }

    expect(_miolo(imagem(comTracos: true), w, h, escuro: false), [40, 50, 60]);
    expect(
      () => _miolo(imagem(comTracos: false), w, h, escuro: false),
      throwsA(isA<TestFailure>()),
      reason: 'sem traço, o medidor não pode inventar um',
    );
  });
}
