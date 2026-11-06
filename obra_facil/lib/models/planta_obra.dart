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
///
/// As [paredes] e os [comodos] são os do térreo. Sobrado e prédio têm os
/// andares de cima em [andares], cada um com a sua planta (e quantas vezes
/// ela se repete, no prédio).
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
    this.nomeTerreo = 'Térreo',
    this.andares = const [],
    this.modelo,
    this.fachada = const [],
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

  /// Nome do pavimento de baixo ("Térreo").
  final String nomeTerreo;

  /// Os andares acima do térreo, de baixo para cima.
  final List<AndarPlanta> andares;

  /// Os números do modelo pronto que gerou a planta (tipo, m², quartos...),
  /// para mostrar e refazer. Nulo: planta de verdade (lida ou de exemplo).
  final Map<String, dynamic>? modelo;

  /// O que a fachada do térreo tem além das paredes e dos vãos: moldura,
  /// ripado, aleta (os modelos prontos; a planta lida não traz).
  final List<ElementoFachada> fachada;

  /// Cômodos do térreo com laje.
  Iterable<ComodoPlanta> get comodosCobertos => comodos.where((c) => c.coberto);

  /// Pavimentos ao todo (o térreo e os andares, com as repetições).
  int get totalPavimentos =>
      1 + andares.fold<int>(0, (s, a) => s + a.repeticoes);

  /// As plantas diferentes, de baixo para cima: o térreo e cada andar.
  int get totalPlantas => 1 + andares.length;

  /// Nome de cada planta ("Térreo", "Superior", "1º ao 3º andar").
  List<String> get nomesDasPlantas =>
      [nomeTerreo, for (final a in andares) a.nome];

  /// A planta [i] (0 = térreo) sozinha, sem os outros andares: é o que a
  /// planta desenhada, a ficha do cômodo e o 360° usam.
  PlantaObra planta(int i) {
    if (i <= 0) {
      return andares.isEmpty ? this : _com(andares: const []);
    }
    final a = andares[i - 1];
    return _com(
      paredes: a.paredes,
      pilares: a.pilares,
      comodos: a.comodos,
      nomeTerreo: a.nome,
      andares: const [],
      fachada: a.fachada,
    );
  }

  /// Em que pavimento (0 = térreo) começa a planta [i].
  int pavimentoDaPlanta(int i) {
    var nivel = 1;
    for (var k = 0; k < i - 1 && k < andares.length; k++) {
      nivel += andares[k].repeticoes;
    }
    return i <= 0 ? 0 : nivel;
  }

  /// A planta (0 = térreo) que tem o cômodo [id], ou -1.
  int plantaDoComodo(String id) {
    if (comodos.any((c) => c.id == id)) return 0;
    for (var i = 0; i < andares.length; i++) {
      if (andares[i].comodos.any((c) => c.id == id)) return i + 1;
    }
    return -1;
  }

  /// Todos os cômodos, de todas as plantas.
  Iterable<ComodoPlanta> get todosOsComodos sync* {
    yield* comodos;
    for (final a in andares) {
      yield* a.comodos;
    }
  }

  /// Área construída (os cômodos cobertos de todos os pavimentos), em m².
  double get areaConstruida =>
      comodosCobertos.fold<double>(0, (s, c) => s + c.area) +
      andares.fold<double>(
          0,
          (s, a) =>
              s +
              a.repeticoes *
                  a.comodos
                      .where((c) => c.coberto)
                      .fold<double>(0, (t, c) => t + c.area));

  /// Uma cópia com outras partes.
  PlantaObra copiar({
    String? nome,
    String? fonte,
    AlturasPlanta? alturas,
    List<ComodoPlanta>? comodos,
    List<AndarPlanta>? andares,
    Map<String, dynamic>? modelo,
  }) =>
      _com(
        nome: nome,
        fonte: fonte,
        alturas: alturas,
        comodos: comodos,
        andares: andares,
        modelo: modelo,
      );

  PlantaObra _com({
    String? nome,
    String? fonte,
    AlturasPlanta? alturas,
    List<ParedePlanta>? paredes,
    List<PilarPlanta>? pilares,
    List<ComodoPlanta>? comodos,
    String? nomeTerreo,
    List<AndarPlanta>? andares,
    Map<String, dynamic>? modelo,
    List<ElementoFachada>? fachada,
  }) =>
      PlantaObra(
        versao: versao,
        nome: nome ?? this.nome,
        fonte: fonte ?? this.fonte,
        largura: largura,
        profundidade: profundidade,
        alturas: alturas ?? this.alturas,
        cobertura: cobertura,
        paredes: paredes ?? this.paredes,
        pilares: pilares ?? this.pilares,
        comodos: comodos ?? this.comodos,
        nomeTerreo: nomeTerreo ?? this.nomeTerreo,
        andares: andares ?? this.andares,
        modelo: modelo ?? this.modelo,
        fachada: fachada ?? this.fachada,
      );

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
    if (!(alturas.peDireito >= 2.2 && alturas.peDireito <= 4.5)) {
      p.add('O pé-direito de ${alturas.peDireito} m está fora do comum '
          '(2,20 a 4,50 m).');
    }
    _problemasDaPlanta(p, paredes, comodos, '');
    _problemasDaFachada(p, fachada, '');
    for (final a in andares) {
      if (a.repeticoes < 1) {
        p.add('O andar ${a.nome} não se repete nenhuma vez.');
      }
      _problemasDaPlanta(p, a.paredes, a.comodos, ' (${a.nome})');
      _problemasDaFachada(p, a.fachada, ' (${a.nome})');
    }
    final ids = <String>{};
    for (final c in todosOsComodos) {
      if (!ids.add(c.id)) p.add('Dois cômodos com o mesmo código: ${c.id}.');
    }
    return p;
  }

  void _problemasDaPlanta(List<String> p, List<ParedePlanta> paredes,
      List<ComodoPlanta> comodos, String onde) {
    if (paredes.isEmpty) p.add('A planta$onde não tem paredes.');
    if (comodos.isEmpty) p.add('A planta$onde não tem cômodos.');
    for (final w in paredes) {
      if (w.comprimento < 0.05) {
        p.add('A parede ${w.id} não tem comprimento.');
        continue;
      }
      if (!(w.espessura >= 0.05 && w.espessura <= 0.6)) {
        p.add('A parede ${w.id} tem espessura de ${w.espessura} m.');
      }
      final vaos = [...w.aberturas]
        ..sort((a, b) => a.inicio.compareTo(b.inicio));
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
  }

  static void _problemasDaFachada(
      List<String> p, List<ElementoFachada> fachada, String onde) {
    for (final e in fachada) {
      if (!(e.ate - e.de > 0.01) || !(e.topo - e.base > 0.01)) {
        p.add('Um elemento da fachada$onde (${e.tipo.chave}) não tem '
            'medidas.');
      }
    }
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
        if (nomeTerreo != 'Térreo') 'nomeTerreo': nomeTerreo,
        if (andares.isNotEmpty) 'andares': [for (final a in andares) a.toMap()],
        if (modelo != null) 'modelo': modelo,
        if (fachada.isNotEmpty) 'fachada': [for (final e in fachada) e.toMap()],
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
      pilares: [
        for (final p in _lista(m['pilares'])) PilarPlanta.fromMap(_mapa(p))
      ],
      comodos: [
        for (final (i, c) in _lista(m['comodos']).indexed)
          ComodoPlanta.fromMap(_mapa(c), indice: i),
      ],
      nomeTerreo: m['nomeTerreo'] as String? ?? 'Térreo',
      andares: [
        for (final (i, a) in _lista(m['andares']).indexed)
          AndarPlanta.fromMap(_mapa(a), indice: i),
      ],
      modelo: m['modelo'] is Map ? _mapa(m['modelo']) : null,
      fachada: [
        for (final e in _lista(m['fachada'])) ElementoFachada.fromMap(_mapa(e)),
      ],
    );
  }
}

/// Um andar acima do térreo: a planta dele e quantas vezes ela se repete
/// (no prédio, os andares-tipo iguais).
@immutable
class AndarPlanta {
  const AndarPlanta({
    required this.nome,
    required this.paredes,
    required this.comodos,
    this.pilares = const [],
    this.repeticoes = 1,
    this.fachada = const [],
  });

  /// "Superior", "1º ao 3º andar".
  final String nome;
  final List<ParedePlanta> paredes;
  final List<ComodoPlanta> comodos;
  final List<PilarPlanta> pilares;
  final int repeticoes;

  /// Moldura, ripado e aleta da fachada deste andar.
  final List<ElementoFachada> fachada;

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'repeticoes': repeticoes,
        'paredes': [for (final w in paredes) w.toMap()],
        'pilares': [for (final p in pilares) p.toMap()],
        'comodos': [for (final c in comodos) c.toMap()],
        if (fachada.isNotEmpty) 'fachada': [for (final e in fachada) e.toMap()],
      };

  factory AndarPlanta.fromMap(Map<String, dynamic> m, {int indice = 0}) =>
      AndarPlanta(
        nome: m['nome'] as String? ?? 'Andar ${indice + 1}',
        repeticoes: (m['repeticoes'] as num?)?.toInt() ?? 1,
        paredes: [
          for (final (i, w) in _lista(m['paredes']).indexed)
            ParedePlanta.fromMap(_mapa(w), indice: i),
        ],
        pilares: [
          for (final p in _lista(m['pilares'])) PilarPlanta.fromMap(_mapa(p))
        ],
        comodos: [
          for (final (i, c) in _lista(m['comodos']).indexed)
            ComodoPlanta.fromMap(_mapa(c), indice: i),
        ],
        fachada: [
          for (final e in _lista(m['fachada']))
            ElementoFachada.fromMap(_mapa(e)),
        ],
      );
}

/// Alturas que a planta baixa não mostra (vêm do corte, ou do padrão).
@immutable
class AlturasPlanta {
  const AlturasPlanta({
    this.peDireito = 2.6,
    this.porta = 2.1,
    this.muro = 2.0,
    this.platibanda = 0.6,
  });

  /// Do piso pronto ao fundo da laje.
  final double peDireito;

  /// Altura padrão de porta (do piso ao topo do vão).
  final double porta;

  /// Altura padrão do muro de divisa.
  final double muro;

  /// Da laje de cobertura ao topo da platibanda (esconde o telhado).
  final double platibanda;

  Map<String, dynamic> toMap() => {
        'peDireito': peDireito,
        'porta': porta,
        'muro': muro,
        'platibanda': platibanda,
      };

  factory AlturasPlanta.fromMap(Map<String, dynamic> m) => AlturasPlanta(
        peDireito: _num(m['peDireito'], 2.6),
        porta: _num(m['porta'], 2.1),
        muro: _num(m['muro'], 2.0),
        platibanda: _num(m['platibanda'], 0.6).clamp(0.3, 2.0).toDouble(),
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

  /// Portão no muro (de grade).
  portao('portao'),

  /// Porta da garagem na parede da casa (de lâminas, sobe ou basculante).
  portaGaragem('porta_garagem'),

  /// Porta de entrada pivotante, larga e alta, de madeira.
  portaPivotante('porta_pivotante');

  const TipoAbertura(this.chave);

  final String chave;

  bool get ehJanela => this == janela;

  /// Fecha com uma folha (tudo menos a passagem e a janela).
  bool get ehPorta => this != passagem && this != janela;

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
    this.unidade,
    this.fachada,
  });

  final String id;
  final String nome;

  /// A unidade do cômodo no geminado ou no prédio ("Casa 2", "Apto 3").
  final String? unidade;

  /// Acabamento da fachada na frente do cômodo, na maquete: "ripado"
  /// (ripas de madeira) ou "moldura" (quadro de concreto).
  final String? fachada;

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
        if (unidade != null) 'unidade': unidade,
        if (fachada != null) 'fachada': fachada,
      };

  /// Uma cópia com outro nome, cobertura ou piso (a revisão da planta).
  ComodoPlanta copiar({String? nome, bool? coberto, PisoComodo? piso}) =>
      ComodoPlanta(
        id: id,
        nome: nome ?? this.nome,
        tipo: tipo,
        coberto: coberto ?? this.coberto,
        piso: piso ?? this.piso,
        retangulos: retangulos,
        unidade: unidade,
        fachada: fachada,
      );

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
        unidade: m['unidade'] as String?,
        fachada: m['fachada'] as String?,
      );
}

/// O que um [ElementoFachada] é.
enum TipoElementoFachada {
  /// Quadro de concreto em volta de um vão da fachada (a sacada): quatro
  /// faixas de [ElementoFachada.borda]; as dos lados e a de cima vão do
  /// lado de fora até o fundo da sacada ([ElementoFachada.recuo]); a de
  /// baixo é a mureta da frente, até o [ElementoFachada.peitoril].
  moldura('moldura'),

  /// Ripas de madeira em pé, presas na parede, a cada
  /// [ElementoFachada.passo].
  ripadoVertical('ripado_vertical'),

  /// Ripas deitadas (a faixa sobre a porta).
  ripadoHorizontal('ripado_horizontal'),

  /// Lâmina em pé saindo da fachada (a divisa entre as casas).
  aleta('aleta'),

  /// Pano de parede rebocada e pintada que fecha uma fresta da fachada
  /// (entre a moldura e a divisa, do lado da sacada).
  pano('pano');

  const TipoElementoFachada(this.chave);

  final String chave;

  static TipoElementoFachada daChave(Object? chave) =>
      TipoElementoFachada.values
          .firstWhere((t) => t.chave == chave, orElse: () => aleta);
}

/// Uma peça da fachada que não é parede nem vão: a moldura da sacada, o
/// ripado, a aleta da divisa. Fica numa face voltada para a frente ou para
/// o fundo do terreno (as fachadas dos modelos prontos).
@immutable
class ElementoFachada {
  const ElementoFachada({
    required this.tipo,
    required this.de,
    required this.ate,
    required this.y,
    this.sentido = 1,
    required this.base,
    required this.topo,
    this.saliencia = 0,
    this.recuo = 0,
    this.borda = 0.5,
    this.peitoril,
    this.passo = 0.1,
  });

  final TipoElementoFachada tipo;

  /// De onde a onde vai, em `x` da planta.
  final double de;
  final double ate;

  /// A face em que está presa, em `y` da planta.
  final double y;

  /// Para onde a face olha: +1 para a rua (y crescendo), -1 para o fundo.
  final int sentido;

  /// Alturas da base e do topo, a partir do piso pronto do pavimento
  /// (negativa: desce abaixo dele).
  final double base;
  final double topo;

  /// Quanto sai para fora da face.
  final double saliencia;

  /// Quanto entra para dentro da face (a moldura cobre o fundo da sacada).
  final double recuo;

  /// Largura das faixas da moldura.
  final double borda;

  /// Topo da faixa de baixo da moldura (a mureta); nulo: sem ela.
  final double? peitoril;

  /// Distância entre as ripas.
  final double passo;

  double get largura => ate - de;

  Map<String, dynamic> toMap() => {
        'tipo': tipo.chave,
        'de': de,
        'ate': ate,
        'y': y,
        if (sentido != 1) 'sentido': sentido,
        'base': base,
        'topo': topo,
        if (saliencia != 0) 'saliencia': saliencia,
        if (recuo != 0) 'recuo': recuo,
        if (tipo == TipoElementoFachada.moldura) 'borda': borda,
        if (peitoril != null) 'peitoril': peitoril,
        if (tipo == TipoElementoFachada.ripadoVertical ||
            tipo == TipoElementoFachada.ripadoHorizontal)
          'passo': passo,
      };

  factory ElementoFachada.fromMap(Map<String, dynamic> m) => ElementoFachada(
        tipo: TipoElementoFachada.daChave(m['tipo']),
        de: _num(m['de']),
        ate: _num(m['ate']),
        y: _num(m['y']),
        sentido: _num(m['sentido'], 1) < 0 ? -1 : 1,
        base: _num(m['base']),
        topo: _num(m['topo']),
        saliencia: _num(m['saliencia']),
        recuo: _num(m['recuo']),
        borda: _num(m['borda'], 0.5),
        peitoril: m['peitoril'] == null ? null : _num(m['peitoril']),
        passo: _num(m['passo'], 0.1).clamp(0.03, 1.0).toDouble(),
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
