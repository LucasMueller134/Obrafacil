import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
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
  /// suporte do app. A cópia é refeita se o conteúdo mudar — um modelo novo
  /// que veio numa atualização do app.
  static Future<String?> caminhoLocal() => _caminho ??= _copiarParaArquivo();

  /// Esquece a cópia resolvida nesta sessão, para o teste simular a
  /// abertura do app com outro modelo ou outra pasta.
  @visibleForTesting
  static void reiniciar() => _caminho = null;

  static Future<String?> _copiarParaArquivo() async {
    try {
      final dados = await rootBundle.load(asset);
      final pasta = await getApplicationSupportDirectory();
      final arquivo = File('${pasta.path}/modelos/fases_obra.tflite');
      final bytes =
          dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes);
      if (!await _mesmoConteudo(arquivo, bytes)) {
        await arquivo.parent.create(recursive: true);
        await arquivo.writeAsBytes(bytes, flush: true);
      }
      return arquivo.path;
    } catch (_) {
      // Asset ausente (o caso normal enquanto ninguém treinou o modelo) ou
      // sem espaço para copiar: o app segue com o modelo base.
      return null;
    }
  }

  /// A cópia no aparelho é o modelo que veio no app? Comparar só o tamanho
  /// não basta: retreinar com a mesma arquitetura e as mesmas classes gera
  /// um arquivo do mesmo tamanho com outros pesos, e o app seguiria para
  /// sempre com o modelo antigo. A leitura é uma por sessão
  /// ([caminhoLocal] guarda o resultado).
  static Future<bool> _mesmoConteudo(File arquivo, Uint8List bytes) async {
    if (!await arquivo.exists() || await arquivo.length() != bytes.length) {
      return false;
    }
    return listEquals(await arquivo.readAsBytes(), bytes);
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
