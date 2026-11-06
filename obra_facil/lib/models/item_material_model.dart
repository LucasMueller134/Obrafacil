/// Item de material identificado num lançamento (pela nota, voz ou texto).
/// É o elo entre o financeiro e o estoque: na aprovação do lançamento,
/// cada item entra automaticamente no estoque da obra.
class ItemMaterialModel {
  /// O material como o estoque conhece ("Cimento", "Tijolo") ou o nome
  /// limpo do produto.
  final String material;
  final double quantidade;
  final String unidade;

  /// O produto como veio impresso na nota ("CIMENTO CP II-E-32 50KG");
  /// nulo quando o item veio da fala ou do texto.
  final String? descricao;

  /// Preço de uma unidade e total da linha, quando a nota traz.
  final double? valorUnitario;
  final double? valorTotal;

  const ItemMaterialModel({
    required this.material,
    required this.quantidade,
    required this.unidade,
    this.descricao,
    this.valorUnitario,
    this.valorTotal,
  });

  String get resumo =>
      '${quantidade == quantidade.roundToDouble() ? quantidade.toStringAsFixed(0) : quantidade.toStringAsFixed(2)} '
      '$unidade $material';

  /// O total da linha: o impresso ou, sem ele, quantidade × preço.
  double? get totalDaLinha =>
      valorTotal ??
      (valorUnitario == null ? null : quantidade * valorUnitario!);

  Map<String, dynamic> toMap() => {
        'material': material,
        'quantidade': quantidade,
        'unidade': unidade,
        if (descricao != null) 'descricao': descricao,
        if (valorUnitario != null) 'valorUnitario': valorUnitario,
        if (valorTotal != null) 'valorTotal': valorTotal,
      };

  factory ItemMaterialModel.fromMap(Map<String, dynamic> map) =>
      ItemMaterialModel(
        material: map['material'] ?? '',
        quantidade: (map['quantidade'] ?? 0).toDouble(),
        unidade: map['unidade'] ?? 'un',
        descricao: map['descricao'] as String?,
        valorUnitario: (map['valorUnitario'] as num?)?.toDouble(),
        valorTotal: (map['valorTotal'] as num?)?.toDouble(),
      );
}
