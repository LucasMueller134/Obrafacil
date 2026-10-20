import 'package:flutter/material.dart';

import '../movimento.dart';
import '../tipografia.dart';
import '../tokens.dart';
import 'area_pressionavel.dart';
import 'par_com_valor.dart';

/// Linha de lista com 72 dp ou mais: ícone de traço (sem quadradinho
/// colorido atrás), título e, na mesma linha de base, o valor à direita;
/// embaixo, o apoio e o [fim] (ex.: um `SeloStatus`) sob o valor. O título
/// quebra no máximo em 2 linhas; o apoio vai até o selo, não só até a
/// coluna do valor, e numa tela de 360 dp cabe numa linha. O valor vai na
/// Archivo, a letra dos números da prancheta, com algarismos tabulares:
/// uma coluna de valores alinha pela direita.
///
/// Não usa `LayoutBuilder`: funciona dentro de diálogo e de menu.
///
/// Tocável quando tem [aoTocar]: pressionada, o fundo fica recuado (cor
/// sólida) e aparece a seta.
class LinhaLista extends StatelessWidget {
  const LinhaLista({
    super.key,
    required this.titulo,
    this.apoio,
    this.valor,
    this.icone,
    this.inicio,
    this.fim,
    this.aoTocar,
    this.seta,
    this.divisoria = false,
    this.margemHorizontal = Espaco.margem,
    this.rotuloSemantico,
    this.vibrar = false,
  });

  final String titulo;

  /// Segunda linha, em texto secundário.
  final String? apoio;

  /// Valor à direita (ex.: "R$ 2.380,00").
  final String? valor;
  final IconData? icone;

  /// Troca o ícone por outro widget (ex.: `CaixaHachurada`).
  final Widget? inicio;

  /// Embaixo do valor, à direita (ex.: `SeloStatus`).
  final Widget? fim;

  /// Nulo: só leitura.
  final VoidCallback? aoTocar;

  /// Seta de navegação; padrão: aparece quando é tocável.
  final bool? seta;

  /// Traço de grade embaixo.
  final bool divisoria;

  /// Recuo do conteúdo nas laterais (16 na tela; 12 dentro de uma folha).
  final double margemHorizontal;

  /// Substitui o texto lido pelo leitor de tela.
  final String? rotuloSemantico;

  /// Vibração leve ao tocar.
  final bool vibrar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final mostrarSeta = seta ?? aoTocar != null;

    Widget corpo(bool pressionado) {
      final temSegunda = apoio != null || fim != null;
      return AnimatedContainer(
        duration: context.duracao(Movimento.rapido),
        constraints: const BoxConstraints(minHeight: Alvo.principal),
        padding: EdgeInsets.symmetric(
          horizontal: margemHorizontal,
          vertical: Espaco.e12,
        ),
        decoration: BoxDecoration(
          color: pressionado ? c.folhaRebaixada : const Color(0x00000000),
          border: divisoria
              ? Border(bottom: BorderSide(color: c.grade, width: Traco.fino))
              : null,
        ),
        child: Row(
          children: [
            if (inicio != null || icone != null)
              Padding(
                padding: const EdgeInsets.only(right: Espaco.e12),
                child: inicio ?? Icon(icone, size: 24, color: c.grafite),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primeira linha: título e valor na mesma linha de base,
                  // como na fila da prancha. O valor fica com no máximo
                  // metade e, se não couber (fonte muito grande), encolhe,
                  // mas nunca perde dígito.
                  ParComValor(
                    fracaoMaxima: 0.5,
                    esquerda: Text(
                      titulo,
                      style: Tipografia.corpoForte.copyWith(color: c.grafite),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    direita: valor == null
                        ? null
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              valor!,
                              style: Tipografia.subtitulo
                                  .copyWith(color: c.grafite),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                  ),
                  // Segunda linha: o apoio vai até o selo (ou até a borda),
                  // não só até a coluna do valor.
                  if (temSegunda)
                    Padding(
                      padding: const EdgeInsets.only(top: Espaco.e4),
                      // O selo de status nunca é cortado: pode ir até 60%.
                      child: ParComValor(
                        fracaoMaxima: 0.6,
                        esquerda: apoio == null
                            ? const SizedBox.shrink()
                            : Text(
                                apoio!,
                                style: Tipografia.apoio
                                    .copyWith(color: c.grafite2),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        direita: fim,
                      ),
                    ),
                ],
              ),
            ),
            if (mostrarSeta)
              Padding(
                padding: const EdgeInsets.only(left: Espaco.e4),
                child: Icon(Icons.chevron_right, size: 24, color: c.traco),
              ),
          ],
        ),
      );
    }

    if (aoTocar == null) {
      return MergeSemantics(child: corpo(false));
    }
    return AreaPressionavel(
      aoTocar: aoTocar,
      escala: 1,
      vibrar: vibrar,
      rotuloSemantico: rotuloSemantico,
      construtor: (context, e) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: e.focado
            ? BoxDecoration(
                border: Border.all(color: c.marcaTexto, width: 3),
              )
            : const BoxDecoration(),
        child: corpo(e.pressionado),
      ),
    );
  }
}
