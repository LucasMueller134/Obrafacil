// Entrar e criar conta com o Google, com um Firebase falso: conta nova
// escolhe o perfil, conta que já existe só entra, o cadastro já cria com
// o perfil escolhido, fechar o seletor não muda nada, erro vira mensagem e,
// sem o Google configurado, o botão não aparece.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuthException, User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';
import 'package:obra_facil/services/auth_service.dart';

import 'visual/suporte/captura.dart';
import 'visual/suporte/dados_exemplo.dart';
import 'visual/suporte/fakes.dart';
import 'visual/suporte/plataforma.dart';

const _uid = 'conta-google-ana';
const _email = 'ana.souza@gmail.com';

/// Firebase falso com o Google: avisa do login antes de o perfil existir
/// (como o de verdade) e guarda os perfis criados.
class _GoogleFalso implements AuthService {
  _GoogleFalso({
    this.disponivel = true,
    this.cancelar = false,
    this.falha,
    Map<String, UsuarioModel>? perfis,
  }) : perfis = perfis ?? {};

  final bool disponivel;
  final bool cancelar;
  final Object? falha;
  final Map<String, UsuarioModel> perfis;
  final pedidos = <String>[];

  final _mudancas = StreamController<User?>();
  User? _atual;

  @override
  Stream<User?> get authStateChanges => _mudancas.stream;

  @override
  User? get usuarioFirebase => _atual;

  @override
  bool get googleDisponivel => disponivel;

  @override
  String? get nomeDaConta => _atual == null ? null : 'Ana Souza';

  @override
  bool get emailVerificado => _atual != null;

  @override
  String? get emailAtual => _atual?.email;

  @override
  Future<UsuarioModel?> carregarPerfil(String uid) async {
    // A leitura demora: o perfil criado no meio não pode se perder.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return perfis[uid];
  }

  @override
  Future<EntradaGoogle?> entrarComGoogle() async {
    pedidos.add('google');
    if (cancelar) return null;
    if (falha != null) throw falha!;
    _atual = UsuarioFirebaseFalso(_uid, email: _email);
    _mudancas.add(_atual);
    return EntradaGoogle(
        perfil: perfis[_uid], nome: 'Ana Souza', email: _email);
  }

  @override
  Future<UsuarioModel> criarPerfil({
    required String nome,
    required PerfilUsuario perfil,
  }) async {
    pedidos.add('criarPerfil $nome ${perfil.name}');
    return perfis[_uid] = UsuarioModel(
      id: _uid,
      nome: nome,
      email: _email,
      perfil: perfil,
      criadoEm: DateTime(2026, 11, 6),
    );
  }

  @override
  Future<void> sair() async {
    pedidos.add('sair');
    _atual = null;
    _mudancas.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '_GoogleFalso não implementa ${invocation.memberName}.');
}

class _App {
  _App(this.auth, this.router);

  final AuthProvider auth;
  final dynamic router;

  String get rota => router.routerDelegate.currentConfiguration.uri.toString();
}

Future<_App> _abrir(WidgetTester tester, _GoogleFalso servico,
    {String rota = '/login'}) async {
  final view = tester.view
    ..devicePixelRatio = 2
    ..physicalSize = const Size(390, 844) * 2;
  addTearDown(view.reset);
  instalarPluginsFalsos();
  final auth = AuthProvider(servico);
  final router = criarRouter(auth);
  await tester.pumpWidget(AppDeCaptura(
    auth: auth,
    db: FirestoreFalso(DadosExemplo.padrao()),
    router: router,
  ));
  servico._mudancas.add(null); // ninguém logado ainda
  await assentar(tester);
  if (rota != '/login') {
    router.go(rota);
    await assentar(tester);
  }
  return _App(auth, router);
}

Future<void> _fechar(WidgetTester tester, _App app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  app.router.dispose();
  app.auth.dispose();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await assentar(tester);
}

void main() {
  setUpAll(prepararCapturas);

  testWidgets('login: conta Google nova escolhe o perfil e entra',
      (tester) async {
    final servico = _GoogleFalso();
    final app = await _abrir(tester, servico);

    await _tocar(tester, find.text('Entrar com o Google'));
    expect(app.rota, '/completar-perfil');
    expect(find.text('FALTA POUCO · 1 DE 2'), findsOneWidget);
    expect(find.textContaining(_email), findsOneWidget);

    await _tocar(tester, find.text(PerfilUsuario.dono.label));
    expect(find.text('Seu nome'), findsOneWidget);
    // O nome vem da conta Google; não pede e-mail nem senha.
    expect(find.widgetWithText(TextFormField, 'Ana Souza'), findsOneWidget);
    expect(find.text('Senha'), findsNothing);

    await _tocar(tester, find.text('Criar conta'));
    expect(servico.pedidos, ['google', 'criarPerfil Ana Souza dono']);
    expect(app.auth.usuario?.perfil, PerfilUsuario.dono);
    expect(app.rota, '/obras');
    expect(tester.takeException(), isNull);
    await _fechar(tester, app);
  });

  testWidgets('cadastro: continuar com o Google já cria com o perfil escolhido',
      (tester) async {
    final servico = _GoogleFalso();
    final app = await _abrir(tester, servico, rota: '/cadastro');

    await _tocar(tester, find.text(PerfilUsuario.mestre.label));
    await _tocar(tester, find.text('Continuar com o Google'));
    expect(servico.pedidos, ['google', 'criarPerfil Ana Souza mestre']);
    expect(app.auth.usuario?.perfil, PerfilUsuario.mestre);
    // A leitura do perfil que começou antes não apaga o que foi criado.
    await tester.pump(const Duration(seconds: 1));
    expect(app.auth.usuario?.perfil, PerfilUsuario.mestre);
    expect(app.rota, '/obras');
    await _fechar(tester, app);
  });

  testWidgets('conta Google que já existe só entra', (tester) async {
    final servico = _GoogleFalso(perfis: {
      _uid: UsuarioModel(
        id: _uid,
        nome: 'Ana Souza',
        email: _email,
        perfil: PerfilUsuario.cliente,
        criadoEm: DateTime(2026, 1, 1),
      ),
    });
    final app = await _abrir(tester, servico);

    await _tocar(tester, find.text('Entrar com o Google'));
    expect(servico.pedidos, ['google']);
    expect(app.rota, '/cliente');
    await _fechar(tester, app);
  });

  testWidgets('fechar o seletor de contas não muda nada', (tester) async {
    final servico = _GoogleFalso(cancelar: true);
    final app = await _abrir(tester, servico);

    await _tocar(tester, find.text('Entrar com o Google'));
    expect(app.rota, '/login');
    expect(find.byType(SnackBar), findsNothing);
    await _fechar(tester, app);
  });

  testWidgets('conta nova: "usar outra conta" sai e volta ao login',
      (tester) async {
    final servico = _GoogleFalso();
    final app = await _abrir(tester, servico);

    await _tocar(tester, find.text('Entrar com o Google'));
    expect(app.rota, '/completar-perfil');
    await _tocar(tester, find.text('Usar outra conta'));
    expect(servico.pedidos, ['google', 'sair']);
    expect(app.rota, '/login');
    await _fechar(tester, app);
  });

  testWidgets('erro do Google vira mensagem', (tester) async {
    final servico = _GoogleFalso(
        falha: FirebaseAuthException(
            code: 'account-exists-with-different-credential'));
    final app = await _abrir(tester, servico);

    await _tocar(tester, find.text('Entrar com o Google'));
    expect(find.textContaining('já tem conta com senha'), findsOneWidget);
    expect(app.rota, '/login');
    await _fechar(tester, app);
  });

  testWidgets('sem o Google configurado, o botão não aparece', (tester) async {
    final servico = _GoogleFalso(disponivel: false);
    final app = await _abrir(tester, servico);
    expect(find.text('Entrar com o Google'), findsNothing);

    app.router.go('/cadastro');
    await assentar(tester);
    await _tocar(tester, find.text(PerfilUsuario.dono.label));
    expect(find.text('Continuar com o Google'), findsNothing);
    expect(find.text('Senha'), findsOneWidget);
    await _fechar(tester, app);
  });

  test('as falhas do Google viram mensagens', () {
    expect(
      AuthService.mensagemErro(const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError)),
      contains('ainda não está configurado'),
    );
    expect(
      AuthService.mensagemErro(const GoogleSignInException(
          code: GoogleSignInExceptionCode.interrupted)),
      'Não foi possível entrar com o Google. Tente de novo.',
    );
  });
}
