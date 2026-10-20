import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/medidor_quadros.dart';
import 'package:shared_preferences/shared_preferences.dart';

Duration _ms(num v) => Duration(microseconds: (v * 1000).round());

/// Um quadro do motor que começa a ser construído em [inicioUs].
ui.FrameTiming _quadro(
  int inicioUs, {
  double construcao = 5,
  double raster = 5,
}) {
  final construcaoFim = inicioUs + (construcao * 1000).round();
  final rasterFim = construcaoFim + (raster * 1000).round();
  return ui.FrameTiming(
    vsyncStart: inicioUs - 100,
    buildStart: inicioUs,
    buildFinish: construcaoFim,
    rasterStart: construcaoFim,
    rasterFinish: rasterFim,
    rasterFinishWallTime: rasterFim,
  );
}

void main() {
  group('EstatisticaQuadros', () {
    test('percentil pelo posto mais próximo', () {
      final v = [for (var i = 1; i <= 10; i++) i.toDouble()];
      expect(EstatisticaQuadros.percentil(v, 0.5), 5);
      expect(EstatisticaQuadros.percentil(v, 0.9), 9);
      expect(EstatisticaQuadros.percentil(v, 1), 10);
      expect(EstatisticaQuadros.percentil(const [], 0.9), 0);
    });

    test('o quadro é a mais lenta das duas threads', () {
      final e = EstatisticaQuadros.de([2, 30, 4], [10, 1, 12])!;
      expect(e.quadros, 3);
      expect(e.p50Ms, 12);
      expect(e.p90Ms, 30);
      expect(e.p90ConstrucaoMs, 30);
      expect(e.p90RasterMs, 12);
      expect(EstatisticaQuadros.de(const [], const []), isNull);
    });

    test('fps do quadro mediano, no máximo 60', () {
      expect(EstatisticaQuadros.de([20], [1])!.fpsMediano, 50);
      expect(EstatisticaQuadros.de([2], [1])!.fpsMediano, 60);
    });
  });

  group('MedidorQuadros', () {
    test('descarta os primeiros e decide no 90º quadro contado', () {
      final m = MedidorQuadros();
      for (var i = 0; i < 3; i++) {
        expect(m.registrar(_ms(500), _ms(500)), isFalse);
      }
      expect(m.quadrosMedidos, 0, reason: 'os 3 primeiros não contam');
      for (var i = 0; i < 89; i++) {
        expect(m.registrar(_ms(8), _ms(10)), isFalse);
      }
      expect(m.decidido, isFalse);
      expect(m.parcial!.quadros, 89);
      expect(m.registrar(_ms(8), _ms(10)), isTrue);
      expect(m.decidido, isTrue);
      expect(m.quadrosMedidos, 90);
      expect(m.inicial!.p90Ms, 10);
      expect(m.lento, isFalse);
      // Depois de decidido, só a janela recente anda (ela vê todos os
      // quadros, até os descartados).
      expect(m.registrar(_ms(40), _ms(40)), isFalse);
      expect(m.inicial!.quadros, 90);
      expect(m.recente!.quadros, 94);
    });

    test('p90 acima de 20 ms reprova; 20 ms em cheio passa', () {
      MedidorQuadros medir(double ms) {
        final m = MedidorQuadros(descartar: 0);
        for (var i = 0; i < 90; i++) {
          m.registrar(_ms(1), _ms(i < 80 ? 10 : ms));
        }
        return m;
      }

      // 10 de 90 quadros lentos: o p90 (81º) já é lento.
      expect(medir(25).lento, isTrue);
      expect(medir(25).inicial!.p90Ms, 25);
      expect(medir(20).lento, isFalse);
    });

    test('janela recente limitada', () {
      final m = MedidorQuadros(janelaRecente: 5, descartar: 0);
      for (var i = 0; i < 12; i++) {
        m.registrar(_ms(i), _ms(0));
      }
      expect(m.recente!.quadros, 5);
      expect(m.recente!.p90Ms, 11);
    });

    test('quadros de antes do início (carregamento) não contam', () {
      final m = MedidorQuadros(descartar: 0, quadrosParaDecidir: 3)
        ..inicioUs = 1000000;
      expect(m.registrarTiming(_quadro(900000, construcao: 300)), isFalse);
      expect(m.quadrosMedidos, 0);
      m.registrarTiming(_quadro(1000000));
      m.registrarTiming(_quadro(1016000));
      expect(m.registrarTiming(_quadro(1033000)), isTrue);
      expect(m.inicial!.p90Ms, 5);
    });

    test('relógios que não batem: não filtra (em vez de jogar tudo fora)', () {
      final m = MedidorQuadros(descartar: 0, quadrosParaDecidir: 2)
        // 1 hora à frente do quadro: não é o mesmo relógio.
        ..inicioUs = 3600 * 1000000 + 5000;
      m.registrarTiming(_quadro(5000));
      expect(m.registrarTiming(_quadro(21000)), isTrue);
    });

    test('pularProximos volta a descartar e esquece o início', () {
      final m = MedidorQuadros(descartar: 2)..inicioUs = 10;
      m.registrar(_ms(1), _ms(1));
      m.registrar(_ms(1), _ms(1));
      m.registrar(_ms(1), _ms(1));
      expect(m.quadrosMedidos, 1);
      m.pularProximos();
      expect(m.inicioUs, isNull);
      m.registrar(_ms(1), _ms(1));
      m.registrar(_ms(1), _ms(1));
      expect(m.quadrosMedidos, 1);
    });
  });

  group('MedidorQuadros.encerrar (prazo da medição)', () {
    test('com quadros suficientes decide com eles', () {
      final m = MedidorQuadros(descartar: 0);
      for (var i = 0; i < 40; i++) {
        m.registrar(_ms(5), _ms(30));
      }
      expect(m.decidido, isFalse);
      expect(m.encerrar(), isTrue);
      expect(m.decidido, isTrue);
      expect(m.inicial!.quadros, 40);
      expect(m.lento, isTrue);
      expect(m.encerrar(), isFalse, reason: 'só uma vez');
      // Depois de encerrada, quadros novos só vão para a janela recente.
      expect(m.registrar(_ms(5), _ms(5)), isFalse);
      expect(m.quadrosMedidos, 40);
      expect(m.recente!.quadros, 41);
    });

    test('com poucos quadros termina sem decisão (nunca reprova)', () {
      final m = MedidorQuadros(descartar: 0);
      for (var i = 0; i < 29; i++) {
        m.registrar(_ms(5), _ms(80));
      }
      expect(m.encerrar(), isTrue);
      expect(m.decidido, isTrue);
      expect(m.inicial, isNull);
      expect(m.lento, isFalse);
      expect(m.parcial!.quadros, 29, reason: 'o painel ainda mostra');
    });
  });

  group('DecisaoDesempenho', () {
    final agora = DateTime(2026, 10, 19, 12);

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sem decisão guardada: null', () async {
      expect(await DecisaoDesempenho.ler(agora: agora), isNull);
    });

    test('grava, lê e esquece', () async {
      await DecisaoDesempenho.gravar(27.456, agora: agora);
      expect(await DecisaoDesempenho.ler(agora: agora), 27.46);
      await DecisaoDesempenho.esquecer();
      expect(await DecisaoDesempenho.ler(agora: agora), isNull);
    });

    test('vale 30 dias; depois o aparelho é medido de novo', () async {
      await DecisaoDesempenho.gravar(30, agora: agora);
      expect(
        await DecisaoDesempenho.ler(agora: agora.add(const Duration(days: 29))),
        30,
      );
      expect(
        await DecisaoDesempenho.ler(agora: agora.add(const Duration(days: 31))),
        isNull,
      );
    });

    test('data no futuro (relógio adiantado ao gravar) não vale', () async {
      await DecisaoDesempenho.gravar(40, agora: DateTime(2031, 1, 1));
      expect(await DecisaoDesempenho.ler(agora: agora), isNull);
      // Um pouco à frente (fuso, ajuste da hora) ainda vale.
      await DecisaoDesempenho.gravar(
          40, agora: agora.add(const Duration(hours: 12)));
      expect(await DecisaoDesempenho.ler(agora: agora), 40);
    });

    test('valor estragado não derruba: null', () async {
      SharedPreferences.setMockInitialValues(
        {DecisaoDesempenho.chave: 'não é json'},
      );
      expect(await DecisaoDesempenho.ler(agora: agora), isNull);
      SharedPreferences.setMockInitialValues(
        {DecisaoDesempenho.chave: '{"p90": "x"}'},
      );
      expect(await DecisaoDesempenho.ler(agora: agora), isNull);
    });
  });
}
