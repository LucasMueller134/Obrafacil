import 'package:flutter/material.dart';

import '../tipografia.dart';
import '../tokens.dart';
import 'folha.dart';

/// Lista vazia (ou fila zerada): ícone de traço, o que aconteceu e, se
/// houver, o que fazer.
class AvisoVazio extends StatelessWidget {
  const AvisoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
    this.acao,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Folha(
      preenchimento: const EdgeInsets.all(Espaco.e24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 36, color: c.grafite),
          const SizedBox(height: Espaco.e12),
          Text(titulo, style: Tipografia.titulo.copyWith(color: c.grafite)),
          const SizedBox(height: Espaco.e4),
          Text(texto, style: Tipografia.corpo.copyWith(color: c.grafite2)),
          if (acao != null) ...[
            const SizedBox(height: Espaco.e24),
            acao!,
          ],
        ],
      ),
    );
  }
}
