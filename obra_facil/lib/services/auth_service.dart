// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario_model.dart';
import '../constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UsuarioModel?> login(String email, String senha) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
      if (credential.user != null) {
        return await getUsuario(credential.user!.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _traduzirErro(e.code);
    }
  }

  Future<UsuarioModel> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String perfil,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final usuario = UsuarioModel(
        id: credential.user!.uid,
        nome: nome,
        email: email,
        perfil: perfil,
        criadoEm: DateTime.now(),
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(usuario.id)
          .set(usuario.toMap());

      await credential.user!.updateDisplayName(nome);

      return usuario;
    } on FirebaseAuthException catch (e) {
      throw _traduzirErro(e.code);
    }
  }

  Future<UsuarioModel?> getUsuario(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (doc.exists) {
      return UsuarioModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> resetarSenha(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _traduzirErro(e.code);
    }
  }

  String _traduzirErro(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Usuário não encontrado';
      case 'wrong-password':
        return 'Senha incorreta';
      case 'email-already-in-use':
        return 'E-mail já cadastrado';
      case 'weak-password':
        return 'Senha muito fraca (mínimo 6 caracteres)';
      case 'invalid-email':
        return 'E-mail inválido';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde';
      default:
        return 'Erro de autenticação. Tente novamente';
    }
  }
}
