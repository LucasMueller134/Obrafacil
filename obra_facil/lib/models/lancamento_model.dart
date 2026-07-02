// lib/models/lancamento_model.dart
class LancamentoModel {
  final String id;
  final String obraId;
  final String categoria;
  final String descricao;
  final double quantidade;
  final String unidade;
  final double valorUnitario;
  final double valorTotal;
  final String fornecedorId;
  final String fornecedorNome;
  final String statusPagamento;
  final String fase;
  final String? notaFiscalUrl;
  final String? audioUrl;
  final String lancadoPorId;
  final String lancadoPorNome;
  final DateTime data;
  final DateTime criadoEm;
  final bool sincronizado;

  LancamentoModel({
    required this.id,
    required this.obraId,
    required this.categoria,
    required this.descricao,
    required this.quantidade,
    required this.unidade,
    required this.valorUnitario,
    required this.valorTotal,
    required this.fornecedorId,
    required this.fornecedorNome,
    required this.statusPagamento,
    required this.fase,
    this.notaFiscalUrl,
    this.audioUrl,
    required this.lancadoPorId,
    required this.lancadoPorNome,
    required this.data,
    required this.criadoEm,
    this.sincronizado = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'obraId': obraId,
    'categoria': categoria,
    'descricao': descricao,
    'quantidade': quantidade,
    'unidade': unidade,
    'valorUnitario': valorUnitario,
    'valorTotal': valorTotal,
    'fornecedorId': fornecedorId,
    'fornecedorNome': fornecedorNome,
    'statusPagamento': statusPagamento,
    'fase': fase,
    'notaFiscalUrl': notaFiscalUrl,
    'audioUrl': audioUrl,
    'lancadoPorId': lancadoPorId,
    'lancadoPorNome': lancadoPorNome,
    'data': data.toIso8601String(),
    'criadoEm': criadoEm.toIso8601String(),
    'sincronizado': sincronizado,
  };

  factory LancamentoModel.fromMap(Map<String, dynamic> map) => LancamentoModel(
    id: map['id'],
    obraId: map['obraId'],
    categoria: map['categoria'],
    descricao: map['descricao'],
    quantidade: (map['quantidade'] ?? 0).toDouble(),
    unidade: map['unidade'] ?? 'un',
    valorUnitario: (map['valorUnitario'] ?? 0).toDouble(),
    valorTotal: (map['valorTotal'] ?? 0).toDouble(),
    fornecedorId: map['fornecedorId'] ?? '',
    fornecedorNome: map['fornecedorNome'] ?? '',
    statusPagamento: map['statusPagamento'] ?? 'A Pagar',
    fase: map['fase'] ?? '',
    notaFiscalUrl: map['notaFiscalUrl'],
    audioUrl: map['audioUrl'],
    lancadoPorId: map['lancadoPorId'] ?? '',
    lancadoPorNome: map['lancadoPorNome'] ?? '',
    data: DateTime.parse(map['data']),
    criadoEm: DateTime.parse(map['criadoEm']),
    sincronizado: map['sincronizado'] ?? false,
  );
}
