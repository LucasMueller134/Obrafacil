import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../constants/app_constants.dart';
import 'texto_br.dart';

/// Modelo próprio de fases da obra — opcional.
///
/// O classificador base do ML Kit não conhece obra: não tem "formwork",
/// "rebar" nem "masonry" que apareçam de verdade. Um classificador treinado
/// com as fotos do próprio canteiro (ver docs/ia/treinar-modelo.md) conhece,
/// e roda no aparelho do mesmo jeito, pelo `LocalLabelerOptions` do ML Kit.
///
/// O app funciona com ou sem ele: sem o arquivo do modelo, ou se ele não
/// carregar, a leitura da foto segue só com o modelo base, como sempre foi.
abstract class ModeloFases {
  /// Onde o treino deixa o modelo dentro do app.
  static const String asset = 'assets/modelos/fases_obra.tflite';

  static Future<String?>? _caminho;

  /// Caminho do modelo num arquivo local, ou null quando o app não tem
  /// modelo próprio.
  ///
  /// O ML Kit só abre modelo por caminho de arquivo, e asset dentro do APK
  /// não é arquivo: na primeira vez o modelo é copiado para a pasta de
  /// suporte do app. A cópia é refeita se o tamanho mudar — um modelo novo
  /// que veio numa atualização do app.
  static Future<String?> caminhoLocal() => _caminho ??= _copiarParaArquivo();

  static Future<String?> _copiarParaArquivo() async {
    try {
      final dados = await rootBundle.load(asset);
      final pasta = await getApplicationSupportDirectory();
      final arquivo = File('${pasta.path}/modelos/fases_obra.tflite');
      if (!await arquivo.exists() ||
          await arquivo.length() != dados.lengthInBytes) {
        await arquivo.parent.create(recursive: true);
        await arquivo.writeAsBytes(
          dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes),
          flush: true,
        );
      }
      return arquivo.path;
    } catch (_) {
      // Asset ausente (o caso normal enquanto ninguém treinou o modelo) ou
      // sem espaço para copiar: o app segue com o modelo base.
      return null;
    }
  }

  /// Nome do rótulo de cada fase no modelo próprio: a fase sem acento,
  /// minúscula, com "_" no lugar de espaço ("Reboco e contrapiso" →
  /// "reboco_e_contrapiso"). É o nome da pasta de fotos no treino.
  static String rotuloDaFase(String fase) => TextoBr.normalizar(fase)
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  static final Map<String, String> _fasePorRotulo = {
    for (final fase in AppConstants.fasesPadrao) rotuloDaFase(fase): fase,
  };

  /// Fase do app que o rótulo do modelo próprio representa, ou null se o
  /// rótulo não é dele (é do modelo base, em inglês, ou a classe "outros").
  static String? faseDoRotulo(String rotulo) =>
      _fasePorRotulo[rotulo.toLowerCase().trim()];
}
