import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/lancamento_model.dart';
import '../utils/formatters.dart';

/// Rosca de gastos por categoria (somente lançamentos aprovados).
class GraficoCategorias extends StatelessWidget {
  final List<LancamentoModel> lancamentos;

  const GraficoCategorias({super.key, required this.lancamentos});

  @override
  Widget build(BuildContext context) {
    final porCategoria = <CategoriaCusto, double>{};
    for (final l in lancamentos) {
      if (l.status != StatusLancamento.aprovado) continue;
      porCategoria[l.categoria] = (porCategoria[l.categoria] ?? 0) + l.valor;
    }
    final total = porCategoria.values.fold<double>(0, (s, v) => s + v);

    if (total <= 0) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Sem gastos aprovados ainda',
            style: TextStyle(color: AppColors.textoSecundario),
          ),
        ),
      );
    }

    final entradas = porCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 38,
              startDegreeOffset: -90,
              sections: [
                for (final e in entradas)
                  PieChartSectionData(
                    value: e.value,
                    color: e.key.cor,
                    radius: 20,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in entradas) ...[
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: e.key.cor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key.label,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(e.value / total * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18, bottom: 8),
                  child: Text(
                    Formatters.moeda(e.value),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textoSecundario),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
