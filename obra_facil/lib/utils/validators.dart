import 'formatters.dart';

/// Validações de formulário.
abstract class Validators {
  static String? obrigatorio(String? v, [String campo = 'Este campo']) {
    if (v == null || v.trim().isEmpty) return '$campo é obrigatório';
    return null;
  }

  /// Formato do e-mail. A prova de que ele existe mesmo é o link de
  /// confirmação enviado no cadastro — aqui só barramos o que já dá para
  /// saber que está errado antes de gastar um envio.
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
    final email = v.trim();
    if (email.contains(' ')) return 'O e-mail não pode ter espaços';
    final regex = RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$');
    if (!regex.hasMatch(email)) return 'E-mail inválido';
    // ".." e ponto colado no @ passam pela regex mas nenhum servidor aceita.
    if (email.contains('..') ||
        email.startsWith('.') ||
        email.contains('.@') ||
        email.contains('@.')) {
      return 'E-mail inválido';
    }
    final dominio = email.split('@').last;
    if (dominio.split('.').last.length < 2) {
      return 'Domínio do e-mail incompleto';
    }
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
