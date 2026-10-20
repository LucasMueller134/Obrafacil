// Movimento da prancheta (seção 5 da especificação).
//
// Só o que informa uma mudança se mexe. Com "reduzir animações" ligado no
// aparelho, toda duração vira zero: use `context.duracao(...)`.

import 'package:flutter/widgets.dart';

/// Durações, curvas e mola.
abstract final class Movimento {
  /// Estado pressionado, troca de seleção.
  static const Duration rapido = Duration(milliseconds: 120);

  /// Entrar e sair de elementos.
  static const Duration medio = Duration(milliseconds: 220);

  /// Traçado de cota, contagem de valor, maquete.
  static const Duration lento = Duration(milliseconds: 360);

  /// Quanto tempo o "Desfazer" fica à vista depois de aprovar ou excluir
  /// (no lugar de um diálogo de confirmação).
  static const Duration janelaDesfazer = Duration(seconds: 4);

  static const Curve entrar = Curves.easeOutCubic;
  static const Curve sair = Curves.easeInCubic;

  /// Folhas e cartões: assenta sem quique (amortecimento 0,92 do crítico).
  static const SpringDescription mola =
      SpringDescription(mass: 1, stiffness: 520, damping: 42);

  /// O aparelho pediu para reduzir animações? Sem MediaQuery, não.
  static bool reduzido(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duracao], ou zero com "reduzir animações".
  static Duration ajustar(BuildContext context, Duration duracao) =>
      reduzido(context) ? Duration.zero : duracao;
}

/// Atalhos de movimento no contexto.
extension MovimentoDoContexto on BuildContext {
  /// "Reduzir animações" está ligado?
  bool get reduzirAnimacoes => Movimento.reduzido(this);

  /// A duração pedida, ou zero com "reduzir animações".
  Duration duracao(Duration duracao) => Movimento.ajustar(this, duracao);
}
