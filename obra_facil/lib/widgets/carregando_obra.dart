import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'ilustracoes.dart';

/// Indicador de carregamento oficial do app: a betoneira girando.
class CarregandoObra extends StatelessWidget {
  final String mensagem;

  const CarregandoObra({super.key, this.mensagem = 'Preparando a massa…'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 110,
            height: 100,
            child: IlustracaoBetoneira(girando: true),
          ),
          const SizedBox(height: 10),
          Text(
            mensagem,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textoSecundario),
          ),
        ],
      ),
    );
  }
}
