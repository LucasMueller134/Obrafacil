// O caminho do tempo real da MaqueteObra (entrada do 3D por cima da imagem,
// medição dos quadros, corte por lentidão, giro, avanço e tema), com uma
// cena falsa no lugar da CenaMaquete: sem Impeller não dá para criar nem a
// `Scene` do flutter_scene. O que a cena de verdade faz com isso (SceneView,
// nós, materiais) só um aparelho mostra; ver cena_glb_test.dart para o que
// dá para conferir do modelo sem GPU.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/cena_maquete.dart';
import 'package:obra_facil/design/maquete/maquete.dart';
import 'package:obra_facil/design/maquete/medidor_quadros.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chaveVista = ValueKey('cena-falsa');

class _CenaFalsa implements Cena3dMaquete {
  final temas = <TemaMaquete>[];
  final planos = <PlanoMaquete>[];
  VoidCallback? aoDesenhar;
  void Function(Object erro)? aoFalhar;
  double? giro;
  double? proporcao;
  int vistas = 0;
  bool descartada = false;

  /// A vista simula a CenaMaquete quando o renderViews lança: avisa no
  /// meio da pintura (a exceção em si fica presa na cena).
  bool falharAoPintar = false;

  @override
  void aplicarTema(TemaMaquete tema) => temas.add(tema);

  @override
  void aplicar(PlanoMaquete plano) => planos.add(plano);

  @override
  Widget vista({
    required double proporcao,
    required double giro,
    required VoidCallback aoDesenhar,
    required void Function(Object erro) aoFalhar,
  }) {
    this.proporcao = proporcao;
    this.giro = giro;
    this.aoDesenhar = aoDesenhar;
    this.aoFalhar = aoFalhar;
    vistas++;
    if (falharAoPintar) {
      return CustomPaint(
        key: _chaveVista,
        size: Size.infinite,
        painter: _PintorQueFalha(
          () => aoFalhar(StateError('pipeline recusado pelo driver')),
        ),
      );
    }
    return const ColoredBox(key: _chaveVista, color: Color(0xFF00AA00));
  }

  @override
  (double, int)? get ultimoQuadro => (1.5, 42);

  @override
  void descartar() => descartada = true;
}

class _PintorQueFalha extends CustomPainter {
  _PintorQueFalha(this.aoPintar);

  final VoidCallback aoPintar;

  @override
  void paint(Canvas canvas, Size size) => aoPintar();

  @override
  bool shouldRepaint(_PintorQueFalha antigo) => false;
}

Widget _app(
  Widget filho, {
  Brightness brilho = Brightness.light,
  bool reduzir = false,
  bool tickers = true,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brilho),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduzir),
        child: Scaffold(
          // tickers: false é o que o Overlay faz com a rota encoberta.
          body: TickerMode(
            enabled: tickers,
            child: Center(child: SizedBox(width: 390, child: filho)),
          ),
        ),
      ),
    ),
  );
}

Finder _imagem(int estado, {bool escuro = false}) => find.byKey(
      MaqueteObra.chaveImagem(
        MaqueteObra.caminhoReserva(estado: estado, escuro: escuro),
      ),
    );

bool _relogio(WidgetTester tester) =>
    TickerMode.valuesOf(tester.element(find.byKey(_chaveVista))).enabled;

double _opacidade3d(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find
        .ancestor(
            of: find.byKey(_chaveVista), matching: find.byType(AnimatedOpacity))
        .first)
    .opacity;

/// O primeiro quadro desenhado da cena (o SceneView chama depois do
/// aquecimento).
Future<void> _desenhar(WidgetTester tester, _CenaFalsa cena) async {
  cena.aoDesenhar!();
  await tester.pump();
}

/// Deixa terminar a entrada do 3D (o ticker da animação só dá o primeiro
/// passo no quadro seguinte, e a animação só termina depois da duração).
Future<void> _esperarTroca(WidgetTester tester) async {
  await tester.pump();
  await tester
      .pump(MaqueteObra.duracaoTroca + const Duration(milliseconds: 16));
  await tester.pump();
}

/// Passa o app pelos estados do ciclo de vida, um a um, como o sistema.
void _ciclo(WidgetTester tester, List<AppLifecycleState> estados) {
  for (final e in estados) {
    tester.binding.handleAppLifecycleStateChanged(e);
  }
}

/// Entrega [n] tempos de quadro ao motor de mentira, como o engine faz em
/// lote, todos depois do quadro atual. Com [numero], os quadros são
/// numerados a partir dele (como o motor numera os de verdade).
void _quadros(WidgetTester tester, int n, {double ms = 8, int? numero}) {
  final inicio =
      SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
  final dur = (ms * 1000).round();
  tester.binding.platformDispatcher.onReportTimings!([
    for (var i = 0; i < n; i++)
      ui.FrameTiming(
        vsyncStart: inicio + 1000 + i * 16667,
        buildStart: inicio + 1000 + i * 16667,
        buildFinish: inicio + 1000 + i * 16667 + 2000,
        rasterStart: inicio + 1000 + i * 16667 + 2000,
        rasterFinish: inicio + 1000 + i * 16667 + 2000 + dur,
        rasterFinishWallTime: inicio + 1000 + i * 16667 + 2000 + dur,
        frameNumber: numero == null ? -1 : numero + i,
      ),
  ]);
}

void main() {
  late _CenaFalsa cena;
  late int cargas;
  late ValueNotifier<DiagnosticoMaquete> diag;

  setUp(() {
    MaqueteObra.reiniciarParaTeste();
    SharedPreferences.setMockInitialValues({});
    cargas = 0;
    cena = _CenaFalsa();
    diag = ValueNotifier(const DiagnosticoMaquete());
    MaqueteObra.carregadorDeCena = ({required tema}) async {
      cargas++;
      return cena;
    };
  });
  tearDown(MaqueteObra.reiniciarParaTeste);

  Future<void> montar(
    WidgetTester tester, {
    ProgressoMaquete? progresso,
    bool? cortar,
    bool interativa = true,
    Brightness brilho = Brightness.light,
  }) async {
    await tester.pumpWidget(_app(
      MaqueteObra(
        progresso: progresso ?? ProgressoMaquete.estado(3),
        cortarPorDesempenho: cortar,
        interativa: interativa,
        diagnostico: diag,
      ),
      brilho: brilho,
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('carrega por baixo da imagem, entra por cima e a imagem sai',
      (tester) async {
    final progresso = ProgressoMaquete.fases([1, 1, 1, 0.4]);
    await montar(tester, progresso: progresso);

    expect(cargas, 1);
    expect(diag.value.modo, ModoMaquete.tempoReal);
    expect(diag.value.revelada, isFalse);
    // A cena já recebeu o tema e o plano do avanço.
    expect(cena.temas.last, same(TemaMaquete.claro));
    expect(cena.planos.last.pecas,
        PlanoMaquete.calcular(progresso.avancoPorFase).pecas);
    expect(cena.planos.last.fantasmas,
        PlanoMaquete.calcular(progresso.avancoPorFase).fantasmas);
    // Câmera casada com a caixa (390 x 220).
    expect(cena.proporcao, closeTo(390 / 220, 1e-9));
    // Enquanto aquece: imagem na tela, 3D transparente, relógio ligado.
    expect(_imagem(3), findsOneWidget);
    expect(_opacidade3d(tester), 0);
    expect(_relogio(tester), isTrue);

    await _desenhar(tester, cena);
    expect(diag.value.revelada, isTrue);
    expect(_opacidade3d(tester), 1);
    expect(_imagem(3), findsOneWidget, reason: 'esmaecendo por baixo');

    await _esperarTroca(tester);
    expect(_imagem(3), findsNothing, reason: 'a imagem sai depois da troca');
    expect(find.byKey(_chaveVista), findsOneWidget);
  });

  testWidgets('mede os primeiros quadros e para o relógio', (tester) async {
    await montar(tester);
    await _desenhar(tester, cena);
    _quadros(tester, 50);
    await tester.pump();
    expect(diag.value.quadrosMedidos, 47, reason: '3 descartados');
    expect(diag.value.medicaoConcluida, isFalse);
    expect(_relogio(tester), isTrue);

    _quadros(tester, 43, ms: 9);
    await tester.pump();
    expect(diag.value.medicaoConcluida, isTrue);
    expect(diag.value.quadrosMedidos, 90);
    expect(diag.value.medicao!.p90Ms, 9);
    expect(diag.value.modo, ModoMaquete.tempoReal);
    // Sem giro automático: depois da medição a cena só redesenha quando
    // algo muda.
    expect(_relogio(tester), isFalse);
    expect(diag.value.cpuCenaMs, 1.5);
    expect(diag.value.chamadasDeDesenho, 42);

    // Quadros de depois entram na janela recente (painel).
    _quadros(tester, 10, ms: 12);
    await tester.pump();
    expect(diag.value.recente!.quadros, greaterThan(90));
  });

  testWidgets('quadros lentos: troca para a imagem e guarda a decisão',
      (tester) async {
    await montar(tester, cortar: true);
    await _desenhar(tester, cena);
    await _esperarTroca(tester);
    expect(_imagem(3), findsNothing);

    _quadros(tester, 93, ms: 30);
    await tester.pump();
    expect(diag.value.modo, ModoMaquete.imagem);
    expect(diag.value.motivo, MotivoMaquete.quadrosLentos);
    expect(diag.value.detalhe, 'p90 30.0 ms > 20 ms');
    expect(diag.value.medicao!.p90Ms, 30, reason: 'a medição fica no painel');
    expect(find.byKey(_chaveVista), findsNothing);
    expect(_imagem(3), findsOneWidget);
    await tester.pump();
    expect(cena.descartada, isTrue, reason: 'a cena é solta depois do quadro');

    final guardado = await tester.runAsync(DecisaoDesempenho.ler);
    expect(guardado, 30);

    // A próxima maquete já abre na imagem, sem carregar o 3D.
    await tester.pumpWidget(_app(MaqueteObra(
      key: UniqueKey(),
      progresso: ProgressoMaquete.estado(3),
      cortarPorDesempenho: true,
      diagnostico: diag,
    )));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(diag.value.motivo, MotivoMaquete.decisaoGuardada);
    expect(cargas, 1);
  });

  testWidgets('em debug, quadros lentos só aparecem na medição',
      (tester) async {
    await montar(tester);
    await _desenhar(tester, cena);
    _quadros(tester, 93, ms: 30);
    await tester.pump();
    expect(diag.value.modo, ModoMaquete.tempoReal);
    expect(diag.value.medicao!.p90Ms, 30);
    expect(_relogio(tester), isFalse);
    expect(cena.descartada, isFalse);
  });

  testWidgets('quadros de antes do primeiro desenho não contam',
      (tester) async {
    await montar(tester);
    // Ainda aquecendo: tempos que chegam agora são ignorados.
    _quadros(tester, 20, ms: 200);
    await tester.pump();
    expect(diag.value.quadrosMedidos, 0);
    await _desenhar(tester, cena);
    _quadros(tester, 10);
    await tester.pump();
    expect(diag.value.quadrosMedidos, 7);
    expect(diag.value.medicao!.p90Ms, 8);
  });

  testWidgets('o avanço muda: a cena anima de um plano ao outro',
      (tester) async {
    await montar(tester, progresso: ProgressoMaquete.estado(2));
    await _desenhar(tester, cena);
    final novo = ProgressoMaquete.fases([1, 1, 0.6]);
    await tester.pumpWidget(_app(MaqueteObra(
      progresso: novo,
      diagnostico: diag,
    )));
    final vistasAntes = cena.vistas;
    await tester.pump(MaqueteObra.duracaoTroca ~/ 3);
    int fiadas(PlanoMaquete p) => [
          for (var k = 0; k < 15; k++)
            if (p.pecas[NosMaquete.fiada(k)]!.visivel) k,
        ].length;
    final meio = fiadas(cena.planos.last);
    expect(meio, inExclusiveRange(0, 9), reason: 'no meio do caminho');
    await tester.pump(MaqueteObra.duracaoTroca);
    expect(cena.planos.last.pecas,
        PlanoMaquete.calcular(novo.avancoPorFase).pecas);
    expect(fiadas(cena.planos.last), 9);
    expect(cena.vistas, greaterThan(vistasAntes), reason: 'redesenha');
  });

  testWidgets('o tema muda: a cena troca as cores', (tester) async {
    await montar(tester);
    expect(cena.temas.last, same(TemaMaquete.claro));
    await tester.pumpWidget(_app(
      MaqueteObra(progresso: ProgressoMaquete.estado(3), diagnostico: diag),
      brilho: Brightness.dark,
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(cena.temas.last, same(TemaMaquete.escuro));
  });

  testWidgets('arrastar na horizontal gira; não interativa não gira',
      (tester) async {
    await montar(tester);
    await _desenhar(tester, cena);
    expect(cena.giro, 0);
    await tester.drag(find.byKey(_chaveVista), const Offset(200, 0));
    await tester.pump();
    // O tester.drag anda 20 pontos de folga antes de o arrasto valer.
    expect(
      cena.giro,
      inInclusiveRange(
        150 * CameraMaquete.giroPorPonto,
        200 * CameraMaquete.giroPorPonto + 1e-9,
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    cena = _CenaFalsa();
    await montar(tester, interativa: false);
    await _desenhar(tester, cena);
    await tester.drag(find.byKey(_chaveVista), const Offset(200, 0));
    await tester.pump();
    expect(cena.giro, 0);
  });

  testWidgets('girar também pelo leitor de tela', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);
    await _desenhar(tester, cena);
    final no = tester.getSemantics(find.byType(MaqueteObra));
    expect(no.getSemanticsData().customSemanticsActionIds, hasLength(2));
    semantica.dispose();
  });

  testWidgets(
      '"reduzir animações" ligado depois: solta a cena; desligado, '
      'carrega de novo', (tester) async {
    await montar(tester);
    await _desenhar(tester, cena);
    await tester.pumpWidget(_app(
      MaqueteObra(progresso: ProgressoMaquete.estado(3), diagnostico: diag),
      reduzir: true,
    ));
    await tester.pump();
    expect(diag.value.modo, ModoMaquete.imagem);
    expect(diag.value.motivo, MotivoMaquete.reduzirAnimacoes);
    expect(find.byKey(_chaveVista), findsNothing);
    expect(cena.descartada, isTrue);

    final primeira = cena;
    cena = _CenaFalsa();
    await tester.pumpWidget(_app(
      MaqueteObra(progresso: ProgressoMaquete.estado(3), diagnostico: diag),
    ));
    await tester.pump();
    await tester.pump();
    expect(cargas, 2);
    expect(diag.value.modo, ModoMaquete.tempoReal);
    expect(primeira.planos, isNotEmpty);
  });

  testWidgets('app em segundo plano para o relógio da cena', (tester) async {
    await montar(tester);
    await _desenhar(tester, cena);
    expect(_relogio(tester), isTrue);
    _ciclo(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump();
    expect(_relogio(tester), isFalse);
    _ciclo(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    expect(_relogio(tester), isTrue);
  });

  testWidgets('tirar a maquete da tela solta a cena', (tester) async {
    await montar(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(cena.descartada, isTrue);
  });

  testWidgets('painel no tempo real: medição, cena e relógio contínuo',
      (tester) async {
    await tester.pumpWidget(_app(MaqueteObra(
      progresso: ProgressoMaquete.estado(3),
      altura: 600,
      diagnostico: diag,
    )));
    await tester.pump();
    await tester.pump();
    await tester.longPress(find.byType(MaqueteObra));
    await tester.pump();
    expect(find.text('modo: tempoReal (aquecendo)'), findsOneWidget);

    await _desenhar(tester, cena);
    _quadros(tester, 93);
    await tester.pump();
    expect(find.text('modo: tempoReal'), findsOneWidget);
    expect(find.text('medição: 90/90 (concluída)'), findsOneWidget);
    expect(find.text('cena: CPU 1.5 ms · 42 desenhos'), findsOneWidget);
    expect(_relogio(tester), isFalse);

    await tester.tap(find.text('desenhar sem parar'));
    await tester.pump();
    expect(_relogio(tester), isTrue);
    await tester.tap(find.text('parar relógio'));
    await tester.pump();
    expect(_relogio(tester), isFalse);
  });

  group('caminhos de erro: a maquete sempre volta para a imagem', () {
    testWidgets(
        'desenhar a cena lança no meio da pintura: imagem, e a próxima '
        'maquete nem tenta', (tester) async {
      await montar(tester);
      await _desenhar(tester, cena);
      await _esperarTroca(tester);
      expect(_imagem(3), findsNothing);

      cena.falharAoPintar = true;
      // Um quadro novo da cena (o tema muda) chega a pintar e falha.
      await tester.pumpWidget(_app(
        MaqueteObra(progresso: ProgressoMaquete.estado(3), diagnostico: diag),
        brilho: Brightness.dark,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'nada de setState no meio da pintura');
      expect(diag.value.modo, ModoMaquete.imagem);
      expect(diag.value.motivo, MotivoMaquete.semSuporte);
      expect(diag.value.detalhe,
          'falha ao desenhar: Bad state: pipeline recusado pelo driver');
      expect(find.byKey(_chaveVista), findsNothing);
      expect(_imagem(3, escuro: true), findsOneWidget);
      await tester.pump();
      expect(cena.descartada, isTrue);

      await tester.pumpWidget(_app(MaqueteObra(
        key: UniqueKey(),
        progresso: ProgressoMaquete.estado(3),
        diagnostico: diag,
      )));
      await tester.pump();
      await tester.pump();
      expect(cargas, 1);
      expect(diag.value.motivo, MotivoMaquete.semSuporte);
    });

    testWidgets('o 3D que não aparece (aquecimento travado): imagem e '
        'relógio parado', (tester) async {
      await montar(tester);
      expect(_relogio(tester), isTrue, reason: 'aquecendo');
      await tester.pump(
          MaqueteObra.tempoMaximoDeAquecimento - const Duration(seconds: 1));
      expect(diag.value.modo, ModoMaquete.tempoReal);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(diag.value.modo, ModoMaquete.imagem);
      expect(diag.value.motivo, MotivoMaquete.semSuporte);
      expect(diag.value.detalhe, contains('aquecimento'));
      expect(find.byKey(_chaveVista), findsNothing, reason: 'sem relógio');
      expect(_imagem(3), findsOneWidget);
      await tester.pump();
      expect(cena.descartada, isTrue);
    });

    testWidgets('aquecimento com a rota encoberta ou o app em segundo plano '
        'não estoura o prazo', (tester) async {
      await tester.pumpWidget(_app(
        MaqueteObra(progresso: ProgressoMaquete.estado(3), diagnostico: diag),
        tickers: false,
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump(MaqueteObra.tempoMaximoDeAquecimento * 3);
      expect(diag.value.modo, ModoMaquete.tempoReal);

      // A rota volta a aparecer, e o app vai para o segundo plano.
      await tester.pumpWidget(_app(
        MaqueteObra(progresso: ProgressoMaquete.estado(3), diagnostico: diag),
      ));
      _ciclo(tester, const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]);
      await tester.pump(MaqueteObra.tempoMaximoDeAquecimento * 2);
      expect(diag.value.modo, ModoMaquete.tempoReal);

      _ciclo(tester, const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      await _desenhar(tester, cena);
      await tester.pump(MaqueteObra.tempoMaximoDeAquecimento * 2);
      expect(diag.value.modo, ModoMaquete.tempoReal);
      expect(diag.value.revelada, isTrue);
    });

    testWidgets('cena que chega depois do tempo de carga é solta',
        (tester) async {
      final atrasada = Completer<Cena3dMaquete>();
      MaqueteObra.carregadorDeCena = ({required tema}) => atrasada.future;
      await tester.pumpWidget(_app(
        MaqueteObra(progresso: ProgressoMaquete.estado(3), diagnostico: diag),
      ));
      await tester.pump();
      await tester.pump(MaqueteObra.tempoMaximoDeCarga);
      await tester.pump();
      expect(diag.value.modo, ModoMaquete.imagem);
      expect(cena.descartada, isFalse);
      atrasada.complete(cena);
      await tester.pump();
      expect(cena.descartada, isTrue);
    });
  });

  group('medição e bateria', () {
    testWidgets(
        'só contam os quadros em que a cena andou: os de outra tela por '
        'cima não decidem nada', (tester) async {
      var numero = 1000;
      MaqueteObra.numeroDoQuadro = () => numero;
      await montar(tester, cortar: true);
      // 20 quadros da cena (o SceneView chama o onTick a cada um).
      for (var i = 0; i < 20; i++) {
        numero = 1000 + i;
        cena.aoDesenhar!();
      }
      await tester.pump();
      // A rota é encoberta (o relógio da cena para) e a tela de cima anima
      // com quadros lentos.
      await tester.pumpWidget(_app(
        MaqueteObra(
          progresso: ProgressoMaquete.estado(3),
          cortarPorDesempenho: true,
          diagnostico: diag,
        ),
        tickers: false,
      ));
      _quadros(tester, 93, ms: 35, numero: 5000);
      await tester.pump();
      expect(diag.value.quadrosMedidos, 0);
      expect(diag.value.modo, ModoMaquete.tempoReal);
      expect(await tester.runAsync(DecisaoDesempenho.ler), isNull);

      // Os tempos dos 20 quadros da cena chegam: esses contam.
      _quadros(tester, 20, numero: 1000);
      await tester.pump();
      expect(diag.value.quadrosMedidos, 17, reason: '3 descartados');
      expect(diag.value.medicao!.p90Ms, 8);
    });

    testWidgets(
        'numeração que não casa com a dos tempos: volta a contar tudo '
        '(a medição não fica presa)', (tester) async {
      var numero = 0;
      MaqueteObra.numeroDoQuadro = () => numero++;
      await montar(tester);
      for (var i = 0; i < 400; i++) {
        cena.aoDesenhar!();
      }
      await tester.pump();
      _quadros(tester, 93, numero: 900000);
      await tester.pump();
      expect(diag.value.medicaoConcluida, isTrue);
      expect(diag.value.quadrosMedidos, 90);
    });

    testWidgets('a medição tem prazo: sem quadros, o relógio para sem '
        'decidir nada', (tester) async {
      await montar(tester, cortar: true);
      await _desenhar(tester, cena);
      expect(_relogio(tester), isTrue);
      await tester.pump(MaqueteObra.prazoDaMedicao);
      await tester.pump();
      expect(diag.value.medicaoConcluida, isTrue);
      expect(diag.value.modo, ModoMaquete.tempoReal);
      expect(_relogio(tester), isFalse);
      expect(await tester.runAsync(DecisaoDesempenho.ler), isNull);
    });

    testWidgets('prazo com quadros suficientes e lentos: decide com eles',
        (tester) async {
      await montar(tester, cortar: true);
      await _desenhar(tester, cena);
      _quadros(tester, 40, ms: 35);
      await tester.pump(MaqueteObra.prazoDaMedicao);
      await tester.pump();
      expect(diag.value.modo, ModoMaquete.imagem);
      expect(diag.value.motivo, MotivoMaquete.quadrosLentos);
      expect(diag.value.medicao!.quadros, 37);
      expect(await tester.runAsync(DecisaoDesempenho.ler), 35);
    });

    testWidgets(
        'o pai reconstruir não redesenha a cena; mudar algo do 3D, sim',
        (tester) async {
      await montar(tester);
      await _desenhar(tester, cena);
      _quadros(tester, 93);
      await tester.pump();
      final antes = cena.vistas;
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(_app(MaqueteObra(
          progresso: ProgressoMaquete.estado(3),
          diagnostico: diag,
        )));
      }
      expect(cena.vistas, antes, reason: 'o mesmo SceneView, sem desenhar');

      await tester.drag(find.byKey(_chaveVista), const Offset(100, 0));
      await tester.pump();
      expect(cena.vistas, greaterThan(antes), reason: 'giro');
      final depoisDoGiro = cena.vistas;
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.fases([1, 1, 1, 0.5]),
        diagnostico: diag,
      )));
      await tester.pump(MaqueteObra.duracaoTroca);
      expect(cena.vistas, greaterThan(depoisDoGiro), reason: 'avanço');
    });

    testWidgets(
        'depois da medição, sem painel nem diagnóstico, deixa de ouvir os '
        'tempos de quadro', (tester) async {
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(3),
        painelDepuracao: false,
      )));
      await tester.pump();
      await tester.pump();
      await _desenhar(tester, cena);
      _quadros(tester, 93);
      await tester.pump();
      final d = MaqueteObra.diagnosticoGlobal.value;
      expect(d.medicaoConcluida, isTrue);
      final recentes = d.recente!.quadros;
      _quadros(tester, 10, ms: 50);
      await tester.pump();
      expect(MaqueteObra.diagnosticoGlobal.value.recente!.quadros, recentes);
    });
  });
}
