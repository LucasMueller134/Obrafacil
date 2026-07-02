class CronogramaFaseModel {
  final String id;
  final String obraId;
  final String nome;

  /// Posição da fase no cronograma (0 = primeira).
  final int ordem;
  final DateTime dataInicio;
  final DateTime dataFim;

  /// 0 a 100.
  final int percentualConcluido;
  final String? observacoes;

  const CronogramaFaseModel({
    required this.id,
    required this.obraId,
    required this.nome,
    required this.ordem,
    required this.dataInicio,
    required this.dataFim,
    this.percentualConcluido = 0,
    this.observacoes,
  });

  bool get concluida => percentualConcluido >= 100;

  bool get atrasada =>
      !concluida && DateTime.now().isAfter(dataFim);

  bool get emAndamento =>
      !concluida &&
      DateTime.now().isAfter(dataInicio) &&
      !DateTime.now().isAfter(dataFim);

  Map<String, dynamic> toMap() => {
        'obraId': obraId,
        'nome': nome,
        'ordem': ordem,
        'dataInicio': dataInicio.toIso8601String(),
        'dataFim': dataFim.toIso8601String(),
        'percentualConcluido': percentualConcluido,
        'observacoes': observacoes,
      };

  factory CronogramaFaseModel.fromMap(String id, Map<String, dynamic> map) =>
      CronogramaFaseModel(
        id: id,
        obraId: map['obraId'] ?? '',
        nome: map['nome'] ?? '',
        ordem: map['ordem'] ?? 0,
        dataInicio:
            DateTime.tryParse(map['dataInicio'] ?? '') ?? DateTime.now(),
        dataFim: DateTime.tryParse(map['dataFim'] ?? '') ?? DateTime.now(),
        percentualConcluido: map['percentualConcluido'] ?? 0,
        observacoes: map['observacoes'],
      );

  CronogramaFaseModel copyWith({
    String? nome,
    int? ordem,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? percentualConcluido,
    String? observacoes,
  }) =>
      CronogramaFaseModel(
        id: id,
        obraId: obraId,
        nome: nome ?? this.nome,
        ordem: ordem ?? this.ordem,
        dataInicio: dataInicio ?? this.dataInicio,
        dataFim: dataFim ?? this.dataFim,
        percentualConcluido: percentualConcluido ?? this.percentualConcluido,
        observacoes: observacoes ?? this.observacoes,
      );
}
