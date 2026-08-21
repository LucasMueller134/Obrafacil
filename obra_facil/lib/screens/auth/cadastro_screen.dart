import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

/// Cadastro em duas etapas: primeiro quem você é, depois seus dados.
///
/// Os três perfis lado a lado não cabiam na largura de um celular — o
/// texto estourava por cima do formulário. Separado assim cada perfil
/// ganha uma linha inteira e o formulário aparece sem disputa de espaço.
class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  PerfilUsuario? _perfil;
  bool _carregando = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    final erro = await context.read<AuthProvider>().cadastrar(
          nome: _nomeCtrl.text,
          email: _emailCtrl.text,
          senha: _senhaCtrl.text,
          perfil: _perfil!,
        );
    if (!mounted) return;
    setState(() => _carregando = false);
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
    // Deu certo: o router leva para a área do perfil escolhido.
  }

  void _voltar() {
    if (_perfil != null) {
      setState(() => _perfil = null);
      return;
    }
    context.canPop() ? context.pop() : context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_perfil == null ? 'Criar conta' : 'Seus dados'),
        leading: BackButton(onPressed: _voltar),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
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
    );
  }

  // ------------------------------------------------------- Etapa 1

  Widget _escolhaDePerfil() {
    return SingleChildScrollView(
      key: const ValueKey('perfil'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Como você vai usar o ObraFácil?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Escolha o seu perfil. Isso define o que você vê no app.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textoSecundario),
          ),
          const SizedBox(height: 20),
          for (final (perfil, icone) in const [
            (PerfilUsuario.dono, Icons.business_center),
            (PerfilUsuario.mestre, Icons.engineering),
            (PerfilUsuario.cliente, Icons.holiday_village),
          ]) ...[
            _CartaoPerfil(
              perfil: perfil,
              icone: icone,
              onTap: () => setState(() => _perfil = perfil),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/login'),
              child: const Text('Já tenho conta'),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- Etapa 2

  Widget _formulario() {
    final perfil = _perfil!;
    return SingleChildScrollView(
      key: const ValueKey('formulario'),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lembra a escolha da etapa anterior e deixa trocar.
            InkWell(
              onTap: () => setState(() => _perfil = null),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.laranja.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.laranja.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined,
                        size: 18, color: AppColors.laranja),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Entrando como ${perfil.label}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text('Trocar',
                        style: TextStyle(
                            color: AppColors.laranja,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => Validators.obrigatorio(v, 'O nome'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _senhaCtrl,
              obscureText: !_senhaVisivel,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _carregando ? null : _cadastrar(),
              decoration: InputDecoration(
                labelText: 'Senha',
                helperText: 'Mínimo de 6 caracteres',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                  icon: Icon(_senhaVisivel
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _senhaVisivel = !_senhaVisivel),
                ),
              ),
              validator: Validators.senha,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amareloCapacete.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.amareloCapacete.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read,
                      size: 18, color: AppColors.amareloCapacete),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      perfil == PerfilUsuario.cliente
                          ? 'Vamos enviar um link para confirmar seu e-mail. '
                              'Depois, use o código que o responsável pela '
                              'obra te passar.'
                          : 'Vamos enviar um link para confirmar seu e-mail. '
                              'Você já pode usar o app enquanto isso.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _carregando ? null : _cadastrar,
              child: _carregando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Perfil ocupando a linha inteira: ícone, nome e o que ele faz.
class _CartaoPerfil extends StatelessWidget {
  final PerfilUsuario perfil;
  final IconData icone;
  final VoidCallback onTap;

  const _CartaoPerfil({
    required this.perfil,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borda),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.laranja.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icone, size: 24, color: AppColors.laranja),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    perfil.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    perfil.descricao,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textoSecundario),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textoDesabilitado),
          ],
        ),
      ),
    );
  }
}
