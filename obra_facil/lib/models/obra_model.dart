// lib/models/obra_model.dart
class ObraModel {
  final String id;
  final String nome;
  final String endereco;
  final String status;
  final String faseAtual;
  final double orcamentoTotal;
  final double custoAtual;
  final String mestreId;
  final String donoId;
  final DateTime dataInicio;
  final DateTime? dataPrevisaoFim;
  final DateTime? dataFim;
  final String? fotoUrl;
  final double? latitude;
  final double? longitude;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  ObraModel({
    required this.id,
    required this.nome,
    required this.endereco,
    required this.status,
    required this.faseAtual,
    required this.orcamentoTotal,
    required this.custoAtual,
    required this.mestreId,
    required this.donoId,
    required this.dataInicio,
    this.dataPrevisaoFim,
    this.dataFim,
    this.fotoUrl,
    this.latitude,
    this.longitude,
    required this.criadoEm,
    required this.atualizadoEm,
  });

  double get percentualGasto =>
      orcamentoTotal > 0 ? (custoAtual / orcamentoTotal) * 100 : 0;

  double get saldoRestante => orcamentoTotal - custoAtual;

  bool get estourandoOrcamento => percentualGasto >= 80;

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'endereco': endereco,
    'status': status,
    'faseAtual': faseAtual,
    'orcamentoTotal': orcamentoTotal,
    'custoAtual': custoAtual,
    'mestreId': mestreId,
    'donoId': donoId,
    'dataInicio': dataInicio.toIso8601String(),
    'dataPrevisaoFim': dataPrevisaoFim?.toIso8601String(),
    'dataFim': dataFim?.toIso8601String(),
    'fotoUrl': fotoUrl,
    'latitude': latitude,
    'longitude': longitude,
    'criadoEm': criadoEm.toIso8601String(),
    'atualizadoEm': atualizadoEm.toIso8601String(),
  };

  factory ObraModel.fromMap(Map<String, dynamic> map) => ObraModel(
    id: map['id'],
    nome: map['nome'],
    endereco: map['endereco'],
    status: map['status'],
    faseAtual: map['faseAtual'],
    orcamentoTotal: (map['orcamentoTotal'] ?? 0).toDouble(),
    custoAtual: (map['custoAtual'] ?? 0).toDouble(),
    mestreId: map['mestreId'] ?? '',
    donoId: map['donoId'] ?? '',
    dataInicio: DateTime.parse(map['dataInicio']),
    dataPrevisaoFim: map['dataPrevisaoFim'] != null
        ? DateTime.parse(map['dataPrevisaoFim'])
        : null,
    dataFim: map['dataFim'] != null ? DateTime.parse(map['dataFim']) : null,
    fotoUrl: map['fotoUrl'],
    latitude: map['latitude']?.toDouble(),
    longitude: map['longitude']?.toDouble(),
    criadoEm: DateTime.parse(map['criadoEm']),
    atualizadoEm: DateTime.parse(map['atualizadoEm']),
  );

  ObraModel copyWith({
    String? nome,
    String? endereco,
    String? status,
    String? faseAtual,
    double? orcamentoTotal,
    double? custoAtual,
    String? fotoUrl,
    DateTime? atualizadoEm,
  }) =>
      ObraModel(
        id: id,
        nome: nome ?? this.nome,
        endereco: endereco ?? this.endereco,
        status: status ?? this.status,
        faseAtual: faseAtual ?? this.faseAtual,
        orcamentoTotal: orcamentoTotal ?? this.orcamentoTotal,
        custoAtual: custoAtual ?? this.custoAtual,
        mestreId: mestreId,
        donoId: donoId,
        dataInicio: dataInicio,
        dataPrevisaoFim: dataPrevisaoFim,
        dataFim: dataFim,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        latitude: latitude,
        longitude: longitude,
        criadoEm: criadoEm,
        atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      );
}
