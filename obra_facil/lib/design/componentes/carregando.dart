import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../movimento.dart';
import '../tokens.dart';

/// Indicador de carregamento do tamanho de um ícone: um arco de 3/4 que
/// gira sem mudar de tamanho (o do Material encolhe até virar um ponto e,
/// parado numa foto ou no sol, parece sujeira). Com "reduzir animações",
/// uma ampulheta parada.
///
/// Vai dentro de botões e linhas; para uma tela inteira carregando, use
/// `EsqueletoFolha`.
class IndicadorCarregando extends StatefulWidget {
  const IndicadorCarregando({super.key, this.cor, this.tamanho = 22});

  /// Padrão: a cor do ícone do contexto (ou o grafite).
  final Color? cor;
  final double tamanho;

  @override
  State<IndicadorCarregando> createState() => _IndicadorCarregandoState();
}

class _IndicadorCarregandoState extends State<IndicadorCarregando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduzirAnimacoes) {
      _giro.stop();
    } else if (!_giro.isAnimating) {
      _giro.repeat();
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor =
        widget.cor ?? IconTheme.of(context).color ?? context.cores.grafite;
    if (context.reduzirAnimacoes) {
      return Icon(Icons.hourglass_top, size: widget.tamanho, color: cor);
    }
    // O giro só repinta o próprio arco (camada separada): nada de
    // reconstruir widgets nem repintar o botão ou a tela a cada quadro.
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.tamanho,
        child: CustomPaint(painter: _PintorArco(cor, giro: _giro)),
      ),
    );
  }
}

class _PintorArco extends CustomPainter {
  _PintorArco(this.cor, {required this.giro}) : super(repaint: giro);

  final Color cor;
  final Animation<double> giro;

  @override
  void paint(Canvas canvas, Size size) {
    const espessura = 2.5;
    final centro = size.center(Offset.zero);
    canvas
      ..save()
      ..translate(centro.dx, centro.dy)
      ..rotate(giro.value * 2 * math.pi)
      ..translate(-centro.dx, -centro.dy);
    final caixa = (Offset.zero & size).deflate(espessura / 2 + 1);
    canvas.drawArc(
      caixa,
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = espessura,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorArco antigo) =>
      antigo.cor != cor || antigo.giro != giro;
}
