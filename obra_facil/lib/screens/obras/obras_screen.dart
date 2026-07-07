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

class ObrasScreen extends StatelessWidget {
  const ObrasScreen({super.key});

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
      body: StreamBuilder<List<ObraModel>>(
        stream: db.obrasDoUsuario(usuario.id),
        builder: (context, snapshot) {
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
          final obras = snapshot.data ?? const [];
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
                    mensagem:
                        'Peça ao dono da obra o código de convite e entre '
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
        },
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/obras/${obra.id}'),
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
