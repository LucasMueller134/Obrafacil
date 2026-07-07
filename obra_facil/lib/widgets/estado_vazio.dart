import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String mensagem;
  final String? rotuloAcao;
  final VoidCallback? onAcao;

  /// Ilustração temática de canteiro — quando presente, substitui o ícone.
  final Widget? ilustracao;

  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.mensagem,
    this.rotuloAcao,
    this.onAcao,
    this.ilustracao,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ilustracao != null)
              SizedBox(width: 170, height: 160, child: ilustracao)
            else
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.superficieAlta,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icone, size: 36, color: AppColors.laranja),
              ),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textoSecundario),
              textAlign: TextAlign.center,
            ),
            if (rotuloAcao != null && onAcao != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAcao,
                icon: const Icon(Icons.add),
                label: Text(rotuloAcao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
