// Plugins nativos de mentira para as capturas: sem Android não há
// microfone nem ML Kit, e o canal sem resposta derruba o teste.
//
// - Voz (speech_to_text): responde como o Android ("initialize" e
//   "listen" dão certo) e [falaDoAparelho] manda ao app o que o
//   reconhecedor mandaria, na mesma forma usada em
//   test/escuta_microfone_test.dart.
// - ML Kit (OCR, códigos, rótulos): as telas criam os leitores e os
//   fecham no dispose; o fechar só precisa de uma resposta.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const canalVoz = MethodChannel('plugin.csdcorp.com/speech_to_text');

const _canaisMudos = [
  MethodChannel('google_mlkit_text_recognizer'),
  MethodChannel('google_mlkit_barcode_scanning'),
  MethodChannel('google_mlkit_image_labeler'),
];

bool _instalados = false;

/// Instala os plugins de mentira (uma vez por arquivo de teste). Ficam até
/// o fim: uma tela desmontada depois de um teste que falhou ainda fecha o
/// microfone e o leitor de notas, e sem resposta o erro cairia no teste
/// seguinte.
void instalarPluginsFalsos() {
  if (_instalados) return;
  _instalados = true;
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  mensageiro.setMockMethodCallHandler(
    canalVoz,
    (chamada) async => switch (chamada.method) {
      'initialize' || 'has_permission' || 'listen' => true,
      _ => null,
    },
  );
  for (final canal in _canaisMudos) {
    mensageiro.setMockMethodCallHandler(canal, (_) async => null);
  }
}

/// O reconhecedor do aparelho manda um evento para o app.
Future<void> _doAparelho(
    WidgetTester tester, String metodo, Object argumento) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    canalVoz.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(metodo, argumento)),
    (_) {},
  );
  await tester.pump();
}

/// O microfone abriu (o Android avisa "listening").
Future<void> microfoneAberto(WidgetTester tester) =>
    _doAparelho(tester, 'notifyStatus', 'listening');

/// O reconhecedor ouviu [texto] — parcial enquanto a pessoa fala, ou o
/// resultado final quando [finalizou].
Future<void> falaDoAparelho(
  WidgetTester tester,
  String texto, {
  bool finalizou = false,
  double confianca = 0.92,
}) =>
    _doAparelho(
      tester,
      'textRecognition',
      jsonEncode({
        'alternates': [
          {'recognizedWords': texto, 'confidence': confianca},
        ],
        'resultType': finalizou ? 2 : 0,
      }),
    );
