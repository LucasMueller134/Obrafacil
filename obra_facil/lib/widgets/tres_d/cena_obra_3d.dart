import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import 'motor_3d.dart';

/// Cores da maquete — tons de material real, não a paleta de interface.
abstract class _Cores {
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


/// Monta o canteiro. Ordem não importa: o motor ordena por profundidade.
List<Malha> _montarCanteiro() {
  final m = <Malha>[];

  // ---------------------------------------------------------- Terreno
  m.add(Malha.caixa(
    centro: const Vetor3(0, -1.42, 0),
    tamanho: const Vetor3(8.4, 0.44, 7.0),
    cor: const Color(0xFF3E3529), // terra batida
    corTopo: const Color(0xFF4A4032),
    texturaTopo: Textura.concreto,
  ));

  // Radier concretado
  m.add(Malha.caixa(
    centro: const Vetor3(0, -1.08, 0),
    tamanho: const Vetor3(5.0, 0.3, 3.9),
    cor: _Cores.concreto,
    corTopo: _Cores.concretoTopo,
    textura: Textura.concreto,
  ));

  // ---------------------------------------------------------- Alvenaria
  const alturaParede = 1.75;
  const espessura = 0.24;
  const baseParede = -0.93;
  const meioParede = baseParede + alturaParede / 2;

  Malha tijolos(Vetor3 centro, Vetor3 tamanho) => Malha.caixa(
        centro: centro,
        tamanho: tamanho,
        cor: _Cores.tijolo,
        corTopo: _Cores.tijoloTopo,
        textura: Textura.tijolo,
        texturaTopo: Textura.lisa,
      );

  // Parede do fundo com vão de janela: dois montantes e a verga.
  // Abrir o vão é o que faz ler como parede de casa, e não como bloco.
  const zFundo = -1.7;
  m.add(tijolos(const Vetor3(-1.65, meioParede, zFundo),
      const Vetor3(1.7, alturaParede, espessura)));
  m.add(tijolos(const Vetor3(1.65, meioParede, zFundo),
      const Vetor3(1.7, alturaParede, espessura)));
  // Verga sobre o vão
  m.add(tijolos(const Vetor3(0, baseParede + 1.52, zFundo),
      const Vetor3(1.6, 0.46, espessura)));
  // Peitoril
  m.add(Malha.caixa(
    centro: const Vetor3(0, baseParede + 0.32, zFundo),
    tamanho: const Vetor3(1.6, 0.64, espessura),
    cor: _Cores.tijolo,
    corTopo: _Cores.concretoTopo,
    textura: Textura.tijolo,
  ));

  // Parede da esquerda com vão de porta (aberto até o chão).
  const xEsq = -2.38;
  m.add(tijolos(const Vetor3(xEsq, meioParede, -0.95),
      const Vetor3(espessura, alturaParede, 1.5)));
  m.add(tijolos(const Vetor3(xEsq, meioParede, 1.15),
      const Vetor3(espessura, alturaParede, 1.1)));
  m.add(tijolos(const Vetor3(xEsq, baseParede + 1.58, 0.15),
      const Vetor3(espessura, 0.34, 0.9)));

  // Parede da direita subindo em degraus — a obra em andamento.
  for (var i = 0; i < 4; i++) {
    final altura = alturaParede - i * 0.4;
    m.add(tijolos(
      Vetor3(2.38, baseParede + altura / 2, -1.35 + i * 0.9),
      Vetor3(espessura, altura, 0.9),
    ));
  }
  // Tijolos avulsos sendo assentados no topo do último degrau — a fiada
  // interrompida no meio do serviço.
  for (var i = 0; i < 3; i++) {
    m.add(tijolos(
      Vetor3(2.38, baseParede + 0.42, 0.55 + i * 0.34),
      const Vetor3(espessura, 0.14, 0.28),
    ));
  }

  // ------------------------------------------------- Cobertura em obra
  // Madeiramento atravessando o vão.
  for (var i = 0; i < 4; i++) {
    m.add(Malha.caixa(
      centro: Vetor3(0, baseParede + alturaParede + 0.07, -1.35 + i * 0.92),
      tamanho: const Vetor3(5.0, 0.14, 0.16),
      cor: _Cores.madeira,
      textura: Textura.madeira,
    ));
  }
  // Telhado assentado só sobre a metade dos fundos.
  m.add(Malha.telhado(
    centroBase: Vetor3(0, baseParede + alturaParede + 0.14, -1.05),
    largura: 5.2,
    profundidade: 1.9,
    altura: 1.0,
    cor: _Cores.telha,
    corEmpena: const Color(0xFF7E3A26),
    textura: Textura.telha,
  ));

  // ------------------------------------------------------------ Andaime
  const xAndaime = -2.95;
  for (final z in [-1.2, 1.0]) {
    m.add(Malha.caixa(
      centro: Vetor3(xAndaime, -0.22, z),
      tamanho: const Vetor3(0.08, 2.28, 0.08),
      cor: _Cores.aco,
    ));
  }
  for (final y in [-0.82, 0.0, 0.78]) {
    m.add(Malha.caixa(
      centro: Vetor3(xAndaime, y, -0.1),
      tamanho: const Vetor3(0.06, 0.06, 2.2),
      cor: _Cores.aco,
    ));
  }
  m.add(Malha.caixa(
    centro: const Vetor3(xAndaime, 0.06, -0.1),
    tamanho: const Vetor3(0.6, 0.06, 2.1),
    cor: _Cores.madeira,
    textura: Textura.madeira,
  ));

  // ---------------------------------------------------------- Guindaste
  const xg = 3.35, zg = 1.9;
  m.add(Malha.caixa(
    centro: const Vetor3(xg, -1.08, zg),
    tamanho: const Vetor3(0.78, 0.32, 0.78),
    cor: _Cores.aco,
    textura: Textura.concreto,
  ));
  m.add(Malha.caixa(
    centro: const Vetor3(xg, 0.45, zg),
    tamanho: const Vetor3(0.2, 2.85, 0.2),
    cor: _Cores.guindaste,
  ));
  m.add(Malha.caixa(
    centro: const Vetor3(xg - 1.5, 1.8, zg),
    tamanho: const Vetor3(3.1, 0.14, 0.14),
    cor: _Cores.guindaste,
  ));
  m.add(Malha.caixa(
    centro: const Vetor3(xg + 0.66, 1.8, zg),
    tamanho: const Vetor3(0.52, 0.32, 0.28),
    cor: _Cores.aco,
  ));
  m.add(Malha.caixa(
    centro: const Vetor3(xg - 2.3, 1.28, zg),
    tamanho: const Vetor3(0.035, 0.9, 0.035),
    cor: _Cores.aco,
  ));
  m.add(Malha.caixa(
    centro: const Vetor3(xg - 2.3, 0.72, zg),
    tamanho: const Vetor3(0.4, 0.28, 0.4),
    cor: _Cores.capacete,
  ));

  // ------------------------------------------------- Material no canteiro
  // Palete de tijolos, com as fiadas visíveis.
  for (var i = 0; i < 4; i++) {
    m.add(Malha.caixa(
      centro: Vetor3(-2.9, -0.85 + i * 0.17, 2.5),
      tamanho: const Vetor3(1.0, 0.17, 0.72),
      cor: _Cores.tijolo,
      corTopo: _Cores.tijoloTopo,
      textura: Textura.tijolo,
    ));
  }
  // Pilha de areia (tronco de pirâmide achatado).
  m.add(Malha.caixa(
    centro: const Vetor3(0.9, -1.06, 2.6),
    tamanho: const Vetor3(1.5, 0.34, 1.2),
    cor: const Color(0xFFB79A6A),
    corTopo: const Color(0xFFC9AC7C),
    textura: Textura.concreto,
  ));
  // Betoneira.
  m.add(Malha.cilindro(
    centroBase: const Vetor3(-0.9, -0.93, 2.55),
    raio: 0.4,
    altura: 0.6,
    cor: _Cores.concreto,
    corTopo: _Cores.concretoTopo,
    lados: 12,
  ));

  return m;
}

class _PintorCena extends CustomPainter {
  final List<Malha> malhas;
  final Camera3D camera;

  _PintorCena({required this.malhas, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    final faces = camera.renderizar(malhas);
    final sombra = camera.projetarSombra(malhas);
    // A cena é modelada em unidades de ~7 de largura; a escala encaixa
    // isso no espaço disponível, mantendo a proporção.
    final escala = math.min(size.width, size.height * 1.35) / 8.6;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.58);
    canvas.scale(escala);

    _pintarSombra(canvas, sombra);

    for (final face in faces) {
      final caminho = Path()..addPolygon(face.pontos, true);
      // Gradiente entre o vértice mais sombreado e o mais iluminado: a
      // luz varia dentro da própria face, como em superfície real.
      final tinta = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      if (face.inicioLuz == face.fimLuz) {
        tinta.color = face.corClara;
      } else {
        tinta.shader = ui.Gradient.linear(
          face.inicioLuz,
          face.fimLuz,
          [face.corEscura, face.corClara],
        );
      }
      canvas.drawPath(caminho, tinta);
      _pintarTextura(canvas, face, caminho);
    }
    canvas.restore();
  }

  /// Sombra: a silhueta da cena achatada no chão, borrada e sobreposta.
  /// Várias camadas curtas empilhadas dão a borda macia sem custo de
  /// desfoque grande.
  void _pintarSombra(Canvas canvas, SombraProjetada sombra) {
    final tinta = Paint()
      ..color = Colors.black.withValues(alpha: 0.13)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.09);
    for (final silhueta in sombra.silhuetas) {
      canvas.drawPath(Path()..addPolygon(silhueta, true), tinta);
    }
  }

  /// Acabamento por cima da cor: fiada de tijolo, poro de concreto, veio
  /// de madeira, onda de telha. Desenhado dentro do recorte da face, o
  /// que faz a textura acompanhar a perspectiva.
  void _pintarTextura(Canvas canvas, FaceProjetada face, Path caminho) {
    if (face.textura == Textura.lisa || face.pontos.length < 4) return;

    canvas.save();
    canvas.clipPath(caminho);

    final p0 = face.pontos[0];
    final p1 = face.pontos[1];
    final p2 = face.pontos[2];
    final p3 = face.pontos[3];

    switch (face.textura) {
      case Textura.tijolo:
        // Junta horizontal acompanhando as arestas laterais da face.
        _riscar(canvas, p0, p1, p3, p2, 7, 0.014, const Color(0x4A2A1206));
        // Junta vertical, alternada por fiada — meia amarração.
        _riscar(canvas, p0, p3, p1, p2, 5, 0.010, const Color(0x2E2A1206));
      case Textura.concreto:
        _riscar(canvas, p0, p1, p3, p2, 3, 0.010, const Color(0x1AFFFFFF));
      case Textura.madeira:
        _riscar(canvas, p0, p3, p1, p2, 4, 0.008, const Color(0x33452B0F));
      case Textura.telha:
        _riscar(canvas, p0, p3, p1, p2, 10, 0.012, const Color(0x3A3A1206));
      case Textura.lisa:
        break;
    }
    canvas.restore();
  }

  /// Traça [quantidade] linhas paralelas cruzando o quadrilátero, indo do
  /// lado [a]→[b] até o lado [c]→[d]. Interpolar nos dois lados mantém as
  /// linhas em perspectiva junto com a face.
  void _riscar(Canvas canvas, Offset a, Offset b, Offset c, Offset d,
      int quantidade, double espessura, Color cor) {
    final tinta = Paint()
      ..strokeWidth = espessura
      ..color = cor
      ..isAntiAlias = true;
    for (var i = 1; i < quantidade; i++) {
      final t = i / quantidade;
      canvas.drawLine(
        Offset.lerp(a, d, t)!,
        Offset.lerp(b, c, t)!,
        tinta,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorCena velho) =>
      velho.camera.giro != camera.giro ||
      velho.camera.inclinacao != camera.inclinacao;
}
