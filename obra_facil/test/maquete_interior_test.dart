// A casa mobiliada da vista 360°: a maquete de fora fica sem móveis (mais
// leve), a de dentro vem com os móveis de cada cômodo, uma luminária por
// cômodo coberto, e nenhum móvel na frente de porta.

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/gerador/gerador_maquete.dart';
import 'package:obra_facil/design/maquete/gerador/geometria.dart';
import 'package:obra_facil/models/models.dart';

import 'visual/suporte/dados_exemplo.dart';

final _plantas = <String, PlantaObra Function()>{
  'geminado de 2 sobrados': () => ModelosPlanta.montar(const PedidoModelo(
      tipo: TipoModelo.geminado,
      area: 160,
      quartos: 3,
      unidades: 2,
      sobrado: true)),
  'casa térrea': () => ModelosPlanta.montar(
      const PedidoModelo(tipo: TipoModelo.casa, area: 120, quartos: 3)),
  'casa de exemplo': DadosExemplo.plantaExemplo,
};

/// Os pontos (x e y da planta, altura) de um material em toda a maquete.
List<(double, double, double)> _pontos(MaqueteGerada m, String material) {
  final saida = <(double, double, double)>[];
  for (final no in m.modelo.raiz.todos) {
    final lote = no.malha.lotes[material];
    if (lote == null) continue;
    final (tx, ty, tz) = no.translacao;
    final p = lote.posicoes;
    for (var i = 0; i < p.length; i += 3) {
      final (x, y) = m.paraPlanta(p[i] + tx, p[i + 2] + tz);
      saida.add((x, y, p[i + 1] + ty));
    }
  }
  return saida;
}

Set<String> _materiais(ModeloGerado m) => {
      for (final no in m.raiz.todos)
        for (final e in no.malha.lotes.entries)
          if (e.value.triangulos > 0) e.key,
    };

/// Os materiais que só os móveis usam.
const _moveis = [
  'tecido',
  'roupa_de_cama',
  'madeira_clara',
  'louca',
  'tela_tv',
];

void main() {
  for (final MapEntry(key: nome, value: montar) in _plantas.entries) {
    group(nome, () {
      final planta = montar();
      final fora = GeradorMaquete.gerar(planta);
      final dentro = GeradorMaquete.gerar(planta, interior: true);

      test('de fora sem móveis; por dentro mobiliada e com as luzes', () {
        expect(_materiais(fora.modelo).intersection(_moveis.toSet()), isEmpty);
        expect(_materiais(dentro.modelo), containsAll(_moveis));
        // As árvores e o carro ficam nas duas.
        expect(_materiais(fora.modelo), containsAll(['folhagem', 'tronco']));
        expect(fora.luzes, isEmpty);
        // Uma luminária por cômodo coberto (de todos os pavimentos).
        final cobertos = [
          for (var i = 0; i < planta.totalPlantas; i++)
            for (final c in planta.planta(i).comodos)
              if (c.coberto &&
                  c.principal.largura >= 0.7 &&
                  c.principal.profundidade >= 0.7)
                c.id,
        ];
        expect(dentro.luzes.map((l) => l.comodo).toSet(), cobertos.toSet());
        // Dentro do limite da maquete.
        expect(dentro.modelo.triangulos,
            lessThanOrEqualTo(GeradorMaquete.limiteDeTriangulos));
      });

      test('cada cômodo tem os móveis do tipo dele', () {
        bool tem(String material, RetanguloPlanta r, {double? acimaDe}) =>
            _pontos(dentro, material).any((p) =>
                p.$1 > r.x &&
                p.$1 < r.x1 &&
                p.$2 > r.y &&
                p.$2 < r.y1 &&
                (acimaDe == null || p.$3 > acimaDe));
        final terreo = planta.planta(0);
        for (final c in terreo.comodos.where((c) => c.coberto)) {
          final r = c.principal;
          switch (c.tipo) {
            case 'quarto':
              expect(tem('roupa_de_cama', r), isTrue, reason: c.nome);
            case 'sala':
              expect(tem('madeira_clara', r), isTrue, reason: c.nome);
            case 'banheiro':
              expect(tem('louca', r), isTrue, reason: c.nome);
            case 'cozinha':
              // Bancada (o tampo a 0,9 m do piso) e a cuba de inox.
              expect(tem('granito', r, acimaDe: 0.9), isTrue, reason: c.nome);
              expect(tem('inox', r, acimaDe: 1.0), isTrue, reason: c.nome);
          }
        }
      });

      test('nenhum móvel na frente de porta', () {
        final piso = NiveisMaquete.piso;
        for (var i = 0; i < planta.totalPlantas; i++) {
          final vista = planta.planta(i);
          final y0 = piso +
              i * (planta.alturas.peDireito + NiveisMaquete.espessuraLaje);
          for (final w in vista.paredes) {
            final (dx, dy) = w.direcao;
            for (final a in w.aberturas) {
              if (a.tipo != TipoAbertura.porta &&
                  a.tipo != TipoAbertura.passagem) {
                continue;
              }
              for (final material in _moveis) {
                for (final (x, y, h) in _pontos(dentro, material)) {
                  if (h < y0 + 0.05 || h > y0 + 2.0) continue;
                  final rx = x - w.de.$1, ry = y - w.de.$2;
                  final u = rx * dx + ry * dy;
                  final v = (rx * -dy + ry * dx).abs();
                  final naFrente = u > a.inicio + 0.05 &&
                      u < a.inicio + a.largura - 0.05 &&
                      v < 0.45;
                  expect(naFrente, isFalse,
                      reason: '$material na frente da ${a.tipo.name} '
                          '${a.id} (${x.toStringAsFixed(2)}, '
                          '${y.toStringAsFixed(2)})');
                }
              }
            }
          }
        }
      });
    });
  }
}
