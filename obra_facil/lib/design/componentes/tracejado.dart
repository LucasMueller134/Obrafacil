import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// Traço e intervalo do tracejado: a linha "ainda não existe" do desenho.
const double _traco = 6;
const double _intervalo = 4;

/// Desenha [caminho] tracejado (6 de traço, 4 de intervalo) com [tinta]:
/// o mesmo tracejado do botão desabilitado e da maquete.
void pintarTracejado(Canvas canvas, Path caminho, Paint tinta) {
  for (final ui.PathMetric medida in caminho.computeMetrics()) {
    for (var d = 0.0; d < medida.length; d += _traco + _intervalo) {
      canvas.drawPath(medida.extractPath(d, d + _traco), tinta);
    }
  }
}

/// Linha horizontal tracejada, no meio da altura.
class PintorTracejado extends CustomPainter {
  const PintorTracejado(this.cor, {this.espessura = Traco.forte});

  final Color cor;
  final double espessura;

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()
      ..color = cor
      ..strokeWidth = espessura;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _traco + _intervalo) {
      final fim = (x + _traco).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(fim, y), tinta);
    }
  }

  @override
  bool shouldRepaint(PintorTracejado antigo) =>
      antigo.cor != cor || antigo.espessura != espessura;
}

/// Contorno tracejado de um retângulo com cantos [raio]. É o estado
/// desabilitado dos botões e opções: o que ainda não dá para usar aparece
/// tracejado, como o que ainda não foi construído.
class ContornoTracejado extends CustomPainter {
  const ContornoTracejado({
    required this.cor,
    this.raio = Raio.pequeno,
    this.espessura = Traco.fino,
  });

  final Color cor;
  final double raio;
  final double espessura;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final retangulo = (Offset.zero & size).deflate(espessura / 2);
    final contorno = Path()
      ..addRRect(RRect.fromRectAndRadius(retangulo, Radius.circular(raio)));
    pintarTracejado(
      canvas,
      contorno,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = espessura,
    );
  }

  @override
  bool shouldRepaint(ContornoTracejado antigo) =>
      antigo.cor != cor || antigo.raio != raio || antigo.espessura != espessura;
}
