import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compressão e armazenamento de fotos como data URI (base64) no Firestore.
///
/// Escolha de projeto: o Firebase Storage passou a exigir o plano Blaze em
/// projetos novos, então o protótipo guarda a foto comprimida dentro do
/// próprio documento (limite de 1 MB por doc). O widget ImagemObra também
/// aceita URLs http, então migrar para Storage depois não quebra nada.
abstract class ImagemService {
  /// Redimensiona, comprime em JPEG e devolve um data URI.
  ///
  /// [ladoMaximo] e [qualidade] existem para o diário, que guarda até três
  /// fotos no mesmo documento e precisa caber no limite de 1 MB.
  static Future<String> comprimirParaDataUri(
    File arquivo, {
    int ladoMaximo = 900,
    int qualidade = 70,
  }) async {
    final bytes = await arquivo.readAsBytes();
    final comprimido =
        await Isolate.run(() => _comprimir(bytes, ladoMaximo, qualidade));
    return 'data:image/jpeg;base64,${base64Encode(comprimido)}';
  }

  static Uint8List _comprimir(Uint8List bytes, int ladoMaximo, int qualidade) {
    final original = img.decodeImage(bytes);
    if (original == null) return bytes;
    final maiorLado =
        original.width > original.height ? original.width : original.height;
    final imagem = maiorLado > ladoMaximo
        ? img.copyResize(
            original,
            width: original.width >= original.height ? ladoMaximo : null,
            height: original.height > original.width ? ladoMaximo : null,
          )
        : original;
    return Uint8List.fromList(img.encodeJpg(imagem, quality: qualidade));
  }

  static bool ehDataUri(String fonte) => fonte.startsWith('data:image');

  static Uint8List bytesDe(String dataUri) =>
      base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));
}
