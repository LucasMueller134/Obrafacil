import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/constants/app_constants.dart';
import 'package:obra_facil/services/ia/cores_foto.dart';
import 'package:obra_facil/services/ia/diario_foto_service.dart';
import 'package:obra_facil/services/ia/modelo_fases.dart';

void main() {
  group('Rótulos do modelo próprio', () {
    test('o rótulo é a fase sem acento, com "_" no lugar do espaço', () {
      expect(ModeloFases.rotuloDaFase('Fundação'), 'fundacao');
      expect(ModeloFases.rotuloDaFase('Reboco e contrapiso'),
          'reboco_e_contrapiso');
      expect(ModeloFases.rotuloDaFase('Instalações elétricas'),
          'instalacoes_eletricas');
    });

    test('todo rótulo de fase volta para a fase do app', () {
      for (final fase in AppConstants.fasesPadrao) {
        expect(ModeloFases.faseDoRotulo(ModeloFases.rotuloDaFase(fase)), fase);
      }
    });

    test('rótulo do modelo base e a classe "outros" não são fase', () {
      expect(ModeloFases.faseDoRotulo('Roof'), isNull);
      expect(ModeloFases.faseDoRotulo('outros'), isNull);
    });

    test('sem o arquivo do modelo no app, não há caminho e nada quebra',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(await ModeloFases.caminhoLocal(), isNull);
    });
  });

  group('Modelo próprio na leitura da foto', () {
    test('modelo próprio confiante decide a fase sozinho', () {
      final a = DiarioFotoService.interpretar(
          const [RotuloFoto('reboco_e_contrapiso', 0.86)]);
      expect(a.faseSugerida, 'Reboco e contrapiso');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
    });

    test('modelo próprio pouco confiante só ajuda, não preenche', () {
      final a =
          DiarioFotoService.interpretar(const [RotuloFoto('alvenaria', 0.32)]);
      expect(a.confiancaFase, lessThan(0.5));
    });

    test('modelo próprio corrige o palpite do modelo genérico', () {
      // O modelo base vê "Roof" e madeira — sem ele, não dava para dizer
      // a fase. O modelo da obra reconhece a forma da laje.
      final a = DiarioFotoService.interpretar(const [
        RotuloFoto('Roof', 0.80),
        RotuloFoto('Wood', 0.66),
        RotuloFoto('estrutura', 0.81),
      ]);
      expect(a.faseSugerida, 'Estrutura');
      expect(a.confiancaFase, greaterThanOrEqualTo(0.5));
    });

    test('a "estrutura" do modelo próprio não vira fundação pela terra', () {
      // A regra que manda concreto e ferragem com terra à mostra para a
      // fundação é correção do modelo genérico; o da obra já sabe.
      final a = DiarioFotoService.interpretar(
        const [
          RotuloFoto('Soil', 0.70),
          RotuloFoto('Metal', 0.60),
          RotuloFoto('estrutura', 0.92),
        ],
        paleta: const PaletaObra(terra: 0.25),
      );
      expect(a.faseSugerida, 'Estrutura');
    });

    test('modelo próprio concordando com o genérico aumenta a confiança', () {
      final so = DiarioFotoService.interpretar(const [RotuloFoto('Brick', .8)]);
      final junto = DiarioFotoService.interpretar(
          const [RotuloFoto('Brick', 0.8), RotuloFoto('alvenaria', 0.6)]);
      expect(junto.faseSugerida, 'Alvenaria');
      expect(junto.confiancaFase, greaterThan(so.confiancaFase));
    });

    test('a fundação vista pelo modelo próprio é indício de obra', () {
      final a = DiarioFotoService.interpretar(
        const [RotuloFoto('Soil', 0.70), RotuloFoto('fundacao', 0.55)],
        paleta: const PaletaObra(terra: 0.45),
      );
      expect(a.faseSugerida, 'Fundação');
    });

    test('a classe "outros" do modelo próprio é ignorada', () {
      final a = DiarioFotoService.interpretar(const [RotuloFoto('outros', .9)]);
      expect(a.faseSugerida, isNull);
      expect(a.encontrouAlgo, isFalse);
    });
  });
}
