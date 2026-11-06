// Os modelos prontos (casa, geminado e prédio): para uma varredura dos
// números que o dono pode pedir, a planta sai sem problemas, com a área
// perto da pedida, todo cômodo coberto tem porta e a escada fica no mesmo
// lugar em todos os pavimentos.

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/models.dart';

/// Cômodos cobertos que não têm porta nem passagem.
List<String> _semPorta(PlantaObra p) {
  final saida = <String>[];
  for (var i = 0; i < p.totalPlantas; i++) {
    final andar = p.planta(i);
    for (final c in andar.comodosCobertos) {
      final vaos = andar.aberturasDo(c).where((a) => !a.tipo.ehJanela);
      if (vaos.isEmpty) saida.add('${andar.nomeTerreo}: ${c.id}');
    }
  }
  return saida;
}

void _conferir(PedidoModelo pedido, double areaEsperada) {
  final p = ModelosPlanta.montar(pedido);
  final rotulo = pedido.resumo;
  expect(p.problemas(), isEmpty, reason: rotulo);
  expect(_semPorta(p), isEmpty, reason: rotulo);
  // A área construída (cômodos por dentro das paredes) fica perto da
  // pedida: as paredes comem uns 10%.
  expect(p.areaConstruida,
      inInclusiveRange(areaEsperada * 0.7, areaEsperada * 1.3),
      reason: '$rotulo: ${p.areaConstruida.toStringAsFixed(1)} m²');
  expect(p.modelo, pedido.toMap());
  // Volta igual do Firestore.
  final volta = PlantaObra.fromMap(p.toMap());
  expect(volta.toMap(), p.toMap());
  // Escadas no mesmo lugar em todos os pavimentos.
  final escadas = [
    for (var i = 0; i < p.totalPlantas; i++)
      [
        for (final c in p.planta(i).comodos.where((c) => c.tipo == 'escada'))
          (c.principal.x, c.principal.y, c.unidade),
      ],
  ];
  for (final e in escadas.skip(1)) {
    expect(e, escadas.first, reason: '$rotulo: escada fora do lugar');
  }
}

void main() {
  group('casa', () {
    for (final sobrado in [false, true]) {
      for (final area in const <double>[40, 60, 90, 120, 180, 260, 400]) {
        for (var q = 1; q <= 4; q++) {
          final pedido = PedidoModelo(
              tipo: TipoModelo.casa,
              area: area.toDouble(),
              quartos: q,
              sobrado: sobrado);
          if (pedido.problema != null) continue;
          test(pedido.resumo, () => _conferir(pedido, area.toDouble()));
        }
      }
    }
  });

  group('geminado', () {
    for (final sobrado in [false, true]) {
      for (final n in [2, 3, 4]) {
        for (final area in const <double>[50, 75, 110, 150, 200, 250]) {
          final pedido = PedidoModelo(
            tipo: TipoModelo.geminado,
            area: area.toDouble(),
            quartos: PedidoModelo.quartosPara(sobrado ? area / 2 + 20 : area),
            sobrado: sobrado,
            unidades: n,
          );
          if (pedido.problema != null) continue;
          test(pedido.resumo, () {
            _conferir(pedido, area * n);
            final p = ModelosPlanta.montar(pedido);
            expect(p.comodos.map((c) => c.unidade).whereType<String>().toSet(),
                {for (var i = 1; i <= n; i++) 'Casa $i'});
          });
        }
      }
    }
  });

  group('prédio', () {
    for (final (aptos, andares) in [
      (1, 1),
      (2, 1),
      (4, 2),
      (8, 4),
      (12, 4),
      (15, 5),
      (20, 10),
      (32, 8)
    ]) {
      for (final area in const <double>[35, 60, 90]) {
        final pedido = PedidoModelo(
          tipo: TipoModelo.predio,
          area: area.toDouble(),
          quartos: PedidoModelo.quartosPara(area.toDouble()).clamp(1, 3),
          apartamentos: aptos,
          andares: andares,
        );
        if (pedido.problema != null) continue;
        test(pedido.resumo, () {
          final p = ModelosPlanta.montar(pedido);
          expect(p.totalPavimentos, andares);
          // Cada apartamento perto da área pedida.
          final apto1 = p.comodos
              .where((c) => c.unidade == 'Apto 1' && c.coberto)
              .fold<double>(0, (s, c) => s + c.area);
          expect(apto1, inInclusiveRange(area * 0.7, area * 1.3),
              reason: '${pedido.resumo}: apto de $apto1 m²');
          // Os apartamentos e o núcleo (corredor, escada, hall).
          _conferir(pedido, area * pedido.totalApartamentos + andares * 25);
        });
      }
    }
  });

  test('pedidos impossíveis dizem o que corrigir', () {
    expect(const PedidoModelo(tipo: TipoModelo.casa, area: 20).problema,
        contains('35 m²'));
    expect(
        const PedidoModelo(tipo: TipoModelo.casa, area: 50, quartos: 4)
            .problema,
        contains('Pouca área'));
    expect(
        const PedidoModelo(
                tipo: TipoModelo.predio, area: 60, apartamentos: 40, andares: 2)
            .problema,
        contains('por andar'));
    expect(
        () => ModelosPlanta.montar(
            const PedidoModelo(tipo: TipoModelo.casa, area: 20)),
        throwsArgumentError);
  });
}
