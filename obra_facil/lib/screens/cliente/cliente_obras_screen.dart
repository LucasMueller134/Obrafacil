import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/carregando_obra.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/ilustracoes.dart';

/// Porta de entrada de quem contratou a obra: lista as obras que ele
/// acompanha. Nenhum dado financeiro passa por aqui.
class ClienteObrasScreen extends StatelessWidget {
  const ClienteObrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final usuario = context.watch<AuthProvider>().usuario;
    if (usuario == null) {
      return const Scaffold(body: CarregandoObra(mensagem: 'Carregando…'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas obras'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmarSaida(context),
          ),
        ],
      ),
      body: StreamBuilder<List<ObraModel>>(
        stream: db.obrasDoCliente(usuario.id),
        builder: (context, snapshot) =>
            TrocaSuave(child: _conteudo(context, snapshot)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _entrarComCodigo(context),
        icon: const Icon(Icons.qr_code),
        label: const Text('Entrar com código'),
      ),
    );
  }

  Widget _conteudo(
      BuildContext context, AsyncSnapshot<List<ObraModel>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const CarregandoObra(mensagem: 'Buscando suas obras…');
    }
    final obras = snapshot.data ?? const <ObraModel>[];
    if (obras.isEmpty) {
      return EstadoVazio(
        icone: Icons.holiday_village,
        ilustracao: const IlustracaoTrabalhador(),
        titulo: 'Nenhuma obra por aqui ainda',
        mensagem: 'Peça ao responsável pela obra o código de '
            'acompanhamento e entre para ver o andamento.',
        rotuloAcao: 'Entrar com código',
        onAcao: () => _entrarComCodigo(context),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
      itemCount: obras.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _CartaoObraCliente(obra: obras[i]).aparecer(i),
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
        title: const Text('Acompanhar uma obra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digite o código de acompanhamento que o responsável pela '
              'obra passou para você.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Código',
                hintText: 'Ex.: A3B7XZ',
              ),
            ),
          ],
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
    final messenger = ScaffoldMessenger.of(context);
    final obra = await db.entrarComoClientePorCodigo(codigo, uid);
    messenger.showSnackBar(SnackBar(
      content: Text(obra == null
          ? 'Código não encontrado. Confira com o responsável pela obra.'
          : 'Pronto! Agora você acompanha a ${obra.nome}.'),
    ));
  }
}

class _CartaoObraCliente extends StatelessWidget {
  final ObraModel obra;

  const _CartaoObraCliente({required this.obra});

  @override
  Widget build(BuildContext context) {
    final pctPrazo = obra.duracaoDias <= 0
        ? 0
        : (obra.diasDecorridos / obra.duracaoDias * 100).round().clamp(0, 100);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/cliente/${obra.id}'),
        child: Padding(
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
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.laranja.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      obra.status.label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.laranja,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                obra.endereco,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textoSecundario),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pctPrazo / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.superficieAlta,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event,
                      size: 14, color: AppColors.textoSecundario),
                  const SizedBox(width: 4),
                  Text(
                    'Entrega prevista: '
                    '${Formatters.data(obra.previsaoTermino)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textoSecundario),
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
