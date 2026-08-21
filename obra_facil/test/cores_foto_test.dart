import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obra_facil/services/ia/cores_foto.dart';
import 'package:obra_facil/services/ia/diario_foto_service.dart';

/// Imagem de teste: [fracaoCeu] do topo com a cor do céu, o resto com a
/// cor do chão. É o formato de uma foto de canteiro.
img.Image _cena({
  required (int, int, int) chao,
  (int, int, int)? ceu,
  double fracaoCeu = 0.28,
}) {
  final imagem = img.Image(width: 100, height: 100);
  final limite = (100 * fracaoCeu).round();
  for (var y = 0; y < 100; y++) {
    for (var x = 0; x < 100; x++) {
      final cor = (ceu != null && y < limite) ? ceu : chao;
      imagem.setPixelRgb(x, y, cor.$1, cor.$2, cor.$3);
    }
  }
  return imagem;
}

// Cores reais de canteiro, tiradas de tons médios de foto.
const _terra = (139, 105, 68); // barranco / aterro
const _tijolo = (170, 63, 42); // cerâmica vermelha
const _concreto = (150, 150, 152); // concreto curado
const _parede = (238, 236, 232); // parede pintada
const _mato = (86, 130, 58); // vegetação
const _ceuAzul = (110, 165, 225);
const _ceuCinza = (205, 208, 212);

void main() {
  group('Leitura das cores da foto', () {
    test('barranco de terra é reconhecido como terra', () {
      final p = CoresFoto.analisar(_cena(chao: _terra, ceu: _ceuAzul));
      expect(p.terra, greaterThan(0.5));
      expect(p.tijolo, lessThan(0.05));
    });

    test('parede de tijolo é reconhecida como tijolo', () {
      final p = CoresFoto.analisar(_cena(chao: _tijolo, ceu: _ceuAzul));
      expect(p.tijolo, greaterThan(0.5));
      expect(p.terra, lessThan(0.15));
    });

    test('concreto cai em cinza, não em terra', () {
      final p = CoresFoto.analisar(_cena(chao: _concreto, ceu: _ceuCinza));
      expect(p.concreto, greaterThan(0.5));
      expect(p.terra, lessThan(0.05));
    });

    test('parede pintada cai em claro', () {
      final p = CoresFoto.analisar(_cena(chao: _parede));
      expect(p.claro, greaterThan(0.5));
    });

    test('mato é separado da terra', () {
      final p = CoresFoto.analisar(_cena(chao: _mato));
      expect(p.vegetacao, greaterThan(0.5));
      expect(p.terra, lessThan(0.05));
    });
  });

  group('Clima pelo céu', () {
    test('céu azul é dia de sol', () {
      final p = CoresFoto.analisar(_cena(chao: _terra, ceu: _ceuAzul));
      expect(p.climaPeloCeu, 'Ensolarado');
    });

    test('céu branco fechado é nublado', () {
      final p = CoresFoto.analisar(_cena(chao: _terra, ceu: _ceuCinza));
      expect(p.climaPeloCeu, 'Nublado');
    });

    test('foto sem céu não opina sobre o tempo', () {
      // Foto de detalhe, tirada apontando para baixo.
      final p = CoresFoto.analisar(_cena(chao: _concreto));
      expect(p.climaPeloCeu, isNull);
    });
  });

  group('Cor somada ao classificador', () {
    test('barranco decide a fundação mesmo sem rótulo de terra', () {
      // O caso do canteiro real: o modelo devolveu "Roof" e nenhum
      // rótulo de solo, mas metade da foto é barranco.
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Roof', 0.72), RotuloFoto('Wood', 0.66)],
        paleta: CoresFoto.analisar(_cena(chao: _terra, ceu: _ceuAzul)),
      );
      expect(a.faseSugerida, 'Fundação');
      expect(a.materiais, isNot(contains('Telha')));
      expect(a.climaSugerido, 'Ensolarado');
    });

    test('cor de tijolo reforça alvenaria', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Wall', 0.70)],
        paleta: CoresFoto.analisar(_cena(chao: _tijolo, ceu: _ceuAzul)),
      );
      expect(a.faseSugerida, 'Alvenaria');
      expect(a.confiancaFase, greaterThan(0.5));
    });

    test('foto sem evidência não inventa fase', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Selfie', 0.90)],
        paleta: CoresFoto.analisar(_cena(chao: _mato)),
      );
      expect(a.faseSugerida, isNull);
      expect(a.confiancaFase, 0);
    });

    test('chuva vista pelo modelo vence o céu claro da cor', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Rain', 0.80)],
        paleta: CoresFoto.analisar(_cena(chao: _terra, ceu: _ceuCinza)),
      );
      expect(a.climaSugerido, 'Chuvoso');
    });

    test('sem análise de cor, segue funcionando como antes', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Brick', 0.90), RotuloFoto('Wall', 0.70)],
      );
      expect(a.faseSugerida, 'Alvenaria');
      expect(a.materiais, contains('Tijolo'));
    });
  });
}
