import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/utils/validators.dart';

void main() {
  group('Validação de e-mail', () {
    test('aceita endereços comuns', () {
      for (final email in [
        'lucas@gmail.com',
        'lucas.mueller@soow.com.br',
        'obra+teste@dominio.com',
        'mestre-1@empresa.eng.br',
      ]) {
        expect(Validators.email(email), isNull, reason: email);
      }
    });

    test('recusa o que nenhum servidor entregaria', () {
      for (final email in [
        'lucas',
        'lucas@',
        '@gmail.com',
        'lucas@gmail',
        'lucas@@gmail.com',
        'lucas gomes@gmail.com',
        'lucas..mueller@gmail.com',
        'lucas.@gmail.com',
        'lucas@.com',
        'lucas@gmail.c',
      ]) {
        expect(Validators.email(email), isNotNull, reason: email);
      }
    });

    test('campo vazio pede o e-mail', () {
      expect(Validators.email(''), 'Informe o e-mail');
      expect(Validators.email(null), 'Informe o e-mail');
      expect(Validators.email('   '), 'Informe o e-mail');
    });
  });
}
