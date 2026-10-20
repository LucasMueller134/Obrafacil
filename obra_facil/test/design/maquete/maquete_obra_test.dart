import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/constants/app_constants.dart';
import 'package:obra_facil/design/maquete/cena_maquete.dart';
import 'package:obra_facil/design/maquete/maquete.dart';
import 'package:obra_facil/design/maquete/medidor_quadros.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';
import 'package:obra_facil/models/cronograma_fase_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _papelClaro = Color(0xFFF4F5F3);
const _papelEscuro = Color(0xFF121315);

Widget _app(
  Widget filho, {
  Brightness brilho = Brightness.light,
  bool reduzir = false,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brilho),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduzir),
        child: Scaffold(
          body: Center(child: SizedBox(width: 390, child: filho)),
        ),
      ),
    ),
  );
}

/// Deixa as imagens decodificarem (a decodificação é assíncrona de verdade,
/// fora do relógio falso do teste) e redesenha.
Future<void> _carregarImagens(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    final pendentes = tester
        .widgetList<RawImage>(find.byType(RawImage))
        .where((r) => r.image == null);
    if (pendentes.isEmpty) {
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  fail('as imagens de reserva não decodificaram');
}

String _caminho(int estado, {bool escuro = false}) =>
    MaqueteObra.caminhoReserva(estado: estado, escuro: escuro);

Finder _imagem(int estado, {bool escuro = false}) =>
    find.byKey(MaqueteObra.chaveImagem(_caminho(estado, escuro: escuro)));

Finder _anterior(int estado, {bool escuro = false}) => find.byKey(
      ValueKey('maquete-reserva-anterior:${_caminho(estado, escuro: escuro)}'),
    );

CronogramaFaseModel _fase(int i, int pct) => CronogramaFaseModel(
      id: 'f$i',
      obraId: 'obra',
      nome: AppConstants.fasesPadrao[i],
      ordem: i,
      dataInicio: DateTime(2026, 1, 1),
      dataFim: DateTime(2026, 12, 31),
      percentualConcluido: pct,
    );

/// Conta as tentativas de carregar a cena 3D e responde com [resposta].
class _Carregador {
  _Carregador(this.resposta);

  final Future<Cena3dMaquete> Function() resposta;
  int chamadas = 0;

  Future<Cena3dMaquete> call({required TemaMaquete tema}) {
    chamadas++;
    return resposta();
  }
}

/// A exceção que o flutter_gpu lança sem Impeller (a de verdade sai em
/// maquete_obra_sem_gpu_test.dart).
final _semImpeller = Exception(
  'Flutter GPU requires the Impeller rendering backend, but Impeller is not '
  'enabled. (simulada)',
);

void main() {
  setUp(() {
    MaqueteObra.reiniciarParaTeste();
    MaqueteObra.carregadorDeCena =
        ({required tema}) async => throw _semImpeller;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(MaqueteObra.reiniciarParaTeste);

  group('sem GPU (como em todo teste e em aparelho sem Flutter GPU)', () {
    // O carregador de verdade é testado em maquete_obra_sem_gpu_test.dart
    // (um por arquivo: o flutter_scene guarda futuros da inicialização, e no
    // teste cada testWidgets tem a sua zona de tempo falso).
    testWidgets('a segunda maquete do processo nem tenta o GPU de novo',
        (tester) async {
      final carregador = _Carregador(() async => throw _semImpeller);
      MaqueteObra.carregadorDeCena = carregador.call;
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(1),
      )));
      await tester.pump();
      expect(carregador.chamadas, 1);
      expect(
          MaqueteObra.diagnosticoGlobal.value.motivo, MotivoMaquete.semSuporte);

      await tester.pumpWidget(_app(MaqueteObra(
        key: UniqueKey(),
        progresso: ProgressoMaquete.estado(1),
      )));
      await tester.pump();
      expect(carregador.chamadas, 1);
      expect(
          MaqueteObra.diagnosticoGlobal.value.motivo, MotivoMaquete.semSuporte);
      expect(MaqueteObra.diagnosticoGlobal.value.detalhe, contains('Impeller'));
    });

    testWidgets('modelo desatualizado (nó ausente) também vai para a imagem',
        (tester) async {
      MaqueteObra.carregadorDeCena = _Carregador(
        () async => throw StateError('maquete.glb sem os nós fase_x'),
      ).call;
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(0),
      )));
      await tester.pump();
      expect(MaqueteObra.diagnosticoGlobal.value.modo, ModoMaquete.imagem);
      expect(MaqueteObra.diagnosticoGlobal.value.detalhe,
          'Bad state: maquete.glb sem os nós fase_x');
    });

    testWidgets(
        'enquanto a cena carrega, mostra a imagem; carga que não '
        'termina vira imagem', (tester) async {
      final nunca = Completer<Cena3dMaquete>();
      MaqueteObra.carregadorDeCena = _Carregador(() => nunca.future).call;
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(4),
      )));
      await tester.pump();
      expect(MaqueteObra.diagnosticoGlobal.value.modo, ModoMaquete.carregando);
      expect(_imagem(4), findsOneWidget);

      await tester.pump(MaqueteObra.tempoMaximoDeCarga);
      await tester.pump();
      expect(MaqueteObra.diagnosticoGlobal.value.modo, ModoMaquete.imagem);
      expect(
          MaqueteObra.diagnosticoGlobal.value.motivo, MotivoMaquete.semSuporte);
      expect(MaqueteObra.diagnosticoGlobal.value.detalhe,
          startsWith('TimeoutException'));
      expect(_imagem(4), findsOneWidget);
    });
  });

  group('imagem certa por estado e tema', () {
    test('as 22 imagens existem no bundle', () async {
      final manifesto = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final escuro in [false, true]) {
        for (var n = 0; n <= 10; n++) {
          expect(manifesto.listAssets(), contains(_caminho(n, escuro: escuro)));
        }
      }
      expect(_caminho(-1), 'assets/3d/reserva/claro/estado_00.webp');
      expect(_caminho(11, escuro: true),
          'assets/3d/reserva/escuro/estado_10.webp');
    });

    for (final brilho in Brightness.values) {
      final escuro = brilho == Brightness.dark;
      testWidgets('tema ${brilho.name}: estado_XX do avanço e papel de fundo',
          (tester) async {
        for (final n in [0, 2, 5, 10]) {
          await tester.pumpWidget(_app(
            MaqueteObra(
                key: ValueKey(n), progresso: ProgressoMaquete.estado(n)),
            brilho: brilho,
          ));
          await tester.pump();
          expect(_imagem(n, escuro: escuro), findsOneWidget,
              reason: 'estado $n');
          expect(_imagem(n, escuro: !escuro), findsNothing);
        }
        final fundo = tester.widget<ColoredBox>(find
            .descendant(
              of: find.byType(MaqueteObra),
              matching: find.byType(ColoredBox),
            )
            .first);
        expect(fundo.color, escuro ? _papelEscuro : _papelClaro);
      });
    }

    testWidgets('fase em andamento usa a imagem das fases prontas seguidas',
        (tester) async {
      // Fundação e estrutura prontas, alvenaria em 40%: estado_02.
      final p = ProgressoMaquete.doCronograma([
        _fase(0, 100),
        _fase(1, 100),
        _fase(2, 40),
        for (var i = 3; i < 10; i++) _fase(i, 0),
      ]);
      await tester.pumpWidget(_app(MaqueteObra(progresso: p)));
      await tester.pump();
      expect(_imagem(2), findsOneWidget);
    });

    testWidgets('mudar o avanço troca a imagem com esmaecimento',
        (tester) async {
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(2),
      )));
      await _carregarImagens(tester);
      expect(_imagem(2), findsOneWidget);

      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(3),
      )));
      // A nova entra por cima da antiga, que fica até a nova decodificar.
      expect(_imagem(3), findsOneWidget);
      expect(_anterior(2), findsOneWidget);
      await _carregarImagens(tester);
      await tester.pump(MaqueteObra.duracaoTroca ~/ 2);
      expect(_anterior(2), findsOneWidget, reason: 'no meio da troca');
      final opacidade = tester.widget<AnimatedOpacity>(find.ancestor(
        of: _imagem(3),
        matching: find.byType(AnimatedOpacity),
      ));
      expect(opacidade.opacity, 1);
      await tester.pump(MaqueteObra.duracaoTroca);
      await tester.pump();
      expect(_anterior(2), findsNothing, reason: 'a antiga sai no fim');
      expect(_imagem(3), findsOneWidget);
    });

    testWidgets('trocar o tema troca a pasta da imagem', (tester) async {
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(6),
      )));
      await tester.pump();
      expect(_imagem(6), findsOneWidget);
      await tester.pumpWidget(_app(
        MaqueteObra(progresso: ProgressoMaquete.estado(6)),
        brilho: Brightness.dark,
      ));
      // O MaterialApp anima o tema; o brilho vira na metade.
      await tester.pump(const Duration(milliseconds: 300));
      expect(_imagem(6, escuro: true), findsOneWidget);
    });
  });

  group('o que força a imagem', () {
    testWidgets('reduzir animações: imagem, e o Flutter GPU nem é iniciado',
        (tester) async {
      final carregador = _Carregador(() async => throw StateError('x'));
      MaqueteObra.carregadorDeCena = carregador.call;
      await tester.pumpWidget(_app(
        MaqueteObra(progresso: ProgressoMaquete.estado(5)),
        reduzir: true,
      ));
      await tester.pump();
      expect(carregador.chamadas, 0);
      expect(MaqueteObra.diagnosticoGlobal.value.modo, ModoMaquete.imagem);
      expect(MaqueteObra.diagnosticoGlobal.value.motivo,
          MotivoMaquete.reduzirAnimacoes);
      expect(_imagem(5), findsOneWidget);

      // A troca de imagem também fica sem animação.
      await _carregarImagens(tester);
      await tester.pumpWidget(_app(
        MaqueteObra(progresso: ProgressoMaquete.estado(6)),
        reduzir: true,
      ));
      await _carregarImagens(tester);
      await tester.pump();
      expect(_anterior(5), findsNothing);
      expect(_imagem(6), findsOneWidget);

      // Desligar "reduzir animações" volta a tentar o 3D.
      await tester.pumpWidget(_app(
        MaqueteObra(progresso: ProgressoMaquete.estado(6)),
      ));
      await tester.pump();
      await tester.pump();
      expect(carregador.chamadas, 1);
      expect(
          MaqueteObra.diagnosticoGlobal.value.motivo, MotivoMaquete.semSuporte);
    });

    testWidgets('forcarReserva: imagem sem tentar o 3D', (tester) async {
      final carregador = _Carregador(() async => throw StateError('x'));
      MaqueteObra.carregadorDeCena = carregador.call;
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(7),
        forcarReserva: true,
      )));
      await tester.pump();
      expect(carregador.chamadas, 0);
      expect(MaqueteObra.diagnosticoGlobal.value.motivo, MotivoMaquete.forcada);
      expect(_imagem(7), findsOneWidget);
    });

    testWidgets('aparelho já medido como lento: imagem sem tentar o 3D',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        DecisaoDesempenho.chave: jsonEncode({
          'p90': 31.5,
          'em': DateTime.now().toIso8601String(),
        }),
      });
      final carregador = _Carregador(() async => throw StateError('x'));
      MaqueteObra.carregadorDeCena = carregador.call;
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(1),
        cortarPorDesempenho: true,
      )));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(carregador.chamadas, 0);
      expect(MaqueteObra.diagnosticoGlobal.value.motivo,
          MotivoMaquete.decisaoGuardada);
      expect(MaqueteObra.diagnosticoGlobal.value.detalhe, contains('31.5'));
    });

    testWidgets('em debug a decisão guardada não vale (tempos de debug)',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        DecisaoDesempenho.chave: jsonEncode({
          'p90': 31.5,
          'em': DateTime.now().toIso8601String(),
        }),
      });
      final carregador = _Carregador(() async => throw StateError('x'));
      MaqueteObra.carregadorDeCena = carregador.call;
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(1),
      )));
      await tester.pump();
      expect(carregador.chamadas, 1);
    });
  });

  group('acessibilidade e legenda', () {
    testWidgets('descreve a maquete para o leitor de tela', (tester) async {
      final semantica = tester.ensureSemantics();
      final p = ProgressoMaquete.fases(
        [1, 1, 0.5, 0, 0, 0, 0, 0, 0, 0],
        percentualObra: 38,
      );
      await tester.pumpWidget(_app(MaqueteObra(progresso: p)));
      await tester.pump();
      final no = find.bySemanticsLabel(
        'Maquete da obra: Alvenaria em andamento, 38% da obra',
      );
      expect(no, findsOneWidget);
      expect(
        tester.getSemantics(no),
        isSemantics(
          label: 'Maquete da obra: Alvenaria em andamento, 38% da obra',
          isImage: true,
        ),
      );
      // A legenda e a imagem não viram nós soltos.
      expect(find.bySemanticsLabel('ainda não construído'), findsNothing);
      semantica.dispose();
    });

    testWidgets('legenda do tracejado enquanto falta fase', (tester) async {
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(4),
      )));
      await tester.pump();
      expect(find.text('ainda não construído'), findsOneWidget);
      final estilo = tester.widget<Text>(find.text('ainda não construído'));
      expect(estilo.style!.fontSize, greaterThanOrEqualTo(15));

      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(10),
      )));
      await tester.pump();
      expect(find.text('ainda não construído'), findsNothing);

      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(4),
        legenda: false,
      )));
      await tester.pump();
      expect(find.text('ainda não construído'), findsNothing);
    });

    testWidgets('altura pedida, largura toda', (tester) async {
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.vazio,
        altura: 144,
      )));
      await tester.pump();
      expect(tester.getSize(find.byType(MaqueteObra)), const Size(390, 144));
    });
  });

  group('painel de depuração', () {
    testWidgets('toque longo mostra modo, motivo e detalhe; fechar some',
        (tester) async {
      // Alta, para o painel inteiro caber com a fonte de teste (larga).
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(2),
        altura: 520,
      )));
      await tester.pump();
      await tester.longPress(find.byType(MaqueteObra));
      await tester.pump();
      expect(find.text('modo: imagem'), findsOneWidget);
      expect(find.text('motivo: ${MotivoMaquete.semSuporte.texto}'),
          findsOneWidget);
      expect(find.textContaining('detalhe: Exception: Flutter GPU requires'),
          findsOneWidget);
      expect(find.text('imagem: estado_02'), findsOneWidget);
      // Sem 3D não há relógio para ligar.
      expect(find.text('desenhar sem parar'), findsNothing);

      await tester.tap(find.text('fechar'));
      await tester.pump();
      expect(find.text('modo: imagem'), findsNothing);
    });

    testWidgets('painelDepuracao: false desliga o toque longo', (tester) async {
      await tester.pumpWidget(_app(MaqueteObra(
        progresso: ProgressoMaquete.estado(2),
        painelDepuracao: false,
      )));
      await tester.pump();
      await tester.longPress(find.byType(MaqueteObra));
      await tester.pump();
      expect(find.text('modo: imagem'), findsNothing);
    });

    test('linhas do diagnóstico com medição', () {
      const d = DiagnosticoMaquete(
        modo: ModoMaquete.tempoReal,
        revelada: true,
        estadoReserva: 3,
        quadrosMedidos: 90,
        medicaoConcluida: true,
        medicao: EstatisticaQuadros(
          quadros: 90,
          p50Ms: 9.5,
          p90Ms: 14.26,
          p90ConstrucaoMs: 6,
          p90RasterMs: 14.26,
        ),
        cpuCenaMs: 2.5,
        chamadasDeDesenho: 61,
      );
      expect(d.linhas, [
        'modo: tempoReal',
        'imagem: estado_03',
        'medição: 90/90 (concluída)',
        '  p50 9.5 ms · p90 14.3 ms (UI 6.0 ms · raster 14.3 ms)',
        'cena: CPU 2.5 ms · 61 desenhos',
      ]);
    });
  });
}
