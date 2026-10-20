// Capturas do "depois" do Lançar gasto (novo lançamento), claro e escuro,
// e a fumaça do diário, que usa o mesmo painel de voz e os mesmos botões.
//
//   CAPTURAR=depois flutter test test/visual/depois_lancar_gasto_test.dart
//
// grava os PNG em docs/redesign/depois/. Sem CAPTURAR, os testes são
// pulados. Ver docs/redesign/LEIA-ME-capturas.md. Rode só este arquivo:
// a série do antes (capturas_test.dart) também roda com qualquer
// CAPTURAR e gravaria a cena 07 dela, no escuro, por cima da do depois.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/providers/auth_provider.dart';
import 'package:obra_facil/screens/lancamentos/novo_lancamento_screen.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';
import 'suporte/fakes.dart';
import 'suporte/fontes.dart';
import 'suporte/nota_falsa.dart';
import 'suporte/plataforma.dart';

const _obra = '/obras/${IdsExemplo.obra}';
const _novo = '$_obra/lancamentos/novo';

/// As mesmas falas das capturas do antes.
const _falaParcial = 'comprei seis metros de areia média por mil duzentos '
    'e noventa reais';
const _falaCompleta = '$_falaParcial no areial são jorge';

const _falaDiario = 'hoje choveu de manhã, trabalharam três pedreiros e '
    'dois serventes, terminamos o reboco da fachada';

Future<void> _abrirVoz(WidgetTester tester, String botao) async {
  await tester.tap(find.text(botao));
  await assentar(tester, total: const Duration(milliseconds: 600));
  await microfoneAberto(tester);
}

Future<void> _falarEConcluir(WidgetTester tester) async {
  await _abrirVoz(tester, 'Falar o gasto');
  await falaDoAparelho(tester, _falaParcial);
  await falaDoAparelho(tester, _falaCompleta, finalizou: true);
  await assentar(tester, total: const Duration(milliseconds: 600));
  await tester.tap(find.text('Concluir'));
}

/// Foto da nota pela câmera, com o cupom de suporte/nota_falsa.dart.
Future<void> _tirarFotoDaNota(
  WidgetTester tester, {
  Duration demora = const Duration(milliseconds: 300),
}) async {
  await prepararNotaFalsa(tester, demora: demora);
  await tester.tap(find.text('Foto da nota'));
  await assentar(tester, total: const Duration(milliseconds: 600));
  await tester.tap(find.text('Tirar foto da nota'));
}

/// A segunda foto: o leitor do aparelho falha (a primeira foi lida).
Future<void> _segundaFotoFalha(WidgetTester tester) async {
  await _tirarFotoDaNota(tester);
  await assentar(tester);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('google_mlkit_text_recognizer'),
    (chamada) async => chamada.method == 'vision#startTextRecognizer'
        ? throw PlatformException(code: 'falhou')
        : null,
  );
  await tester.tap(find.text('Foto da nota').first);
  await assentar(tester, total: const Duration(milliseconds: 600));
  await tester.tap(find.text('Tirar foto da nota'));
}

/// Celular estreito (360x780) com a fonte do sistema a 130%, só esta tela
/// na pilha (as telas de baixo têm os problemas delas nesse tamanho). O
/// harness de suporte/captura.dart só faz 390 pontos; este grava no mesmo
/// lugar, com as mesmas verificações (sem erro, sem fonte de teste).
void _capturarEstreita(
  String nome, {
  Brightness brilho = Brightness.light,
  required Future<void> Function(WidgetTester tester) acao,
}) {
  testWidgets('${nome}_360_130', (tester) async {
    debugDisableShadows = false;
    try {
      final view = tester.view;
      view.devicePixelRatio = pixelRatioCaptura;
      view.physicalSize = const Size(360, 780) * pixelRatioCaptura;
      const insets = FakeViewPadding(
        top: 24 * pixelRatioCaptura,
        bottom: 16 * pixelRatioCaptura,
      );
      view.padding = insets;
      view.viewPadding = insets;
      addTearDown(view.reset);
      tester.platformDispatcher.platformBrightnessTestValue = brilho;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      instalarPluginsFalsos();

      final auth = AuthProvider(AuthServiceFalso(UsuariosExemplo.mestre));
      final router = GoRouter(initialLocation: _novo, routes: [
        GoRoute(
          path: '/obras/:obraId/lancamentos/novo',
          builder: (_, estado) =>
              NovoLancamentoScreen(obraId: estado.pathParameters['obraId']!),
        ),
      ]);
      final moldura = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: moldura,
        child: AppDeCaptura(
          auth: auth,
          db: FirestoreFalso(DadosExemplo.padrao()),
          router: router,
        ),
      ));
      await assentar(tester);
      await acao(tester);
      await assentar(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(familiasNaoCarregadas(), isEmpty);
      await tester.runAsync(() async {
        final limite = moldura.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final imagem = await limite.toImage(pixelRatio: pixelRatioCaptura);
        final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
        imagem.dispose();
        final pasta = _pastaDaSerie()..createSync(recursive: true);
        File('${pasta.path}/${nome}_360_130.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 10));
      router.dispose();
      auth.dispose();
    } finally {
      debugDisableShadows = true;
    }
  }, skip: !capturando);
}

/// `docs/redesign/<serie>/`, subindo a partir da pasta do pacote.
Directory _pastaDaSerie() {
  var dir = Directory.current.absolute;
  while (!Directory('${dir.path}/docs/redesign').existsSync()) {
    if (dir.parent.path == dir.path) {
      throw StateError('docs/redesign/ não encontrado');
    }
    dir = dir.parent;
  }
  return Directory('${dir.path}/docs/redesign/$serieDeCaptura');
}

Future<void> _rolarAte(WidgetTester tester, Finder alvo) => tester
    .scrollUntilVisible(alvo, 200, scrollable: find.byType(Scrollable).first);

/// A cena no claro e no escuro (sufixo `_escuro`).
void _nosDoisTemas(
  String nome, {
  required String rota,
  UsuarioModel? usuario,
  Future<void> Function(WidgetTester tester)? acao,
}) {
  for (final brilho in Brightness.values) {
    capturarCena(Cena(
      brilho == Brightness.dark ? '${nome}_escuro' : nome,
      usuario: usuario ?? UsuariosExemplo.mestre,
      rota: rota,
      brilho: brilho,
      acao: acao,
    ));
  }
}

void main() {
  setUpAll(() async {
    if (capturando) await prepararCapturas();
  });

  _nosDoisTemas('07_novo_lancamento_mestre', rota: _novo);

  // Painel de voz aberto, ouvindo, com a interpretação ao vivo. No antes
  // os botões estouravam 8,4 pontos; aqui não pode haver erro nenhum.
  _nosDoisTemas(
    '08_novo_lancamento_voz_mestre',
    rota: _novo,
    acao: (tester) async {
      await _abrirVoz(tester, 'Falar o gasto');
      await falaDoAparelho(tester, _falaParcial);
    },
  );

  // Depois do "Concluir": o recibo do que foi entendido e o formulário.
  _nosDoisTemas(
    '09_novo_lancamento_voz_preenchido_mestre',
    rota: _novo,
    acao: _falarEConcluir,
  );

  // Extras (sem par no antes): "Salvar" sem nada preenchido mostra os
  // erros e rola até o primeiro; e o rodapé acima do teclado.
  _nosDoisTemas(
    '07b_novo_lancamento_erros_mestre',
    rota: _novo,
    acao: (tester) => tester.tap(find.text('Salvar lançamento')),
  );

  _nosDoisTemas(
    '07c_novo_lancamento_teclado_mestre',
    rota: _novo,
    acao: (tester) async {
      tester.view.viewInsets =
          FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
      await tester.tap(find.widgetWithText(TextFormField, 'Valor'));
    },
  );

  // Extras do caminho da foto: a escolha entre câmera e galeria, a nota
  // sendo lida (a varredura sobre a foto; o "OCR" demora 6 s de tempo
  // falso, mais que o tempo até a captura) e o recibo do que foi lido.
  _nosDoisTemas(
    '07d_novo_lancamento_escolha_foto_mestre',
    rota: _novo,
    acao: (tester) => tester.tap(find.text('Foto da nota')),
  );

  _nosDoisTemas(
    '07e_novo_lancamento_lendo_nota_mestre',
    rota: _novo,
    acao: (tester) =>
        _tirarFotoDaNota(tester, demora: const Duration(seconds: 6)),
  );

  _nosDoisTemas(
    '07f_novo_lancamento_nota_lida_mestre',
    rota: _novo,
    acao: _tirarFotoDaNota,
  );

  // Uma segunda foto que o leitor não consegue ler: o erro sai fora do
  // recibo (que continua o da primeira, como os campos), dito como erro.
  _nosDoisTemas(
    '07g_novo_lancamento_falha_leitura_mestre',
    rota: _novo,
    acao: _segundaFotoFalha,
  );

  // Celular estreito com a fonte grande (360 dp, 130%): o recibo empilha
  // fornecedor e data, nada quebra no meio da palavra nem some em "…".
  _capturarEstreita('07f_novo_lancamento_nota_lida_mestre', acao: (t) async {
    await _tirarFotoDaNota(t);
    await assentar(t);
    await _rolarAte(t, find.text('DATA'));
  });
  _capturarEstreita('08_novo_lancamento_voz_mestre', acao: (t) async {
    await _abrirVoz(t, 'Falar o gasto');
    await falaDoAparelho(t, _falaCompleta);
  });
  _capturarEstreita('09_novo_lancamento_voz_preenchido_mestre',
      brilho: Brightness.dark, acao: _falarEConcluir);

  // Fumaça do diário (ainda no tema antigo, só escuro): os mesmos
  // BotaoIa, AvisoIa e painel de voz, que leem context.cores e caem na
  // paleta escura padrão quando o tema não tem a extensão.
  capturarCena(Cena(
    'diario_registro_fumaca_mestre',
    usuario: UsuariosExemplo.mestre,
    rota: '$_obra/diario',
    acao: (tester) => tester.tap(find.text('Registrar dia')),
  ));

  capturarCena(Cena(
    'diario_voz_fumaca_mestre',
    usuario: UsuariosExemplo.mestre,
    rota: '$_obra/diario',
    acao: (tester) async {
      await tester.tap(find.text('Registrar dia'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      await _abrirVoz(tester, 'Ditar o dia');
      await falaDoAparelho(tester, _falaDiario);
    },
  ));

  capturarCena(Cena(
    'diario_voz_preenchido_fumaca_mestre',
    usuario: UsuariosExemplo.mestre,
    rota: '$_obra/diario',
    acao: (tester) async {
      await tester.tap(find.text('Registrar dia'));
      await assentar(tester, total: const Duration(milliseconds: 600));
      await _abrirVoz(tester, 'Ditar o dia');
      await falaDoAparelho(tester, _falaDiario, finalizou: true);
      await assentar(tester, total: const Duration(milliseconds: 600));
      await tester.tap(find.text('Concluir'));
    },
  ));
}
