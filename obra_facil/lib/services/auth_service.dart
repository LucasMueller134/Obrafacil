import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario_model.dart';

/// Autenticação (Firebase Auth) + perfil do usuário no Firestore.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get usuarioFirebase => _auth.currentUser;

  Future<UsuarioModel?> carregarPerfil(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return null;
    return UsuarioModel.fromMap(doc.id, doc.data()!);
  }

  Future<UsuarioModel> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required PerfilUsuario perfil,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
    final usuario = UsuarioModel(
      id: cred.user!.uid,
      nome: nome.trim(),
      email: email.trim(),
      perfil: perfil,
      criadoEm: DateTime.now(),
    );
    await _db.collection('usuarios').doc(usuario.id).set(usuario.toMap());
    await cred.user!.updateDisplayName(usuario.nome);
    return usuario;
  }

  Future<UsuarioModel?> entrar({
    required String email,
    required String senha,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: senha,
    );
    return carregarPerfil(cred.user!.uid);
  }

  Future<void> sair() => _auth.signOut();

  Future<void> recuperarSenha(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Traduz os códigos de erro do Firebase Auth para mensagens amigáveis.
  static String mensagemErro(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou senha incorretos.';
        case 'email-already-in-use':
          return 'Já existe uma conta com este e-mail.';
        case 'weak-password':
          return 'Senha muito fraca. Use pelo menos 6 caracteres.';
        case 'network-request-failed':
          return 'Sem conexão. Verifique sua internet.';
        case 'too-many-requests':
          return 'Muitas tentativas. Aguarde alguns minutos.';
      }
    }
    return 'Não foi possível concluir. Tente novamente.';
  }
}
