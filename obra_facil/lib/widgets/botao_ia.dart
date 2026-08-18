import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Botão de entrada por IA (foto ou voz) — o par que abre os formulários
/// de lançamento e de diário.
class BotaoIa extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String descricao;
  final VoidCallback? onTap;

  const BotaoIa({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.descricao,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.laranja.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.laranja.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Icon(icone, color: AppColors.laranja, size: 26),
            const SizedBox(height: 8),
            Text(rotulo,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

/// Faixa amarela com o que a IA entendeu (ou não) da foto/fala.
class AvisoIa extends StatelessWidget {
  final String mensagem;

  const AvisoIa({super.key, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amareloCapacete.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.amareloCapacete.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome,
              size: 18, color: AppColors.amareloCapacete),
          const SizedBox(width: 8),
          Expanded(
            child:
                Text(mensagem, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
