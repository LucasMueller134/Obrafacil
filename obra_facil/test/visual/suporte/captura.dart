// Harness das capturas de tela (antes e depois do redesenho).
//
// Cada [Cena] vira dois testes: tela de celular (390x844 pontos) e tela
// comprida (390x2400), ambos com pixel ratio 3. O app é montado como no
// lib/main.dart — AuthProvider de verdade, router de verdade
// (criarRouter), localização pt_BR — só que com o Firebase trocado pelos
// falsos de fakes.dart e os plugins nativos por plataforma.dart.
//
// Os testes só rodam com a variável CAPTURAR definida; o valor é o nome
// da série e da pasta: CAPTURAR=antes grava em docs/redesign/antes/.
// Ver docs/redesign/LEIA-ME-capturas.md.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:obra_facil/constants/app_theme.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';
import 'package:obra_facil/services/firestore_service.dart';
import 'package:provider/provider.dart';

import 'dados_exemplo.dart';
import 'fakes.dart';
import 'fontes.dart';
import 'plataforma.dart';

/// Nome da série (variável CAPTURAR), ou null quando não é para capturar.
final String? serieDeCaptura = () {
  final valor = Platform.environment['CAPTURAR']?.trim() ?? '';
  if (valor.isEmpty) return null;
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(valor)) {
    throw StateError('CAPTURAR="$valor": use só letras, números, - e _ '
        '(é o nome da pasta em docs/redesign/).');
  }
  return valor;
}();

/// Os testes de captura rodam? (skip quando CAPTURAR não está definida)
bool get capturando => serieDeCaptura != null;

/// Pixel ratio das capturas: 390x844 pontos viram um PNG de 1170x2532.
const double pixelRatioCaptura = 3;

/// Barra de status e barra de gestos do Android (edge-to-edge), em pontos.
const double _barraDeStatus = 24;
const double _barraDeGestos = 16;

enum Tamanho {
  /// Celular comum (390x844 pontos).
  celular(Size(390, 844), ''),

  /// Tela comprida, para ver a página inteira sem rolar.
  comprida(Size(390, 2400), '_longa');

  final Size pontos;
  final String sufixo;

  const Tamanho(this.pontos, this.sufixo);
}

/// Uma tela a capturar.
class Cena {
  /// Nome do arquivo, sem extensão (ex.: "02_obra_dono").
  final String nome;

  /// Quem está logado.
  final UsuarioModel usuario;

  /// Rota aberta com `router.go`, como se a pessoa tivesse chegado nela.
  final String rota;

  /// O que fazer na tela antes da foto (tocar num filtro, abrir a voz...).
  final Future<void> Function(WidgetTester tester)? acao;

  /// Tema do sistema (o app atual só tem o escuro).
  final Brightness brilho;

  /// Defeito de layout que o app TEM nesta tela, com a mensagem exata do
  /// erro (ex.: 'A RenderFlex overflowed by 8.4 pixels on the right.').
  /// A captura mostra a faixa amarela e preta do modo debug onde o
  /// conteúdo não coube. Se o erro sumir ou mudar, o teste falha: aí é
  /// tirar daqui. Qualquer outro erro continua reprovando a captura.
  final String? defeitoConhecido;

  const Cena(
    this.nome, {
    required this.usuario,
    required this.rota,
    this.acao,
    this.brilho = Brightness.dark,
    this.defeitoConhecido,
  });
}

/// Fontes e datas em pt_BR. Chame no setUpAll do arquivo de capturas.
Future<void> prepararCapturas() async {
  await carregarFontes();
  await initializeDateFormatting('pt_BR'); // como o main()
}

/// Registra os testes da [cena] (um por [Tamanho]).
void capturarCena(Cena cena) {
  for (final tamanho in Tamanho.values) {
    testWidgets(
      '${cena.nome}${tamanho.sufixo}',
      (tester) => _capturar(tester, cena, tamanho),
      skip: !capturando,
    );
  }
}

/// O MaterialApp do lib/main.dart com o Firebase trocado pelos falsos.
/// Quando o main.dart mudar (tema claro/escuro do redesenho), mude aqui
/// também — a captura tem de ser o app como ele é.
class AppDeCaptura extends StatelessWidget {
  final AuthProvider auth;
  final FirestoreService db;
  final GoRouter router;

  const AppDeCaptura({
    super.key,
    required this.auth,
    required this.db,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        Provider<FirestoreService>.value(value: db),
      ],
      child: MaterialApp.router(
        title: 'ObraFácil',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: router,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}

/// Deixa as animações terminarem. Não usa pumpAndSettle porque algumas
/// telas têm animação contínua (o microfone pulsando).
Future<void> assentar(
  WidgetTester tester, {
  Duration total = const Duration(seconds: 2),
}) async {
  const passo = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += passo) {
    await tester.pump(passo);
  }
}

Future<void> _capturar(WidgetTester tester, Cena cena, Tamanho tamanho) async {
  // O flutter_test troca toda sombra por um contorno preto (para golden
  // estável); a captura quer a sombra de verdade. O flutter_test confere
  // no fim do corpo do teste que a variável voltou, daí o finally.
  debugDisableShadows = false;
  try {
    await _capturarCom(tester, cena, tamanho);
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _capturarCom(
    WidgetTester tester, Cena cena, Tamanho tamanho) async {
  _configurarTela(tester, tamanho, cena.brilho);
  instalarPluginsFalsos();

  final db = FirestoreFalso(DadosExemplo.padrao());
  final auth = AuthProvider(AuthServiceFalso(cena.usuario));
  final router = criarRouter(auth);
  final moldura = GlobalKey();

  await tester.pumpWidget(RepaintBoundary(
    key: moldura,
    child: AppDeCaptura(auth: auth, db: db, router: router),
  ));
  // Splash → área do perfil, quando o AuthProvider termina de carregar.
  await assentar(tester);
  expect(auth.inicializando, isFalse, reason: 'o AuthProvider não carregou');

  router.go(cena.rota);
  await assentar(tester);
  expect(router.routerDelegate.currentConfiguration.uri.toString(), cena.rota,
      reason: 'o router redirecionou para outra tela');

  if (cena.acao != null) {
    await cena.acao!(tester);
    await assentar(tester);
  }

  // Nada de tela vermelha, faixa de overflow ou texto na fonte de teste.
  final erro = tester.takeException();
  if (cena.defeitoConhecido case final defeito?) {
    expect(erro?.toString(), defeito,
        reason: 'o defeito conhecido desta tela mudou ou sumiu');
  } else {
    expect(erro, isNull, reason: 'a tela deu erro: $erro');
  }
  expect(find.byType(ErrorWidget), findsNothing);
  expect(familiasNaoCarregadas(), isEmpty,
      reason: 'texto fora das fontes carregadas (sairia em blocos)');

  await _gravarPng(tester, moldura, '${cena.nome}${tamanho.sufixo}');

  // Desmonta antes de soltar o auth e o router: as telas fecham microfone,
  // leitor de notas e timers no dispose. Os 10 s de tempo falso deixam
  // vencer o que ainda corre por conta própria (a pausa de 6 s do
  // speech_to_text só se encerra quando dispara, como no aparelho).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  router.dispose();
  auth.dispose();
}

void _configurarTela(WidgetTester tester, Tamanho tamanho, Brightness brilho) {
  final view = tester.view;
  view.devicePixelRatio = pixelRatioCaptura;
  view.physicalSize = tamanho.pontos * pixelRatioCaptura;
  const insets = FakeViewPadding(
    top: _barraDeStatus * pixelRatioCaptura,
    bottom: _barraDeGestos * pixelRatioCaptura,
  );
  view.padding = insets;
  view.viewPadding = insets;
  tester.platformDispatcher.platformBrightnessTestValue = brilho;
  addTearDown(view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// `docs/redesign/<serie>/`, achada subindo a partir da pasta do pacote.
Directory _pastaDaSerie() {
  var dir = Directory.current.absolute;
  while (true) {
    final redesign = Directory('${dir.path}/docs/redesign');
    if (redesign.existsSync()) {
      return Directory('${redesign.path}/$serieDeCaptura');
    }
    final pai = dir.parent;
    if (pai.path == dir.path) {
      throw StateError('docs/redesign/ não encontrado acima de '
          '${Directory.current.path}');
    }
    dir = pai;
  }
}

Future<void> _gravarPng(
    WidgetTester tester, GlobalKey moldura, String nome) async {
  final arquivo = File('${_pastaDaSerie().path}/$nome.png');
  await tester.runAsync(() async {
    final limite =
        moldura.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final imagem = await limite.toImage(pixelRatio: pixelRatioCaptura);
    final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
    imagem.dispose();
    arquivo.parent.createSync(recursive: true);
    arquivo.writeAsBytesSync(png!.buffer.asUint8List());
  });
}
