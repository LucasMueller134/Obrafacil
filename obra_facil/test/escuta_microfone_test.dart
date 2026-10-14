import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/services/ia/escuta_voz.dart';
import 'package:obra_facil/services/ia/voz_service.dart';

/// A escuta do microfone contra o plugin de mentira: o canal do
/// speech_to_text responde como o Android e os eventos chegam na ordem em
/// que o Android os manda — inclusive as ordens que travavam o painel.
const _canal = MethodChannel('plugin.csdcorp.com/speech_to_text');

void main() {
  late List<MethodCall> chamadas;
  late bool listenComeca;

  setUp(() {
    chamadas = [];
    listenComeca = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (call) async {
      chamadas.add(call);
      return switch (call.method) {
        'initialize' || 'has_permission' => true,
        'listen' => listenComeca,
        _ => null,
      };
    });
  });

  Future<void> doAparelho(
      WidgetTester tester, String metodo, Object arg) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _canal.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(metodo, arg)),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> estado(WidgetTester t, String s) =>
      doAparelho(t, 'notifyStatus', s);
  Future<void> erro(WidgetTester t, String codigo) => doAparelho(
      t, 'notifyError', jsonEncode({'errorMsg': codigo, 'permanent': true}));
  Future<void> ouviu(WidgetTester t, List<(String, double)> hipoteses,
          {bool finalizou = false}) =>
      doAparelho(
          t,
          'textRecognition',
          jsonEncode({
            'alternates': [
              for (final (texto, confianca) in hipoteses)
                {'recognizedWords': texto, 'confidence': confianca},
            ],
            'resultType': finalizou ? 2 : 0,
          }));

  Future<_Gravacao> gravar(WidgetTester tester, VozService voz,
      {bool online = false}) async {
    final g = _Gravacao();
    await voz.inicializar();
    await voz.ouvir(
      (_, __) {},
      online: online,
      onResultado: g.resultados.add,
      onErro: g.erros.add,
      onFim: () => g.fins++,
    );
    await tester.pump();
    return g;
  }

  Future<void> encerrar(WidgetTester tester, VozService voz) async {
    await voz.cancelar();
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('o erro que o Android manda depois do "done" não se perde',
      (tester) async {
    final voz = VozService();
    final g = await gravar(tester, voz);
    await estado(tester, 'listening');
    // Ordem real: o Android avisa o fim e só depois o erro que o causou.
    await estado(tester, 'notListening');
    await estado(tester, 'doneNoResult');
    await erro(tester, 'error_no_match');
    await tester.pump(const Duration(seconds: 1));

    expect(g.erros.single.tipo, TipoErroVoz.naoEntendi);
    expect(g.fins, 1);
    await encerrar(tester, voz);
  });

  testWidgets('sem resultado e sem erro, encerra mesmo assim', (tester) async {
    final voz = VozService();
    final g = await gravar(tester, voz);
    await estado(tester, 'listening');
    await estado(tester, 'notListening');
    await estado(tester, 'doneNoResult');
    await tester.pump(const Duration(seconds: 1));

    expect(g.erros, isEmpty);
    expect(g.fins, 1);
    await encerrar(tester, voz);
  });

  testWidgets('o resultado final traz todas as hipóteses e encerra uma vez',
      (tester) async {
    final voz = VozService();
    final g = await gravar(tester, voz);
    await estado(tester, 'listening');
    await ouviu(tester, [('paguei o aluguel da caçamba duzentos e', -1)]);
    expect(g.fins, 0);
    await ouviu(
        tester,
        [
          ('paguei o aluguel da caçamba duzentos e', 0.8),
          ('paguei o aluguel da caçamba duzentos e oitenta', 0),
        ],
        finalizou: true);
    await estado(tester, 'notListening');
    await estado(tester, 'done');
    await tester.pump(const Duration(seconds: 4));

    final final_ = g.resultados.last;
    expect(final_.finalizou, isTrue);
    expect(final_.hipoteses, hasLength(2));
    expect(final_.confianca, 0.8);
    expect(VozService.interpretarHipoteses(final_.hipoteses).valor, 280);
    expect(g.fins, 1);
    await encerrar(tester, voz);
  });

  testWidgets('microfone fechado sem resultado final: encerra no prazo',
      (tester) async {
    final voz = VozService();
    final g = await gravar(tester, voz);
    await estado(tester, 'listening');
    await ouviu(tester, [('paguei o frete 80', -1)]);
    await estado(tester, 'notListening');
    await tester.pump(const Duration(milliseconds: 2900));
    expect(g.fins, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(g.fins, 1);
    expect(g.resultados.last.texto, 'paguei o frete 80');
    await encerrar(tester, voz);
  });

  testWidgets('escuta recusada pelo aparelho, sem erro: avisa que não começou',
      (tester) async {
    listenComeca = false;
    final voz = VozService();
    final g = await gravar(tester, voz);
    await tester.pump(const Duration(milliseconds: 2100));

    expect(g.erros.single, same(ErroVoz.naoComecou));
    expect(g.fins, 1);
    await encerrar(tester, voz);
  });

  testWidgets('o fim atrasado da gravação cancelada não encerra a nova',
      (tester) async {
    final voz = VozService();
    final primeira = await gravar(tester, voz);
    await estado(tester, 'listening');
    await voz.cancelar(); // "Regravar"
    final segunda = await gravar(tester, voz);
    await estado(tester, 'notListening'); // ainda da primeira
    await estado(tester, 'doneNoResult');
    await estado(tester, 'listening');
    await ouviu(tester, [('comprei cimento', -1)]);
    await tester.pump(const Duration(seconds: 1));

    expect(primeira.fins, 0, reason: 'cancelada não avisa ninguém');
    expect(segunda.fins, 0);
    expect(segunda.resultados.single.texto, 'comprei cimento');
    await encerrar(tester, voz);
  });

  testWidgets('no aparelho por padrão; online só quando pedido',
      (tester) async {
    final voz = VozService();
    await gravar(tester, voz);
    expect(
        chamadas.lastWhere((c) => c.method == 'listen').arguments['onDevice'],
        isTrue);
    await voz.cancelar();

    final g = await gravar(tester, voz, online: true);
    expect(
        chamadas.lastWhere((c) => c.method == 'listen').arguments['onDevice'],
        isFalse);
    expect(
        chamadas.lastWhere((c) => c.method == 'listen').arguments['localeId'],
        'pt_BR');
    // No online, erro de rede não oferece o online de novo.
    await estado(tester, 'listening');
    await erro(tester, 'error_network');
    expect(g.erros.single.ofereceOnline, isFalse);
    await encerrar(tester, voz);
  });

  testWidgets('sem o pacote offline, a saída é escolher o online',
      (tester) async {
    final voz = VozService();
    final g = await gravar(tester, voz);
    await estado(tester, 'listening');
    await erro(tester, 'error_language_unavailable');

    expect(g.erros.single.tipo, TipoErroVoz.pacoteOffline);
    expect(g.erros.single.ofereceOnline, isTrue);
    expect(g.fins, 1);
    await encerrar(tester, voz);
  });
}

class _Gravacao {
  final resultados = <ResultadoVoz>[];
  final erros = <ErroVoz>[];
  var fins = 0;
}
