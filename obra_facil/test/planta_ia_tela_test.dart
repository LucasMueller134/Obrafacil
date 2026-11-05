// A IA da planta nas telas, com a IA falsa (nada sai para a rede nem gasta):
// ler a planta, revisar e confirmar; as imagens "como vai ficar" na planta,
// no cliente e na vista 360°; gerar uma imagem; e as mensagens de falha.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:obra_facil/design/design.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';
import 'package:obra_facil/screens/planta/como_vai_ficar.dart';
import 'package:obra_facil/screens/planta/enviar_planta.dart';
import 'package:obra_facil/services/firestore_service.dart';
import 'package:obra_facil/services/ia/planta_ia_service.dart';
import 'package:provider/provider.dart';

import 'visual/suporte/captura.dart';
import 'visual/suporte/dados_exemplo.dart';
import 'visual/suporte/fakes.dart';
import 'visual/suporte/plataforma.dart';

/// Uma tela solta, com os provedores do app.
Future<FirestoreFalso> _abrirTela(WidgetTester tester, Widget tela,
    {PlantaIaService? ia}) async {
  final view = tester.view
    ..devicePixelRatio = 2
    ..physicalSize = const Size(390, 844) * 2;
  addTearDown(view.reset);
  instalarPluginsFalsos();
  final db = FirestoreFalso(DadosExemplo.padrao());
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<FirestoreService>.value(value: db),
      Provider<PlantaIaService>.value(value: ia ?? PlantaIaFalsa()),
    ],
    child: MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: TemaPrancheta(child: tela),
    ),
  ));
  await assentar(tester);
  return db;
}

class _App {
  _App(this.db, this.auth, this.router);

  final FirestoreFalso db;
  final AuthProvider auth;
  final GoRouter router;
}

Future<_App> _abrirApp(WidgetTester tester, String rota,
    {required UsuarioModel usuario}) async {
  final view = tester.view
    ..devicePixelRatio = 2
    ..physicalSize = const Size(390, 844) * 2;
  addTearDown(view.reset);
  instalarPluginsFalsos();
  final db = FirestoreFalso(DadosExemplo.padrao().comImagens());
  final auth = AuthProvider(AuthServiceFalso(usuario));
  final router = criarRouter(auth);
  await tester.pumpWidget(AppDeCaptura(auth: auth, db: db, router: router));
  await assentar(tester);
  router.go(rota);
  await assentar(tester);
  return _App(db, auth, router);
}

Future<void> _fechar(WidgetTester tester, [_App? app]) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  app?.router.dispose();
  app?.auth.dispose();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await assentar(tester);
}

/// Rola a tela até [alvo] (a lista constrói só o que está à vista).
Future<void> _rolarAte(WidgetTester tester, Finder alvo,
    {double passo = 200}) async {
  await tester.scrollUntilVisible(alvo, passo,
      scrollable: find.byType(Scrollable).first);
  await tester.pump();
}

/// Texto de uma nota (Text.rich com o ícone na frente).
Finder _nota(String texto) => find.textContaining(texto, findRichText: true);

/// Um PNG pequeno de verdade (o quadro "capturado" da vista).
Uint8List _png() {
  final i = img.Image(width: 8, height: 6);
  img.fill(i, color: img.ColorRgb8(200, 120, 40));
  return Uint8List.fromList(img.encodePng(i));
}

PlantaObra _semComodos(PlantaObra p) => PlantaObra(
      versao: p.versao,
      nome: p.nome,
      fonte: p.fonte,
      largura: p.largura,
      profundidade: p.profundidade,
      alturas: p.alturas,
      cobertura: p.cobertura,
      paredes: p.paredes,
      pilares: p.pilares,
      comodos: const [],
    );

void main() {
  setUpAll(prepararCapturas);

  group('revisão da planta lida', () {
    testWidgets('mostra os avisos da IA e grava ao confirmar', (tester) async {
      final planta = DadosExemplo.plantaExemplo();
      final db = await _abrirTela(
        tester,
        RevisaoPlantaScreen(
          obraId: IdsExemplo.obra,
          leitura: LeituraPlanta(
            planta: planta,
            avisos: const ['A cota da garagem estava borrada.'],
          ),
        ),
      );
      expect(find.text('Confira antes de confirmar'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      await _rolarAte(tester, _nota('A cota da garagem estava borrada.'));

      await _tocar(tester, find.text('Confirmar a planta'));
      expect(db.escritas,
          contains('salvarPlanta ${IdsExemplo.obra} ${planta.nome}'));
      expect(tester.takeException(), isNull);
      await _fechar(tester);
    });

    testWidgets('com problema, não deixa confirmar', (tester) async {
      final db = await _abrirTela(
        tester,
        RevisaoPlantaScreen(
          obraId: IdsExemplo.obra,
          leitura: LeituraPlanta(
              planta: _semComodos(DadosExemplo.plantaExemplo())),
        ),
      );
      await _rolarAte(tester, _nota('A planta não tem cômodos.'));
      expect(find.text('Corrija os itens em vermelho para confirmar.'),
          findsOneWidget);
      final botao =
          tester.widget<BotaoPrincipal>(find.byType(BotaoPrincipal).last);
      expect(botao.aoTocar, isNull);
      expect(db.escritas, isEmpty);
      await _fechar(tester);
    });

    testWidgets('corrige o nome do cômodo e o pé-direito', (tester) async {
      final planta = DadosExemplo.plantaExemplo();
      final primeiro = planta.comodos.firstWhere((c) => c.coberto);
      await _abrirTela(
        tester,
        RevisaoPlantaScreen(
          obraId: IdsExemplo.obra,
          leitura: LeituraPlanta(planta: planta),
        ),
      );
      final linha = find.widgetWithText(LinhaLista, primeiro.nome);
      await _rolarAte(tester, linha);
      await _tocar(tester, linha);
      await tester.enterText(find.byType(TextField), 'Sala de estar');
      await _tocar(tester, find.text('Salvar o cômodo'));
      expect(find.text('Sala de estar'), findsOneWidget);

      final mais = find.widgetWithIcon(BotaoIcone, Icons.add);
      await _rolarAte(tester, mais, passo: -200);
      await _tocar(tester, mais);
      expect(find.text('2,55 m'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _fechar(tester);
    });
  });

  group('lendo a planta', () {
    testWidgets('lida, abre a revisão', (tester) async {
      final ia = PlantaIaFalsa(
          leitura: LeituraPlanta(planta: DadosExemplo.plantaExemplo()));
      await _abrirTela(
        tester,
        LeituraPlantaScreen(
          obraId: IdsExemplo.obra,
          arquivo: ArquivoPlanta(Uint8List(10), 'planta.pdf'),
        ),
        ia: ia,
      );
      expect(ia.pedidos, ['lerPlanta ${IdsExemplo.obra} planta.pdf 10']);
      expect(find.text('Confira antes de confirmar'), findsOneWidget);
      await _fechar(tester);
    });

    testWidgets('função não publicada: diz o que falta', (tester) async {
      final ia = PlantaIaFalsa(
          falha: PlantaIaFirebase.traduzirFalha('not-found', 'NOT_FOUND'));
      await _abrirTela(
        tester,
        LeituraPlantaScreen(
          obraId: IdsExemplo.obra,
          arquivo: ArquivoPlanta(Uint8List(10), 'planta.pdf'),
        ),
        ia: ia,
      );
      expect(find.text('A leitura não deu certo'), findsOneWidget);
      expect(find.textContaining('ainda não foi publicada'), findsOneWidget);
      // Tentar de novo não adianta: só voltar.
      expect(find.text('Tentar de novo'), findsNothing);
      expect(find.widgetWithText(BotaoContorno, 'Voltar'), findsOneWidget);
      await _fechar(tester);
    });
  });

  test('as falhas das funções viram mensagens para o dono', () {
    expect(PlantaIaFirebase.traduzirFalha('not-found', null).naoPublicada,
        isTrue);
    expect(
        PlantaIaFirebase.traduzirFalha('not-found', 'Obra não encontrada.')
            .mensagem,
        'Obra não encontrada.');
    expect(
        PlantaIaFirebase.traduzirFalha('resource-exhausted', 'Limite do mês.')
            .mensagem,
        'Limite do mês.');
    expect(PlantaIaFirebase.traduzirFalha('unauthenticated', null).mensagem,
        contains('Entre'));
  });

  group('como vai ficar', () {
    testWidgets('na planta: a galeria e, para o dono, gerar a fachada',
        (tester) async {
      final app = await _abrirApp(tester, '/obras/${IdsExemplo.obra}/planta',
          usuario: UsuariosExemplo.dono);
      await tester.scrollUntilVisible(
          find.text('Gerar a fachada de novo'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Fachada'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _fechar(tester, app);
    });

    testWidgets('no cliente: a galeria, sem botão de gerar', (tester) async {
      final app = await _abrirApp(tester, '/cliente/${IdsExemplo.obra}',
          usuario: UsuariosExemplo.cliente);
      await tester.scrollUntilVisible(find.text('Fachada'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Gerar'), findsNothing);
      expect(tester.takeException(), isNull);
      await _fechar(tester, app);
    });

    testWidgets('gerar a imagem de um cômodo', (tester) async {
      final ia = PlantaIaFalsa();
      await _abrirTela(
        tester,
        GerarImagemScreen(
          obraId: IdsExemplo.obra,
          pedido: PedidoImagem.comodo(
            vista: 'sala',
            nomeComodo: 'Sala',
            guia: _png(),
            medidas: '3,23 × 4,10 m',
            piso: 'Porcelanato',
          ),
        ),
        ia: ia,
      );
      expect(find.textContaining('US\$ 0,24'), findsWidgets);
      await _tocar(tester, find.textContaining('Gerar a imagem'));
      expect(ia.pedidos, ['gerarImagem ${IdsExemplo.obra} sala true']);
      expect(find.text('Pronto'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _fechar(tester);
    });

    testWidgets('limite do mês: a mensagem aparece e nada quebra',
        (tester) async {
      final ia = PlantaIaFalsa(
          falha: const FalhaIaPlanta('Limite de imagens do mês atingido.'));
      await _abrirTela(
        tester,
        GerarImagemScreen(
          obraId: IdsExemplo.obra,
          pedido: PedidoImagem.comodo(
              vista: 'sala', nomeComodo: 'Sala', guia: _png()),
        ),
        ia: ia,
      );
      await _tocar(tester, find.textContaining('Gerar a imagem'));
      await _rolarAte(tester, _nota('Limite de imagens do mês atingido.'));
      expect(find.text('Pronto'), findsNothing);
      await _fechar(tester);
    });
  });
}
