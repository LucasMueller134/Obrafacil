/// Item de material identificado num lançamento (pela nota, voz ou texto).
/// É o elo entre o financeiro e o estoque: na aprovação do lançamento,
/// cada item entra automaticamente no estoque da obra.
class ItemMaterialModel {
  final String material;
  final double quantidade;
  final String unidade;

  const ItemMaterialModel({
    required this.material,
    required this.quantidade,
    required this.unidade,
  });

  String get resumo =>
      '${quantidade == quantidade.roundToDouble() ? quantidade.toStringAsFixed(0) : quantidade.toStringAsFixed(2)} '
      '$unidade $material';

  Map<String, dynamic> toMap() => {
        'material': material,
        'quantidade': quantidade,
        'unidade': unidade,
      };

  factory ItemMaterialModel.fromMap(Map<String, dynamic> map) =>
      ItemMaterialModel(
        material: map['material'] ?? '',
        quantidade: (map['quantidade'] ?? 0).toDouble(),
        unidade: map['unidade'] ?? 'un',
      );
}
