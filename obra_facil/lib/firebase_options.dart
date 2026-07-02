// Arquivo gerado pelo FlutterFire CLI — substitua rodando:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Enquanto os valores abaixo forem placeholders, o app mostra a tela
// de configuração pendente em vez de tentar conectar no Firebase.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'ObraFácil é Android-first: plataforma não suportada.');
    }
  }

  /// True quando o flutterfire configure já foi executado.
  static bool get configurado => !android.apiKey.contains('PLACEHOLDER');

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_API_KEY',
    appId: 'PLACEHOLDER_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'PLACEHOLDER_PROJECT_ID',
    storageBucket: 'PLACEHOLDER_BUCKET',
  );
}
