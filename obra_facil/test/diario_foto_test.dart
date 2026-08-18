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

    test('telhado com madeiramento indica cobertura', () {
      // "Roof" precisa de um segundo rótulo de telhado para valer: sozinho
      // ele aparece em qualquer estrutura vista de cima.
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Roof', 0.88),
        RotuloFoto('Shingle', 0.66),
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

    test('baldrame armado não vira cobertura (caso do canteiro real)', () {
      // Foto de fundação: formas de madeira, armação de ferragem, sapatas
      // concretadas e o barranco da escavação. O modelo genérico devolve
      // "Roof" para a laje vista de cima — sozinho isso não pode decidir.
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Roof', 0.72),
        RotuloFoto('Wood', 0.68),
        RotuloFoto('Soil', 0.63),
        RotuloFoto('Metal', 0.57),
        RotuloFoto('Concrete', 0.51),
      ]);

      expect(a.faseSugerida, 'Fundação');
      expect(a.materiais, isNot(contains('Telha')));
      expect(a.materiais, contains('Vergalhão de aço'));
      expect(a.materiais, containsAll(<String>['Madeira', 'Concreto']));
    });

    test('"Roof" sozinho não sugere cobertura nem telha', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Roof', 0.80),
        RotuloFoto('Wood', 0.55),
      ]);
      expect(a.faseSugerida, isNull);
      expect(a.materiais, isNot(contains('Telha')));
    });

    test('telhado confirmado por um segundo rótulo continua valendo', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Roof', 0.86),
        RotuloFoto('Shingle', 0.61),
      ]);
      expect(a.faseSugerida, 'Cobertura');
      expect(a.materiais, contains('Telha'));
    });

    test('tela de ferragem não vira instalação elétrica', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Wire', 0.74),
        RotuloFoto('Metal', 0.66),
        RotuloFoto('Soil', 0.58),
      ]);
      expect(a.materiais, isNot(contains('Fio elétrico')));
      expect(a.materiais, contains('Vergalhão de aço'));
      expect(a.faseSugerida, isNot('Instalações elétricas'));
    });

    test('contrapiso de concreto não vira piso cerâmico', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Floor', 0.77),
        RotuloFoto('Concrete', 0.70),
      ]);
      expect(a.materiais, isNot(contains('Piso cerâmico')));
      expect(a.materiais, contains('Concreto'));
    });

    test('sem terra à mostra, concreto e ferragem são estrutura', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Concrete', 0.81),
        RotuloFoto('Scaffolding', 0.60),
      ]);
      expect(a.faseSugerida, 'Estrutura');
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
