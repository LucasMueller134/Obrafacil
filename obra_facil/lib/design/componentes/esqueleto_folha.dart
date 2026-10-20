import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../movimento.dart';
import '../tokens.dart';
import 'folha.dart';
import 'hachura.dart';

/// Carregamento com a forma do conteúdo que vai chegar: uma folha com
/// blocos hachurados no lugar do rótulo, do valor e das linhas de texto,
/// como a área "a construir" de uma planta. A hachura desliza devagar;
/// com "reduzir animações", fica parada.
class EsqueletoFolha extends StatefulWidget {
  const EsqueletoFolha({
    super.key,
    this.linhas = 3,
    this.comRotulo = true,
    this.comValor = true,
    this.rotuloSemantico = 'Carregando',
  });

  /// Quantas linhas de texto.
  final int linhas;
  final bool comRotulo;

  /// Bloco alto no lugar do valor-herói.
  final bool comValor;
  final String rotuloSemantico;

  @override
  State<EsqueletoFolha> createState() => _EsqueletoFolhaState();
}

class _EsqueletoFolhaState extends State<EsqueletoFolha>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduzirAnimacoes) {
      _controle.stop();
    } else if (!_controle.isAnimating) {
      _controle.repeat();
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  static const _larguras = [0.92, 0.74, 0.84];

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    Widget bloco(double fracao, double altura) => FractionallySizedBox(
          widthFactor: fracao,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: altura,
            child: CustomPaint(
              painter: _PintorBloco(
                fundo: c.folhaRebaixada,
                hachura: c.grade,
                andamento: _controle,
              ),
            ),
          ),
        );
    return Semantics(
      container: true,
      label: widget.rotuloSemantico,
      excludeSemantics: true,
      child: Folha(
        // A hachura desliza numa camada só dela: a tela em volta não é
        // repintada a cada quadro.
        child: RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.comRotulo) ...[
                bloco(0.32, 13),
                const SizedBox(height: Espaco.e8),
              ],
              if (widget.comValor) ...[
                bloco(0.64, 40),
                const SizedBox(height: Espaco.e16),
              ],
              for (var i = 0; i < widget.linhas; i++) ...[
                if (i > 0) const SizedBox(height: Espaco.e8),
                bloco(_larguras[i % _larguras.length], 17),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorBloco extends CustomPainter {
  _PintorBloco({
    required this.fundo,
    required this.hachura,
    required this.andamento,
  }) : super(repaint: andamento);

  final Color fundo;
  final Color hachura;

  /// De 0 a 1: desloca a hachura um passo inteiro (o ciclo emenda).
  final Animation<double> andamento;

  /// Passo horizontal da hachura padrão (5 dp na perpendicular, a 45°).
  static final double _passo = 5 * math.sqrt2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fundo);
    Hachura(cor: hachura, deslocamento: andamento.value * _passo)
        .paint(canvas, size);
  }

  @override
  bool shouldRepaint(_PintorBloco antigo) =>
      antigo.andamento != andamento ||
      antigo.fundo != fundo ||
      antigo.hachura != hachura;
}
