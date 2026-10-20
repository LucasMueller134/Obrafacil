// Montagem comum dos testes do design system.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/design.dart';

/// Põe [filho] numa tela com o tema da prancheta.
///
/// [semAnimacao] liga o "reduzir animações" do aparelho; [escalaTexto] é o
/// tamanho de fonte do sistema; [rolavel] põe o filho numa coluna rolável
/// (para listas de componentes) em vez de centralizado.
Widget montar(
  Widget filho, {
  Brightness brilho = Brightness.light,
  bool semAnimacao = false,
  double escalaTexto = 1,
  bool rolavel = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: semAnimacao,
        textScaler: TextScaler.linear(escalaTexto),
      ),
      child: child!,
    ),
    home: TemaPrancheta(
      brilho: brilho,
      child: Scaffold(
        body: rolavel
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(Espaco.margem),
                child: filho,
              )
            : Center(child: filho),
      ),
    ),
  );
}

/// Tela de [largura] x [altura] pontos (densidade 1).
void definirTela(WidgetTester tester, double largura, [double altura = 800]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(largura, altura);
  addTearDown(tester.view.reset);
}

/// Grava as vibrações pedidas ao sistema enquanto o teste roda.
List<String> gravarVibracoes(WidgetTester tester) {
  final chamadas = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (chamada) async {
      if (chamada.method == 'HapticFeedback.vibrate') {
        // Sem argumento é a vibração padrão (HapticFeedback.vibrate).
        chamadas.add(chamada.arguments as String? ?? 'padrao');
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return chamadas;
}
