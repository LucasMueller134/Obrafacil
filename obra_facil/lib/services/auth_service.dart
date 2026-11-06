import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import '../models/usuario_model.dart';

/// O que volta de entrar com o Google: o perfil do app (nulo quando a
/// conta é nova aqui) e o nome e o e-mail da conta Google.
class EntradaGoogle {
  const EntradaGoogle({this.perfil, this.nome, this.email});

  final UsuarioModel? perfil;
  final String? nome;
  final String? email;
}

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
    // Confirmação do e-mail: é o que separa um endereço real de um
    // inventado no cadastro. Falhar aqui (sem rede, cota do Firebase) não
    // pode derrubar o cadastro que já foi feito — a tela de confirmação
    // tem botão de reenviar.
    try {
      await cred.user!.sendEmailVerification();
    } catch (_) {}
    return usuario;
  }

  /// O e-mail desta sessão já foi confirmado?
  bool get emailVerificado => _auth.currentUser?.emailVerified ?? false;

  String? get emailAtual => _auth.currentUser?.email;

  Future<void> reenviarVerificacao() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Rebusca o usuário no Firebase para ver se o link já foi clicado —
  /// a confirmação acontece fora do app, então o estado local envelhece.
  Future<bool> recarregarVerificacao() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
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

  // ------------------------------------------------------------ Google

  /// O login com Google está configurado neste build?
  bool get googleDisponivel =>
      DefaultFirebaseOptions.googleWebClientId.isNotEmpty;

  Future<void>? _googlePronto;

  /// Prepara o login do Google uma vez só (se falhar, tenta de novo na
  /// próxima).
  Future<void> _iniciarGoogle() => _googlePronto ??= GoogleSignIn.instance
          .initialize(serverClientId: DefaultFirebaseOptions.googleWebClientId)
          .catchError((Object e) {
        _googlePronto = null;
        throw e;
      });

  /// Entra com uma conta Google escolhida no seletor do Android. Devolve
  /// null se a pessoa fechou o seletor.
  Future<EntradaGoogle?> entrarComGoogle() async {
    await _iniciarGoogle();
    final GoogleSignInAccount conta;
    try {
      conta = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = conta.authentication.idToken;
    if (idToken == null) {
      throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'O Google não devolveu o idToken.');
    }
    final UserCredential cred;
    try {
      cred = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken));
    } on FirebaseAuthException catch (e) {
      // "invalid-credential" aqui não é senha errada: é o Google.
      if (e.code != 'invalid-credential') rethrow;
      throw GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError, description: e.message);
    }
    final user = cred.user!;
    return EntradaGoogle(
      perfil: await carregarPerfil(user.uid),
      nome: user.displayName ?? conta.displayName,
      email: user.email ?? conta.email,
    );
  }

  /// Cria o perfil do app para quem já entrou no Firebase (pelo Google) e
  /// ainda não tem.
  Future<UsuarioModel> criarPerfil({
    required String nome,
    required PerfilUsuario perfil,
  }) async {
    final user = _auth.currentUser!;
    final email = user.email ?? '';
    final nomeFinal = nome.trim().isNotEmpty
        ? nome.trim()
        : (user.displayName?.trim().isNotEmpty ?? false)
            ? user.displayName!.trim()
            : email.split('@').first;
    final usuario = UsuarioModel(
      id: user.uid,
      nome: nomeFinal,
      email: email,
      perfil: perfil,
      criadoEm: DateTime.now(),
    );
    await _db.collection('usuarios').doc(usuario.id).set(usuario.toMap());
    if (user.displayName != nomeFinal) {
      try {
        await user.updateDisplayName(nomeFinal);
      } catch (_) {}
    }
    return usuario;
  }

  /// Nome da conta que entrou (o do Google, para sugerir no perfil).
  String? get nomeDaConta => _auth.currentUser?.displayName;

  Future<void> sair() async {
    final comGoogle = _auth.currentUser?.providerData
            .any((p) => p.providerId == GoogleAuthProvider.PROVIDER_ID) ??
        false;
    await _auth.signOut();
    // Sem isto o Android lembra a conta e não deixa escolher outra.
    if (comGoogle && googleDisponivel) {
      try {
        await _iniciarGoogle();
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
  }

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
        case 'invalid-recipient-email':
        case 'auth/invalid-email-verified':
          return 'Não foi possível enviar para este e-mail. Confira se '
              'está escrito certo.';
        case 'account-exists-with-different-credential':
          return 'Este e-mail já tem conta com senha. Entre com o e-mail '
              'e a senha.';
        case 'user-disabled':
          return 'Esta conta foi desativada.';
        case 'operation-not-allowed':
          return 'Este jeito de entrar ainda não está liberado. Use o '
              'e-mail e a senha.';
      }
    }
    if (e is GoogleSignInException) {
      switch (e.code) {
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'O login com Google ainda não está configurado. Use o '
              'e-mail e a senha.';
        case GoogleSignInExceptionCode.uiUnavailable:
          return 'Não deu para abrir as contas Google deste celular.';
        default:
          return 'Não foi possível entrar com o Google. Tente de novo.';
      }
    }
    return 'Não foi possível concluir. Tente novamente.';
  }
}
