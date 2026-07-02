class EstoqueItemModel {
  final String id;
  final String obraId;
  final String material;
  final double quantidade;
  final String unidade;
  final double quantidadeMinima;
  final DateTime atualizadoEm;

  const EstoqueItemModel({
    required this.id,
    required this.obraId,
    required this.material,
    required this.quantidade,
    required this.unidade,
    required this.quantidadeMinima,
    required this.atualizadoEm,
  });

  bool get estoqueBaixo => quantidade <= quantidadeMinima;

  Map<String, dynamic> toMap() => {
        'obraId': obraId,
        'material': material,
        'quantidade': quantidade,
        'unidade': unidade,
        'quantidadeMinima': quantidadeMinima,
        'atualizadoEm': atualizadoEm.toIso8601String(),
      };

  factory EstoqueItemModel.fromMap(String id, Map<String, dynamic> map) =>
      EstoqueItemModel(
        id: id,
        obraId: map['obraId'] ?? '',
        material: map['material'] ?? '',
        quantidade: (map['quantidade'] ?? 0).toDouble(),
        unidade: map['unidade'] ?? 'un',
        quantidadeMinima: (map['quantidadeMinima'] ?? 0).toDouble(),
        atualizadoEm:
            DateTime.tryParse(map['atualizadoEm'] ?? '') ?? DateTime.now(),
      );

  EstoqueItemModel copyWith({
    String? material,
    double? quantidade,
    String? unidade,
    double? quantidadeMinima,
  }) =>
      EstoqueItemModel(
        id: id,
        obraId: obraId,
        material: material ?? this.material,
        quantidade: quantidade ?? this.quantidade,
        unidade: unidade ?? this.unidade,
        quantidadeMinima: quantidadeMinima ?? this.quantidadeMinima,
        atualizadoEm: DateTime.now(),
      );
}
