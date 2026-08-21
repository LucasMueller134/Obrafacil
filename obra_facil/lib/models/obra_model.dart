enum StatusObra {
  emAndamento,
  pausada,
  concluida;

  String get label => switch (this) {
        StatusObra.emAndamento => 'Em andamento',
        StatusObra.pausada => 'Pausada',
        StatusObra.concluida => 'Concluída',
      };

  static StatusObra fromString(String? v) => StatusObra.values.firstWhere(
        (s) => s.name == v,
        orElse: () => StatusObra.emAndamento,
      );
}

class ObraModel {
  final String id;
  final String nome;
  final String endereco;
  final String? cliente;
  final double orcamento;
  final DateTime dataInicio;
  final DateTime previsaoTermino;
  final StatusObra status;
  final String donoId;

  /// Usuários (mestres de obra) com acesso a esta obra.
  final List<String> equipeIds;

  /// Usuários (clientes) que acompanham esta obra sem ver custos.
  final List<String> clientesIds;

  /// Código curto que o dono compartilha para o mestre entrar na obra.
  final String codigoConvite;

  /// Código de convite do cliente — separado do da equipe, porque quem
  /// entra por ele não pode ver custo nenhum. Vazio nas obras criadas
  /// antes deste recurso; é gerado quando o dono convida o cliente.
  final String codigoCliente;
  final DateTime criadoEm;

  const ObraModel({
    required this.id,
    required this.nome,
    required this.endereco,
    this.cliente,
    required this.orcamento,
    required this.dataInicio,
    required this.previsaoTermino,
    this.status = StatusObra.emAndamento,
    required this.donoId,
    this.equipeIds = const [],
    this.clientesIds = const [],
    required this.codigoConvite,
    this.codigoCliente = '',
    required this.criadoEm,
  });

  int get duracaoDias => previsaoTermino.difference(dataInicio).inDays;

  int get diasDecorridos {
    final passados = DateTime.now().difference(dataInicio).inDays;
    return passados.clamp(0, duracaoDias);
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'endereco': endereco,
        'cliente': cliente,
        'orcamento': orcamento,
        'dataInicio': dataInicio.toIso8601String(),
        'previsaoTermino': previsaoTermino.toIso8601String(),
        'status': status.name,
        'donoId': donoId,
        'equipeIds': equipeIds,
        'clientesIds': clientesIds,
        'codigoCliente': codigoCliente,
        'codigoConvite': codigoConvite,
        'criadoEm': criadoEm.toIso8601String(),
      };

  factory ObraModel.fromMap(String id, Map<String, dynamic> map) => ObraModel(
        id: id,
        nome: map['nome'] ?? '',
        endereco: map['endereco'] ?? '',
        cliente: map['cliente'],
        orcamento: (map['orcamento'] ?? 0).toDouble(),
        dataInicio:
            DateTime.tryParse(map['dataInicio'] ?? '') ?? DateTime.now(),
        previsaoTermino: DateTime.tryParse(map['previsaoTermino'] ?? '') ??
            DateTime.now(),
        status: StatusObra.fromString(map['status']),
        donoId: map['donoId'] ?? '',
        equipeIds: List<String>.from(map['equipeIds'] ?? const []),
        clientesIds: List<String>.from(map['clientesIds'] ?? const []),
        codigoCliente: map['codigoCliente'] ?? '',
        codigoConvite: map['codigoConvite'] ?? '',
        criadoEm: DateTime.tryParse(map['criadoEm'] ?? '') ?? DateTime.now(),
      );

  ObraModel copyWith({
    String? nome,
    String? endereco,
    String? cliente,
    double? orcamento,
    DateTime? dataInicio,
    DateTime? previsaoTermino,
    StatusObra? status,
    List<String>? equipeIds,
    List<String>? clientesIds,
    String? codigoCliente,
  }) =>
      ObraModel(
        id: id,
        nome: nome ?? this.nome,
        endereco: endereco ?? this.endereco,
        cliente: cliente ?? this.cliente,
        orcamento: orcamento ?? this.orcamento,
        dataInicio: dataInicio ?? this.dataInicio,
        previsaoTermino: previsaoTermino ?? this.previsaoTermino,
        status: status ?? this.status,
        donoId: donoId,
        equipeIds: equipeIds ?? this.equipeIds,
        clientesIds: clientesIds ?? this.clientesIds,
        codigoConvite: codigoConvite,
        codigoCliente: codigoCliente ?? this.codigoCliente,
        criadoEm: criadoEm,
      );
}
