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

/// Foto grande (900x675, em JPEG 70 como o app guarda) com o seu próprio
/// ruído de sensor: [ruido] é o desvio, em níveis de 0 a 255. Duas fotos de
/// verdade nunca têm o mesmo ruído — os testes de cima usam a mesma semente
/// nas duas e por isso não pegavam a equalização esticando o ruído.
Uint8List _fotoGrande(int semente, double Function(int x, int y) tom,
    {double ruido = 2}) {
  const largura = 900, altura = 675;
  final imagem = img.Image(width: largura, height: altura);
  final r = Random(semente);
  for (var y = 0; y < altura; y++) {
    for (var x = 0; x < largura; x++) {
      final u1 = r.nextDouble().clamp(1e-9, 1.0), u2 = r.nextDouble();
      final n = sqrt(-2 * log(u1)) * cos(2 * pi * u2) * ruido;
      final v = (tom(x, y) + n).round().clamp(0, 255);
      imagem.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodeJpg(imagem, quality: 70));
}

/// Parede rebocada ou pintada, quase de um tom só (um leve degradê de
/// luz). [janela] abre um vão escuro no meio.
Uint8List _paredeLisa(int semente, {double ruido = 2, bool janela = false}) =>
    _fotoGrande(semente, ruido: ruido, (x, y) {
      if (janela && x > 350 && x < 550 && y > 200 && y < 420) return 60;
      return 180 + 10 * x / 900;
    });

/// Parede de tijolo à vista (fiada de 22 px, tijolo de 60 px, junta de
/// 4 px), do mesmo ponto.
Uint8List _paredeDeTijolo(int semente) => _fotoGrande(semente, (x, y) {
      final desloc = (y ~/ 22).isEven ? 0 : 30;
      return (y % 22) < 4 || ((x + desloc) % 60) < 4 ? 170 : 110;
    });

/// A cena de [_foto] numa foto grande, com ruído próprio em vez da
/// textura fixa.
Uint8List _canteiroGrande(int semente, {bool paredeNova = false}) =>
    _fotoGrande(semente, ruido: 3, (x, y) {
      final xx = x * 160 ~/ 900, yy = y * 120 ~/ 675;
      if (xx >= 40 && xx < 58 && yy >= 50 && yy < 70) return 40;
      if (xx >= 20 && xx < 80 && yy >= 30 && yy < 100) return 170;
      if (paredeNova && xx >= 95 && xx < 145 && yy >= 40 && yy < 100) {
        return 150;
      }
      return yy < 45 ? 200.0 - yy : 110;
    });

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

  group('Ruído de câmera não é mudança', () {
    test('duas fotos da mesma parede lisa não mostram mudança', () async {
      // Antes, a equalização esticava ±2 níveis de ruído em dezenas, e o
      // Sobel com corte relativo transformava isso em bordas: 37%.
      expect(await _indice(_paredeLisa(1), _paredeLisa(2)), lessThan(0.10));
    });

    test('nem com o ruído forte de pouca luz', () async {
      expect(
        await _indice(_paredeLisa(1, ruido: 5), _paredeLisa(2, ruido: 5)),
        lessThan(0.10),
      );
    });

    test('a mesma parede de tijolo, do mesmo ponto, não mostra mudança',
        () async {
      expect(
        await _indice(_paredeDeTijolo(1), _paredeDeTijolo(2)),
        lessThan(0.10),
      );
    });

    test('um vão aberto na parede lisa continua contando', () async {
      final igual = await _indice(_paredeLisa(1), _paredeLisa(2));
      final comVao =
          await _indice(_paredeLisa(1), _paredeLisa(2, janela: true));
      expect(comVao, greaterThanOrEqualTo(0.30));
      expect(comVao, greaterThan(igual * 3));
    });

    test('o reboco sobre o tijolo continua contando', () async {
      // Tirar o ruído não pode apagar a mudança de superfície inteira.
      expect(
        await _indice(_paredeDeTijolo(1), _paredeLisa(2)),
        greaterThanOrEqualTo(0.30),
      );
    });

    test('a parede nova se separa do ruído da mesma cena', () async {
      // Com ruído próprio em cada foto, a cena igual dava 12% e a parede
      // nova 13%: o índice não separava uma coisa da outra.
      final igual = await _indice(_canteiroGrande(1), _canteiroGrande(2));
      final comParede = await _indice(
          _canteiroGrande(1), _canteiroGrande(2, paredeNova: true));
      expect(igual, lessThan(0.10));
      expect(comParede, greaterThanOrEqualTo(0.10));
      expect(comParede, greaterThan(igual * 2));
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
