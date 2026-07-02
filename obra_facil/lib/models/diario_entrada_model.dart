class DiarioEntradaModel {
  final String id;
  final String obraId;
  final String descricao;
  final String fase;
  final int numeroPessoas;
  final String clima;
  final List<String> fotosUrls;
  final String registradoPorId;
  final String registradoPorNome;
  final DateTime data;
  final DateTime criadoEm;

  const DiarioEntradaModel({
    required this.id,
    required this.obraId,
    required this.descricao,
    required this.fase,
    required this.numeroPessoas,
    required this.clima,
    this.fotosUrls = const [],
    required this.registradoPorId,
    required this.registradoPorNome,
    required this.data,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
        'obraId': obraId,
        'descricao': descricao,
        'fase': fase,
        'numeroPessoas': numeroPessoas,
        'clima': clima,
        'fotosUrls': fotosUrls,
        'registradoPorId': registradoPorId,
        'registradoPorNome': registradoPorNome,
        'data': data.toIso8601String(),
        'criadoEm': criadoEm.toIso8601String(),
      };

  factory DiarioEntradaModel.fromMap(String id, Map<String, dynamic> map) =>
      DiarioEntradaModel(
        id: id,
        obraId: map['obraId'] ?? '',
        descricao: map['descricao'] ?? '',
        fase: map['fase'] ?? '',
        numeroPessoas: map['numeroPessoas'] ?? 0,
        clima: map['clima'] ?? 'Ensolarado',
        fotosUrls: List<String>.from(map['fotosUrls'] ?? const []),
        registradoPorId: map['registradoPorId'] ?? '',
        registradoPorNome: map['registradoPorNome'] ?? '',
        data: DateTime.tryParse(map['data'] ?? '') ?? DateTime.now(),
        criadoEm: DateTime.tryParse(map['criadoEm'] ?? '') ?? DateTime.now(),
      );
}
