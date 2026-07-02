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

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      _usuario = null;
    } else {
      _usuario = await _authService.carregarPerfil(user.uid);
    }
    _inicializando = false;
    notifyListeners();
  }

  /// Retorna null em caso de sucesso, ou a mensagem de erro.
  Future<String?> entrar(String email, String senha) async {
    try {
      _usuario = await _authService.entrar(email: email, senha: senha);
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
