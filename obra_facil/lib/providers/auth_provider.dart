import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/usuario_model.dart';
import '../services/auth_service.dart';

/// Estado global de autenticação: quem está logado e qual o seu perfil.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<User?>? _sub;

  UsuarioModel? _usuario;
  bool _inicializando = true;

  AuthProvider(this._authService) {
    _sub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  UsuarioModel? get usuario => _usuario;
  bool get logado => _usuario != null;
  bool get inicializando => _inicializando;
  bool get ehDono => _usuario?.ehDono ?? false;
  bool get ehCliente => _usuario?.ehCliente ?? false;

  /// E-mail confirmado pelo link. O cliente só entra depois disso; para
  /// dono e mestre é só um aviso, para não travar quem já usa o app.
  bool get emailVerificado => _emailVerificado;
  bool _emailVerificado = false;

  String? get emailPendente => _authService.emailAtual;

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _usuario = null;
      _emailVerificado = false;
    } else {
      _usuario = await _authService.carregarPerfil(user.uid);
      _emailVerificado = user.emailVerified;
    }
    _inicializando = false;
    notifyListeners();
  }

  /// Confere no Firebase se o link de confirmação já foi clicado.
  Future<bool> atualizarVerificacao() async {
    final verificado = await _authService.recarregarVerificacao();
    if (verificado != _emailVerificado) {
      _emailVerificado = verificado;
      notifyListeners();
    }
    return verificado;
  }

  /// Retorna null em caso de sucesso, ou a mensagem de erro.
  Future<String?> reenviarVerificacao() async {
    try {
      await _authService.reenviarVerificacao();
      return null;
    } catch (e) {
      return AuthService.mensagemErro(e);
    }
  }

  /// Retorna null em caso de sucesso, ou a mensagem de erro.
  Future<String?> entrar(String email, String senha) async {
    try {
      _usuario = await _authService.entrar(email: email, senha: senha);
      _emailVerificado = _authService.emailVerificado;
      notifyListeners();
      return null;
    } catch (e) {
      return AuthService.mensagemErro(e);
    }
  }

  Future<String?> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required PerfilUsuario perfil,
  }) async {
    try {
      _usuario = await _authService.cadastrar(
        nome: nome,
        email: email,
        senha: senha,
        perfil: perfil,
      );
      _emailVerificado = _authService.emailVerificado;
      notifyListeners();
      return null;
    } catch (e) {
      return AuthService.mensagemErro(e);
    }
  }

  Future<String?> recuperarSenha(String email) async {
    try {
      await _authService.recuperarSenha(email);
      return null;
    } catch (e) {
      return AuthService.mensagemErro(e);
    }
  }

  Future<void> sair() async {
    await _authService.sair();
    _usuario = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
