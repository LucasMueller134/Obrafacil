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

  /// Entrou pelo Google, mas a conta é nova no app: falta escolher o
  /// perfil. Fica escondido enquanto uma entrada está em andamento (a
  /// tela que pediu cuida do resultado).
  bool get semPerfil => _semPerfil && _ocupado == 0;
  bool _semPerfil = false;

  /// O login com Google está configurado neste build?
  bool get googleDisponivel => _authService.googleDisponivel;

  /// Nome da conta Google, para sugerir no perfil.
  String? get nomeDaConta => _authService.nomeDaConta;

  /// Entradas em andamento (entrar, cadastrar, Google).
  int _ocupado = 0;

  /// Conta as mudanças de quem está logado: a leitura do perfil que
  /// começou antes de uma entrada mais nova não sobrescreve o resultado
  /// dela (o Firebase avisa do login antes de o perfil ser gravado).
  int _versao = 0;

  Future<void> _onAuthChanged(User? user) async {
    final vez = ++_versao;
    UsuarioModel? perfil;
    if (user != null) perfil = await _authService.carregarPerfil(user.uid);
    if (vez == _versao) {
      _usuario = perfil;
      _semPerfil = user != null && perfil == null;
      _emailVerificado = user?.emailVerified ?? false;
    }
    _inicializando = false;
    notifyListeners();
  }

  /// Grava o resultado de uma entrada feita pela tela.
  void _aplicar(UsuarioModel? usuario) {
    _versao++;
    _usuario = usuario;
    _semPerfil = usuario == null && _authService.usuarioFirebase != null;
    _emailVerificado = _authService.emailVerificado;
  }

  /// Roda uma entrada pedida pela tela: devolve null se deu certo (ou se a
  /// pessoa desistiu), ou a mensagem de erro.
  Future<String?> _entrada(Future<void> Function() acao) async {
    _ocupado++;
    try {
      await acao();
      return null;
    } catch (e) {
      return AuthService.mensagemErro(e);
    } finally {
      _ocupado--;
      notifyListeners();
    }
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
  Future<String?> entrar(String email, String senha) => _entrada(() async {
        _aplicar(await _authService.entrar(email: email, senha: senha));
      });

  Future<String?> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required PerfilUsuario perfil,
  }) =>
      _entrada(() async {
        _aplicar(await _authService.cadastrar(
          nome: nome,
          email: email,
          senha: senha,
          perfil: perfil,
        ));
      });

  /// Entra com o Google. Com o [perfil] (vindo do cadastro), uma conta
  /// nova já sai criada com ele; sem, a conta nova fica [semPerfil] e o
  /// app pede a escolha. Conta que já existe só entra.
  Future<String?> entrarComGoogle({PerfilUsuario? perfil}) =>
      _entrada(() async {
        final entrada = await _authService.entrarComGoogle();
        if (entrada == null) return; // fechou o seletor de contas
        var usuario = entrada.perfil;
        if (usuario == null && perfil != null) {
          usuario = await _authService.criarPerfil(
              nome: entrada.nome ?? '', perfil: perfil);
        }
        _aplicar(usuario);
      });

  /// Cria o perfil de quem entrou pelo Google e ainda não tinha.
  Future<String?> completarPerfil({
    required String nome,
    required PerfilUsuario perfil,
  }) =>
      _entrada(() async {
        _aplicar(await _authService.criarPerfil(nome: nome, perfil: perfil));
      });

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
    _versao++;
    _usuario = null;
    _semPerfil = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
