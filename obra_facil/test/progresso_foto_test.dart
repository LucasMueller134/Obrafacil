import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obra_facil/services/ia/progresso_foto_service.dart';

/// Cena de canteiro sintética: céu, chão, uma parede com janela e uma
/// textura fixa por cima (a mesma semente nas duas fotos, como o reboco
/// que não muda de um dia para o outro).
///
/// [luz] multiplica o brilho (0,5 = foto bem mais escura); [gama] muda o
/// contraste; [paredeNova] levanta uma segunda parede; [deslocamento] move
/// a câmera alguns pixels para o lado.
Uint8List _foto({
  double luz = 1,
  double gama = 1,
  bool paredeNova = false,
  int deslocamento = 0,
}) {
  const largura = 160, altura = 120;
  final imagem = img.Image(width: largura, height: altura);
  final textura = Random(7);
  for (var y = 0; y < altura; y++) {
    for (var x = 0; x < largura; x++) {
      final xx = x + deslocamento;
      var tom = y < 45 ? 200 - y : 110; // céu em degradê, chão escuro
      if (xx >= 20 && xx < 80 && y >= 30 && y < 100) tom = 170; // parede
      if (xx >= 40 && xx < 58 && y >= 50 && y < 70) tom = 40; // janela
      if (paredeNova && xx >= 95 && xx < 145 && y >= 40 && y < 100) {
        tom = 150;
      }
      tom += textura.nextInt(13) - 6;
      final normalizado = pow((tom.clamp(0, 255)) / 255, gama) * luz;
      final v = (normalizado * 255).round().clamp(0, 255);
      imagem.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(imagem));
}

/// Imagem sem relação nenhuma com a cena: outro lugar, outro enquadramento.
Uint8List _outraCena() {
  final imagem = img.Image(width: 160, height: 120);
  final r = Random(99);
  for (var y = 0; y < 120; y++) {
    for (var x = 0; x < 160; x++) {
      final faixa = ((x + y) ~/ 12).isEven ? 60 : 190;
      final v = (faixa + r.nextInt(31) - 15).clamp(0, 255);
      imagem.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(imagem));
}

Future<double> _indice(Uint8List a, Uint8List b) async =>
    (await ProgressoFotoService.compararBytes(a, b)).indiceMudanca;

void main() {
  group('Comparação visual entre fotos', () {
    test('a mesma foto não mostra mudança', () async {
      expect(await _indice(_foto(), _foto()), lessThan(0.05));
    });

    test('a mesma cena com outra luz dá índice baixo', () async {
      // Manhã e fim de tarde: antes da equalização, isto dava "mudança
      // grande".
      final r =
          await ProgressoFotoService.compararBytes(_foto(), _foto(luz: 0.55));
      expect(r.indiceMudanca, lessThan(0.10));
      expect(r.luzMuitoDiferente, isTrue);
    });

    test('a mesma cena com outro contraste dá índice baixo', () async {
      expect(await _indice(_foto(), _foto(gama: 1.6)), lessThan(0.10));
    });

    test('uma parede nova muda mais que a luz', () async {
      final soLuz = await _indice(_foto(), _foto(luz: 0.6));
      final comParede = await _indice(_foto(), _foto(paredeNova: true));
      expect(comParede, greaterThanOrEqualTo(0.10));
      expect(comParede, greaterThan(soLuz * 2));
    });

    test('parede nova vista com outra luz continua contando', () async {
      final r = await _indice(_foto(), _foto(paredeNova: true, luz: 0.6));
      expect(r, greaterThanOrEqualTo(0.10));
    });

    test('a mão que treme um pouco não vira mudança grande', () async {
      expect(await _indice(_foto(), _foto(deslocamento: 2)), lessThan(0.30));
    });

    test('cenas sem relação dão mudança grande', () async {
      expect(await _indice(_foto(), _outraCena()), greaterThanOrEqualTo(0.55));
    });

    test('foto ilegível é erro, não "nenhuma mudança"', () async {
      expect(
        ProgressoFotoService.compararBytes(
            Uint8List.fromList([1, 2, 3]), _foto()),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Texto da comparação', () {
    test('fala de mudança visual e não promete avanço da obra', () {
      for (final indice in [0.05, 0.2, 0.4, 0.8]) {
        final texto = ComparacaoFotos(indiceMudanca: indice).interpretacao;
        expect(texto.toLowerCase(), contains('mudança visual'));
        expect(texto.toLowerCase(), isNot(contains('avan')));
      }
    });

    test('luz parecida não gera aviso', () {
      expect(
        const ComparacaoFotos(indiceMudanca: 0.3, diferencaDeLuz: 0.05)
            .luzMuitoDiferente,
        isFalse,
      );
    });
  });
}
