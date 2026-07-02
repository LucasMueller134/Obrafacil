// lib/firebase_options.dart
// ATENÇÃO: Este arquivo é gerado automaticamente pelo FlutterFire CLI.
// Execute: flutterfire configure
// Depois substitua este arquivo pelo gerado.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Plataforma não suportada');
    }
  }

  // SUBSTITUA com os dados gerados pelo: flutterfire configure
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'SUA_API_KEY',
    appId: 'SEU_APP_ID',
    messagingSenderId: 'SEU_SENDER_ID',
    projectId: 'SEU_PROJECT_ID',
    storageBucket: 'SEU_BUCKET.appspot.com',
  );
}
