import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _carregando = false;
  bool _carregandoGoogle = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    final erro = await context
        .read<AuthProvider>()
        .entrar(_emailCtrl.text, _senhaCtrl.text);
    if (!mounted) return;
    setState(() => _carregando = false);
    if (erro != null) {
      unawaited(Tato.erro());
      mostrarAviso(context, erro);
    }
  }

  /// Entra com a conta Google do celular. Conta nova no app segue para a
  /// escolha do perfil (o router leva).
  Future<void> _entrarComGoogle() async {
    setState(() => _carregandoGoogle = true);
    final erro = await context.read<AuthProvider>().entrarComGoogle();
    if (!mounted) return;
    setState(() => _carregandoGoogle = false);
    if (erro != null) {
      unawaited(Tato.erro());
      mostrarAviso(context, erro);
    }
  }

  Future<void> _recuperarSenha() async {
    if (Validators.email(_emailCtrl.text) != null) {
      mostrarAviso(context, 'Digite seu e-mail no campo acima primeiro.');
      return;
    }
    final erro =
        await context.read<AuthProvider>().recuperarSenha(_emailCtrl.text);
    if (!mounted) return;
    mostrarAviso(
      context,
      erro ?? 'Enviamos um link de recuperação para ${_emailCtrl.text.trim()}.',
    );
  }

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: Builder(builder: _tela));

  Widget _tela(BuildContext context) {
    final c = context.cores;
    final altura = MediaQuery.sizeOf(context).height;
    // A maquete parada, em obra: alvenaria pronta e o que falta tracejado.
    // É a ideia do app numa imagem (a mesma da central da obra), e custa
    // uma textura só por quadro (o teclado e o cursor não a redesenham).
    final maquete = MaqueteObra.caminhoReserva(estado: 3, escuro: c.ehEscuro);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.margem,
            Espaco.e24,
            Espaco.margem,
            Espaco.e24,
          ),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Rotulo('Gestão de obras'),
                  const SizedBox(height: Espaco.e4),
                  Semantics(
                    header: true,
                    child: Text(
                      AppConstants.appName,
                      style: Tipografia.tituloTela.copyWith(color: c.grafite),
                    ),
                  ),
                  const SizedBox(height: Espaco.e4),
                  Text(
                    'Gestão inteligente de obras na palma da mão',
                    style: Tipografia.apoio.copyWith(color: c.grafite2),
                  ),
                  const SizedBox(height: Espaco.e8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: (altura * 0.28).clamp(140.0, 240.0),
                    ),
                    child: AspectRatio(
                      aspectRatio: 3 / 2,
                      child: Image.asset(
                        maquete,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: Espaco.e16),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: Espaco.e16),
                  TextFormField(
                    controller: _senhaCtrl,
                    obscureText: !_senhaVisivel,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip:
                            _senhaVisivel ? 'Esconder senha' : 'Mostrar senha',
                        icon: Icon(_senhaVisivel
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                    validator: Validators.senha,
                    onFieldSubmitted: (_) => _entrar(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _recuperarSenha,
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                  const SizedBox(height: Espaco.e8),
                  BotaoPrincipal(
                    rotulo: 'Entrar',
                    grande: true,
                    expandir: true,
                    carregando: _carregando,
                    aoTocar: _carregando || _carregandoGoogle ? null : _entrar,
                  ),
                  if (context.read<AuthProvider>().googleDisponivel) ...[
                    const SizedBox(height: Espaco.e24),
                    const LinhaCota(legenda: 'Ou'),
                    const SizedBox(height: Espaco.e16),
                    BotaoContorno(
                      rotulo: 'Entrar com o Google',
                      simbolo: const LogoGoogle(),
                      expandir: true,
                      carregando: _carregandoGoogle,
                      aoTocar: _carregando || _carregandoGoogle
                          ? null
                          : () => unawaited(_entrarComGoogle()),
                    ),
                  ],
                  const SizedBox(height: Espaco.e32),
                  const LinhaCota(legenda: 'Primeira vez aqui?'),
                  const SizedBox(height: Espaco.e16),
                  BotaoContorno(
                    rotulo: 'Criar conta',
                    expandir: true,
                    aoTocar: () => context.push('/cadastro'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
