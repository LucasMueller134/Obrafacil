// O geminado na fachada desenhada (fachada_geminado.dxf): no tamanho-padrão
// cada casa tem 6 m de frente e 7 m de altura, porta da garagem de 3,40 m e
// pivotante de 1,40 m (as duas com 2,60 m do chão), moldura de 5,60 m com a
// sacada, ripado em L, porta de correr de 3,20 m e a aleta na divisa. Casa
// maior ou menor: a frente vai de 5 a 8 m e as peças acompanham.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/gerador/gerador_maquete.dart';
import 'package:obra_facil/design/maquete/gerador/glb.dart';
import 'package:obra_facil/models/models.dart';

/// Os vãos de um tipo, com o x do começo (paredes deitadas).
List<(double, double, double)> _vaos(PlantaObra p, TipoAbertura tipo) => [
      for (final w in p.paredes)
        for (final a in w.aberturas)
          if (a.tipo == tipo)
            (w.pontoEm(a.inicio).$1, a.largura, a.altura ?? 0),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

PlantaObra _geminado(double area, {int quartos = 3, int casas = 2}) =>
    ModelosPlanta.montar(PedidoModelo(
      tipo: TipoModelo.geminado,
      area: area,
      quartos: quartos,
      unidades: casas,
      sobrado: true,
    ));

Map<String, dynamic> _jsonDoGlb(Uint8List glb) {
  final bd = ByteData.sublistView(glb);
  final tamanho = bd.getUint32(12, Endian.little);
  return jsonDecode(utf8.decode(glb.sublist(20, 20 + tamanho)))
      as Map<String, dynamic>;
}

void main() {
  group('tamanho-padrão (2 sobrados de 160 m²)', () {
    final p = _geminado(160);
    final superior = p.planta(1);

    test('6 m de frente por casa e 7 m de altura', () {
      expect(ModelosPlanta.larguraGeminado(160), 6.0);
      expect(p.largura, 12.0);
      final topo =
          0.2 + 2 * (p.alturas.peDireito + 0.12) + p.alturas.platibanda;
      expect(topo, closeTo(7.0, 0.001));
    });

    test('térreo: porta da garagem e pivotante onde o desenho põe', () {
      final garagem = _vaos(p, TipoAbertura.portaGaragem);
      final pivo = _vaos(p, TipoAbertura.portaPivotante);
      expect(garagem.length, 2);
      expect(pivo.length, 2);
      for (final (i, x0) in [0.0, 6.0].indexed) {
        expect(garagem[i].$1, closeTo(x0 + 0.40, 0.01));
        expect(garagem[i].$2, closeTo(3.40, 0.01));
        expect(garagem[i].$3, closeTo(2.40, 0.01));
        expect(pivo[i].$1, closeTo(x0 + 4.20, 0.01));
        expect(pivo[i].$2, closeTo(1.40, 0.01));
      }
      // Frente aberta para a rua, sem portão de muro.
      expect(_vaos(p, TipoAbertura.portao), isEmpty);
    });

    test('em cima: porta de correr de 3,20 m a 1,90 m da divisa', () {
      final correr = _vaos(superior, TipoAbertura.portaCorrer);
      expect(correr.length, 2);
      expect(correr.first.$1, closeTo(1.90, 0.01));
      expect(correr.first.$2, closeTo(3.20, 0.01));
      // Até o fundo da viga: 5,62 m do chão.
      expect(0.2 + 2.92 + correr.first.$3, closeTo(5.62, 0.001));
    });

    test('moldura, ripado em L e aleta com as medidas do desenho', () {
      final f = superior.fachada;
      final molduras =
          f.where((e) => e.tipo == TipoElementoFachada.moldura).toList();
      expect(molduras.length, 2);
      final m = molduras.first;
      expect(m.de, closeTo(0.2, 0.001));
      expect(m.ate, closeTo(5.8, 0.001));
      expect(m.borda, 0.5);
      // De 2,80 a 6,40 m do chão; a faixa de baixo até 3,30 m.
      expect(3.12 + m.base, closeTo(2.80, 0.001));
      expect(3.12 + m.topo, closeTo(6.40, 0.001));
      expect(3.12 + m.peitoril!, closeTo(3.30, 0.001));
      final vertical =
          f.firstWhere((e) => e.tipo == TipoElementoFachada.ripadoVertical);
      expect(vertical.de, closeTo(0.7, 0.001));
      expect(vertical.largura, closeTo(1.0, 0.001));
      final deitado =
          f.firstWhere((e) => e.tipo == TipoElementoFachada.ripadoHorizontal);
      expect(deitado.de, closeTo(1.7, 0.001));
      expect(deitado.topo - deitado.base, closeTo(0.30, 0.001));
      // A aleta fica no térreo e sobe até o topo.
      final aleta =
          p.fachada.singleWhere((e) => e.tipo == TipoElementoFachada.aleta);
      expect((aleta.de + aleta.ate) / 2, closeTo(6.0, 0.001));
      expect(0.2 + aleta.topo, closeTo(7.0, 0.001));
    });

    test('nenhuma janela na divisa do terreno', () {
      for (var i = 0; i < p.totalPlantas; i++) {
        for (final w in p.planta(i).paredes) {
          final naDivisa = w.de.$1 == w.ate.$1 &&
              (w.de.$1.abs() < 0.01 || (w.de.$1 - p.largura).abs() < 0.01);
          if (!naDivisa) continue;
          expect(w.aberturas.where((a) => a.tipo.ehJanela), isEmpty,
              reason: w.id);
        }
      }
    });

    test('a maquete tem moldura grafite, cumaru, portão e LED', () {
      final m = GeradorMaquete.gerar(p);
      expect(m.modelo.triangulos,
          lessThanOrEqualTo(GeradorMaquete.limiteDeTriangulos));
      final glb = escreverGlb(m.modelo);
      final materiais = {
        for (final mat in _jsonDoGlb(glb)['materials'] as List)
          (mat as Map)['name'],
      };
      expect(
          materiais,
          containsAll(
              ['grafite', 'madeira_cumaru', 'portao_laminas', 'luz_led']));
      // O topo da maquete chega nos 7 m (a platibanda).
      expect(m.niveis.platibandaTopo + 2.92, closeTo(7.0, 0.001));
    });
  });

  test('casa maior ou menor: a frente e as peças acompanham', () {
    expect(ModelosPlanta.larguraGeminado(100), 5.0);
    expect(ModelosPlanta.larguraGeminado(150), 6.0);
    expect(ModelosPlanta.larguraGeminado(220), 7.0);
    expect(ModelosPlanta.larguraGeminado(300), 8.0);
    for (final area in [110.0, 150.0, 220.0, 250.0]) {
      final w = ModelosPlanta.larguraGeminado(area);
      final p = _geminado(area, quartos: 2);
      final moldura = p
          .planta(1)
          .fachada
          .firstWhere((e) => e.tipo == TipoElementoFachada.moldura);
      expect(moldura.largura, closeTo(w - 0.4, 0.001), reason: '$area m²');
      final portao = _vaos(p, TipoAbertura.portaGaragem).first;
      // A garagem é a frente menos a faixa do hall (2,4 m a partir de
      // 7,5 m de frente, com dois carros); o portão, 60 cm menor que ela.
      final garagem = w - (w >= 7.5 ? 2.4 : 2.0);
      expect(portao.$2, closeTo((garagem - 0.6).clamp(2.4, 5.0), 0.01),
          reason: '$area m²');
    }
  });

  test('quartos lado a lado nos fundos: o limite depende da frente', () {
    expect(ModelosPlanta.maxQuartosGeminado(110), 3);
    expect(ModelosPlanta.maxQuartosGeminado(250), 4);
    expect(
        const PedidoModelo(
                tipo: TipoModelo.geminado, area: 160, quartos: 4, sobrado: true)
            .problema,
        contains('até 3 quartos'));
    final p = _geminado(250, quartos: 4);
    final quartos =
        p.planta(1).comodos.where((c) => c.nome.startsWith('Quarto ')).length;
    expect(quartos, 3 * 2);
  });

  test('o geminado térreo também ganha a fachada', () {
    for (final area in [75.0, 110.0]) {
      final p = ModelosPlanta.montar(PedidoModelo(
          tipo: TipoModelo.geminado, area: area, quartos: 2, unidades: 2));
      expect(_vaos(p, TipoAbertura.portaPivotante).length, 2,
          reason: '$area m²');
      expect(
          p.fachada.where((e) => e.tipo == TipoElementoFachada.moldura).length,
          2);
      expect(p.fachada.where((e) => e.tipo == TipoElementoFachada.aleta).length,
          1);
      expect(_vaos(p, TipoAbertura.portao), isEmpty, reason: '$area m²');
    }
  });
}
