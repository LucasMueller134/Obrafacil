class FotoObraModel {
  final String id;
  final String obraId;
  final String url;
  final String? fase;
  final String? descricao;
  final String registradoPorNome;
  final DateTime data;

  const FotoObraModel({
    required this.id,
    required this.obraId,
    required this.url,
    this.fase,
    this.descricao,
    required this.registradoPorNome,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
        'obraId': obraId,
        'url': url,
        'fase': fase,
        'descricao': descricao,
        'registradoPorNome': registradoPorNome,
        'data': data.toIso8601String(),
      };

  factory FotoObraModel.fromMap(String id, Map<String, dynamic> map) =>
      FotoObraModel(
        id: id,
        obraId: map['obraId'] ?? '',
        url: map['url'] ?? '',
        fase: map['fase'],
        descricao: map['descricao'],
        registradoPorNome: map['registradoPorNome'] ?? '',
        data: DateTime.tryParse(map['data'] ?? '') ?? DateTime.now(),
      );
}
