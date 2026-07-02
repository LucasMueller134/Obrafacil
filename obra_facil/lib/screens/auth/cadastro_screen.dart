import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

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
  PerfilUsuario _perfil = PerfilUsuario.dono;
  bool _carregando = false;

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
          perfil: _perfil,
        );
    if (!mounted) return;
    setState(() => _carregando = false);
    if (erro != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta'),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Como você vai usar o ObraFácil?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CartaoPerfil(
                        perfil: PerfilUsuario.dono,
                        icone: Icons.business_center,
                        descricao: 'Cria obras, aprova gastos e acompanha tudo',
                        selecionado: _perfil == PerfilUsuario.dono,
                        onTap: () =>
                            setState(() => _perfil = PerfilUsuario.dono),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CartaoPerfil(
                        perfil: PerfilUsuario.mestre,
                        icone: Icons.engineering,
                        descricao: 'Registra gastos, materiais e o dia a dia',
                        selecionado: _perfil == PerfilUsuario.mestre,
                        onTap: () =>
                            setState(() => _perfil = PerfilUsuario.mestre),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nomeCtrl,
                  textCapitalization: TextCapitalization.words,
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
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha (mínimo 6 caracteres)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: Validators.senha,
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
        ),
      ),
    );
  }
}

class _CartaoPerfil extends StatelessWidget {
  final PerfilUsuario perfil;
  final IconData icone;
  final String descricao;
  final bool selecionado;
  final VoidCallback onTap;

  const _CartaoPerfil({
    required this.perfil,
    required this.icone,
    required this.descricao,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selecionado
              ? AppColors.laranja.withValues(alpha: 0.14)
              : AppColors.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado ? AppColors.laranja : AppColors.borda,
            width: selecionado ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icone,
                size: 30,
                color: selecionado
                    ? AppColors.laranja
                    : AppColors.textoSecundario),
            const SizedBox(height: 10),
            Text(
              perfil.label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}
