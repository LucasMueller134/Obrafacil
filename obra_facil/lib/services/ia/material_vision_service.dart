import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

class MaterialDetectado {
  /// Nome do material em português (ex.: "Tijolo").
  final String material;

  /// Rótulo original do modelo de visão (ex.: "Brick").
  final String labelOriginal;

  /// 0 a 1.
  final double confianca;

  const MaterialDetectado({
    required this.material,
    required this.labelOriginal,
    required this.confianca,
  });
}

/// IA on-device nº 1 — reconhecimento de material pela câmera.
///
/// Usa o classificador de imagens do Google ML Kit (modelo TensorFlow Lite
/// embarcado no aparelho, offline) e traduz os rótulos genéricos do modelo
/// para os materiais de construção usados no app.
class MaterialVisionService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.45),
  );

  /// Mapeia rótulos do modelo base do ML Kit → material de construção.
  static const Map<String, String> _mapaMateriais = {
    'brick': 'Tijolo',
    'brickwork': 'Tijolo',
    'wood': 'Madeira',
    'lumber': 'Madeira',
    'plank': 'Madeira',
    'plywood': 'Madeira',
    'concrete': 'Concreto',
    'cement': 'Cimento',
    'sand': 'Areia',
    'gravel': 'Brita',
    'rock': 'Brita',
    'stone': 'Brita',
    'metal': 'Vergalhão de aço',
    'steel': 'Vergalhão de aço',
    'iron': 'Vergalhão de aço',
    'wire': 'Fio elétrico',
    'cable': 'Fio elétrico',
    'pipe': 'Cano PVC',
    'plumbing': 'Cano PVC',
    'tile': 'Piso cerâmico',
    'flooring': 'Piso cerâmico',
    'roof': 'Telha',
    'paint': 'Tinta',
    'door': 'Porta',
    'window': 'Janela',
    'glass': 'Vidro',
    'ladder': 'Escada',
    'scaffolding': 'Andaime',
  };

  /// Analisa a foto e retorna os materiais reconhecidos, do mais
  /// confiante para o menos.
  Future<List<MaterialDetectado>> reconhecer(String caminhoImagem) async {
    final input = InputImage.fromFilePath(caminhoImagem);
    final labels = await _labeler.processImage(input);

    final detectados = <MaterialDetectado>[];
    final vistos = <String>{};
    for (final label in labels) {
      final material = _mapaMateriais[label.label.toLowerCase()];
      if (material == null || vistos.contains(material)) continue;
      vistos.add(material);
      detectados.add(MaterialDetectado(
        material: material,
        labelOriginal: label.label,
        confianca: label.confidence,
      ));
    }
    detectados.sort((a, b) => b.confianca.compareTo(a.confianca));
    return detectados;
  }

  void dispose() => _labeler.close();
}
