import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../movimento.dart';
import '../tipografia.dart';
import '../tokens.dart';
import 'area_pressionavel.dart';
import 'rotulo.dart';
import 'tracejado.dart';

/// Uma opção do [SeletorGrande].
@immutable
class OpcaoSeletor<T> {
  const OpcaoSeletor({required this.valor, required this.rotulo, this.icone});

  final T valor;
  final String rotulo;
  final IconData? icone;
}

/// Escolha entre 2 a 4 opções em botões de 56 dp, todas à vista: troca o
/// dropdown (ex.: a categoria do gasto). A opção escolhida fica grafite e
/// ganha um check, então a seleção não depende só da cor. Com 4 opções (ou
/// pouca largura), vira uma grade de 2 colunas. Funciona também dentro de
/// diálogos e folhas.
class SeletorGrande<T> extends StatelessWidget {
  const SeletorGrande({
    super.key,
    required this.opcoes,
    required this.selecionado,
    required this.aoMudar,
    this.rotulo,
  });

  final List<OpcaoSeletor<T>> opcoes;

  /// Valor escolhido; nulo: nenhum ainda.
  final T? selecionado;

  /// Nulo: desabilitado.
  final ValueChanged<T>? aoMudar;

  /// Rótulo em caixa alta acima das opções.
  final String? rotulo;

  @override
  Widget build(BuildContext context) {
    assert(
      opcoes.length >= 2 && opcoes.length <= 4,
      'SeletorGrande aceita de 2 a 4 opções; para mais, use uma lista.',
    );
    // Largura mínima confortável de uma opção, crescendo com a fonte (a
    // escala do sistema não é linear: mede no tamanho do texto da opção).
    final tamanhoTexto = Tipografia.corpoForte.fontSize!;
    final escalaTexto =
        MediaQuery.textScalerOf(context).scale(tamanhoTexto) / tamanhoTexto;
    return Semantics(
      container: true,
      label: rotulo,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rotulo != null) ...[
            ExcludeSemantics(child: Rotulo(rotulo!)),
            const SizedBox(height: Espaco.e8),
          ],
          _Grade(
            colunasPreferidas: opcoes.length == 4 ? 2 : opcoes.length,
            larguraMinima: 96 * escalaTexto,
            children: [
              for (final opcao in opcoes)
                _Opcao<T>(
                  opcao: opcao,
                  selecionada: opcao.valor == selecionado,
                  aoMudar: aoMudar,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grade de opções de larguras iguais, todas da altura da mais alta da
/// linha. Decide o número de colunas pela largura que recebe: um layout
/// próprio, sem `LayoutBuilder`, para funcionar também dentro de diálogos
/// (que medem o conteúdo antes de montar).
class _Grade extends MultiChildRenderObjectWidget {
  const _Grade({
    required this.colunasPreferidas,
    required this.larguraMinima,
    required super.children,
  });

  final int colunasPreferidas;
  final double larguraMinima;

  @override
  _RenderGrade createRenderObject(BuildContext context) => _RenderGrade(
        colunasPreferidas: colunasPreferidas,
        larguraMinima: larguraMinima,
      );

  @override
  void updateRenderObject(BuildContext context, _RenderGrade renderObject) {
    renderObject
      ..colunasPreferidas = colunasPreferidas
      ..larguraMinima = larguraMinima;
  }
}

class _DadosGrade extends ContainerBoxParentData<RenderBox> {}

class _RenderGrade extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _DadosGrade>,
        RenderBoxContainerDefaultsMixin<RenderBox, _DadosGrade> {
  _RenderGrade({required int colunasPreferidas, required double larguraMinima})
      : _colunasPreferidas = colunasPreferidas,
        _larguraMinima = larguraMinima;

  static const double _espaco = Espaco.entreAlvos;

  int _colunasPreferidas;
  set colunasPreferidas(int v) {
    if (v == _colunasPreferidas) return;
    _colunasPreferidas = v;
    markNeedsLayout();
  }

  double _larguraMinima;
  set larguraMinima(double v) {
    if (v == _larguraMinima) return;
    _larguraMinima = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DadosGrade) child.parentData = _DadosGrade();
  }

  List<RenderBox> get _filhos {
    final lista = <RenderBox>[];
    var filho = firstChild;
    while (filho != null) {
      lista.add(filho);
      filho = childAfter(filho);
    }
    return lista;
  }

  double _larguraPor(double largura, int colunas) =>
      (largura - (colunas - 1) * _espaco) / colunas;

  /// Quantas colunas cabem: as preferidas; se cada opção ficar estreita
  /// demais, 2; e, se nem assim, 1. Estreita demais é menos que a largura
  /// mínima ou menos que a palavra mais longa do rótulo: com a fonte
  /// grande, "Equipamento" não pode quebrar no meio da palavra.
  int _colunas(double largura, List<RenderBox> filhos) {
    var colunas = math.max(1, math.min(_colunasPreferidas, filhos.length));
    if (!largura.isFinite) return colunas;
    final palavraMaisLonga = filhos
        .map((f) => f.getMinIntrinsicWidth(double.infinity))
        .reduce(math.max);
    final necessaria = math.max(_larguraMinima, palavraMaisLonga);
    while (colunas > 1 && _larguraPor(largura, colunas) < necessaria) {
      colunas = colunas > 2 ? 2 : 1;
    }
    return colunas;
  }

  /// Monta (ou só mede, com [montar] falso) e devolve o tamanho.
  Size _distribuir(BoxConstraints limites, {required bool montar}) {
    final filhos = _filhos;
    if (filhos.isEmpty) return limites.smallest;
    final colunas = _colunas(limites.maxWidth, filhos);
    final por = limites.maxWidth.isFinite
        ? math.max(0.0, _larguraPor(limites.maxWidth, colunas))
        : filhos
            .map((f) => f.getMaxIntrinsicWidth(double.infinity))
            .reduce(math.max);
    var y = 0.0;
    for (var i = 0; i < filhos.length; i += colunas) {
      final linha = filhos.sublist(i, math.min(i + colunas, filhos.length));
      final altura =
          linha.map((f) => f.getMaxIntrinsicHeight(por)).reduce(math.max);
      if (montar) {
        for (var j = 0; j < linha.length; j++) {
          linha[j].layout(BoxConstraints.tightFor(width: por, height: altura));
          (linha[j].parentData! as _DadosGrade).offset =
              Offset(j * (por + _espaco), y);
        }
      }
      y += altura;
      if (i + colunas < filhos.length) y += _espaco;
    }
    final largura = limites.maxWidth.isFinite
        ? limites.maxWidth
        : colunas * por + (colunas - 1) * _espaco;
    return limites.constrain(Size(largura, y));
  }

  @override
  void performLayout() => size = _distribuir(constraints, montar: true);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _distribuir(constraints, montar: false);

  @override
  double computeMinIntrinsicWidth(double height) {
    final filhos = _filhos;
    if (filhos.isEmpty) return 0;
    return filhos.map((f) => f.getMinIntrinsicWidth(height)).reduce(math.max);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final filhos = _filhos;
    if (filhos.isEmpty) return 0;
    final colunas = math.min(_colunasPreferidas, filhos.length);
    final maior =
        filhos.map((f) => f.getMaxIntrinsicWidth(height)).reduce(math.max);
    return colunas * maior + (colunas - 1) * _espaco;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _distribuir(BoxConstraints(maxWidth: width), montar: false).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _distribuir(BoxConstraints(maxWidth: width), montar: false).height;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class _Opcao<T> extends StatelessWidget {
  const _Opcao({
    required this.opcao,
    required this.selecionada,
    required this.aoMudar,
  });

  final OpcaoSeletor<T> opcao;
  final bool selecionada;
  final ValueChanged<T>? aoMudar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final mudar = aoMudar;
    return AreaPressionavel(
      aoTocar: mudar == null ? null : () => mudar(opcao.valor),
      vibrar: true,
      rotuloSemantico: opcao.rotulo,
      selecionado: selecionada,
      grupoExclusivo: true,
      construtor: (context, e) {
        // Desabilitado: sem fundo e tracejado; a escolhida mantém o check,
        // então dá para ver o que estava marcado.
        final Color fundo;
        final Color frente;
        final Color? borda;
        if (!e.habilitado) {
          fundo = const Color(0x00000000);
          frente = c.grafite2;
          borda = null;
        } else if (selecionada) {
          fundo = c.grafite;
          frente = c.sobreGrafite;
          borda = c.grafite;
        } else {
          fundo = e.pressionado ? c.folhaRebaixada : c.folha;
          frente = c.grafite;
          borda = c.traco;
        }
        final icone = selecionada ? Icons.check : opcao.icone;
        final caixa = AnimatedContainer(
          duration: context.duracao(Movimento.rapido),
          curve: Movimento.entrar,
          constraints: const BoxConstraints(minHeight: Alvo.opcao),
          padding: const EdgeInsets.symmetric(
            horizontal: Espaco.e12,
            vertical: Espaco.e8,
          ),
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: Raio.cantoPequeno,
            border: borda == null
                ? null
                : Border.all(color: borda, width: Traco.fino),
          ),
          foregroundDecoration: e.focado
              ? BoxDecoration(
                  borderRadius: Raio.cantoPequeno,
                  border: Border.all(color: c.marcaTexto, width: 3),
                )
              : null,
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  if (icone != null)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: Espaco.e8),
                        child: Icon(icone, size: 22, color: frente),
                      ),
                    ),
                  TextSpan(text: opcao.rotulo),
                ],
              ),
              style: Tipografia.corpoForte.copyWith(color: frente, height: 1.2),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
        if (borda != null) return caixa;
        return CustomPaint(
          foregroundPainter: ContornoTracejado(cor: c.traco),
          child: caixa,
        );
      },
    );
  }
}
