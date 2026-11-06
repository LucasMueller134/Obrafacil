// Configuração do Firebase do projeto obrafacil-a755c.
// Gerada a partir do google-services.json (equivalente ao flutterfire configure,
// feito manualmente porque a rede corporativa bloqueia o pub.dev).

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
            'Obra na Mão é Android-first: plataforma não suportada.');
    }
  }

  /// True quando as chaves reais do projeto já estão configuradas.
  static bool get configurado => !android.apiKey.contains('PLACEHOLDER');

  /// ID do cliente "web" do login com Google (no Firebase: Authentication →
  /// Sign-in method → Google → Configuração do SDK da Web). Não é segredo:
  /// vai dentro de todo app que usa o login do Google. Vazio, o botão
  /// "Entrar com o Google" não aparece.
  static const googleWebClientId = '';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCi0msI8deseumFQeMIV82DnA4b6yzaNQ',
    appId: '1:1038297734342:android:dddea9d24f4515c47d8bc7',
    messagingSenderId: '1038297734342',
    projectId: 'obrafacil-a755c',
    storageBucket: 'obrafacil-a755c.firebasestorage.app',
  );
}
