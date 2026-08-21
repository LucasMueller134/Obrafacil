import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animações padrão do ObraFácil — entrada escalonada e suave,
/// consistente em todas as telas.
extension AnimacoesObraFacil on Widget {
  /// Item de lista: fade + desliza de baixo, com atraso pelo índice.
  Widget aparecer(int indice) => animate(
        delay: Duration(milliseconds: 45 * indice.clamp(0, 10)),
      )
          .fadeIn(duration: 260.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.12,
            end: 0,
            duration: 320.ms,
            curve: Curves.easeOutCubic,
          );

  /// Seção de dashboard: fade com leve zoom.
  Widget aparecerSecao(int indice) => animate(
        delay: Duration(milliseconds: 60 * indice.clamp(0, 8)),
      )
          .fadeIn(duration: 300.ms, curve: Curves.easeOut)
          .scaleXY(begin: 0.98, end: 1, duration: 300.ms);
}

/// Troca entre os estados de uma tela — tipicamente o "carregando" dando
/// lugar ao conteúdo.
///
/// O conteúdo novo aparece sozinho: o estado anterior sai do desenho no
/// mesmo instante, sem ficar sobreposto. Cruzar os dois deixava o
/// indicador de carregamento boiando por cima da lista, que é justamente
/// a poluição que se quer evitar numa tela cheia.
class TrocaSuave extends StatelessWidget {
  final Widget child;

  const TrocaSuave({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      // Só o estado atual é pintado — nada de empilhar o que está saindo.
      layoutBuilder: (atual, __) => atual ?? const SizedBox.shrink(),
      transitionBuilder: (filho, animacao) => FadeTransition(
        opacity: animacao,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animacao),
          child: filho,
        ),
      ),
      child: child,
    );
  }
}
