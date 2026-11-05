import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A planta baixa de uma obra, como dados: é dela que sai a maquete 3D
/// (fundação, estrutura, alvenaria fiada a fiada, cobertura...), a planta
/// tocável do cliente e a vista 360° de cada cômodo.
///
/// Formato (o mesmo no Firestore, em `obras/{id}/planta/atual`, e no JSON
/// que a leitura da planta pelo Gemini devolve):
///
/// * medidas em metros; `x` cresce para a direita do desenho e `y` do fundo
///   do terreno para a rua (a frente da casa fica em `y` máximo);
/// * paredes pela linha de centro (`de` → `ate`), com espessura e tipo
///   (`alvenaria` sobe até o pé-direito e segura a laje; `muro` é a divisa,
///   mais baixa; `mureta_vidro` é mureta com vidro em cima);
/// * vãos pela distância ao longo da parede, a partir do ponto `de`;
/// * cômodos como um ou mais retângulos (o primeiro dá o nome e as medidas),
///   cobertos (com laje) ou não.
@immutable
class PlantaObra {
  const PlantaObra({
    this.versao = 1,
    this.nome,
    this.fonte,
    required this.largura,
    required this.profundidade,
    this.alturas = const AlturasPlanta(),
    this.cobertura = TipoCobertura.lajePlatibanda,
    required this.paredes,
    this.pilares = const [],
    required this.comodos,
  });

  final int versao;

  /// Nome do projeto ("Casa térrea 7 x 20").
  final String? nome;

  /// De onde veio a planta (arquivo, autor, licença).
  final String? fonte;

  /// Terreno, em metros: largura em `x` e profundidade em `y`.
  final double largura;
  final double profundidade;

  final AlturasPlanta alturas;
  final TipoCobertura cobertura;
  final List<ParedePlanta> paredes;

  /// Pilares soltos, fora das paredes (varanda, garagem). Os das paredes o
  /// gerador da maquete põe sozinho.
  final List<PilarPlanta> pilares;
  final List<ComodoPlanta> comodos;

  /// Cômodos com laje (é a área construída).
  Iterable<ComodoPlanta> get comodosCobertos => comodos.where((c) => c.coberto);

  /// Área construída (soma dos cômodos cobertos), em m².
  double get areaConstruida =>
      comodosCobertos.fold<double>(0, (s, c) => s + c.area);

  /// O cômodo que contém o ponto (x, y) da planta, ou nulo. Cômodos
  /// cobertos ganham dos descobertos onde se sobrepõem.
  ComodoPlanta? comodoEm(double x, double y) {
    ComodoPlanta? achado;
    for (final c in comodos) {
      if (!c.contem(x, y)) continue;
      if (achado == null || (c.coberto && !achado.coberto)) achado = c;
    }
    return achado;
  }

  /// Portas, janelas e passagens que dão para o cômodo [c] (o meio do vão,
  /// um pouco para cada lado da parede, cai dentro dele).
  List<AberturaPlanta> aberturasDo(ComodoPlanta c) {
    final saida = <AberturaPlanta>[];
    for (final w in paredes) {
      final (dx, dy) = w.direcao;
      final folga = w.espessura / 2 + 0.08;
      for (final a in w.aberturas) {
        final (mx, my) = w.pontoEm(a.inicio + a.largura / 2);
        if (c.contem(mx - dy * folga, my + dx * folga) ||
            c.contem(mx + dy * folga, my - dx * folga)) {
          saida.add(a);
        }
      }
    }
    return saida;
  }

  /// O que impede de gerar a maquete com esta planta (lista vazia: ok). As
  /// mensagens são para o dono conferir na tela de revisão.
  List<String> problemas() {
    final p = <String>[];
    if (!(largura > 0) || !(profundidade > 0)) {
      p.add('O terreno precisa ter largura e profundidade.');
    }
    if (paredes.isEmpty) p.add('A planta não tem paredes.');
    if (comodos.isEmpty) p.add('A planta não tem cômodos.');
    if (!(alturas.peDireito >= 2.2 && alturas.peDireito <= 4.5)) {
      p.add('O pé-direito de ${alturas.peDireito} m está fora do comum '
          '(2,20 a 4,50 m).');
    }
    for (final w in paredes) {
      if (w.comprimento < 0.05) {
        p.add('A parede ${w.id} não tem comprimento.');
        continue;
      }
      if (!(w.espessura >= 0.05 && w.espessura <= 0.6)) {
        p.add('A parede ${w.id} tem espessura de ${w.espessura} m.');
      }
      final vaos = [...w.aberturas]..sort((a, b) => a.inicio.compareTo(b.inicio));
      for (var i = 0; i < vaos.length; i++) {
        final a = vaos[i];
        if (a.largura <= 0 ||
            a.inicio < -0.01 ||
            a.inicio + a.largura > w.comprimento + 0.01) {
          p.add('O vão ${a.id} sai da parede ${w.id}.');
        }
        if (a.topo(alturas) > w.alturaEm(alturas) + 0.01) {
          p.add('O vão ${a.id} é mais alto que a parede ${w.id}.');
        }
        if (i > 0) {
          final anterior = vaos[i - 1];
          if (anterior.inicio + anterior.largura > a.inicio + 0.01) {
            p.add('Os vãos ${anterior.id} e ${a.id} se sobrepõem.');
          }
        }
      }
    }
    for (final c in comodos) {
      if (c.retangulos.isEmpty ||
          c.retangulos.any((r) => r.largura <= 0 || r.profundidade <= 0)) {
        p.add('O cômodo ${c.nome} não tem medidas.');
      }
    }
    return p;
  }

  Map<String, dynamic> toMap() => {
        'versao': versao,
        if (nome != null) 'nome': nome,
        if (fonte != null) 'fonte': fonte,
        'terreno': {'largura': largura, 'profundidade': profundidade},
        'frente': 'y+',
        'alturas': alturas.toMap(),
        'cobertura': {'tipo': cobertura.chave},
        'paredes': [for (final w in paredes) w.toMap()],
        'pilares': [for (final p in pilares) p.toMap()],
        'comodos': [for (final c in comodos) c.toMap()],
      };

  factory PlantaObra.fromMap(Map<String, dynamic> m) {
    final terreno = _mapa(m['terreno']);
    return PlantaObra(
      versao: (m['versao'] as num?)?.toInt() ?? 1,
      nome: m['nome'] as String?,
      fonte: m['fonte'] as String?,
      largura: _num(terreno['largura']),
      profundidade: _num(terreno['profundidade']),
      alturas: AlturasPlanta.fromMap(_mapa(m['alturas'])),
      cobertura: TipoCobertura.daChave(_mapa(m['cobertura'])['tipo']),
      paredes: [
        for (final (i, w) in _lista(m['paredes']).indexed)
          ParedePlanta.fromMap(_mapa(w), indice: i),
      ],
      pilares: [for (final p in _lista(m['pilares'])) PilarPlanta.fromMap(_mapa(p))],
      comodos: [
        for (final (i, c) in _lista(m['comodos']).indexed)
          ComodoPlanta.fromMap(_mapa(c), indice: i),
      ],
    );
  }
}

/// Alturas que a planta baixa não mostra (vêm do corte, ou do padrão).
@immutable
class AlturasPlanta {
  const AlturasPlanta({
    this.peDireito = 2.6,
    this.porta = 2.1,
    this.muro = 2.0,
  });

  /// Do piso pronto ao fundo da laje.
  final double peDireito;

  /// Altura padrão de porta (do piso ao topo do vão).
  final double porta;

  /// Altura padrão do muro de divisa.
  final double muro;

  Map<String, dynamic> toMap() =>
      {'peDireito': peDireito, 'porta': porta, 'muro': muro};

  factory AlturasPlanta.fromMap(Map<String, dynamic> m) => AlturasPlanta(
        peDireito: _num(m['peDireito'], 2.6),
        porta: _num(m['porta'], 2.1),
        muro: _num(m['muro'], 2.0),
      );
}

/// Como a casa é coberta. A planta baixa não mostra o telhado; o dono
/// escolhe na revisão.
enum TipoCobertura {
  /// Laje, platibanda e telhado de fibrocimento escondido atrás dela.
  lajePlatibanda('laje_platibanda');

  const TipoCobertura(this.chave);

  final String chave;

  static TipoCobertura daChave(Object? chave) => TipoCobertura.values
      .firstWhere((t) => t.chave == chave, orElse: () => lajePlatibanda);
}

enum TipoParede {
  /// Bloco cerâmico até o pé-direito; segura a laje.
  alvenaria('alvenaria'),

  /// Muro de divisa, mais baixo, sem laje em cima.
  muro('muro'),

  /// Mureta com vidro em cima (jardim de inverno, área de sol).
  muretaVidro('mureta_vidro');

  const TipoParede(this.chave);

  final String chave;

  static TipoParede daChave(Object? chave) => TipoParede.values
      .firstWhere((t) => t.chave == chave, orElse: () => alvenaria);
}

@immutable
class ParedePlanta {
  const ParedePlanta({
    required this.id,
    required this.de,
    required this.ate,
    this.espessura = 0.14,
    this.tipo = TipoParede.alvenaria,
    this.altura,
    this.aberturas = const [],
  });

  final String id;

  /// Pontas da linha de centro, em metros (x, y da planta).
  final (double, double) de;
  final (double, double) ate;
  final double espessura;
  final TipoParede tipo;

  /// Altura própria (muro, mureta); nula: o pé-direito.
  final double? altura;
  final List<AberturaPlanta> aberturas;

  double get comprimento =>
      math.sqrt(math.pow(ate.$1 - de.$1, 2) + math.pow(ate.$2 - de.$2, 2));

  /// Direção unitária de `de` para `ate`.
  (double, double) get direcao {
    final c = comprimento;
    if (c == 0) return (1, 0);
    return ((ate.$1 - de.$1) / c, (ate.$2 - de.$2) / c);
  }

  /// Ponto da linha de centro a [u] metros de `de`.
  (double, double) pontoEm(double u) {
    final d = direcao;
    return (de.$1 + d.$1 * u, de.$2 + d.$2 * u);
  }

  /// Altura da parede com as [alturas] da planta.
  double alturaEm(AlturasPlanta alturas) =>
      altura ??
      switch (tipo) {
        TipoParede.muro => alturas.muro,
        TipoParede.muretaVidro => alturas.porta,
        TipoParede.alvenaria => alturas.peDireito,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'de': [de.$1, de.$2],
        'ate': [ate.$1, ate.$2],
        'espessura': espessura,
        'tipo': tipo.chave,
        if (altura != null) 'altura': altura,
        if (aberturas.isNotEmpty)
          'aberturas': [for (final a in aberturas) a.toMap()],
      };

  factory ParedePlanta.fromMap(Map<String, dynamic> m, {int indice = 0}) =>
      ParedePlanta(
        id: m['id'] as String? ?? 'p${indice + 1}',
        de: _ponto(m['de']),
        ate: _ponto(m['ate']),
        espessura: _num(m['espessura'], 0.14),
        tipo: TipoParede.daChave(m['tipo']),
        altura: m['altura'] == null ? null : _num(m['altura']),
        aberturas: [
          for (final (i, a) in _lista(m['aberturas']).indexed)
            AberturaPlanta.fromMap(_mapa(a), indice: i),
        ],
      );
}

enum TipoAbertura {
  porta('porta'),
  portaCorrer('porta_correr'),

  /// Vão sem porta (passagem entre cômodos).
  passagem('passagem'),
  janela('janela'),
  portao('portao');

  const TipoAbertura(this.chave);

  final String chave;

  bool get ehJanela => this == janela;

  static TipoAbertura daChave(Object? chave) => TipoAbertura.values
      .firstWhere((t) => t.chave == chave, orElse: () => porta);
}

@immutable
class AberturaPlanta {
  const AberturaPlanta({
    required this.id,
    required this.tipo,
    required this.inicio,
    required this.largura,
    this.peitoril,
    this.altura,
  });

  final String id;
  final TipoAbertura tipo;

  /// Distância, ao longo da parede, do ponto `de` ao começo do vão.
  final double inicio;
  final double largura;

  /// Altura do piso à base do vão (janela); nulo: 1,0 m na janela, 0 nas
  /// portas.
  final double? peitoril;

  /// Altura do vão; nula: a da porta (portas e passagens) ou 1,2 m (janela).
  final double? altura;

  double base(AlturasPlanta a) => peitoril ?? (tipo.ehJanela ? 1.0 : 0.0);

  double topo(AlturasPlanta a) =>
      base(a) + (altura ?? (tipo.ehJanela ? 1.2 : a.porta));

  Map<String, dynamic> toMap() => {
        'id': id,
        'tipo': tipo.chave,
        'inicio': inicio,
        'largura': largura,
        if (peitoril != null) 'peitoril': peitoril,
        if (altura != null) 'altura': altura,
      };

  factory AberturaPlanta.fromMap(Map<String, dynamic> m, {int indice = 0}) =>
      AberturaPlanta(
        id: m['id'] as String? ?? 'v${indice + 1}',
        tipo: TipoAbertura.daChave(m['tipo']),
        inicio: _num(m['inicio']),
        largura: _num(m['largura']),
        peitoril: m['peitoril'] == null ? null : _num(m['peitoril']),
        altura: m['altura'] == null ? null : _num(m['altura']),
      );
}

@immutable
class PilarPlanta {
  const PilarPlanta({required this.x, required this.y, this.lado = 0.15});

  final double x;
  final double y;
  final double lado;

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'lado': lado};

  factory PilarPlanta.fromMap(Map<String, dynamic> m) => PilarPlanta(
        x: _num(m['x']),
        y: _num(m['y']),
        lado: _num(m['lado'], 0.15),
      );
}

/// Acabamento de piso de um cômodo.
enum PisoComodo {
  porcelanato('porcelanato'),
  ceramica('ceramica'),
  cimento('cimento'),
  garagem('garagem'),
  grama('grama'),
  madeira('madeira');

  const PisoComodo(this.chave);

  final String chave;

  String get rotulo => switch (this) {
        porcelanato => 'Porcelanato',
        ceramica => 'Cerâmica',
        cimento => 'Cimentado',
        garagem => 'Piso de garagem',
        grama => 'Grama',
        madeira => 'Madeira',
      };

  static PisoComodo daChave(Object? chave) => PisoComodo.values
      .firstWhere((t) => t.chave == chave, orElse: () => porcelanato);
}

@immutable
class RetanguloPlanta {
  const RetanguloPlanta(this.x, this.y, this.largura, this.profundidade);

  /// Canto de menor x e menor y.
  final double x;
  final double y;
  final double largura;
  final double profundidade;

  double get area => largura * profundidade;
  double get x1 => x + largura;
  double get y1 => y + profundidade;

  bool contem(double px, double py) =>
      px >= x && px <= x1 && py >= y && py <= y1;

  Map<String, dynamic> toMap() =>
      {'x': x, 'y': y, 'largura': largura, 'profundidade': profundidade};

  factory RetanguloPlanta.fromMap(Map<String, dynamic> m) => RetanguloPlanta(
        _num(m['x']),
        _num(m['y']),
        _num(m['largura']),
        _num(m['profundidade']),
      );
}

@immutable
class ComodoPlanta {
  const ComodoPlanta({
    required this.id,
    required this.nome,
    this.tipo = 'comodo',
    this.coberto = true,
    this.piso = PisoComodo.porcelanato,
    required this.retangulos,
  });

  final String id;
  final String nome;

  /// quarto, sala, cozinha, banheiro, garagem, varanda, quintal...
  final String tipo;

  /// Tem laje em cima.
  final bool coberto;
  final PisoComodo piso;

  /// O primeiro é o principal: dá as medidas mostradas.
  final List<RetanguloPlanta> retangulos;

  double get area => retangulos.fold<double>(0, (s, r) => s + r.area);

  RetanguloPlanta get principal => retangulos.first;

  bool contem(double x, double y) => retangulos.any((r) => r.contem(x, y));

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'tipo': tipo,
        'coberto': coberto,
        'piso': piso.chave,
        'retangulos': [for (final r in retangulos) r.toMap()],
      };

  factory ComodoPlanta.fromMap(Map<String, dynamic> m, {int indice = 0}) =>
      ComodoPlanta(
        id: m['id'] as String? ?? 'c${indice + 1}',
        nome: m['nome'] as String? ?? 'Cômodo ${indice + 1}',
        tipo: m['tipo'] as String? ?? 'comodo',
        coberto: m['coberto'] as bool? ?? true,
        piso: PisoComodo.daChave(m['piso']),
        retangulos: [
          for (final r in _lista(m['retangulos']))
            RetanguloPlanta.fromMap(_mapa(r)),
        ],
      );
}

double _num(Object? v, [double padrao = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? padrao;

Map<String, dynamic> _mapa(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

List<Object?> _lista(Object? v) => v is List ? v : const [];

(double, double) _ponto(Object? v) {
  final l = _lista(v);
  return (l.isNotEmpty ? _num(l[0]) : 0, l.length > 1 ? _num(l[1]) : 0);
}
