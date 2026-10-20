import 'package:flutter/material.dart';

import '../design/design.dart';

/// Célula de indicador na linguagem da prancheta (ex.: "Aprovados 16"):
/// rótulo em caixa alta, o número com algarismos tabulares e, opcional, o
/// valor em R$ embaixo. Numa `Folha` (contorno no traço), sem cor de status.
class CartaoResumo extends StatelessWidget {
  final String rotulo;
  final String valor;

  /// Linha de apoio sob o valor (ex.: "R$ 4.912,40").
  final String? apoio;

  /// Forma antes do rótulo (ex.: o check do aprovado, a hachura do
  /// pendente), as mesmas do `SeloStatus`.
  final Widget? simbolo;

  const CartaoResumo({
    super.key,
    required this.rotulo,
    required this.valor,
    this.apoio,
    this.simbolo,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    // A folha do design system (borda no traço, raio 4), não uma caixa
    // desenhada aqui.
    return MergeSemantics(
      child: Folha(
        preenchimento: const EdgeInsets.fromLTRB(
          Espaco.e12,
          Espaco.e8,
          Espaco.e12,
          Espaco.e12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (simbolo != null) ...[
                  simbolo!,
                  const SizedBox(width: Espaco.e8),
                ],
                Expanded(child: Rotulo(rotulo)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              valor,
              style: Tipografia.subtitulo.copyWith(color: c.grafite),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (apoio != null)
              Text(
                apoio!,
                style: Tipografia.apoio.copyWith(color: c.grafite2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
