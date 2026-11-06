// Geometria da maquete gerada pela planta: malhas por material e a árvore
// de nós do glb, em Dart puro (sem Flutter GPU), para dar para testar e
// gravar o glb em memória.
//
// Coordenadas do glTF: metros, Y para cima, frente da casa (a rua) em +Z.

import 'dart:math' as math;
import 'dart:typed_data';

/// Um ponto 3D (x, y, z) do glTF.
typedef P3 = (double, double, double);

/// Triângulos de um material, com normal por vértice (faces planas).
class LoteMaterial {
  final posicoes = <double>[];
  final normais = <double>[];
  final indices = <int>[];

  int get vertices => posicoes.length ~/ 3;
  int get triangulos => indices.length ~/ 3;

  int _v(P3 p, P3 n) {
    posicoes
      ..add(p.$1)
      ..add(p.$2)
      ..add(p.$3);
    normais
      ..add(n.$1)
      ..add(n.$2)
      ..add(n.$3);
    return vertices - 1;
  }

  /// Quadrilátero plano a-b-c-d (anti-horário visto de fora).
  void quad(P3 a, P3 b, P3 c, P3 d) {
    final n = _normal(a, b, c);
    final i = _v(a, n), j = _v(b, n), k = _v(c, n), l = _v(d, n);
    indices.addAll([i, j, k, i, k, l]);
  }

  void triangulo(P3 a, P3 b, P3 c) {
    final n = _normal(a, b, c);
    indices.addAll([_v(a, n), _v(b, n), _v(c, n)]);
  }

  /// Quadrilátero com a frente (e a normal) para o lado oposto a [dentro]:
  /// a ordem dos vértices não importa.
  void quadFora(P3 a, P3 b, P3 c, P3 d, P3 dentro) {
    if (_paraDentro(a, b, c, dentro)) {
      quad(d, c, b, a);
    } else {
      quad(a, b, c, d);
    }
  }

  /// Triângulo com a frente para o lado oposto a [dentro].
  void trianguloFora(P3 a, P3 b, P3 c, P3 dentro) {
    if (_paraDentro(a, b, c, dentro)) {
      triangulo(c, b, a);
    } else {
      triangulo(a, b, c);
    }
  }

  static bool _paraDentro(P3 a, P3 b, P3 c, P3 dentro) {
    final n = _normal(a, b, c);
    final m = (
      (a.$1 + b.$1 + c.$1) / 3 - dentro.$1,
      (a.$2 + b.$2 + c.$2) / 3 - dentro.$2,
      (a.$3 + b.$3 + c.$3) / 3 - dentro.$3,
    );
    return n.$1 * m.$1 + n.$2 * m.$2 + n.$3 * m.$3 < 0;
  }

  /// Mínimo e máximo das posições (o glTF exige no acessor de POSITION).
  (P3, P3) limites() {
    var mn = (double.infinity, double.infinity, double.infinity);
    var mx = (-double.infinity, -double.infinity, -double.infinity);
    for (var i = 0; i < posicoes.length; i += 3) {
      final x = posicoes[i], y = posicoes[i + 1], z = posicoes[i + 2];
      mn = (math.min(mn.$1, x), math.min(mn.$2, y), math.min(mn.$3, z));
      mx = (math.max(mx.$1, x), math.max(mx.$2, y), math.max(mx.$3, z));
    }
    return (mn, mx);
  }

  static P3 _normal(P3 a, P3 b, P3 c) {
    final u = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
    final v = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
    final n = (
      u.$2 * v.$3 - u.$3 * v.$2,
      u.$3 * v.$1 - u.$1 * v.$3,
      u.$1 * v.$2 - u.$2 * v.$1,
    );
    final c2 = math.sqrt(n.$1 * n.$1 + n.$2 * n.$2 + n.$3 * n.$3);
    if (c2 == 0) return (0, 1, 0);
    return (n.$1 / c2, n.$2 / c2, n.$3 / c2);
  }
}

/// A malha de um nó: um lote de triângulos por material.
class MalhaGerada {
  final Map<String, LoteMaterial> lotes = {};

  LoteMaterial lote(String material) =>
      lotes.putIfAbsent(material, LoteMaterial.new);

  bool get vazia => lotes.values.every((l) => l.triangulos == 0);

  int get triangulos => lotes.values.fold(0, (s, l) => s + l.triangulos);

  /// Junta os triângulos de [outra], subindo [dy] (os andares do prédio).
  void anexar(MalhaGerada outra, {double dy = 0}) {
    for (final MapEntry(key: material, value: origem) in outra.lotes.entries) {
      if (origem.triangulos == 0) continue;
      final destino = lote(material);
      final base = destino.vertices;
      final p = origem.posicoes;
      for (var i = 0; i < p.length; i += 3) {
        destino.posicoes
          ..add(p[i])
          ..add(p[i + 1] + dy)
          ..add(p[i + 2]);
      }
      destino.normais.addAll(origem.normais);
      destino.indices.addAll([for (final i in origem.indices) i + base]);
    }
  }

  /// Caixa alinhada aos eixos.
  void caixa(String material, P3 min, P3 max, {bool semBase = false}) {
    if (max.$1 - min.$1 < 1e-5 ||
        max.$2 - min.$2 < 1e-5 ||
        max.$3 - min.$3 < 1e-5) {
      return;
    }
    final (x0, y0, z0) = min;
    final (x1, y1, z1) = max;
    _prisma(
      material,
      [(x0, z0), (x1, z0), (x1, z1), (x0, z1)],
      y0,
      y1,
      semBase: semBase,
    );
  }

  /// Caixa ao longo de um segmento no chão: de [origem] na direção
  /// [direcao] (unitária, no plano XZ), de [u0] a [u1] ao longo, de [w0] a
  /// [w1] para o lado (normal à esquerda da direção) e de [y0] a [y1].
  void caixaAoLongo(
    String material, {
    required (double, double) origem,
    required (double, double) direcao,
    required double u0,
    required double u1,
    required double w0,
    required double w1,
    required double y0,
    required double y1,
    bool semTopoNemBase = false,
  }) {
    if (u1 - u0 < 1e-5 || w1 - w0 < 1e-5 || y1 - y0 < 1e-5) return;
    final (dx, dz) = direcao;
    // Normal à esquerda de (dx, dz) no plano XZ, visto de cima (+Y).
    final (nx, nz) = (dz, -dx);
    (double, double) p(double u, double w) =>
        (origem.$1 + dx * u + nx * w, origem.$2 + dz * u + nz * w);
    _prisma(material, [p(u0, w0), p(u1, w0), p(u1, w1), p(u0, w1)], y0, y1,
        semBase: semTopoNemBase, semTopo: semTopoNemBase);
  }

  /// Prisma reto de base convexa [base] (pontos XZ), de [y0] a [y1]. As
  /// faces saem viradas para fora, qualquer que seja a ordem da base.
  void _prisma(
    String material,
    List<(double, double)> base,
    double y0,
    double y1, {
    bool semBase = false,
    bool semTopo = false,
  }) {
    final l = lote(material);
    final n = base.length;
    final cx = base.fold<double>(0, (s, p) => s + p.$1) / n;
    final cz = base.fold<double>(0, (s, p) => s + p.$2) / n;
    final centro = (cx, (y0 + y1) / 2, cz);
    for (var i = 1; i + 1 < n; i++) {
      final a = base[0], b = base[i], c = base[i + 1];
      if (!semTopo) {
        l.trianguloFora(
            (a.$1, y1, a.$2), (b.$1, y1, b.$2), (c.$1, y1, c.$2), centro);
      }
      if (!semBase) {
        l.trianguloFora(
            (a.$1, y0, a.$2), (b.$1, y0, b.$2), (c.$1, y0, c.$2), centro);
      }
    }
    for (var i = 0; i < n; i++) {
      final a = base[i], b = base[(i + 1) % n];
      l.quadFora(
        (a.$1, y0, a.$2),
        (b.$1, y0, b.$2),
        (b.$1, y1, b.$2),
        (a.$1, y1, a.$2),
        centro,
      );
    }
  }

  /// Cilindro vertical (ou tronco de cone, com [raioTopo]).
  void cilindro(
    String material, {
    required P3 base,
    required double raio,
    required double altura,
    double? raioTopo,
    int lados = 16,
  }) {
    final l = lote(material);
    final rt = raioTopo ?? raio;
    final (cx, y0, cz) = base;
    final y1 = y0 + altura;
    (double, double) em(double r, int i) {
      final a = 2 * math.pi * i / lados;
      return (cx + r * math.cos(a), cz - r * math.sin(a));
    }

    final meio = (cx, (y0 + y1) / 2, cz);
    for (var i = 0; i < lados; i++) {
      final a0 = em(raio, i), a1 = em(raio, i + 1);
      final b0 = em(rt, i), b1 = em(rt, i + 1);
      l.quadFora(
        (a0.$1, y0, a0.$2),
        (a1.$1, y0, a1.$2),
        (b1.$1, y1, b1.$2),
        (b0.$1, y1, b0.$2),
        meio,
      );
      l.trianguloFora(
          (cx, y1, cz), (b0.$1, y1, b0.$2), (b1.$1, y1, b1.$2), meio);
      l.trianguloFora(
          (cx, y0, cz), (a1.$1, y0, a1.$2), (a0.$1, y0, a0.$2), meio);
    }
  }

  /// Esfera de baixa resolução (copa de árvore de maquete).
  void esfera(String material, P3 centro, double raio,
      {int anel = 10, int fatias = 7}) {
    final l = lote(material);
    P3 p(int i, int j) {
      final fi = math.pi * j / fatias;
      final te = 2 * math.pi * i / anel;
      return (
        centro.$1 + raio * math.sin(fi) * math.cos(te),
        centro.$2 + raio * math.cos(fi),
        centro.$3 - raio * math.sin(fi) * math.sin(te),
      );
    }

    for (var j = 0; j < fatias; j++) {
      for (var i = 0; i < anel; i++) {
        final a = p(i, j),
            b = p(i, j + 1),
            c = p(i + 1, j + 1),
            d = p(i + 1, j);
        if (j == 0) {
          l.trianguloFora(a, b, c, centro);
        } else if (j == fatias - 1) {
          l.trianguloFora(a, b, d, centro);
        } else {
          l.quadFora(a, b, c, d, centro);
        }
      }
    }
  }

  /// Retângulo horizontal fino (linha de grade, faixa de cota) em [y].
  void faixa(String material, (double, double) a, (double, double) b,
      double largura, double y) {
    final dx = b.$1 - a.$1, dz = b.$2 - a.$2;
    final c = math.sqrt(dx * dx + dz * dz);
    if (c < 1e-6) return;
    caixaAoLongo(
      material,
      origem: a,
      direcao: (dx / c, dz / c),
      u0: 0,
      u1: c,
      w0: -largura / 2,
      w1: largura / 2,
      y0: y,
      y1: y + 0.004,
    );
  }

  /// Traço tracejado entre [a] e [b] (o "ainda não construído"): prismas
  /// finos de [traco] m com [vazio] m de intervalo.
  void tracejado(String material, P3 a, P3 b,
      {double traco = 0.16, double vazio = 0.1, double espessura = 0.03}) {
    final d = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
    final c = math.sqrt(d.$1 * d.$1 + d.$2 * d.$2 + d.$3 * d.$3);
    if (c < 1e-6) return;
    final u = (d.$1 / c, d.$2 / c, d.$3 / c);
    // Dois vetores perpendiculares ao traço.
    final ref = u.$2.abs() > 0.9 ? (1.0, 0.0, 0.0) : (0.0, 1.0, 0.0);
    var v = _cruz(u, ref);
    v = _unit(v);
    final w = _unit(_cruz(u, v));
    final h = espessura / 2;
    var s = 0.0;
    while (s < c - 1e-6) {
      final e = math.min(s + traco, c);
      final p0 = (a.$1 + u.$1 * s, a.$2 + u.$2 * s, a.$3 + u.$3 * s);
      final p1 = (a.$1 + u.$1 * e, a.$2 + u.$2 * e, a.$3 + u.$3 * e);
      _barra(material, p0, p1, v, w, h);
      s = e + vazio;
    }
  }

  /// Contorno tracejado de um polígono horizontal em [y].
  void contornoTracejado(
      String material, List<(double, double)> pontos, double y,
      {bool fechado = true}) {
    for (var i = 0; i < pontos.length - (fechado ? 0 : 1); i++) {
      final a = pontos[i], b = pontos[(i + 1) % pontos.length];
      tracejado(material, (a.$1, y, a.$2), (b.$1, y, b.$2));
    }
  }

  /// Anel tracejado horizontal (caixa d'água, copa de árvore).
  void anelTracejado(String material, P3 centro, double raio,
      {int lados = 20}) {
    final pts = [
      for (var i = 0; i < lados; i++)
        (
          centro.$1 + raio * math.cos(2 * math.pi * i / lados),
          centro.$3 - raio * math.sin(2 * math.pi * i / lados),
        ),
    ];
    for (var i = 0; i < lados; i += 2) {
      final a = pts[i], b = pts[(i + 1) % lados];
      _barra(
        material,
        (a.$1, centro.$2, a.$2),
        (b.$1, centro.$2, b.$2),
        (0, 1, 0),
        _unit(_cruz((b.$1 - a.$1, 0, b.$2 - a.$2), (0, 1, 0))),
        0.014,
      );
    }
  }

  /// Barra do tracejado: prisma de três lados, sem tampas (de longe as
  /// pontas não aparecem, e são 6 triângulos em vez de 12).
  void _barra(String material, P3 p0, P3 p1, P3 v, P3 w, double h) {
    final l = lote(material);
    P3 m(P3 p, double a, double b) => (
          p.$1 + v.$1 * a + w.$1 * b,
          p.$2 + v.$2 * a + w.$2 * b,
          p.$3 + v.$3 * a + w.$3 * b,
        );
    const s = 0.866;
    final c0 = [m(p0, h, 0), m(p0, -h / 2, h * s), m(p0, -h / 2, -h * s)];
    final c1 = [m(p1, h, 0), m(p1, -h / 2, h * s), m(p1, -h / 2, -h * s)];
    final meio = (
      (p0.$1 + p1.$1) / 2,
      (p0.$2 + p1.$2) / 2,
      (p0.$3 + p1.$3) / 2,
    );
    for (var i = 0; i < 3; i++) {
      final j = (i + 1) % 3;
      l.quadFora(c0[i], c0[j], c1[j], c1[i], meio);
    }
  }

  static P3 _cruz(P3 a, P3 b) => (
        a.$2 * b.$3 - a.$3 * b.$2,
        a.$3 * b.$1 - a.$1 * b.$3,
        a.$1 * b.$2 - a.$2 * b.$1,
      );

  static P3 _unit(P3 a) {
    final c = math.sqrt(a.$1 * a.$1 + a.$2 * a.$2 + a.$3 * a.$3);
    return c == 0 ? (1, 0, 0) : (a.$1 / c, a.$2 / c, a.$3 / c);
  }
}

/// Um nó do glb: nome, translação (o pivô da peça), malha e filhos.
class NoGerado {
  NoGerado(this.nome, {this.translacao = (0, 0, 0), this.extras});

  final String nome;

  /// Pivô: as posições da [malha] são relativas a ele.
  P3 translacao;
  final Map<String, Object?>? extras;
  final MalhaGerada malha = MalhaGerada();
  final List<NoGerado> filhos = [];

  NoGerado filho(NoGerado no) {
    filhos.add(no);
    return no;
  }

  /// O nó com esse nome, nesta subárvore.
  NoGerado? procurar(String nome) {
    if (this.nome == nome) return this;
    for (final f in filhos) {
      final achado = f.procurar(nome);
      if (achado != null) return achado;
    }
    return null;
  }

  Iterable<NoGerado> get todos sync* {
    yield this;
    for (final f in filhos) {
      yield* f.todos;
    }
  }

  /// Leva a malha para as coordenadas do pivô (as peças são desenhadas em
  /// coordenadas da cena e depois "penduradas" no pivô).
  void centrarNoPivo() {
    final (tx, ty, tz) = translacao;
    if (tx == 0 && ty == 0 && tz == 0) return;
    for (final lote in malha.lotes.values) {
      final p = lote.posicoes;
      for (var i = 0; i < p.length; i += 3) {
        p[i] -= tx;
        p[i + 1] -= ty;
        p[i + 2] -= tz;
      }
    }
  }
}

/// Um material PBR simples, como os do `maquete.glb` (sem textura).
class MaterialGerado {
  const MaterialGerado(
    this.nome, {
    required this.cor,
    this.metalico = 0,
    this.rugosidade = 0.9,
    this.transparente = false,
    this.semLuz = false,
    this.duasFaces = false,
  });

  final String nome;

  /// RGBA linear (0 a 1), o `baseColorFactor` do glTF.
  final List<double> cor;
  final double metalico;
  final double rugosidade;
  final bool transparente;
  final bool semLuz;
  final bool duasFaces;
}

/// O modelo inteiro: a raiz, os materiais e o enquadramento da câmera.
class ModeloGerado {
  ModeloGerado({
    required this.raiz,
    required this.materiais,
    required this.limites,
  });

  final NoGerado raiz;
  final List<MaterialGerado> materiais;

  /// Caixa que contém a maquete (tabuleiro incluso), em coordenadas glTF.
  final (P3, P3) limites;

  int get triangulos => raiz.todos.fold(0, (s, n) => s + n.malha.triangulos);
}

/// Bytes little-endian, para o glb.
class BytesLE {
  final _b = BytesBuilder(copy: false);
  int get length => _b.length;

  void floats(List<double> v) {
    final d = ByteData(v.length * 4);
    for (var i = 0; i < v.length; i++) {
      d.setFloat32(i * 4, v[i], Endian.little);
    }
    _b.add(d.buffer.asUint8List());
  }

  void uint32s(List<int> v) {
    final d = ByteData(v.length * 4);
    for (var i = 0; i < v.length; i++) {
      d.setUint32(i * 4, v[i], Endian.little);
    }
    _b.add(d.buffer.asUint8List());
  }

  void uint16s(List<int> v) {
    final d = ByteData(v.length * 2);
    for (var i = 0; i < v.length; i++) {
      d.setUint16(i * 2, v[i], Endian.little);
    }
    _b.add(d.buffer.asUint8List());
  }

  void alinhar([int multiplo = 4, int preenchimento = 0]) {
    while (_b.length % multiplo != 0) {
      _b.addByte(preenchimento);
    }
  }

  void bytes(List<int> v) => _b.add(v);

  Uint8List pegar() => _b.takeBytes();
}
