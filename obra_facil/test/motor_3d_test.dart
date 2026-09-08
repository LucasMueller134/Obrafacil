import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/widgets/tres_d/motor_3d.dart';

const _vermelho = Color(0xFFFF0000);

void main() {
  group('Álgebra dos vetores', () {
    test('produto vetorial dá a normal da face', () {
      // Face no plano XY, vértices anti-horários: normal para +Z.
      const a = Vetor3(0, 0, 0);
      const b = Vetor3(1, 0, 0);
      const c = Vetor3(0, 1, 0);
      final normal = (b - a).cross(c - a).normalizado;
      expect(normal.x, closeTo(0, 1e-9));
      expect(normal.y, closeTo(0, 1e-9));
      expect(normal.z, closeTo(1, 1e-9));
    });

    test('normalizar não quebra com vetor nulo', () {
      expect(Vetor3.zero.normalizado.comprimento, 0);
    });

    test('girar meia volta em Y inverte X e Z', () {
      const p = Vetor3(1, 2, 3);
      final g = p.girarY(math.pi);
      expect(g.x, closeTo(-1, 1e-9));
      expect(g.y, closeTo(2, 1e-9)); // eixo do giro não muda
      expect(g.z, closeTo(-3, 1e-9));
    });

    test('girar preserva o comprimento', () {
      const p = Vetor3(1.5, -2, 0.75);
      expect(p.girarY(0.7).comprimento, closeTo(p.comprimento, 1e-9));
      expect(p.girarX(1.3).comprimento, closeTo(p.comprimento, 1e-9));
    });
  });

  group('Câmera e perspectiva', () {
    const camera = Camera3D(giro: 0, inclinacao: 0, distancia: 10, foco: 7);

    test('o que está longe encolhe', () {
      final perto = camera.projetar(const Vetor3(1, 0, 2));
      final longe = camera.projetar(const Vetor3(1, 0, -2));
      expect(longe.dx.abs(), lessThan(perto.dx.abs()));
    });

    test('a origem cai no centro da tela', () {
      final centro = camera.projetar(Vetor3.zero);
      expect(centro.dx, closeTo(0, 1e-9));
      expect(centro.dy, closeTo(0, 1e-9));
    });

    test('Y do mundo para cima vira Y da tela para cima', () {
      // No canvas o Y cresce para baixo, então o topo tem dy negativo.
      expect(camera.projetar(const Vetor3(0, 1, 0)).dy, lessThan(0));
    });
  });

  group('Rasterização de um cubo', () {
    final cubo = Malha.caixa(
      centro: Vetor3.zero,
      tamanho: const Vetor3(2, 2, 2),
      cor: _vermelho,
    );

    test('o cubo tem 8 vértices e 6 faces', () {
      expect(cubo.vertices, hasLength(8));
      expect(cubo.faces, hasLength(6));
    });

    test('as costas são descartadas: nunca mais de 3 faces visíveis', () {
      // De qualquer ângulo, um cubo mostra no máximo três lados.
      for (var passo = 0; passo < 24; passo++) {
        final camera = Camera3D(
          giro: passo * math.pi / 12,
          inclinacao: 0.4,
          distancia: 9,
        );
        final visiveis = camera.renderizar([cubo]);
        expect(visiveis.length, inclusiveRangeMatcher(1, 3),
            reason: 'giro ${passo * 15}°');
      }
    });

    test('as faces saem ordenadas do fundo para a frente', () {
      const camera = Camera3D(giro: 0.5, inclinacao: 0.4, distancia: 9);
      final faces = camera.renderizar([cubo]);
      for (var i = 1; i < faces.length; i++) {
        expect(faces[i].profundidade,
            greaterThanOrEqualTo(faces[i - 1].profundidade));
      }
    });

    test('a face virada para a luz fica mais clara que a de sombra', () {
      // Luz vindo de cima: o topo tem de sair mais claro que a lateral.
      const camera = Camera3D(
        giro: 0.6,
        inclinacao: 0.6,
        distancia: 9,
        luz: Vetor3(0, 1, 0),
      );
      final faces = camera.renderizar([cubo]);
      final luminancias = [
        for (final f in faces) f.corClara.computeLuminance(),
      ];
      expect(luminancias.reduce(math.max),
          greaterThan(luminancias.reduce(math.min)),
          reason: 'sem variação de luz a maquete vira uma mancha chapada');
    });

    test('a cor iluminada mantém a opacidade original', () {
      const camera = Camera3D(distancia: 9);
      for (final face in camera.renderizar([cubo])) {
        expect(face.corClara.a, 1.0);
        expect(face.corEscura.a, 1.0);
      }
    });

    test('cada face tem gradiente entre extremo claro e escuro', () {
      // Sem essa variação a face vira mancha chapada — o que dava
      // aparência de desenho em vez de maquete.
      const camera = Camera3D(giro: 0.6, inclinacao: 0.45, distancia: 9);
      final faces = camera.renderizar([
        Malha.caixa(
          centro: Vetor3.zero,
          tamanho: const Vetor3(2, 3, 2),
          cor: _vermelho,
        )
      ]);
      final verticais = faces.where((f) => f.inicioLuz != f.fimLuz);
      expect(verticais, isNotEmpty);
      for (final face in verticais) {
        expect(face.corClara.computeLuminance(),
            greaterThan(face.corEscura.computeLuminance()));
      }
    });

    test('cena vazia não quebra', () {
      const camera = Camera3D();
      expect(camera.renderizar(const <Malha>[]), isEmpty);
      expect(camera.projetarSombra(const <Malha>[]).silhuetas, isEmpty);
    });
  });

  group('Sombra projetada', () {
    test('a silhueta acompanha a cena, e não um borrão fixo', () {
      final caixa = Malha.caixa(
        centro: const Vetor3(0, 0, 0),
        tamanho: const Vetor3(2, 2, 2),
        cor: _vermelho,
      );
      const camera = Camera3D(giro: 0.4, inclinacao: 0.45, distancia: 9);
      final sombra = camera.projetarSombra([caixa]);
      expect(sombra.silhuetas, isNotEmpty);
      // Girar a cena muda a sombra: prova que ela é projetada, não colada.
      const outra = Camera3D(giro: 1.8, inclinacao: 0.45, distancia: 9);
      final sombra2 = outra.projetarSombra([caixa]);
      expect(sombra2.silhuetas.first.first,
          isNot(sombra.silhuetas.first.first));
    });

    test('o que está no chão não lança sombra sobre si mesmo', () {
      // Terreno colado no chão: nada a projetar.
      final terreno = Malha.caixa(
        centro: const Vetor3(0, Camera3D.chao, 0),
        tamanho: const Vetor3(6, 0.02, 6),
        cor: _vermelho,
      );
      const camera = Camera3D();
      expect(camera.projetarSombra([terreno]).silhuetas, isEmpty);
    });
  });

  group('Formas do canteiro', () {
    test('telhado de duas águas tem cumeeira acima da base', () {
      final telhado = Malha.telhado(
        centroBase: Vetor3.zero,
        largura: 4,
        profundidade: 2,
        altura: 1,
        cor: _vermelho,
      );
      expect(telhado.vertices, hasLength(6));
      final alturas = telhado.vertices.map((v) => v.y).toList();
      expect(alturas.reduce(math.max), 1.0);
      expect(alturas.reduce(math.min), 0.0);
    });

    test('cilindro fecha o topo e tem uma face por lado', () {
      final tambor = Malha.cilindro(
        centroBase: Vetor3.zero,
        raio: 1,
        altura: 2,
        cor: _vermelho,
        lados: 8,
      );
      expect(tambor.vertices, hasLength(16)); // 8 lados × base e topo
      expect(tambor.faces, hasLength(9)); // 8 laterais + 1 tampa
    });

    test('transladar move todo mundo junto', () {
      final caixa = Malha.caixa(
        centro: Vetor3.zero,
        tamanho: const Vetor3(1, 1, 1),
        cor: _vermelho,
      );
      final movida = caixa.transladar(const Vetor3(5, 0, 0));
      for (var i = 0; i < caixa.vertices.length; i++) {
        expect(movida.vertices[i].x, caixa.vertices[i].x + 5);
      }
      expect(movida.faces, same(caixa.faces));
    });
  });
}

Matcher inclusiveRangeMatcher(int min, int max) =>
    allOf(greaterThanOrEqualTo(min), lessThanOrEqualTo(max));
