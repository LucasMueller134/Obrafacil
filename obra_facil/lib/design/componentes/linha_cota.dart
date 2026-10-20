import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../tipografia.dart';
import '../tokens.dart';
import 'rotulo.dart';
import 'tracejado.dart';

/// Traço oblíquo de 45° da linha de cota, centrado em [centro].
void pintarTracoObliquo(
  Canvas canvas,
  Offset centro,
  Color cor, {
  double tamanho = 12,
  double espessura = Traco.forte,
}) {
  final d = tamanho / 2;
  canvas.drawLine(
    centro + Offset(-d, d),
    centro + Offset(d, -d),
    Paint()
      ..color = cor
      ..strokeWidth = espessura,
  );
}

/// Divisória como linha de cota: traço oblíquo nas pontas e, opcional, a
/// legenda em caixa alta no meio.
class LinhaCota extends StatelessWidget {
  const LinhaCota({super.key, this.legenda});

  final String? legenda;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    Widget trecho({required bool esquerda, required bool direita}) =>
        CustomPaint(
          size: const Size(double.infinity, 20),
          painter: _PintorLinhaCota(
            linha: c.traco,
            ponta: c.grafite,
            pontaEsquerda: esquerda,
            pontaDireita: direita,
          ),
        );
    if (legenda == null) return trecho(esquerda: true, direita: true);
    // A legenda nunca come a linha inteira: sobram ao menos 32 dp de cada
    // lado e, se não couber (fonte grande), ela quebra em duas linhas. É
    // um layout próprio (sem LayoutBuilder), para funcionar também dentro
    // de diálogo.
    return _ComLegenda(
      linha: c.traco,
      ponta: c.grafite,
      child: Rotulo(legenda!, maxLinhas: 2, alinhamento: TextAlign.center),
    );
  }
}

/// Linha de cota com a legenda no meio: a legenda é o filho; as duas
/// metades da linha são pintadas aqui, dos lados dela.
class _ComLegenda extends SingleChildRenderObjectWidget {
  const _ComLegenda({
    required this.linha,
    required this.ponta,
    required super.child,
  });

  final Color linha;
  final Color ponta;

  @override
  _RenderComLegenda createRenderObject(BuildContext context) =>
      _RenderComLegenda(linha: linha, ponta: ponta);

  @override
  void updateRenderObject(
      BuildContext context, _RenderComLegenda renderObject) {
    renderObject
      ..linha = linha
      ..ponta = ponta;
  }
}

class _RenderComLegenda extends RenderShiftedBox {
  _RenderComLegenda({required Color linha, required Color ponta})
      : _linha = linha,
        _ponta = ponta,
        super(null);

  /// Linha mínima de cada lado e o respiro entre ela e a legenda.
  static const double _sobra = Espaco.e32;
  static const double _respiro = Espaco.e8;
  static const double _reservado = 2 * (_sobra + _respiro);
  static const double _alturaMinima = 20;

  Color _linha;
  set linha(Color v) {
    if (v == _linha) return;
    _linha = v;
    markNeedsPaint();
  }

  Color _ponta;
  set ponta(Color v) {
    if (v == _ponta) return;
    _ponta = v;
    markNeedsPaint();
  }

  Size _medir(
    BoxConstraints limites,
    Size Function(RenderBox, BoxConstraints) medir,
  ) {
    final legenda = child;
    final largura = limites.maxWidth.isFinite
        ? limites.maxWidth
        : (legenda?.getMaxIntrinsicWidth(double.infinity) ?? 0) + _reservado;
    final tamanho = legenda == null
        ? Size.zero
        : medir(
            legenda,
            BoxConstraints(maxWidth: math.max(0, largura - _reservado)),
          );
    return limites.constrain(
      Size(largura, math.max(_alturaMinima, tamanho.height)),
    );
  }

  @override
  void performLayout() {
    size = _medir(constraints, (filho, limites) {
      filho.layout(limites, parentUsesSize: true);
      return filho.size;
    });
    if (child case final legenda?) {
      (legenda.parentData! as BoxParentData).offset = Offset(
        (size.width - legenda.size.width) / 2,
        (size.height - legenda.size.height) / 2,
      );
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _medir(constraints, (filho, limites) => filho.getDryLayout(limites));

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(height) ?? 0) + _reservado;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(height) ?? 0) + _reservado;

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
        _alturaMinima,
        child?.getMinIntrinsicHeight(math.max(0, width - _reservado)) ?? 0,
      );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
        _alturaMinima,
        child?.getMaxIntrinsicHeight(math.max(0, width - _reservado)) ?? 0,
      );

  @override
  void paint(PaintingContext context, Offset offset) {
    final legenda = child;
    final meio = offset.dy + size.height / 2;
    var esquerda = offset.dx + size.width / 2;
    var direita = esquerda;
    if (legenda != null) {
      final inicio = (legenda.parentData! as BoxParentData).offset.dx;
      esquerda = offset.dx + inicio - _respiro;
      direita = offset.dx + inicio + legenda.size.width + _respiro;
    }
    final canvas = context.canvas;
    _pintarTrecho(canvas, offset.dx, esquerda, meio, _linha, _ponta,
        pontaEsquerda: true, pontaDireita: false);
    _pintarTrecho(canvas, direita, offset.dx + size.width, meio, _linha, _ponta,
        pontaEsquerda: false, pontaDireita: true);
    super.paint(context, offset);
  }
}

/// Recuo da ponta: o traço oblíquo cabe dentro da linha.
const double _recuoPonta = 6;

/// Um trecho de linha de cota de [inicio] a [fim], na altura [y], com linha
/// de chamada e traço oblíquo nas pontas pedidas.
void _pintarTrecho(
  Canvas canvas,
  double inicio,
  double fim,
  double y,
  Color linha,
  Color ponta, {
  required bool pontaEsquerda,
  required bool pontaDireita,
}) {
  final x0 = pontaEsquerda ? inicio + _recuoPonta : inicio;
  final x1 = pontaDireita ? fim - _recuoPonta : fim;
  final traco = Paint()
    ..color = linha
    ..strokeWidth = Traco.fino;
  canvas.drawLine(Offset(x0, y), Offset(x1, y), traco);
  for (final (tem, x) in [(pontaEsquerda, x0), (pontaDireita, x1)]) {
    if (!tem) continue;
    // Linha de chamada curta e o traço oblíquo.
    canvas.drawLine(Offset(x, y - 6), Offset(x, y + 6), traco);
    pintarTracoObliquo(canvas, Offset(x, y), ponta, tamanho: 10);
  }
}

/// Legenda do tracejado: "– – – ainda não construído". Explica, junto da
/// maquete ou de um desenho, o que a linha tracejada quer dizer.
class LegendaTracejada extends StatelessWidget {
  const LegendaTracejada(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: Espaco.e8),
              child: CustomPaint(
                size: const Size(28, 4),
                painter: PintorTracejado(c.grafite),
              ),
            ),
          ),
          TextSpan(text: texto),
        ],
      ),
      style: Tipografia.apoio.copyWith(color: c.grafite2),
    );
  }
}

class _PintorLinhaCota extends CustomPainter {
  const _PintorLinhaCota({
    required this.linha,
    required this.ponta,
    required this.pontaEsquerda,
    required this.pontaDireita,
  });

  final Color linha;
  final Color ponta;
  final bool pontaEsquerda;
  final bool pontaDireita;

  @override
  void paint(Canvas canvas, Size size) => _pintarTrecho(
        canvas,
        0,
        size.width,
        size.height / 2,
        linha,
        ponta,
        pontaEsquerda: pontaEsquerda,
        pontaDireita: pontaDireita,
      );

  @override
  bool shouldRepaint(_PintorLinhaCota antigo) =>
      antigo.linha != linha ||
      antigo.ponta != ponta ||
      antigo.pontaEsquerda != pontaEsquerda ||
      antigo.pontaDireita != pontaDireita;
}
