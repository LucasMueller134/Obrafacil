import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Ilustrações de canteiro desenhadas em código (CustomPainter), no mesmo
/// estilo flat do ícone do app. Sem assets externos: escalam em qualquer
/// resolução e seguem a paleta "Canteiro Premium".
///
/// Cores neutras exclusivas das ilustrações:
const _papel = Color(0xFFE7E5E4);
const _papelSombra = Color(0xFFC8C5C3);
const _pele = Color(0xFFE8B98C);
const _metal = Color(0xFF94A3B8);

Paint _fill(Color cor) => Paint()..color = cor;

// ============================================================ Trabalhador

/// Busto de trabalhador com capacete amarelo e colete refletivo.
class IlustracaoTrabalhador extends StatelessWidget {
  const IlustracaoTrabalhador({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _TrabalhadorPainter(), child: SizedBox.expand());
}

class _TrabalhadorPainter extends CustomPainter {
  const _TrabalhadorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);

    // sombra no chão
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50 * u, 96 * u), width: 52 * u, height: 7 * u),
        _fill(Colors.black.withValues(alpha: 0.25)));

    // colete laranja (busto)
    canvas.drawRRect(
        RRect.fromLTRBAndCorners(30 * u, 64 * u, 70 * u, 95 * u,
            topLeft: Radius.circular(14 * u),
            topRight: Radius.circular(14 * u)),
        _fill(AppColors.laranja));
    // faixas refletivas
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(38 * u, 64 * u, 44 * u, 95 * u),
            Radius.circular(2 * u)),
        _fill(AppColors.amareloCapacete));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(56 * u, 64 * u, 62 * u, 95 * u),
            Radius.circular(2 * u)),
        _fill(AppColors.amareloCapacete));

    // pescoço e rosto
    canvas.drawRect(Rect.fromLTRB(44 * u, 58 * u, 56 * u, 66 * u), _fill(_pele));
    canvas.drawCircle(Offset(50 * u, 46 * u), 14 * u, _fill(_pele));

    // sorriso
    final sorriso = Paint()
      ..color = const Color(0xFF7C4A21)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(50 * u, 49 * u), radius: 6 * u),
        0.4, 2.3, false, sorriso);
    // olhos
    canvas.drawCircle(
        Offset(45 * u, 45 * u), 1.6 * u, _fill(const Color(0xFF44403C)));
    canvas.drawCircle(
        Offset(55 * u, 45 * u), 1.6 * u, _fill(const Color(0xFF44403C)));

    // capacete: cúpula + aba
    final cupula = Path()
      ..moveTo(33 * u, 38 * u)
      ..arcToPoint(Offset(67 * u, 38 * u),
          radius: Radius.circular(17 * u), clockwise: true)
      ..close();
    canvas.drawPath(cupula, _fill(AppColors.amareloCapacete));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(27 * u, 36 * u, 73 * u, 41 * u),
            Radius.circular(2.5 * u)),
        _fill(AppColors.amareloCapacete));
    // friso central do capacete
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(46 * u, 23 * u, 54 * u, 37 * u),
            Radius.circular(3 * u)),
        _fill(const Color(0xFFEAB308)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ========================================================= Saco de cimento

class IlustracaoSacoCimento extends StatelessWidget {
  const IlustracaoSacoCimento({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _SacoPainter(), child: SizedBox.expand());
}

class _SacoPainter extends CustomPainter {
  const _SacoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50 * u, 93 * u), width: 56 * u, height: 7 * u),
        _fill(Colors.black.withValues(alpha: 0.25)));

    // corpo do saco
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(26 * u, 30 * u, 74 * u, 91 * u),
            Radius.circular(6 * u)),
        _fill(_papel));
    // dobra do topo
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(26 * u, 22 * u, 74 * u, 34 * u),
            Radius.circular(4 * u)),
        _fill(_papelSombra));
    // vincos
    final vinco = _fill(Colors.black.withValues(alpha: 0.07));
    canvas.drawRect(Rect.fromLTRB(38 * u, 34 * u, 40 * u, 91 * u), vinco);
    canvas.drawRect(Rect.fromLTRB(60 * u, 34 * u, 62 * u, 91 * u), vinco);

    // faixa laranja com o rótulo
    canvas.drawRect(
        Rect.fromLTRB(26 * u, 50 * u, 74 * u, 66 * u), _fill(AppColors.laranja));
    final rotulo = TextPainter(
      text: TextSpan(
        text: 'CIMENTO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9.5 * u,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2 * u,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rotulo.paint(
        canvas, Offset(50 * u - rotulo.width / 2, 58 * u - rotulo.height / 2));

    // "50kg"
    final peso = TextPainter(
      text: TextSpan(
        text: '50 kg',
        style: TextStyle(
          color: const Color(0xFF78716C),
          fontSize: 7 * u,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    peso.paint(
        canvas, Offset(50 * u - peso.width / 2, 76 * u - peso.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================== Betoneira

/// Betoneira com o tambor girando quando [girando] é true —
/// é o indicador de carregamento oficial do app.
class IlustracaoBetoneira extends StatefulWidget {
  final bool girando;

  const IlustracaoBetoneira({super.key, this.girando = false});

  @override
  State<IlustracaoBetoneira> createState() => _IlustracaoBetoneiraState();
}

class _IlustracaoBetoneiraState extends State<IlustracaoBetoneira>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.girando) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant IlustracaoBetoneira old) {
    super.didUpdateWidget(old);
    if (widget.girando && !_controller.isAnimating) _controller.repeat();
    if (!widget.girando && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _BetoneiraPainter(angulo: _controller.value * 2 * math.pi),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BetoneiraPainter extends CustomPainter {
  final double angulo;

  const _BetoneiraPainter({required this.angulo});

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50 * u, 95 * u), width: 64 * u, height: 6 * u),
        _fill(Colors.black.withValues(alpha: 0.25)));

    // chassi
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(18 * u, 76 * u, 82 * u, 84 * u),
            Radius.circular(3 * u)),
        _fill(AppColors.laranjaEscuro));
    // suporte inclinado até o tambor
    final suporte = Path()
      ..moveTo(44 * u, 80 * u)
      ..lineTo(52 * u, 80 * u)
      ..lineTo(62 * u, 50 * u)
      ..lineTo(55 * u, 48 * u)
      ..close();
    canvas.drawPath(suporte, _fill(AppColors.laranjaEscuro));

    // rodas
    for (final cx in [30.0, 66.0]) {
      canvas.drawCircle(
          Offset(cx * u, 88 * u), 7.5 * u, _fill(const Color(0xFF334155)));
      canvas.drawCircle(Offset(cx * u, 88 * u), 3 * u, _fill(_metal));
    }

    // tambor girando
    canvas.save();
    canvas.translate(58 * u, 44 * u);
    canvas.rotate(angulo);
    canvas.drawCircle(Offset.zero, 23 * u, _fill(_papel));
    canvas.drawCircle(Offset.zero, 23 * u,
        Paint()
          ..color = _papelSombra
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * u);
    // pás internas (3 raios laranja)
    final pa = Paint()
      ..color = AppColors.laranja
      ..strokeWidth = 4 * u
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * 2 * math.pi / 3;
      canvas.drawLine(Offset.zero,
          Offset(16 * u * math.cos(a), 16 * u * math.sin(a)), pa);
    }
    canvas.drawCircle(Offset.zero, 5 * u, _fill(AppColors.laranjaEscuro));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BetoneiraPainter oldDelegate) =>
      oldDelegate.angulo != angulo;
}

// ================================================================ Skyline

/// Silhueta de canteiro: prédios com janelas acesas e um guindaste.
/// Decorativa — usar com Opacity por trás do conteúdo.
class IlustracaoSkyline extends StatelessWidget {
  const IlustracaoSkyline({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _SkylinePainter(), child: SizedBox.expand());
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final predio = _fill(AppColors.superficieAlta);
    final janela = _fill(AppColors.amareloCapacete.withValues(alpha: 0.85));

    // prédios (frações da largura)
    final blocos = [
      (0.02, 0.45), // (x inicial, altura relativa)
      (0.16, 0.75),
      (0.34, 0.55),
      (0.52, 0.9),
      (0.72, 0.6),
      (0.88, 0.4),
    ];
    for (final (x, altura) in blocos) {
      final rect =
          Rect.fromLTRB(x * w, h * (1 - altura), (x + 0.13) * w, h);
      canvas.drawRect(rect, predio);
      // janelas em grade (determinístico)
      const lado = 0.022;
      for (var jx = 0; jx < 3; jx++) {
        for (var jy = 0; jy < 8; jy++) {
          final jxPos = rect.left + (0.02 + jx * 0.037) * w;
          final jyPos = rect.top + (0.12 + jy * 0.14) * h * altura;
          if (jyPos + lado * w > h - 4) continue;
          // acende ~metade das janelas num padrão fixo
          if ((jx + jy * 3 + (x * 100).round()) % 3 == 0) {
            canvas.drawRect(
                Rect.fromLTWH(jxPos, jyPos, lado * w, lado * w), janela);
          }
        }
      }
    }

    // guindaste
    final laranja = _fill(AppColors.laranja);
    final torreX = 0.68 * w;
    canvas.drawRect(
        Rect.fromLTRB(torreX, 0.12 * h, torreX + 0.012 * w, h), laranja);
    // lança
    canvas.drawRect(
        Rect.fromLTRB(0.44 * w, 0.10 * h, torreX + 0.06 * w, 0.13 * h),
        laranja);
    // cabo + bloco içado
    canvas.drawRect(
        Rect.fromLTRB(0.47 * w, 0.13 * h, 0.47 * w + 1.5, 0.42 * h),
        _fill(AppColors.laranja.withValues(alpha: 0.9)));
    canvas.drawRect(
        Rect.fromLTWH(0.45 * w, 0.42 * h, 0.045 * w, 0.06 * h), laranja);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================================================================= Recibo

class IlustracaoRecibo extends StatelessWidget {
  const IlustracaoRecibo({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _ReciboPainter(), child: SizedBox.expand());
}

class _ReciboPainter extends CustomPainter {
  const _ReciboPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50 * u, 93 * u), width: 50 * u, height: 6 * u),
        _fill(Colors.black.withValues(alpha: 0.25)));

    // papel com base serrilhada
    final papel = Path()..moveTo(28 * u, 14 * u);
    papel.lineTo(72 * u, 14 * u);
    papel.lineTo(72 * u, 84 * u);
    var x = 72.0;
    var pico = false;
    while (x > 28) {
      x -= 5.5;
      papel.lineTo(x * u, (pico ? 84 : 89) * u);
      pico = !pico;
    }
    papel.close();
    canvas.drawPath(papel, _fill(_papel));

    // cabeçalho laranja
    canvas.drawRect(
        Rect.fromLTRB(28 * u, 14 * u, 72 * u, 24 * u), _fill(AppColors.laranja));

    // linhas de texto
    final linha = _fill(_papelSombra);
    for (final y in [32.0, 40.0, 48.0, 56.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(34 * u, y * u, 66 * u, (y + 3.4) * u),
              Radius.circular(1.7 * u)),
          linha);
    }
    // total em destaque
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(34 * u, 66 * u, 54 * u, 72 * u),
            Radius.circular(2 * u)),
        _fill(AppColors.laranja));
    canvas.drawCircle(
        Offset(63 * u, 69 * u), 5.5 * u, _fill(AppColors.sucesso));
    final ok = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * u
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(60.5 * u, 69 * u), Offset(62.3 * u, 71 * u), ok);
    canvas.drawLine(
        Offset(62.3 * u, 71 * u), Offset(65.8 * u, 66.7 * u), ok);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================== Prancheta

class IlustracaoPrancheta extends StatelessWidget {
  const IlustracaoPrancheta({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(
      painter: _PranchetaPainter(), child: SizedBox.expand());
}

class _PranchetaPainter extends CustomPainter {
  const _PranchetaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50 * u, 93 * u), width: 52 * u, height: 6 * u),
        _fill(Colors.black.withValues(alpha: 0.25)));

    // prancheta (madeira clara)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(27 * u, 18 * u, 73 * u, 90 * u),
            Radius.circular(5 * u)),
        _fill(const Color(0xFFD9A066)));
    // papel
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(32 * u, 26 * u, 68 * u, 84 * u),
            Radius.circular(3 * u)),
        _fill(_papel));
    // clipe metálico
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(42 * u, 13 * u, 58 * u, 24 * u),
            Radius.circular(3.5 * u)),
        _fill(_metal));

    // itens de checklist: check laranja + linha
    for (final (i, y) in [34.0, 45.0, 56.0, 67.0].indexed) {
      final feito = i < 2;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(36 * u, y * u, 42 * u, (y + 6) * u),
              Radius.circular(1.8 * u)),
          _fill(feito ? AppColors.laranja : _papelSombra));
      if (feito) {
        final ok = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * u
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(37.4 * u, (y + 3) * u),
            Offset(38.8 * u, (y + 4.4) * u), ok);
        canvas.drawLine(Offset(38.8 * u, (y + 4.4) * u),
            Offset(40.8 * u, (y + 1.6) * u), ok);
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(46 * u, (y + 1.5) * u, 64 * u, (y + 4.5) * u),
              Radius.circular(1.5 * u)),
          _fill(_papelSombra));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================== Polaroids

class IlustracaoPolaroids extends StatelessWidget {
  const IlustracaoPolaroids({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(
      painter: _PolaroidsPainter(), child: SizedBox.expand());
}

class _PolaroidsPainter extends CustomPainter {
  const _PolaroidsPainter();

  void _polaroid(Canvas canvas, double u, Offset centro, double anguloGraus,
      Color foto) {
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(anguloGraus * math.pi / 180);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: 42 * u, height: 50 * u),
            Radius.circular(2.5 * u)),
        _fill(_papel));
    // área da foto
    final area = Rect.fromCenter(
        center: Offset(0, -4 * u), width: 34 * u, height: 32 * u);
    canvas.drawRect(area, _fill(foto));
    // sol e prédio dentro da foto
    canvas.drawCircle(Offset(area.left + 8 * u, area.top + 8 * u), 4 * u,
        _fill(AppColors.amareloCapacete));
    canvas.drawRect(
        Rect.fromLTRB(area.left + 16 * u, area.top + 12 * u,
            area.left + 28 * u, area.bottom),
        _fill(AppColors.superficieAlta));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50 * u, 92 * u), width: 60 * u, height: 6 * u),
        _fill(Colors.black.withValues(alpha: 0.25)));

    _polaroid(canvas, u, Offset(41 * u, 52 * u), -9,
        AppColors.laranja.withValues(alpha: 0.85));
    _polaroid(canvas, u, Offset(60 * u, 50 * u), 7, AppColors.info);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================================================================== Loja

class IlustracaoLoja extends StatelessWidget {
  const IlustracaoLoja({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _LojaPainter(), child: SizedBox.expand());
}

class _LojaPainter extends CustomPainter {
  const _LojaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);

    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(50 * u, 92 * u), width: 64 * u, height: 6 * u),
        _fill(Colors.black.withValues(alpha: 0.25)));

    // fachada
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(22 * u, 40 * u, 78 * u, 89 * u),
            Radius.circular(3 * u)),
        _fill(AppColors.superficieAlta));

    // toldo listrado com barrado ondulado
    for (var i = 0; i < 6; i++) {
      final x0 = (17 + i * 11.0) * u;
      canvas.drawRect(Rect.fromLTRB(x0, 30 * u, x0 + 11 * u, 44 * u),
          _fill(i.isEven ? AppColors.laranja : _papel));
      canvas.drawArc(
          Rect.fromLTRB(x0, 39 * u, x0 + 11 * u, 49 * u),
          0, math.pi, false,
          _fill(i.isEven ? AppColors.laranja : _papel));
    }

    // porta
    canvas.drawRRect(
        RRect.fromLTRBAndCorners(43 * u, 60 * u, 57 * u, 89 * u,
            topLeft: Radius.circular(4 * u),
            topRight: Radius.circular(4 * u)),
        _fill(const Color(0xFF334155)));
    canvas.drawCircle(
        Offset(54 * u, 75 * u), 1.5 * u, _fill(AppColors.amareloCapacete));

    // vitrines iluminadas
    for (final x0 in [27.0, 62.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(x0 * u, 58 * u, (x0 + 11) * u, 72 * u),
              Radius.circular(2 * u)),
          _fill(AppColors.amareloCapacete.withValues(alpha: 0.85)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
