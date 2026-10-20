import 'package:flutter/material.dart';

import '../tipografia.dart';
import '../tokens.dart';
import 'rotulo.dart';

/// Quadro de título da prancha: linhas de células com rótulo + valor,
/// separadas por traço. Contorno grafite, separadores na cor do traço e
/// cantos retos, como o carimbo desenhado no canto da folha.
///
/// ```dart
/// Carimbo(linhas: [
///   [CelulaCarimbo(rotulo: 'Obra', valor: 'Sobrado Vila Izabel', destaque: true)],
///   [CelulaCarimbo(rotulo: 'Fase', valor: 'Alvenaria'),
///    CelulaCarimbo(rotulo: 'Semana', valor: '14 de 32')],
/// ])
/// ```
class Carimbo extends StatelessWidget {
  const Carimbo({super.key, required this.linhas});

  /// Cada linha divide a largura entre as células pelo `flex` delas.
  final List<List<CelulaCarimbo>> linhas;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final separador = BorderSide(color: c.traco, width: Traco.fino);
    return Container(
      decoration: BoxDecoration(
        color: c.folha,
        border: Border.all(color: c.grafite, width: Traco.fino),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < linhas.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: separador),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < linhas[i].length; j++)
                      Expanded(
                        flex: linhas[i][j].flex,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: j == 0 ? null : Border(left: separador),
                          ),
                          child: linhas[i][j],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Uma célula do [Carimbo]: rótulo em caixa alta e o valor embaixo.
class CelulaCarimbo extends StatelessWidget {
  const CelulaCarimbo({
    super.key,
    required this.rotulo,
    this.valor = '',
    this.destaque = false,
    this.flex = 1,
    this.conteudo,
  });

  final String rotulo;
  final String valor;

  /// Valor no tamanho de título de tela (o nome da obra).
  final bool destaque;

  /// Proporção da largura na linha.
  final int flex;

  /// Troca o texto do valor por outro widget.
  final Widget? conteudo;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final estilo = destaque ? Tipografia.tituloTela : Tipografia.subtitulo;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaco.e12,
          Espaco.e8,
          Espaco.e12,
          Espaco.e12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Rotulo(rotulo),
            const SizedBox(height: 2),
            conteudo ??
                Text(
                  valor,
                  style: estilo.copyWith(color: c.grafite),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          ],
        ),
      ),
    );
  }
}
