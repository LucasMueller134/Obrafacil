// lib/screens/obras/obras_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../models/obra_model.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';
import '../auth/login_screen.dart';
import 'nova_obra_screen.dart';
import 'obra_detalhe_screen.dart';
import '../fornecedores/fornecedores_screen.dart';

class ObrasScreen extends StatelessWidget {
  const ObrasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuario;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ObraFácil'),
            if (usuario != null)
              Text(
                'Olá, ${usuario.nome.split(' ').first}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Fornecedores',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FornecedoresScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await provider.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ObraModel>>(
        stream: provider.streamObras(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          }
          final obras = snapshot.data ?? [];
          if (obras.isEmpty) {
            return _EmptyObras(onAdicionar: () => _abrirNovaObra(context));
          }
          return _ListaObras(obras: obras);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirNovaObra(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova Obra'),
      ),
    );
  }

  void _abrirNovaObra(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NovaObraScreen()),
    );
  }
}

class _ListaObras extends StatelessWidget {
  final List<ObraModel> obras;
  const _ListaObras({required this.obras});

  @override
  Widget build(BuildContext context) {
    final emAndamento = obras.where((o) => o.status == AppConstants.statusEmAndamento).toList();
    final pausadas = obras.where((o) => o.status == AppConstants.statusPausada).toList();
    final concluidas = obras.where((o) => o.status == AppConstants.statusConcluida).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPIs
        _KpiStrip(obras: obras),
        const SizedBox(height: 20),
        if (emAndamento.isNotEmpty) ...[
          _SectionHeader(titulo: 'Em Andamento', count: emAndamento.length),
          ...emAndamento.map((o) => _ObraCard(obra: o)),
          const SizedBox(height: 16),
        ],
        if (pausadas.isNotEmpty) ...[
          _SectionHeader(titulo: 'Pausadas', count: pausadas.length),
          ...pausadas.map((o) => _ObraCard(obra: o)),
          const SizedBox(height: 16),
        ],
        if (concluidas.isNotEmpty) ...[
          _SectionHeader(titulo: 'Concluídas', count: concluidas.length),
          ...concluidas.map((o) => _ObraCard(obra: o)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final List<ObraModel> obras;
  const _KpiStrip({required this.obras});

  @override
  Widget build(BuildContext context) {
    final totalGasto = obras.fold<double>(0, (a, b) => a + b.custoAtual);
    final emAndamento = obras.where((o) => o.status == AppConstants.statusEmAndamento).length;
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            titulo: 'Obras Ativas',
            valor: '$emAndamento',
            icone: Icons.construction,
            cor: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            titulo: 'Gasto Total',
            valor: fmt.format(totalGasto),
            icone: Icons.attach_money,
            cor: AppTheme.secondary,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;

  const _KpiCard({
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icone, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String titulo;
  final int count;
  const _SectionHeader({required this.titulo, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObraCard extends StatelessWidget {
  final ObraModel obra;
  const _ObraCard({required this.obra});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.read<AppProvider>().selecionarObra(obra);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ObraDetalheScreen(obra: obra)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.home_work_outlined, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obra.nome,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          obra.endereco,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: obra.status),
                ],
              ),
              const SizedBox(height: 16),
              // Fase atual
              Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    obra.faseAtual,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barra de progresso orçamento
              if (obra.orcamentoTotal > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Orçamento usado',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${obra.percentualGasto.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: obra.estourandoOrcamento
                            ? AppTheme.warning
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (obra.percentualGasto / 100).clamp(0.0, 1.0),
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation(
                      obra.estourandoOrcamento ? AppTheme.warning : AppTheme.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gasto atual',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        fmt.format(obra.custoAtual),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  if (obra.orcamentoTotal > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Orçamento',
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          fmt.format(obra.orcamentoTotal),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                ],
              ),
              if (obra.estourandoOrcamento) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber, size: 14, color: AppTheme.warning),
                      const SizedBox(width: 4),
                      Text(
                        'Orçamento atingiu ${obra.percentualGasto.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color cor;
    switch (status) {
      case AppConstants.statusEmAndamento:
        cor = AppTheme.success;
        break;
      case AppConstants.statusPausada:
        cor = AppTheme.warning;
        break;
      default:
        cor = AppTheme.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyObras extends StatelessWidget {
  final VoidCallback onAdicionar;
  const _EmptyObras({required this.onAdicionar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: AppTheme.border),
            const SizedBox(height: 24),
            Text(
              'Nenhuma obra cadastrada',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione sua primeira obra para começar a gerenciar seus custos',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAdicionar,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Obra'),
            ),
          ],
        ),
      ),
    );
  }
}
