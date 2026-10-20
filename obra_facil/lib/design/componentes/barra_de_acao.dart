import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Rodapé fixo com a ação principal da tela, ao alcance do polegar.
///
/// Use em `Scaffold.bottomNavigationBar`: a barra sobe junto com o teclado
/// e respeita a área segura (barra de gestos). A [principal] ocupa a
/// largura; a [secundaria] (em geral um `BotaoIcone`) fica à direita, a
/// 12 dp.
class BarraDeAcao extends StatelessWidget {
  const BarraDeAcao({
    super.key,
    required this.principal,
    this.secundaria,
    this.acima,
  });

  final Widget principal;
  final Widget? secundaria;

  /// Linha de apoio acima dos botões (ex.: total selecionado).
  final Widget? acima;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    final seguro = MediaQuery.paddingOf(context);
    final inferior = math.max(teclado, seguro.bottom);
    return Material(
      color: c.papel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.grafite, width: Traco.fino),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Espaco.margem + seguro.left,
            Espaco.e12,
            Espaco.margem + seguro.right,
            Espaco.e12 + inferior,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (acima != null) ...[
                acima!,
                const SizedBox(height: Espaco.e8),
              ],
              Row(
                children: [
                  Expanded(child: principal),
                  if (secundaria != null) ...[
                    const SizedBox(width: Espaco.entreAlvos),
                    secundaria!,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
