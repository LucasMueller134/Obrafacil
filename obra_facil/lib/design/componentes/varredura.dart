import 'package:flutter/material.dart';

import '../movimento.dart';
import '../tipografia.dart';
import '../tokens.dart';
import 'linha_cota.dart';

/// Uma linha grafite percorre a imagem (a foto da nota) enquanto algo é
/// lido, com a etiqueta do que está acontecendo. A linha tem halo da cor do
/// papel para aparecer sobre partes claras e escuras da foto.
///
/// Com "reduzir animações", a linha fica parada no meio; a etiqueta
/// continua dizendo o que acontece.
class Varredura extends StatefulWidget {
  const Varredura({
    super.key,
    required this.child,
    this.ativa = true,
    this.legenda = 'Lendo a nota',
  });

  final Widget child;
  final bool ativa;

  /// Texto da etiqueta e do leitor de tela.
  final String legenda;

  @override
  State<Varredura> createState() => _VarreduraState();
}

class _VarreduraState extends State<Varredura>
    with SingleTickerProviderStateMixin {
  // Uma ida dura 1,6 s: devagar o bastante para ler como "trabalhando".
  late final AnimationController _controle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizar();
  }

  @override
  void didUpdateWidget(Varredura antigo) {
    super.didUpdateWidget(antigo);
    _sincronizar();
  }

  void _sincronizar() {
    final mover = widget.ativa && !context.reduzirAnimacoes;
    if (mover) {
      if (!_controle.isAnimating) _controle.repeat(reverse: true);
    } else {
      _controle.stop();
      _controle.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Stack(
      children: [
        widget.child,
        if (widget.ativa) ...[
          // A linha anda numa camada só dela: a foto embaixo não é
          // repintada a cada quadro.
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _PintorVarredura(
                    andamento: _controle,
                    linha: c.grafite,
                    halo: c.papel,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: Espaco.e8,
            top: Espaco.e8,
            right: Espaco.e8,
            child: Align(
              alignment: Alignment.topLeft,
              child: Semantics(
                container: true,
                liveRegion: true,
                label: widget.legenda,
                excludeSemantics: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Espaco.e8,
                    vertical: Espaco.e4,
                  ),
                  decoration: BoxDecoration(
                    color: c.papel,
                    border: Border.all(color: c.grafite, width: Traco.fino),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: Espaco.e8),
                            child: Icon(
                              Icons.document_scanner_outlined,
                              size: 18,
                              color: c.grafite,
                            ),
                          ),
                        ),
                        TextSpan(text: widget.legenda.toUpperCase()),
                      ],
                    ),
                    style: Tipografia.rotulo.copyWith(color: c.grafite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PintorVarredura extends CustomPainter {
  _PintorVarredura({
    required this.andamento,
    required this.linha,
    required this.halo,
  }) : super(repaint: andamento);

  /// De 0 (topo) a 1 (base), ida e volta.
  final Animation<double> andamento;
  final Color linha;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * Curves.easeInOut.transform(andamento.value);
    final esquerda = Offset(0, y);
    final direita = Offset(size.width, y);
    canvas.drawLine(
      esquerda,
      direita,
      Paint()
        ..color = halo
        ..strokeWidth = 6,
    );
    canvas.drawLine(
      esquerda,
      direita,
      Paint()
        ..color = linha
        ..strokeWidth = 2.5,
    );
    // Traço oblíquo nas pontas, como uma cota que mede a nota.
    for (final x in [12.0, size.width - 12]) {
      pintarTracoObliquo(canvas, Offset(x, y), halo, tamanho: 18, espessura: 6);
      pintarTracoObliquo(canvas, Offset(x, y), linha,
          tamanho: 16, espessura: 2.5);
    }
  }

  @override
  bool shouldRepaint(_PintorVarredura antigo) =>
      antigo.andamento != andamento ||
      antigo.linha != linha ||
      antigo.halo != halo;
}
