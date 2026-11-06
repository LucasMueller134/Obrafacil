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
    // Cada quarto pede uns 10 m² e o resto da casa uns 24; o sobrado, com
    // garagem, hall, escada e suíte, começa nuns 80.
    final precisa = sobrado ? 80.0 + quartos * 15 : quartos * 10.0 + 24;
    if (area < precisa) {
      return 'Pouca área para $quartos quartos: aumente os m² ou tire um '
          'quarto.';
    }
    if (tipo == TipoModelo.geminado && (unidades < 2 || unidades > 4)) {
      return 'O geminado tem de 2 a 4 casas.';
    }
    // No geminado sobrado os quartos ficam lado a lado nos fundos.
    if (tipo == TipoModelo.geminado &&
        sobrado &&
        quartos > ModelosPlanta.maxQuartosGeminado(area)) {
      return 'Com ${area.round()} m², cada sobrado do geminado tem até '
          '${ModelosPlanta.maxQuartosGeminado(area)} quartos: aumente os m² '
          'ou tire um quarto.';
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
  //
  // O estilo de referência (sobrado geminado moderno): garagem coberta na
  // frente, embaixo do andar de cima; hall de entrada com ripado ao lado,
  // de onde sai a escada; sala, jantar e cozinha integrados; lavabo e
  // lavanderia; área gourmet aberta para o quintal nos fundos. Em cima, a
  // suíte com closet e sacada de vidro na frente, os quartos, o banheiro e
  // a circulação. A térrea segue o mesmo jeito, num pavimento só.

  static const double _lateral = 1.0;
  static const double _fundos = 3.0;

  /// Profundidade da garagem coberta (um carro de 4,6 m e folga).
  static const double _garagem = 5.0;

  /// Faixa do hall e da escada, ao lado da garagem.
  static const double _faixa = 2.5;

  /// Fundo da área gourmet.
  static const double _gourmet = 3.0;

  static PlantaObra _casas(PedidoModelo p, int n) {
    final geminado = p.tipo == TipoModelo.geminado;
    final unidades = [
      for (var i = 0; i < n; i++)
        geminado && p.sobrado
            ? _sobradoGeminado('u${i + 1}-', p.area, p.quartos,
                n == 1 ? null : 'Casa ${i + 1}')
            : p.sobrado
                ? _sobrado('u${i + 1}-', p.area, p.quartos,
                    n == 1 ? null : 'Casa ${i + 1}')
                : _terrea('u${i + 1}-', p.area, p.quartos,
                    n == 1 ? null : 'Casa ${i + 1}',
                    portaDaFrente: true, fachadaGeminado: geminado),
    ];
    final modelo = unidades.first;
    final wu = modelo.largura, du = modelo.profundidade;
    // O sobrado geminado encosta nas divisas (como no desenho); a térrea
    // deixa o corredor dos lados (as janelas dos quartos dão para ele).
    final lateral = geminado && p.sobrado ? 0.0 : _lateral;
    // Com garagem coberta, na frente só o acesso e um jardim; com a
    // fechada, o recuo aberto para a rua; sem garagem, a descoberta.
    final frente = modelo.garagemFechada
        ? _frenteGeminado
        : modelo.garagemCoberta
            ? 2.0
            : 5.5;
    final largura = lateral * 2 + n * wu;
    final profundidade = _fundos + du + frente;
    final alturas = geminado ? alturasGeminado : _alturasCasa;

    final terreo = _Pavimento();
    final superior = _Pavimento();
    final fachadaTerreo = <ElementoFachada>[];
    final fachadaSuperior = <ElementoFachada>[];
    for (var i = 0; i < n; i++) {
      final u = unidades[i];
      final ox = lateral + i * wu;
      terreo.juntar(u.terreo, ox, _fundos);
      if (p.sobrado) superior.juntar(u.superior!, ox, _fundos);
      fachadaTerreo.addAll([for (final e in u.fachadaTerreo) _mover(e, ox)]);
      fachadaSuperior
          .addAll([for (final e in u.fachadaSuperior) _mover(e, ox)]);
      final nomeUnidade = n == 1 ? null : 'Casa ${i + 1}';
      final x0 = i == 0 ? 0.0 : ox, x1 = i == n - 1 ? largura : ox + wu;
      final prefixo = 'u${i + 1}-';
      final yf = _fundos + du;
      terreo.cels.addAll([
        if (u.garagemFechada) ...[
          // Recuo aberto para a rua: o acesso dos carros na frente do
          // portão e a entrada na frente do hall (muros só dos lados).
          _Cel('${prefixo}acesso', 'Acesso da garagem', 'garagem', x0, yf,
              ox + u.garagemAte, profundidade,
              coberto: false,
              piso: PisoComodo.garagem,
              unidade: nomeUnidade,
              abertoRua: true),
          _Cel(
              '${prefixo}entrada',
              'Entrada',
              'jardim',
              ox + u.garagemAte,
              yf,
              u.frenteAte == null || u.frenteAte! >= wu - 0.01
                  ? x1
                  : ox + u.frenteAte!,
              profundidade,
              coberto: false,
              piso: PisoComodo.porcelanato,
              unidade: nomeUnidade,
              abertoRua: true),
          if (u.frenteAte != null && u.frenteAte! < wu - 0.01)
            _Cel('${prefixo}jardim', 'Jardim', 'jardim', ox + u.frenteAte!,
                _fundos + u.corpoAte!, x1, profundidade,
                coberto: false,
                piso: PisoComodo.grama,
                unidade: nomeUnidade,
                abertoRua: true),
        ] else if (u.garagemCoberta) ...[
          // O acesso dos carros fica aberto para a rua (sem muro); o
          // jardim, na frente do hall, tem o portão de pedestre.
          _Cel('${prefixo}acesso', 'Acesso da garagem', 'garagem', x0, yf,
              ox + u.garagemAte, profundidade,
              coberto: false,
              piso: PisoComodo.garagem,
              unidade: nomeUnidade,
              aberto: true),
          _Cel(
              '${prefixo}jardim',
              'Jardim',
              'jardim',
              ox + u.garagemAte,
              yf,
              u.frenteAte == null || u.frenteAte! >= wu - 0.01
                  ? x1
                  : ox + u.frenteAte!,
              profundidade,
              coberto: false,
              piso: PisoComodo.grama,
              unidade: nomeUnidade,
              portao: 1.0),
          // O jardim do lado da garagem e do hall (térrea larga).
          if (u.frenteAte != null && u.frenteAte! < wu - 0.01)
            _Cel('${prefixo}jardim-2', 'Jardim', 'jardim', ox + u.frenteAte!,
                _fundos + u.corpoAte!, x1, profundidade,
                coberto: false, piso: PisoComodo.grama, unidade: nomeUnidade),
        ] else
          // Vaga descoberta; no geminado, aberta para a rua (a fachada
          // aparece inteira).
          _Cel('${prefixo}garagem', 'Garagem', 'garagem', x0, yf, x1,
              profundidade,
              coberto: false,
              piso: PisoComodo.garagem,
              unidade: nomeUnidade,
              portao: geminado ? null : 2.8,
              abertoRua: geminado),
        _Cel('${prefixo}quintal', 'Quintal', 'quintal', x0, 0, x1, _fundos,
            coberto: false, piso: PisoComodo.grama, unidade: nomeUnidade),
        if (i == 0 && lateral > 0)
          _Cel('${prefixo}lateral-e', 'Corredor lateral', 'circulacao', 0,
              _fundos, lateral, yf,
              coberto: false, piso: PisoComodo.cimento, unidade: nomeUnidade),
        if (i == n - 1 && lateral > 0)
          _Cel('${prefixo}lateral-d', 'Corredor lateral', 'circulacao',
              largura - lateral, _fundos, largura, yf,
              coberto: false, piso: PisoComodo.cimento, unidade: nomeUnidade),
      ]);
      // A aleta na divisa com a casa do lado, do chão ao topo da
      // platibanda.
      if (geminado && i < n - 1) {
        final pavimentos = p.sobrado ? 2 : 1;
        final xd = ox + wu;
        fachadaTerreo.add(ElementoFachada(
          tipo: TipoElementoFachada.aleta,
          de: _r(xd - 0.1),
          ate: _r(xd + 0.1),
          y: _r(_frenteDe(u) + 0.075),
          base: -0.2,
          topo:
              _r(pavimentos * (alturas.peDireito + 0.12) + alturas.platibanda),
          saliencia: 0.45,
        ));
      }
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
      alturas: alturas,
      fachada: [for (final e in fachadaTerreo) _naPlanta(e, _fundos)],
      andares: [
        if (p.sobrado)
          (
            'Superior',
            superior,
            1,
            [for (final e in fachadaSuperior) _naPlanta(e, _fundos)]
          ),
      ],
    );
  }

  static const AlturasPlanta _alturasCasa =
      AlturasPlanta(peDireito: 2.6, porta: 2.1, muro: 2.0);

  /// A frente da casa (onde está a parede da rua), em y da casa.
  static double _frenteDe(_Casa u) => u.profundidade;

  /// Elemento da casa levado para o lugar dela no terreno (só em x; o y
  /// entra em [_naPlanta]).
  static ElementoFachada _mover(ElementoFachada e, double dx) =>
      _elemento(e, dx: dx, dy: 0);

  static ElementoFachada _naPlanta(ElementoFachada e, double dy) =>
      _elemento(e, dx: 0, dy: dy);

  static ElementoFachada _elemento(ElementoFachada e,
          {required double dx, required double dy}) =>
      ElementoFachada(
        tipo: e.tipo,
        de: _r(e.de + dx),
        ate: _r(e.ate + dx),
        y: _r(e.y + dy),
        sentido: e.sentido,
        base: e.base,
        topo: e.topo,
        saliencia: e.saliencia,
        recuo: e.recuo,
        borda: e.borda,
        peitoril: e.peitoril,
        passo: e.passo,
      );

  static const double _corredor = 1.1;

  /// Térrea: na frente a garagem coberta e o hall de entrada; depois a
  /// cozinha (ao lado da garagem) e a sala integradas; atrás os quartos e
  /// os banheiros em duas colunas com o corredor no meio; nos fundos a
  /// área gourmet. Casa pequena fica sem garagem coberta e sem gourmet.
  ///
  /// [apartamento]: sem garagem, hall e gourmet; a sala ganha uma sacada
  /// de vidro na frente (o apartamento do prédio).
  ///
  /// [fachadaGeminado]: a frente do geminado (o desenho): garagem fechada
  /// com porta de lâminas, porta pivotante no hall e uma moldura de
  /// concreto em volta das duas, com ripado sobre as portas.
  static _Casa _terrea(String pre, double area, int q, String? unidade,
      {required bool portaDaFrente,
      bool apartamento = false,
      bool fachadaGeminado = false}) {
    final nb = q >= 3 ? 2 : 1;
    final largura = (math.sqrt(area) * 0.95).clamp(6.0, 14.0);
    final cw = (largura - _corredor) / 2;
    // O que entra além do corpo da casa, se couber. A garagem vai até 2
    // carros (5,4 m); do lado dela, o hall e um jardim.
    var garagem = !apartamento && area >= 60;
    var gourmet = !apartamento && area >= 90;
    final hw = math.min(2.2, largura - 2.8);
    final gw = math.min(largura - hw, 5.4);
    double extras() =>
        (garagem ? (gw + hw) * _garagem : 0) +
        (gourmet ? largura * _gourmet : 0);
    // A garagem e o gourmet só entram se a casa continuar folgada.
    if (area - extras() < q * 18.0 + 40) gourmet = false;
    if (area - extras() < q * 13.0 + 32) garagem = false;
    final corpo = area - extras();
    final temLavanderia = corpo >= 45;
    var aq = (corpo * 0.14).clamp(7.5, 14.0);
    late _Colunas col;
    late double social;
    for (var tentativa = 0; tentativa < 16; tentativa++) {
      col = _Colunas(cw);
      // A lavanderia encosta na cozinha (coluna da esquerda, em cima).
      if (temLavanderia) {
        col.esquerda.add(_Item(
            'lavanderia', 'Lavanderia', 'lavanderia', 3.0, 1.5,
            piso: PisoComodo.ceramica));
      }
      for (var b = 0; b < nb; b++) {
        col.direita.add(_Item('banheiro-${b + 1}',
            nb == 1 ? 'Banheiro' : 'Banheiro ${b + 1}', 'banheiro', 3.6, 1.7,
            piso: PisoComodo.ceramica));
      }
      for (var k = 0; k < q; k++) {
        col.naMaisCurta(_Item(
            'quarto-${k + 1}',
            k == 0 && q >= 2
                ? 'Suíte'
                : (q == 1 ? 'Quarto' : 'Quarto ${k + 1}'),
            'quarto',
            k == 0 && q >= 2 ? aq * 1.25 : aq,
            2.6));
      }
      social = (corpo - largura * col.profundidade) / largura;
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
    final y0 = gourmet ? _gourmet : 0.0;
    final ySocial = y0 + db;
    final d0 = ySocial + social;
    // No apartamento, a sacada sai 1,3 m na frente da sala.
    final d = d0 + (garagem ? _garagem : 0) + (apartamento ? 1.3 : 0);
    final casa = _Casa(largura, d);
    final t = casa.terreo;
    // Fundos: as duas colunas e o corredor.
    col.colocar(t, pre, unidade, y0, ySocial);
    final corredor = _Cel('${pre}corredor', 'Corredor', 'circulacao', cw, y0,
        cw + _corredor, ySocial,
        unidade: unidade);
    t.cels.add(corredor);
    // A cozinha à esquerda (ao lado da garagem e da lavanderia) e a sala à
    // direita, embaixo do hall; o corredor abre na sala.
    final wk = math.min(math.max(largura * 0.36, 2.6), cw - 0.1);
    final cozinha = _Cel(
        '${pre}cozinha',
        temLavanderia ? 'Cozinha' : 'Cozinha e serviço',
        'cozinha',
        0,
        ySocial,
        wk,
        d0,
        piso: PisoComodo.ceramica,
        unidade: unidade);
    final sacada = apartamento;
    final sala = _Cel('${pre}sala', 'Sala de estar e jantar', 'sala', wk,
        ySocial, largura, d0,
        unidade: unidade);
    t.cels.addAll([sala, cozinha]);
    // Cozinha integrada: a passagem é larga.
    t.ligar(sala.id, cozinha.id, TipoAbertura.passagem,
        math.max(1.2, social - 0.6));
    t.ligar(sala.id, corredor.id, TipoAbertura.passagem, 0.9);
    if (temLavanderia) {
      t.ligar(cozinha.id, '${pre}lavanderia', TipoAbertura.porta, 0.8);
    }
    for (final item in [...col.esquerda, ...col.direita]) {
      t.ligar('$pre${item.id}', corredor.id, TipoAbertura.porta,
          item.tipo == 'banheiro' ? 0.7 : 0.8);
    }
    if (sacada) {
      final c = _Cel(
          '${pre}sacada', 'Sacada', 'varanda', wk, d0, largura, d0 + 1.3,
          piso: PisoComodo.ceramica,
          unidade: unidade,
          guardaCorpo: true,
          fachada: 'moldura');
      t.cels.add(c);
      t.ligar(sala.id, c.id, TipoAbertura.portaCorrer, 2.0);
    }
    if (garagem && fachadaGeminado) {
      // Frente do geminado: a garagem fechada e o hall, com as duas portas
      // altas dentro de uma moldura.
      final g = _Cel('${pre}garagem', 'Garagem', 'garagem', 0, d0, gw, d,
          piso: PisoComodo.garagem, unidade: unidade);
      final hall = _Cel(
          '${pre}hall', 'Hall de entrada', 'hall', gw, d0, gw + hw, d,
          piso: PisoComodo.porcelanato, unidade: unidade);
      t.cels.addAll([g, hall]);
      t.ligar(hall.id, sala.id, TipoAbertura.passagem, 1.0);
      t.ligar(g.id, hall.id, TipoAbertura.porta, 0.8);
      t.ligar(g.id, cozinha.id, TipoAbertura.porta, 0.8);
      final portaoW = (gw - 0.6).clamp(2.4, 5.0).toDouble();
      t.porFora(g.id, _Lado.frente, portaoW,
          tipo: TipoAbertura.portaGaragem,
          alvo: (0.4 + portaoW / 2, d),
          altura: _vaoAlto);
      final pivo = math.min(1.4, hw - 0.6);
      t.porFora(hall.id, _Lado.frente, pivo,
          tipo: TipoAbertura.portaPivotante,
          alvo: (gw + 0.2 + pivo / 2, d),
          altura: _vaoAlto);
      casa
        ..garagemFechada = true
        ..garagemAte = gw
        ..frenteAte = gw + hw
        ..corpoAte = d0;
      final a = alturasGeminado;
      final topo = a.peDireito + 0.12 + a.platibanda - 0.3;
      casa.fachadaTerreo.addAll([
        ElementoFachada(
          tipo: TipoElementoFachada.moldura,
          de: 0.2,
          ate: gw + hw - 0.2,
          y: d + 0.075,
          base: -0.2,
          topo: topo,
          saliencia: 0.3,
          borda: 0.4,
        ),
        ElementoFachada(
          tipo: TipoElementoFachada.ripadoHorizontal,
          de: 0.6,
          ate: gw + hw - 0.6,
          y: d + 0.075,
          base: _vaoAlto,
          topo: topo - 0.4,
          saliencia: 0.05,
          passo: 0.075,
        ),
      ]);
    } else if (garagem) {
      // Frente: a garagem coberta (sem paredes, só pilares) e o hall.
      final g = _Cel('${pre}garagem', 'Garagem', 'garagem', 0, d0, gw, d,
          piso: PisoComodo.garagem,
          unidade: unidade,
          aberto: true,
          fachada: 'moldura');
      final hall = _Cel(
          '${pre}hall', 'Hall de entrada', 'hall', gw, d0, gw + hw, d,
          piso: PisoComodo.porcelanato, unidade: unidade, fachada: 'ripado');
      t.cels.addAll([g, hall]);
      t.ligar(hall.id, sala.id, TipoAbertura.passagem, 1.0);
      t.ligar(g.id, hall.id, TipoAbertura.porta, 0.8);
      t.ligar(g.id, cozinha.id, TipoAbertura.porta, 0.8);
      if (portaDaFrente) t.porFora(hall.id, _Lado.frente, 0.9);
      casa
        ..garagemCoberta = true
        ..garagemAte = gw
        ..frenteAte = gw + hw
        ..corpoAte = d0;
    } else if (portaDaFrente && fachadaGeminado) {
      // Geminado pequeno, sem garagem: a pivotante na sala e a moldura em
      // volta da frente toda, com o ripado sobre a porta e as janelas.
      final pivo = math.min(1.2, largura - wk - 1.2);
      t.porFora(sala.id, _Lado.frente, pivo,
          tipo: TipoAbertura.portaPivotante,
          alvo: (largura - 0.4 - pivo / 2, d),
          altura: _vaoAlto);
      final a = alturasGeminado;
      final topo = a.peDireito + 0.12 + a.platibanda - 0.3;
      casa.fachadaTerreo.addAll([
        ElementoFachada(
          tipo: TipoElementoFachada.moldura,
          de: 0.2,
          ate: largura - 0.2,
          y: d + 0.075,
          base: -0.2,
          topo: topo,
          saliencia: 0.3,
          borda: 0.4,
        ),
        ElementoFachada(
          tipo: TipoElementoFachada.ripadoHorizontal,
          de: 0.6,
          ate: largura - 0.6,
          y: d + 0.075,
          base: _vaoAlto,
          topo: topo - 0.4,
          saliencia: 0.05,
          passo: 0.075,
        ),
      ]);
    } else if (portaDaFrente) {
      t.porFora(sala.id, _Lado.frente, 0.9);
    }
    if (gourmet) {
      final g = _Cel(
          '${pre}gourmet', 'Área gourmet', 'gourmet', 0, 0, largura, _gourmet,
          piso: PisoComodo.ceramica, unidade: unidade, aberto: true);
      t.cels.add(g);
      t.ligar(g.id, corredor.id, TipoAbertura.passagem, 0.9);
    }
    casa.entrada = corredor.id;
    return casa;
  }

  /// Sobrado em duas faixas: a da esquerda (garagem, sala e jantar,
  /// cozinha; em cima a sacada, a suíte, os quartos e o banheiro) e a da
  /// direita (hall de entrada, escada, lavabo, lavanderia; em cima o
  /// banheiro e o closet da suíte, a escada e a circulação). A escada fica
  /// no mesmo lugar nos dois pavimentos. A área gourmet, nos fundos, é só
  /// do térreo.
  static _Casa _sobrado(String pre, double area, int q, String? unidade) {
    const r = _faixa;
    // Faixa da direita, de frente para trás (iguais nos dois pavimentos
    // até a escada).
    const hall = 3.4, escada = 2.7, lavabo = 1.6;
    const banhoSuite = 2.0, closet = 1.4, sacada = 1.3;
    // Mínimos da faixa da esquerda.
    const sala0 = 2.8, cozinha0 = 2.4, suite0 = 3.2, quarto0 = 2.6;
    final temGourmet = area >= 150;
    final dMin = [
      _garagem + sala0 + cozinha0,
      hall + escada + lavabo + 1.6,
      sacada + suite0 + (q - 1) * quarto0 + 1.7,
      banhoSuite + closet + escada + 1.0,
    ].reduce(math.max);
    // Largura e fundo do corpo para a área pedida (os dois pavimentos e o
    // gourmet): lote estreito e fundo, como o de referência.
    var largura = 6.0, d = dMin;
    for (var i = 0; i < 6; i++) {
      final corpo = (area - (temGourmet ? largura * _gourmet : 0)) / 2;
      d = math.max(dMin, math.sqrt(corpo) * 1.35);
      largura = math.max(5.5, corpo / d);
      if (largura > 12) {
        largura = 12;
        d = math.max(dMin, corpo / largura);
      }
    }
    final l = largura - r;
    final db = math.max(1.7, 3.6 / l);
    // A sobra vai para a sala (60%) e a cozinha embaixo; em cima, para a
    // suíte e os quartos.
    final sobraBaixo = d - (_garagem + sala0 + cozinha0);
    final dk = cozinha0 + sobraBaixo * 0.4;
    final sobraCima = d - (sacada + suite0 + (q - 1) * quarto0 + db);
    final dSuite = suite0 + (q == 1 ? sobraCima : sobraCima * 0.4);
    final dq = q == 1 ? 0.0 : quarto0 + sobraCima * 0.6 / (q - 1);
    final m = (dk: dk, dSuite: dSuite, dq: dq, db: db);
    final y0 = temGourmet ? _gourmet : 0.0;
    final dTotal = y0 + d;
    final casa = _Casa(largura, dTotal)
      ..superior = _Pavimento()
      ..garagemCoberta = true
      ..garagemAte = l;

    /// Empilha [itens] (nome, tipo, profundidade) de cima (y = dTotal)
    /// para baixo na faixa x0..x1; o último estica até o fundo y0.
    List<_Cel> empilhar(String prefixo, double x0, double x1,
        List<(String, String, String, double, Map<String, Object?>)> itens) {
      final saida = <_Cel>[];
      var y = dTotal;
      for (var i = 0; i < itens.length; i++) {
        final (id, nome, tipo, h, op) = itens[i];
        final fundo = i == itens.length - 1 ? y0 : y - h;
        saida.add(_Cel('$prefixo$id', nome, tipo, x0, fundo, x1, y,
            piso: op['piso'] as PisoComodo? ?? PisoComodo.porcelanato,
            unidade: unidade,
            aberto: op['aberto'] as bool? ?? false,
            guardaCorpo: op['guarda'] as bool? ?? false,
            fachada: op['fachada'] as String?));
        y = fundo;
      }
      return saida;
    }

    // Térreo. A sala fica com a sobra da faixa da esquerda.
    final t = casa.terreo;
    final dsReal = d - _garagem - m.dk;
    t.cels
      ..addAll(empilhar(pre, 0, l, [
        (
          'garagem',
          'Garagem',
          'garagem',
          _garagem,
          {'piso': PisoComodo.garagem, 'aberto': true, 'fachada': 'moldura'}
        ),
        ('sala', 'Sala de estar e jantar', 'sala', dsReal, {}),
        ('cozinha', 'Cozinha', 'cozinha', m.dk, {'piso': PisoComodo.ceramica}),
      ]))
      ..addAll(empilhar(pre, l, largura, [
        ('hall', 'Hall de entrada', 'hall', hall, {'fachada': 'ripado'}),
        ('escada', 'Escada', 'escada', escada, {'piso': PisoComodo.cimento}),
        ('lavabo', 'Lavabo', 'banheiro', lavabo, {'piso': PisoComodo.ceramica}),
        (
          'lavanderia',
          'Lavanderia',
          'lavanderia',
          0,
          {'piso': PisoComodo.ceramica}
        ),
      ]));
    t.porFora('${pre}hall', _Lado.frente, 0.9);
    t.ligar('${pre}hall', '${pre}garagem', TipoAbertura.porta, 0.8);
    t.ligar('${pre}hall', '${pre}escada', TipoAbertura.passagem, 1.2);
    t.ligar('${pre}escada', '${pre}sala', TipoAbertura.passagem, 0.9);
    t.ligar('${pre}sala', '${pre}cozinha', TipoAbertura.passagem,
        math.max(1.2, l - 0.6));
    t.ligarAoMelhor('${pre}lavabo', ['${pre}sala', '${pre}cozinha'],
        TipoAbertura.porta, 0.7);
    t.ligarAoMelhor('${pre}lavanderia', ['${pre}cozinha', '${pre}sala'],
        TipoAbertura.porta, 0.8);
    if (temGourmet) {
      t.cels.add(_Cel(
          '${pre}gourmet', 'Área gourmet', 'gourmet', 0, 0, largura, _gourmet,
          piso: PisoComodo.ceramica, unidade: unidade, aberto: true));
      t.ligar('${pre}gourmet', '${pre}cozinha', TipoAbertura.portaCorrer,
          math.min(2.4, l - 0.6));
    }

    // Superior: os quartos esticam para preencher a faixa da esquerda.
    final s = casa.superior!;
    final ps = '${pre}s-';
    s.cels
      ..addAll(empilhar(ps, 0, l, [
        (
          'sacada',
          'Sacada',
          'varanda',
          sacada,
          {
            'piso': PisoComodo.ceramica,
            'guarda': true,
            'fachada': 'moldura',
          }
        ),
        ('suite', 'Suíte', 'quarto', m.dSuite, {}),
        (
          'banheiro',
          'Banheiro',
          'banheiro',
          m.db,
          {'piso': PisoComodo.ceramica}
        ),
        for (var k = 2; k <= q; k++)
          ('quarto-$k', 'Quarto $k', 'quarto', m.dq, {}),
      ]))
      ..addAll(empilhar(ps, l, largura, [
        (
          'banho-suite',
          'Banheiro da suíte',
          'banheiro',
          banhoSuite,
          {'piso': PisoComodo.ceramica, 'fachada': 'ripado'}
        ),
        ('closet', 'Closet', 'closet', closet, {}),
        ('escada', 'Escada', 'escada', escada, {'piso': PisoComodo.cimento}),
        ('circulacao', 'Circulação', 'circulacao', 0, {}),
      ]));
    s.ligar('${ps}suite', '${ps}sacada', TipoAbertura.portaCorrer,
        math.min(2.4, l - 0.6));
    // Suíte → closet → banheiro.
    s.ligar('${ps}closet', '${ps}banho-suite', TipoAbertura.porta, 0.7);
    s.ligar('${ps}suite', '${ps}closet', TipoAbertura.passagem, 0.8);
    s.ligarAoMelhor('${ps}suite', ['${ps}escada', '${ps}circulacao'],
        TipoAbertura.porta, 0.8);
    s.ligar('${ps}escada', '${ps}circulacao', TipoAbertura.passagem, 1.2);
    for (var k = 2; k <= q; k++) {
      s.ligarAoMelhor('${ps}quarto-$k', ['${ps}circulacao', '${ps}escada'],
          TipoAbertura.porta, 0.8);
    }
    s.ligarAoMelhor('${ps}banheiro', ['${ps}circulacao', '${ps}escada'],
        TipoAbertura.porta, 0.7);
    casa.entrada = '${pre}hall';
    return casa;
  }

  // ------------------------------------------------------------ geminado
  //
  // O geminado segue a fachada desenhada (fachada_geminado.dxf): no
  // tamanho-padrão, cada casa tem 6 m de frente e 7 m de altura. No
  // térreo, a porta da garagem (3,40 × 2,40) e a porta pivotante de
  // madeira (1,40 × 2,40); em cima, a sacada dentro de uma moldura de
  // concreto (5,60 m de largura, faixas de 50 cm), com vidro na frente,
  // ripado em L (painel em pé de 1 m e faixa deitada sobre a porta) e a
  // porta de correr da suíte (3,20 m). Entre as casas, uma aleta de 20 cm.
  // Casa maior ou menor: a frente vai de 5 a 8 m e as peças acompanham.

  /// Pé-direito, muro e platibanda do geminado: com 2,80 m de pé-direito
  /// o topo fica nos 7,00 m do desenho, a porta de correr em 5,62 m e a
  /// moldura de 2,80 a 6,40 m.
  static const AlturasPlanta alturasGeminado =
      AlturasPlanta(peDireito: 2.8, porta: 2.1, muro: 2.0, platibanda: 0.96);

  /// Fundo da sacada dentro da moldura.
  static const double _sacadaGeminado = 1.2;

  /// Altura da porta da garagem e da pivotante (2,60 m do chão, como no
  /// desenho).
  static const double _vaoAlto = 2.4;

  /// Altura da porta de correr da sacada: até o fundo da viga.
  static double get _vaoSacada => alturasGeminado.peDireito - 0.3;

  /// Recuo da frente: o acesso da garagem e a entrada, abertos para a rua.
  static const double _frenteGeminado = 3.5;

  /// Frente de cada casa do geminado sobrado para a área pedida: 6 m (o
  /// desenho) de 130 a 180 m², de 5 a 8 m fora disso.
  static double larguraGeminado(double area) {
    final w = area <= 110
        ? 5.0
        : area <= 130
            ? 5.0 + (area - 110) / 20
            : area <= 180
                ? 6.0
                : area <= 260
                    ? 6.0 + (area - 180) / 40
                    : 8.0;
    return (w * 10).round() / 10;
  }

  /// Quartos do geminado sobrado: a suíte na frente e os outros lado a lado
  /// nos fundos, com pelo menos 2,4 m de largura cada.
  static int maxQuartosGeminado(double area) =>
      1 + math.max(1, (larguraGeminado(area) / 2.4).floor());

  /// Uma casa do geminado sobrado.
  ///
  /// Térreo: a garagem fechada na frente (faixa da esquerda) e o hall de
  /// entrada do lado; atrás da garagem a cozinha e a sala, integradas; atrás
  /// do hall a escada, o lavabo e a lavanderia; nos fundos a área gourmet.
  /// Superior: a sacada e a suíte com a largura toda; atrás, o closet e o
  /// banheiro da suíte, o banheiro social, a escada e a circulação; nos
  /// fundos os quartos, lado a lado, com janela para o quintal.
  static _Casa _sobradoGeminado(
      String pre, double area, int q, String? unidade) {
    final w = larguraGeminado(area);
    final r = w >= 7.5 ? 2.4 : 2.0; // faixa do hall e da escada
    final l = w - r; // a garagem
    final g = w <= 5.5 ? 5.0 : 5.5; // fundo da garagem
    const sac = _sacadaGeminado, e = 2.7, lavabo = 1.4, corredor = 1.0;
    const suiteMin = 3.0, quartoMin = 3.0;
    final atras = q - 1;
    final meio = q >= 2 ? 3.8 : e;
    final temCorredor = atras >= 2;
    final temGourmet = area >= 150;
    final dMin = [
      g + 2.6 + 3.0,
      sac + suiteMin + e + lavabo + 1.6,
      sac + suiteMin + meio + (temCorredor ? corredor : 0) + quartoMin,
    ].reduce(math.max);
    final d = math.max(dMin, (area - (temGourmet ? w * _gourmet : 0)) / 2 / w);
    // Em cima: a sobra vai meio a meio para a suíte e os quartos.
    final resto = d - sac - meio - (temCorredor ? corredor : 0);
    final suite = (resto * 0.5).clamp(suiteMin, 4.6).toDouble();
    final h = sac + suite; // o hall embaixo da sacada e da suíte
    // A cozinha desce até o lavabo encostar nela com folga para a porta.
    final k = math.max(((d - g) * 0.45).clamp(2.6, 4.0).toDouble(),
        math.min(h + e + 1.0 - g, d - g - 2.8));
    final y0 = temGourmet ? _gourmet : 0.0;
    final dt = y0 + d;
    final casa = _Casa(w, dt)
      ..superior = _Pavimento()
      ..garagemFechada = true
      ..garagemAte = l;

    _Cel cel(String id, String nome, String tipo, double x0, double ya,
            double x1, double yb,
            {PisoComodo piso = PisoComodo.porcelanato, bool aberto = false}) =>
        _Cel('$pre$id', nome, tipo, x0, ya, x1, yb,
            piso: piso, unidade: unidade, aberto: aberto);

    // Térreo.
    final t = casa.terreo;
    final yEscada = dt - h - e;
    t.cels.addAll([
      cel('garagem', 'Garagem', 'garagem', 0, dt - g, l, dt,
          piso: PisoComodo.garagem),
      cel('cozinha', 'Cozinha', 'cozinha', 0, dt - g - k, l, dt - g,
          piso: PisoComodo.ceramica),
      cel('sala', 'Sala de estar e jantar', 'sala', 0, y0, l, dt - g - k),
      cel('hall', 'Hall de entrada', 'hall', l, dt - h, w, dt),
      cel('escada', 'Escada', 'escada', l, yEscada, w, dt - h,
          piso: PisoComodo.cimento),
      cel('lavabo', 'Lavabo', 'banheiro', l, yEscada - lavabo, w, yEscada,
          piso: PisoComodo.ceramica),
      cel('lavanderia', 'Lavanderia', 'lavanderia', l, y0, w, yEscada - lavabo,
          piso: PisoComodo.ceramica),
    ]);
    final portaoW = (l - 0.6).clamp(2.4, 5.0).toDouble();
    t.porFora('${pre}garagem', _Lado.frente, portaoW,
        tipo: TipoAbertura.portaGaragem,
        alvo: (0.4 + portaoW / 2, dt),
        altura: _vaoAlto);
    final pivo = math.min(1.4, r - 0.6);
    t.porFora('${pre}hall', _Lado.frente, pivo,
        tipo: TipoAbertura.portaPivotante,
        alvo: (l + 0.2 + pivo / 2, dt),
        altura: _vaoAlto);
    t.ligar('${pre}garagem', '${pre}hall', TipoAbertura.porta, 0.8);
    t.ligar('${pre}hall', '${pre}escada', TipoAbertura.passagem, 1.2);
    t.ligar('${pre}escada', '${pre}cozinha', TipoAbertura.passagem, 0.9);
    t.ligar('${pre}cozinha', '${pre}sala', TipoAbertura.passagem,
        (l - 0.6).clamp(1.2, 4.0).toDouble());
    t.ligarAoMelhor('${pre}lavabo', ['${pre}cozinha', '${pre}sala'],
        TipoAbertura.porta, 0.7);
    t.ligarAoMelhor('${pre}lavanderia', ['${pre}cozinha', '${pre}sala'],
        TipoAbertura.porta, 0.8);
    final correr = math.min(3.0, l - 0.6);
    if (temGourmet) {
      t.cels.add(cel('gourmet', 'Área gourmet', 'gourmet', 0, 0, w, _gourmet,
          piso: PisoComodo.ceramica, aberto: true));
      t.ligar('${pre}sala', '${pre}gourmet', TipoAbertura.portaCorrer, correr);
      t.ligar('${pre}lavanderia', '${pre}gourmet', TipoAbertura.porta, 0.8);
    } else {
      t.porFora('${pre}sala', _Lado.fundos, correr,
          tipo: TipoAbertura.portaCorrer);
      t.porFora('${pre}lavanderia', _Lado.fundos, 0.8);
    }

    // Superior.
    final s = casa.superior!;
    final ps = '${pre}s-';
    _Cel cs(String id, String nome, String tipo, double x0, double ya,
            double x1, double yb, {PisoComodo piso = PisoComodo.porcelanato}) =>
        _Cel('$ps$id', nome, tipo, x0, ya, x1, yb,
            piso: piso, unidade: unidade);
    final y1 = dt - sac - suite; // fim da suíte
    final cw = (l * 0.42).clamp(1.4, 2.0).toDouble(); // o closet
    final dm = q >= 2 ? 2.2 : e; // closet e banheiro da suíte
    final yq = y1 - meio - (temCorredor ? corredor : 0); // os quartos
    s.cels.addAll([
      _Cel('${ps}sacada', 'Sacada', 'varanda', 0, dt - sac, w, dt,
          piso: PisoComodo.ceramica,
          unidade: unidade,
          guardaCorpo: true,
          vidroSoNaFrente: true,
          vidroEntre: (0.7, w - 0.7)),
      cs('suite', 'Suíte', 'quarto', 0, y1, w, dt - sac),
      cs('closet', 'Closet', 'closet', 0, y1 - dm, cw, y1),
      cs('banho-suite', 'Banheiro da suíte', 'banheiro', cw, y1 - dm, l, y1,
          piso: PisoComodo.ceramica),
      cs('escada', 'Escada', 'escada', l, y1 - e, w, y1,
          piso: PisoComodo.cimento),
      if (q >= 2) ...[
        cs('banheiro', 'Banheiro', 'banheiro', 0, y1 - meio, l, y1 - dm,
            piso: PisoComodo.ceramica),
        cs('circulacao', 'Circulação', 'circulacao', l, y1 - meio, w, y1 - e),
      ],
      if (temCorredor)
        cs('corredor', 'Corredor', 'circulacao', 0, yq, w, yq + corredor),
      if (q == 1)
        cs('sala-intima', 'Sala íntima', 'sala', 0, y0, w, yq)
      else
        for (var i = 0; i < atras; i++)
          cs('quarto-${i + 2}', 'Quarto ${i + 2}', 'quarto', w * i / atras, y0,
              w * (i + 1) / atras, yq),
    ]);
    // O ripado em L e a porta de correr na parede do fundo da sacada.
    final rip = ((w - 1.4) / 4.6).clamp(0.6, 1.2).toDouble();
    final correrSuite = w - 1.8 - rip;
    s.ligar('${ps}suite', '${ps}sacada', TipoAbertura.portaCorrer, correrSuite,
        alvo: ((rip + w) / 2, dt - sac), altura: _vaoSacada);
    s.ligar('${ps}suite', '${ps}closet', TipoAbertura.passagem, 0.8);
    s.ligar('${ps}closet', '${ps}banho-suite', TipoAbertura.porta, 0.7);
    s.ligar('${ps}suite', '${ps}escada', TipoAbertura.porta, 0.8);
    if (q == 1) {
      s.ligar('${ps}escada', '${ps}sala-intima', TipoAbertura.passagem, 1.0);
    } else {
      s.ligar('${ps}escada', '${ps}circulacao', TipoAbertura.passagem, 1.0);
      s.ligar('${ps}banheiro', '${ps}circulacao', TipoAbertura.porta, 0.7);
      if (temCorredor) {
        s.ligar('${ps}circulacao', '${ps}corredor', TipoAbertura.passagem, 1.0);
      }
      for (var i = 0; i < atras; i++) {
        s.ligar(
            '${ps}quarto-${i + 2}',
            temCorredor ? '${ps}corredor' : '${ps}circulacao',
            TipoAbertura.porta,
            0.8);
      }
    }

    // A fachada: a moldura da sacada (descendo até cobrir a laje do
    // térreo), o ripado em L no fundo da sacada e os panos de parede entre
    // a moldura e as divisas.
    final yFrente = dt + 0.075; // face de fora da parede da frente
    final yFundo = dt - sac + 0.06; // face da parede do fundo da sacada
    casa.fachadaSuperior.addAll([
      for (final (a, b) in [(0.0, 0.2), (w - 0.2, w)])
        ElementoFachada(
          tipo: TipoElementoFachada.pano,
          de: a,
          ate: b,
          y: yFrente,
          base: -0.32,
          topo: alturasGeminado.peDireito + 0.12,
          recuo: sac + 0.015,
        ),
      ElementoFachada(
        tipo: TipoElementoFachada.moldura,
        de: 0.2,
        ate: w - 0.2,
        y: yFrente,
        // De 2,80 a 6,40 m do chão; a faixa de baixo até 3,30 m.
        base: -0.32,
        topo: alturasGeminado.peDireito + 0.48,
        saliencia: 0.3,
        recuo: sac + 0.015,
        borda: 0.5,
        peitoril: 0.18,
      ),
      ElementoFachada(
        tipo: TipoElementoFachada.ripadoVertical,
        de: 0.7,
        ate: 0.7 + rip,
        y: yFundo,
        base: 0,
        topo: alturasGeminado.peDireito,
        saliencia: 0.06,
        passo: 0.1,
      ),
      ElementoFachada(
        tipo: TipoElementoFachada.ripadoHorizontal,
        de: 0.7 + rip,
        ate: w - 0.7,
        y: yFundo,
        base: _vaoSacada,
        topo: alturasGeminado.peDireito,
        saliencia: 0.06,
        passo: 0.075,
      ),
    ]);
    casa.entrada = '${pre}hall';
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
    final modelo = _terrea('', p.area, p.quartos, null,
        portaDaFrente: false, apartamento: true);
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
        final apto = _terrea('a$n-', p.area, p.quartos, 'Apto $n',
            portaDaFrente: false, apartamento: true);
        pav.juntar(apto.terreo, ox + i * wu, oy + yFrente);
        pav.ligar(apto.entrada, 'corredor', TipoAbertura.porta, 0.9);
      }
      for (var i = 0; i < fundos; i++) {
        n++;
        final apto = _terrea('a$n-', p.area, p.quartos, 'Apto $n',
            portaDaFrente: false, apartamento: true);
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
              piso: PisoComodo.ceramica, fachada: 'ripado'),
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
              coberto: false, piso: PisoComodo.cimento, portao: 3.0),
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
            p.andares - 1,
            const <ElementoFachada>[],
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
    required List<(String, _Pavimento, int, List<ElementoFachada>)> andares,
    AlturasPlanta alturas = _alturasCasa,
    List<ElementoFachada> fachada = const [],
  }) {
    final t = _Construtor(terreo, largura, profundidade, 't', terreo: true);
    return PlantaObra(
      nome: nome,
      fonte: 'Modelo do app: ${pedido.resumo}',
      largura: _r(largura),
      profundidade: _r(profundidade),
      alturas: alturas,
      paredes: t.paredes,
      pilares: t.pilares,
      comodos: t.comodos,
      nomeTerreo: 'Térreo',
      fachada: fachada,
      andares: [
        for (final (i, (nomeAndar, pav, rep, fachadaAndar)) in andares.indexed)
          () {
            final c = _Construtor(pav, largura, profundidade, 'a${i + 1}');
            return AndarPlanta(
              nome: nomeAndar,
              paredes: c.paredes,
              pilares: c.pilares,
              comodos: c.comodos,
              repeticoes: rep,
              fachada: fachadaAndar,
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
      {this.coberto = true,
      this.piso = PisoComodo.porcelanato,
      this.unidade,
      this.aberto = false,
      this.guardaCorpo = false,
      this.fachada,
      this.portao,
      this.abertoRua = false,
      this.vidroSoNaFrente = false,
      this.vidroEntre});

  String id;
  final String nome;
  final String tipo;
  double x0, y0, x1, y1;
  final bool coberto;
  final PisoComodo piso;
  final String? unidade;

  /// Sem paredes para fora: a garagem coberta e a área gourmet ficam só nos
  /// pilares; o acesso da garagem fica sem muro para a rua.
  final bool aberto;

  /// A parede de fora é mureta com vidro (a sacada).
  final bool guardaCorpo;

  /// Acabamento da fachada na maquete ("ripado", "moldura").
  final String? fachada;

  /// Largura do portão no muro da frente deste quintal.
  final double? portao;

  /// Quintal sem muro para a rua (só os dos lados): a frente aberta do
  /// geminado.
  final bool abertoRua;

  /// Com [guardaCorpo]: vidro só na frente; dos lados, parede (a sacada
  /// dentro da moldura).
  final bool vidroSoNaFrente;

  /// O vidro da mureta só entre estes x (o vão da moldura); nulo: a mureta
  /// toda.
  final (double, double)? vidroEntre;

  _Cel mover(double dx, double dy, {double? espelharY, String prefixo = ''}) {
    var a = y0, b = y1;
    if (espelharY != null) {
      a = espelharY - y1;
      b = espelharY - y0;
    }
    return _Cel('$prefixo$id', nome, tipo, x0 + dx, a + dy, x1 + dx, b + dy,
        coberto: coberto,
        piso: piso,
        unidade: unidade,
        aberto: aberto,
        guardaCorpo: guardaCorpo,
        fachada: fachada,
        portao: portao,
        abertoRua: abertoRua,
        vidroSoNaFrente: vidroSoNaFrente,
        vidroEntre: vidroEntre == null
            ? null
            : (vidroEntre!.$1 + dx, vidroEntre!.$2 + dx));
  }
}

/// Porta, passagem ou janela pedida entre dois cômodos ([b]) ou para fora
/// ([lado]).
class _Lig {
  _Lig(this.a, this.b, this.lado, this.tipo, this.largura,
      {this.candidatos, this.alvo, this.altura});

  final String a;
  final String? b;
  final _Lado? lado;
  final TipoAbertura tipo;
  final double largura;

  /// Ligar ao vizinho, entre estes, com quem a parede comum é maior.
  final List<String>? candidatos;

  /// Ponto (x, y) onde o meio do vão deve ficar (a fachada desenhada); nulo:
  /// no meio do maior trecho livre.
  final (double, double)? alvo;

  /// Altura do vão; nula: 2,10 m (porta) ou a do pé-direito (passagem).
  final double? altura;

  _Lig mover(double dx, double dy, {double? espelharY}) {
    var l = lado;
    if (espelharY != null && l != null) {
      l = switch (l) {
        _Lado.frente => _Lado.fundos,
        _Lado.fundos => _Lado.frente,
        _ => l,
      };
    }
    final p = alvo;
    return _Lig(a, b, l, tipo, largura,
        candidatos: candidatos,
        altura: altura,
        alvo: p == null
            ? null
            : (p.$1 + dx, (espelharY == null ? p.$2 : espelharY - p.$2) + dy));
  }
}

class _Pavimento {
  final List<_Cel> cels = [];
  final List<_Lig> ligs = [];

  void ligar(String a, String b, TipoAbertura tipo, double largura,
          {(double, double)? alvo, double? altura}) =>
      ligs.add(_Lig(a, b, null, tipo, largura, alvo: alvo, altura: altura));

  void porFora(String a, _Lado lado, double largura,
          {TipoAbertura tipo = TipoAbertura.porta,
          (double, double)? alvo,
          double? altura}) =>
      ligs.add(_Lig(a, null, lado, tipo, largura, alvo: alvo, altura: altura));

  /// Porta para o vizinho (entre [candidatos]) com a maior parede comum.
  void ligarAoMelhor(String a, List<String> candidatos, TipoAbertura tipo,
          double largura) =>
      ligs.add(_Lig(a, null, null, tipo, largura, candidatos: candidatos));

  /// Junta [outro] deslocado (e espelhado em y, na fila dos fundos do
  /// prédio: um espelho troca frente e fundo, mas não as ligações).
  void juntar(_Pavimento outro, double dx, double dy, {double? espelharY}) {
    for (final c in outro.cels) {
      cels.add(c.mover(dx, dy, espelharY: espelharY));
    }
    for (final l in outro.ligs) {
      ligs.add(l.mover(dx, dy, espelharY: espelharY));
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

  /// Tem garagem coberta na frente, de x = 0 até [garagemAte].
  bool garagemCoberta = false;
  double garagemAte = 0;

  /// A frente coberta (garagem e hall) vai até x = [frenteAte]; do lado,
  /// até a frente, o corpo da casa termina em y = [corpoAte] (o jardim).
  double? frenteAte;
  double? corpoAte;

  /// A fachada do geminado: garagem fechada na frente, até x =
  /// [garagemAte], e a entrada do lado; frente aberta para a rua.
  bool garagemFechada = false;

  /// Moldura, ripado e aleta (coordenadas da casa), por pavimento.
  final fachadaTerreo = <ElementoFachada>[];
  final fachadaSuperior = <ElementoFachada>[];
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
          if (cobertas.length == 1) {
            final c = cobertas.first;
            // Garagem e gourmet: abertos para fora (só os pilares).
            if (c.aberto) continue;
            final frenteDaCel = h && (linha - c.y1).abs() < _eps;
            if (c.guardaCorpo && (!c.vidroSoNaFrente || frenteDaCel)) {
              pecas.add(_Peca(
                  h, linha, a, b, TipoParede.muretaVidro, _interna, {c.id}));
              continue;
            }
          } else if (!divisa && cobertas.every((c) => c.aberto)) {
            continue;
          }
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
        // unidades diferentes (o acesso da garagem fica aberto para a rua).
        final rua = h && (linha - profundidade).abs() < _eps;
        final muro = (terreo &&
                noLimite &&
                dono.length == 1 &&
                !dono.first.aberto &&
                !(rua && dono.first.abertoRua)) ||
            (dono.length == 2 &&
                dono[0].unidade != dono[1].unidade &&
                !(dono[0].abertoRua && dono[1].abertoRua));
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
      {double? peitoril, double? altura, double minimo = 0.6, double? centro}) {
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
    // Com o centro pedido (a fachada desenhada): o trecho livre que tem
    // ele, ou o mais perto; senão, o maior.
    double distancia((double, double) t) => centro == null
        ? 0
        : centro < t.$1
            ? t.$1 - centro
            : centro > t.$2
                ? centro - t.$2
                : 0;
    livres.sort((p, q) {
      final d = distancia(p).compareTo(distancia(q));
      if (d != 0) return d;
      return (q.$2 - q.$1).compareTo(p.$2 - p.$1);
    });
    final (x, y) = livres.first;
    final cabe = math.min(largura, y - x);
    if (cabe < minimo) return false;
    final inicio = centro == null
        ? (x + y) / 2 - cabe / 2
        : (centro - cabe / 2).clamp(x, y - cabe).toDouble();
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
    // A sacada: vidro em toda a mureta.
    for (final w in _paredes.where((w) => w.tipo == TipoParede.muretaVidro)) {
      // Um vidro por sacada (a mureta de casas vizinhas vira uma parede
      // só), e só no vão da moldura, se a sacada pede.
      final porSacada = <String, (double, double)>{};
      for (final p in w.pecas) {
        final id = p.cels.first;
        final atual = porSacada[id];
        porSacada[id] = atual == null
            ? (p.a, p.b)
            : (math.min(atual.$1, p.a), math.max(atual.$2, p.b));
      }
      for (final MapEntry(key: id, value: (pa, pb)) in porSacada.entries) {
        var a = pa, b = pb;
        final faixa = _porId[id]?.vidroEntre;
        if (faixa != null && w.horizontal) {
          a = math.max(a, faixa.$1);
          b = math.min(b, faixa.$2);
        }
        if (b - a < 0.3) continue;
        w.vaos.add(AberturaPlanta(
          id: '$prefixo-v${++_contaVaos}',
          tipo: TipoAbertura.janela,
          inicio: _r(a - w.a),
          largura: _r(b - a),
          peitoril: 0.15,
          altura: 0.95,
        ));
      }
    }
    for (final l in pav.ligs) {
      final a = _porId[l.a];
      if (a == null) continue;
      final List<(_Parede, double, double)> trechos;
      if (l.candidatos != null) {
        trechos = [
          for (final c in l.candidatos!)
            ..._trechos(
                (w, p) => p.cels.length == 2 && p.cels.containsAll({l.a, c})),
        ];
      } else if (l.b != null) {
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
      // Com o alvo: o trecho que passa mais perto dele.
      final alvo = l.alvo;
      double longe((_Parede, double, double) t) {
        if (alvo == null) return 0;
        final (w, x, y) = t;
        final u = w.horizontal ? alvo.$1 : alvo.$2;
        final v = w.horizontal ? alvo.$2 : alvo.$1;
        final fora = u < x ? x - u : (u > y ? u - y : 0.0);
        return fora + (v - w.linha).abs();
      }

      trechos.sort((p, q) {
        final d = longe(p).compareTo(longe(q));
        if (d != 0) return d;
        return (q.$3 - q.$2).compareTo(p.$3 - p.$2);
      });
      final (w, x, y) = trechos.first;
      _por(w, x, y, l.largura, l.tipo,
          altura: l.altura ?? (l.tipo == TipoAbertura.passagem ? null : 2.1),
          centro: alvo == null ? null : (w.horizontal ? alvo.$1 : alvo.$2),
          minimo: math.min(0.6, l.largura));
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
      // Na divisa do terreno não abre janela (código de obras).
      bool naDivisa(_Parede w) =>
          !w.horizontal &&
          (w.linha.abs() < _eps || (w.linha - this.largura).abs() < _eps);
      final trechos = _trechos((w, p) =>
          p.cels.length == 1 &&
          p.cels.first == c.id &&
          p.tipo == TipoParede.alvenaria &&
          !naDivisa(w));
      trechos.sort((p, q) => (q.$3 - q.$2).compareTo(p.$3 - p.$2));
      for (final (w, x, y) in trechos) {
        if (_por(w, x, y, largura, TipoAbertura.janela,
            peitoril: peitoril, altura: altura, minimo: largura * 0.6)) {
          break;
        }
      }
    }
    // Portão: no muro da frente dos quintais que pedem um.
    if (terreo) {
      for (final c in pav.cels.where((c) => !c.coberto && c.portao != null)) {
        final trechos = _trechos((w, p) =>
            p.tipo == TipoParede.muro &&
            p.cels.contains(c.id) &&
            w.horizontal &&
            (w.linha - profundidade).abs() < _eps);
        if (trechos.isEmpty) continue;
        trechos.sort((p, q) => (q.$3 - q.$2).compareTo(p.$3 - p.$2));
        final (w, x, y) = trechos.first;
        _por(w, x, y, c.portao!, TipoAbertura.portao, altura: 2.0, minimo: 0.8);
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
            altura: w.tipo == TipoParede.muretaVidro ? 1.1 : null,
            aberturas: [...w.vaos]
              ..sort((p, q) => p.inicio.compareTo(q.inicio)),
          ),
      ];

  /// Pilares soltos: nos cantos da garagem coberta e da área gourmet (as
  /// paredes não seguram a laje ali).
  List<PilarPlanta> get pilares {
    final saida = <PilarPlanta>[];
    for (final c in pav.cels.where((c) => c.coberto && c.aberto)) {
      for (final (x, y) in [
        (c.x0, c.y0),
        (c.x1, c.y0),
        (c.x0, c.y1),
        (c.x1, c.y1)
      ]) {
        if (saida.any((p) => (p.x - x).abs() < 0.3 && (p.y - y).abs() < 0.3)) {
          continue;
        }
        saida.add(PilarPlanta(x: _r(x), y: _r(y)));
      }
    }
    return saida;
  }

  List<ComodoPlanta> get comodos => [
        for (final c in pav.cels)
          ComodoPlanta(
            id: '$prefixo-${c.id}',
            nome: c.nome,
            tipo: c.tipo,
            coberto: c.coberto,
            piso: c.piso,
            unidade: c.unidade,
            fachada: c.fachada,
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
