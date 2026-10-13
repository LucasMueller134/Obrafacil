import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/screens/lancamentos/novo_lancamento_screen.dart';

void main() {
  group('Novo lançamento — mensagem quando não salva', () {
    test('permissão negada diz com quem falar', () {
      final msg = NovoLancamentoScreen.mensagemAoSalvar(FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing or insufficient permissions.'));
      expect(msg, contains('permissão'));
      expect(msg, isNot(contains('cloud_firestore')));
    });

    test('sem conexão pede para conferir a internet', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        final msg = NovoLancamentoScreen.mensagemAoSalvar(
            FirebaseException(plugin: 'cloud_firestore', code: code));
        expect(msg, contains('internet'), reason: code);
      }
    });

    test('foto que não abre sugere tirar outra', () {
      final msg = NovoLancamentoScreen.mensagemAoSalvar(
          const FileSystemException('Cannot open file', '/data/x.jpg'));
      expect(msg, contains('foto'));
      expect(msg, isNot(contains('/data')));
    });

    test('qualquer outro erro vira uma frase, nunca o texto técnico', () {
      final msg = NovoLancamentoScreen.mensagemAoSalvar(
          StateError('Bad state: No element'));
      expect(
          msg,
          'Não foi possível salvar o lançamento. Tente de novo em '
          'instantes.');
    });
  });
}
