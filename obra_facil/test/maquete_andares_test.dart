// A maquete de sobrado, geminado e prédio: os pavimentos empilhados, a
// alvenaria nas 15 etapas de baixo para cima, a cobertura só no topo e um
// tamanho que o celular aguenta.

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/gerador/gerador_maquete.dart';
import 'package:obra_facil/design/maquete/gerador/glb.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';
import 'package:obra_facil/models/models.dart';

/// Altura (y) mais alta dos vértices de um nó, já na cena.
double _topo(MaqueteGerada m, String nome) {
  final no = m.modelo.raiz.procurar(nome)!;
  var maior = double.negativeInfinity;
  for (final lote in no.malha.lotes.values) {
    for (var i = 1; i < lote.posicoes.length; i += 3) {
      final y = lote.posicoes[i] + no.translacao.$2;
      if (y > maior) maior = y;
    }
  }
  return maior;
}

void main() {
  final pedidos = {
    'sobrado': const PedidoModelo(
        tipo: TipoModelo.casa, area: 150, quartos: 3, sobrado: true),
    'geminado de 4 sobrados': const PedidoModelo(
        tipo: TipoModelo.geminado,
        area: 120,
        quartos: 2,
        unidades: 4,
        sobrado: true),
    'prédio de 12 aptos': const PedidoModelo(
        tipo: TipoModelo.predio,
        area: 60,
        quartos: 2,
        apartamentos: 12,
        andares: 4),
    'prédio de 80 aptos em 20 andares': const PedidoModelo(
        tipo: TipoModelo.predio,
        area: 60,
        quartos: 2,
        apartamentos: 80,
        andares: 20),
  };

  for (final MapEntry(key: nome, value: pedido) in pedidos.entries) {
    test('$nome: gera, cabe no celular e empilha certo', () {
      final planta = ModelosPlanta.montar(pedido);
      final m = GeradorMaquete.gerar(planta);
      // O limite da maquete (o flutter_scene baixa a resolução sozinho se o
      // aparelho não der conta).
      expect(m.modelo.triangulos,
          lessThanOrEqualTo(GeradorMaquete.limiteDeTriangulos),
          reason: nome);
      // O arquivo acompanha o limite de triângulos (uns 70 bytes cada).
      expect(escreverGlb(m.modelo).length, lessThan(48 * 1024 * 1024));

      // Todos os nós do plano existem e as fiadas têm geometria.
      for (final no in PlanoMaquete.todosOsNos) {
        expect(m.modelo.raiz.procurar(no), isNotNull, reason: no);
      }
      final andar = planta.alturas.peDireito + NiveisMaquete.espessuraLaje;
      final total = planta.totalPavimentos;
      // A última fiada de parede fica no último pavimento e a primeira no
      // térreo: a alvenaria sobe de baixo para cima.
      expect(_topo(m, NosMaquete.fiada(0)), lessThan(andar + 0.5));
      expect(_topo(m, NosMaquete.fiada(NosMaquete.totalFiadas - 1)),
          greaterThan((total - 1) * andar));
      // A cobertura e a caixa d'água ficam em cima do último pavimento.
      expect(_topo(m, 'cobertura_telhas'), greaterThan((total - 1) * andar));
      expect(
          _topo(m, 'hidraulica_caixa_dagua'), greaterThan((total - 1) * andar));
      // A laje de cada pavimento: a mais alta no topo.
      expect(_topo(m, 'estrutura_laje'),
          closeTo(total * andar + NiveisMaquete.piso, 0.2));
    });
  }

  test('a casa térrea continua igual (um pavimento só)', () {
    final planta = ModelosPlanta.montar(
        const PedidoModelo(tipo: TipoModelo.casa, area: 90, quartos: 2));
    expect(planta.andares, isEmpty);
    final m = GeradorMaquete.gerar(planta);
    expect(m.modelo.triangulos, lessThan(120000));
    expect(
        _topo(m, 'estrutura_laje'),
        closeTo(
            planta.alturas.peDireito +
                NiveisMaquete.espessuraLaje +
                NiveisMaquete.piso,
            0.05));
  });
}
