import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import 'motor_3d.dart';

/// Cores da maquete — tons de material real, não a paleta de interface.
abstract class _Cores {
  static const terreno = Color(0xFF1B2637);
  static const concreto = Color(0xFF8A93A3);
  static const concretoTopo = Color(0xFFA9B2C0);
  static const tijolo = Color(0xFFB4553A);
  static const tijoloTopo = Color(0xFFC9694B);
  static const madeira = Color(0xFFB98A4B);
  static const telha = Color(0xFF9C4A32);
  static const aco = Color(0xFF5C6779);
  static const guindaste = AppColors.laranja;
  static const capacete = AppColors.amareloCapacete;
}

/// Maquete 3D de uma casa em construção — a peça de identidade do app.
///
/// É desenhada quadro a quadro pelo [Camera3D], sem asset e sem
/// dependência externa: gira em qualquer resolução, funciona offline e
/// pesa nada. A cena conta a história do produto: fundação pronta,
/// alvenaria subindo em escada (obra em andamento, não terminada),
/// telhado assentado de um lado, andaime encostado e o guindaste laranja
/// da marca ao lado.
class CenaObraTresD extends StatefulWidget {
  /// Gira sozinha. Desligue em tela parada para não gastar bateria.
  final bool animando;

  /// Segundos para uma volta completa.
  final double segundosPorVolta;

  /// Inclinação da câmera: quanto maior, mais se olha de cima.
  final double inclinacao;

  const CenaObraTresD({
    super.key,
    this.animando = true,
    this.segundosPorVolta = 26,
    this.inclinacao = 0.42,
  });

  @override
  State<CenaObraTresD> createState() => _CenaObraTresDState();
}

class _CenaObraTresDState extends State<CenaObraTresD>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.segundosPorVolta * 1000).round()),
  );

  /// A maquete é construída uma vez: por quadro só muda a câmera.
  late final List<Malha> _maquete = _montarCanteiro();

  @override
  void initState() {
    super.initState();
    if (widget.animando) _controle.repeat();
  }

  @override
  void didUpdateWidget(covariant CenaObraTresD velho) {
    super.didUpdateWidget(velho);
    if (widget.animando && !_controle.isAnimating) {
      _controle.repeat();
    } else if (!widget.animando && _controle.isAnimating) {
      _controle.stop();
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controle,
        builder: (_, __) => CustomPaint(
          painter: _PintorCena(
            malhas: _maquete,
            camera: Camera3D(
              // Começa levemente de lado: o canto lê melhor o volume que
              // a fachada de frente.
              giro: -0.6 + _controle.value * 2 * math.pi,
              inclinacao: widget.inclinacao,
            ),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Monta o canteiro inteiro. Ordem não importa: o motor ordena por
/// profundidade a cada quadro.
List<Malha> _montarCanteiro() {
  final malhas = <Malha>[];

  // Terreno
  malhas.add(Malha.caixa(
    centro: const Vetor3(0, -1.35, 0),
    tamanho: const Vetor3(7.2, 0.3, 6.2),
    cor: _Cores.terreno,
    corTopo: const Color(0xFF243248),
  ));

  // Radier / fundação
  malhas.add(Malha.caixa(
    centro: const Vetor3(0, -1.05, 0),
    tamanho: const Vetor3(4.6, 0.34, 3.6),
    cor: _Cores.concreto,
    corTopo: _Cores.concretoTopo,
  ));

  // Paredes: duas inteiras (fundo e esquerda) e uma subindo em escada,
  // que é o que faz a maquete parecer obra e não casa pronta.
  malhas.add(Malha.caixa(
    centro: const Vetor3(0, -0.05, -1.55),
    tamanho: const Vetor3(4.2, 1.7, 0.25),
    cor: _Cores.tijolo,
    corTopo: _Cores.tijoloTopo,
  ));
  malhas.add(Malha.caixa(
    centro: const Vetor3(-2.0, -0.05, 0),
    tamanho: const Vetor3(0.25, 1.7, 3.2),
    cor: _Cores.tijolo,
    corTopo: _Cores.tijoloTopo,
  ));

  // Parede da direita em três degraus decrescentes (fiadas em andamento).
  for (var i = 0; i < 3; i++) {
    final altura = 1.5 - i * 0.45;
    malhas.add(Malha.caixa(
      centro: Vetor3(2.0, -0.9 + altura / 2, -1.0 + i * 1.0),
      tamanho: Vetor3(0.25, altura, 1.0),
      cor: _Cores.tijolo,
      corTopo: _Cores.tijoloTopo,
    ));
  }

  // Fiada solta de tijolos no topo da parede do fundo — obra viva.
  for (var i = 0; i < 4; i++) {
    malhas.add(Malha.caixa(
      centro: Vetor3(-1.5 + i * 0.62, 0.92, -1.55),
      tamanho: const Vetor3(0.5, 0.16, 0.25),
      cor: _Cores.tijolo,
      corTopo: _Cores.tijoloTopo,
    ));
  }

  // Vigas de madeira do madeiramento, atravessando o vão.
  for (var i = 0; i < 3; i++) {
    malhas.add(Malha.caixa(
      centro: Vetor3(0, 0.86, -1.1 + i * 1.05),
      tamanho: const Vetor3(4.3, 0.12, 0.14),
      cor: _Cores.madeira,
    ));
  }

  // Telhado assentado só na metade dos fundos.
  malhas.add(Malha.telhado(
    centroBase: const Vetor3(0, 0.95, -0.85),
    largura: 4.6,
    profundidade: 1.7,
    altura: 0.95,
    cor: _Cores.telha,
    corEmpena: const Color(0xFF7E3A26),
  ));

  // Andaime encostado na parede da esquerda: montantes e travessas.
  const xAndaime = -2.55;
  for (final z in [-1.1, 0.9]) {
    malhas.add(Malha.caixa(
      centro: Vetor3(xAndaime, -0.15, z),
      tamanho: const Vetor3(0.09, 2.1, 0.09),
      cor: _Cores.aco,
    ));
  }
  for (final y in [-0.75, 0.05, 0.72]) {
    malhas.add(Malha.caixa(
      centro: Vetor3(xAndaime, y, -0.1),
      tamanho: const Vetor3(0.07, 0.07, 2.1),
      cor: _Cores.aco,
    ));
  }
  // Prancha de trabalho
  malhas.add(Malha.caixa(
    centro: const Vetor3(xAndaime, 0.12, -0.1),
    tamanho: const Vetor3(0.55, 0.07, 2.0),
    cor: _Cores.madeira,
  ));

  // Guindaste — a peça laranja da marca, que dá altura à silhueta.
  const xGuindaste = 2.95;
  const zGuindaste = 1.75;
  malhas.add(Malha.caixa(
    centro: const Vetor3(xGuindaste, -1.05, zGuindaste),
    tamanho: const Vetor3(0.7, 0.3, 0.7),
    cor: _Cores.aco,
  ));
  malhas.add(Malha.caixa(
    centro: const Vetor3(xGuindaste, 0.35, zGuindaste),
    tamanho: const Vetor3(0.22, 2.6, 0.22),
    cor: _Cores.guindaste,
  ));
  // Lança
  malhas.add(Malha.caixa(
    centro: const Vetor3(xGuindaste - 1.35, 1.62, zGuindaste),
    tamanho: const Vetor3(2.9, 0.16, 0.16),
    cor: _Cores.guindaste,
  ));
  // Contrapeso
  malhas.add(Malha.caixa(
    centro: const Vetor3(xGuindaste + 0.62, 1.62, zGuindaste),
    tamanho: const Vetor3(0.5, 0.34, 0.3),
    cor: _Cores.aco,
  ));
  // Cabo e carga pendurada
  malhas.add(Malha.caixa(
    centro: const Vetor3(xGuindaste - 2.1, 1.12, zGuindaste),
    tamanho: const Vetor3(0.04, 0.85, 0.04),
    cor: _Cores.aco,
  ));
  malhas.add(Malha.caixa(
    centro: const Vetor3(xGuindaste - 2.1, 0.58, zGuindaste),
    tamanho: const Vetor3(0.42, 0.3, 0.42),
    cor: _Cores.capacete,
  ));

  // Pilha de material e betoneira no canteiro.
  for (var i = 0; i < 3; i++) {
    malhas.add(Malha.caixa(
      centro: Vetor3(-2.55, -0.72 + i * 0.19, 2.15),
      tamanho: const Vetor3(0.95, 0.19, 0.7),
      cor: _Cores.tijolo,
      corTopo: _Cores.tijoloTopo,
    ));
  }
  malhas.add(Malha.cilindro(
    centroBase: const Vetor3(-0.35, -0.85, 2.25),
    raio: 0.42,
    altura: 0.62,
    cor: _Cores.concreto,
    corTopo: _Cores.concretoTopo,
    lados: 10,
  ));

  return malhas;
}

class _PintorCena extends CustomPainter {
  final List<Malha> malhas;
  final Camera3D camera;

  _PintorCena({required this.malhas, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    final faces = camera.renderizar(malhas);
    // A cena é modelada em unidades de ~7 de largura; a escala encaixa
    // isso no espaço disponível, mantendo a proporção.
    final escala = math.min(size.width, size.height * 1.35) / 8.6;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.58);
    canvas.scale(escala);

    // Sombra achatada no chão, para a maquete não flutuar.
    canvas.drawOval(
      Rect.fromCenter(
          center: const Offset(0.1, 1.55), width: 7.4, height: 1.5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.28),
    );

    final preenchimento = Paint()..style = PaintingStyle.fill;
    // A aresta escura separa faces de cor parecida — é o que dá o
    // acabamento de maquete em vez de borrão colorido.
    final aresta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018
      ..color = const Color(0x33000000)
      ..strokeJoin = StrokeJoin.round;

    for (final face in faces) {
      final caminho = Path()..addPolygon(face.pontos, true);
      canvas.drawPath(caminho, preenchimento..color = face.cor);
      canvas.drawPath(caminho, aresta);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PintorCena velho) =>
      velho.camera.giro != camera.giro ||
      velho.camera.inclinacao != camera.inclinacao;
}
