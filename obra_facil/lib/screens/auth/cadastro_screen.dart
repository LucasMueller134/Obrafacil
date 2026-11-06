import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

/// Cadastro em duas etapas: primeiro quem você é, depois seus dados.
///
/// Os três perfis lado a lado não cabiam na largura de um celular — o
/// texto estourava por cima do formulário. Separado assim cada perfil
/// ganha uma linha inteira e o formulário aparece sem disputa de espaço.
///
/// Com [completarConta], é o fim de uma entrada pelo Google com conta nova
/// no app: as mesmas duas etapas, só que a segunda pede só o nome.
class CadastroScreen extends StatelessWidget {
  const CadastroScreen({super.key, this.completarConta = false});

  final bool completarConta;

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _Cadastro(completarConta: completarConta));
}

class _Cadastro extends StatefulWidget {
  const _Cadastro({required this.completarConta});

  final bool completarConta;

  @override
  State<_Cadastro> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<_Cadastro> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  PerfilUsuario? _perfil;
  bool _carregando = false;
  bool _carregandoGoogle = false;
  bool _senhaVisivel = false;

  bool get _completar => widget.completarConta;

  @override
  void initState() {
    super.initState();
    // O nome da conta Google já vem preenchido.
    if (_completar) {
      _nomeCtrl.text = context.read<AuthProvider>().nomeDaConta ?? '';
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(Tato.erro());
      return;
    }
    setState(() => _carregando = true);
    final auth = context.read<AuthProvider>();
    final erro = _completar
        ? await auth.completarPerfil(nome: _nomeCtrl.text, perfil: _perfil!)
        : await auth.cadastrar(
            nome: _nomeCtrl.text,
            email: _emailCtrl.text,
            senha: _senhaCtrl.text,
            perfil: _perfil!,
          );
    if (!mounted) return;
    setState(() => _carregando = false);
    if (erro != null) {
      unawaited(Tato.erro());
      mostrarAviso(context, erro);
    }
    // Deu certo: o router leva para a área do perfil escolhido.
  }

  /// Cria a conta com o Google, já com o perfil escolhido. Se a conta
  /// Google já tem cadastro no app, só entra.
  Future<void> _entrarComGoogle() async {
    setState(() => _carregandoGoogle = true);
    final erro =
        await context.read<AuthProvider>().entrarComGoogle(perfil: _perfil);
    if (!mounted) return;
    setState(() => _carregandoGoogle = false);
    if (erro != null) {
      unawaited(Tato.erro());
      mostrarAviso(context, erro);
    }
  }

  /// Desiste da conta Google nova: sai dela e volta para o login.
  void _usarOutraConta() => unawaited(context.read<AuthProvider>().sair());

  void _voltar() {
    if (_perfil != null) {
      setState(() => _perfil = null);
      return;
    }
    if (_completar) return _usarOutraConta();
    context.canPop() ? context.pop() : context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _voltar),
      ),
      body: SafeArea(
        top: false,
        // Uma etapa por vez: a anterior sai do desenho na hora, sem ficar
        // por baixo da que entra.
        child: AnimatedSwitcher(
          duration: context.duracao(Movimento.medio),
          switchInCurve: Movimento.entrar,
          layoutBuilder: (atual, __) => atual ?? const SizedBox.shrink(),
          transitionBuilder: (filho, animacao) => FadeTransition(
            opacity: animacao,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(animacao),
              child: filho,
            ),
          ),
          child: _perfil == null ? _escolhaDePerfil() : _formulario(),
        ),
      ),
      bottomNavigationBar: _perfil == null
          ? null
          : BarraDeAcao(
              principal: BotaoPrincipal(
                rotulo: 'Criar conta',
                grande: true,
                expandir: true,
                carregando: _carregando,
                aoTocar: _carregando || _carregandoGoogle
                    ? null
                    : () => unawaited(_cadastrar()),
              ),
            ),
    );
  }

  Widget _cabecalho(String etapa, String titulo, String texto) {
    final c = context.cores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Rotulo(etapa),
        const SizedBox(height: Espaco.e4),
        Semantics(
          header: true,
          child: Text(titulo,
              style: Tipografia.tituloTela.copyWith(color: c.grafite)),
        ),
        const SizedBox(height: Espaco.e8),
        Text(texto, style: Tipografia.corpo.copyWith(color: c.grafite2)),
      ],
    );
  }

  // ------------------------------------------------------- Etapa 1

  Widget _escolhaDePerfil() {
    const perfis = [
      (PerfilUsuario.dono, Icons.business_center_outlined),
      (PerfilUsuario.mestre, Icons.engineering_outlined),
      (PerfilUsuario.cliente, Icons.holiday_village_outlined),
    ];
    return SingleChildScrollView(
      key: const ValueKey('perfil'),
      padding: const EdgeInsets.fromLTRB(
          Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecalho(
              _completar ? 'Falta pouco · 1 de 2' : 'Criar conta · 1 de 2',
              'Como você vai usar o Obra na Mão?',
              _completar
                  ? 'Você entrou com ${context.read<AuthProvider>().emailPendente ?? 'a sua conta Google'}. '
                      'Escolha o seu perfil. Isso define o que você vê no app.'
                  : 'Escolha o seu perfil. Isso define o que você vê no app.'),
          const SizedBox(height: Espaco.e24),
          Folha(
            preenchimento: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < perfis.length; i++)
                  LinhaLista(
                    icone: perfis[i].$2,
                    titulo: perfis[i].$1.label,
                    apoio: perfis[i].$1.descricao,
                    margemHorizontal: Espaco.e12,
                    divisoria: i < perfis.length - 1,
                    seta: true,
                    vibrar: true,
                    aoTocar: () => setState(() => _perfil = perfis[i].$1),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Espaco.e24),
          if (_completar) ...[
            const LinhaCota(legenda: 'Não é você?'),
            const SizedBox(height: Espaco.e16),
            BotaoContorno(
              rotulo: 'Usar outra conta',
              expandir: true,
              aoTocar: _usarOutraConta,
            ),
          ] else ...[
            const LinhaCota(legenda: 'Já tem conta?'),
            const SizedBox(height: Espaco.e16),
            BotaoContorno(
              rotulo: 'Entrar',
              expandir: true,
              aoTocar: () =>
                  context.canPop() ? context.pop() : context.go('/login'),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------- Etapa 2

  Widget _formulario() {
    final c = context.cores;
    final perfil = _perfil!;
    return SingleChildScrollView(
      key: const ValueKey('formulario'),
      padding: const EdgeInsets.fromLTRB(
          Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_completar)
              _cabecalho('Falta pouco · 2 de 2', 'Seu nome',
                  'É assim que a equipe vê você no app.')
            else
              _cabecalho('Criar conta · 2 de 2', 'Seus dados',
                  'Com eles você entra no app de qualquer celular.'),
            const SizedBox(height: Espaco.e16),
            // Lembra a escolha da etapa anterior e deixa trocar.
            Folha(
              preenchimento: EdgeInsets.zero,
              child: LinhaLista(
                icone: Icons.badge_outlined,
                titulo: 'Entrando como ${perfil.label}',
                apoio: 'Toque para trocar o perfil',
                margemHorizontal: Espaco.e12,
                aoTocar: () => setState(() => _perfil = null),
                seta: false,
                fim: Text('Trocar',
                    style: Tipografia.corpoForte.copyWith(color: c.marcaTexto)),
              ),
            ),
            const SizedBox(height: Espaco.e24),
            // O jeito mais rápido: a conta Google do celular, sem senha.
            if (!_completar &&
                context.read<AuthProvider>().googleDisponivel) ...[
              BotaoContorno(
                rotulo: 'Continuar com o Google',
                simbolo: const LogoGoogle(),
                expandir: true,
                carregando: _carregandoGoogle,
                aoTocar: _carregando || _carregandoGoogle
                    ? null
                    : () => unawaited(_entrarComGoogle()),
              ),
              const SizedBox(height: Espaco.e24),
              const LinhaCota(legenda: 'Ou com e-mail e senha'),
              const SizedBox(height: Espaco.e16),
            ],
            TextFormField(
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction:
                  _completar ? TextInputAction.done : TextInputAction.next,
              onFieldSubmitted: _completar && !_carregando
                  ? (_) => unawaited(_cadastrar())
                  : null,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: (v) => Validators.obrigatorio(v, 'O nome'),
            ),
            if (_completar)
              ..._avisoDoCliente(perfil)
            else
              ..._emailESenha(perfil),
          ],
        ),
      ),
    );
  }

  /// No fim de uma conta Google: o cliente ainda precisa do código.
  List<Widget> _avisoDoCliente(PerfilUsuario perfil) => [
        if (perfil == PerfilUsuario.cliente) ...[
          const SizedBox(height: Espaco.e24),
          _aviso(Icons.key_outlined,
              'Depois, use o código que o responsável pela obra te passar.'),
        ],
      ];

  Widget _aviso(IconData icone, String texto) {
    final c = context.cores;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 22, color: c.grafite2),
        const SizedBox(width: Espaco.e12),
        Expanded(
          child:
              Text(texto, style: Tipografia.apoio.copyWith(color: c.grafite2)),
        ),
      ],
    );
  }

  List<Widget> _emailESenha(PerfilUsuario perfil) => [
        const SizedBox(height: Espaco.e16),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'E-mail'),
          validator: Validators.email,
        ),
        const SizedBox(height: Espaco.e16),
        TextFormField(
          controller: _senhaCtrl,
          obscureText: !_senhaVisivel,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: (_) => _carregando ? null : _cadastrar(),
          decoration: InputDecoration(
            labelText: 'Senha',
            helperText: 'Mínimo de 6 caracteres',
            suffixIcon: IconButton(
              tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
              icon: Icon(_senhaVisivel
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
            ),
          ),
          validator: Validators.senha,
        ),
        const SizedBox(height: Espaco.e24),
        _aviso(
          Icons.mark_email_read_outlined,
          perfil == PerfilUsuario.cliente
              ? 'Vamos enviar um link para confirmar seu e-mail. '
                  'Depois, use o código que o responsável pela '
                  'obra te passar.'
              : 'Vamos enviar um link para confirmar seu e-mail. '
                  'Você já pode usar o app enquanto isso.',
        ),
      ];
}
