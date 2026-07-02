class FornecedorModel {
  final String id;

  /// Fornecedores pertencem ao dono e são compartilhados entre suas obras.
  final String donoId;
  final String nome;
  final String? telefone;
  final String? email;
  final String? cnpj;
  final String? observacoes;
  final DateTime criadoEm;

  const FornecedorModel({
    required this.id,
    required this.donoId,
    required this.nome,
    this.telefone,
    this.email,
    this.cnpj,
    this.observacoes,
    required this.criadoEm,
  });

  Map<String, dynamic> toMap() => {
        'donoId': donoId,
        'nome': nome,
        'telefone': telefone,
        'email': email,
        'cnpj': cnpj,
        'observacoes': observacoes,
        'criadoEm': criadoEm.toIso8601String(),
      };

  factory FornecedorModel.fromMap(String id, Map<String, dynamic> map) =>
      FornecedorModel(
        id: id,
        donoId: map['donoId'] ?? '',
        nome: map['nome'] ?? '',
        telefone: map['telefone'],
        email: map['email'],
        cnpj: map['cnpj'],
        observacoes: map['observacoes'],
        criadoEm: DateTime.tryParse(map['criadoEm'] ?? '') ?? DateTime.now(),
      );
}
