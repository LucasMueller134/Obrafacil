import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/mensagens_erro.dart';

void main() {
  group('Mensagens de erro da câmera e das IAs', () {
    test('câmera sem permissão explica onde liberar', () {
      final m = MensagensErro.daCamera(
          PlatformException(code: 'camera_access_denied', message: 'x'));
      expect(m, contains('permissão'));
      expect(m, contains('configurações'));
    });

    test('aparelho sem câmera sugere a galeria', () {
      final m = MensagensErro.daCamera(
          PlatformException(code: 'no_available_camera'));
      expect(m, contains('galeria'));
    });

    test('falha da IA não mostra a exceção crua', () {
      final erro = PlatformException(
          code: 'ImageLabelingError', message: 'Failed to load model');
      final m = MensagensErro.daAnalise(erro, oQue: 'a foto');
      expect(m, isNot(contains('PlatformException')));
      expect(m, isNot(contains('Failed')));
      expect(m, contains('a foto'));
    });

    test('foto que não abre no aparelho pede outra foto', () {
      final m = MensagensErro.daAnalise(
          const FileSystemException('Cannot open file'),
          oQue: 'o material');
      expect(m, contains('Tire outra'));
      expect(m, isNot(contains('Cannot')));
    });

    test('fora do celular avisa que a IA é do app instalado', () {
      final m = MensagensErro.daAnalise(MissingPluginException('sem canal'),
          oQue: 'o material');
      expect(m, contains('celular'));
    });

    test('leitura demorada sugere foto mais simples', () {
      final m = MensagensErro.daAnalise(TimeoutException('lento'),
          oQue: 'o material');
      expect(m, contains('demorou'));
    });
  });

  group('Mensagens de erro ao salvar', () {
    test('sem permissão no Firestore manda falar com o dono', () {
      final m = MensagensErro.aoSalvar(FirebaseException(
          plugin: 'cloud_firestore', code: 'permission-denied'));
      expect(m, contains('permissão'));
      expect(m, isNot(contains('permission-denied')));
    });

    test('documento grande demais aponta as fotos', () {
      final m = MensagensErro.aoSalvar(FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: 'Document exceeds the maximum allowed size of 1 MB',
      ));
      expect(m, contains('fotos'));
    });

    test('servidor fora do ar fala de conexão', () {
      final m = MensagensErro.aoSalvar(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
      expect(m, contains('conexão'));
    });

    test('erro desconhecido vira mensagem genérica, sem detalhe técnico', () {
      final m = MensagensErro.aoSalvar(StateError('Bad state: xyz'));
      expect(m, isNot(contains('xyz')));
      expect(m, contains('Tente de novo'));
    });
  });
}
