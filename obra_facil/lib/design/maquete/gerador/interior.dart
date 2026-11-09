// O interior da casa pronta, para a vista 360° dos cômodos: móveis em cada
// cômodo (pelo tipo dele), forro, rodapé, rejunte do piso, revestimento do
// banheiro, cortinas e as luminárias do teto (com a posição da luz de cada
// uma para a cena).
//
// Os móveis são encostados nas paredes livres: nunca na frente de porta nem
// no raio de abertura dela, e móvel alto (guarda-roupa, geladeira, TV)
// nunca na frente de janela. Sem lugar que sirva, o móvel fica de fora.

import 'dart:math' as math;

import '../../../models/planta_obra.dart';
import 'gerador_maquete.dart' show MateriaisMaquete, NiveisMaquete;
import 'geometria.dart';
import 'mobilia.dart';
import 'moldura.dart';

typedef _M = MateriaisMaquete;

/// Uma luminária do teto: onde a luz fica (cena) e o tamanho do cômodo.
class LuzDoTeto {
  const LuzDoTeto(this.posicao, this.alcance, {this.comodo});

  final P3 posicao;

  /// Até onde a luz chega (m): o cômodo e um pouco mais.
  final double alcance;

  /// Id do cômodo da luminária.
  final String? comodo;
}

/// Um vão (porta, janela, passagem) visto de um lado do cômodo.
class _VaoNoLado {
  const _VaoNoLado(this.u0, this.u1, this.abertura);
  final double u0, u1;
  final AberturaPlanta abertura;
  bool get janela => abertura.tipo.ehJanela;
}

/// Um lado do retângulo do cômodo: de [a] na direção [d], com [n] para
/// dentro (tudo na planta).
class _Lado {
  _Lado(this.indice, this.a, this.d, this.n, this.comprimento);
  final int indice;
  final (double, double) a, d, n;
  final double comprimento;
  final vaos = <_VaoNoLado>[];

  (double, double) ponto(double u, double v) =>
      (a.$1 + d.$1 * u + n.$1 * v, a.$2 + d.$2 * u + n.$2 * v);

  bool get temPorta => vaos.any((v) => !v.janela);
  bool get temJanela => vaos.any((v) => v.janela);
}

/// Retângulo da planta (x0, y0, x1, y1).
typedef _Ret = (double, double, double, double);

bool _cruza(_Ret a, _Ret b) =>
    a.$1 < b.$3 - 1e-6 &&
    b.$1 < a.$3 - 1e-6 &&
    a.$2 < b.$4 - 1e-6 &&
    b.$2 < a.$4 - 1e-6;

class DecoradorInterior {
  DecoradorInterior(this.planta, this.centro, this.niveis, this.malha,
      {this.reservados = const {}});

  final PlantaObra planta;
  final (double, double) centro;
  final NiveisMaquete niveis;
  final MalhaGerada malha;
  final luzes = <LuzDoTeto>[];

  /// Áreas já ocupadas por peças da maquete (a bancada da churrasqueira),
  /// por id do cômodo: (x0, y0, x1, y1) da planta.
  final Map<String, List<(double, double, double, double)>> reservados;

  /// Onde a tinta da parede fica, a partir da borda do cômodo.
  static const double _parede = 0.026;

  /// Altura do piso acabado.
  static const double _piso = NiveisMaquete.piso + 0.045;

  void decorar() {
    for (final c in planta.comodos) {
      if (!c.coberto) continue;
      final r = c.principal;
      if (r.largura < 0.7 || r.profundidade < 0.7) continue;
      final lados = _lados(r);
      _forroELuz(c);
      _piso_(c);
      _rodape(c, lados);
      if (c.tipo == 'banheiro') _revestimento(lados);
      final e = _Espaco(r, lados)
        ..bloqueios.addAll(reservados[c.id] ?? const [])
        ..molduraNoChao = _molduraNoChao;
      switch (c.tipo) {
        case 'quarto':
          _quarto(c, e);
        case 'sala':
          _sala(c, e);
        case 'cozinha':
          _cozinha(e);
        case 'banheiro':
          _banheiro(c, e);
        case 'lavanderia':
          _lavanderia(e);
        case 'varanda':
          _varanda(e);
        case 'gourmet':
          _gourmet(e);
        case 'closet':
          _closet(e);
        case 'hall':
          _hall(e);
      }
      if (c.tipo == 'quarto' || c.tipo == 'sala') _cortinas(lados);
    }
  }

  // ------------------------------------------------------------ apoio

  (double, double) _xz((double, double) p) =>
      (p.$1 - centro.$1, p.$2 - centro.$2);

  /// Referencial de um móvel encostado no lado [l], começando em [u].
  Moldura _moldura(_Lado l, double u, {double v = _parede + 0.004}) =>
      Moldura(malha,
          origem: _xz(l.ponto(u, v)), eixoU: l.d, eixoV: l.n, y0: _piso);

  /// Referencial de uma mesa solta: canto (x, y) da planta, comprida em X
  /// ([deitada]) ou em Y.
  Moldura _molduraNoChao(
          double x, double y, bool deitada, double lx, double ly) =>
      deitada
          ? Moldura(malha,
              origem: _xz((x, y)), eixoU: (1, 0), eixoV: (0, 1), y0: _piso)
          : Moldura(malha,
              origem: _xz((x + lx, y)),
              eixoU: (0, 1),
              eixoV: (-1, 0),
              y0: _piso);

  /// Os quatro lados do cômodo e os vãos de cada um.
  List<_Lado> _lados(RetanguloPlanta r) {
    final lados = [
      _Lado(0, (r.x, r.y), (1, 0), (0, 1), r.largura),
      _Lado(1, (r.x1, r.y), (0, 1), (-1, 0), r.profundidade),
      _Lado(2, (r.x1, r.y1), (-1, 0), (0, -1), r.largura),
      _Lado(3, (r.x, r.y1), (0, -1), (1, 0), r.profundidade),
    ];
    for (final w in planta.paredes) {
      for (final v in w.aberturas) {
        final p0 = w.pontoEm(v.inicio), p1 = w.pontoEm(v.inicio + v.largura);
        final meio = ((p0.$1 + p1.$1) / 2, (p0.$2 + p1.$2) / 2);
        for (final l in lados) {
          final rx = meio.$1 - l.a.$1, ry = meio.$2 - l.a.$2;
          final ao = rx * l.d.$1 + ry * l.d.$2;
          final fora = (rx * l.n.$1 + ry * l.n.$2).abs();
          if (fora > w.espessura / 2 + 0.15 || ao < 0 || ao > l.comprimento) {
            continue;
          }
          double proj((double, double) p) =>
              (p.$1 - l.a.$1) * l.d.$1 + (p.$2 - l.a.$2) * l.d.$2;
          final s0 = proj(p0), s1 = proj(p1);
          l.vaos.add(_VaoNoLado(math.max(0, math.min(s0, s1)),
              math.min(l.comprimento, math.max(s0, s1)), v));
        }
      }
    }
    return lados;
  }

  // ------------------------------------------------------------ cômodo

  void _forroELuz(ComodoPlanta c) {
    final topo = niveis.lajeFundo;
    for (final r in c.retangulos) {
      final (ax, az) = _xz((r.x, r.y));
      final (bx, bz) = _xz((r.x1, r.y1));
      malha.caixa(_M.forro.nome, (ax, topo - 0.012, az), (bx, topo, bz));
    }
    final r = c.principal;
    final (cx, cz) = _xz(((r.x + r.x1) / 2, (r.y + r.y1) / 2));
    final m = Moldura(malha, origem: (cx, cz), eixoU: (1, 0), y0: 0);
    // Plafom redondo de sobrepor com o difusor aceso.
    final raio = (math.min(r.largura, r.profundidade) * 0.1).clamp(0.14, 0.24);
    m.cilindro(_M.laca.nome, 0, 0, topo - 0.06, 0.048, raio, lados: 28);
    m.cilindro(_M.lampada.nome, 0, 0, topo - 0.064, 0.005, raio * 0.86,
        lados: 28);
    final meiaDiagonal =
        math.sqrt(r.largura * r.largura + r.profundidade * r.profundidade) / 2;
    // A luz fica meio metro abaixo do plafom: assim o forro e as paredes
    // também recebem (o plafom de verdade espalha a luz pelo difusor).
    luzes.add(
        LuzDoTeto((cx, topo - 0.55, cz), meiaDiagonal + 1.5, comodo: c.id));
  }

  /// Rejunte do piso (porcelanato grande, cerâmica menor, réguas de
  /// madeira).
  void _piso_(ComodoPlanta c) {
    final (passoX, passoY) = switch (c.piso) {
      PisoComodo.porcelanato => (0.9, 0.9),
      PisoComodo.ceramica => (0.45, 0.45),
      PisoComodo.madeira => (0.0, 0.2),
      PisoComodo.garagem => (0.6, 0.6),
      _ => (0.0, 0.0),
    };
    const y = _piso + 0.0002;
    for (final r in c.retangulos) {
      if (passoX > 0) {
        for (var x = r.x + passoX; x < r.x1 - 0.05; x += passoX) {
          malha.faixa(_M.rejunte.nome, _xz((x, r.y)), _xz((x, r.y1)), 0.003, y);
        }
      }
      if (passoY > 0) {
        for (var yy = r.y + passoY; yy < r.y1 - 0.05; yy += passoY) {
          malha.faixa(
              _M.rejunte.nome, _xz((r.x, yy)), _xz((r.x1, yy)), 0.003, y);
        }
      }
    }
  }

  /// Rodapé branco de 7 cm, fora dos vãos de porta.
  void _rodape(ComodoPlanta c, List<_Lado> lados) {
    if (c.tipo == 'banheiro' || c.tipo == 'escada') return;
    for (final l in lados) {
      final livres = _livres(l, (v) => !v.janela, folga: 0);
      for (final (a, b) in livres) {
        _moldura(l, 0, v: _parede)
            .caixa(_M.laca.nome, a, b, 0, 0.012, 0, 0.07, chanfro: 0.003);
      }
    }
  }

  /// Banheiro: azulejo do piso ao teto, com as juntas a cada 30 cm.
  void _revestimento(List<_Lado> lados) {
    final altura = niveis.lajeFundo - _piso;
    for (final l in lados) {
      final m = _moldura(l, 0, v: _parede);
      // Recorta portas e janelas (a janela pela altura dela).
      final cortes = <(double, double, double, double)>[
        for (final v in l.vaos)
          (
            v.u0,
            v.u1,
            v.abertura.base(planta.alturas) - 0.045,
            v.abertura.topo(planta.alturas) - 0.045,
          ),
      ];
      final faixas = <double>[0];
      for (var h = 0.3; h < altura - 0.05; h += 0.3) {
        faixas.add(h);
      }
      faixas.add(altura);
      for (var k = 0; k + 1 < faixas.length; k++) {
        final h0 = faixas[k], h1 = faixas[k + 1];
        var trechos = [(0.0, l.comprimento)];
        for (final (u0, u1, b, t) in cortes) {
          if (t <= h0 || b >= h1) continue;
          trechos = [
            for (final (a, z) in trechos) ...[
              if (u0 > a) (a, math.min(u0, z)),
              if (u1 < z) (math.max(u1, a), z),
            ],
          ].where((t) => t.$2 - t.$1 > 0.01).toList();
        }
        for (final (a, z) in trechos) {
          m.caixa(_M.azulejo.nome, a, z, 0, 0.004, h0 + 0.0015, h1 - 0.0015);
          m.caixa(_M.rejunte.nome, a, z, 0, 0.002, h0, h1);
        }
      }
    }
  }

  /// Cortinas de linho nos lados das janelas, com o trilho embutido.
  void _cortinas(List<_Lado> lados) {
    final topo = niveis.lajeFundo - _piso - 0.02;
    for (final l in lados) {
      for (final v in l.vaos.where((v) => v.janela)) {
        final a = math.max(0.0, v.u0 - 0.25),
            b = math.min(l.comprimento, v.u1 + 0.25);
        final m = _moldura(l, 0, v: _parede);
        m.caixa(_M.metalPreto.nome, a, b, 0.07, 0.1, topo - 0.03, topo);
        for (final (c0, c1) in [(a, a + 0.32), (b - 0.32, b)]) {
          // Três dobras desencontradas.
          for (var k = 0; k < 3; k++) {
            final u = c0 + k * (c1 - c0) / 3;
            final dv = k.isEven ? 0.05 : 0.09;
            m.caixa(_M.roupaDeCama.nome, u, u + (c1 - c0) / 3 + 0.02, dv,
                dv + 0.05, 0.02, topo - 0.03,
                chanfro: 0.02);
          }
        }
      }
    }
  }

  /// Trechos livres do lado [l] (u0, u1): sem os vãos que [bloqueia] (com
  /// [folga] dos lados).
  List<(double, double)> _livres(_Lado l, bool Function(_VaoNoLado) bloqueia,
      {double folga = 0.1}) {
    var trechos = [(0.0, l.comprimento)];
    for (final v in l.vaos.where(bloqueia)) {
      final c0 = v.u0 - folga, c1 = v.u1 + folga;
      trechos = [
        for (final (a, b) in trechos) ...[
          if (c0 > a) (a, math.min(c0, b)),
          if (c1 < b) (math.max(c1, a), b),
        ],
      ].where((t) => t.$2 - t.$1 > 0.05).toList();
    }
    return trechos;
  }

  // ------------------------------------------------------------ móveis

  void _quarto(ComodoPlanta c, _Espaco e) {
    final menor = math.min(e.r.largura, e.r.profundidade);
    final suite = c.nome.toLowerCase().contains('suíte');
    final larguraCama = menor >= 3.0 && suite
        ? 1.58
        : menor >= 2.6
            ? 1.38
            : 0.88;
    final comprimento = larguraCama > 1.5 ? 1.98 : 1.88;
    // A cama com os dois criados-mudos; sem espaço, só a cama.
    for (final comMudos in [true, false]) {
      final larg = larguraCama + (comMudos ? 1.0 : 0);
      final lugar = e.procurar(larg, comprimento,
          alto: false,
          preferir: (l) =>
              (l.temPorta ? 0 : 4) + (l.temJanela ? 0 : 2) + l.comprimento,
          frente: 0.55,
          centrar: true);
      if (lugar == null) continue;
      final (l, u) = lugar;
      final u0 = u + (comMudos ? 0.5 : 0);
      // Tapete passando por baixo da cama.
      _moldura(l, u0 - 0.45).caixa(_M.tapete.nome, 0, larguraCama + 0.9, 0.6,
          comprimento + 0.55, 0, 0.012,
          chanfro: 0.004);
      Mobilia.cama(_moldura(l, u0), larguraCama, comprimento);
      if (comMudos) {
        Mobilia.criadoMudo(_moldura(l, u));
        Mobilia.criadoMudo(_moldura(l, u0 + larguraCama + 0.05));
      }
      if (!l.vaos
          .any((v) => v.janela && v.u1 > u0 && v.u0 < u0 + larguraCama)) {
        Mobilia.quadro(_moldura(l, u0 + larguraCama / 2 - 0.45, v: _parede),
            0.9, 0.6, 1.3);
      }
      break;
    }
    // Guarda-roupa num canto livre.
    for (final larg in [2.0, 1.6, 1.2]) {
      final lugar =
          e.procurar(larg, 0.6, alto: true, frente: 0.6, preferir: (l) => 0);
      if (lugar == null) continue;
      final (l, u) = lugar;
      Mobilia.guardaRoupa(_moldura(l, u), larg);
      break;
    }
    if (!suite) {
      // A mesa e a cadeira (até 1,05 m da parede) fora do raio da porta.
      final lugar = e.procurar(1.1, 1.05, alto: false, frente: 0.15);
      if (lugar != null) Mobilia.escrivaninha(_moldura(lugar.$1, lugar.$2));
    }
  }

  void _sala(ComodoPlanta c, _Espaco e) {
    // Sofá na parede mais comprida sem porta; a TV na de frente.
    final larguraSofa = math.min(
        2.2, math.max(1.6, math.max(e.r.largura, e.r.profundidade) * 0.45));
    final sofa = e.procurar(larguraSofa, 0.92,
        alto: false,
        frente: 1.2,
        centrar: true,
        preferir: (l) => (l.temPorta ? 0 : 3) + l.comprimento);
    if (sofa != null) {
      final (l, u) = sofa;
      Mobilia.sofa(_moldura(l, u), larguraSofa);
      final oposto = e.lados[(l.indice + 2) % 4];
      final distancia = l.indice.isEven ? e.r.profundidade : e.r.largura;
      // O centro do sofá visto do lado oposto.
      final meio = oposto.comprimento - (u + larguraSofa / 2);
      // Mesa de centro e tapete entre o sofá e a TV.
      final m = _moldura(l, u);
      final temTv = distancia > 2.6;
      m.caixa(_M.tapete.nome, -0.2, larguraSofa + 0.2, 0.55,
          math.min(distancia - (temTv ? 0.6 : 0.2), 2.6), 0, 0.012,
          chanfro: 0.004);
      // A mesa a 40 cm do sofá, se sobrar passagem até a TV.
      const vMesa = 0.92 + 0.4 + 0.28;
      if (vMesa + 0.28 + 0.45 <= distancia - (temTv ? 0.42 : 0)) {
        Mobilia.mesaDeCentro(
            m.mover(du: larguraSofa / 2 - 0.5, dv: vMesa - 0.28), 1.0, 0.56);
        e.ocupar(l, u + larguraSofa / 2 - 0.5, 1.0, vMesa - 0.28, vMesa + 0.28);
      }
      if (temTv) {
        final larguraRack = math.min(1.8, oposto.comprimento - 0.4);
        final uRack = (meio - larguraRack / 2)
            .clamp(
                0.05, math.max(0.05, oposto.comprimento - larguraRack - 0.05))
            .toDouble();
        if (e.cabe(oposto, uRack, larguraRack, 0.42, alto: true)) {
          Mobilia.rackComTv(_moldura(oposto, uRack), larguraRack);
          e.ocupar(oposto, uRack, larguraRack, 0, 0.42);
        }
      }
      if (!l.vaos.any((v) => v.janela && v.u1 > u && v.u0 < u + larguraSofa)) {
        Mobilia.quadro(
            _moldura(l, u + larguraSofa / 2 - 0.6, v: _parede), 1.2, 0.7, 1.15);
      }
    }
    // Mesa de jantar no que sobrou (sala comprida).
    final jantar = e.procurarNoMeio(1.6, 0.9, folga: 0.68) ??
        e.procurarNoMeio(1.2, 0.8, folga: 0.68);
    if (jantar != null) {
      final (m, larg, fundo) = jantar;
      Mobilia.mesaDeJantar(m, larg, fundo);
    }
    final canto = e.procurar(0.45, 0.45, alto: false, frente: 0.1);
    if (canto != null) {
      Mobilia.vasoComPlanta(
          _moldura(canto.$1, canto.$2 + 0.22).mover(dv: 0.22), 1.1);
    }
  }

  void _cozinha(_Espaco e) {
    // A bancada na parede mais comprida que tenha trecho livre de porta.
    _Lado? melhor;
    (double, double)? trecho;
    for (final l in e.lados) {
      for (final t in _livres(l, (v) => !v.janela)) {
        if (trecho == null || t.$2 - t.$1 > trecho.$2 - trecho.$1) {
          melhor = l;
          trecho = t;
        }
      }
    }
    if (melhor == null || trecho == null || trecho.$2 - trecho.$1 < 1.2) return;
    final l = melhor;
    var (a, b) = trecho;
    a += 0.02;
    b -= 0.02;
    // O maior pedaço do trecho fora do raio das portas dos outros lados.
    var melhorA = a, melhorB = a;
    for (var x = a; x < b - 1.2; x += 0.05) {
      for (var y = b; y - x > melhorB - melhorA && y - x >= 1.2; y -= 0.05) {
        if (e.cabe(l, x, y - x, 0.62, alto: false)) {
          melhorA = x;
          melhorB = y;
          break;
        }
      }
    }
    a = melhorA;
    b = melhorB;
    if (b - a < 1.2) return;
    // A geladeira numa ponta (a que for canto, de preferência).
    var temGeladeira = false;
    if (b - a >= 2.3) {
      final noFim = l.comprimento - b < a;
      for (final fim in [noFim, !noFim]) {
        final u = fim ? b - 0.72 : a;
        if (!e.cabe(l, u, 0.72, 0.74, alto: true)) continue;
        Mobilia.geladeira(_moldura(l, u));
        e.ocupar(l, u, 0.72, 0, 0.74);
        if (fim) {
          b -= 0.76;
        } else {
          a += 0.76;
        }
        temGeladeira = true;
        break;
      }
    }
    final largura = b - a;
    final janela =
        l.vaos.where((v) => v.janela && v.u0 < b && v.u1 > a).firstOrNull;
    final pia = janela != null
        ? ((janela.u0 + janela.u1) / 2 - a).clamp(0.4, largura - 0.4)
        : largura * (temGeladeira ? 0.7 : 0.3);
    final fogao = pia > largura / 2 ? 0.45 : largura - 0.45;
    Mobilia.bancada(_moldura(l, a), largura,
        pia: pia,
        fogao: (fogao - pia).abs() > 0.9 ? fogao : null,
        semAereoDe: janela == null ? null : janela.u0 - a - 0.05,
        semAereoAte: janela == null ? null : janela.u1 - a + 0.05);
    e.ocupar(l, a, largura, 0, 0.62);
  }

  void _banheiro(ComodoPlanta c, _Espaco e) {
    final pequeno = c.area < 2.6;
    if (!pequeno) {
      // O box num canto, longe da porta.
      var pronto = false;
      for (final l in e.lados) {
        if (pronto || l.comprimento < 1.6) continue;
        final bw = math.min(1.2, l.comprimento * 0.45);
        const bf = 0.9;
        for (final u in [0.0, l.comprimento - bw]) {
          if (!e.cabe(l, u, bw, bf - _parede, alto: false, frente: 0)) continue;
          e.ocupar(l, u, bw, 0, bf);
          Mobilia.box(_moldura(l, u), bw, bf - _parede,
              lateral: u == 0 ? bw : 0);
          pronto = true;
          break;
        }
      }
    }
    final pia = e.procurar(0.8, 0.5, alto: false, frente: 0.5) ??
        e.procurar(0.6, 0.5, alto: false, frente: 0.4);
    if (pia != null) {
      final larg = e.ultimaLargura;
      Mobilia.pia(_moldura(pia.$1, pia.$2), larg);
    }
    final vaso = e.procurar(0.42, 0.65, alto: false, frente: 0.3);
    if (vaso != null) Mobilia.vasoSanitario(_moldura(vaso.$1, vaso.$2));
  }

  void _lavanderia(_Espaco e) {
    final lugar = e.procurar(1.25, 0.66, alto: false, frente: 0.5);
    if (lugar != null) Mobilia.lavanderia(_moldura(lugar.$1, lugar.$2));
  }

  void _varanda(_Espaco e) {
    final fundo = math.min(e.r.largura, e.r.profundidade);
    if (fundo < 0.9) return;
    final lugar = e.procurar(1.9, 0.82,
        alto: false, frente: 0.05, preferir: (l) => l.temPorta ? 0 : 1);
    if (lugar == null) return;
    final (l, u) = lugar;
    Mobilia.poltrona(_moldura(l, u));
    Mobilia.poltrona(_moldura(l, u + 1.12));
    Mobilia.vasoComPlanta(_moldura(l, u + 0.95).mover(dv: 0.3), 0.6);
  }

  void _gourmet(_Espaco e) {
    final jantar = e.procurarNoMeio(1.8, 0.9, folga: 0.68) ??
        e.procurarNoMeio(1.4, 0.8, folga: 0.68);
    if (jantar != null) {
      final (m, larg, fundo) = jantar;
      Mobilia.mesaDeJantar(m, larg, fundo);
    }
    final canto = e.procurar(0.5, 0.5, alto: false, frente: 0.1);
    if (canto != null) {
      Mobilia.vasoComPlanta(
          _moldura(canto.$1, canto.$2 + 0.25).mover(dv: 0.25), 1.2);
    }
  }

  void _closet(_Espaco e) {
    for (var i = 0; i < 2; i++) {
      final lugar = e.procurar(
              math.max(e.r.largura, e.r.profundidade) - 0.1, 0.55,
              alto: true, frente: 0.5) ??
          e.procurar(1.2, 0.55, alto: true, frente: 0.5);
      if (lugar == null) return;
      Mobilia.closet(_moldura(lugar.$1, lugar.$2), e.ultimaLargura);
    }
  }

  void _hall(_Espaco e) {
    final lugar = e.procurar(1.1, 0.36, alto: false, frente: 0.6);
    if (lugar != null) Mobilia.aparador(_moldura(lugar.$1, lugar.$2), 1.1);
  }
}

/// O chão de um cômodo e o que já foi posto nele.
class _Espaco {
  _Espaco(this.r, this.lados) {
    // O raio de abertura de cada porta fica livre.
    for (final l in lados) {
      for (final v in l.vaos) {
        if (v.janela) continue;
        final fundo = switch (v.abertura.tipo) {
          TipoAbertura.porta ||
          TipoAbertura.portaPivotante =>
            math.min(1.0, v.u1 - v.u0 + 0.1),
          _ => 0.75,
        };
        bloqueios.add(_ret(l, v.u0 - 0.1, v.u1 - v.u0 + 0.2, 0, fundo));
      }
    }
  }

  final RetanguloPlanta r;
  final List<_Lado> lados;
  final bloqueios = <_Ret>[];
  final ocupados = <_Ret>[];
  double ultimaLargura = 0;

  _Ret _ret(_Lado l, double u, double largura, double v0, double v1) {
    final p = l.ponto(u, v0), q = l.ponto(u + largura, v1);
    return (
      math.min(p.$1, q.$1),
      math.min(p.$2, q.$2),
      math.max(p.$1, q.$1),
      math.max(p.$2, q.$2),
    );
  }

  /// Cabe um móvel de [largura] x [fundo] no lado [l] a partir de [u]? Com
  /// [frente] livre na frente dele (para usar).
  bool cabe(_Lado l, double u, double largura, double fundo,
      {required bool alto, double frente = 0}) {
    if (u < -1e-6 || u + largura > l.comprimento + 1e-6) return false;
    const parede = DecoradorInterior._parede;
    final corpo = _ret(l, u, largura, parede, parede + fundo);
    final uso = _ret(l, u, largura, parede, parede + fundo + frente);
    // Dentro do cômodo (com o espaço de uso).
    if (uso.$1 < r.x - 1e-6 ||
        uso.$2 < r.y - 1e-6 ||
        uso.$3 > r.x1 + 1e-6 ||
        uso.$4 > r.y1 + 1e-6) {
      return false;
    }
    for (final v in l.vaos) {
      final naFrente = v.u1 > u + 0.02 && v.u0 < u + largura - 0.02;
      if (!naFrente) continue;
      if (!v.janela) return false;
      if (alto) return false;
      // Móvel baixo embaixo de janela: só abaixo do peitoril.
    }
    if (bloqueios.any((b) => _cruza(b, corpo))) return false;
    if (ocupados.any((o) => _cruza(o, uso) || _cruza(o, corpo))) return false;
    return true;
  }

  void ocupar(_Lado l, double u, double largura, double v0, double v1) {
    ocupados.add(_ret(l, u, largura, DecoradorInterior._parede + v0,
        DecoradorInterior._parede + v1));
  }

  /// O primeiro lugar (lado, u) para o móvel, nos lados que [preferir]
  /// dá mais pontos; centrado no trecho livre ou encostado num canto.
  (_Lado, double)? procurar(double largura, double fundo,
      {required bool alto,
      double frente = 0.5,
      bool centrar = false,
      double Function(_Lado)? preferir}) {
    final ordem = [...lados]..sort(
        (a, b) => (preferir?.call(b) ?? 0).compareTo(preferir?.call(a) ?? 0));
    for (final l in ordem) {
      final candidatos = <double>[];
      if (centrar) candidatos.add((l.comprimento - largura) / 2);
      candidatos.addAll([0.02, l.comprimento - largura - 0.02]);
      for (var u = 0.1; u < l.comprimento - largura; u += 0.1) {
        candidatos.add(u);
      }
      for (final u in candidatos) {
        if (!cabe(l, u, largura, fundo, alto: alto, frente: frente)) continue;
        ocupar(l, u, largura, 0, fundo + frente * 0.6);
        ultimaLargura = largura;
        return (l, u);
      }
    }
    return null;
  }

  /// Um lugar solto no meio do cômodo para uma mesa de [largura] x
  /// [fundo] com [folga] em volta (as cadeiras). Devolve o referencial já
  /// no canto da mesa.
  (Moldura, double, double)? procurarNoMeio(double largura, double fundo,
      {required double folga}) {
    for (final deitada in [true, false]) {
      final (lx, ly) = deitada ? (largura, fundo) : (fundo, largura);
      final (fx, fy) = deitada ? (0.25, folga) : (folga, 0.25);
      for (var x = r.x + fx + 0.1; x + lx + fx < r.x1 - 0.05; x += 0.1) {
        for (var y = r.y + fy + 0.1; y + ly + fy < r.y1 - 0.05; y += 0.1) {
          final mesa = (x - fx, y - fy, x + lx + fx, y + ly + fy);
          if (bloqueios.any((b) => _cruza(b, mesa))) continue;
          if (ocupados.any((o) => _cruza(o, mesa))) continue;
          ocupados.add(mesa);
          return (_molduraDaMesa(x, y, deitada, lx, ly), largura, fundo);
        }
      }
    }
    return null;
  }

  /// Definida pelo decorador (precisa do centro e da malha).
  Moldura Function(double x, double y, bool deitada, double lx, double ly)?
      molduraNoChao;

  Moldura _molduraDaMesa(
          double x, double y, bool deitada, double lx, double ly) =>
      molduraNoChao!(x, y, deitada, lx, ly);
}
