import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/formatters.dart';
import '../movimento.dart';
import '../tipografia.dart';
import '../tokens.dart';
import 'rotulo.dart';

/// O número principal da tela, em R$: Archivo 40/800 com algarismos
/// tabulares. Quando o valor muda, conta até o novo número (360 ms); como
/// todo dígito tem a mesma largura, o número não tremula. Com "reduzir
/// animações", mostra o valor final na hora.
///
/// Não conta ao aparecer (aparecer não é mudança), a menos que
/// [contarAoAparecer] seja verdadeiro. Nunca estoura a largura: se não
/// couber, diminui.
class ValorHeroi extends StatefulWidget {
  const ValorHeroi({
    super.key,
    required this.valor,
    this.rotulo,
    this.centavosMenores = true,
    this.contarAoAparecer = false,
    this.cor,
  });

  final double valor;

  /// Rótulo em caixa alta acima do valor (ex.: "Gasto até agora").
  final String? rotulo;

  /// Centavos em 55% do tamanho: o olho lê os reais primeiro.
  final bool centavosMenores;
  final bool contarAoAparecer;

  /// Padrão: `grafite`.
  final Color? cor;

  @override
  State<ValorHeroi> createState() => _ValorHeroiState();
}

class _ValorHeroiState extends State<ValorHeroi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(vsync: this);
  late double _de = widget.contarAoAparecer ? 0 : widget.valor;
  late double _ate = widget.valor;
  bool _iniciado = false;

  double get _exibido =>
      _de + (_ate - _de) * Movimento.entrar.transform(_controle.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciado) {
      _iniciado = true;
      if (_de != _ate) _animar();
    }
  }

  @override
  void didUpdateWidget(ValorHeroi antigo) {
    super.didUpdateWidget(antigo);
    if (widget.valor != _ate) {
      _de = _exibido;
      _ate = widget.valor;
      _animar();
    }
  }

  void _animar() {
    final duracao = context.duracao(Movimento.lento);
    if (duracao == Duration.zero) {
      _controle.value = 1;
      return;
    }
    _controle.duration = duracao;
    _controle.forward(from: 0);
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final estilo =
        Tipografia.valorHeroi.copyWith(color: widget.cor ?? c.grafite);
    final valorFinal = Formatters.moeda(widget.valor);
    return Semantics(
      container: true,
      label:
          widget.rotulo == null ? valorFinal : '${widget.rotulo}: $valorFinal',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.rotulo != null) ...[
            Rotulo(widget.rotulo!),
            const SizedBox(height: Espaco.e4),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // A contagem repinta só o número, numa camada própria, e numa
            // caixa de tamanho fixo (a do maior dos dois valores): trocar
            // o texto a cada quadro não remonta nem repinta a tela em
            // volta. Os algarismos tabulares garantem que todo número do
            // caminho cabe nela.
            child: SizedBox.fromSize(
              size: _caixa(context, estilo),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controle,
                  builder: (context, _) => Text.rich(
                    _texto(_exibido, estilo),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// O tamanho do maior texto entre o valor de partida e o de chegada.
  Size _caixa(BuildContext context, TextStyle estilo) {
    final escala =
        MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
    var largura = 0.0;
    var altura = 0.0;
    for (final v in {_de, _ate}) {
      final medida = TextPainter(
        text: _texto(v, estilo),
        textDirection: TextDirection.ltr,
        textScaler: escala,
        maxLines: 1,
      )..layout();
      largura = math.max(largura, medida.width);
      altura = math.max(altura, medida.height);
      medida.dispose();
    }
    // Arredonda para cima: a caixa nunca corta o último dígito.
    return Size(largura.ceilToDouble() + 1, altura.ceilToDouble());
  }

  InlineSpan _texto(double valor, TextStyle estilo) {
    final texto = Formatters.moeda(valor);
    final virgula = texto.lastIndexOf(',');
    if (!widget.centavosMenores || virgula < 0) {
      return TextSpan(text: texto, style: estilo);
    }
    return TextSpan(
      style: estilo,
      children: [
        TextSpan(text: texto.substring(0, virgula)),
        TextSpan(
          text: texto.substring(virgula),
          style: TextStyle(fontSize: estilo.fontSize! * 0.55, letterSpacing: 0),
        ),
      ],
    );
  }
}
