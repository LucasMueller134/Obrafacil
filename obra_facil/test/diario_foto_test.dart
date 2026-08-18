import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/diario_foto_service.dart';

void main() {
  group('Leitura da foto do canteiro', () {
    test('parede de tijolo vira material e fase de alvenaria', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Brick', 0.91),
        RotuloFoto('Wall', 0.78),
        RotuloFoto('Sky', 0.55),
      ]);

      expect(a.materiais, contains('Tijolo'));
      expect(a.faseSugerida, 'Alvenaria');
      expect(a.climaSugerido, 'Ensolarado');
      expect(a.encontrouAlgo, isTrue);
    });

    test('telhado indica cobertura', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Roof', 0.88),
        RotuloFoto('Wood', 0.61),
      ]);
      expect(a.faseSugerida, 'Cobertura');
      expect(a.materiais, containsAll(<String>['Telha', 'Madeira']));
    });

    test('pessoas na foto são sinalizadas', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Person', 0.83),
        RotuloFoto('Helmet', 0.52),
      ]);
      expect(a.temPessoas, isTrue);
      expect(a.descricaoSugerida, contains('equipe'));
    });

    test('céu chuvoso é sugerido como clima', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Rain', 0.72),
        RotuloFoto('Cloud', 0.70),
      ]);
      expect(a.climaSugerido, 'Chuvoso');
    });

    test('rótulo mais confiante manda no clima', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Cloud', 0.51),
        RotuloFoto('Sky', 0.93),
      ]);
      expect(a.climaSugerido, 'Ensolarado');
    });

    test('um indício fraco não inventa fase', () {
      // "Furniture" sozinho pesa 1 — não basta para sugerir acabamento.
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Furniture', 0.62),
      ]);
      expect(a.faseSugerida, isNull);
    });

    test('foto irreconhecível não gera rascunho', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Selfie', 0.90),
        RotuloFoto('Smile', 0.71),
      ]);
      expect(a.encontrouAlgo, isFalse);
      expect(a.descricaoSugerida, isEmpty);
      expect(a.materiais, isEmpty);
    });

    test('rascunho de descrição cita fase e materiais', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Tile', 0.90),
        RotuloFoto('Flooring', 0.64),
      ]);
      expect(a.faseSugerida, 'Revestimentos');
      expect(a.descricaoSugerida.toLowerCase(), contains('revestimentos'));
      expect(a.descricaoSugerida, endsWith('.'));
    });
  });
}
