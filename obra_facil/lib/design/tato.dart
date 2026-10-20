// Vibração (seção 5): o mestre de luva e no barulho sente que deu certo.

import 'package:flutter/services.dart';

/// Toda vibração do app passa por aqui.
///
/// No Android, cada chamada vira uma constante do sistema (ver
/// `PlatformPlugin.java` do Flutter): `selectionClick` → CLOCK_TICK,
/// `mediumImpact` → KEYBOARD_TAP, `heavyImpact` → CONTEXT_CLICK e
/// `vibrate` → LONG_PRESS. O CONTEXT_CLICK é tão fraco quanto o toque de
/// teclado; o LONG_PRESS é o mais forte que funciona em qualquer versão.
abstract final class Tato {
  /// Desliga todas as vibrações (preferência do usuário, testes).
  static bool ativo = true;

  /// Seleção: escolher uma opção, marcar algo.
  static Future<void> leve() =>
      ativo ? HapticFeedback.selectionClick() : Future.value();

  /// Salvar e aprovar.
  static Future<void> confirmar() =>
      ativo ? HapticFeedback.mediumImpact() : Future.value();

  /// Falhou: a vibração longa do sistema, bem mais forte que a de
  /// confirmar, para não confundir.
  static Future<void> erro() =>
      ativo ? HapticFeedback.vibrate() : Future.value();
}
