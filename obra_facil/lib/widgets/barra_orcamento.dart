import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/formatters.dart';

/// Barra de progresso do orçamento com cor semântica
/// (verde → amarelo a partir de 75% → vermelho a partir de 95%).
class BarraOrcamento extends StatelessWidget {
  final double gasto;
  final double orcamento;

  const BarraOrcamento({
    super.key,
    required this.gasto,
    required this.orcamento,
  });

  @override
  Widget build(BuildContext context) {
    final fracao = orcamento <= 0 ? 0.0 : (gasto / orcamento).clamp(0.0, 1.0);
    final estourou = orcamento > 0 && gasto > orcamento;
    final cor = estourou || fracao >= 0.95
        ? AppColors.erro
        : fracao >= 0.75
            ? AppColors.alerta
            : AppColors.sucesso;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              Formatters.moeda(gasto),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: cor),
            ),
            Text(
              'de ${Formatters.moeda(orcamento)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 12,
            color: AppColors.cinzaCimento,
            alignment: Alignment.centerLeft,
            // preenchimento animado com gradiente
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fracao),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, valor, __) => FractionallySizedBox(
                widthFactor: valor.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        cor,
                        Color.lerp(cor, Colors.white, 0.30)!,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (estourou) ...[
          const SizedBox(height: 6),
          Text(
            'Orçamento estourado em ${Formatters.moeda(gasto - orcamento)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.erro),
          ),
        ],
      ],
    );
  }
}
