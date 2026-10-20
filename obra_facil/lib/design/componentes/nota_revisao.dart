import 'package:flutter/material.dart';

import '../tipografia.dart';
import '../tokens.dart';

/// Cor da [NotaRevisao].
enum TipoNota {
  /// Vermelho de revisão: erro, alerta de orçamento.
  revisao,

  /// Laranja: destaque, novidade.
  marca,
}

/// Anotação de revisão, como a caneta vermelha na prancha: texto em negrito
/// dentro de uma pílula de contorno. Não é tocável.
class NotaRevisao extends StatelessWidget {
  const NotaRevisao(
    this.texto, {
    super.key,
    this.tipo = TipoNota.revisao,
    this.icone,
  });

  final String texto;
  final TipoNota tipo;

  /// Ícone de traço antes do texto (opcional).
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final cor = tipo == TipoNota.revisao ? c.revisao : c.marcaTexto;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.e12,
        vertical: Espaco.e4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Raio.pilula),
        border: Border.all(color: cor, width: Traco.fino),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (icone != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: Espaco.e8),
                  child: Icon(icone, size: 18, color: cor),
                ),
              ),
            TextSpan(text: texto),
          ],
        ),
        style: Tipografia.apoio.copyWith(
          color: cor,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}
