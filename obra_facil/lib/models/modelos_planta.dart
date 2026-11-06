import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'planta_obra.dart';

/// Os modelos prontos de obra: o dono informa poucos números (m², quartos,
/// térreo ou sobrado, quantas unidades, quantos andares) e o app monta uma
/// planta coerente na hora: cômodos, paredes, portas, janelas, quintal,
/// garagem, muros e escada. Serve para ter a maquete e o "por dentro" sem a
/// planta de verdade; quem quer o projeto exato envia a planta.
enum TipoModelo {
  casa('casa', 'Casa'),
  geminado('geminado', 'Geminado'),
  predio('predio', 'Prédio');

  const TipoModelo(this.chave, this.rotulo);

  final String chave;
  final String rotulo;

  static TipoModelo daChave(Object? chave) =>
      values.firstWhere((t) => t.chave == chave, orElse: () => casa);
}

/// O que o dono pediu. A [area] é a da casa, a de cada unidade do geminado
/// ou a de cada apartamento.
@immutable
class PedidoModelo {
  const PedidoModelo({
    required this.tipo,
    required this.area,
    this.quartos = 2,
    this.sobrado = false,
    this.unidades = 2,
    this.apartamentos = 8,
    this.andares = 4,
  });

  final TipoModelo tipo;
  final double area;
  final int quartos;

  /// Casa e geminado: dois pavimentos.
  final bool sobrado;

  /// Geminado: 2, 3 ou 4 casas lado a lado.
  final int unidades;

  /// Prédio: quantos apartamentos e em quantos andares.
  final int apartamentos;
  final int andares;

  /// Prédio: apartamentos por andar (arredonda para cima).
  int get aptosPorAndar => math.max(1, (apartamentos / andares).ceil());

  /// Prédio: apartamentos de verdade (por andar × andares).
  int get totalApartamentos => aptosPorAndar * andares;

  /// Quartos que cabem bem na área (sugestão inicial do formulário).
  static int quartosPara(double area) => area < 45
      ? 1
      : area < 80
          ? 2
          : area < 130
              ? 3
              : 4;

  /// O que impede de montar (nulo: dá para montar).
  String? get problema {
    final unidade = switch (tipo) {
      TipoModelo.casa => 'a casa',
      TipoModelo.geminado => 'cada casa',
      TipoModelo.predio => 'cada apartamento',
    };
    final (minimo, maximo) = switch (tipo) {
      TipoModelo.casa => (sobrado ? 100.0 : 35.0, 400.0),
      TipoModelo.geminado => (sobrado ? 100.0 : 35.0, 250.0),
      TipoModelo.predio => (30.0, 200.0),
    };
    if (!(area >= minimo)) {
      return 'Informe pelo menos ${minimo.round()} m² para $unidade.';
    }
    if (area > maximo) return 'Até ${maximo.round()} m² para $unidade.';
    final maxQuartos = tipo == TipoModelo.predio ? 3 : 4;
    if (quartos < 1 || quartos > maxQuartos) {
      return 'De 1 a $maxQuartos quartos.';
    }
    // Cada quarto pede uns 9 m² e o resto da casa uns 22.
    final porPavimento = sobrado ? area / 2 : area;
    final precisa = sobrado ? quartos * 9.0 + 6 : quartos * 9.0 + 22;
    if (porPavimento < precisa) {
      return 'Pouca área para $quartos quartos: aumente os m² ou tire um '
          'quarto.';
    }
    if (tipo == TipoModelo.geminado && (unidades < 2 || unidades > 4)) {
      return 'O geminado tem de 2 a 4 casas.';
    }
    if (tipo == TipoModelo.predio) {
      if (andares < 1 || andares > 20) return 'De 1 a 20 andares.';
      if (apartamentos < 1) return 'Informe quantos apartamentos.';
      if (aptosPorAndar > 8) {
        return 'São $aptosPorAndar apartamentos por andar: o máximo é 8. '
            'Aumente os andares.';
      }
    }
    return null;
  }

  /// "Casa térrea · 90 m² · 2 quartos".
  String get resumo {
    final m2 = '${area.round()} m²';
    final q = quartos == 1 ? '1 quarto' : '$quartos quartos';
    return switch (tipo) {
      TipoModelo.casa => '${sobrado ? 'Sobrado' : 'Casa térrea'} · $m2 · $q',
      TipoModelo.geminado =>
        'Geminado · $unidades ${sobrado ? 'sobrados' : 'casas'} de $m2 · $q',
      TipoModelo.predio => 'Prédio · $totalApartamentos aptos de $m2 · '
          '$andares ${andares == 1 ? 'andar' : 'andares'} · $q',
    };
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo.chave,
        'area': area,
        'quartos': quartos,
        if (tipo != TipoModelo.predio) 'sobrado': sobrado,
        if (tipo == TipoModelo.geminado) 'unidades': unidades,
        if (tipo == TipoModelo.predio) ...{
          'apartamentos': apartamentos,
          'andares': andares,
        },
      };

  factory PedidoModelo.fromMap(Map<String, dynamic> m) => PedidoModelo(
        tipo: TipoModelo.daChave(m['tipo']),
        area: (m['area'] as num?)?.toDouble() ?? 70,
        quartos: (m['quartos'] as num?)?.toInt() ?? 2,
        sobrado: m['sobrado'] as bool? ?? false,
        unidades: (m['unidades'] as num?)?.toInt() ?? 2,
        apartamentos: (m['apartamentos'] as num?)?.toInt() ?? 8,
        andares: (m['andares'] as num?)?.toInt() ?? 4,
      );

  @override
  bool operator ==(Object other) =>
      other is PedidoModelo && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}

/// Monta a planta de um [PedidoModelo]. Lança [ArgumentError] se o pedido
/// tem [PedidoModelo.problema].
abstract final class ModelosPlanta {
  static PlantaObra montar(PedidoModelo pedido) {
    final problema = pedido.problema;
    if (problema != null) throw ArgumentError(problema);
    return switch (pedido.tipo) {
      TipoModelo.casa => _casas(pedido, 1),
      TipoModelo.geminado => _casas(pedido, pedido.unidades),
      TipoModelo.predio => _predio(pedido),
    };
  }

  // ------------------------------------------------------------ casas

  static const double _lateral = 1.0;
  static const double _fundos = 3.0;
  static const double _frente = 5.5;

  static PlantaObra _casas(PedidoModelo p, int n) {
    final unidades = [
      for (var i = 0; i < n; i++)
        _unidadeCasa('u${i + 1}-', p.area, p.quartos, p.sobrado,
            n == 1 ? null : 'Casa ${i + 1}'),
    ];
    final wu = unidades.first.largura, du = unidades.first.profundidade;
    final largura = _lateral * 2 + n * wu;
    final profundidade = _fundos + du + _frente;

    final terreo = _Pavimento();
    final superior = _Pavimento();
    for (var i = 0; i < n; i++) {
      final u = unidades[i];
      final ox = _lateral + i * wu;
      terreo.juntar(u.terreo, ox, _fundos);
      if (p.sobrado) superior.juntar(u.superior!, ox, _fundos);
      final nomeUnidade = n == 1 ? null : 'Casa ${i + 1}';
      final x0 = i == 0 ? 0.0 : ox, x1 = i == n - 1 ? largura : ox + wu;
      final prefixo = 'u${i + 1}-';
      terreo.cels.addAll([
        _Cel('${prefixo}garagem', 'Garagem', 'garagem', x0, _fundos + du, x1,
            profundidade,
            coberto: false, piso: PisoComodo.garagem, unidade: nomeUnidade),
        _Cel('${prefixo}quintal', 'Quintal', 'quintal', x0, 0, x1, _fundos,
            coberto: false, piso: PisoComodo.grama, unidade: nomeUnidade),
        if (i == 0)
          _Cel('${prefixo}lateral-e', 'Corredor lateral', 'circulacao', 0,
              _fundos, _lateral, _fundos + du,
              coberto: false, piso: PisoComodo.cimento, unidade: nomeUnidade),
        if (i == n - 1)
          _Cel('${prefixo}lateral-d', 'Corredor lateral', 'circulacao',
              largura - _lateral, _fundos, largura, _fundos + du,
              coberto: false, piso: PisoComodo.cimento, unidade: nomeUnidade),
      ]);
    }
    final nome = switch (p.tipo) {
      TipoModelo.geminado =>
        'Geminado de $n ${p.sobrado ? 'sobrados' : 'casas'}',
      _ => p.sobrado ? 'Sobrado' : 'Casa térrea',
    };
    return _montar(
      pedido: p,
      nome: '$nome de ${p.area.round()} m²',
      largura: largura,
      profundidade: profundidade,
      terreo: terreo,
      andares: [if (p.sobrado) ('Superior', superior, 1)],
    );
  }

  /// Uma casa (térrea ou sobrado) em coordenadas locais, com a frente em y
  /// alto e o fundo em y = 0.
  static _Casa _unidadeCasa(
      String pre, double area, int q, bool sobrado, String? unidade) {
    return sobrado
        ? _sobrado(pre, area, q, unidade)
        : _terrea(pre, area, q, unidade, portaDaFrente: true);
  }

  static const double _corredor = 1.1;

  /// Térrea: na frente a sala e a cozinha; atrás, os quartos e o banheiro
  /// em duas colunas, com o corredor no meio.
  static _Casa _terrea(String pre, double area, int q, String? unidade,
      {required bool portaDaFrente}) {
    final nb = q >= 3 ? 2 : 1;
    // Abaixo de 50 m², a área de serviço fica junto da cozinha.
    final temLavanderia = area >= 50;
    var aq = (area * 0.14).clamp(7.5, 14.0);
    final largura = (math.sqrt(area) * 0.95).clamp(6.0, 14.0);
    final cw = (largura - _corredor) / 2;
    late _Colunas col;
    late double social;
    for (var tentativa = 0; tentativa < 16; tentativa++) {
      col = _Colunas(cw);
      if (temLavanderia) {
        col.direita.add(_Item(
            'lavanderia', 'Lavanderia', 'lavanderia', 3.0, 1.5,
            piso: PisoComodo.ceramica));
      }
      for (var b = 0; b < nb; b++) {
        col.direita.add(_Item('banheiro-${b + 1}',
            nb == 1 ? 'Banheiro' : 'Banheiro ${b + 1}', 'banheiro', 3.6, 1.7,
            piso: PisoComodo.ceramica));
      }
      for (var k = 0; k < q; k++) {
        col.naMaisCurta(_Item('quarto-${k + 1}',
            q == 1 ? 'Quarto' : 'Quarto ${k + 1}', 'quarto', aq, 2.6));
      }
      social = (area - largura * col.profundidade) / largura;
      if (social < 3.0 && aq > 7.0) {
        aq = math.max(7.0, aq * 0.93);
        continue;
      }
      if (social > 6.0 && aq < 20) {
        aq = math.min(20, aq * 1.08);
        continue;
      }
      break;
    }
    social = math.max(3.0, social);
    final db = col.profundidade;
    final d = db + social;
    final casa = _Casa(largura, d);
    final t = casa.terreo;
    // Fundos: as duas colunas e o corredor.
    col.colocar(t, pre, unidade, 0, db);
    final corredor = _Cel(
        '${pre}corredor', 'Corredor', 'circulacao', cw, 0, cw + _corredor, db,
        unidade: unidade);
    t.cels.add(corredor);
    // Frente: sala e cozinha (a cozinha fica em cima da coluna da direita,
    // ao lado da lavanderia).
    final wk = math.min(math.max(largura * 0.36, 2.6), cw - 0.1);
    final sala = _Cel('${pre}sala', 'Sala', 'sala', 0, db, largura - wk, d,
        unidade: unidade);
    final cozinha = _Cel(
        '${pre}cozinha',
        temLavanderia ? 'Cozinha' : 'Cozinha e serviço',
        'cozinha',
        largura - wk,
        db,
        largura,
        d,
        piso: PisoComodo.ceramica,
        unidade: unidade);
    t.cels.addAll([sala, cozinha]);
    t.ligar(sala.id, cozinha.id, TipoAbertura.passagem, 1.2);
    t.ligar(sala.id, corredor.id, TipoAbertura.passagem, 0.9);
    if (temLavanderia) {
      t.ligar(cozinha.id, '${pre}lavanderia', TipoAbertura.porta, 0.8);
    }
    for (final item in [...col.esquerda, ...col.direita]) {
      t.ligar('$pre${item.id}', corredor.id, TipoAbertura.porta,
          item.tipo == 'banheiro' ? 0.7 : 0.8);
    }
    if (portaDaFrente) t.porFora(sala.id, _Lado.frente, 0.9);
    casa.entrada = corredor.id;
    return casa;
  }

  /// Sobrado: embaixo a sala, a cozinha, o lavabo, a lavanderia e a escada;
  /// em cima os quartos e os banheiros. A escada fica no mesmo lugar nos
  /// dois pavimentos (fundo da coluna da direita).
  static _Casa _sobrado(String pre, double area, int q, String? unidade) {
    const escada = 2.6;
    final porPavimento = area / 2;
    final nb = q >= 2 ? 2 : 1;
    var aq = (porPavimento * 0.24).clamp(8.0, 24.0);
    late double largura, cw, d, dbTerreo;
    late _Colunas cima, baixo;
    for (var tentativa = 0; tentativa < 12; tentativa++) {
      largura = (math.sqrt(porPavimento) * 0.95).clamp(6.2, 14.0);
      cw = (largura - _corredor) / 2;
      cima = _Colunas(cw)..escadaNoFundo = escada;
      for (var b = 0; b < nb; b++) {
        cima.direita.add(_Item('banheiro-${b + 1}',
            nb == 1 ? 'Banheiro' : 'Banheiro ${b + 1}', 'banheiro', 3.6, 1.7,
            piso: PisoComodo.ceramica));
      }
      for (var k = 0; k < q; k++) {
        cima.naMaisCurta(_Item('quarto-${k + 1}',
            q == 1 ? 'Quarto' : 'Quarto ${k + 1}', 'quarto', aq, 2.6));
      }
      baixo = _Colunas(cw)..escadaNoFundo = escada;
      baixo.esquerda.add(_Item('cozinha', 'Cozinha', 'cozinha',
          math.max(porPavimento * 0.16, 8), 2.8,
          piso: PisoComodo.ceramica));
      baixo.direita.addAll([
        _Item('lavabo', 'Lavabo', 'banheiro', 2.2, 1.3,
            piso: PisoComodo.ceramica),
        _Item('lavanderia', 'Lavanderia', 'lavanderia', 3.0, 1.4,
            piso: PisoComodo.ceramica),
      ]);
      dbTerreo = baixo.profundidade;
      // A sala fica com o que sobra da área pedida (no mínimo 3,2 m).
      d = math.max(
          math.max(cima.profundidade, dbTerreo + 3.2), porPavimento / largura);
      final real = largura * d;
      if (real > porPavimento * 1.1 && aq > 7.5) {
        aq = math.max(7.5, aq * 0.93);
        continue;
      }
      if (cima.profundidade < d * 0.85 && aq < 24) {
        aq = math.min(24, aq * 1.08);
        continue;
      }
      break;
    }
    final casa = _Casa(largura, d)..superior = _Pavimento();
    // Térreo.
    final t = casa.terreo;
    baixo.colocar(t, pre, unidade, 0, dbTerreo);
    final corredor = _Cel('${pre}corredor', 'Corredor', 'circulacao', cw, 0,
        cw + _corredor, dbTerreo,
        unidade: unidade);
    final sala = _Cel('${pre}sala', 'Sala', 'sala', 0, dbTerreo, largura, d,
        unidade: unidade);
    t.cels.addAll([corredor, sala]);
    t.ligar(sala.id, corredor.id, TipoAbertura.passagem, 0.9);
    t.ligar(sala.id, '${pre}cozinha', TipoAbertura.passagem, 1.5);
    t.ligar('${pre}lavabo', corredor.id, TipoAbertura.porta, 0.7);
    t.ligar('${pre}lavanderia', corredor.id, TipoAbertura.porta, 0.8);
    t.ligar('${pre}escada', corredor.id, TipoAbertura.passagem, 0.9);
    t.porFora(sala.id, _Lado.frente, 0.9);
    // Superior.
    final s = casa.superior!;
    cima.colocar(s, '${pre}s-', unidade, 0, d);
    final circ = _Cel('${pre}s-circulacao', 'Circulação', 'circulacao', cw, 0,
        cw + _corredor, d,
        unidade: unidade);
    s.cels.add(circ);
    for (final item in [...cima.esquerda, ...cima.direita]) {
      s.ligar('${pre}s-${item.id}', circ.id, TipoAbertura.porta,
          item.tipo == 'banheiro' ? 0.7 : 0.8);
    }
    s.ligar('${pre}s-escada', circ.id, TipoAbertura.passagem, 0.9);
    casa.entrada = corredor.id;
    return casa;
  }

  // ------------------------------------------------------------ prédio

  static const double _corredorPredio = 1.4;
  static const double _nucleo = 2.8;

  /// Prédio: os apartamentos em duas filas (frente e fundos) com o corredor
  /// no meio e o núcleo (escada e hall) na ponta direita. Todos os andares
  /// são iguais.
  static PlantaObra _predio(PedidoModelo p) {
    final k = p.aptosPorAndar;
    final frente = (k / 2).ceil(), fundos = k ~/ 2;
    final modelo = _terrea('', p.area, p.quartos, null, portaDaFrente: false);
    final wu = modelo.largura, du = modelo.profundidade;
    final yCorredor = fundos > 0 ? du : 0.0;
    final yFrente = yCorredor + _corredorPredio;
    final dPredio = yFrente + du;
    final wFilas = frente * wu;
    final wPredio = wFilas + _nucleo;
    const lat = 1.5, atras = 3.0, adiante = 4.0;
    final largura = wPredio + lat * 2;
    final profundidade = atras + dPredio + adiante;

    _Pavimento andar(bool terreo) {
      final pav = _Pavimento();
      final ox = lat, oy = atras;
      var n = 0;
      for (var i = 0; i < frente; i++) {
        n++;
        final apto =
            _terrea('a$n-', p.area, p.quartos, 'Apto $n', portaDaFrente: false);
        pav.juntar(apto.terreo, ox + i * wu, oy + yFrente);
        pav.ligar(apto.entrada, 'corredor', TipoAbertura.porta, 0.9);
      }
      for (var i = 0; i < fundos; i++) {
        n++;
        final apto =
            _terrea('a$n-', p.area, p.quartos, 'Apto $n', portaDaFrente: false);
        // Fila dos fundos: espelhada, com a sala para o fundo do terreno.
        pav.juntar(apto.terreo, ox + i * wu, oy, espelharY: du);
        pav.ligar(apto.entrada, 'corredor', TipoAbertura.porta, 0.9);
      }
      final xn = ox + wFilas;
      pav.cels.add(_Cel('corredor', 'Corredor', 'circulacao', ox,
          oy + yCorredor, ox + wFilas, oy + yFrente));
      // O núcleo, na ponta do corredor: o hall na altura do corredor, a
      // escada encostada nele, a entrada na frente e um depósito no que
      // sobra no fundo.
      const lado = 2.8, prof = 2.8;
      final meio = (yCorredor + yFrente) / 2;
      var h0 = math.max(0.0, meio - lado / 2);
      var h1 = h0 + lado;
      double e0, e1;
      if (h0 >= prof) {
        e0 = h0 - prof;
        e1 = h0;
      } else {
        e0 = h1;
        e1 = h1 + prof;
      }
      // Sem espaço para a entrada na frente: a escada ou o hall vão até lá.
      final topo = math.max(h1, e1);
      final temEntrada = dPredio - topo >= 1.5;
      if (!temEntrada) {
        if (e1 > h1) {
          e1 = dPredio;
        } else {
          h1 = dPredio;
        }
      }
      final fundo = math.min(h0, e0);
      final temDeposito = fundo >= 0.8;
      if (!temDeposito) {
        if (e0 < h0) {
          e0 = 0;
        } else {
          h0 = 0;
        }
      }
      pav.cels.addAll([
        _Cel('hall', 'Hall', 'circulacao', xn, oy + h0, xn + _nucleo, oy + h1,
            piso: PisoComodo.ceramica),
        _Cel('escada', 'Escada', 'escada', xn, oy + e0, xn + _nucleo, oy + e1,
            piso: PisoComodo.cimento),
        if (temEntrada)
          _Cel('entrada', terreo ? 'Entrada' : 'Circulação', 'hall', xn,
              oy + math.max(h1, e1), xn + _nucleo, oy + dPredio,
              piso: PisoComodo.ceramica),
        if (temDeposito)
          _Cel('deposito', 'Depósito', 'despensa', xn, oy, xn + _nucleo,
              oy + fundo,
              piso: PisoComodo.cimento),
      ]);
      pav.ligar('escada', 'hall', TipoAbertura.passagem, 1.2);
      pav.ligar('corredor', 'hall', TipoAbertura.passagem, 1.2);
      if (temEntrada) {
        pav.ligar(
            'entrada', e1 > h1 ? 'escada' : 'hall', TipoAbertura.passagem, 1.2);
      }
      if (temDeposito) {
        pav.ligar(
            'deposito', e0 < h0 ? 'escada' : 'hall', TipoAbertura.porta, 0.8);
      }
      if (terreo) {
        pav.porFora(temEntrada ? 'entrada' : (e1 > h1 ? 'escada' : 'hall'),
            _Lado.frente, 1.2);
        pav.cels.addAll([
          _Cel('frente', 'Frente', 'jardim', 0, atras + dPredio, largura,
              profundidade,
              coberto: false, piso: PisoComodo.cimento),
          _Cel('fundos', 'Fundos', 'quintal', 0, 0, largura, atras,
              coberto: false, piso: PisoComodo.grama),
          _Cel('lateral-e', 'Lateral', 'circulacao', 0, atras, lat,
              atras + dPredio,
              coberto: false, piso: PisoComodo.cimento),
          _Cel('lateral-d', 'Lateral', 'circulacao', largura - lat, atras,
              largura, atras + dPredio,
              coberto: false, piso: PisoComodo.cimento),
          // A vaga da fila dos fundos que ficou sem apartamento.
          if (fundos < frente && fundos > 0)
            _Cel('area-livre', 'Área livre', 'jardim', ox + fundos * wu, oy,
                ox + wFilas, oy + du,
                coberto: false, piso: PisoComodo.grama),
        ]);
      }
      return pav;
    }

    return _montar(
      pedido: p,
      nome: 'Prédio de ${p.totalApartamentos} apartamentos',
      largura: largura,
      profundidade: profundidade,
      terreo: andar(true),
      andares: [
        if (p.andares > 1)
          (
            p.andares == 2 ? '2º andar' : '2º ao ${p.andares}º andar',
            andar(false),
            p.andares - 1
          ),
      ],
    );
  }

  // ------------------------------------------------------------ montagem

  static PlantaObra _montar({
    required PedidoModelo pedido,
    required String nome,
    required double largura,
    required double profundidade,
    required _Pavimento terreo,
    required List<(String, _Pavimento, int)> andares,
  }) {
    final t = _Construtor(terreo, largura, profundidade, 't', terreo: true);
    return PlantaObra(
      nome: nome,
      fonte: 'Modelo do app: ${pedido.resumo}',
      largura: _r(largura),
      profundidade: _r(profundidade),
      alturas: const AlturasPlanta(peDireito: 2.6, porta: 2.1, muro: 2.0),
      paredes: t.paredes,
      comodos: t.comodos,
      nomeTerreo: 'Térreo',
      andares: [
        for (final (i, (nomeAndar, pav, rep)) in andares.indexed)
          () {
            final c = _Construtor(pav, largura, profundidade, 'a${i + 1}');
            return AndarPlanta(
              nome: nomeAndar,
              paredes: c.paredes,
              comodos: c.comodos,
              repeticoes: rep,
            );
          }(),
      ],
      modelo: pedido.toMap(),
    );
  }
}

double _r(double v) => (v * 1000).round() / 1000;

// ============================================================== células

enum _Lado { frente, fundos, esquerda, direita }

/// Um cômodo como retângulo pelas linhas de centro das paredes.
class _Cel {
  _Cel(this.id, this.nome, this.tipo, this.x0, this.y0, this.x1, this.y1,
      {this.coberto = true, this.piso = PisoComodo.porcelanato, this.unidade});

  String id;
  final String nome;
  final String tipo;
  double x0, y0, x1, y1;
  final bool coberto;
  final PisoComodo piso;
  final String? unidade;

  _Cel mover(double dx, double dy, {double? espelharY, String prefixo = ''}) {
    var a = y0, b = y1;
    if (espelharY != null) {
      a = espelharY - y1;
      b = espelharY - y0;
    }
    return _Cel('$prefixo$id', nome, tipo, x0 + dx, a + dy, x1 + dx, b + dy,
        coberto: coberto, piso: piso, unidade: unidade);
  }
}

/// Porta, passagem ou janela pedida entre dois cômodos ([b]) ou para fora
/// ([lado]).
class _Lig {
  _Lig(this.a, this.b, this.lado, this.tipo, this.largura);

  final String a;
  final String? b;
  final _Lado? lado;
  final TipoAbertura tipo;
  final double largura;
}

class _Pavimento {
  final List<_Cel> cels = [];
  final List<_Lig> ligs = [];

  void ligar(String a, String b, TipoAbertura tipo, double largura) =>
      ligs.add(_Lig(a, b, null, tipo, largura));

  void porFora(String a, _Lado lado, double largura) =>
      ligs.add(_Lig(a, null, lado, TipoAbertura.porta, largura));

  /// Junta [outro] deslocado (e espelhado em y, na fila dos fundos do
  /// prédio: um espelho troca frente e fundo, mas não as ligações).
  void juntar(_Pavimento outro, double dx, double dy, {double? espelharY}) {
    for (final c in outro.cels) {
      cels.add(c.mover(dx, dy, espelharY: espelharY));
    }
    for (final l in outro.ligs) {
      var lado = l.lado;
      if (espelharY != null && lado != null) {
        lado = switch (lado) {
          _Lado.frente => _Lado.fundos,
          _Lado.fundos => _Lado.frente,
          _ => lado,
        };
      }
      ligs.add(_Lig(l.a, l.b, lado, l.tipo, l.largura));
    }
  }
}

/// Uma casa montada em coordenadas locais.
class _Casa {
  _Casa(this.largura, this.profundidade);

  final double largura;
  final double profundidade;
  final _Pavimento terreo = _Pavimento();
  _Pavimento? superior;

  /// O cômodo por onde se entra (o corredor), já com o prefixo.
  String entrada = '';
}

/// Um cômodo a pôr numa coluna: área desejada e profundidade mínima.
class _Item {
  _Item(this.id, this.nome, this.tipo, this.area, this.minimo,
      {this.piso = PisoComodo.porcelanato});

  final String id;
  final String nome;
  final String tipo;
  final double area;
  final double minimo;
  final PisoComodo piso;
}

/// Duas colunas de cômodos, uma de cada lado do corredor. A escada (se
/// houver) fica no fundo da coluna da direita, sempre do mesmo tamanho.
class _Colunas {
  _Colunas(this.largura);

  final double largura;
  final esquerda = <_Item>[];
  final direita = <_Item>[];
  double escadaNoFundo = 0;

  double _prof(_Item i) => math.max(i.area / largura, i.minimo);

  double get _esquerda => esquerda.fold(0.0, (s, i) => s + _prof(i));

  double get _direita =>
      direita.fold(0.0, (s, i) => s + _prof(i)) + escadaNoFundo;

  double get profundidade => math.max(_esquerda, _direita);

  void naMaisCurta(_Item item) =>
      (_esquerda <= _direita ? esquerda : direita).add(item);

  /// Põe as colunas entre y0 e y1 (de cima para baixo), esticando os
  /// cômodos para preencher.
  void colocar(
      _Pavimento p, String pre, String? unidade, double y0, double y1) {
    final total = y1 - y0;
    void coluna(List<_Item> itens, double x0, double fundo) {
      final soma = itens.fold(0.0, (s, i) => s + _prof(i));
      final escala = soma <= 0 ? 1.0 : (total - fundo) / soma;
      var y = y1;
      for (final item in itens) {
        final h = _prof(item) * escala;
        p.cels.add(_Cel(
            '$pre${item.id}', item.nome, item.tipo, x0, y - h, x0 + largura, y,
            piso: item.piso, unidade: unidade));
        y -= h;
      }
    }

    coluna(esquerda, 0, 0);
    coluna(direita, largura + ModelosPlanta._corredor, escadaNoFundo);
    if (escadaNoFundo > 0) {
      final x0 = largura + ModelosPlanta._corredor;
      p.cels.add(_Cel('${pre}escada', 'Escada', 'escada', x0, y0, x0 + largura,
          y0 + escadaNoFundo,
          piso: PisoComodo.cimento, unidade: unidade));
    }
  }
}

// ============================================================ paredes

/// Um pedaço de parede entre cômodos (ou de muro), já classificado.
class _Peca {
  _Peca(this.horizontal, this.linha, this.a, this.b, this.tipo, this.espessura,
      this.cels);

  final bool horizontal;
  final double linha;
  final double a, b;
  final TipoParede tipo;
  final double espessura;

  /// Os cômodos dos dois lados (um só: parede de fora).
  final Set<String> cels;
}

class _Parede {
  _Parede(
      this.horizontal, this.linha, this.a, this.b, this.tipo, this.espessura);

  final bool horizontal;
  final double linha;
  final double a;
  double b;
  final TipoParede tipo;
  final double espessura;
  final pecas = <_Peca>[];
  final vaos = <AberturaPlanta>[];
}

/// Das células para as paredes, os vãos e os cômodos da [PlantaObra].
class _Construtor {
  _Construtor(this.pav, this.largura, this.profundidade, this.prefixo,
      {this.terreo = false}) {
    _paredes = _levantar();
    _abrir();
  }

  final _Pavimento pav;
  final double largura;
  final double profundidade;
  final String prefixo;
  final bool terreo;
  late final List<_Parede> _paredes;
  late final Map<String, _Cel> _porId = {for (final c in pav.cels) c.id: c};
  int _contaVaos = 0;

  static const double _eps = 0.005;
  static const double _externa = 0.15;
  static const double _interna = 0.12;

  List<_Parede> _levantar() {
    // As bordas de cada célula, por linha.
    final linhas = <(bool, int), List<(double, double, _Cel)>>{};
    void borda(bool h, double linha, double a, double b, _Cel c) => linhas
        .putIfAbsent((h, (linha * 1000).round()), () => []).add((a, b, c));
    for (final c in pav.cels) {
      borda(true, c.y0, c.x0, c.x1, c);
      borda(true, c.y1, c.x0, c.x1, c);
      borda(false, c.x0, c.y0, c.y1, c);
      borda(false, c.x1, c.y0, c.y1, c);
    }
    final pecas = <_Peca>[];
    for (final MapEntry(key: (h, chave), value: bordas) in linhas.entries) {
      final linha = chave / 1000;
      final cortes = <double>{
        for (final (a, b, _) in bordas) ...[a, b],
      }.toList()
        ..sort();
      final limite = h ? profundidade : largura;
      final noLimite = linha.abs() < _eps || (linha - limite).abs() < _eps;
      for (var i = 0; i + 1 < cortes.length; i++) {
        final a = cortes[i], b = cortes[i + 1];
        if (b - a < 0.01) continue;
        final dono = [
          for (final (x, y, c) in bordas)
            if (x <= a + _eps && y >= b - _eps) c,
        ];
        final cobertas = dono.where((c) => c.coberto).toList();
        if (cobertas.isNotEmpty) {
          final divisa = cobertas.length == 2 &&
              cobertas[0].unidade != cobertas[1].unidade;
          pecas.add(_Peca(
              h,
              linha,
              a,
              b,
              TipoParede.alvenaria,
              cobertas.length == 1 || divisa ? _externa : _interna,
              {for (final c in cobertas) c.id}));
          continue;
        }
        // Só descobertos: muro no limite do terreno e entre quintais de
        // unidades diferentes.
        final muro = (terreo && noLimite && dono.length == 1) ||
            (dono.length == 2 && dono[0].unidade != dono[1].unidade);
        if (muro) {
          pecas.add(_Peca(h, linha, a, b, TipoParede.muro, _interna,
              {for (final c in dono) c.id}));
        }
      }
    }
    // Junta os pedaços seguidos da mesma linha numa parede só.
    pecas.sort((p, q) {
      final c = (p.horizontal ? 0 : 1).compareTo(q.horizontal ? 0 : 1);
      if (c != 0) return c;
      final l = p.linha.compareTo(q.linha);
      if (l != 0) return l;
      return p.a.compareTo(q.a);
    });
    final paredes = <_Parede>[];
    for (final p in pecas) {
      final ultima = paredes.lastOrNull;
      if (ultima != null &&
          ultima.horizontal == p.horizontal &&
          (ultima.linha - p.linha).abs() < _eps &&
          ultima.tipo == p.tipo &&
          ultima.espessura == p.espessura &&
          (ultima.b - p.a).abs() < _eps) {
        ultima.b = p.b;
        ultima.pecas.add(p);
        continue;
      }
      paredes.add(_Parede(p.horizontal, p.linha, p.a, p.b, p.tipo, p.espessura)
        ..pecas.add(p));
    }
    return paredes;
  }

  /// Trechos seguidos de uma parede onde valem as [cels] (o mesmo par de
  /// cômodos).
  List<(_Parede, double, double)> _trechos(
      bool Function(_Parede w, _Peca p) vale) {
    final saida = <(_Parede, double, double)>[];
    for (final w in _paredes) {
      double? a, b;
      for (final p in w.pecas) {
        if (vale(w, p)) {
          if (a != null && (p.a - b!).abs() < _eps) {
            b = p.b;
          } else {
            if (a != null) saida.add((w, a, b!));
            a = p.a;
            b = p.b;
          }
        } else if (a != null) {
          saida.add((w, a, b!));
          a = null;
        }
      }
      if (a != null) saida.add((w, a, b!));
    }
    return saida;
  }

  /// Põe um vão de [largura] no trecho [a, b] da parede, no maior espaço
  /// livre (sem encostar em outro vão). Devolve se coube.
  bool _por(_Parede w, double a, double b, double largura, TipoAbertura tipo,
      {double? peitoril, double? altura, double minimo = 0.6}) {
    const folga = 0.15;
    // Espaços livres no trecho.
    var livres = [(a + folga, b - folga)];
    for (final v in w.vaos) {
      final v0 = v.inicio + w.a - folga,
          v1 = v.inicio + v.largura + w.a + folga;
      livres = [
        for (final (x, y) in livres) ...[
          if (v0 > x) (x, math.min(y, v0)),
          if (v1 < y) (math.max(x, v1), y),
        ],
      ].where((t) => t.$2 - t.$1 > 0.01).toList();
    }
    if (livres.isEmpty) return false;
    livres.sort((p, q) => (q.$2 - q.$1).compareTo(p.$2 - p.$1));
    final (x, y) = livres.first;
    final cabe = math.min(largura, y - x);
    if (cabe < minimo) return false;
    final inicio = (x + y) / 2 - cabe / 2;
    w.vaos.add(AberturaPlanta(
      id: '$prefixo-v${++_contaVaos}',
      tipo: tipo,
      inicio: _r(inicio - w.a),
      largura: _r(cabe),
      peitoril: peitoril,
      altura: altura,
    ));
    return true;
  }

  void _abrir() {
    // Portas e passagens pedidas.
    for (final l in pav.ligs) {
      final a = _porId[l.a];
      if (a == null) continue;
      final List<(_Parede, double, double)> trechos;
      if (l.b != null) {
        final par = {l.a, l.b!};
        trechos =
            _trechos((w, p) => p.cels.length == 2 && p.cels.containsAll(par));
      } else {
        trechos = _trechos((w, p) =>
            p.cels.length == 1 &&
            p.cels.first == l.a &&
            p.tipo == TipoParede.alvenaria &&
            switch (l.lado!) {
              _Lado.frente => w.horizontal && (w.linha - a.y1).abs() < _eps,
              _Lado.fundos => w.horizontal && (w.linha - a.y0).abs() < _eps,
              _Lado.esquerda => !w.horizontal && (w.linha - a.x0).abs() < _eps,
              _Lado.direita => !w.horizontal && (w.linha - a.x1).abs() < _eps,
            });
      }
      if (trechos.isEmpty) continue;
      trechos.sort((p, q) => (q.$3 - q.$2).compareTo(p.$3 - p.$2));
      final (w, x, y) = trechos.first;
      _por(w, x, y, l.largura, l.tipo,
          altura: l.tipo == TipoAbertura.passagem ? null : 2.1);
    }
    // Janelas: em cada cômodo coberto, na parede de fora mais comprida.
    for (final c in pav.cels.where((c) => c.coberto)) {
      final (largura, peitoril, altura) = switch (c.tipo) {
        'quarto' || 'sala' => (1.5, 1.0, 1.2),
        'cozinha' || 'lavanderia' => (1.2, 1.1, 1.0),
        'banheiro' => (0.6, 1.5, 0.5),
        'hall' => (1.2, 1.0, 1.2),
        _ => (0.0, 0.0, 0.0),
      };
      if (largura == 0) continue;
      final trechos = _trechos((w, p) =>
          p.cels.length == 1 &&
          p.cels.first == c.id &&
          p.tipo == TipoParede.alvenaria);
      trechos.sort((p, q) => (q.$3 - q.$2).compareTo(p.$3 - p.$2));
      for (final (w, x, y) in trechos) {
        if (_por(w, x, y, largura, TipoAbertura.janela,
            peitoril: peitoril, altura: altura, minimo: largura * 0.6)) {
          break;
        }
      }
    }
    // Portão: no muro da frente de cada garagem (ou da frente do prédio).
    if (terreo) {
      for (final c in pav.cels.where(
          (c) => !c.coberto && (c.tipo == 'garagem' || c.id == 'frente'))) {
        final trechos = _trechos((w, p) =>
            p.tipo == TipoParede.muro &&
            p.cels.contains(c.id) &&
            w.horizontal &&
            (w.linha - profundidade).abs() < _eps);
        if (trechos.isEmpty) continue;
        trechos.sort((p, q) => (q.$3 - q.$2).compareTo(p.$3 - p.$2));
        final (w, x, y) = trechos.first;
        _por(w, x, y, c.tipo == 'garagem' ? 2.8 : 3.0, TipoAbertura.portao,
            altura: 2.0, minimo: 1.0);
      }
    }
  }

  List<ParedePlanta> get paredes => [
        for (final (i, w) in _paredes.indexed)
          ParedePlanta(
            id: '$prefixo-p${i + 1}',
            de: w.horizontal ? (_r(w.a), _r(w.linha)) : (_r(w.linha), _r(w.a)),
            ate: w.horizontal ? (_r(w.b), _r(w.linha)) : (_r(w.linha), _r(w.b)),
            espessura: w.espessura,
            tipo: w.tipo,
            aberturas: [...w.vaos]
              ..sort((p, q) => p.inicio.compareTo(q.inicio)),
          ),
      ];

  List<ComodoPlanta> get comodos => [
        for (final c in pav.cels)
          ComodoPlanta(
            id: '$prefixo-${c.id}',
            nome: c.nome,
            tipo: c.tipo,
            coberto: c.coberto,
            piso: c.piso,
            unidade: c.unidade,
            retangulos: [
              () {
                // Meia parede interna: os cômodos vizinhos se encostam por
                // dentro da parede (a laje não fica com fresta).
                const m = 0.06;
                return RetanguloPlanta(_r(c.x0 + m), _r(c.y0 + m),
                    _r(c.x1 - c.x0 - 2 * m), _r(c.y1 - c.y0 - 2 * m));
              }(),
            ],
          ),
      ];
}
