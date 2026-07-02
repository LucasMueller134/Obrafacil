import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ComparacaoFotos {
  /// 0 a 1 — quanto a cena mudou entre as duas fotos.
  final double indiceMudanca;

  const ComparacaoFotos({required this.indiceMudanca});

  String get interpretacao {
    if (indiceMudanca < 0.10) {
      return 'Quase nenhuma mudança visível entre as fotos.';
    }
    if (indiceMudanca < 0.30) {
      return 'Mudança leve — avanço pontual na cena.';
    }
    if (indiceMudanca < 0.55) {
      return 'Mudança moderada — a obra avançou de forma perceptível.';
    }
    return 'Mudança grande — avanço significativo (ou ângulo de foto muito diferente).';
  }
}

/// IA on-device nº 4 — estimativa de progresso por foto (experimental).
///
/// Compara duas fotos do mesmo ponto da obra combinando diferença de
/// histograma de luminância (mudança global da cena) com diferença
/// pixel a pixel em baixa resolução (mudança estrutural). O cálculo
/// roda num isolate para não travar a interface.
class ProgressoFotoService {
  static Future<ComparacaoFotos> comparar(
      String caminhoAntes, String caminhoDepois) async {
    final bytesAntes = await File(caminhoAntes).readAsBytes();
    final bytesDepois = await File(caminhoDepois).readAsBytes();
    return compararBytes(bytesAntes, bytesDepois);
  }

  static Future<ComparacaoFotos> compararBytes(
      Uint8List bytesAntes, Uint8List bytesDepois) async {
    final indice = await Isolate.run(
        () => _calcularIndice(bytesAntes, bytesDepois));
    return ComparacaoFotos(indiceMudanca: indice);
  }

  static double _calcularIndice(
      Uint8List bytesAntes, Uint8List bytesDepois) {
    final antes = _preparar(bytesAntes);
    final depois = _preparar(bytesDepois);
    if (antes == null || depois == null) return 0;

    final difHistograma = _diferencaHistograma(antes, depois);
    final difPixels = _diferencaPixels(antes, depois);

    // Pesos empíricos: a diferença estrutural (pixels) importa mais que a
    // variação global de iluminação (histograma).
    return (0.35 * difHistograma + 0.65 * difPixels).clamp(0.0, 1.0);
  }

  /// Reduz para 64x64 em tons de cinza — barato e suficiente para comparar.
  static img.Image? _preparar(Uint8List bytes) {
    final decodificada = img.decodeImage(bytes);
    if (decodificada == null) return null;
    return img.grayscale(
      img.copyResize(decodificada, width: 64, height: 64),
    );
  }

  static double _diferencaHistograma(img.Image a, img.Image b) {
    const bins = 32;
    final histA = _histograma(a, bins);
    final histB = _histograma(b, bins);
    var soma = 0.0;
    for (var i = 0; i < bins; i++) {
      soma += (histA[i] - histB[i]).abs();
    }
    return (soma / 2).clamp(0.0, 1.0); // distância L1 normalizada
  }

  static List<double> _histograma(img.Image imagem, int bins) {
    final hist = List<double>.filled(bins, 0);
    for (final pixel in imagem) {
      final lum = pixel.r.toInt(); // já está em cinza (r == g == b)
      hist[(lum * bins) ~/ 256] += 1;
    }
    final total = imagem.width * imagem.height;
    return hist.map((v) => v / total).toList();
  }

  static double _diferencaPixels(img.Image a, img.Image b) {
    var soma = 0.0;
    for (var y = 0; y < a.height; y++) {
      for (var x = 0; x < a.width; x++) {
        final la = a.getPixel(x, y).r;
        final lb = b.getPixel(x, y).r;
        soma += (la - lb).abs() / 255.0;
      }
    }
    return (soma / (a.width * a.height)).clamp(0.0, 1.0);
  }
}
