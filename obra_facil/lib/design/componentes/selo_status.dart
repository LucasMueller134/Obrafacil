import 'package:flutter/material.dart';

import '../tipografia.dart';
import '../tokens.dart';
import 'hachura.dart';

/// Os status que um lançamento ou etapa pode ter.
enum StatusSelo { pendente, aprovado, recusado, aviso }

/// Status com forma, nunca só com cor: hachura (pendente), check
/// (aprovado), x (recusado) ou triângulo sobre amarelo (aviso), sempre
/// com o texto. O texto fica em grafite para ser lido no sol; a cor do
/// status vai no ícone e no contorno.
class SeloStatus extends StatelessWidget {
  const SeloStatus(this.status, {super.key, this.texto});

  final StatusSelo status;

  /// Troca o texto padrão ("Pendente", "Aprovado", "Recusado", "Atenção").
  final String? texto;

  static String textoPadrao(StatusSelo status) => switch (status) {
        StatusSelo.pendente => 'Pendente',
        StatusSelo.aprovado => 'Aprovado',
        StatusSelo.recusado => 'Recusado',
        StatusSelo.aviso => 'Atenção',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final t = texto ?? textoPadrao(status);
    final (Color borda, Color fundo, Color frente, Widget forma) =
        switch (status) {
      StatusSelo.pendente => (
          c.grafite,
          c.folha,
          c.grafite,
          CaixaHachurada(
              largura: 12, altura: 16, cor: c.grafite, espacamento: 3.5),
        ),
      StatusSelo.aprovado => (
          c.ok,
          c.folha,
          c.grafite,
          Icon(Icons.check, size: 20, color: c.ok),
        ),
      StatusSelo.recusado => (
          c.revisao,
          c.folha,
          c.grafite,
          Icon(Icons.close, size: 20, color: c.revisao),
        ),
      StatusSelo.aviso => (
          c.sobreAviso,
          c.aviso,
          c.sobreAviso,
          Icon(Icons.warning_amber, size: 20, color: c.sobreAviso),
        ),
    };
    return Semantics(
      container: true,
      label: 'Status: $t',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(Espaco.e8, 3, Espaco.e12, 3),
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: Raio.cantoPequeno,
          border: Border.all(color: borda, width: Traco.fino),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.only(right: Espaco.e8),
                  child: forma,
                ),
              ),
              TextSpan(text: t),
            ],
          ),
          style: Tipografia.apoio.copyWith(
            color: frente,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
