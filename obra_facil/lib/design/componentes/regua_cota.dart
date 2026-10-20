import 'package:flutter/material.dart';

import '../movimento.dart';
import '../tipografia.dart';
import '../tokens.dart';
import 'linha_cota.dart';

/// Barra de avanço desenhada como linha de cota: trilho recuado, o
/// preenchimento grafite até o [valor], traço oblíquo e linha de chamada
/// nas pontas e, opcional, um marcador laranja com legenda (ex.: o avanço
/// da obra contra o orçamento gasto).
///
/// Ao aparecer, a régua se traça da esquerda até o valor; ao mudar, vai do
/// valor antigo ao novo. Com "reduzir animações", aparece pronta.
class ReguaCota extends StatelessWidget {
  const ReguaCota({
    super.key,
    required this.valor,
    this.marcador,
    this.legenda,
    this.rotuloSemantico,
  });

  /// Fração preenchida, de 0 a 1. Acima de 1 a régua fica cheia; um
  /// valor inválido (divisão por orçamento zero) conta como 0.
  final double valor;

  /// Posição do marcador laranja, de 0 a 1.
  final double? marcador;

  /// Legenda do marcador, em preto sobre o marca-texto laranja.
  final String? legenda;

  /// O que a régua mede, para o leitor de tela (ex.: "Orçamento usado").
  final String? rotuloSemantico;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final duracao = context.duracao(Movimento.lento);
    double finito(double v) => v.isFinite ? v : 0;
    final alvo = finito(valor).clamp(0.0, 1.0);
    final alvoMarcador =
        marcador == null ? null : finito(marcador!).clamp(0.0, 1.0);
    final porcento = '${(finito(valor) * 100).round()}%';
    // 15 sp: em 13 sp o preto no laranja (6,7:1) não chega ao 7:1 que a
    // regra pede para texto pequeno.
    final estilo = Tipografia.apoio.copyWith(
      color: c.sobreMarca,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
    // A faixa da etiqueta tem altura fixa (medida uma vez, não a cada
    // quadro da animação).
    var alturaEtiqueta = 0.0;
    if (legenda != null && alvoMarcador != null) {
      final medida = TextPainter(
        text: TextSpan(text: legenda, style: estilo),
        textDirection: TextDirection.ltr,
        textScaler:
            MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      alturaEtiqueta = (medida.height + 2 * _vertical).ceilToDouble();
      medida.dispose();
    }
    return Semantics(
      container: true,
      label: rotuloSemantico,
      value: legenda == null ? porcento : '$porcento; $legenda',
      excludeSemantics: true,
      // O traçado anima por 360 ms: numa camada própria, para não
      // repintar a tela em volta a cada quadro.
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: alvo),
          duration: duracao,
          curve: Movimento.entrar,
          builder: (context, preenchido, _) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: alvoMarcador ?? 0),
            duration: duracao,
            curve: Movimento.entrar,
            builder: (context, posicao, _) => _desenho(
              c,
              estilo,
              alturaEtiqueta,
              preenchido,
              alvoMarcador == null ? null : posicao,
            ),
          ),
        ),
      ),
    );
  }

  Widget _desenho(
    CoresObra c,
    TextStyle estilo,
    double alturaEtiqueta,
    double preenchido,
    double? posicao,
  ) {
    final comLegenda = legenda != null && posicao != null;
    final pintura = CustomPaint(
      size: const Size(double.infinity, PintorReguaCota.altura),
      painter: PintorReguaCota(
        preenchimento: preenchido,
        marcador: posicao,
        cores: c,
        marcadorDesdeOTopo: comLegenda,
      ),
    );
    if (!comLegenda) return pintura;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A etiqueta é uma bandeirinha presa ao marcador, que sobe pela
        // borda dela. A posição é calculada no layout (sem LayoutBuilder,
        // para a régua funcionar também dentro de diálogo), numa faixa de
        // altura fixa: mover a etiqueta a cada quadro não remonta a tela.
        SizedBox(
          height: alturaEtiqueta,
          child: CustomPaint(
            foregroundPainter:
                _PintorHaste(posicao: posicao, cor: c.marcaTexto),
            child: CustomSingleChildLayout(
              delegate: _PosicaoEtiqueta(posicao),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Espaco.e8 + _haste / 2,
                  vertical: _vertical,
                ),
                color: c.marca,
                child: Text(
                  legenda!,
                  style: estilo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
        pintura,
      ],
    );
  }
}

/// Espessura do marcador (a haste da bandeirinha).
const double _haste = 3;
const double _vertical = 2;

/// Põe a etiqueta à esquerda do marcador, encostada nele; se não couber,
/// à direita.
class _PosicaoEtiqueta extends SingleChildLayoutDelegate {
  const _PosicaoEtiqueta(this.posicao);

  final double posicao;

  double _x(double largura) => PintorReguaCota.xDoMarcador(largura, posicao);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final x = _x(constraints.maxWidth);
    final ladoMaior = x >= constraints.maxWidth - x
        ? x + _haste / 2
        : constraints.maxWidth - x + _haste / 2;
    return BoxConstraints(
      maxWidth: ladoMaior.clamp(0.0, constraints.maxWidth),
      minHeight: constraints.maxHeight,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = _x(size.width);
    final esquerda = x + _haste / 2;
    final direita = size.width - x + _haste / 2;
    final aEsquerda = childSize.width <= esquerda || esquerda >= direita;
    final dx = aEsquerda ? esquerda - childSize.width : x - _haste / 2;
    return Offset(dx.clamp(0.0, size.width - childSize.width), 0);
  }

  @override
  bool shouldRelayout(_PosicaoEtiqueta antigo) => antigo.posicao != posicao;
}

/// A haste da bandeirinha: o marcador continuando pela faixa da etiqueta.
class _PintorHaste extends CustomPainter {
  const _PintorHaste({required this.posicao, required this.cor});

  final double posicao;
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final x = PintorReguaCota.xDoMarcador(size.width, posicao);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = cor
        ..strokeWidth = _haste,
    );
  }

  @override
  bool shouldRepaint(_PintorHaste antigo) =>
      antigo.posicao != posicao || antigo.cor != cor;
}

/// Pintura da [ReguaCota]. Pública para quem quiser a régua num gráfico
/// próprio (e para os testes lerem o quanto já foi traçado).
class PintorReguaCota extends CustomPainter {
  const PintorReguaCota({
    required this.preenchimento,
    required this.cores,
    this.marcador,
    this.marcadorDesdeOTopo = false,
  });

  /// Altura da área pintada.
  static const double altura = 30;

  /// Recuo horizontal, para o traço oblíquo caber.
  static const double recuo = 8;

  static const double _alturaBarra = 12;
  static const double _topoBarra = (altura - _alturaBarra) / 2;

  /// Posição x do marcador numa régua desta [largura].
  static double xDoMarcador(double largura, double fracao) =>
      recuo + (largura - 2 * recuo) * fracao.clamp(0.0, 1.0);

  final double preenchimento;
  final double? marcador;
  final CoresObra cores;

  /// O marcador começa no topo da área (encostado na etiqueta).
  final bool marcadorDesdeOTopo;

  @override
  void paint(Canvas canvas, Size size) {
    final x0 = recuo;
    final x1 = size.width - recuo;
    const topo = _topoBarra;
    const base = _topoBarra + _alturaBarra;
    const meio = (topo + base) / 2;
    final barra = Rect.fromLTRB(x0, topo, x1, base);

    // Trilho recuado, preenchimento grafite e o contorno da barra.
    canvas.drawRect(barra, Paint()..color = cores.folhaRebaixada);
    final p = preenchimento.clamp(0.0, 1.0);
    final feito = Rect.fromLTRB(x0, topo, x0 + (x1 - x0) * p, base);
    if (p > 0) canvas.drawRect(feito, Paint()..color = cores.grafite);
    canvas.drawRect(
      barra.deflate(Traco.fino / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Traco.fino
        ..color = cores.grafite,
    );

    // Linhas de chamada e traço oblíquo nas pontas. Onde o oblíquo passa
    // sobre o preenchimento grafite, ele inverte de cor (papel sobre
    // grafite), como a linha que cruza uma área cheia num desenho: um
    // traço só, contínuo, que não some no preto nem vira "//".
    final chamada = Paint()
      ..color = cores.grafite
      ..strokeWidth = Traco.fino;
    for (final x in [x0, x1]) {
      canvas.drawLine(Offset(x, topo - 6), Offset(x, base + 6), chamada);
      final centro = Offset(x, meio);
      pintarTracoObliquo(canvas, centro, cores.grafite, tamanho: 16);
      if (p > 0) {
        canvas
          ..save()
          ..clipRect(feito);
        pintarTracoObliquo(canvas, centro, cores.sobreGrafite, tamanho: 16);
        canvas.restore();
      }
    }

    final m = marcador;
    if (m != null) {
      final xm = xDoMarcador(size.width, m);
      final inicio = marcadorDesdeOTopo ? 0.0 : topo - 6;
      final linha = (Offset(xm, inicio), Offset(xm, base + 6));
      // O laranja já se separa do grafite no claro (3,3:1); no escuro o
      // preenchimento é claro e o marcador ganha, só sobre ele, um respiro
      // da cor do papel.
      if (p > 0 && CoresObra.contraste(cores.marcaTexto, cores.grafite) < 3) {
        canvas
          ..save()
          ..clipRect(feito);
        canvas.drawLine(
          linha.$1,
          linha.$2,
          Paint()
            ..color = cores.papel
            ..strokeWidth = 5,
        );
        canvas.restore();
      }
      canvas.drawLine(
        linha.$1,
        linha.$2,
        Paint()
          ..color = cores.marcaTexto
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(PintorReguaCota antigo) =>
      antigo.preenchimento != preenchimento ||
      antigo.marcador != marcador ||
      antigo.cores != cores ||
      antigo.marcadorDesdeOTopo != marcadorDesdeOTopo;
}
