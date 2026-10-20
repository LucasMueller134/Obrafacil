import 'package:flutter/material.dart';

import '../tipografia.dart';
import '../tokens.dart';

/// Rótulo de campo e de carimbo: Archivo 13/700 em caixa alta. O leitor de
/// tela recebe o texto original (caixa alta é lida letra por letra em
/// alguns leitores).
class Rotulo extends StatelessWidget {
  const Rotulo(
    this.texto, {
    super.key,
    this.cor,
    this.maxLinhas = 1,
    this.alinhamento,
  });

  final String texto;

  /// Padrão: `grafite2` (8:1 na folha). Não use cor abaixo de 7:1.
  final Color? cor;
  final int maxLinhas;
  final TextAlign? alinhamento;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: Tipografia.rotulo.copyWith(color: cor ?? context.cores.grafite2),
      maxLines: maxLinhas,
      overflow: TextOverflow.ellipsis,
      textAlign: alinhamento,
      semanticsLabel: texto,
    );
  }
}
