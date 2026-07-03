enum TipoMovimentoEstoque {
  entrada,
  saida;

  static TipoMovimentoEstoque fromString(String? v) =>
      TipoMovimentoEstoque.values.firstWhere(
        (t) => t.name == v,
        orElse: () => TipoMovimentoEstoque.entrada,
      );
}

/// Registro de entrada/saída de material no estoque.
///
/// É a base do histórico que alimenta a previsão de término:
/// as saídas ao longo do tempo revelam o ritmo de consumo da obra.
class MovimentoEstoqueModel {
  final String id;
  final String obraId;
  final String material;
  final TipoMovimentoEstoque tipo;
  final double quantidade;
  final String unidade;

  /// 'aprovacao' (lançamento aprovado) ou 'manual' (ajuste na tela).
  final String origem;
  final String? lancamentoId;
  final DateTime data;

  const MovimentoEstoqueModel({
    required this.id,
    required this.obraId,
    required this.material,
    required this.tipo,
    required this.quantidade,
    required this.unidade,
    required this.origem,
    this.lancamentoId,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
        'obraId': obraId,
        'material': material,
        'tipo': tipo.name,
        'quantidade': quantidade,
        'unidade': unidade,
        'origem': origem,
        'lancamentoId': lancamentoId,
        'data': data.toIso8601String(),
      };

  factory MovimentoEstoqueModel.fromMap(String id, Map<String, dynamic> map) =>
      MovimentoEstoqueModel(
        id: id,
        obraId: map['obraId'] ?? '',
        material: map['material'] ?? '',
        tipo: TipoMovimentoEstoque.fromString(map['tipo']),
        quantidade: (map['quantidade'] ?? 0).toDouble(),
        unidade: map['unidade'] ?? 'un',
        origem: map['origem'] ?? 'manual',
        lancamentoId: map['lancamentoId'],
        data: DateTime.tryParse(map['data'] ?? '') ?? DateTime.now(),
      );
}
