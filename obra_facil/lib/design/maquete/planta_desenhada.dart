import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/planta_obra.dart';
import '../tipografia.dart';
import '../tokens.dart';
import 'progresso_maquete.dart';

/// A planta baixa da obra desenhada como na prancheta: cômodos com nome e
/// área, paredes em grafite (já levantadas) ou tracejadas (ainda não), vãos
/// abertos e janelas em traço fino. Tocável: [aoTocarComodo] recebe o
/// cômodo tocado e [selecionado] fica destacado em laranja.
///
/// É a reserva da maquete gerada pela planta (aparelho sem 3D, testes,
/// "reduzir animações") e a planta que o cliente toca para ver cada cômodo.
/// Numa caixa larga, a planta comprida deita: a frente (a rua) fica à
/// direita.
class PlantaDesenhada extends StatelessWidget {
  const PlantaDesenhada({
    super.key,
    required this.planta,
    this.progresso,
    this.selecionado,
    this.aoTocarComodo,
    this.rotulos = true,
    this.numeros,
  });

  /// Altura que a planta pede para a [largura] dada (sem sobrar papel em
  /// cima e embaixo), entre [minima] e [maxima].
  static double alturaPara(PlantaObra planta, double largura,
      {double minima = 140, double maxima = 420}) {
    const margem = 2 * 14.0;
    final deitada = planta.profundidade > planta.largura;
    final proporcao = deitada
        ? planta.largura / planta.profundidade
        : planta.profundidade / planta.largura;
    return ((largura - margem) * proporcao + margem).clamp(minima, maxima);
  }

  final PlantaObra planta;

  /// Avanço da obra; nulo: a planta inteira em traço cheio (projeto).
  final ProgressoMaquete? progresso;

  /// Id do cômodo destacado.
  final String? selecionado;
  final ValueChanged<ComodoPlanta>? aoTocarComodo;

  /// Nome e área dentro dos cômodos que couberem.
  final bool rotulos;

  /// Número de cada cômodo (pelo id), como na legenda de um desenho: com
  /// ele, a planta mostra o número no lugar do nome (que não cabe em
  /// cômodo pequeno) e a lista ao lado repete o número.
  final Map<String, int>? numeros;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return LayoutBuilder(builder: (context, caixa) {
      final tamanho = Size(
        caixa.maxWidth.isFinite ? caixa.maxWidth : 320,
        caixa.maxHeight.isFinite ? caixa.maxHeight : 220,
      );
      final mapa = MapaPlanta(planta, tamanho);
      final pintura = CustomPaint(
        size: tamanho,
        painter: _PintorPlanta(
          planta: planta,
          mapa: mapa,
          cores: c,
          paredesLevantadas: progresso == null ||
              progresso!.avancoPorFase[2] > 0 ||
              progresso!.estadoReserva > 2,
          selecionado: selecionado,
          rotulos: rotulos,
          numeros: numeros,
          escalaTexto: MediaQuery.textScalerOf(context),
        ),
      );
      final tocar = aoTocarComodo;
      if (tocar == null) return pintura;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final (x, y) = mapa.paraPlanta(d.localPosition);
          final comodo = planta.comodoEm(x, y);
          if (comodo != null) tocar(comodo);
        },
        child: pintura,
      );
    });
  }
}

/// Da planta (metros) para a tela (pontos) e de volta.
class MapaPlanta {
  MapaPlanta(this.planta, this.tamanho, {double margem = 14})
      : deitada = planta.profundidade > planta.largura &&
            tamanho.width > tamanho.height {
    final largura = deitada ? planta.profundidade : planta.largura;
    final altura = deitada ? planta.largura : planta.profundidade;
    escala = math.min(
      (tamanho.width - 2 * margem) / largura,
      (tamanho.height - 2 * margem) / altura,
    );
    origem = Offset(
      (tamanho.width - largura * escala) / 2,
      (tamanho.height - altura * escala) / 2,
    );
  }

  final PlantaObra planta;
  final Size tamanho;

  /// A planta comprida deitou (a frente fica à direita).
  final bool deitada;
  late final double escala;
  late final Offset origem;

  Offset paraTela(double x, double y) => deitada
      ? origem + Offset(y * escala, (planta.largura - x) * escala)
      : origem + Offset(x * escala, y * escala);

  (double, double) paraPlanta(Offset p) {
    final q = (p - origem) / escala;
    return deitada ? (planta.largura - q.dy, q.dx) : (q.dx, q.dy);
  }

  Rect retangulo(RetanguloPlanta r) =>
      Rect.fromPoints(paraTela(r.x, r.y), paraTela(r.x1, r.y1));
}

class _PintorPlanta extends CustomPainter {
  _PintorPlanta({
    required this.planta,
    required this.mapa,
    required this.cores,
    required this.paredesLevantadas,
    required this.selecionado,
    required this.rotulos,
    required this.numeros,
    required this.escalaTexto,
  });

  final Map<String, int>? numeros;

  final PlantaObra planta;
  final MapaPlanta mapa;
  final CoresObra cores;
  final bool paredesLevantadas;
  final String? selecionado;
  final bool rotulos;
  final TextScaler escalaTexto;

  @override
  void paint(Canvas canvas, Size size) {
    final c = cores;
    // Terreno.
    final lote = mapa
        .retangulo(RetanguloPlanta(0, 0, planta.largura, planta.profundidade));
    canvas.drawRect(lote, Paint()..color = c.folhaRebaixada);

    // Cômodos.
    for (final comodo in planta.comodos) {
      final sel = comodo.id == selecionado;
      final cor = sel
          ? c.marca.withValues(alpha: 0.35)
          : comodo.coberto
              ? c.folha
              : comodo.piso == PisoComodo.grama
                  ? c.grade
                  : c.folhaRebaixada;
      for (final r in comodo.retangulos) {
        canvas.drawRect(mapa.retangulo(r), Paint()..color = cor);
      }
    }

    // Paredes.
    final cheia = Paint()
      ..color = c.grafite
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    for (final w in planta.paredes) {
      final esp = math.max(2.0, w.espessura * mapa.escala);
      final muro = w.tipo == TipoParede.muro;
      final tinta = cheia
        ..strokeWidth = muro ? math.max(1.5, esp * 0.7) : esp
        ..color = muro ? c.traco : c.grafite;
      final trechos = <(double, double)>[(0, w.comprimento)];
      final vaos = [...w.aberturas]
        ..sort((a, b) => a.inicio.compareTo(b.inicio));
      final cheios = <(double, double)>[];
      var u = 0.0;
      for (final a in vaos) {
        if (a.inicio > u) cheios.add((u, a.inicio));
        u = math.max(u, a.inicio + a.largura);
      }
      if (u < w.comprimento) cheios.add((u, w.comprimento));
      for (final (a, b)
          in w.tipo == TipoParede.muretaVidro ? trechos : cheios) {
        final p0 = w.pontoEm(a), p1 = w.pontoEm(b);
        final o0 = mapa.paraTela(p0.$1, p0.$2),
            o1 = mapa.paraTela(p1.$1, p1.$2);
        if (paredesLevantadas) {
          canvas.drawLine(o0, o1, tinta);
        } else {
          _tracejar(
              canvas,
              o0,
              o1,
              Paint()
                ..color = c.traco
                ..strokeWidth = 1.5);
        }
      }
      // Janelas: traço fino no vão.
      for (final a in vaos) {
        if (!a.tipo.ehJanela) continue;
        final p0 = w.pontoEm(a.inicio), p1 = w.pontoEm(a.inicio + a.largura);
        canvas.drawLine(
          mapa.paraTela(p0.$1, p0.$2),
          mapa.paraTela(p1.$1, p1.$2),
          Paint()
            ..color = c.traco
            ..strokeWidth = 1.5,
        );
      }
    }

    // Contorno do terreno, tracejado.
    final pts = [
      lote.topLeft,
      lote.topRight,
      lote.bottomRight,
      lote.bottomLeft
    ];
    for (var i = 0; i < 4; i++) {
      _tracejar(
          canvas,
          pts[i],
          pts[(i + 1) % 4],
          Paint()
            ..color = c.traco
            ..strokeWidth = 1);
    }

    // Destaque do cômodo escolhido (por cima das paredes).
    for (final comodo in planta.comodos) {
      if (comodo.id != selecionado) continue;
      for (final r in comodo.retangulos) {
        canvas.drawRect(
          mapa.retangulo(r).deflate(1),
          Paint()
            ..color = c.marcaTexto
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    if (rotulos) _rotular(canvas);
  }

  void _rotular(Canvas canvas) {
    final numeros = this.numeros;
    if (numeros != null) {
      _numerar(canvas, numeros);
      return;
    }
    for (final comodo in planta.comodos) {
      final r = mapa.retangulo(comodo.principal).deflate(4);
      final area = comodo.area.toStringAsFixed(1).replaceAll('.', ',');
      final texto = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: comodo.nome.toUpperCase(),
            style: Tipografia.rotulo.copyWith(color: cores.grafite),
          ),
          TextSpan(
            text: '\n$area m²',
            style: Tipografia.rotulo.copyWith(
              color: cores.grafite2,
              fontWeight: FontWeight.w600,
              fontFeatures: Tipografia.tabular,
            ),
          ),
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        textScaler: escalaTexto,
        maxLines: 2,
      )..layout(maxWidth: math.max(0, r.width));
      // Só onde cabe inteiro (texto cortado não informa).
      if (texto.width > r.width + 0.5 ||
          texto.height > r.height ||
          texto.didExceedMaxLines) {
        texto.dispose();
        continue;
      }
      texto.paint(canvas, r.center - Offset(texto.width / 2, texto.height / 2));
      texto.dispose();
    }
  }

  /// O número de cada cômodo num círculo, no meio do retângulo principal.
  void _numerar(Canvas canvas, Map<String, int> numeros) {
    for (final comodo in planta.comodos) {
      final n = numeros[comodo.id];
      if (n == null) continue;
      final r = mapa.retangulo(comodo.principal);
      final sel = comodo.id == selecionado;
      final texto = TextPainter(
        text: TextSpan(
          text: '$n',
          style: Tipografia.rotulo.copyWith(
            color: sel ? cores.sobreMarca : cores.grafite,
            fontFeatures: Tipografia.tabular,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: escalaTexto.clamp(maxScaleFactor: 1.3),
      )..layout();
      final raio = math.max(texto.width, texto.height) / 2 + 4;
      // Cômodo estreito demais nem para o número: fica sem.
      if (r.shortestSide < raio * 2 - 2) {
        texto.dispose();
        continue;
      }
      canvas.drawCircle(
          r.center, raio, Paint()..color = sel ? cores.marca : cores.folha);
      canvas.drawCircle(
        r.center,
        raio,
        Paint()
          ..color = cores.grafite
          ..style = PaintingStyle.stroke
          ..strokeWidth = Traco.fino,
      );
      texto.paint(canvas, r.center - Offset(texto.width / 2, texto.height / 2));
      texto.dispose();
    }
  }

  static void _tracejar(Canvas canvas, Offset a, Offset b, Paint tinta) {
    final d = b - a;
    final c = d.distance;
    if (c < 0.5) return;
    final u = d / c;
    const traco = 6.0, vazio = 4.0;
    var s = 0.0;
    while (s < c) {
      final e = math.min(s + traco, c);
      canvas.drawLine(a + u * s, a + u * e, tinta);
      s = e + vazio;
    }
  }

  @override
  bool shouldRepaint(covariant _PintorPlanta velho) =>
      velho.planta != planta ||
      velho.selecionado != selecionado ||
      velho.paredesLevantadas != paredesLevantadas ||
      velho.cores != cores ||
      velho.mapa.tamanho != mapa.tamanho ||
      velho.rotulos != rotulos ||
      velho.numeros != numeros;
}
