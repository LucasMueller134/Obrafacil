import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/cores_foto.dart';
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

  group('Telhado só com evidência de telhado', () {
    test('baldrame com "Shingle" e solo não lista telha nem vira cobertura',
        () {
      // O modelo genérico chegou a devolver "Shingle" para as formas do
      // baldrame vistas de cima. Com terra à mostra, isso não basta.
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Wood', 0.81),
          RotuloFoto('Roof', 0.74),
          RotuloFoto('Soil', 0.66),
          RotuloFoto('Building', 0.60),
          RotuloFoto('Shingle', 0.55),
          RotuloFoto('Metal', 0.52),
        ],
        paleta: const PaletaObra(terra: 0.30, concreto: 0.20, ceuAzul: 0.3),
      );
      expect(a.materiais, isNot(contains('Telha')));
      expect(a.faseSugerida, 'Fundação');
      expect(a.materiais, containsAll(<String>['Madeira', 'Vergalhão de aço']));
    });

    test(
        'com terra à mostra, telhado ainda vale se a evidência for muito '
        'forte', () {
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Roof tile', 0.84),
        RotuloFoto('Shingle', 0.77),
        RotuloFoto('Roof', 0.70),
        RotuloFoto('Soil', 0.50),
      ]);
      expect(a.faseSugerida, 'Cobertura');
      expect(a.materiais, contains('Telha'));
    });

    test('telha cerâmica sob o céu é cobertura, não alvenaria', () {
      // O vermelho da telha cai na mesma cor do tijolo; quem diz que é
      // telhado é o rótulo "Roof" com céu na foto.
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Roof', 0.82), RotuloFoto('Sky', 0.71)],
        paleta: const PaletaObra(tijolo: 0.42, ceuAzul: 0.55),
      );
      expect(a.faseSugerida, 'Cobertura');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
      expect(a.materiais, contains('Telha'));
      expect(a.materiais, isNot(contains('Tijolo')));
    });

    test('com "Shingle" confirmando o telhado, até o "Brick" é a telha', () {
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Roof', 0.80),
          RotuloFoto('Brick', 0.66),
          RotuloFoto('Shingle', 0.61),
        ],
        paleta: const PaletaObra(tijolo: 0.38, ceuAzul: 0.4),
      );
      expect(a.faseSugerida, 'Cobertura');
      expect(a.materiais, contains('Telha'));
      expect(a.materiais, isNot(contains('Tijolo')));
    });

    test(
        'vermelho com "Roof" mas sem céu nem telhado específico segue '
        'sendo tijolo', () {
      // Parede de tijolo vista de cima: o "Roof" é o ângulo, não telhado.
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Roof', 0.70), RotuloFoto('Brick', 0.66)],
        paleta: const PaletaObra(tijolo: 0.40, concreto: 0.2),
      );
      expect(a.faseSugerida, 'Alvenaria');
      expect(a.materiais, isNot(contains('Telha')));
    });
  });

  group('Madeira não é barranco', () {
    test('forma de laje vista de cima não vira fundação', () {
      // Paleta como a análise antiga media: a madeira da forma entrava
      // como "terra". Dois rótulos de madeira e nenhum de solo dizem que o
      // marrom é a forma.
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Wood', 0.86),
          RotuloFoto('Roof', 0.71),
          RotuloFoto('Floor', 0.64),
          RotuloFoto('Plank', 0.58),
        ],
        paleta: const PaletaObra(terra: 0.62, concreto: 0.12),
      );
      expect(a.faseSugerida, 'Estrutura');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
      expect(a.materiais, contains('Madeira'));
      expect(a.materiais, isNot(contains('Telha')));
    });

    test('forma de laje com a madeira medida pela cor também é estrutura', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Wood', 0.80), RotuloFoto('Roof', 0.68)],
        paleta: const PaletaObra(madeira: 0.55, concreto: 0.10),
      );
      expect(a.faseSugerida, 'Estrutura');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
    });

    test('um rótulo de madeira com marrom moderado não é barranco', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Wood', 0.78), RotuloFoto('Roof', 0.66)],
        paleta: const PaletaObra(terra: 0.38),
      );
      expect(a.faseSugerida, isNot('Fundação'));
    });

    test('madeira e solo juntos continuam fundação (baldrame)', () {
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Wood', 0.80),
          RotuloFoto('Plank', 0.62),
          RotuloFoto('Soil', 0.60),
          RotuloFoto('Metal', 0.55),
        ],
        paleta: const PaletaObra(terra: 0.40, madeira: 0.15),
      );
      expect(a.faseSugerida, 'Fundação');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
    });

    test('piso de madeira pronto não vira forma de laje', () {
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Wood', 0.88),
          RotuloFoto('Floor', 0.80),
          RotuloFoto('Hardwood', 0.72),
          RotuloFoto('Plank', 0.60),
          RotuloFoto('Flooring', 0.58),
        ],
      );
      expect(a.faseSugerida, isNot('Estrutura'));
    });
  });

  group('Bloco, reboco e contrapiso', () {
    test('parede de bloco de concreto é alvenaria de bloco, não tijolo', () {
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Wall', 0.84),
          RotuloFoto('Concrete', 0.72),
          RotuloFoto('Brick', 0.61),
        ],
        paleta: const PaletaObra(concreto: 0.58, claro: 0.05, ceuAzul: 0.2),
      );
      expect(a.faseSugerida, 'Alvenaria');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
      expect(a.materiais, contains('Bloco de concreto'));
      expect(a.materiais, isNot(contains('Tijolo')));
    });

    test('parede de tijolo vermelho continua tijolo', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Brick', 0.88), RotuloFoto('Wall', 0.75)],
        paleta: const PaletaObra(tijolo: 0.45, concreto: 0.30),
      );
      expect(a.materiais, contains('Tijolo'));
      expect(a.materiais, isNot(contains('Bloco de concreto')));
    });

    test('parede rebocada cinza é reboco, não estrutura', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Wall', 0.82), RotuloFoto('Concrete', 0.70)],
        paleta: const PaletaObra(concreto: 0.62, claro: 0.10),
      );
      expect(a.faseSugerida, 'Reboco e contrapiso');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
    });

    test('contrapiso cinza é reboco e contrapiso', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Floor', 0.79), RotuloFoto('Concrete', 0.74)],
        paleta: const PaletaObra(concreto: 0.66),
      );
      expect(a.faseSugerida, 'Reboco e contrapiso');
      expect(a.materiais, isNot(contains('Piso cerâmico')));
    });

    test('concreto com ferragem continua estrutura', () {
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Floor', 0.70),
          RotuloFoto('Concrete', 0.68),
          RotuloFoto('Metal', 0.60),
        ],
        paleta: const PaletaObra(concreto: 0.55),
      );
      expect(a.faseSugerida, 'Estrutura');
    });
  });

  group('Fundação precisa de obra na foto', () {
    test('monte de areia sem obra não sugere fase', () {
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Sand', 0.84),
          RotuloFoto('Soil', 0.71),
          RotuloFoto('Rock', 0.55),
        ],
        paleta: const PaletaObra(terra: 0.48, madeira: 0.12, ceuAzul: 0.3),
      );
      expect(a.faseSugerida, isNull);
      expect(a.materiais, contains('Areia'));
    });

    test('terra roxa com ferragem é fundação, não alvenaria', () {
      // O solo vermelho cai na faixa de cor do tijolo; sem parede nem
      // rótulo de alvenaria, o vermelho é o próprio chão.
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Soil', 0.74), RotuloFoto('Metal', 0.63)],
        paleta: const PaletaObra(tijolo: 0.40, terra: 0.10),
      );
      expect(a.faseSugerida, 'Fundação');
      expect(a.materiais, isNot(contains('Tijolo')));
    });

    test('baldrame em terra roxa visto de cima continua fundação', () {
      // "Roof" é o ângulo; com solo à mostra, o vermelho não é telha nem
      // tijolo.
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Roof', 0.74),
          RotuloFoto('Soil', 0.66),
          RotuloFoto('Wood', 0.60),
          RotuloFoto('Metal', 0.55),
        ],
        paleta: const PaletaObra(tijolo: 0.42, terra: 0.08, ceuAzul: 0.2),
      );
      expect(a.faseSugerida, 'Fundação');
      expect(a.materiais, isNot(contains('Tijolo')));
      expect(a.materiais, isNot(contains('Telha')));
    });

    test('ferragem na vala aberta dá confiança para preencher a fundação', () {
      // Os pontos de concreto e ferragem passam para a fundação quando a
      // terra está à mostra — e a confiança tem de contar com eles.
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Soil', 0.70),
        RotuloFoto('Metal', 0.62),
        RotuloFoto('Concrete', 0.55),
      ]);
      expect(a.faseSugerida, 'Fundação');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
    });
  });
}
