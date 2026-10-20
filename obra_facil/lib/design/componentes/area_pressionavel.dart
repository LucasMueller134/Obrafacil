import 'dart:async';

import 'package:flutter/material.dart';

import '../movimento.dart';
import '../tato.dart';

/// Estado de toque que a [AreaPressionavel] passa para quem desenha.
@immutable
class EstadoToque {
  const EstadoToque({
    required this.pressionado,
    required this.focado,
    required this.habilitado,
  });

  final bool pressionado;

  /// Foco de teclado ou de acessibilidade: desenhe um contorno visível.
  final bool focado;
  final bool habilitado;
}

/// Base de tudo que se toca no design system: foco, teclado, Semantics,
/// vibração opcional e o estado pressionado como forma (encolhe um pouco),
/// nunca como véu de cor translúcida.
class AreaPressionavel extends StatefulWidget {
  const AreaPressionavel({
    super.key,
    required this.aoTocar,
    required this.construtor,
    this.rotuloSemantico,
    this.dicaSemantica,
    this.escala = 0.97,
    this.vibrar = false,
    this.botao = true,
    this.selecionado,
    this.grupoExclusivo = false,
  });

  /// Nulo: desabilitado.
  final VoidCallback? aoTocar;

  /// Desenha o conteúdo para o estado atual.
  final Widget Function(BuildContext context, EstadoToque estado) construtor;

  /// Texto lido pelo leitor de tela. Se dado, substitui o dos filhos.
  final String? rotuloSemantico;
  final String? dicaSemantica;

  /// Escala enquanto pressionado (1 = não encolhe).
  final double escala;

  /// Vibração leve ao tocar.
  final bool vibrar;

  /// Anuncia como botão ao leitor de tela.
  final bool botao;

  /// Para opções de escolha: anuncia selecionado/não selecionado.
  final bool? selecionado;

  /// Faz parte de um grupo em que só uma opção vale.
  final bool grupoExclusivo;

  @override
  State<AreaPressionavel> createState() => _AreaPressionavelState();
}

class _AreaPressionavelState extends State<AreaPressionavel> {
  bool _pressionado = false;
  bool _focado = false;

  void _tocar() {
    final acao = widget.aoTocar;
    if (acao == null) return;
    if (widget.vibrar) unawaited(Tato.leve());
    acao();
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.aoTocar != null;
    final estado = EstadoToque(
      pressionado: _pressionado && habilitado,
      focado: _focado && habilitado,
      habilitado: habilitado,
    );
    Widget conteudo = widget.construtor(context, estado);
    if (widget.escala != 1) {
      conteudo = AnimatedScale(
        scale: estado.pressionado ? widget.escala : 1,
        duration: context.duracao(Movimento.rapido),
        curve: Movimento.entrar,
        child: conteudo,
      );
    }
    const transparente = Color(0x00000000);
    // Uma coisa tocável é um nó só para o leitor de tela: o rótulo, o
    // valor e o selo de status de uma linha de lista são lidos juntos, com
    // o "botão" (o selo não fica como um nó solto, fora do toque).
    return MergeSemantics(
      child: Semantics(
        container: true,
        button: widget.botao,
        enabled: habilitado,
        selected: widget.selecionado,
        inMutuallyExclusiveGroup: widget.grupoExclusivo ? true : null,
        label: widget.rotuloSemantico,
        hint: widget.dicaSemantica,
        onTap: habilitado ? _tocar : null,
        excludeSemantics: widget.rotuloSemantico != null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: habilitado ? _tocar : null,
            onHighlightChanged: (v) => setState(() => _pressionado = v),
            onFocusChange: (v) => setState(() => _focado = v),
            canRequestFocus: habilitado,
            excludeFromSemantics: true,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(transparente),
            splashColor: transparente,
            highlightColor: transparente,
            focusColor: transparente,
            hoverColor: transparente,
            child: conteudo,
          ),
        ),
      ),
    );
  }
}
