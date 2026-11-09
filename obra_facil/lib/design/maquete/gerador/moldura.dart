// Formas posicionadas por um referencial local (u ao longo de uma parede, v
// para dentro do cômodo, h para cima): é como os móveis, as árvores e o
// carro são desenhados, sem se preocupar com a direção da parede.

import 'dart:math' as math;

import 'geometria.dart';

/// Referencial de desenho: origem no chão da cena (X, Z do glTF) na altura
/// [y0]; [eixoU] e [eixoV] unitários e perpendiculares no plano XZ.
class Moldura {
  Moldura(
    this.malha, {
    required this.origem,
    required this.eixoU,
    (double, double)? eixoV,
    this.y0 = 0,
  }) : eixoV = eixoV ?? (-eixoU.$2, eixoU.$1);

  final MalhaGerada malha;
  final (double, double) origem;
  final (double, double) eixoU;
  final (double, double) eixoV;
  final double y0;

  /// O mesmo referencial deslocado [du], [dv] e [dh], e girado [giro]
  /// radianos em volta do eixo vertical (de u para v).
  Moldura mover(
      {double du = 0, double dv = 0, double dh = 0, double giro = 0}) {
    final (x, z) = _xz(du, dv);
    final c = math.cos(giro), s = math.sin(giro);
    final u = (eixoU.$1 * c + eixoV.$1 * s, eixoU.$2 * c + eixoV.$2 * s);
    final v = (eixoV.$1 * c - eixoU.$1 * s, eixoV.$2 * c - eixoU.$2 * s);
    return Moldura(malha, origem: (x, z), eixoU: u, eixoV: v, y0: y0 + dh);
  }

  (double, double) _xz(double u, double v) => (
        origem.$1 + eixoU.$1 * u + eixoV.$1 * v,
        origem.$2 + eixoU.$2 * u + eixoV.$2 * v,
      );

  /// O ponto local (u, v, h) na cena.
  P3 p(double u, double v, double h) {
    final (x, z) = _xz(u, v);
    return (x, y0 + h, z);
  }

  /// Uma direção local na cena (sem a origem).
  P3 _dir(double u, double v, double h) => (
        eixoU.$1 * u + eixoV.$1 * v,
        h,
        eixoU.$2 * u + eixoV.$2 * v,
      );

  /// Caixa de [u0] a [u1], [v0] a [v1] e [h0] a [h1]. Com [chanfro], as
  /// doze arestas saem cortadas a 45°: a quina pega luz e a peça parece
  /// acabada, não um bloco.
  void caixa(String material, double u0, double u1, double v0, double v1,
      double h0, double h1,
      {double chanfro = 0, bool semBase = false}) {
    if (u1 < u0) (u0, u1) = (u1, u0);
    if (v1 < v0) (v0, v1) = (v1, v0);
    if (u1 - u0 < 1e-5 || v1 - v0 < 1e-5 || h1 - h0 < 1e-5) return;
    final l = malha.lote(material);
    final cu = (u0 + u1) / 2, cv = (v0 + v1) / 2, ch = (h0 + h1) / 2;
    final centro = p(cu, cv, ch);
    final c =
        math.min(chanfro, math.min(u1 - u0, math.min(v1 - v0, h1 - h0)) * 0.45);
    if (c <= 1e-4) {
      final a = p(u0, v0, h0), b = p(u1, v0, h0);
      final cc = p(u1, v1, h0), d = p(u0, v1, h0);
      final e = p(u0, v0, h1), f = p(u1, v0, h1);
      final g = p(u1, v1, h1), hh = p(u0, v1, h1);
      if (!semBase) l.quadFora(a, b, cc, d, centro);
      l
        ..quadFora(e, f, g, hh, centro)
        ..quadFora(a, b, f, e, centro)
        ..quadFora(b, cc, g, f, centro)
        ..quadFora(cc, d, hh, g, centro)
        ..quadFora(d, a, e, hh, centro);
      return;
    }
    // Meias-medidas e o ponto em coordenadas relativas ao centro.
    final hu = (u1 - u0) / 2, hv = (v1 - v0) / 2, hh = (h1 - h0) / 2;
    P3 q(double su, double a, double sv, double b, double sh, double d) =>
        p(cu + su * a, cv + sv * b, ch + sh * d);
    for (final su in const [-1.0, 1.0]) {
      for (final sv in const [-1.0, 1.0]) {
        for (final sh in const [-1.0, 1.0]) {
          // Canto: o triângulo entre as três faces.
          l.trianguloFora(
            q(su, hu, sv, hv - c, sh, hh - c),
            q(su, hu - c, sv, hv, sh, hh - c),
            q(su, hu - c, sv, hv - c, sh, hh),
            centro,
          );
        }
      }
    }
    // Faces (encolhidas pelo chanfro).
    for (final s in const [-1.0, 1.0]) {
      l
        ..quadFora(
            q(s, hu, -1, hv - c, -1, hh - c),
            q(s, hu, 1, hv - c, -1, hh - c),
            q(s, hu, 1, hv - c, 1, hh - c),
            q(s, hu, -1, hv - c, 1, hh - c),
            centro)
        ..quadFora(
            q(-1, hu - c, s, hv, -1, hh - c),
            q(1, hu - c, s, hv, -1, hh - c),
            q(1, hu - c, s, hv, 1, hh - c),
            q(-1, hu - c, s, hv, 1, hh - c),
            centro);
      if (s > 0 || !semBase) {
        l.quadFora(
            q(-1, hu - c, -1, hv - c, s, hh),
            q(1, hu - c, -1, hv - c, s, hh),
            q(1, hu - c, 1, hv - c, s, hh),
            q(-1, hu - c, 1, hv - c, s, hh),
            centro);
      }
    }
    // Arestas: as 12 faixas a 45°.
    for (final a in const [-1.0, 1.0]) {
      for (final b in const [-1.0, 1.0]) {
        // Paralelas a h.
        l.quadFora(
            q(a, hu, b, hv - c, -1, hh - c),
            q(a, hu - c, b, hv, -1, hh - c),
            q(a, hu - c, b, hv, 1, hh - c),
            q(a, hu, b, hv - c, 1, hh - c),
            centro);
        // Paralelas a v.
        l.quadFora(
            q(a, hu, -1, hv - c, b, hh - c),
            q(a, hu - c, -1, hv - c, b, hh),
            q(a, hu - c, 1, hv - c, b, hh),
            q(a, hu, 1, hv - c, b, hh - c),
            centro);
        // Paralelas a u.
        l.quadFora(
            q(-1, hu - c, a, hv, b, hh - c),
            q(-1, hu - c, a, hv - c, b, hh),
            q(1, hu - c, a, hv - c, b, hh),
            q(1, hu - c, a, hv, b, hh - c),
            centro);
      }
    }
  }

  /// Cilindro em pé (ou tronco de cone com [raioTopo]), lado liso.
  void cilindro(String material, double u, double v, double h0, double altura,
      double raio,
      {double? raioTopo, int lados = 16, bool tampas = true}) {
    cilindroEntre(material, (u, v, h0), (u, v, h0 + altura), raio,
        raioFim: raioTopo, lados: lados, tampas: tampas);
  }

  /// Cilindro liso de [a] a [b] (pontos locais), em qualquer direção:
  /// rodas, canos, rolos de almofada, pés inclinados.
  void cilindroEntre(String material, (double, double, double) a,
      (double, double, double) b, double raio,
      {double? raioFim, int lados = 14, bool tampas = true}) {
    final l = malha.lote(material);
    final pa = p(a.$1, a.$2, a.$3), pb = p(b.$1, b.$2, b.$3);
    final eixo = _unit((pb.$1 - pa.$1, pb.$2 - pa.$2, pb.$3 - pa.$3));
    final ref = eixo.$2.abs() > 0.9 ? (1.0, 0.0, 0.0) : (0.0, 1.0, 0.0);
    final x = _unit(_cruz(eixo, ref));
    final y = _cruz(eixo, x);
    final rb = raioFim ?? raio;
    P3 anel(P3 c, double r, double ang) => (
          c.$1 + (x.$1 * math.cos(ang) + y.$1 * math.sin(ang)) * r,
          c.$2 + (x.$2 * math.cos(ang) + y.$2 * math.sin(ang)) * r,
          c.$3 + (x.$3 * math.cos(ang) + y.$3 * math.sin(ang)) * r,
        );
    P3 normal(double ang) => (
          x.$1 * math.cos(ang) + y.$1 * math.sin(ang),
          x.$2 * math.cos(ang) + y.$2 * math.sin(ang),
          x.$3 * math.cos(ang) + y.$3 * math.sin(ang),
        );
    final meio =
        ((pa.$1 + pb.$1) / 2, (pa.$2 + pb.$2) / 2, (pa.$3 + pb.$3) / 2);
    for (var i = 0; i < lados; i++) {
      final t0 = 2 * math.pi * i / lados, t1 = 2 * math.pi * (i + 1) / lados;
      final a0 = anel(pa, raio, t0), a1 = anel(pa, raio, t1);
      final b0 = anel(pb, rb, t0), b1 = anel(pb, rb, t1);
      final n0 = normal(t0), n1 = normal(t1);
      _liso(l, a0, n0, a1, n1, b1, n1);
      _liso(l, a0, n0, b1, n1, b0, n0);
      if (tampas) {
        l
          ..trianguloFora(pa, a0, a1, meio)
          ..trianguloFora(pb, b1, b0, meio);
      }
    }
  }

  /// Esfera lisa (ou elipsoide, achatada por [escalaH]) com centro em (u,
  /// v, h): copa, almofada redonda, luminária.
  void esfera(String material, double u, double v, double h, double raio,
      {double escalaH = 1, int anel = 14, int fatias = 9, bool liso = true}) {
    final l = malha.lote(material);
    final c = p(u, v, h);
    P3 ponto(int i, int j) {
      final fi = math.pi * j / fatias, te = 2 * math.pi * i / anel;
      final d = _dir(math.sin(fi) * math.cos(te), math.sin(fi) * math.sin(te),
          math.cos(fi) * escalaH);
      return (c.$1 + d.$1 * raio, c.$2 + d.$2 * raio, c.$3 + d.$3 * raio);
    }

    P3 normal(P3 q) => _unit((
          (q.$1 - c.$1),
          (q.$2 - c.$2) / (escalaH * escalaH),
          (q.$3 - c.$3),
        ));
    for (var j = 0; j < fatias; j++) {
      for (var i = 0; i < anel; i++) {
        final a = ponto(i, j), b = ponto(i, j + 1);
        final cc = ponto(i + 1, j + 1), d = ponto(i + 1, j);
        if (!liso) {
          if (j > 0) l.trianguloFora(a, b, d, c);
          if (j < fatias - 1) l.trianguloFora(b, cc, d, c);
          continue;
        }
        if (j > 0) _liso(l, a, normal(a), b, normal(b), d, normal(d));
        if (j < fatias - 1) {
          _liso(l, b, normal(b), cc, normal(cc), d, normal(d));
        }
      }
    }
  }

  /// Prisma em pé de base convexa [base] (pontos u, v), de [h0] a [h1].
  void prisma(
      String material, List<(double, double)> base, double h0, double h1) {
    final l = malha.lote(material);
    final n = base.length;
    final cu = base.fold<double>(0, (s, q) => s + q.$1) / n;
    final cv = base.fold<double>(0, (s, q) => s + q.$2) / n;
    final centro = p(cu, cv, (h0 + h1) / 2);
    for (var i = 1; i + 1 < n; i++) {
      final a = base[0], b = base[i], c = base[i + 1];
      l
        ..trianguloFora(
            p(a.$1, a.$2, h1), p(b.$1, b.$2, h1), p(c.$1, c.$2, h1), centro)
        ..trianguloFora(
            p(a.$1, a.$2, h0), p(b.$1, b.$2, h0), p(c.$1, c.$2, h0), centro);
    }
    for (var i = 0; i < n; i++) {
      final a = base[i], b = base[(i + 1) % n];
      l.quadFora(p(a.$1, a.$2, h0), p(b.$1, b.$2, h0), p(b.$1, b.$2, h1),
          p(a.$1, a.$2, h1), centro);
    }
  }

  /// Perfil convexo [perfil] (pontos u, h) puxado de [v0] a [v1]: a lateral
  /// do carro, o encosto inclinado, a cuba.
  void perfil(
      String material, List<(double, double)> perfil, double v0, double v1) {
    final l = malha.lote(material);
    final n = perfil.length;
    final cu = perfil.fold<double>(0, (s, q) => s + q.$1) / n;
    final chh = perfil.fold<double>(0, (s, q) => s + q.$2) / n;
    final centro = p(cu, (v0 + v1) / 2, chh);
    for (var i = 1; i + 1 < n; i++) {
      final a = perfil[0], b = perfil[i], c = perfil[i + 1];
      l
        ..trianguloFora(
            p(a.$1, v0, a.$2), p(b.$1, v0, b.$2), p(c.$1, v0, c.$2), centro)
        ..trianguloFora(
            p(a.$1, v1, a.$2), p(b.$1, v1, b.$2), p(c.$1, v1, c.$2), centro);
    }
    for (var i = 0; i < n; i++) {
      final a = perfil[i], b = perfil[(i + 1) % n];
      l.quadFora(p(a.$1, v0, a.$2), p(b.$1, v0, b.$2), p(b.$1, v1, b.$2),
          p(a.$1, v1, a.$2), centro);
    }
  }

  /// Placa vertical fina no plano u-h (quadro, espelho, tela), de [v0] a
  /// [v1] de espessura.
  void placa(String material, double u0, double u1, double h0, double h1,
          double v0, double v1) =>
      caixa(material, u0, u1, v0, v1, h0, h1);

  static void _liso(LoteMaterial l, P3 a, P3 na, P3 b, P3 nb, P3 c, P3 nc) {
    // A face tem de ficar de frente para o lado das normais.
    final u = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
    final v = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
    final f = _cruz(u, v);
    final m =
        (na.$1 + nb.$1 + nc.$1, na.$2 + nb.$2 + nc.$2, na.$3 + nb.$3 + nc.$3);
    if (f.$1 * m.$1 + f.$2 * m.$2 + f.$3 * m.$3 >= 0) {
      l.trianguloLiso(a, na, b, nb, c, nc);
    } else {
      l.trianguloLiso(a, na, c, nc, b, nb);
    }
  }

  static P3 _cruz(P3 a, P3 b) => (
        a.$2 * b.$3 - a.$3 * b.$2,
        a.$3 * b.$1 - a.$1 * b.$3,
        a.$1 * b.$2 - a.$2 * b.$1,
      );

  static P3 _unit(P3 a) {
    final c = math.sqrt(a.$1 * a.$1 + a.$2 * a.$2 + a.$3 * a.$3);
    return c == 0 ? (0, 1, 0) : (a.$1 / c, a.$2 / c, a.$3 / c);
  }
}
