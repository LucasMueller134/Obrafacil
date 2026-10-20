import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';

List<double> _so(int fase, double t) =>
    [for (var i = 0; i < 10; i++) i == fase ? t : 0.0];

/// O manifesto lido do disco (os testes rodam na pasta do pacote).
final Map<String, dynamic> _manifesto =
    jsonDecode(File('assets/3d/maquete.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('PlanoMaquete: regra por fase', () {
    test('não começada: peças escondidas, fantasma visível', () {
      final plano = PlanoMaquete.calcular(List.filled(10, 0));
      expect(plano.pecas.values.every((e) => !e.visivel), isTrue);
      expect(plano.fantasmas.values.every((v) => v), isTrue);
    });

    test('concluída: peças inteiras, fantasma escondido', () {
      final plano = PlanoMaquete.calcular(List.filled(10, 1));
      expect(plano.pecas.values.every((e) => e == EstadoPeca.inteira), isTrue);
      expect(plano.fantasmas.values.every((v) => !v), isTrue);
    });

    test('estado N da reserva: fases 0..N-1 prontas, fantasmas N..9', () {
      for (var n = 0; n <= 10; n++) {
        final plano = PlanoMaquete.calcular(
          [for (var i = 0; i < 10; i++) i < n ? 1.0 : 0.0],
        );
        for (var f = 0; f < 10; f++) {
          expect(plano.fantasmas[NosMaquete.fantasma(f)], f >= n,
              reason: 'estado $n, fantasma $f');
          for (final etapa in PlanoMaquete.etapasPorFase[f]) {
            expect(plano.pecas[etapa.no]!.visivel, f < n,
                reason: 'estado $n, ${etapa.no}');
          }
        }
      }
    });

    test('em andamento: o fantasma continua (regra do LEIA-ME)', () {
      final plano = PlanoMaquete.calcular(_so(2, 0.5));
      expect(plano.fantasmas[NosMaquete.fantasma(2)], isTrue);
    });

    test('alvenaria sobe fiada a fiada pela porcentagem', () {
      int fiadas(double t) {
        final plano = PlanoMaquete.calcular(_so(2, t));
        return [
          for (var k = 0; k < 15; k++)
            if (plano.pecas[NosMaquete.fiada(k)]!.visivel) k,
        ].length;
      }

      expect(fiadas(0), 0);
      expect(fiadas(0.05), 0);
      expect(fiadas(1 / 15), 1);
      expect(fiadas(0.38), 5);
      expect(fiadas(0.5), 7);
      expect(fiadas(0.99), 14);
      expect(fiadas(1), 15);
      // Sempre de baixo para cima, sem buraco.
      for (var t = 0.0; t <= 1; t += 0.01) {
        final plano = PlanoMaquete.calcular(_so(2, t));
        final vis = [
          for (var k = 0; k < 15; k++)
            plano.pecas[NosMaquete.fiada(k)]!.visivel,
        ];
        final n = vis.where((v) => v).length;
        expect(vis.sublist(0, n).every((v) => v), isTrue, reason: 't=$t');
        // Fiada é inteira ou não aparece (sem escala).
        for (var k = 0; k < 15; k++) {
          final e = plano.pecas[NosMaquete.fiada(k)]!;
          if (e.visivel) expect(e.inteiraNaEscala, isTrue);
        }
      }
    });

    test('estrutura: pilares, depois vigas, depois laje', () {
      EstadoPeca e(double t, String no) =>
          PlanoMaquete.calcular(_so(1, t)).pecas[no]!;

      // 20%: pilares subindo (escala só em Y), vigas e laje ainda não.
      final pilar = e(0.2, 'estrutura_pilares');
      expect(pilar.visivel, isTrue);
      expect(pilar.escalaY, inExclusiveRange(0, 1));
      expect((pilar.escalaX, pilar.escalaZ), (1.0, 1.0));
      expect(e(0.2, 'estrutura_vigas').visivel, isFalse);
      expect(e(0.2, 'estrutura_laje').visivel, isFalse);

      // 60%: pilares prontos, vigas subindo, laje não.
      expect(e(0.6, 'estrutura_pilares'), EstadoPeca.inteira);
      expect(e(0.6, 'estrutura_vigas').escalaY, inExclusiveRange(0, 1));
      expect(e(0.6, 'estrutura_laje').visivel, isFalse);

      // 85%: laje concretando de trás para a frente (escala em Z).
      final laje = e(0.85, 'estrutura_laje');
      expect(laje.escalaZ, inExclusiveRange(0, 1));
      expect((laje.escalaX, laje.escalaY), (1.0, 1.0));
      expect(e(0.85, 'estrutura_vigas'), EstadoPeca.inteira);
    });

    test('cobertura: terças, depois telhas', () {
      final p30 = PlanoMaquete.calcular(_so(3, 0.3));
      expect(p30.pecas['cobertura_tercas']!.visivel, isTrue);
      expect(p30.pecas['cobertura_telhas']!.visivel, isFalse);
      final p70 = PlanoMaquete.calcular(_so(3, 0.7));
      expect(p70.pecas['cobertura_tercas'], EstadoPeca.inteira);
      expect(p70.pecas['cobertura_telhas']!.escalaX, inExclusiveRange(0, 1));
    });

    test('o crescimento é contínuo e não regride com o avanço', () {
      for (final fase in [0, 1, 3, 4, 5, 7]) {
        for (final etapa in PlanoMaquete.etapasPorFase[fase]) {
          var antes = 0.0;
          for (var t = 0.0; t <= 1.0001; t += 0.02) {
            final e = PlanoMaquete.calcular(_so(fase, t)).pecas[etapa.no]!;
            final v = e.visivel ? e.escalaX * e.escalaY * e.escalaZ : 0.0;
            expect(v, greaterThanOrEqualTo(antes - 1e-9),
                reason: '${etapa.no} em t=$t');
            antes = v;
          }
        }
      }
    });

    test('escala nunca é zero (a matriz degeneraria)', () {
      for (var fase = 0; fase < 10; fase++) {
        for (var t = 0.0; t <= 1; t += 0.001) {
          for (final e in PlanoMaquete.calcular(_so(fase, t)).pecas.values) {
            if (!e.visivel) continue;
            expect(math.min(e.escalaX, math.min(e.escalaY, e.escalaZ)),
                greaterThan(EstadoPeca.escalaMinima));
          }
        }
      }
    });

    test('avanço fora de 0..1 ou lista curta não quebra', () {
      final plano = PlanoMaquete.calcular([2, -1]);
      expect(plano.pecas['fundacao_radier'], EstadoPeca.inteira);
      expect(plano.pecas['estrutura_pilares']!.visivel, isFalse);
      expect(plano.fantasmas, hasLength(10));
    });
  });

  group('PlanoMaquete x manifesto', () {
    test('as peças de cada fase são exatamente os filhos do manifesto', () {
      final fases = (_manifesto['fases'] as List).cast<Map<String, dynamic>>();
      expect(fases, hasLength(10));
      for (final f in fases) {
        final i = f['indice'] as int;
        expect(
          PlanoMaquete.etapasPorFase[i].map((e) => e.no).toSet(),
          (f['filhos'] as List).cast<String>().toSet(),
          reason: f['no'] as String,
        );
        expect(NosMaquete.fantasma(i), f['fantasma']);
      }
      expect(
        [for (var k = 0; k < NosMaquete.totalFiadas; k++) NosMaquete.fiada(k)],
        (_manifesto['fiadas_alvenaria'] as List).cast<String>(),
      );
    });

    test('peça que cresce por escala tem pivô fora da origem da cena', () {
      final pivos = (_manifesto['pivos'] as Map).cast<String, List>();
      for (final etapas in PlanoMaquete.etapasPorFase) {
        for (final etapa in etapas) {
          if (etapa.crescimento == Crescimento.aparecer) continue;
          final p = pivos[etapa.no]!.cast<num>();
          expect(p.any((v) => v != 0), isTrue,
              reason: '${etapa.no} cresceria a partir do centro da cena');
        }
      }
    });

    test('câmera = camera_reserva com o Z trocado de sinal', () {
      final cam = _manifesto['camera_reserva'] as Map<String, dynamic>;
      final pos = (cam['posicao'] as List).cast<num>();
      final alvo = (cam['alvo'] as List).cast<num>();
      expect(CameraMaquete.posicao, [pos[0], pos[1], -pos[2]]);
      expect(CameraMaquete.alvo, [alvo[0], alvo[1], -alvo[2]]);
      expect(CameraMaquete.fovVerticalGraus, cam['fov_vertical_graus']);
      final res = (cam['resolucao'] as List).cast<num>();
      expect(CameraMaquete.proporcaoReserva, res[0] / res[1]);
    });

    test('cores de tema = materiais_de_tema e fundo do manifesto', () {
      String hex(Color c) =>
          '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      final mats = (_manifesto['materiais_de_tema'] as Map)
          .cast<String, Map<String, dynamic>>();
      final fundo = (_manifesto['fundo'] as Map).cast<String, String>();
      for (final (nome, tema) in [
        ('claro', TemaMaquete.claro),
        ('escuro', TemaMaquete.escuro),
      ]) {
        for (final material in ['base', 'grade', 'grade_forte', 'cota']) {
          expect(hex(tema.corDoMaterial(material)!), mats[material]![nome],
              reason: '$material ($nome)');
        }
        // O fantasma vem das imagens (cor_fantasma_test.dart), não do
        // fantasma_opaco do manifesto.
        expect(tema.corDoMaterial('fantasma'), tema.fantasma);
        expect(hex(tema.papel), fundo[nome]);
      }
      expect(TemaMaquete.claro.corDoMaterial('concreto'), isNull);
      expect(TemaMaquete.de(escuro: true), same(TemaMaquete.escuro));
    });
  });

  group('cor do fantasma na cena (curva de tons)', () {
    test('PBR Neutral: identidade menos 0,04 no meio, compressão no alto', () {
      expect(TemaMaquete.pbrNeutral([0.5, 0.5, 0.5]), [
        for (final _ in [0, 1, 2]) closeTo(0.46, 1e-12)
      ]);
      final alto = TemaMaquete.pbrNeutral([4.0, 4.0, 4.0]);
      expect(alto.first, inExclusiveRange(0.9, 1.0));
      // No pé da curva: y = 6,25 x².
      expect(TemaMaquete.pbrNeutral([0.02, 0.02, 0.02]).first,
          closeTo(6.25 * 0.0004, 1e-12));
    });

    test('a cor de cena sai na tela como a cor exata do fantasma', () {
      for (final tema in [TemaMaquete.claro, TemaMaquete.escuro]) {
        final tela = TemaMaquete.pbrNeutral(tema.fantasmaNaCena.sublist(0, 3));
        final srgb = [for (final v in tela) TemaMaquete.paraSrgb(v) * 255];
        expect(srgb[0], closeTo(tema.fantasma.r * 255, 0.01));
        expect(srgb[1], closeTo(tema.fantasma.g * 255, 0.01));
        expect(srgb[2], closeTo(tema.fantasma.b * 255, 0.01));
        expect(tema.fantasmaNaCena[3], 1);
      }
    });

    test('a inversa vale também no pé da curva', () {
      for (final y in [0.001, 0.01, 0.03, 0.1, 0.5, 0.6]) {
        final x = TemaMaquete.antesDaCurva([y, y * 1.1, y * 0.9]);
        final volta = TemaMaquete.pbrNeutral(x);
        expect(volta[0], closeTo(y, 1e-9));
        expect(volta[1], closeTo(y * 1.1, 1e-9));
        expect(volta[2], closeTo(y * 0.9, 1e-9));
      }
    });

    test('sRGB <-> linear', () {
      for (var v = 0.0; v <= 1; v += 0.05) {
        expect(
            TemaMaquete.paraSrgb(TemaMaquete.paraLinear(v)), closeTo(v, 1e-9));
      }
    });
  });

  group('CameraMaquete', () {
    final base = 26.99 * math.pi / 180;

    test('caixa 3:2 ou mais larga: mesmo campo vertical da imagem', () {
      expect(CameraMaquete.fovVerticalPara(1.5), closeTo(base, 1e-12));
      expect(CameraMaquete.fovVerticalPara(2.4), closeTo(base, 1e-12));
      expect(CameraMaquete.fovVerticalPara(0), closeTo(base, 1e-12));
      expect(CameraMaquete.fovVerticalPara(double.nan), closeTo(base, 1e-12));
    });

    test('caixa mais estreita: a largura da imagem manda', () {
      // Numa caixa 1:1 a imagem ocupa a largura; o campo horizontal da
      // câmera tem de ser o da imagem.
      final fov = CameraMaquete.fovVerticalPara(1);
      final horizontal = 2 * math.atan(math.tan(fov / 2) * 1);
      final horizontalImagem = 2 * math.atan(math.tan(base / 2) * 1.5);
      expect(horizontal, closeTo(horizontalImagem, 1e-12));
    });

    test('girar mantém altura e distância ao eixo, e volta com 2π', () {
      final p = CameraMaquete.posicao;
      final r = math.sqrt(p[0] * p[0] + p[2] * p[2]);
      for (final a in [0.3, -1.2, math.pi]) {
        final g = CameraMaquete.girar(p, a);
        expect(g[1], p[1]);
        expect(math.sqrt(g[0] * g[0] + g[2] * g[2]), closeTo(r, 1e-9));
      }
      final volta = CameraMaquete.girar(p, 2 * math.pi);
      for (var i = 0; i < 3; i++) {
        expect(volta[i], closeTo(p[i], 1e-9));
      }
    });

    test('giro positivo leva a câmera para a esquerda da tela', () {
      // Direita da tela no flutter_scene (mão esquerda): up x forward.
      final p = CameraMaquete.posicao, a = CameraMaquete.alvo;
      final f = [a[0] - p[0], a[1] - p[1], a[2] - p[2]];
      final direita = [f[2], 0.0, -f[0]]; // (0,1,0) x f
      final g = CameraMaquete.girar(p, 0.01);
      final passo = [g[0] - p[0], g[1] - p[1], g[2] - p[2]];
      final projecao =
          passo[0] * direita[0] + passo[1] * direita[1] + passo[2] * direita[2];
      expect(projecao, lessThan(0));
    });
  });
}
