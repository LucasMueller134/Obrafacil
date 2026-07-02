import 'formatters.dart';

/// Validações de formulário.
abstract class Validators {
  static String? obrigatorio(String? v, [String campo = 'Este campo']) {
    if (v == null || v.trim().isEmpty) return '$campo é obrigatório';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
    final regex = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$');
    if (!regex.hasMatch(v.trim())) return 'E-mail inválido';
    return null;
  }

  static String? senha(String? v) {
    if (v == null || v.isEmpty) return 'Informe a senha';
    if (v.length < 6) return 'A senha precisa de pelo menos 6 caracteres';
    return null;
  }

  static String? valor(String? v, {bool obrigatorio = true}) {
    if (v == null || v.trim().isEmpty) {
      return obrigatorio ? 'Informe o valor' : null;
    }
    final parsed = Formatters.parseValor(v);
    if (parsed == null) return 'Valor inválido';
    if (parsed <= 0) return 'O valor deve ser maior que zero';
    return null;
  }

  static String? numero(String? v, {bool obrigatorio = true}) {
    if (v == null || v.trim().isEmpty) {
      return obrigatorio ? 'Informe um número' : null;
    }
    final parsed = Formatters.parseValor(v);
    if (parsed == null) return 'Número inválido';
    if (parsed < 0) return 'Não pode ser negativo';
    return null;
  }
}
