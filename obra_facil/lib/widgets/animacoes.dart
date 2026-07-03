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
