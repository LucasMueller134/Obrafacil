// Fontes de verdade nas capturas de tela.
//
// No `flutter test` todo texto sai na fonte de teste (blocos) e os ícones
// viram quadrados, a menos que as fontes sejam carregadas à mão. O
// [carregarFontes] carrega, de uma vez:
//
// 1. As fontes declaradas no pubspec (FontManifest.json do build de teste),
//    lidas pelo rootBundle: Archivo, Atkinson e PlexMono, as da prancheta.
//    Uma família nova no pubspec entra aqui sem mudar nada. São as mesmas
//    que o app leva embutidas (nada é baixado da internet).
// 2. MaterialIcons, do cache do SDK do Flutter.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Famílias carregadas: [familiasNaoCarregadas] confere que nenhum texto
/// da captura ficou na fonte de teste.
final Set<String> familiasCarregadas = {};

bool _prontas = false;

/// Carrega todas as fontes (as do pubspec e o MaterialIcons). Chame no
/// setUpAll, fora do testWidgets: o carregamento é assíncrono de verdade.
/// Pode ser chamado mais de uma vez.
Future<void> carregarFontes() async {
  if (_prontas) return;
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1. Fontes do pubspec (FontManifest.json do build de teste).
  final manifesto = jsonDecode(await rootBundle.loadString('FontManifest.json'))
      as List<dynamic>;
  for (final familia in manifesto.cast<Map<String, dynamic>>()) {
    final nome = familia['family'] as String;
    if (nome == 'MaterialIcons') continue; // vem do SDK, abaixo
    final carregador = FontLoader(nome);
    for (final fonte
        in (familia['fonts'] as List).cast<Map<String, dynamic>>()) {
      carregador.addFont(rootBundle.load(fonte['asset'] as String));
    }
    await carregador.load();
    familiasCarregadas.add(nome);
  }

  // 2. Ícones Material, do cache do SDK.
  final icones = FontLoader('MaterialIcons')
    ..addFont(Future.value(_bytes(File(_caminhoMaterialIcons()))));
  await icones.load();
  familiasCarregadas.add('MaterialIcons');
  _prontas = true;
}

ByteData _bytes(File arquivo) =>
    ByteData.sublistView(Uint8List.fromList(arquivo.readAsBytesSync()));

String _caminhoMaterialIcons() {
  const relativo =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final raizes = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final r?) r,
    // flutter_tester fica em <sdk>/bin/cache/artifacts/engine/<plataforma>/
    File(Platform.resolvedExecutable)
        .parent
        .parent
        .parent
        .parent
        .parent
        .parent
        .path,
  ];
  for (final raiz in raizes) {
    final f = File('$raiz/$relativo');
    if (f.existsSync()) return f.path;
  }
  throw StateError('MaterialIcons-Regular.otf não encontrado no cache do SDK '
      '(procurado em ${raizes.join(', ')}). Rode `flutter precache`.');
}

/// Textos da árvore cuja família não foi carregada (sairiam na fonte de
/// teste). Vazio = toda a tela está nas fontes de verdade.
Set<String> familiasNaoCarregadas() {
  final faltando = <String>{};
  void visitar(InlineSpan span, String? familiaHerdada) {
    final familia = span.style?.fontFamily ?? familiaHerdada;
    if (span is TextSpan) {
      final texto = span.text ?? '';
      if (texto.trim().isNotEmpty &&
          (familia == null || !familiasCarregadas.contains(familia))) {
        faltando.add('${familia ?? '(sem família)'}: "${_curto(texto)}"');
      }
      for (final filho in span.children ?? const <InlineSpan>[]) {
        visitar(filho, familia);
      }
    }
  }

  void percorrer(RenderObject ro) {
    if (ro is RenderParagraph) visitar(ro.text, null);
    if (ro is RenderEditable) {
      final span = ro.text;
      if (span != null) visitar(span, null);
    }
    ro.visitChildren(percorrer);
  }

  for (final view in WidgetsBinding.instance.renderViews) {
    percorrer(view);
  }
  return faltando;
}

String _curto(String s) => s.length <= 30 ? s : '${s.substring(0, 30)}…';
