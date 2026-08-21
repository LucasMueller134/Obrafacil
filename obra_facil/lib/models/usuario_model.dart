/// Perfil de acesso do usuário.
enum PerfilUsuario {
  dono,
  mestre,

  /// Quem contratou a obra: acompanha o andamento, sem ver dinheiro.
  cliente;

  String get label => switch (this) {
        PerfilUsuario.dono => 'Dono / Gestor',
        PerfilUsuario.mestre => 'Mestre de obras',
        PerfilUsuario.cliente => 'Cliente',
      };

  String get descricao => switch (this) {
        PerfilUsuario.dono =>
          'Cria as obras, aprova lançamentos e vê todos os custos',
        PerfilUsuario.mestre =>
          'Lança gastos do canteiro e registra o diário da obra',
        PerfilUsuario.cliente =>
          'Acompanha o andamento da obra que contratou',
      };

  static PerfilUsuario fromString(String? v) =>
      PerfilUsuario.values.firstWhere(
        (p) => p.name == v,
        orElse: () => PerfilUsuario.mestre,
      );
}

class UsuarioModel {
  final String id;
  final String nome;
  final String email;
  final PerfilUsuario perfil;
  final DateTime criadoEm;

  const UsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    required this.criadoEm,
  });

  bool get ehDono => perfil == PerfilUsuario.dono;

  bool get ehCliente => perfil == PerfilUsuario.cliente;

  /// Quem trabalha na obra — dono e mestre. O cliente é de fora.
  bool get ehDaEquipe => !ehCliente;

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'email': email,
        'perfil': perfil.name,
        'criadoEm': criadoEm.toIso8601String(),
      };

  factory UsuarioModel.fromMap(String id, Map<String, dynamic> map) =>
      UsuarioModel(
        id: id,
        nome: map['nome'] ?? '',
        email: map['email'] ?? '',
        perfil: PerfilUsuario.fromString(map['perfil']),
        criadoEm:
            DateTime.tryParse(map['criadoEm'] ?? '') ?? DateTime.now(),
      );
}
