// O "Lançar gasto" redesenhado, no app de verdade (router, AuthProvider e
// o Firestore falso das capturas): os atalhos ?inicio=foto|voz, a
// validação com o Salvar no rodapé e o lançamento que chega ao
// FirestoreService, à mão e pela fala.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:obra_facil/design/design.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';
import 'package:obra_facil/screens/lancamentos/novo_lancamento_screen.dart';
import 'package:obra_facil/services/ia/ocr_nota_service.dart';

import 'visual/suporte/captura.dart' show AppDeCaptura, assentar;
import 'visual/suporte/dados_exemplo.dart';
import 'visual/suporte/fakes.dart';
import 'visual/suporte/fontes.dart';
import 'visual/suporte/nota_falsa.dart';
import 'visual/suporte/plataforma.dart';

const _novo = '/obras/${IdsExemplo.obra}/lancamentos/novo';

/// O falso das capturas, guardando o lançamento que a tela mandou criar.
class _FirestoreQueGuarda extends FirestoreFalso {
  _FirestoreQueGuarda() : super(DadosExemplo.padrao());

  final criados = <LancamentoModel>[];

  @override
  Future<String> criarLancamento(LancamentoModel l) {
    criados.add(l);
    return super.criarLancamento(l);
  }
}

class _App {
  _App(this.router, this.db, this.auth);

  final GoRouter router;
  final _FirestoreQueGuarda db;
  final AuthProvider auth;

  String get local => router.routerDelegate.currentConfiguration.uri.toString();
}

/// [soATela]: um router só com a rota do lançamento, sem as telas de
/// cima na pilha (a lista de obras, por exemplo, tem os defeitos dela em
/// 360 dp com fonte grande, e eles não são desta tela).
Future<_App> _abrir(
  WidgetTester tester,
  String rota, {
  Size tela = const Size(390, 844),
  double escalaTexto = 1,
  bool soATela = false,
}) async {
  final view = tester.view;
  view.devicePixelRatio = 3;
  view.physicalSize = tela * 3;
  addTearDown(view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  instalarPluginsFalsos();

  final db = _FirestoreQueGuarda();
  final auth = AuthProvider(AuthServiceFalso(UsuariosExemplo.mestre));
  final router = soATela
      ? GoRouter(initialLocation: rota, routes: [
          GoRoute(
            path: '/obras/:obraId/lancamentos/novo',
            builder: (_, estado) =>
                NovoLancamentoScreen(obraId: estado.pathParameters['obraId']!),
          ),
        ])
      : criarRouter(auth);
  await tester.pumpWidget(AppDeCaptura(auth: auth, db: db, router: router));
  await assentar(tester);
  if (!soATela) {
    router.go(rota);
    await assentar(tester);
  }
  return _App(router, db, auth);
}

/// Desmonta antes de soltar o router (a tela fecha microfone e leitor de
/// notas no dispose) e deixa vencer os prazos da escuta.
Future<void> _fechar(WidgetTester tester, _App app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  app.router.dispose();
  app.auth.dispose();
}

Finder _campo(String rotulo) => find.widgetWithText(TextFormField, rotulo);

void main() {
  // As fontes de verdade: com a de teste (todo glifo de 1 em), as telas
  // de antes da rota (a lista de obras) estouram e os toques erram.
  setUpAll(() async {
    await carregarFontes();
    await initializeDateFormatting('pt_BR');
  });

  group('Atalho ?inicio da rota', () {
    testWidgets('sem ?inicio não abre nada', (tester) async {
      final app = await _abrir(tester, _novo);
      expect(find.text('Lançar gasto'), findsOneWidget);
      expect(find.text('Tirar foto da nota'), findsNothing);
      expect(find.text('Concluir'), findsNothing);
      await _fechar(tester, app);
    });

    testWidgets('?inicio=voz abre o painel de voz uma vez só', (tester) async {
      final app = await _abrir(tester, '$_novo?inicio=voz');
      await microfoneAberto(tester);
      expect(find.text('Concluir'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await assentar(tester);
      expect(find.text('Concluir'), findsNothing);
      // Nem a reconstrução da tela nem o tempo passando abrem de novo.
      await assentar(tester);
      expect(find.text('Concluir'), findsNothing);
      expect(app.db.criados, isEmpty);
      await _fechar(tester, app);
    });

    testWidgets('?inicio=foto abre a escolha entre câmera e galeria',
        (tester) async {
      final app = await _abrir(tester, '$_novo?inicio=foto');
      expect(find.text('Tirar foto da nota'), findsOneWidget);
      expect(find.text('Escolher da galeria'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await assentar(tester);
      expect(find.text('Tirar foto da nota'), findsNothing);
      await assentar(tester);
      expect(find.text('Tirar foto da nota'), findsNothing);
      await _fechar(tester, app);
    });
  });

  group('Cabe em 360 dp', () {
    for (final escala in [1.0, 1.3]) {
      testWidgets('painel de voz e recibo, fonte a ${escala * 100 ~/ 1}%',
          (tester) async {
        final app = await _abrir(tester, _novo,
            tela: const Size(360, 740), escalaTexto: escala, soATela: true);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Falar o gasto'));
        await assentar(tester, total: const Duration(milliseconds: 600));
        await microfoneAberto(tester);
        await falaDoAparelho(
            tester,
            'comprei seis metros de areia média por mil duzentos e noventa '
            'reais no areial são jorge');
        await assentar(tester);
        expect(tester.takeException(), isNull,
            reason: 'o painel de voz estourou em 360 dp');
        // Os três botões à vista e tocáveis.
        for (final rotulo in ['Concluir', 'Regravar', 'Cancelar']) {
          final caixa = tester.getRect(find.text(rotulo));
          expect(caixa.right, lessThanOrEqualTo(360), reason: rotulo);
          expect(caixa.bottom, lessThanOrEqualTo(740), reason: rotulo);
        }
        expect(
            tester
                .getSize(find
                    .ancestor(
                        of: find.text('Concluir'),
                        matching: find.byType(AnimatedContainer))
                    .first)
                .height,
            greaterThanOrEqualTo(72));

        await tester.tap(find.text('Concluir'));
        await assentar(tester);
        expect(tester.takeException(), isNull,
            reason: 'o recibo estourou em 360 dp');
        expect(find.text('ENTENDIDO DA FALA'), findsOneWidget);
        await _fechar(tester, app);
      });
    }
  });

  group('Salvar lançamento', () {
    testWidgets('sem descrição e valor mostra os erros e não grava',
        (tester) async {
      final app = await _abrir(tester, _novo);
      await tester.tap(find.text('Salvar lançamento'));
      await assentar(tester);

      expect(find.text('A descrição é obrigatório'), findsOneWidget);
      expect(find.text('Informe o valor'), findsOneWidget);
      expect(app.db.criados, isEmpty);
      expect(app.local, _novo, reason: 'a tela não fecha');
      await _fechar(tester, app);
    });

    testWidgets('à mão: grava pendente, com categoria, fornecedor e itens',
        (tester) async {
      final app = await _abrir(tester, _novo);
      await tester.enterText(_campo('Descrição'), '10 sacos de cimento');
      await tester.enterText(_campo('Valor'), '350,00');
      await tester.enterText(
          _campo('Fornecedor (opcional)'), 'Depósito São José');
      await tester.tap(find.text('Salvar lançamento'));
      await assentar(tester);

      expect(app.db.criados, hasLength(1));
      final l = app.db.criados.single;
      expect(l.descricao, '10 sacos de cimento');
      expect(l.valor, 350);
      expect(l.categoria, CategoriaCusto.material);
      expect(l.status, StatusLancamento.pendente);
      expect(l.origem, OrigemLancamento.manual);
      expect(l.fornecedorNome, 'Depósito São José');
      expect(l.criadoPorId, UsuariosExemplo.mestre.id);
      // Material à mão: os itens saem da descrição, como antes.
      expect(l.itens, isNotEmpty);
      expect(find.text('Lançamento enviado para aprovação do dono.'),
          findsOneWidget);
      expect(app.local, '/obras/${IdsExemplo.obra}/lancamentos');
      await _fechar(tester, app);
    });

    testWidgets('a categoria escolhida no seletor é a que vai', (tester) async {
      final app = await _abrir(tester, _novo);
      await tester.enterText(_campo('Descrição'), 'Diária do pedreiro');
      await tester.enterText(_campo('Valor'), '250');
      await tester.tap(find.text('Mão de obra'));
      await tester.pump();
      await tester.tap(find.text('Salvar lançamento'));
      await assentar(tester);

      final l = app.db.criados.single;
      expect(l.categoria, CategoriaCusto.maoDeObra);
      expect(l.itens, isEmpty);
      await _fechar(tester, app);
    });

    testWidgets('pela fala: recibo, tirar e devolver item, e grava por voz',
        (tester) async {
      final app = await _abrir(tester, _novo);
      await tester.tap(find.text('Falar o gasto'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      await microfoneAberto(tester);
      await falaDoAparelho(
        tester,
        'comprei seis metros de areia média por mil duzentos e noventa '
        'reais no areial são jorge',
        finalizou: true,
      );
      await assentar(tester, total: const Duration(milliseconds: 600));
      await tester.tap(find.text('Concluir'));
      await assentar(tester);

      // O recibo, com a mesma mensagem de hoje.
      expect(find.text('ENTENDIDO DA FALA'), findsOneWidget);
      expect(
          find.text('Lançamento interpretado da sua fala — confira antes de '
              'salvar.'),
          findsOneWidget);
      expect(find.text('6 m³ Areia'), findsOneWidget);

      // Tirar o item tem "Desfazer" (no lugar de um diálogo).
      await tester.tap(find.byTooltip('Tirar 6 m³ Areia do estoque'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      expect(find.text('6 m³ Areia'), findsNothing);
      expect(find.text('6 m³ Areia não vai para o estoque.'), findsOneWidget);
      await tester.tap(find.text('Desfazer'));
      await assentar(tester);
      expect(find.text('6 m³ Areia'), findsOneWidget);

      await tester.tap(find.text('Salvar lançamento'));
      await assentar(tester);
      final l = app.db.criados.single;
      expect(l.origem, OrigemLancamento.voz);
      expect(l.valor, 1290);
      expect(l.itens.map((i) => i.resumo), ['6 m³ Areia']);
      await _fechar(tester, app);
    });

    testWidgets(
        'salvar logo depois de tirar um item: a confirmação não espera o '
        '"Desfazer" e ele não vai para a tela seguinte', (tester) async {
      final app = await _abrir(tester, _novo);
      await _falarAreia(tester);
      await tester.tap(find.byTooltip('Tirar 6 m³ Areia do estoque'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Desfazer'), findsOneWidget);

      await tester.tap(find.text('Salvar lançamento'));
      await assentar(tester, total: const Duration(seconds: 1));
      expect(app.db.criados, hasLength(1));
      expect(app.local, '/obras/${IdsExemplo.obra}/lancamentos');
      expect(find.text('Lançamento enviado para aprovação do dono.'),
          findsOneWidget);
      expect(find.text('Desfazer'), findsNothing);
      await _fechar(tester, app);
    });
  });

  group('Leitura da nota', () {
    testWidgets(
        'uma leitura que falha depois de uma boa não entra no recibo da boa',
        (tester) async {
      final app = await _abrir(tester, _novo);
      await _lerNota(tester);
      expect(find.text('LIDO DA NOTA'), findsOneWidget);

      // A segunda foto: o leitor do aparelho falha.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_text_recognizer'),
        (chamada) async => chamada.method == 'vision#startTextRecognizer'
            ? throw PlatformException(code: 'falhou')
            : null,
      );
      await _lerNota(tester, preparar: false);

      final erro = find.text(
          OcrNotaService.mensagemDeErro(PlatformException(code: 'falhou')));
      expect(erro, findsOneWidget);
      // O recibo continua o da leitura boa (os campos também), e o erro
      // fica fora dele, dito como erro.
      expect(find.text('LIDO DA NOTA'), findsOneWidget);
      expect(
          find.ancestor(of: erro, matching: find.byType(Folha)), findsNothing);
      await _fechar(tester, app);
    });
  });

  group('Canteiro', () {
    testWidgets('alvos de toque: 96 nas capturas, 64 no mestre, 72 no Salvar',
        (tester) async {
      final app = await _abrir(tester, _novo);
      double altura(Finder f) => tester.getSize(f).height;
      Finder botaoDe(String texto) => find
          .ancestor(of: find.text(texto), matching: find.byType(InkWell))
          .first;

      expect(altura(botaoDe('Foto da nota')), greaterThanOrEqualTo(96));
      expect(altura(botaoDe('Falar o gasto')), greaterThanOrEqualTo(96));
      expect(altura(botaoDe('Salvar lançamento')), greaterThanOrEqualTo(72));
      expect(altura(botaoDe('Data do gasto')), greaterThanOrEqualTo(64));

      await _lerNota(tester);
      for (final rotulo in [
        'Tirar 2000 un Bloco de concreto do estoque',
        'Tirar a foto da nota do lançamento',
      ]) {
        final caixa = tester.getSize(find.byTooltip(rotulo));
        expect(caixa.height, greaterThanOrEqualTo(64), reason: rotulo);
        expect(caixa.width, greaterThanOrEqualTo(64), reason: rotulo);
      }
      await tester.scrollUntilVisible(
          find.text('Ver o texto lido da nota'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(altura(botaoDe('Ver o texto lido da nota')),
          greaterThanOrEqualTo(64));
      await _fechar(tester, app);
    });

    testWidgets('erro na escuta vibra (Tato.erro)', (tester) async {
      final vibracoes = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
        if (chamada.method == 'HapticFeedback.vibrate') {
          vibracoes.add('${chamada.arguments}');
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final app = await _abrir(tester, _novo);
      await tester.tap(find.text('Falar o gasto'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      await microfoneAberto(tester);
      vibracoes.clear();
      await _doAparelho(tester, 'notifyError',
          '{"errorMsg":"error_no_match","permanent":true}');
      await _doAparelho(tester, 'notifyStatus', 'done');
      await assentar(tester, total: const Duration(milliseconds: 600));
      expect(find.text('Tentar de novo'), findsOneWidget);
      // HapticFeedback.vibrate() é a vibração longa do Tato.erro.
      expect(vibracoes, ['null']);
      await _fechar(tester, app);
    });
  });

  group('Cabe em 360 dp com a fonte a 130%, sem quebrar palavra', () {
    testWidgets('data do recibo, foto da nota e rótulos do painel de voz',
        (tester) async {
      final app = await _abrir(tester, _novo,
          tela: const Size(360, 740), escalaTexto: 1.3, soATela: true);
      await _lerNota(tester);

      // "19/10/2026" numa linha só (antes saía "19/10/20" e "26").
      await tester.scrollUntilVisible(find.text('DATA'), 200,
          scrollable: find.byType(Scrollable).first);
      _numaLinhaSo(tester, find.textContaining('19/10/2026'), '19/10/2026');
      // ...e o fornecedor inteiro, sem "Construtor …".
      _numaLinhaSo(
          tester,
          find.descendant(
              of: find.byType(CelulaCarimbo),
              matching: find.text('Casa do Construtor Ltda')),
          'Construtor');
      await tester.scrollUntilVisible(find.text('Foto da nota').last, 200,
          scrollable: find.byType(Scrollable).first);
      _numaLinhaSo(
          tester, find.text('Vai junto com o lançamento.'), 'lançamento.');
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(find.text('Falar o gasto'), -200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Falar o gasto'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      await microfoneAberto(tester);
      await falaDoAparelho(
          tester,
          'comprei seis metros de areia média por mil duzentos e noventa '
          'reais no areial são jorge');
      await assentar(tester);
      final rolagem = find
          .descendant(
              of: find.byType(BottomSheet), matching: find.byType(Scrollable))
          .first;
      final fornecedor = find.descendant(
          of: find.byType(BottomSheet), matching: find.text('FORNECEDOR'));
      await tester.scrollUntilVisible(fornecedor, 200, scrollable: rolagem);
      _numaLinhaSo(tester, fornecedor, 'FORNECEDOR');
      expect(tester.takeException(), isNull);
      await _fechar(tester, app);
    });
  });
}

const _areia = 'comprei seis metros de areia média por mil duzentos e noventa '
    'reais no areial são jorge';

/// Fala a compra de areia e conclui: o recibo "Entendido da fala".
Future<void> _falarAreia(WidgetTester tester) async {
  await tester.tap(find.text('Falar o gasto'));
  await assentar(tester, total: const Duration(milliseconds: 600));
  await microfoneAberto(tester);
  await falaDoAparelho(tester, _areia, finalizou: true);
  await assentar(tester, total: const Duration(milliseconds: 600));
  await tester.tap(find.text('Concluir'));
  await assentar(tester);
}

/// Tira a foto da nota pela câmera (o cupom de visual/suporte).
Future<void> _lerNota(WidgetTester tester, {bool preparar = true}) async {
  if (preparar) await prepararNotaFalsa(tester);
  await tester.tap(find.text('Foto da nota').first);
  await assentar(tester, total: const Duration(milliseconds: 600));
  await tester.tap(find.text('Tirar foto da nota'));
  await assentar(tester);
}

/// O reconhecedor de voz manda um evento para o app.
Future<void> _doAparelho(
    WidgetTester tester, String metodo, Object argumento) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    canalVoz.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(metodo, argumento)),
    (_) {},
  );
  await tester.pump();
}

/// O [trecho] do texto em [texto] fica numa linha só (não foi quebrado no
/// meio da palavra) e inteiro (sem reticências).
void _numaLinhaSo(WidgetTester tester, Finder texto, String trecho) {
  final paragrafo = tester.renderObject<RenderParagraph>(
      find.descendant(of: texto, matching: find.byType(RichText)).first);
  final inteiro = paragrafo.text.toPlainText();
  final inicio = inteiro.indexOf(trecho);
  expect(inicio, isNot(-1), reason: '"$trecho" não está em "$inteiro"');
  final caixas = paragrafo.getBoxesForSelection(
      TextSelection(baseOffset: inicio, extentOffset: inicio + trecho.length));
  final linhas = caixas.map((c) => c.top.round()).toSet();
  expect(linhas, hasLength(1),
      reason: '"$trecho" quebrou em ${linhas.length} linhas');
  expect(paragrafo.didExceedMaxLines, isFalse,
      reason: '"$trecho" foi cortado com reticências');
}
