import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// Linhas diagonais (/) de desenho técnico: marcam o que está pendente ou
/// ainda não existe. Recorta no próprio retângulo.
class Hachura extends CustomPainter {
  const Hachura({
    required this.cor,
    this.espacamento = 5,
    this.espessura = Traco.fino,
    this.deslocamento = 0,
  });

  final Color cor;

  /// Distância entre as linhas, medida na perpendicular.
  final double espacamento;
  final double espessura;

  /// Desloca as linhas na horizontal (para animar).
  final double deslocamento;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final passo = espacamento * math.sqrt2;
    final tinta = Paint()
      ..color = cor
      ..strokeWidth = espessura;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final inicio = -size.height - passo + (deslocamento % passo);
    for (var x = inicio; x < size.width + passo; x += passo) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        tinta,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(Hachura antigo) =>
      antigo.cor != cor ||
      antigo.espacamento != espacamento ||
      antigo.espessura != espessura ||
      antigo.deslocamento != deslocamento;
}

/// Caixa com hachura e contorno: a amostra de "pendente" ao lado de um
/// título, ou uma área inteira que ainda falta.
class CaixaHachurada extends StatelessWidget {
  const CaixaHachurada({
    super.key,
    this.largura,
    this.altura,
    this.cor,
    this.contorno = true,
    this.espacamento = 5,
    this.child,
  });

  final double? largura;
  final double? altura;

  /// Cor das linhas e do contorno (padrão: `grafite`).
  final Color? cor;
  final bool contorno;
  final double espacamento;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tinta = cor ?? context.cores.grafite;
    return Container(
      width: largura,
      height: altura,
      decoration: contorno
          ? BoxDecoration(border: Border.all(color: tinta, width: Traco.fino))
          : null,
      child: CustomPaint(
        painter: Hachura(cor: tinta, espacamento: espacamento),
        child: child,
      ),
    );
  }
}
