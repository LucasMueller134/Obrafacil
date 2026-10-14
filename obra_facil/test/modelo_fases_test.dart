import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/constants/app_constants.dart';
import 'package:obra_facil/services/ia/cores_foto.dart';
import 'package:obra_facil/services/ia/diario_foto_service.dart';
import 'package:obra_facil/services/ia/modelo_fases.dart';

/// Simula o app instalado: [modelo] é o asset que veio no app (null = sem
/// modelo próprio) e [pasta] a pasta de suporte do aparelho.
void _simularAparelho(Directory pasta, Uint8List? modelo) {
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  mensageiro.setMockMessageHandler('flutter/assets', (mensagem) async {
    final chave = utf8.decode(mensagem!.buffer.asUint8List());
    if (chave == ModeloFases.asset && modelo != null) {
      return ByteData.sublistView(modelo);
    }
    return null;
  });
  mensageiro.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => pasta.path);
}

void main() {
  group('Cópia do modelo próprio no aparelho', () {
    late Directory pasta;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      pasta = await Directory.systemTemp.createTemp('modelo_fases');
      ModeloFases.reiniciar();
    });

    tearDown(() async {
      ModeloFases.reiniciar();
      final mensageiro =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      mensageiro.setMockMessageHandler('flutter/assets', null);
      mensageiro.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'), null);
      await pasta.delete(recursive: true);
    });

    test('modelo retreinado do mesmo tamanho substitui a cópia antiga',
        () async {
      // Mesma arquitetura e mesmas classes dão sempre o mesmo número de
      // bytes: só o conteúdo diz que o modelo mudou.
      final arquivo = File('${pasta.path}/modelos/fases_obra.tflite');
      await arquivo.parent.create(recursive: true);
      await arquivo.writeAsBytes(List.filled(4096, 1));
      _simularAparelho(pasta, Uint8List.fromList(List.filled(4096, 2)));

      final caminho = await ModeloFases.caminhoLocal();
      expect(caminho, arquivo.path);
      expect(await File(caminho!).readAsBytes(), everyElement(2));
    });

    test('a cópia igual ao modelo do app é aproveitada', () async {
      final modelo = Uint8List.fromList(List.generate(4096, (i) => i % 251));
      final arquivo = File('${pasta.path}/modelos/fases_obra.tflite');
      await arquivo.parent.create(recursive: true);
      await arquivo.writeAsBytes(modelo);
      final antes = await arquivo.lastModified();
      _simularAparelho(pasta, modelo);

      expect(await ModeloFases.caminhoLocal(), arquivo.path);
      expect(await arquivo.lastModified(), antes);
      expect(await arquivo.readAsBytes(), modelo);
    });

    test('fechar o formulário durante a leitura não deixa classificador aberto',
        () async {
      _simularAparelho(pasta, Uint8List.fromList(List.filled(1024, 7)));
      // Classificadores do ML Kit abertos no nativo: id -> tipo.
      final abertos = <String, String>{};
      final baseResponde = Completer<void>();
      const canal = MethodChannel('google_mlkit_image_labeler');
      final mensageiro =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      mensageiro.setMockMethodCallHandler(canal, (chamada) async {
        final argumentos = chamada.arguments as Map;
        final id = argumentos['id'] as String;
        if (chamada.method == 'vision#startImageLabelDetector') {
          final tipo = (argumentos['options'] as Map)['type'] as String;
          abertos[id] = tipo;
          if (tipo == 'base') await baseResponde.future;
          return <Object>[];
        }
        if (chamada.method == 'vision#closeImageLabelDetector') {
          abertos.remove(id);
        }
        return null;
      });
      addTearDown(() => mensageiro.setMockMethodCallHandler(canal, null));

      final servico = DiarioFotoService();
      final leitura = servico.analisar('/nao/existe.jpg');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // O usuário fecha o formulário com o modelo base ainda lendo a foto.
      servico.dispose();
      baseResponde.complete();
      await leitura;
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(abertos.values, isNot(contains('local')));
    });
  });

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
