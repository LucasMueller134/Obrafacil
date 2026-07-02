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
  /// Redimensiona (máx. 900px), comprime em JPEG e devolve um data URI.
  static Future<String> comprimirParaDataUri(File arquivo) async {
    final bytes = await arquivo.readAsBytes();
    final comprimido = await Isolate.run(() => _comprimir(bytes));
    return 'data:image/jpeg;base64,${base64Encode(comprimido)}';
  }

  static Uint8List _comprimir(Uint8List bytes) {
    final original = img.decodeImage(bytes);
    if (original == null) return bytes;
    final maiorLado =
        original.width > original.height ? original.width : original.height;
    final imagem = maiorLado > 900
        ? img.copyResize(
            original,
            width: original.width >= original.height ? 900 : null,
            height: original.height > original.width ? 900 : null,
          )
        : original;
    return Uint8List.fromList(img.encodeJpg(imagem, quality: 70));
  }

  static bool ehDataUri(String fonte) => fonte.startsWith('data:image');

  static Uint8List bytesDe(String dataUri) =>
      base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));
}
