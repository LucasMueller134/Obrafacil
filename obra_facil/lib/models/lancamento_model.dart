import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum CategoriaCusto {
  maoDeObra,
  material,
  equipamento,
  outros;

  String get label => switch (this) {
        CategoriaCusto.maoDeObra => 'Mão de obra',
        CategoriaCusto.material => 'Material',
        CategoriaCusto.equipamento => 'Equipamento',
        CategoriaCusto.outros => 'Outros',
      };

  IconData get icone => switch (this) {
        CategoriaCusto.maoDeObra => Icons.engineering,
        CategoriaCusto.material => Icons.inventory_2,
        CategoriaCusto.equipamento => Icons.construction,
        CategoriaCusto.outros => Icons.receipt_long,
      };

  Color get cor => switch (this) {
        CategoriaCusto.maoDeObra => AppColors.catMaoDeObra,
        CategoriaCusto.material => AppColors.catMaterial,
        CategoriaCusto.equipamento => AppColors.catEquipamento,
        CategoriaCusto.outros => AppColors.catOutros,
      };

  static CategoriaCusto fromString(String? v) =>
      CategoriaCusto.values.firstWhere(
        (c) => c.name == v,
        orElse: () => CategoriaCusto.outros,
      );
}

/// Fluxo de aprovação: mestre lança → dono aprova ou rejeita.
enum StatusLancamento {
  pendente,
  aprovado,
  rejeitado;

  String get label => switch (this) {
        StatusLancamento.pendente => 'Pendente',
        StatusLancamento.aprovado => 'Aprovado',
        StatusLancamento.rejeitado => 'Rejeitado',
      };

  Color get cor => switch (this) {
        StatusLancamento.pendente => AppColors.alerta,
        StatusLancamento.aprovado => AppColors.sucesso,
        StatusLancamento.rejeitado => AppColors.erro,
      };

  static StatusLancamento fromString(String? v) =>
      StatusLancamento.values.firstWhere(
        (s) => s.name == v,
        orElse: () => StatusLancamento.pendente,
      );
}

/// Como o lançamento foi criado — usado para medir o uso das IAs.
enum OrigemLancamento {
  manual,
  ocr,
  voz;

  String get label => switch (this) {
        OrigemLancamento.manual => 'Manual',
        OrigemLancamento.ocr => 'Nota fiscal (OCR)',
        OrigemLancamento.voz => 'Por voz',
      };

  static OrigemLancamento fromString(String? v) =>
      OrigemLancamento.values.firstWhere(
        (o) => o.name == v,
        orElse: () => OrigemLancamento.manual,
      );
}

class LancamentoModel {
  final String id;
  final String obraId;
  final String descricao;
  final double valor;
  final CategoriaCusto categoria;
  final StatusLancamento status;
  final OrigemLancamento origem;
  final String? fornecedorId;
  final String? fornecedorNome;
  final String? fotoNotaUrl;
  final DateTime data;
  final String criadoPorId;
  final String criadoPorNome;
  final String? aprovadoPorId;
  final String? motivoRejeicao;
  final DateTime criadoEm;

  const LancamentoModel({
    required this.id,
    required this.obraId,
    required this.descricao,
    required this.valor,
    required this.categoria,
    this.status = StatusLancamento.pendente,
    this.origem = OrigemLancamento.manual,
    this.fornecedorId,
    this.fornecedorNome,
    this.fotoNotaUrl,
    required this.data,
    required this.criadoPorId,
    required this.criadoPorNome,
    this.aprovadoPorId,
    this.motivoRejeicao,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
        'obraId': obraId,
        'descricao': descricao,
        'valor': valor,
        'categoria': categoria.name,
        'status': status.name,
        'origem': origem.name,
        'fornecedorId': fornecedorId,
        'fornecedorNome': fornecedorNome,
        'fotoNotaUrl': fotoNotaUrl,
        'data': data.toIso8601String(),
        'criadoPorId': criadoPorId,
        'criadoPorNome': criadoPorNome,
        'aprovadoPorId': aprovadoPorId,
        'motivoRejeicao': motivoRejeicao,
        'criadoEm': criadoEm.toIso8601String(),
      };

  factory LancamentoModel.fromMap(String id, Map<String, dynamic> map) =>
      LancamentoModel(
        id: id,
        obraId: map['obraId'] ?? '',
        descricao: map['descricao'] ?? '',
        valor: (map['valor'] ?? 0).toDouble(),
        categoria: CategoriaCusto.fromString(map['categoria']),
        status: StatusLancamento.fromString(map['status']),
        origem: OrigemLancamento.fromString(map['origem']),
        fornecedorId: map['fornecedorId'],
        fornecedorNome: map['fornecedorNome'],
        fotoNotaUrl: map['fotoNotaUrl'],
        data: DateTime.tryParse(map['data'] ?? '') ?? DateTime.now(),
        criadoPorId: map['criadoPorId'] ?? '',
        criadoPorNome: map['criadoPorNome'] ?? '',
        aprovadoPorId: map['aprovadoPorId'],
        motivoRejeicao: map['motivoRejeicao'],
        criadoEm: DateTime.tryParse(map['criadoEm'] ?? '') ?? DateTime.now(),
      );

  LancamentoModel copyWith({
    String? descricao,
    double? valor,
    CategoriaCusto? categoria,
    StatusLancamento? status,
    String? fornecedorId,
    String? fornecedorNome,
    String? fotoNotaUrl,
    DateTime? data,
    String? aprovadoPorId,
    String? motivoRejeicao,
  }) =>
      LancamentoModel(
        id: id,
        obraId: obraId,
        descricao: descricao ?? this.descricao,
        valor: valor ?? this.valor,
        categoria: categoria ?? this.categoria,
        status: status ?? this.status,
        origem: origem,
        fornecedorId: fornecedorId ?? this.fornecedorId,
        fornecedorNome: fornecedorNome ?? this.fornecedorNome,
        fotoNotaUrl: fotoNotaUrl ?? this.fotoNotaUrl,
        data: data ?? this.data,
        criadoPorId: criadoPorId,
        criadoPorNome: criadoPorNome,
        aprovadoPorId: aprovadoPorId ?? this.aprovadoPorId,
        motivoRejeicao: motivoRejeicao ?? this.motivoRejeicao,
        criadoEm: criadoEm,
      );
}
