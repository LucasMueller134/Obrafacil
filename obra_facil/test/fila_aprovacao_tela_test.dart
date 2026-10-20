// Fila de aprovação (/obras/:id/lancamentos): o que o redesenho promete.
//
// - O dono com pendentes abre em "Pendentes"; a rota ?filtro=pendentes
//   também; o mestre abre em "Todos".
// - Aprovar (botão, deslizar ou "Aprovar todos") vibra, tira o cartão da
//   fila e mostra o aviso com Desfazer; só grava quando o aviso fecha, e
//   grava as MESMAS chamadas de antes (moderarLancamento e, com itens,
//   aplicarLancamentoNoEstoque), na mesma ordem em cada gasto. No
//   "Aprovar todos", uma aprovação parada sem sinal não segura as outras;
//   só esperam umas pelas outras as que mexem no mesmo material.
// - Desfazer devolve o cartão e não grava nada.
// - Sair da tela (ou o app ir para o fundo) antes dos 4 s grava na hora.
// - Recusar continua imediato, com o diálogo do motivo.
// - Em 360 dp com fonte 130%, nada estoura (com foto da nota), nenhuma
//   palavra quebra no meio e o filtro não perde o número.
// - Alvos de toque, leitor de tela e "reduzir animações".
//
// Usa o app de verdade (router, AuthProvider) com o Firestore falso das
// capturas, que registra as escritas em `FirestoreFalso.escritas`.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:obra_facil/design/design.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/router/app_router.dart';

import 'visual/suporte/captura.dart';
import 'visual/suporte/dados_exemplo.dart';
import 'visual/suporte/fakes.dart';
import 'visual/suporte/plataforma.dart';

const _fila = '/obras/${IdsExemplo.obra}/lancamentos';

class _App {
  _App(this.db, this.auth, this.router);

  final FirestoreFalso db;
  final AuthProvider auth;
  final GoRouter router;

  /// Só as escritas da moderação e do estoque, na ordem.
  List<String> get gravado => db.escritas
      .where((e) =>
          e.startsWith('moderarLancamento') ||
          e.startsWith('aplicarLancamentoNoEstoque') ||
          e.startsWith('excluirLancamento'))
      .toList();
}

/// Abre o app como no main.dart, numa tela de celular, e vai para [rota].
Future<_App> _abrir(
  WidgetTester tester,
  UsuarioModel usuario,
  String rota, {
  DadosExemplo? dados,
  FirestoreFalso? banco,
  Size tela = const Size(390, 844),
  double fonte = 1,
}) async {
  final view = tester.view
    ..devicePixelRatio = 2
    ..physicalSize = tela * 2;
  addTearDown(view.reset);
  if (fonte != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = fonte;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  instalarPluginsFalsos();
  final db = banco ?? FirestoreFalso(dados ?? DadosExemplo.padrao());
  final auth = AuthProvider(AuthServiceFalso(usuario));
  final router = criarRouter(auth);
  await tester.pumpWidget(AppDeCaptura(auth: auth, db: db, router: router));
  await assentar(tester);
  // A lista de obras (/obras, outra tela, ainda no visual antigo) estoura
  // em 360 dp com fonte 130%; aqui só a fila conta. Coberta pela fila, ela
  // não é mais montada.
  tester.takeException();
  router.go(rota);
  await assentar(tester);
  expect(router.routerDelegate.currentConfiguration.uri.toString(), rota);
  return _App(db, auth, router);
}

Future<void> _fechar(WidgetTester tester, _App app) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  app.router.dispose();
  app.auth.dispose();
}

/// Grava as vibrações pedidas ao sistema.
List<String> _gravarVibracoes(WidgetTester tester) {
  final vibracoes = <String>[];
  final mensageiro = tester.binding.defaultBinaryMessenger;
  mensageiro.setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
    if (chamada.method == 'HapticFeedback.vibrate') {
      vibracoes.add('${chamada.arguments}');
    }
    return null;
  });
  addTearDown(
      () => mensageiro.setMockMethodCallHandler(SystemChannels.platform, null));
  return vibracoes;
}

/// O sistema avisa que o app mudou de estado (como o Android faz): o
/// binding gera as transições do meio (resumed → inactive → hidden).
Future<void> _cicloDoApp(WidgetTester tester, AppLifecycleState estado) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(estado.toString()),
      (_) {},
    );

Finder get _botoesAprovar => find.widgetWithText(BotaoPrincipal, 'Aprovar');

/// [primeira] foi gravada antes de [segunda].
void _antesDe(List<String> gravado, String primeira, String segunda) {
  expect(gravado, containsAll([primeira, segunda]));
  expect(gravado.indexOf(primeira), lessThan(gravado.indexOf(segunda)),
      reason: '$primeira deveria vir antes de $segunda em $gravado');
}

/// Onde começa cada linha do parágrafo, da segunda em diante (o
/// caractere que desceu para uma linha nova).
List<int> _inicioDasLinhas(RenderParagraph p, String texto) {
  // Linha nova: a caixa do caractere começa abaixo do pé da anterior
  // (comparar só o topo confundiria os centavos menores do valor).
  final inicios = <int>[];
  double? peAnterior;
  for (var i = 0; i < texto.length; i++) {
    final caixas = p.getBoxesForSelection(
        TextSelection(baseOffset: i, extentOffset: i + 1));
    if (caixas.isEmpty) continue;
    final caixa = caixas.first;
    if (peAnterior != null && caixa.top >= peAnterior - 1) inicios.add(i);
    peAnterior = caixa.bottom;
  }
  return inicios;
}

/// Palavras que a quebra de linha cortou no meio ("Aprov / ar") e opções
/// do filtro que perderam texto nas reticências ("Pendentes…"). O teste
/// de overflow não pega nenhum dos dois.
List<String> _textosCortados(WidgetTester tester) {
  bool separa(String c) =>
      c.trim().isEmpty || c == '\uFFFC' || '-–/·'.contains(c);
  final cortes = <String>[];
  for (final elemento in find.byType(RichText).evaluate()) {
    final p = elemento.renderObject! as RenderParagraph;
    if (!p.hasSize || p.didExceedMaxLines) continue;
    final texto = p.text.toPlainText();
    for (final i in _inicioDasLinhas(p, texto)) {
      if (!separa(texto[i - 1]) && !separa(texto[i])) {
        cortes.add('"$texto" quebrou no meio da palavra');
        break;
      }
    }
  }
  final opcoes = find.descendant(
    of: find.byWidgetPredicate((w) => w is SeletorGrande),
    matching: find.byType(RichText),
  );
  for (final elemento in opcoes.evaluate()) {
    final p = elemento.renderObject! as RenderParagraph;
    if (p.didExceedMaxLines) {
      cortes.add('opção "${p.text.toPlainText()}" cortada');
    }
  }
  return cortes;
}

/// O Firestore sem sinal para um lançamento: a escrita fica registrada
/// (no aparelho), mas o Future dela nunca termina.
class _FirestoreSemSinal extends FirestoreFalso {
  _FirestoreSemSinal(super.dados, {required this.parado});

  final String parado;
  final Completer<void> _nunca = Completer<void>();

  @override
  Future<void> moderarLancamento({
    required LancamentoModel lancamento,
    required bool aprovar,
    required String donoId,
    String? motivoRejeicao,
  }) {
    final gravou = super.moderarLancamento(
      lancamento: lancamento,
      aprovar: aprovar,
      donoId: donoId,
      motivoRejeicao: motivoRejeicao,
    );
    return lancamento.id == parado
        ? gravou.then((_) => _nunca.future)
        : gravou;
  }
}

/// O seletor de filtro está em [rotulo]?
bool _filtroEm(WidgetTester tester, String rotulo) {
  final seletor = tester.widget<SeletorGrande<Object?>>(
    find.byWidgetPredicate((w) => w is SeletorGrande),
  );
  final escolhida =
      seletor.opcoes.firstWhere((o) => o.valor == seletor.selecionado);
  return escolhida.rotulo == rotulo;
}

/// Uma foto de nota de mentira, como o app grava (data URI).
String _fotoDaNota() {
  final imagem = img.Image(width: 300, height: 400);
  img.fill(imagem, color: img.ColorRgb8(250, 248, 240));
  for (var y = 40; y < 360; y += 24) {
    img.drawLine(imagem,
        x1: 30, y1: y, x2: 270, y2: y, color: img.ColorRgb8(40, 40, 40));
  }
  return 'data:image/png;base64,${base64Encode(img.encodePng(imagem))}';
}

void main() {
  setUpAll(prepararCapturas);

  group('filtro inicial', () {
    testWidgets('dono com pendentes abre em Pendentes, com os cartões',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);
      expect(_filtroEm(tester, '3 pendentes'), isTrue);
      expect(find.text('3 gastos para aprovar'.toUpperCase()), findsOneWidget);
      expect(find.text('Aprovar todos'), findsOneWidget);
      expect(_botoesAprovar, findsWidgets);
      // O aprovado não aparece em Pendentes.
      expect(find.text('Argamassa e cal para assentamento'), findsNothing);
      await _fechar(tester, app);
    });

    testWidgets('a rota ?filtro=pendentes abre em Pendentes', (tester) async {
      final app = await _abrir(
          tester, UsuariosExemplo.mestre, '$_fila?filtro=pendentes');
      expect(_filtroEm(tester, '3 pendentes'), isTrue);
      // O mestre vê os pendentes, mas não decide.
      expect(_botoesAprovar, findsNothing);
      expect(find.text('Bloco cerâmico 9 furos'), findsOneWidget);
      await _fechar(tester, app);
    });

    testWidgets('mestre sem filtro na rota abre em Todos', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.mestre, _fila);
      expect(_filtroEm(tester, 'Todos'), isTrue);
      expect(_botoesAprovar, findsNothing);
      expect(find.text('Lançar gasto'), findsOneWidget);
      await _fechar(tester, app);
    });
  });

  group('aprovar com desfazer', () {
    testWidgets('o cartão sai na hora, vibra, e só grava quando o aviso fecha',
        (tester) async {
      final vibracoes = _gravarVibracoes(tester);
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);

      await tester.tap(_botoesAprovar.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(vibracoes, contains('HapticFeedbackType.mediumImpact'));
      expect(find.text('Aprovado'), findsOneWidget);
      expect(find.text('Desfazer'), findsOneWidget);
      expect(_filtroEm(tester, '2 pendentes'), isTrue);
      expect(find.text('Bloco cerâmico 9 furos'), findsNothing);
      // Ainda no desfazer: nada gravado.
      expect(app.gravado, isEmpty);

      await assentar(tester, total: const Duration(seconds: 5));
      expect(find.text('Desfazer'), findsNothing);
      // As mesmas chamadas de antes, na mesma ordem.
      expect(app.gravado, [
        'moderarLancamento l18 true',
        'aplicarLancamentoNoEstoque l18',
      ]);
      await _fechar(tester, app);
    });

    testWidgets('Desfazer devolve o cartão e não grava nada', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);

      await tester.tap(_botoesAprovar.first);
      await assentar(tester, total: const Duration(milliseconds: 600));
      expect(find.text('Bloco cerâmico 9 furos'), findsNothing);

      await tester.tap(find.text('Desfazer'));
      await assentar(tester, total: const Duration(seconds: 1));
      expect(find.text('Bloco cerâmico 9 furos'), findsOneWidget);
      expect(_filtroEm(tester, '3 pendentes'), isTrue);

      await assentar(tester, total: const Duration(seconds: 6));
      expect(app.gravado, isEmpty);
      await _fechar(tester, app);
    });

    testWidgets('Aprovar todos: um aviso, e as chamadas de antes em cada gasto',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);

      await tester.tap(find.text('Aprovar todos'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      expect(find.text('3 aprovados'), findsOneWidget);
      expect(find.text('Nada para aprovar'), findsOneWidget);
      expect(app.gravado, isEmpty);

      await assentar(tester, total: const Duration(seconds: 5));
      expect(
        app.gravado,
        unorderedEquals([
          'moderarLancamento l18 true',
          'aplicarLancamentoNoEstoque l18',
          'moderarLancamento l19 true',
          'aplicarLancamentoNoEstoque l19',
          // Sem itens: sem estoque, como antes.
          'moderarLancamento l20 true',
        ]),
      );
      // Em cada gasto, a ordem da _aprovar: aprova e depois o estoque.
      _antesDe(app.gravado, 'moderarLancamento l18 true',
          'aplicarLancamentoNoEstoque l18');
      _antesDe(app.gravado, 'moderarLancamento l19 true',
          'aplicarLancamentoNoEstoque l19');
      await _fechar(tester, app);
    });

    testWidgets('sem sinal, uma aprovação parada não segura as outras',
        (tester) async {
      // A escrita da l18 fica no aparelho, mas o servidor não responde: o
      // await dela não termina (é o que o Firestore faz sem sinal).
      final banco = _FirestoreSemSinal(DadosExemplo.padrao(), parado: 'l18');
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila,
          banco: banco);

      await tester.tap(find.text('Aprovar todos'));
      await assentar(tester, total: const Duration(seconds: 5));
      // As três aprovações foram pedidas ao Firestore (ficam gravadas no
      // aparelho e sobem quando o sinal voltar); só o estoque da parada
      // espera, como na _aprovar de sempre.
      expect(
        app.gravado,
        unorderedEquals([
          'moderarLancamento l18 true',
          'moderarLancamento l19 true',
          'aplicarLancamentoNoEstoque l19',
          'moderarLancamento l20 true',
        ]),
      );
      await _fechar(tester, app);
    });

    testWidgets('dois gastos do mesmo material: o segundo espera o primeiro',
        (tester) async {
      // A entrada no estoque lê e soma: duas juntas no mesmo material
      // perderiam uma entrada.
      final dados = DadosExemplo.padrao();
      final lista = dados.lancamentos[IdsExemplo.obra]!;
      final i = lista.indexWhere((l) => l.id == 'l19');
      lista[i] = lista[i].copyWith(itens: const [
        ItemMaterialModel(
            material: 'Bloco cerâmico 9 furos', quantidade: 500, unidade: 'un'),
      ]);
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila,
          dados: dados);

      await tester.tap(find.text('Aprovar todos'));
      await assentar(tester, total: const Duration(seconds: 5));
      expect(app.gravado, hasLength(5));
      _antesDe(app.gravado, 'aplicarLancamentoNoEstoque l18',
          'moderarLancamento l19 true');
      _antesDe(app.gravado, 'moderarLancamento l19 true',
          'aplicarLancamentoNoEstoque l19');
      // O que não divide material não espera.
      _antesDe(app.gravado, 'moderarLancamento l20 true',
          'aplicarLancamentoNoEstoque l18');
      await _fechar(tester, app);
    });

    testWidgets('aprovar outro antes de o aviso fechar grava o primeiro',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);

      await tester.tap(_botoesAprovar.first);
      await assentar(tester, total: const Duration(milliseconds: 600));
      await tester.tap(_botoesAprovar.first);
      // O aviso novo entra no lugar do antigo: o antigo fecha sem
      // desfazer e grava.
      await assentar(tester, total: const Duration(seconds: 1));
      expect(app.gravado, [
        'moderarLancamento l18 true',
        'aplicarLancamentoNoEstoque l18',
      ]);
      await assentar(tester, total: const Duration(seconds: 5));
      expect(app.gravado, [
        'moderarLancamento l18 true',
        'aplicarLancamentoNoEstoque l18',
        'moderarLancamento l19 true',
        'aplicarLancamentoNoEstoque l19',
      ]);
      await _fechar(tester, app);
    });

    testWidgets('sair da tela antes dos 4 s grava na hora e tira o aviso',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);

      await tester.tap(_botoesAprovar.first);
      await assentar(tester, total: const Duration(milliseconds: 500));
      expect(app.gravado, isEmpty);

      app.router.pop();
      await assentar(tester, total: const Duration(seconds: 1));
      expect(app.router.routerDelegate.currentConfiguration.uri.toString(),
          '/obras/${IdsExemplo.obra}');
      // 1,5 s depois de aprovar: o aviso ainda estaria correndo.
      expect(app.gravado, [
        'moderarLancamento l18 true',
        'aplicarLancamentoNoEstoque l18',
      ]);
      expect(find.text('Desfazer'), findsNothing);

      // E não grava de novo quando o tempo do aviso acabaria.
      await assentar(tester, total: const Duration(seconds: 5));
      expect(app.gravado, hasLength(2));
      await _fechar(tester, app);
    });

    testWidgets('o app ir para o fundo grava na hora', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);
      addTearDown(() => _cicloDoApp(tester, AppLifecycleState.resumed));

      await tester.tap(_botoesAprovar.first);
      await assentar(tester, total: const Duration(milliseconds: 500));
      await _cicloDoApp(tester, AppLifecycleState.hidden);
      await assentar(tester, total: const Duration(milliseconds: 500));
      expect(app.gravado, [
        'moderarLancamento l18 true',
        'aplicarLancamentoNoEstoque l18',
      ]);
      await _fechar(tester, app);
    });

    testWidgets('deslizar para a direita aprova, com o mesmo desfazer',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);

      await tester.drag(find.text('Bloco cerâmico 9 furos'),
          const Offset(320, 0));
      await assentar(tester, total: const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Aprovado'), findsOneWidget);
      expect(find.text('Bloco cerâmico 9 furos'), findsNothing);
      expect(app.gravado, isEmpty);

      // Desfazer devolve o cartão (e o Dismissible novo funciona).
      await tester.tap(find.text('Desfazer'));
      await assentar(tester, total: const Duration(seconds: 1));
      expect(find.text('Bloco cerâmico 9 furos'), findsOneWidget);
      await assentar(tester, total: const Duration(seconds: 6));
      expect(app.gravado, isEmpty);
      expect(tester.takeException(), isNull);
      await _fechar(tester, app);
    });
  });

  group('recusar e excluir', () {
    testWidgets('Recusar abre o motivo e grava na hora', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);

      await tester
          .tap(find.widgetWithText(BotaoContorno, 'Recusar').first);
      await assentar(tester, total: const Duration(milliseconds: 600));
      expect(find.text('Recusar gasto'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Valor não confere');
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Recusar'),
      ));
      await assentar(tester, total: const Duration(milliseconds: 600));
      expect(app.gravado, ['moderarLancamento l18 false']);
      await _fechar(tester, app);
    });

    testWidgets('cancelar o motivo não grava', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);
      await tester.drag(
          find.text('Bloco cerâmico 9 furos'), const Offset(-320, 0));
      await assentar(tester, total: const Duration(milliseconds: 800));
      expect(find.text('Recusar gasto'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await assentar(tester, total: const Duration(seconds: 1));
      // O cartão volta para o lugar.
      expect(find.text('Bloco cerâmico 9 furos'), findsOneWidget);
      expect(app.gravado, isEmpty);
      await _fechar(tester, app);
    });

    testWidgets('o mestre exclui o próprio pendente, com desfazer',
        (tester) async {
      final app = await _abrir(
          tester, UsuariosExemplo.mestre, '$_fila?filtro=pendentes');
      await tester.tap(find.text('Areia média'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      await tester.tap(find.text('Excluir lançamento'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      expect(find.text('Lançamento excluído'), findsOneWidget);
      expect(find.text('Areia média'), findsNothing);
      expect(app.gravado, isEmpty);
      await assentar(tester, total: const Duration(seconds: 5));
      expect(app.gravado, ['excluirLancamento l19']);
      await _fechar(tester, app);
    });
  });

  group('cabe em 360 dp com fonte 130%', () {
    DadosExemplo comFoto() {
      final dados = DadosExemplo.padrao();
      final lista = dados.lancamentos[IdsExemplo.obra]!;
      final i = lista.indexWhere((l) => l.id == 'l18');
      lista[i] = lista[i].copyWith(fotoNotaUrl: _fotoDaNota());
      return dados;
    }

    for (final (nome, usuario, rota) in [
      ('fila do dono', UsuariosExemplo.dono, _fila),
      ('todos do dono', UsuariosExemplo.dono, '$_fila?filtro=todos'),
      ('todos do mestre', UsuariosExemplo.mestre, _fila),
      ('recusados', UsuariosExemplo.dono, '$_fila?filtro=recusados'),
    ]) {
      testWidgets(nome, (tester) async {
        final app = await _abrir(tester, usuario, rota,
            dados: comFoto(),
            tela: const Size(360, 640),
            fonte: 1.3);
        expect(tester.takeException(), isNull);
        // Rola até o fim: tudo é montado e medido.
        final lista = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        final posicao = tester.state<ScrollableState>(lista.first).position;
        // E desce de meia em meia tela: em cada trecho, nenhuma palavra
        // cortada (o filtro, os botões do cartão, as linhas).
        expect(_textosCortados(tester), isEmpty);
        for (var y = 0.0; y < posicao.maxScrollExtent + 320; y += 320) {
          posicao.jumpTo(y.clamp(0, posicao.maxScrollExtent));
          await tester.pump();
          expect(_textosCortados(tester), isEmpty, reason: 'rolagem $y');
        }
        for (var i = 0; i < 10; i++) {
          final fim = posicao.maxScrollExtent;
          posicao.jumpTo(fim);
          await tester.pump();
          if (posicao.maxScrollExtent == fim) break;
        }
        expect(tester.takeException(), isNull);
        await _fechar(tester, app);
      });
    }

    testWidgets('a data da linha nunca some atrás do fornecedor',
        (tester) async {
      final app = await _abrir(
          tester, UsuariosExemplo.dono, '$_fila?filtro=recusados',
          tela: const Size(360, 640), fonte: 1.3);
      // "Casa do Construtor" quebra em duas linhas nessa largura; o apoio
      // tem duas, então a data vem primeiro.
      final apoio = tester.renderObject<RenderParagraph>(find.descendant(
        of: find.byType(LinhaLista),
        matching: find.textContaining('07/10'),
      ));
      final texto = apoio.text.toPlainText();
      final segunda = _inicioDasLinhas(apoio, texto).first;
      expect(texto.substring(0, segunda).trim(), '07/10');
      await _fechar(tester, app);
    });

    testWidgets('folha de detalhe com a foto da nota', (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila,
          dados: comFoto(), tela: const Size(360, 640), fonte: 1.3);
      // Em 360 x 640 o cartão começa abaixo do rodapé: rola até ele.
      await tester.ensureVisible(find.text('Bloco cerâmico 9 furos'));
      await tester.pump();
      await tester.tap(find.text('Bloco cerâmico 9 furos'));
      await assentar(tester, total: const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      expect(find.text('Entra no estoque ao aprovar'.toUpperCase()),
          findsOneWidget);
      // As ações ficam à vista, fora da rolagem.
      final aprovar = find.descendant(
        of: find.byType(BottomSheet),
        matching: _botoesAprovar,
      );
      expect(aprovar, findsOneWidget);
      expect(tester.getRect(aprovar).bottom, lessThanOrEqualTo(640));
      // Sem largura para os dois lado a lado: um embaixo do outro, sem
      // cortar "Aprovar" e "Recusar" no meio.
      expect(_textosCortados(tester), isEmpty);
      final recusar = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(BotaoContorno, 'Recusar'),
      );
      expect(tester.getRect(recusar).top,
          greaterThan(tester.getRect(aprovar).bottom));
      expect(tester.getRect(recusar).bottom, lessThanOrEqualTo(640));
      await _fechar(tester, app);
    });
  });

  group('canteiro', () {
    testWidgets('alvos de toque: 64 dp nas decisões, 72 na ação principal',
        (tester) async {
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);
      double altura(Finder f) => tester.getSize(f.first).height;
      // No cartão, Aprovar e Recusar lado a lado em 390 dp.
      final aprovar = _botoesAprovar.first;
      final recusar = find.widgetWithText(BotaoContorno, 'Recusar').first;
      expect(tester.getRect(aprovar).top, tester.getRect(recusar).top);
      expect(altura(aprovar), greaterThanOrEqualTo(Alvo.mestre));
      expect(altura(recusar), greaterThanOrEqualTo(Alvo.mestre));
      expect(
          tester.getRect(recusar).left - tester.getRect(aprovar).right,
          greaterThanOrEqualTo(Espaco.entreAlvos));
      expect(altura(find.widgetWithText(BotaoContorno, 'Aprovar todos')),
          greaterThanOrEqualTo(Alvo.mestre));
      expect(altura(find.widgetWithText(BotaoMarca, 'Lançar gasto')),
          greaterThanOrEqualTo(Alvo.principal));
      expect(altura(find.byWidgetPredicate((w) => w is SeletorGrande)),
          greaterThanOrEqualTo(2 * Alvo.opcao));

      await tester.tap(find.text('Bloco cerâmico 9 furos'));
      await assentar(tester, total: const Duration(milliseconds: 800));
      final naFolha = find.descendant(
          of: find.byType(BottomSheet), matching: _botoesAprovar);
      expect(altura(naFolha), greaterThanOrEqualTo(Alvo.principal));
      await _fechar(tester, app);
    });

    testWidgets('o leitor de tela ouve o status do cartão e as decisões',
        (tester) async {
      final semantica = tester.ensureSemantics();
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);
      expect(
        find.bySemanticsLabel(RegExp(
            r'^Bloco cerâmico 9 furos, pendente, R\$\s2\.380,00, '
            r'Casa do Construtor · 14/10, foto da nota')),
        findsOneWidget,
      );
      // O deslize tem botão equivalente em cada cartão.
      expect(find.bySemanticsLabel('Aprovar'), findsWidgets);
      expect(find.bySemanticsLabel('Recusar'), findsWidgets);
      await _fechar(tester, app);
      semantica.dispose();
    });

    testWidgets('com "reduzir animações", o cartão sai na hora',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final app = await _abrir(tester, UsuariosExemplo.dono, _fila);

      await tester.tap(_botoesAprovar.first);
      await tester.pump();
      await tester.pump();
      expect(find.text('Bloco cerâmico 9 furos'), findsNothing);

      // Pelo deslize também: solto além do limite, sai sem correr nem
      // encolher (sem avançar o relógio).
      await tester.timedDrag(find.text('Areia média'), const Offset(300, 0),
          const Duration(seconds: 1));
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      expect(find.text('Areia média'), findsNothing);
      expect(find.text('Aprovado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await assentar(tester, total: const Duration(seconds: 5));
      await _fechar(tester, app);
    });
  });
}
