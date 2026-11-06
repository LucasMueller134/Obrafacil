import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../providers/auth_provider.dart';

/// Confirmação do e-mail para quem entra de fora da equipe.
///
/// O cliente não passa daqui sem clicar no link: é o que garante que o
/// e-mail do cadastro existe de verdade e é dele. A tela fica conferindo
/// sozinha, porque a confirmação acontece no navegador, fora do app.
class VerificarEmailScreen extends StatelessWidget {
  const VerificarEmailScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const TemaPrancheta(child: _VerificarEmail());
}

class _VerificarEmail extends StatefulWidget {
  const _VerificarEmail();

  @override
  State<_VerificarEmail> createState() => _VerificarEmailScreenState();
}

class _VerificarEmailScreenState extends State<_VerificarEmail> {
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
    unawaited(erro == null ? Tato.confirmar() : Tato.erro());
    mostrarAviso(context, erro ?? 'E-mail reenviado. Confira também o spam.');
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
    final verificado =
        await context.read<AuthProvider>().atualizarVerificacao();
    if (!mounted || verificado) return;
    unawaited(Tato.erro());
    mostrarAviso(
        context,
        'Ainda não recebi a confirmação. Abra o link do e-mail e tente de '
        'novo.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final auth = context.watch<AuthProvider>();
    final email = auth.emailPendente ?? auth.usuario?.email ?? 'seu e-mail';
    final esperando = _segundosParaReenviar > 0;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              Espaco.margem, Espaco.e48, Espaco.margem, Espaco.e32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.mark_email_unread_outlined,
                  size: 48, color: c.grafite),
            ),
            const SizedBox(height: Espaco.e16),
            const Rotulo('Último passo'),
            const SizedBox(height: Espaco.e4),
            Semantics(
              header: true,
              child: Text('Confirme seu e-mail',
                  style: Tipografia.tituloTela.copyWith(color: c.grafite)),
            ),
            const SizedBox(height: Espaco.e16),
            Carimbo(linhas: [
              [
                CelulaCarimbo(
                  rotulo: 'Enviamos o link para',
                  conteudo: Text(
                    email,
                    style: Tipografia.corpoForte.copyWith(color: c.grafite),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: Espaco.e16),
            Text(
              'Abra o e-mail e toque no link. Assim que confirmar, esta tela '
              'avança sozinha. Se não achar, olhe no spam.',
              style: Tipografia.corpo.copyWith(color: c.grafite2),
            ),
            const SizedBox(height: Espaco.e32),
            BotaoPrincipal(
              rotulo: 'Já confirmei',
              icone: Icons.refresh,
              grande: true,
              expandir: true,
              aoTocar: () => unawaited(_conferirAgora()),
            ),
            const SizedBox(height: Espaco.entreAlvos),
            BotaoContorno(
              rotulo: esperando
                  ? 'Reenviar em ${_segundosParaReenviar}s'
                  : 'Reenviar e-mail',
              icone: Icons.send_outlined,
              expandir: true,
              carregando: _reenviando,
              aoTocar: _reenviando || esperando
                  ? null
                  : () => unawaited(_reenviar()),
            ),
            const SizedBox(height: Espaco.e24),
            const LinhaCota(legenda: 'E-mail errado?'),
            const SizedBox(height: Espaco.e8),
            Center(
              child: TextButton(
                onPressed: () => context.read<AuthProvider>().sair(),
                child: const Text('Usar outra conta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
