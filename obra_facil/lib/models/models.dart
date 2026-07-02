// lib/models/fornecedor_model.dart
class FornecedorModel {
  final String id;
  final String nome;
  final String telefone;
  final String? email;
  final String? cnpj;
  final String? observacoes;
  final double totalGasto;
  final DateTime criadoEm;

  FornecedorModel({
    required this.id,
    required this.nome,
    required this.telefone,
    this.email,
    this.cnpj,
    this.observacoes,
    this.totalGasto = 0,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'telefone': telefone,
    'email': email,
    'cnpj': cnpj,
    'observacoes': observacoes,
    'totalGasto': totalGasto,
    'criadoEm': criadoEm.toIso8601String(),
  };

  factory FornecedorModel.fromMap(Map<String, dynamic> map) => FornecedorModel(
    id: map['id'],
    nome: map['nome'],
    telefone: map['telefone'] ?? '',
    email: map['email'],
    cnpj: map['cnpj'],
    observacoes: map['observacoes'],
    totalGasto: (map['totalGasto'] ?? 0).toDouble(),
    criadoEm: DateTime.parse(map['criadoEm']),
  );
}

// lib/models/estoque_model.dart
class EstoqueModel {
  final String id;
  final String obraId;
  final String material;
  final double quantidade;
  final String unidade;
  final double quantidadeMinima;
  final DateTime atualizadoEm;

  EstoqueModel({
    required this.id,
    required this.obraId,
    required this.material,
    required this.quantidade,
    required this.unidade,
    required this.quantidadeMinima,
    required this.atualizadoEm,
  });

  bool get estaBaixo => quantidade <= quantidadeMinima;

  Map<String, dynamic> toMap() => {
    'id': id,
    'obraId': obraId,
    'material': material,
    'quantidade': quantidade,
    'unidade': unidade,
    'quantidadeMinima': quantidadeMinima,
    'atualizadoEm': atualizadoEm.toIso8601String(),
  };

  factory EstoqueModel.fromMap(Map<String, dynamic> map) => EstoqueModel(
    id: map['id'],
    obraId: map['obraId'],
    material: map['material'],
    quantidade: (map['quantidade'] ?? 0).toDouble(),
    unidade: map['unidade'] ?? 'un',
    quantidadeMinima: (map['quantidadeMinima'] ?? 0).toDouble(),
    atualizadoEm: DateTime.parse(map['atualizadoEm']),
  );
}

// lib/models/diario_model.dart
class DiarioModel {
  final String id;
  final String obraId;
  final String descricao;
  final String fase;
  final int numeroPessoas;
  final String clima;
  final String registradoPorNome;
  final DateTime data;
  final DateTime criadoEm;

  DiarioModel({
    required this.id,
    required this.obraId,
    required this.descricao,
    required this.fase,
    required this.numeroPessoas,
    required this.clima,
    required this.registradoPorNome,
    required this.data,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'obraId': obraId,
    'descricao': descricao,
    'fase': fase,
    'numeroPessoas': numeroPessoas,
    'clima': clima,
    'registradoPorNome': registradoPorNome,
    'data': data.toIso8601String(),
    'criadoEm': criadoEm.toIso8601String(),
  };

  factory DiarioModel.fromMap(Map<String, dynamic> map) => DiarioModel(
    id: map['id'],
    obraId: map['obraId'],
    descricao: map['descricao'],
    fase: map['fase'] ?? '',
    numeroPessoas: map['numeroPessoas'] ?? 0,
    clima: map['clima'] ?? 'Bom',
    registradoPorNome: map['registradoPorNome'] ?? '',
    data: DateTime.parse(map['data']),
    criadoEm: DateTime.parse(map['criadoEm']),
  );
}

// lib/models/cronograma_model.dart
class CronogramaModel {
  final String id;
  final String obraId;
  final String fase;
  final DateTime dataInicio;
  final DateTime dataFim;
  final int percentualConcluido;
  final String? observacoes;

  CronogramaModel({
    required this.id,
    required this.obraId,
    required this.fase,
    required this.dataInicio,
    required this.dataFim,
    required this.percentualConcluido,
    this.observacoes,
  });

  bool get atrasado =>
      DateTime.now().isAfter(dataFim) && percentualConcluido < 100;

  Map<String, dynamic> toMap() => {
    'id': id,
    'obraId': obraId,
    'fase': fase,
    'dataInicio': dataInicio.toIso8601String(),
    'dataFim': dataFim.toIso8601String(),
    'percentualConcluido': percentualConcluido,
    'observacoes': observacoes,
  };

  factory CronogramaModel.fromMap(Map<String, dynamic> map) => CronogramaModel(
    id: map['id'],
    obraId: map['obraId'],
    fase: map['fase'],
    dataInicio: DateTime.parse(map['dataInicio']),
    dataFim: DateTime.parse(map['dataFim']),
    percentualConcluido: map['percentualConcluido'] ?? 0,
    observacoes: map['observacoes'],
  );
}

// lib/models/galeria_model.dart
class GaleriaModel {
  final String id;
  final String obraId;
  final String fotoUrl;
  final String fase;
  final String? descricao;
  final String registradoPorNome;
  final DateTime data;

  GaleriaModel({
    required this.id,
    required this.obraId,
    required this.fotoUrl,
    required this.fase,
    this.descricao,
    required this.registradoPorNome,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'obraId': obraId,
    'fotoUrl': fotoUrl,
    'fase': fase,
    'descricao': descricao,
    'registradoPorNome': registradoPorNome,
    'data': data.toIso8601String(),
  };

  factory GaleriaModel.fromMap(Map<String, dynamic> map) => GaleriaModel(
    id: map['id'],
    obraId: map['obraId'],
    fotoUrl: map['fotoUrl'],
    fase: map['fase'] ?? '',
    descricao: map['descricao'],
    registradoPorNome: map['registradoPorNome'] ?? '',
    data: DateTime.parse(map['data']),
  );
}
