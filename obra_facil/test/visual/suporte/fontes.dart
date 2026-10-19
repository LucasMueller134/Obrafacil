// Fontes de verdade nas capturas de tela.
//
// No `flutter test` todo texto sai na fonte de teste (blocos) e os ícones
// viram quadrados, a menos que as fontes sejam carregadas à mão. O
// [carregarFontes] carrega, de uma vez:
//
// 1. Poppins (tema atual, via google_fonts). O google_fonts baixaria a
//    fonte em tempo de execução, o que não existe no teste. O download é
//    desligado (allowRuntimeFetching = false) e os TTF de
//    test/visual/fontes/ — os mesmos arquivos, byte a byte (SHA-256 da
//    tabela do google_fonts 6.3.3), que o app baixa de fonts.gstatic.com
//    no aparelho — são servidos como se fossem assets do app: o
//    canal 'flutter/assets' é interceptado e o AssetManifest.bin ganha as
//    entradas "visual_teste/fontes/Poppins-*.ttf", que é onde o google_fonts
//    procura antes de ir à rede. Ele mesmo registra cada variante com o
//    nome que usa nos TextStyle ("Poppins_regular", "Poppins_700"...).
// 2. Fontes declaradas no pubspec (FontManifest.json do build de teste),
//    lidas pelo rootBundle: Archivo, Atkinson e PlexMono, do redesenho.
//    Uma família nova no pubspec entra aqui sem mudar nada.
// 3. MaterialIcons, do cache do SDK do Flutter.
// 4. Uma fonte de símbolos (subconjunto da Noto, OFL) registrada com o
//    nome "Poppins": a Poppins não tem "→" nem "✕", e no aparelho o
//    Android completa com a fonte do sistema; no teste, sem isso, sairia
//    um quadradinho. O google_fonts põe "Poppins" no fontFamilyFallback
//    de todo estilo, então é por esse nome que o fallback entra.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

const _pastaFontes = 'test/visual/fontes';
const _prefixoAsset = 'visual_teste/fontes/';

/// Variantes da Poppins que o app usa (e que estão em test/visual/fontes).
/// Se o app pedir outra (ex.: w300), o google_fonts acusa no teste.
const _variantesPoppins = <(FontWeight, FontStyle, String)>[
  (FontWeight.w400, FontStyle.normal, 'Poppins-Regular'),
  (FontWeight.w400, FontStyle.italic, 'Poppins-Italic'),
  (FontWeight.w500, FontStyle.normal, 'Poppins-Medium'),
  (FontWeight.w600, FontStyle.normal, 'Poppins-SemiBold'),
  (FontWeight.w700, FontStyle.normal, 'Poppins-Bold'),
  (FontWeight.w800, FontStyle.normal, 'Poppins-ExtraBold'),
];

/// Famílias que recebem a fonte de símbolos como último recurso. Se o
/// tema novo listar outra família em `fontFamilyFallback`, acrescente-a
/// aqui para os símbolos que faltarem nas fontes embutidas.
const familiasComFallbackDeSimbolos = ['Poppins'];

/// Famílias carregadas: [familiasNaoCarregadas] confere que nenhum texto
/// da captura ficou na fonte de teste.
final Set<String> familiasCarregadas = {};

bool _prontas = false;

/// Carrega todas as fontes (Poppins, as do pubspec, MaterialIcons e o
/// fallback de símbolos). Chame no setUpAll, fora do testWidgets: o
/// carregamento é assíncrono de verdade. Pode ser chamado mais de uma vez.
Future<void> carregarFontes() async {
  if (_prontas) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  _servirFontesComoAssets();
  rootBundle.clear();

  // 1. Poppins pelo próprio google_fonts, sem rede.
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final (peso, estilo, _) in _variantesPoppins) {
    final s = GoogleFonts.poppins(fontWeight: peso, fontStyle: estilo);
    familiasCarregadas.add(s.fontFamily!);
  }
  await GoogleFonts.pendingFonts();

  // 2. Fontes do pubspec (FontManifest.json do build de teste).
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

  // 3. Ícones Material, do cache do SDK.
  final icones = FontLoader('MaterialIcons')
    ..addFont(Future.value(_bytes(File(_caminhoMaterialIcons()))));
  await icones.load();
  familiasCarregadas.add('MaterialIcons');

  // 4. Símbolos como fallback.
  for (final familia in familiasComFallbackDeSimbolos) {
    final c = FontLoader(familia)
      ..addFont(Future.value(
          _bytes(File('$_pastaFontes/SimbolosTeste-Regular.ttf'))));
    await c.load();
    familiasCarregadas.add(familia);
  }
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

/// Intercepta o canal de assets: as chaves "visual_teste/fontes/..." saem
/// de test/visual/fontes; o AssetManifest.bin ganha essas chaves; o resto
/// é lido do build de teste, como o flutter_test faria.
void _servirFontesComoAssets() {
  final pastaBuild = Platform.environment['UNIT_TEST_ASSETS'];
  final prefixoPacote = 'packages/${Platform.environment['APP_NAME'] ?? ''}/';

  File? doBuild(String chave) {
    if (pastaBuild == null) return null;
    var f = File('$pastaBuild/$chave');
    if (f.existsSync()) return f;
    if (chave.startsWith(prefixoPacote)) {
      f = File('$pastaBuild/${chave.substring(prefixoPacote.length)}');
      if (f.existsSync()) return f;
    }
    return null;
  }

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (mensagem) async {
    final chave = utf8.decode(mensagem!.buffer
        .asUint8List(mensagem.offsetInBytes, mensagem.lengthInBytes));
    if (chave.startsWith(_prefixoAsset)) {
      final f = File('$_pastaFontes/${chave.substring(_prefixoAsset.length)}');
      return f.existsSync() ? _bytes(f) : null;
    }
    if (chave == 'AssetManifest.bin') {
      final original = doBuild(chave);
      final mapa = original == null
          ? <Object?, Object?>{}
          : const StandardMessageCodec().decodeMessage(_bytes(original))
              as Map<Object?, Object?>;
      for (final (_, _, arquivo) in _variantesPoppins) {
        final k = '$_prefixoAsset$arquivo.ttf';
        mapa[k] = <Object?>[
          <Object?, Object?>{'asset': k},
        ];
      }
      return const StandardMessageCodec().encodeMessage(mapa);
    }
    final f = doBuild(chave);
    return f == null ? null : _bytes(f);
  });
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
