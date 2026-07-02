// lib/screens/relatorios/relatorio_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/lancamento_model.dart';
import '../../providers/app_provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';

class RelatorioScreen extends StatelessWidget {
  final String obraId;
  final String nomeObra;
  const RelatorioScreen({super.key, required this.obraId, required this.nomeObra});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: StreamBuilder<List<LancamentoModel>>(
        stream: provider.firebaseService.streamLancamentos(obraId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final lancamentos = snapshot.data ?? [];
          if (lancamentos.isEmpty) {
            return const Center(child: Text('Nenhum lançamento para gerar relatório'));
          }
          return _RelatorioContent(lancamentos: lancamentos, nomeObra: nomeObra);
        },
      ),
    );
  }
}

class _RelatorioContent extends StatelessWidget {
  final List<LancamentoModel> lancamentos;
  final String nomeObra;

  const _RelatorioContent({required this.lancamentos, required this.nomeObra});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final totalGeral = lancamentos.fold<double>(0, (a, b) => a + b.valorTotal);

    // Agrupamento por categoria
    final Map<String, double> porCategoria = {};
    for (final l in lancamentos) {
      porCategoria[l.categoria] = (porCategoria[l.categoria] ?? 0) + l.valorTotal;
    }

    // Agrupamento por fase
    final Map<String, double> porFase = {};
    for (final l in lancamentos) {
      porFase[l.fase] = (porFase[l.fase] ?? 0) + l.valorTotal;
    }

    // Por semana (últimas 8 semanas)
    final Map<String, double> porSemana = {};
    final agora = DateTime.now();
    for (int i = 7; i >= 0; i--) {
      final semana = agora.subtract(Duration(days: i * 7));
      final chave = 'S${8 - i}';
      porSemana[chave] = 0;
    }
    for (final l in lancamentos) {
      final diff = agora.difference(l.data).inDays;
      if (diff < 56) {
        final idx = 7 - (diff ~/ 7);
        if (idx >= 0 && idx <= 7) {
          final chave = 'S${idx + 1}';
          porSemana[chave] = (porSemana[chave] ?? 0) + l.valorTotal;
        }
      }
    }

    final cores = [
      AppTheme.primary, AppTheme.secondary, AppTheme.accent,
      AppTheme.success, AppTheme.warning, AppTheme.error,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total geral
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total gasto na obra',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                fmt.format(totalGeral),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('${lancamentos.length} lançamentos no total',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Gráfico de barras por semana
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gastos por semana',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barGroups: porSemana.entries.toList().asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.value,
                              color: AppTheme.primary,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Text(
                              porSemana.keys.toList()[v.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Por categoria
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Por categoria', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...porCategoria.entries.toList().asMap().entries.map((e) {
                  final cor = cores[e.key % cores.length];
                  final pct = (e.value.value / totalGeral) * 100;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.value.key, style: const TextStyle(fontSize: 13)),
                            Text(fmt.format(e.value.value),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            backgroundColor: AppTheme.border,
                            valueColor: AlwaysStoppedAnimation(cor),
                            minHeight: 8,
                          ),
                        ),
                        Text('${pct.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Por fase
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Por fase da obra', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                ...porFase.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                      Text(fmt.format(e.value),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
