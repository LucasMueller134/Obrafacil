import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/lancamento_model.dart';
import '../utils/formatters.dart';

/// Barras de gasto aprovado por semana (últimas 6 semanas).
class GraficoSemanal extends StatelessWidget {
  final List<LancamentoModel> lancamentos;

  const GraficoSemanal({super.key, required this.lancamentos});

  @override
  Widget build(BuildContext context) {
    const numSemanas = 6;
    final agora = DateTime.now();
    final inicioSemanaAtual = DateTime(agora.year, agora.month, agora.day)
        .subtract(Duration(days: agora.weekday - 1));

    final inicios = List.generate(
      numSemanas,
      (i) => inicioSemanaAtual.subtract(Duration(days: 7 * (numSemanas - 1 - i))),
    );

    final valores = List<double>.filled(numSemanas, 0);
    for (final l in lancamentos) {
      if (l.status != StatusLancamento.aprovado) continue;
      for (var i = 0; i < numSemanas; i++) {
        final fim = inicios[i].add(const Duration(days: 7));
        if (!l.data.isBefore(inicios[i]) && l.data.isBefore(fim)) {
          valores[i] += l.valor;
          break;
        }
      }
    }

    final maior = valores.fold<double>(0, (m, v) => v > m ? v : m);
    if (maior <= 0) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Sem gastos nas últimas semanas',
            style: TextStyle(color: AppColors.textoSecundario),
          ),
        ),
      );
    }

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maior * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                Formatters.moedaCompacta(rod.toY),
                const TextStyle(
                  color: AppColors.textoPrimario,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (valor, meta) {
                  final i = valor.toInt();
                  if (i < 0 || i >= numSemanas) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      Formatters.dataCurta(inicios[i]),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textoSecundario,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < numSemanas; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: valores[i],
                    width: 20,
                    color: i == numSemanas - 1
                        ? AppColors.laranja
                        : AppColors.laranja.withValues(alpha: 0.45),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
