import 'package:flutter/material.dart';

import '../tokens.dart';

/// Superfície da prancheta: folha branca com borda de 1,5 dp e raio 4,
/// sem sombra. A variante [destaque] tem borda grafite de 2 dp.
class Folha extends StatelessWidget {
  const Folha({
    super.key,
    required this.child,
    this.destaque = false,
    this.preenchimento = const EdgeInsets.all(Espaco.e16),
    this.margem,
    this.cor,
  });

  final Widget child;

  /// Borda grafite de 2 dp: a folha que pede atenção na tela.
  final bool destaque;

  final EdgeInsetsGeometry preenchimento;
  final EdgeInsetsGeometry? margem;

  /// Troca o fundo (padrão: `folha`).
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Container(
      margin: margem,
      padding: preenchimento,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cor ?? c.folha,
        borderRadius: Raio.cantoPadrao,
        border: Border.all(
          color: destaque ? c.grafite : c.traco,
          width: destaque ? Traco.forte : Traco.fino,
        ),
      ),
      child: child,
    );
  }
}
