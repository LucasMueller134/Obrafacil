// lib/models/usuario_model.dart
class UsuarioModel {
  final String id;
  final String nome;
  final String email;
  final String perfil; // 'dono' ou 'mestre'
  final List<String> obrasIds;
  final DateTime criadoEm;

  UsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.obrasIds = const [],
    required this.criadoEm,
  });

  bool get isDono => perfil == 'dono';
  bool get isMestre => perfil == 'mestre';

  Map<String, dynamic> toMap() => {
    'id': id,
    'nome': nome,
    'email': email,
    'perfil': perfil,
    'obrasIds': obrasIds,
    'criadoEm': criadoEm.toIso8601String(),
  };

  factory UsuarioModel.fromMap(Map<String, dynamic> map) => UsuarioModel(
    id: map['id'],
    nome: map['nome'],
    email: map['email'],
    perfil: map['perfil'],
    obrasIds: List<String>.from(map['obrasIds'] ?? []),
    criadoEm: DateTime.parse(map['criadoEm']),
  );
}
