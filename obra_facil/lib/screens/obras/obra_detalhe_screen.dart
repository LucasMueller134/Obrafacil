// lib/screens/obras/obra_detalhe_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/obra_model.dart';
import '../../models/lancamento_model.dart';
import '../../models/models.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../lancamentos/lancamentos_screen.dart';
import '../lancamentos/novo_lancamento_screen.dart';
import '../relatorios/relatorio_screen.dart';
import '../estoque/estoque_screen.dart';
import '../diario/diario_screen.dart';
import '../cronograma/cronograma_screen.dart';
import '../galeria/galeria_screen.dart';
import 'nova_obra_screen.dart';

class ObraDetalheScreen extends StatefulWidget {
  final ObraModel obra;
  const ObraDetalheScreen({super.key, required this.obra});

  @override
  State<ObraDetalheScreen> createState() => _ObraDetalheScreenState();
}

class _ObraDetalheScreenState extends State<ObraDetalheScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.obra.nome,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NovaObraScreen(obraParaEditar: widget.obra),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Resumo'),
            Tab(text: 'Lançamentos'),
            Tab(text: 'Estoque'),
            Tab(text: 'Diário'),
            Tab(text: 'Cronograma'),
            Tab(text: 'Fotos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ResumoTab(obra: widget.obra),
          LancamentosScreen(obraId: widget.obra.id),
          EstoqueScreen(obraId: widget.obra.id),
          DiarioScreen(obraId: widget.obra.id),
          CronogramaScreen(obraId: widget.obra.id),
          GaleriaScreen(obraId: widget.obra.id),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NovoLancamentoScreen(obraId: widget.obra.id),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Lançamento'),
      ),
    );
  }
}

class _ResumoTab extends StatelessWidget {
  final ObraModel obra;
  const _ResumoTab({required this.obra});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cards de valor
        Row(
          children: [
            Expanded(
              child: _ValorCard(
                titulo: 'Gasto Total',
                valor: fmt.format(obra.custoAtual),
                cor: AppTheme.primary,
                icone: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ValorCard(
                titulo: 'Saldo',
                valor: fmt.format(obra.saldoRestante),
                cor: obra.saldoRestante >= 0 ? AppTheme.success : AppTheme.error,
                icone: Icons.account_balance_wallet_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Gráfico por categoria
        StreamBuilder<List<LancamentoModel>>(
          stream: provider.firebaseService.streamLancamentos(obra.id),
          builder: (context, snapshot) {
            final lancamentos = snapshot.data ?? [];
            if (lancamentos.isEmpty) {
              return _SemDados();
            }
            return _GraficoCategoria(lancamentos: lancamentos);
          },
        ),
        const SizedBox(height: 16),
        // Relatório semanal
        _RelatorioSemanalCard(obraId: obra.id, nomeObra: obra.nome, fase: obra.faseAtual),
        const SizedBox(height: 16),
        // Info da obra
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informações', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _InfoRow(icone: Icons.location_on_outlined, texto: obra.endereco),
                _InfoRow(icone: Icons.layers_outlined, texto: 'Fase: ${obra.faseAtual}'),
                _InfoRow(
                  icone: Icons.calendar_today_outlined,
                  texto:
                      'Início: ${obra.dataInicio.day.toString().padLeft(2, '0')}/${obra.dataInicio.month.toString().padLeft(2, '0')}/${obra.dataInicio.year}',
                ),
                if (obra.dataPrevisaoFim != null)
                  _InfoRow(
                    icone: Icons.event_outlined,
                    texto:
                        'Previsão: ${obra.dataPrevisaoFim!.day.toString().padLeft(2, '0')}/${obra.dataPrevisaoFim!.month.toString().padLeft(2, '0')}/${obra.dataPrevisaoFim!.year}',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _ValorCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final IconData icone;

  const _ValorCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor, size: 24),
          const SizedBox(height: 8),
          Text(titulo,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _GraficoCategoria extends StatelessWidget {
  final List<LancamentoModel> lancamentos;
  const _GraficoCategoria({required this.lancamentos});

  @override
  Widget build(BuildContext context) {
    final Map<String, double> porCategoria = {};
    for (final l in lancamentos) {
      porCategoria[l.categoria] = (porCategoria[l.categoria] ?? 0) + l.valorTotal;
    }

    final cores = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.error,
    ];

    final entries = porCategoria.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastos por categoria',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: entries.asMap().entries.map((e) {
                    final cor = cores[e.key % cores.length];
                    final total = porCategoria.values
                        .fold<double>(0, (a, b) => a + b);
                    final pct = (e.value.value / total) * 100;
                    return PieChartSectionData(
                      value: e.value.value,
                      title: '${pct.toStringAsFixed(0)}%',
                      color: cor,
                      radius: 70,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: entries.asMap().entries.map((e) {
                final cor = cores[e.key % cores.length];
                final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: cor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${e.value.key}: ${fmt.format(e.value.value)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatorioSemanalCard extends StatefulWidget {
  final String obraId;
  final String nomeObra;
  final String fase;
  const _RelatorioSemanalCard({
    required this.obraId,
    required this.nomeObra,
    required this.fase,
  });

  @override
  State<_RelatorioSemanalCard> createState() => _RelatorioSemanalCardState();
}

class _RelatorioSemanalCardState extends State<_RelatorioSemanalCard> {
  String? _relatorio;
  bool _carregando = false;

  Future<void> _gerarRelatorio() async {
    setState(() => _carregando = true);
    try {
      final provider = context.read<AppProvider>();
      final lancamentos = await provider.firebaseService
          .getLancamentosSemana(widget.obraId);
      final total = lancamentos.fold<double>(0, (a, b) => a + b.valorTotal);
      final relatorio = await provider.iaService.gerarRelatorioSemanal(
        nomeObra: widget.nomeObra,
        lancamentos: lancamentos.map((l) => l.toMap()).toList(),
        totalSemana: total,
        faseAtual: widget.fase,
      );
      setState(() => _relatorio = relatorio);
    } catch (e) {
      setState(() => _relatorio = 'Erro ao gerar relatório.');
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Relatório Semanal',
                    style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: _carregando ? null : _gerarRelatorio,
                  icon: _carregando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(_relatorio == null ? 'Gerar' : 'Atualizar'),
                ),
              ],
            ),
            if (_relatorio != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _relatorio!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Toque em "Gerar" para criar um resumo da semana com IA',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icone;
  final String texto;
  const _InfoRow({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icone, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _SemDados extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.bar_chart, size: 48, color: AppTheme.border),
              const SizedBox(height: 12),
              Text(
                'Nenhum lançamento ainda',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
