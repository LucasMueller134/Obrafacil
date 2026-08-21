import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Confirmação do e-mail para quem entra de fora da equipe.
///
/// O cliente não passa daqui sem clicar no link: é o que garante que o
/// e-mail do cadastro existe de verdade e é dele. A tela fica conferindo
/// sozinha, porque a confirmação acontece no navegador, fora do app.
class VerificarEmailScreen extends StatefulWidget {
  const VerificarEmailScreen({super.key});

  @override
  State<VerificarEmailScreen> createState() => _VerificarEmailScreenState();
}

class _VerificarEmailScreenState extends State<VerificarEmailScreen> {
  Timer? _conferindo;
  bool _reenviando = false;
  int _segundosParaReenviar = 0;

  @override
  void initState() {
    super.initState();
    // A confirmação chega de fora; sem esta ronda o usuário clicaria no
    // link e ficaria olhando para uma tela parada.
    _conferindo = Timer.periodic(
      const Duration(seconds: 6),
      (_) => context.read<AuthProvider>().atualizarVerificacao(),
    );
  }

  @override
  void dispose() {
    _conferindo?.cancel();
    super.dispose();
  }

  Future<void> _reenviar() async {
    setState(() => _reenviando = true);
    final erro = await context.read<AuthProvider>().reenviarVerificacao();
    if (!mounted) return;
    setState(() {
      _reenviando = false;
      _segundosParaReenviar = erro == null ? 60 : 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(erro ?? 'E-mail reenviado. Confira também o spam.'),
    ));
    if (erro == null) _contarRegressiva();
  }

  void _contarRegressiva() {
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _segundosParaReenviar <= 0) {
        t.cancel();
        return;
      }
      setState(() => _segundosParaReenviar--);
    });
  }

  Future<void> _conferirAgora() async {
    final verificado = await context.read<AuthProvider>().atualizarVerificacao();
    if (!mounted || verificado) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Ainda não recebi a confirmação. Abra o link do '
          'e-mail e tente de novo.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.emailPendente ?? auth.usuario?.email ?? 'seu e-mail';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.laranja.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_unread,
                      size: 42, color: AppColors.laranja),
                ),
                const SizedBox(height: 22),
                Text(
                  'Confirme seu e-mail',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enviamos um link de confirmação para:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.amareloCapacete,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Abra o e-mail e toque no link. Assim que confirmar, esta '
                  'tela avança sozinha. Se não achar, olhe no spam.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  onPressed: _conferirAgora,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Já confirmei'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _reenviando || _segundosParaReenviar > 0
                      ? null
                      : _reenviar,
                  icon: _reenviando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(_segundosParaReenviar > 0
                      ? 'Reenviar em ${_segundosParaReenviar}s'
                      : 'Reenviar e-mail'),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => context.read<AuthProvider>().sair(),
                  child: const Text('Usar outra conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
