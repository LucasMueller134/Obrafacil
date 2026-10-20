import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../tokens.dart';

enum _Lado { esquerda, direita }

/// Uma linha com texto à esquerda e valor à direita, como "Bloco cerâmico
/// ··· R$ 2.380,00".
///
/// A [direita] fica com a largura dela, até [fracaoMaxima] da linha (o que
/// passar disso encolhe ou quebra); a [esquerda] fica com todo o resto. As
/// duas alinham pela linha de base do texto, então o valor fica na altura
/// da primeira linha do título mesmo que ele quebre em duas.
///
/// É um layout próprio, sem `LayoutBuilder`: funciona dentro de diálogo,
/// menu e `IntrinsicHeight`, que medem o conteúdo antes de montar.
class ParComValor extends StatelessWidget {
  const ParComValor({
    super.key,
    required this.esquerda,
    this.direita,
    this.fracaoMaxima = 0.45,
    this.espaco = Espaco.e12,
  }) : assert(fracaoMaxima > 0 && fracaoMaxima <= 1);

  final Widget esquerda;
  final Widget? direita;

  /// Fração máxima da largura que a [direita] pode ocupar.
  final double fracaoMaxima;

  /// Espaço entre as duas partes.
  final double espaco;

  @override
  Widget build(BuildContext context) => _Par(
        esquerda: esquerda,
        direita: direita,
        fracaoMaxima: fracaoMaxima,
        espaco: espaco,
      );
}

class _Par extends SlottedMultiChildRenderObjectWidget<_Lado, RenderBox> {
  const _Par({
    required this.esquerda,
    required this.direita,
    required this.fracaoMaxima,
    required this.espaco,
  });

  final Widget esquerda;
  final Widget? direita;
  final double fracaoMaxima;
  final double espaco;

  @override
  Iterable<_Lado> get slots => _Lado.values;

  @override
  Widget? childForSlot(_Lado slot) => switch (slot) {
        _Lado.esquerda => esquerda,
        _Lado.direita => direita,
      };

  @override
  _RenderParComValor createRenderObject(BuildContext context) =>
      _RenderParComValor(fracaoMaxima: fracaoMaxima, espaco: espaco);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderParComValor renderObject,
  ) {
    renderObject
      ..fracaoMaxima = fracaoMaxima
      ..espaco = espaco;
  }
}

/// Resultado de um cálculo de layout (de verdade ou "a seco").
class _Medida {
  const _Medida({
    required this.tamanho,
    required this.esquerda,
    required this.direita,
    required this.baseline,
  });

  final Size tamanho;
  final Offset esquerda;
  final Offset direita;

  /// Linha de base da esquerda, medida do topo do par.
  final double? baseline;
}

class _RenderParComValor extends RenderBox
    with SlottedContainerRenderObjectMixin<_Lado, RenderBox> {
  _RenderParComValor({required double fracaoMaxima, required double espaco})
      : _fracaoMaxima = fracaoMaxima,
        _espaco = espaco;

  double _fracaoMaxima;
  set fracaoMaxima(double v) {
    if (v == _fracaoMaxima) return;
    _fracaoMaxima = v;
    markNeedsLayout();
  }

  double _espaco;
  set espaco(double v) {
    if (v == _espaco) return;
    _espaco = v;
    markNeedsLayout();
  }

  RenderBox? get _esquerda => childForSlot(_Lado.esquerda);
  RenderBox? get _direita => childForSlot(_Lado.direita);

  static const TextBaseline _linha = TextBaseline.alphabetic;

  /// O mesmo cálculo para o layout e para as medidas a seco (intrínsecas,
  /// `getDryLayout`): só muda como cada filho é medido.
  _Medida _medir(
    BoxConstraints limites, {
    required Size Function(RenderBox, BoxConstraints) tamanhoDe,
    required double? Function(RenderBox, BoxConstraints) baselineDe,
  }) {
    final esquerda = _esquerda;
    final direita = _direita;
    final largura = limites.maxWidth;

    var tamDireita = Size.zero;
    BoxConstraints? limDireita;
    if (direita != null) {
      limDireita = BoxConstraints(
        maxWidth: largura.isFinite ? largura * _fracaoMaxima : double.infinity,
      );
      tamDireita = tamanhoDe(direita, limDireita);
    }
    final espaco = esquerda != null && direita != null && tamDireita.width > 0
        ? _espaco
        : 0.0;

    var tamEsquerda = Size.zero;
    BoxConstraints? limEsquerda;
    if (esquerda != null) {
      limEsquerda = largura.isFinite
          ? BoxConstraints.tightFor(
              width: math.max(0, largura - tamDireita.width - espaco),
            )
          : const BoxConstraints();
      tamEsquerda = tamanhoDe(esquerda, limEsquerda);
    }

    // Alinha pela linha de base; sem ela (um widget que não é texto), as
    // duas partes ficam no topo.
    final bEsquerda =
        esquerda == null ? null : baselineDe(esquerda, limEsquerda!);
    final bDireita = direita == null ? null : baselineDe(direita, limDireita!);
    var yEsquerda = 0.0;
    var yDireita = 0.0;
    if (bEsquerda != null && bDireita != null) {
      yEsquerda = math.max(0, bDireita - bEsquerda);
      yDireita = math.max(0, bEsquerda - bDireita);
    }

    final larguraFinal = largura.isFinite
        ? largura
        : tamEsquerda.width + espaco + tamDireita.width;
    final altura = math.max(
      yEsquerda + tamEsquerda.height,
      yDireita + tamDireita.height,
    );
    final tamanho = limites.constrain(Size(larguraFinal, altura));
    return _Medida(
      tamanho: tamanho,
      esquerda: Offset(0, yEsquerda),
      direita: Offset(tamanho.width - tamDireita.width, yDireita),
      baseline: bEsquerda == null ? null : yEsquerda + bEsquerda,
    );
  }

  _Medida _medirSeco(BoxConstraints limites) => _medir(
        limites,
        tamanhoDe: (filho, l) => filho.getDryLayout(l),
        baselineDe: (filho, l) => filho.getDryBaseline(l, _linha),
      );

  @override
  void performLayout() {
    final medida = _medir(
      constraints,
      tamanhoDe: (filho, l) {
        filho.layout(l, parentUsesSize: true);
        return filho.size;
      },
      baselineDe: (filho, _) => filho.getDistanceToBaseline(
        _linha,
        onlyReal: true,
      ),
    );
    size = medida.tamanho;
    if (_esquerda case final e?) {
      (e.parentData! as BoxParentData).offset = medida.esquerda;
    }
    if (_direita case final d?) {
      (d.parentData! as BoxParentData).offset = medida.direita;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _medirSeco(constraints).tamanho;

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) =>
      _medirSeco(constraints).baseline;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final esquerda = _esquerda;
    if (esquerda == null) return null;
    final b = esquerda.getDistanceToActualBaseline(baseline);
    if (b == null) return null;
    return (esquerda.parentData! as BoxParentData).offset.dy + b;
  }

  double _somaLarguras(double Function(RenderBox) larguraDe) {
    final esquerda = _esquerda;
    final direita = _direita;
    final le = esquerda == null ? 0.0 : larguraDe(esquerda);
    final ld = direita == null ? 0.0 : larguraDe(direita);
    final espaco = esquerda != null && direita != null && ld > 0 ? _espaco : 0;
    return le + espaco + ld;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _somaLarguras((f) => f.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _somaLarguras((f) => f.getMaxIntrinsicWidth(height));

  // A altura depende do alinhamento pela linha de base: mede a seco, do
  // mesmo jeito que o layout.
  @override
  double computeMinIntrinsicHeight(double width) =>
      _medirSeco(BoxConstraints(maxWidth: width)).tamanho.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _medirSeco(BoxConstraints(maxWidth: width)).tamanho.height;

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final filho in children) {
      context.paintChild(
        filho,
        offset + (filho.parentData! as BoxParentData).offset,
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final filho in children) {
      final deslocamento = (filho.parentData! as BoxParentData).offset;
      final acertou = result.addWithPaintOffset(
        offset: deslocamento,
        position: position,
        hitTest: (result, transformado) =>
            filho.hitTest(result, position: transformado),
      );
      if (acertou) return true;
    }
    return false;
  }
}
