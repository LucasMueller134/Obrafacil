import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Cartão pequeno de indicador (ex.: "Gasto total", "Pendentes").
class CartaoResumo extends StatelessWidget {
  final String rotulo;
  final String valor;
  final IconData icone;
  final Color cor;

  const CartaoResumo({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.icone,
    this.cor = AppColors.laranja,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: cor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rotulo,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textoSecundario),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
