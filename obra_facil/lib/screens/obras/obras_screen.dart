import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notificacoes/tarefa_segundo_plano.dart';
import '../../utils/formatters.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/carregando_obra.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/ilustracoes.dart';

class ObrasScreen extends StatefulWidget {
  const ObrasScreen({super.key});

  @override
  State<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends State<ObrasScreen> {
  @override
  void initState() {
    super.initState();
    // permissão + lembretes agendados + verificador em segundo plano
    NotificacaoBootstrap.aplicar();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final db = context.read<FirestoreService>();
    final usuario = auth.usuario;
    if (usuario == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Olá, ${usuario.nome.split(' ').first}'),
            Text(
              usuario.perfil.label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notificações',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notificacoes'),
          ),
          if (usuario.ehDono)
            IconButton(
              tooltip: 'Fornecedores',
              icon: const Icon(Icons.storefront),
              onPressed: () => context.push('/fornecedores'),
            ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmarSaida(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Dono e mestre não ficam presos por causa do e-mail — só são
          // lembrados. Quem é barrado sem confirmar é o cliente, que é
          // gente de fora e entra por cadastro aberto.
          if (!auth.emailVerificado) const _AvisoEmailPendente(),
          Expanded(
            child: StreamBuilder<List<ObraModel>>(
              stream: db.obrasDoUsuario(usuario.id),
              // O conteúdo entra com fade em vez de substituir o
              // "carregando" no mesmo quadro — é o pisca que parecia
              // tela pulando.
              builder: (context, snapshot) =>
                  TrocaSuave(child: _conteudo(context, snapshot, usuario)),
            ),
          ),
        ],
      ),
      floatingActionButton: usuario.ehDono
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/obras/nova'),
              icon: const Icon(Icons.add),
              label: const Text('Nova obra'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _entrarComCodigo(context),
              icon: const Icon(Icons.qr_code),
              label: const Text('Entrar com código'),
            ),
    );
  }

  Widget _conteudo(BuildContext context,
      AsyncSnapshot<List<ObraModel>> snapshot, UsuarioModel usuario) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CarregandoObra(mensagem: 'Buscando suas obras…');
    }
    if (snapshot.hasError) {
      return EstadoVazio(
        icone: Icons.error_outline,
        titulo: 'Erro ao carregar obras',
        mensagem: '${snapshot.error}',
      );
    }
    final obras = snapshot.data ?? const <ObraModel>[];
    if (obras.isEmpty) {
      return usuario.ehDono
          ? EstadoVazio(
              icone: Icons.apartment,
              ilustracao: const IlustracaoTrabalhador(),
              titulo: 'Nenhuma obra ainda',
              mensagem:
                  'Cadastre sua primeira obra para começar a controlar '
                  'custos, equipe e progresso.',
              rotuloAcao: 'Criar obra',
              onAcao: () => context.push('/obras/nova'),
            )
          : EstadoVazio(
              icone: Icons.qr_code,
              ilustracao: const IlustracaoTrabalhador(),
              titulo: 'Você ainda não está em nenhuma obra',
              mensagem: 'Peça ao dono da obra o código de convite e entre '
                  'para começar a registrar os lançamentos.',
              rotuloAcao: 'Entrar com código',
              onAcao: () => _entrarComCodigo(context),
            );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
      itemCount: obras.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _CartaoObra(obra: obras[i]).aparecer(i),
    );
  }

  Future<void> _confirmarSaida(BuildContext context) async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (sair == true && context.mounted) {
      await context.read<AuthProvider>().sair();
    }
  }

  Future<void> _entrarComCodigo(BuildContext context) async {
    final ctrl = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar numa obra'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Código de convite',
            hintText: 'Ex.: A3B7XZ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    if (codigo == null || codigo.trim().isEmpty || !context.mounted) return;

    final db = context.read<FirestoreService>();
    final uid = context.read<AuthProvider>().usuario!.id;
    final obra = await db.entrarNaObraPorCodigo(codigo, uid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(obra == null
          ? 'Código não encontrado. Confira com o dono da obra.'
          : 'Você entrou na obra "${obra.nome}"!'),
    ));
  }
}

/// Lembrete de confirmação de e-mail para quem já trabalha na obra.
class _AvisoEmailPendente extends StatefulWidget {
  const _AvisoEmailPendente();

  @override
  State<_AvisoEmailPendente> createState() => _AvisoEmailPendenteState();
}

class _AvisoEmailPendenteState extends State<_AvisoEmailPendente> {
  bool _enviando = false;

  Future<void> _reenviar() async {
    setState(() => _enviando = true);
    final auth = context.read<AuthProvider>();
    final erro = await auth.reenviarVerificacao();
    // Se o link já tiver sido clicado, a faixa some sozinha.
    await auth.atualizarVerificacao();
    if (!mounted) return;
    setState(() => _enviando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(erro ?? 'E-mail de confirmação enviado. Olhe no spam '
          'também.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amareloCapacete.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.amareloCapacete.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread,
              size: 18, color: AppColors.amareloCapacete),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Confirme seu e-mail para garantir a recuperação da conta.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: _enviando ? null : _reenviar,
            child: Text(_enviando ? 'Enviando…' : 'Reenviar'),
          ),
        ],
      ),
    );
  }
}

class _CartaoObra extends StatelessWidget {
  final ObraModel obra;

  const _CartaoObra({required this.obra});

  @override
  Widget build(BuildContext context) {
    final corStatus = switch (obra.status) {
      StatusObra.emAndamento => AppColors.sucesso,
      StatusObra.pausada => AppColors.alerta,
      StatusObra.concluida => AppColors.info,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/obras/${obra.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: corStatus, width: 5),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      obra.nome,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: corStatus.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      obra.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: corStatus,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.place,
                      size: 14, color: AppColors.textoSecundario),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      obra.endereco,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textoSecundario),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: AppColors.textoSecundario),
                  const SizedBox(width: 4),
                  Text(
                    '${Formatters.data(obra.dataInicio)} → '
                    '${Formatters.data(obra.previsaoTermino)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textoSecundario),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.moedaCompacta(obra.orcamento),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.laranja,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
