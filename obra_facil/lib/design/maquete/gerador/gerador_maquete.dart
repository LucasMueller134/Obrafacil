// A maquete de uma obra a partir da planta dela (PlantaObra), com as mesmas
// peças e os mesmos nomes do `maquete.glb` (manifesto assets/3d/maquete.json):
// assim o PlanoMaquete (quem mostra e cresce cada peça pelo avanço) e o
// PecasMaquete (cores de tema e o fantasma) servem igual para as duas.
//
// Dart puro: roda no aparelho, offline, na hora em que a planta chega ou é
// corrigida, e roda nos testes.

import 'dart:math' as math;

import '../../../models/planta_obra.dart';
import '../plano_maquete.dart';
import 'area_coberta.dart';
import 'geometria.dart';

/// Os materiais da maquete: os mesmos do `maquete.glb` (cores lineares
/// exportadas pelo Blender) e os pisos que a planta pede.
abstract final class MateriaisMaquete {
  static const base =
      MaterialGerado('base', cor: [0.888, 0.888, 0.863, 1], rugosidade: 0.95);
  static const grade =
      MaterialGerado('grade', cor: [0.716, 0.723, 0.701, 1], rugosidade: 0.95);
  static const gradeForte = MaterialGerado('grade_forte',
      cor: [0.578, 0.584, 0.565, 1], rugosidade: 0.95);
  static const cota =
      MaterialGerado('cota', cor: [0.01, 0.012, 0.014, 1], rugosidade: 0.8);
  static const fantasma = MaterialGerado('fantasma',
      cor: [0.01, 0.012, 0.014, 1], semLuz: true, duasFaces: true);
  static const concreto = MaterialGerado('concreto',
      cor: [0.314, 0.323, 0.305, 1], rugosidade: 0.88);
  static const bloco = MaterialGerado('bloco_ceramico',
      cor: [0.482, 0.122, 0.044, 1], rugosidade: 0.86);
  static const argamassa = MaterialGerado('argamassa',
      cor: [0.509, 0.479, 0.423, 1], rugosidade: 0.95);
  static const fibrocimento = MaterialGerado('fibrocimento',
      cor: [0.366, 0.392, 0.392, 1], rugosidade: 0.78);
  static const madeira = MaterialGerado('madeira_pinus',
      cor: [0.552, 0.323, 0.112, 1], rugosidade: 0.72);
  static const policarbonato = MaterialGerado('policarbonato',
      cor: [0.254, 0.275, 0.292, 1], rugosidade: 0.5);
  static const vidro = MaterialGerado('vidro',
      cor: [0.347, 0.521, 0.651, 0.35],
      rugosidade: 0.05,
      transparente: true,
      duasFaces: true);
  static const aluminio = MaterialGerado('aluminio_escuro',
      cor: [0.024, 0.027, 0.031, 1], metalico: 0.75, rugosidade: 0.38);
  static const galvanizado = MaterialGerado('metal_galvanizado',
      cor: [0.371, 0.397, 0.418, 1], metalico: 0.85, rugosidade: 0.42);
  static const plasticoAzul = MaterialGerado('plastico_azul',
      cor: [0.028, 0.153, 0.451, 1], rugosidade: 0.42);
  static const pvc = MaterialGerado('pvc_marrom',
      cor: [0.195, 0.068, 0.019, 1], rugosidade: 0.45);
  static const reboco =
      MaterialGerado('reboco', cor: [0.445, 0.429, 0.386, 1], rugosidade: 0.93);
  static const calcada = MaterialGerado('calcada',
      cor: [0.515, 0.515, 0.485, 1], rugosidade: 0.95);
  static const granito = MaterialGerado('granito',
      cor: [0.091, 0.095, 0.102, 1], rugosidade: 0.35);
  static const tinta =
      MaterialGerado('tinta', cor: [0.815, 0.807, 0.768, 1], rugosidade: 0.82);
  static const arvore =
      MaterialGerado('arvore', cor: [0.791, 0.776, 0.73, 1], rugosidade: 0.9);
  static const madeiraPorta = MaterialGerado('madeira_porta',
      cor: [0.254, 0.102, 0.033, 1], rugosidade: 0.55);
  // Pisos (só na maquete gerada): tons claros e neutros, como o resto.
  static const porcelanato = MaterialGerado('piso_porcelanato',
      cor: [0.78, 0.76, 0.71, 1], rugosidade: 0.4);
  static const ceramica = MaterialGerado('piso_ceramica',
      cor: [0.66, 0.6, 0.5, 1], rugosidade: 0.5);
  static const pisoGaragem = MaterialGerado('piso_garagem',
      cor: [0.42, 0.42, 0.39, 1], rugosidade: 0.9);
  static const pisoMadeira = MaterialGerado('piso_madeira',
      cor: [0.45, 0.27, 0.12, 1], rugosidade: 0.6);
  static const grama =
      MaterialGerado('grama', cor: [0.52, 0.6, 0.45, 1], rugosidade: 0.95);

  static const todos = [
    base,
    grade,
    gradeForte,
    cota,
    fantasma,
    concreto,
    bloco,
    argamassa,
    fibrocimento,
    madeira,
    policarbonato,
    vidro,
    aluminio,
    galvanizado,
    plasticoAzul,
    pvc,
    reboco,
    calcada,
    granito,
    tinta,
    arvore,
    madeiraPorta,
    porcelanato,
    ceramica,
    pisoGaragem,
    pisoMadeira,
    grama,
  ];

  static String doPiso(PisoComodo piso) => switch (piso) {
        PisoComodo.porcelanato => porcelanato.nome,
        PisoComodo.ceramica => ceramica.nome,
        PisoComodo.cimento => calcada.nome,
        PisoComodo.garagem => pisoGaragem.nome,
        PisoComodo.madeira => pisoMadeira.nome,
        PisoComodo.grama => grama.nome,
      };
}

/// Alturas da maquete (glTF, Y para cima; o terreno em 0).
class NiveisMaquete {
  NiveisMaquete(this.alturas);

  final AlturasPlanta alturas;

  /// Topo do radier: o piso pronto.
  static const double piso = 0.20;
  static const double espessuraLaje = 0.12;
  static const double alturaViga = 0.30;
  static const double fiadaPlatibanda = 0.20;

  double get lajeFundo => piso + alturas.peDireito;
  double get lajeTopo => lajeFundo + espessuraLaje;
  double get vigaFundo => lajeFundo - alturaViga;

  /// Altura de cada uma das 12 fiadas da parede (do piso ao fundo da viga).
  double get fiada => (vigaFundo - piso) / NosMaquete.totalFiadasParede;

  double get platibandaTopo =>
      lajeTopo + fiadaPlatibanda * NosMaquete.totalFiadasPlatibanda;
}

/// O que o gerador entrega: o modelo (para o glb) e as medidas que a câmera
/// e a planta tocável usam.
class MaqueteGerada {
  MaqueteGerada(this.modelo, this.planta, this.niveis, this.centro);

  final ModeloGerado modelo;
  final PlantaObra planta;
  final NiveisMaquete niveis;

  /// Ponto da planta (x, y) que vira a origem da cena.
  final (double, double) centro;

  /// Planta (x, y) para a cena glTF (X, Z).
  (double, double) paraCena(double x, double y) =>
      (x - centro.$1, y - centro.$2);

  /// Cena glTF (X, Z) para a planta (x, y).
  (double, double) paraPlanta(double x, double z) =>
      (x + centro.$1, z + centro.$2);
}

class GeradorMaquete {
  GeradorMaquete._(this.planta)
      : niveis = NiveisMaquete(planta.alturas),
        centro = centroDe(planta);

  /// O ponto da planta que vira a origem da cena: o meio do tabuleiro (que
  /// tem mais margem na frente, para a calçada e a cota).
  static (double, double) centroDe(PlantaObra planta) => (
        planta.largura / 2,
        (planta.profundidade + margemFrente - margem) / 2,
      );

  final PlantaObra planta;
  final NiveisMaquete niveis;
  final (double, double) centro;

  /// Margem do tabuleiro em volta do terreno; na frente cabe a calçada e a
  /// cota da largura.
  static const double margem = 1.6;
  static const double margemFrente = 3.0;

  /// Gera a maquete. Lança [ArgumentError] se a planta tem problemas
  /// ([PlantaObra.problemas]).
  static MaqueteGerada gerar(PlantaObra planta) {
    final problemas = planta.problemas();
    if (problemas.isNotEmpty) {
      throw ArgumentError('Planta com problemas: ${problemas.join(' ')}');
    }
    return GeradorMaquete._(planta)._gerar();
  }

  // ------------------------------------------------------------ apoio

  P3 _p(double x, double y, double alt) => (x - centro.$1, alt, y - centro.$2);

  (double, double) _xz(double x, double y) => (x - centro.$1, y - centro.$2);

  late final AreaCoberta _coberta = AreaCoberta.dos(
    [for (final c in planta.comodosCobertos) ...c.retangulos],
    largura: planta.largura,
    profundidade: planta.profundidade,
    expandir: 0.065,
  );

  late final AreaCoberta _radier = AreaCoberta.dos(
    [for (final c in planta.comodosCobertos) ...c.retangulos],
    largura: planta.largura,
    profundidade: planta.profundidade,
    expandir: 0.2,
  );

  late final AreaCoberta _telhado = _coberta.recuada(0.2);

  /// Altura da base dos blocos da parede.
  double _baseParede(ParedePlanta w) =>
      w.tipo == TipoParede.muro ? 0 : NiveisMaquete.piso;

  /// Topo dos blocos da parede (a alvenaria para no fundo da viga).
  double _topoBlocos(ParedePlanta w) => switch (w.tipo) {
        TipoParede.alvenaria => niveis.vigaFundo,
        TipoParede.muro => w.alturaEm(planta.alturas),
        TipoParede.muretaVidro => NiveisMaquete.piso + _mureta(w),
      };

  /// Altura da mureta (o peitoril do vidro).
  double _mureta(ParedePlanta w) {
    final vidros = w.aberturas.where((a) => a.tipo.ehJanela);
    if (vidros.isEmpty) return 0.5;
    return vidros.map((a) => a.base(planta.alturas)).reduce(math.min);
  }

  /// Vão em coordenadas da parede: (u0, u1, y0, y1), y absoluto.
  List<(double, double, double, double)> _vaos(ParedePlanta w) {
    final b = _baseParede(w);
    final saida = <(double, double, double, double)>[];
    for (final a in w.aberturas) {
      // Na mureta, o "vão" do vidro fica acima dos blocos: não corta nada.
      if (w.tipo == TipoParede.muretaVidro && a.tipo.ehJanela) continue;
      saida.add((
        a.inicio,
        a.inicio + a.largura,
        b + a.base(planta.alturas),
        b + a.topo(planta.alturas),
      ));
    }
    return saida;
  }

  /// Tira de [faixas] os trechos [cortes] (intervalos em u).
  static List<(double, double)> _tirar(
      List<(double, double)> faixas, Iterable<(double, double)> cortes) {
    var atual = faixas;
    for (final (c0, c1) in cortes) {
      final novo = <(double, double)>[];
      for (final (a, b) in atual) {
        if (c1 <= a || c0 >= b) {
          novo.add((a, b));
          continue;
        }
        if (c0 > a) novo.add((a, c0));
        if (c1 < b) novo.add((c1, b));
      }
      atual = novo;
    }
    return [
      for (final f in atual)
        if (f.$2 - f.$1 > 0.02) f,
    ];
  }

  /// Caixa ao longo da parede [w].
  void _naParede(MalhaGerada m, String material, ParedePlanta w, double u0,
      double u1, double meiaEspessura, double y0, double y1,
      {bool semTopoNemBase = false}) {
    final o = _xz(w.de.$1, w.de.$2);
    m.caixaAoLongo(
      material,
      origem: o,
      direcao: w.direcao,
      u0: u0,
      u1: u1,
      w0: -meiaEspessura,
      w1: meiaEspessura,
      y0: y0,
      y1: y1,
      semTopoNemBase: semTopoNemBase,
    );
  }

  /// Pilares das paredes de alvenaria: nas pontas e a cada 3,5 m no
  /// máximo, fora dos vãos. Posição (x, y da planta) e direção.
  late final List<((double, double), (double, double))> _pilares = () {
    final lista = <((double, double), (double, double))>[];
    void por((double, double) p, (double, double) dir) {
      for (final (q, _) in lista) {
        if ((q.$1 - p.$1).abs() < 0.3 && (q.$2 - p.$2).abs() < 0.3) return;
      }
      lista.add((p, dir));
    }

    for (final w in planta.paredes) {
      if (w.tipo != TipoParede.alvenaria) continue;
      final c = w.comprimento;
      final vaos = _vaos(w);
      bool noVao(double u) => vaos.any((v) => u > v.$1 - 0.1 && u < v.$2 + 0.1);
      final us = <double>[0.07, c - 0.07];
      final trechos = (c / 3.5).ceil();
      for (var k = 1; k < trechos; k++) {
        var u = c * k / trechos;
        // Fora do vão: para a borda mais perto dele.
        for (final v in vaos) {
          if (u > v.$1 - 0.1 && u < v.$2 + 0.1) {
            u = (u - v.$1 < v.$2 - u) ? v.$1 - 0.1 : v.$2 + 0.1;
          }
        }
        if (u > 0.2 && u < c - 0.2 && !noVao(u)) us.add(u);
      }
      for (final u in us) {
        por(w.pontoEm(u.clamp(0.0, c)), w.direcao);
      }
    }
    for (final p in planta.pilares) {
      por((p.x, p.y), (1, 0));
    }
    return lista;
  }();

  /// Trechos (u) de cada parede ocupados por pilares.
  List<(double, double)> _trechosDePilar(ParedePlanta w) {
    final saida = <(double, double)>[];
    final (dx, dy) = w.direcao;
    for (final (p, _) in _pilares) {
      final rx = p.$1 - w.de.$1, ry = p.$2 - w.de.$2;
      final u = rx * dx + ry * dy;
      final dist = (rx * -dy + ry * dx).abs();
      if (dist < w.espessura && u > -0.1 && u < w.comprimento + 0.1) {
        saida.add((u - 0.075, u + 0.075));
      }
    }
    return saida;
  }

  /// A frente da casa (o portão, se houver) para o poste do padrão.
  (double, double) get _posicaoPoste {
    for (final w in planta.paredes) {
      for (final a in w.aberturas) {
        if (a.tipo == TipoAbertura.portao) {
          final p = w.pontoEm(a.inicio);
          return (p.$1 - 0.45, planta.profundidade + 0.55);
        }
      }
    }
    return (planta.largura - 0.6, planta.profundidade + 0.55);
  }

  /// Onde a caixa d'água fica: em cima do banheiro (ou da cozinha).
  (double, double)? get _posicaoCaixa {
    for (final tipo in ['banheiro', 'cozinha']) {
      for (final c in planta.comodosCobertos) {
        if (c.tipo == tipo) {
          final r = c.principal;
          return ((r.x + r.x1) / 2, (r.y + r.y1) / 2);
        }
      }
    }
    final c = planta.comodosCobertos.firstOrNull;
    if (c == null) return null;
    return (
      (c.principal.x + c.principal.x1) / 2,
      (c.principal.y + c.principal.y1) / 2
    );
  }

  // ------------------------------------------------------------ montagem

  MaqueteGerada _gerar() {
    final raiz = NoGerado(NosMaquete.raiz);
    final base = raiz.filho(NoGerado(NosMaquete.base));
    final cotas = raiz.filho(NoGerado(NosMaquete.cotas));
    _tabuleiro(base.malha);
    _cotas(cotas.malha);

    final fases = <NoGerado>[];
    const nomesDasFases = [
      'fase_00_fundacao',
      'fase_01_estrutura',
      'fase_02_alvenaria',
      'fase_03_cobertura',
      'fase_04_eletrica',
      'fase_05_hidraulica',
      'fase_06_reboco',
      'fase_07_revestimentos',
      'fase_08_pintura',
      'fase_09_acabamento',
    ];
    for (var i = 0; i < nomesDasFases.length; i++) {
      fases.add(raiz.filho(NoGerado(nomesDasFases[i], extras: {'fase': i})));
    }
    final pecas = <String, NoGerado>{};
    for (var f = 0; f < PlanoMaquete.etapasPorFase.length; f++) {
      for (final e in PlanoMaquete.etapasPorFase[f]) {
        pecas[e.no] = fases[f].filho(NoGerado(e.no));
      }
    }
    final fantasmas = [
      for (var f = 0; f < nomesDasFases.length; f++)
        raiz.filho(NoGerado(NosMaquete.fantasma(f), extras: {'fase': f})),
    ];

    _fundacao(pecas['fundacao_radier']!);
    _estrutura(pecas);
    _alvenaria(pecas);
    _cobertura(pecas);
    _eletrica(pecas);
    _hidraulica(pecas);
    _rebocoEPintura(pecas);
    _revestimentos(pecas);
    _acabamento(pecas);
    _fantasmas(fantasmas);

    for (final no in raiz.todos) {
      no.centrarNoPivo();
    }
    final (xa, za) = _xz(-margem, -margem);
    final (xb, zb) =
        _xz(planta.largura + margem, planta.profundidade + margemFrente);
    final modelo = ModeloGerado(
      raiz: raiz,
      materiais: MateriaisMaquete.todos,
      limites: ((xa, -0.3, za), (xb, niveis.platibandaTopo + 1.0, zb)),
    );
    return MaqueteGerada(modelo, planta, niveis, centro);
  }

  // ------------------------------------------------------------ tabuleiro

  void _tabuleiro(MalhaGerada m) {
    final x0 = -margem, x1 = planta.largura + margem;
    final y0 = -margem, y1 = planta.profundidade + margemFrente;
    final (ax, az) = _xz(x0, y0);
    final (bx, bz) = _xz(x1, y1);
    m.caixa(MateriaisMaquete.base.nome, (ax, -0.3, az), (bx, 0, bz));
    // Grade de 0,5 m e, mais forte, de 2 m (como o papel quadriculado da
    // maquete).
    for (var x = (x0 * 2).ceil() / 2; x <= x1 + 1e-6; x += 0.5) {
      final forte = (x / 2 - (x / 2).round()).abs() < 1e-6;
      m.faixa(
        forte ? MateriaisMaquete.gradeForte.nome : MateriaisMaquete.grade.nome,
        _xz(x, y0 + 0.05),
        _xz(x, y1 - 0.05),
        forte ? 0.02 : 0.012,
        0.0005,
      );
    }
    for (var y = (y0 * 2).ceil() / 2; y <= y1 + 1e-6; y += 0.5) {
      final forte = (y / 2 - (y / 2).round()).abs() < 1e-6;
      m.faixa(
        forte ? MateriaisMaquete.gradeForte.nome : MateriaisMaquete.grade.nome,
        _xz(x0 + 0.05, y),
        _xz(x1 - 0.05, y),
        forte ? 0.02 : 0.012,
        0.0005,
      );
    }
  }

  // ------------------------------------------------------------ cotas

  void _cotas(MalhaGerada m) {
    final mat = MateriaisMaquete.cota.nome;
    const y = 0.003;
    // Largura, na frente (depois da calçada).
    final yf = planta.profundidade + 2.2;
    _linhaDeCota(m, mat, (0, yf), (planta.largura, yf), y);
    _texto(
        m, mat, _numero(planta.largura), (planta.largura / 2, yf + 0.18), 0, y);
    // Profundidade, à esquerda.
    final xl = -1.0;
    _linhaDeCota(m, mat, (xl, 0), (xl, planta.profundidade), y);
    _texto(m, mat, _numero(planta.profundidade),
        (xl - 0.18, planta.profundidade / 2), -math.pi / 2, y);
  }

  static String _numero(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  void _linhaDeCota(MalhaGerada m, String mat, (double, double) a,
      (double, double) b, double y) {
    m.faixa(mat, _xz(a.$1, a.$2), _xz(b.$1, b.$2), 0.022, y);
    // Traço oblíquo nas pontas, como no desenho técnico.
    for (final p in [a, b]) {
      m.faixa(mat, _xz(p.$1 - 0.12, p.$2 + 0.12), _xz(p.$1 + 0.12, p.$2 - 0.12),
          0.024, y);
    }
  }

  /// Texto em traço simples (algarismos de 7 segmentos e vírgula), deitado
  /// no tabuleiro, centrado em [centro] e girado [angulo] rad.
  void _texto(MalhaGerada m, String mat, String texto, (double, double) centro,
      double angulo, double y) {
    const largura = 0.2, altura = 0.34, espaco = 0.09;
    // Segmentos: a (topo), b, c (direita), d (base), e, f (esquerda), g.
    const segmentos = {
      '0': 'abcdef',
      '1': 'bc',
      '2': 'abged',
      '3': 'abgcd',
      '4': 'fgbc',
      '5': 'afgcd',
      '6': 'afgedc',
      '7': 'abc',
      '8': 'abcdefg',
      '9': 'abcfgd',
    };
    final total = texto.length * largura + (texto.length - 1) * espaco;
    final c = math.cos(angulo), s = math.sin(angulo);
    (double, double) girar(double u, double v) =>
        _xz(centro.$1 + u * c - v * s, centro.$2 + u * s + v * c);
    var u0 = -total / 2;
    for (final ch in texto.split('')) {
      final segs = <((double, double), (double, double))>[];
      if (ch == ',') {
        segs.add(
            ((u0 + 0.06, altura / 2 - 0.02), (u0 + 0.02, altura / 2 + 0.08)));
      } else {
        const h = altura / 2;
        final pontos = {
          'a': ((0.0, -h), (largura, -h)),
          'b': ((largura, -h), (largura, 0.0)),
          'c': ((largura, 0.0), (largura, h)),
          'd': ((0.0, h), (largura, h)),
          'e': ((0.0, 0.0), (0.0, h)),
          'f': ((0.0, -h), (0.0, 0.0)),
          'g': ((0.0, 0.0), (largura, 0.0)),
        };
        for (final seg in (segmentos[ch] ?? '').split('')) {
          final (p, q) = pontos[seg]!;
          segs.add(((u0 + p.$1, p.$2), (u0 + q.$1, q.$2)));
        }
      }
      for (final (p, q) in segs) {
        m.faixa(mat, girar(p.$1, p.$2), girar(q.$1, q.$2), 0.03, y);
      }
      u0 += (ch == ',' ? 0.1 : largura) + espaco;
    }
  }

  // ------------------------------------------------------------ 00 fundação

  void _fundacao(NoGerado no) {
    final m = no.malha;
    final mat = MateriaisMaquete.concreto.nome;
    for (final (x0, y0, x1, y1) in _radier.retangulos()) {
      final (ax, az) = _xz(x0, y0);
      final (bx, bz) = _xz(x1, y1);
      m.caixa(mat, (ax, 0, az), (bx, NiveisMaquete.piso, bz));
    }
    // Sapata corrida dos muros e das paredes fora da laje.
    for (final w in planta.paredes) {
      if (w.tipo == TipoParede.alvenaria) continue;
      _naParede(m, mat, w, -0.05, w.comprimento + 0.05, w.espessura / 2 + 0.08,
          0, 0.1);
    }
    final ext = _radier.extensaoEmY();
    no.translacao = (0, 0, ext == null ? 0 : ext.$1 - centro.$2);
  }

  // ------------------------------------------------------------ 01 estrutura

  void _estrutura(Map<String, NoGerado> pecas) {
    final mat = MateriaisMaquete.concreto.nome;
    final pilares = pecas['estrutura_pilares']!;
    for (final (p, dir) in _pilares) {
      final o = _xz(p.$1, p.$2);
      pilares.malha.caixaAoLongo(
        mat,
        origem: o,
        direcao: dir,
        u0: -0.07,
        u1: 0.07,
        w0: -0.07,
        w1: 0.07,
        y0: NiveisMaquete.piso,
        y1: niveis.lajeFundo,
      );
    }
    pilares.translacao = (0, NiveisMaquete.piso, 0);

    final vigas = pecas['estrutura_vigas']!;
    for (final w in planta.paredes) {
      if (w.tipo != TipoParede.alvenaria) continue;
      _naParede(
          vigas.malha,
          mat,
          w,
          -w.espessura / 2,
          w.comprimento + w.espessura / 2,
          w.espessura / 2 + 0.005,
          niveis.vigaFundo,
          niveis.lajeFundo);
    }
    vigas.translacao = (0, niveis.vigaFundo, 0);

    final laje = pecas['estrutura_laje']!;
    for (final (x0, y0, x1, y1) in _coberta.retangulos()) {
      final (ax, az) = _xz(x0, y0);
      final (bx, bz) = _xz(x1, y1);
      laje.malha
          .caixa(mat, (ax, niveis.lajeFundo, az), (bx, niveis.lajeTopo, bz));
    }
    final ext = _coberta.extensaoEmY();
    laje.translacao =
        (0, niveis.lajeFundo, ext == null ? 0 : ext.$1 - centro.$2);
  }

  // ------------------------------------------------------------ 02 alvenaria

  void _alvenaria(Map<String, NoGerado> pecas) {
    final h = niveis.fiada;
    final fiadas = [
      for (var k = 0; k < NosMaquete.totalFiadas; k++)
        pecas[NosMaquete.fiada(k)]!,
    ];
    for (var k = 0; k < NosMaquete.totalFiadasParede; k++) {
      fiadas[k].translacao = (0, NiveisMaquete.piso + k * h, 0);
    }
    for (var k = 0; k < NosMaquete.totalFiadasPlatibanda; k++) {
      fiadas[NosMaquete.totalFiadasParede + k].translacao =
          (0, niveis.lajeTopo + k * NiveisMaquete.fiadaPlatibanda, 0);
    }

    for (final w in planta.paredes) {
      final base = _baseParede(w);
      final topo = _topoBlocos(w);
      final vaos = _vaos(w);
      final pilares = w.tipo == TipoParede.alvenaria
          ? _trechosDePilar(w)
          : const <(double, double)>[];
      // Vergas sobre os vãos e contravergas sob as janelas, em concreto.
      final vergas = <(double, double, double, double)>[];
      for (final (u0, u1, y0, y1) in vaos) {
        if (y1 < topo - 0.12) vergas.add((u0 - 0.2, u1 + 0.2, y1, y1 + 0.1));
        if (y0 > base + 0.15) vergas.add((u0 - 0.2, u1 + 0.2, y0 - 0.1, y0));
      }
      final cursos = ((topo - base) / h - 1e-6).ceil();
      for (var k = 0; k < math.min(cursos, NosMaquete.totalFiadasParede); k++) {
        final y0 = base + k * h;
        final y1 = math.min(y0 + h, topo);
        if (y1 - y0 < 0.02) continue;
        final m = fiadas[k].malha;
        final cortes = <(double, double)>[
          for (final v in [...vaos, ...vergas])
            if (v.$3 < y1 - 1e-6 && v.$4 > y0 + 1e-6) (v.$1, v.$2),
          ...pilares,
        ];
        final trechos = _tirar([(0, w.comprimento)], cortes);
        // Topo à vista: o último curso do muro e da mureta, e o que fica
        // sob um vão (o peitoril cobre só a janela).
        final ultimo = y1 >= topo - 1e-6 && w.tipo != TipoParede.alvenaria;
        _blocos(m, w, trechos, y0, y1, k.isOdd, topoAVista: ultimo);
        for (final (u0, u1, v0, v1) in vergas) {
          if (v0 >= y0 - 1e-6 && v0 < y1 - 1e-6) {
            _naParede(m, MateriaisMaquete.concreto.nome, w, math.max(0, u0),
                math.min(w.comprimento, u1), w.espessura / 2 + 0.003, v0, v1);
          }
        }
      }
    }

    // Platibanda: 3 fiadas em volta da laje, por cima da borda.
    final bordas = _coberta.bordas();
    for (var k = 0; k < NosMaquete.totalFiadasPlatibanda; k++) {
      final y0 = niveis.lajeTopo + k * NiveisMaquete.fiadaPlatibanda;
      final m = fiadas[NosMaquete.totalFiadasParede + k].malha;
      for (final b in bordas) {
        final w = _paredeDaBorda(b);
        _blocos(m, w, [(0, w.comprimento)], y0,
            y0 + NiveisMaquete.fiadaPlatibanda, k.isOdd,
            topoAVista: k == NosMaquete.totalFiadasPlatibanda - 1);
      }
    }
  }

  /// A borda da laje como uma parede de 12 cm por dentro dela.
  ParedePlanta _paredeDaBorda(BordaCoberta b) {
    const e = 0.12;
    final (ix, iy) = b.paraDentro;
    return ParedePlanta(
      id: 'platibanda',
      de: (b.de.$1 + ix * e / 2, b.de.$2 + iy * e / 2),
      ate: (b.ate.$1 + ix * e / 2, b.ate.$2 + iy * e / 2),
      espessura: e,
    );
  }

  /// Blocos de 39 cm com junta de 1 cm, em amarração (a fiada ímpar começa
  /// meio bloco depois), e a argamassa recuada por trás.
  ///
  /// Topo e base dos blocos ficam escondidos pela fiada de cima e pela de
  /// baixo (ou pela viga, pela verga e pelo peitoril): só a última fiada de
  /// um muro ou da platibanda mostra o topo ([topoAVista]).
  void _blocos(MalhaGerada m, ParedePlanta w, List<(double, double)> trechos,
      double y0, double y1, bool impar,
      {bool topoAVista = false}) {
    const modulo = 0.40, bloco = 0.39;
    final e = w.espessura / 2;
    for (final (a, b) in trechos) {
      _naParede(
          m, MateriaisMaquete.argamassa.nome, w, a, b, e * 0.86, y0, y1 - 0.004,
          semTopoNemBase: true);
      // A amarração conta da ponta da parede, não do trecho: os blocos de
      // trechos separados por um vão continuam alinhados.
      var u = a - ((a + (impar ? modulo / 2 : 0)) % modulo);
      while (u < b - 1e-6) {
        final s = math.max(u, a), f = math.min(u + bloco, b);
        if (f - s > 0.04) {
          _naParede(m, MateriaisMaquete.bloco.nome, w, s, f, e, y0, y1 - 0.01,
              semTopoNemBase: !topoAVista);
        }
        u += modulo;
      }
    }
  }

  // ------------------------------------------------------------ 03 cobertura

  void _cobertura(Map<String, NoGerado> pecas) {
    final tercas = pecas['cobertura_tercas']!;
    final telhas = pecas['cobertura_telhas']!;
    final t0 = niveis.lajeTopo;
    final ext = _telhado.extensaoEmY();
    if (ext == null) return;
    final (yFundo, yFrente) = ext;
    // Cai da frente para o fundo, escondido atrás da platibanda.
    double alturaEm(double y) {
      final s =
          ((y - yFundo) / math.max(0.1, yFrente - yFundo)).clamp(0.0, 1.0);
      return t0 + 0.12 + 0.3 * s;
    }

    for (final (x0, y0, x1, y1) in _telhado.retangulos()) {
      // Terças de pinus a cada 1,1 m, com pontaletes.
      for (var y = y0 + 0.2; y < y1 - 0.1; y += 1.1) {
        final topo = alturaEm(y) - 0.04;
        final (ax, az) = _xz(x0 + 0.05, y - 0.03);
        final (bx, bz) = _xz(x1 - 0.05, y + 0.03);
        tercas.malha.caixa(MateriaisMaquete.madeira.nome, (ax, topo - 0.1, az),
            (bx, topo, bz));
        for (var x = x0 + 0.4; x < x1 - 0.2; x += 1.5) {
          final (px, pz) = _xz(x, y);
          tercas.malha.caixa(MateriaisMaquete.madeira.nome,
              (px - 0.03, t0, pz - 0.03), (px + 0.03, topo - 0.1, pz + 0.03));
        }
      }
      // Telha ondulada: perfil em zigue-zague a cada 9 cm.
      final l = telhas.malha.lote(MateriaisMaquete.fibrocimento.nome);
      final (_, za) = _xz(x0, y0);
      final (_, zb) = _xz(x0, y1);
      final ha = alturaEm(y0), hb = alturaEm(y1);
      var x = x0;
      var alto = false;
      while (x < x1 - 1e-6) {
        final xn = math.min(x + 0.09, x1);
        final d0 = alto ? 0.03 : 0.0;
        final d1 = alto ? 0.0 : 0.03;
        final (cx0, _) = _xz(x, y0);
        final (cx1, _) = _xz(xn, y0);
        final dentro = ((cx0 + cx1) / 2, (ha + hb) / 2 - 1, (za + zb) / 2);
        l.quadFora(
          (cx0, ha + d0, za),
          (cx1, ha + d1, za),
          (cx1, hb + d1, zb),
          (cx0, hb + d0, zb),
          dentro,
        );
        x = xn;
        alto = !alto;
      }
    }
    tercas.translacao = (0, t0, 0);
    telhas.translacao = (0, t0, 0);
  }

  // ------------------------------------------------------------ 04 elétrica

  void _eletrica(Map<String, NoGerado> pecas) {
    final (px, py) = _posicaoPoste;
    final (x, z) = _xz(px, py);
    final poste = pecas['eletrica_poste']!;
    poste.malha.caixa(MateriaisMaquete.concreto.nome, (x - 0.08, 0, z - 0.08),
        (x + 0.08, 3.6, z + 0.08));
    poste.translacao = (x, 0, z);

    final caixa = pecas['eletrica_caixa_medicao']!;
    caixa.malha.caixa(MateriaisMaquete.policarbonato.nome,
        (x - 0.17, 1.0, z + 0.08), (x + 0.17, 1.5, z + 0.26));
    caixa.translacao = (x, 1.25, z + 0.17);

    final duto = pecas['eletrica_eletroduto']!;
    duto.malha.cilindro(MateriaisMaquete.galvanizado.nome,
        base: (x + 0.12, 1.5, z), raio: 0.025, altura: 2.3, lados: 8);
    duto.malha.cilindro(MateriaisMaquete.galvanizado.nome,
        base: (x + 0.12, 3.8, z), raio: 0.05, altura: 0.08, lados: 8);
    duto.translacao = (x, 0, z);
  }

  // ------------------------------------------------------------ 05 hidráulica

  void _hidraulica(Map<String, NoGerado> pecas) {
    final pos = _posicaoCaixa;
    if (pos == null) return;
    final (x, z) = _xz(pos.$1, pos.$2);
    final t0 = niveis.lajeTopo;
    final base = pecas['hidraulica_base']!;
    base.malha.caixa(MateriaisMaquete.concreto.nome, (x - 0.7, t0, z - 0.7),
        (x + 0.7, t0 + 0.6, z + 0.7));
    base.translacao = (x, t0, z);

    final caixa = pecas['hidraulica_caixa_dagua']!;
    caixa.malha.cilindro(MateriaisMaquete.plasticoAzul.nome,
        base: (x, t0 + 0.6, z),
        raio: 0.52,
        raioTopo: 0.6,
        altura: 0.68,
        lados: 24);
    caixa.malha.cilindro(MateriaisMaquete.plasticoAzul.nome,
        base: (x, t0 + 1.28, z),
        raio: 0.63,
        raioTopo: 0.5,
        altura: 0.08,
        lados: 24);
    caixa.translacao = (x, t0 + 0.6, z);

    final tubos = pecas['hidraulica_tubos']!;
    tubos.malha.cilindro(MateriaisMaquete.pvc.nome,
        base: (x + 0.75, t0, z), raio: 0.03, altura: 0.95, lados: 8);
    tubos.malha.caixa(MateriaisMaquete.pvc.nome,
        (x + 0.72, t0 + 0.02, z - 0.03), (x + 1.8, t0 + 0.08, z + 0.03));
    tubos.translacao = (x, t0, z);
  }

  // ------------------------------------------------------------ 06 e 08

  /// Retângulos (u0, u1, y0, y1) cheios da face de uma parede, sem os vãos.
  List<(double, double, double, double)> _faces(
      ParedePlanta w, double y0, double y1) {
    final vaos = [
      for (final v in _vaos(w))
        if (v.$4 > y0 && v.$3 < y1) v,
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final saida = <(double, double, double, double)>[];
    final colunas =
        _tirar([(0, w.comprimento)], [for (final v in vaos) (v.$1, v.$2)]);
    for (final (a, b) in colunas) {
      saida.add((a, b, y0, y1));
    }
    for (final (u0, u1, v0, v1) in vaos) {
      if (v0 > y0 + 0.01) saida.add((u0, u1, y0, math.min(v0, y1)));
      if (v1 < y1 - 0.01) saida.add((u0, u1, math.max(v1, y0), y1));
    }
    return saida;
  }

  void _rebocoEPintura(Map<String, NoGerado> pecas) {
    final reboco = pecas['reboco_paredes']!.malha;
    final pintura = pecas['pintura_paredes']!.malha;
    void casca(ParedePlanta w, double y0, double y1, {bool pontas = true}) {
      for (final (u0, u1, v0, v1) in _faces(w, y0, y1)) {
        final a = pontas && u0 <= 0.001 ? u0 - 0.02 : u0;
        final b = pontas && u1 >= w.comprimento - 0.001 ? u1 + 0.02 : u1;
        _naParede(reboco, MateriaisMaquete.reboco.nome, w, a, b,
            w.espessura / 2 + 0.02, v0, v1);
        _naParede(pintura, MateriaisMaquete.tinta.nome, w, a, b,
            w.espessura / 2 + 0.026, v0, v1);
      }
    }

    for (final w in planta.paredes) {
      final topo = switch (w.tipo) {
        TipoParede.alvenaria => niveis.lajeFundo,
        _ => _topoBlocos(w),
      };
      casca(w, _baseParede(w), topo);
    }
    for (final b in _coberta.bordas()) {
      final w = _paredeDaBorda(b);
      casca(w, niveis.lajeFundo, niveis.platibandaTopo, pontas: false);
    }
    // Contrapiso dos cômodos cobertos.
    final contrapiso = pecas['reboco_contrapiso']!;
    for (final c in planta.comodosCobertos) {
      for (final r in c.retangulos) {
        final (ax, az) = _xz(r.x, r.y);
        final (bx, bz) = _xz(r.x1, r.y1);
        contrapiso.malha.caixa(MateriaisMaquete.argamassa.nome,
            (ax, NiveisMaquete.piso, az), (bx, NiveisMaquete.piso + 0.03, bz),
            semBase: true);
      }
    }
    contrapiso.translacao = (0, NiveisMaquete.piso, 0);
  }

  // ------------------------------------------------------------ 07

  void _revestimentos(Map<String, NoGerado> pecas) {
    final calcada = pecas['revestimentos_calcada']!.malha;
    // Pisos dos cômodos (os cobertos sobre o contrapiso; cimentado e
    // garagem descobertos no chão).
    for (final c in planta.comodos) {
      if (c.piso == PisoComodo.grama) continue;
      final y0 = c.coberto ? NiveisMaquete.piso + 0.03 : 0.0;
      final y1 = c.coberto ? NiveisMaquete.piso + 0.045 : 0.05;
      for (final r in c.retangulos) {
        final (ax, az) = _xz(r.x, r.y);
        final (bx, bz) = _xz(r.x1, r.y1);
        calcada.caixa(
            MateriaisMaquete.doPiso(c.piso), (ax, y0, az), (bx, y1, bz),
            semBase: true);
      }
    }
    // Calçada da rua.
    final (ax, az) = _xz(-0.12, planta.profundidade + 0.12);
    final (bx, bz) = _xz(planta.largura + 0.12, planta.profundidade + 1.5);
    calcada.caixa(MateriaisMaquete.calcada.nome, (ax, 0, az), (bx, 0.06, bz),
        semBase: true);

    // Pingadeira: o topo da platibanda.
    final pingadeira = pecas['revestimentos_pingadeira']!;
    for (final b in _coberta.bordas()) {
      final w = _paredeDaBorda(b);
      _naParede(
          pingadeira.malha,
          MateriaisMaquete.granito.nome,
          w,
          -0.04,
          w.comprimento + 0.04,
          w.espessura / 2 + 0.05,
          niveis.platibandaTopo,
          niveis.platibandaTopo + 0.03);
    }
    pingadeira.translacao = (0, niveis.platibandaTopo, 0);

    // Peitoris das janelas e soleiras das portas.
    final peitoris = pecas['revestimentos_peitoris']!.malha;
    for (final w in planta.paredes) {
      final base = _baseParede(w);
      for (final a in w.aberturas) {
        final u0 = a.inicio, u1 = a.inicio + a.largura;
        if (a.tipo.ehJanela) {
          final y = base + a.base(planta.alturas);
          _naParede(peitoris, MateriaisMaquete.granito.nome, w, u0 - 0.03,
              u1 + 0.03, w.espessura / 2 + 0.05, y - 0.025, y);
        } else if (a.tipo != TipoAbertura.portao) {
          _naParede(peitoris, MateriaisMaquete.granito.nome, w, u0, u1,
              w.espessura / 2, base + 0.03, base + 0.05);
        }
      }
    }
    // Ripado: só na maquete-padrão (fica vazio aqui).
  }

  // ------------------------------------------------------------ 09

  void _acabamento(Map<String, NoGerado> pecas) {
    final esquadrias = pecas['acabamento_esquadrias']!.malha;
    final portas = pecas['acabamento_porta']!.malha;
    final al = MateriaisMaquete.aluminio.nome;
    final vidro = MateriaisMaquete.vidro.nome;
    for (final w in planta.paredes) {
      final base = _baseParede(w);
      for (final a in w.aberturas) {
        final u0 = a.inicio, u1 = a.inicio + a.largura;
        final y0 = base + a.base(planta.alturas);
        final y1 = base + a.topo(planta.alturas);
        switch (a.tipo) {
          case TipoAbertura.janela:
          case TipoAbertura.portaCorrer:
            _caixilho(esquadrias, w, u0, u1, y0, y1, al, vidro);
          case TipoAbertura.porta:
            _naParede(portas, MateriaisMaquete.madeiraPorta.nome, w, u0 + 0.02,
                u1 - 0.02, 0.02, y0, y1 - 0.01);
          case TipoAbertura.portao:
            for (var u = u0 + 0.04; u < u1 - 0.02; u += 0.12) {
              _naParede(esquadrias, al, w, u, math.min(u + 0.04, u1), 0.025,
                  y0 + 0.05, y1 - 0.05);
            }
            _naParede(esquadrias, al, w, u0, u1, 0.03, y1 - 0.08, y1 - 0.03);
            _naParede(esquadrias, al, w, u0, u1, 0.03, y0 + 0.05, y0 + 0.1);
          case TipoAbertura.passagem:
            break;
        }
      }
    }
    // Árvores e grama nos cômodos de grama (quintal, jardim).
    final arvores = pecas['acabamento_arvores']!.malha;
    var semente = 7;
    double sorteio() {
      semente = (semente * 1103515245 + 12345) & 0x7fffffff;
      return semente / 0x7fffffff;
    }

    for (final c in planta.comodos) {
      if (c.piso != PisoComodo.grama) continue;
      for (final r in c.retangulos) {
        final (ax, az) = _xz(r.x, r.y);
        final (bx, bz) = _xz(r.x1, r.y1);
        arvores.caixa(MateriaisMaquete.grama.nome, (ax, 0, az), (bx, 0.025, bz),
            semBase: true);
      }
      final r = c.principal;
      final n = (c.area / 9).floor().clamp(1, 3);
      for (var i = 0; i < n; i++) {
        if (r.largura < 1.0 || r.profundidade < 1.0) break;
        final x = r.x +
            0.5 +
            (r.largura - 1.0) * (i + 0.5 + (sorteio() - 0.5) * 0.4) / n;
        final y = r.y + 0.5 + (r.profundidade - 1.0) * (0.3 + 0.4 * sorteio());
        final (tx, tz) = _xz(x, y);
        final raio = 0.42 + 0.18 * sorteio();
        arvores.cilindro(MateriaisMaquete.arvore.nome,
            base: (tx, 0, tz), raio: 0.045, altura: 1.1, lados: 8);
        arvores.esfera(
            MateriaisMaquete.arvore.nome, (tx, 1.1 + raio * 0.8, tz), raio);
      }
    }
  }

  /// Caixilho de alumínio com vidro (janela, porta de correr, vidro da
  /// área de sol).
  void _caixilho(MalhaGerada m, ParedePlanta w, double u0, double u1, double y0,
      double y1, String al, String vidro) {
    const b = 0.045;
    _naParede(m, al, w, u0, u0 + b, 0.035, y0, y1);
    _naParede(m, al, w, u1 - b, u1, 0.035, y0, y1);
    _naParede(m, al, w, u0, u1, 0.035, y0, y0 + b);
    _naParede(m, al, w, u0, u1, 0.035, y1 - b, y1);
    if (u1 - u0 > 1.0) {
      final meio = (u0 + u1) / 2;
      _naParede(m, al, w, meio - b / 2, meio + b / 2, 0.035, y0, y1);
    }
    _naParede(m, vidro, w, u0 + b, u1 - b, 0.006, y0 + b, y1 - b);
  }

  // ------------------------------------------------------------ fantasmas

  void _fantasmas(List<NoGerado> fantasmas) {
    final mat = MateriaisMaquete.fantasma.nome;
    void contorno(MalhaGerada m, AreaCoberta area, double y) {
      for (final b in area.bordas()) {
        m.tracejado(mat, _p(b.de.$1, b.de.$2, y), _p(b.ate.$1, b.ate.$2, y));
      }
    }

    // 00: o contorno do radier.
    contorno(fantasmas[0].malha, _radier, NiveisMaquete.piso);
    // 01: os pilares e o contorno da laje.
    // Os pilares da borda da laje (os de dentro, de fora, somem atrás).
    for (final (p, _) in _pilares) {
      if (!_coberta.contem(p.$1 + 0.3, p.$2) ||
          !_coberta.contem(p.$1 - 0.3, p.$2) ||
          !_coberta.contem(p.$1, p.$2 + 0.3) ||
          !_coberta.contem(p.$1, p.$2 - 0.3)) {
        fantasmas[1].malha.tracejado(mat, _p(p.$1, p.$2, NiveisMaquete.piso),
            _p(p.$1, p.$2, niveis.lajeFundo));
      }
    }
    contorno(fantasmas[1].malha, _coberta, niveis.lajeTopo);
    // 02: topo e pontas das paredes, os vãos e a platibanda.
    final f2 = fantasmas[2].malha;
    for (final w in planta.paredes) {
      final topo = _topoBlocos(w);
      final base = _baseParede(w);
      // O topo da parede e, nas pontas, a altura: o desenho do que falta
      // subir. (Os vãos ficam de fora: tracejado demais vira ruído.)
      final a = w.pontoEm(0), b = w.pontoEm(w.comprimento);
      f2.tracejado(mat, _p(a.$1, a.$2, topo), _p(b.$1, b.$2, topo));
      if (w.tipo == TipoParede.alvenaria) {
        f2.tracejado(mat, _p(a.$1, a.$2, base), _p(a.$1, a.$2, topo));
        f2.tracejado(mat, _p(b.$1, b.$2, base), _p(b.$1, b.$2, topo));
      }
    }
    contorno(f2, _coberta, niveis.platibandaTopo);
    // 03: o contorno do telhado.
    contorno(fantasmas[3].malha, _telhado, niveis.lajeTopo + 0.35);
    // 04: o poste.
    final (px, py) = _posicaoPoste;
    fantasmas[4].malha.tracejado(mat, _p(px, py, 0), _p(px, py, 3.6));
    // 05: a caixa d'água.
    final caixa = _posicaoCaixa;
    if (caixa != null) {
      final (x, z) = _xz(caixa.$1, caixa.$2);
      final t0 = niveis.lajeTopo;
      fantasmas[5].malha.anelTracejado(mat, (x, t0 + 1.36, z), 0.6);
      fantasmas[5].malha.anelTracejado(mat, (x, t0 + 0.6, z), 0.52);
    }
    // 07: a calçada da rua.
    fantasmas[7].malha.contornoTracejado(
        mat,
        [
          _xz(-0.12, planta.profundidade + 0.12),
          _xz(planta.largura + 0.12, planta.profundidade + 0.12),
          _xz(planta.largura + 0.12, planta.profundidade + 1.5),
          _xz(-0.12, planta.profundidade + 1.5),
        ],
        0.06);
    // 09: as copas das árvores.
    for (final c in planta.comodos) {
      if (c.piso != PisoComodo.grama) continue;
      final r = c.principal;
      if (r.largura < 1.0 || r.profundidade < 1.0) continue;
      final (x, z) = _xz((r.x + r.x1) / 2, (r.y + r.y1) / 2);
      fantasmas[9].malha.anelTracejado(mat, (x, 1.5, z), 0.5);
    }
  }
}
