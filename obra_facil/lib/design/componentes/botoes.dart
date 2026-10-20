import 'package:flutter/material.dart';

import '../movimento.dart';
import '../tipografia.dart';
import '../tokens.dart';
import 'area_pressionavel.dart';
import 'carregando.dart';
import 'tracejado.dart';

// Botões da prancheta. Regras comuns:
// - pressionado: encolhe um pouco e o fundo muda para outra cor sólida;
// - carregando: indicador no lugar do ícone, mesma cor, não aceita toque;
// - desabilitado (sem `aoTocar`): sem fundo, contorno tracejado e texto
//   grafite2 (7:1 no papel), legível mas claramente fora de uso;
// - foco de teclado: contorno laranja de 3 dp;
// - vibração leve ao tocar, desligável com `vibrar: false`.

/// Ação principal: 64 dp de altura (72 com [grande]), fundo grafite e
/// texto papel.
class BotaoPrincipal extends StatelessWidget {
  const BotaoPrincipal({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.icone,
    this.grande = false,
    this.carregando = false,
    this.expandir = false,
    this.vibrar = true,
    this.dicaSemantica,
  });

  final String rotulo;

  /// Nulo: desabilitado.
  final VoidCallback? aoTocar;
  final IconData? icone;

  /// 72 dp: a ação principal da tela.
  final bool grande;
  final bool carregando;

  /// Ocupa toda a largura disponível.
  final bool expandir;

  /// Vibração leve ao tocar.
  final bool vibrar;
  final String? dicaSemantica;

  @override
  Widget build(BuildContext context) => _Botao(
        estilo: _EstiloBotao.principal,
        rotulo: rotulo,
        aoTocar: aoTocar,
        icone: icone,
        grande: grande,
        carregando: carregando,
        expandir: expandir,
        vibrar: vibrar,
        dicaSemantica: dicaSemantica,
      );
}

/// Igual ao [BotaoPrincipal], com fundo laranja e texto preto: a ação que
/// cria algo novo (lançar gasto).
class BotaoMarca extends StatelessWidget {
  const BotaoMarca({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.icone,
    this.grande = false,
    this.carregando = false,
    this.expandir = false,
    this.vibrar = true,
    this.dicaSemantica,
  });

  final String rotulo;
  final VoidCallback? aoTocar;
  final IconData? icone;
  final bool grande;
  final bool carregando;
  final bool expandir;
  final bool vibrar;
  final String? dicaSemantica;

  @override
  Widget build(BuildContext context) => _Botao(
        estilo: _EstiloBotao.marca,
        rotulo: rotulo,
        aoTocar: aoTocar,
        icone: icone,
        grande: grande,
        carregando: carregando,
        expandir: expandir,
        vibrar: vibrar,
        dicaSemantica: dicaSemantica,
      );
}

/// Ação secundária: contorno grafite de 2 dp, fundo transparente.
class BotaoContorno extends StatelessWidget {
  const BotaoContorno({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.icone,
    this.grande = false,
    this.carregando = false,
    this.expandir = false,
    this.vibrar = true,
    this.dicaSemantica,
  });

  final String rotulo;
  final VoidCallback? aoTocar;
  final IconData? icone;
  final bool grande;
  final bool carregando;
  final bool expandir;
  final bool vibrar;
  final String? dicaSemantica;

  @override
  Widget build(BuildContext context) => _Botao(
        estilo: _EstiloBotao.contorno,
        rotulo: rotulo,
        aoTocar: aoTocar,
        icone: icone,
        grande: grande,
        carregando: carregando,
        expandir: expandir,
        vibrar: vibrar,
        dicaSemantica: dicaSemantica,
      );
}

/// Variante do [BotaoIcone].
enum EstiloBotaoIcone { contorno, marca, principal }

/// Botão quadrado de 64 dp só com ícone. O [rotulo] é obrigatório: vai
/// para o leitor de tela e para a dica do toque longo.
class BotaoIcone extends StatelessWidget {
  const BotaoIcone({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.estilo = EstiloBotaoIcone.contorno,
    this.tamanho = Alvo.mestre,
    this.carregando = false,
    this.vibrar = true,
  }) : assert(tamanho >= Alvo.minimo);

  final IconData icone;
  final String rotulo;

  /// Nulo: desabilitado.
  final VoidCallback? aoTocar;
  final EstiloBotaoIcone estilo;

  /// Lado do quadrado (no mínimo 48).
  final double tamanho;
  final bool carregando;
  final bool vibrar;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final tipo = switch (estilo) {
      EstiloBotaoIcone.contorno => _EstiloBotao.contorno,
      EstiloBotaoIcone.marca => _EstiloBotao.marca,
      EstiloBotaoIcone.principal => _EstiloBotao.principal,
    };
    return Tooltip(
      message: rotulo,
      excludeFromSemantics: true,
      child: AreaPressionavel(
        aoTocar: carregando ? null : aoTocar,
        vibrar: vibrar,
        rotuloSemantico: carregando ? '$rotulo, carregando' : rotulo,
        escala: 0.94,
        construtor: (context, e) {
          final aparencia = _Aparencia.de(c, tipo, e, carregando: carregando);
          return _Moldura(
            aparencia: aparencia,
            focado: e.focado,
            largura: tamanho,
            altura: tamanho,
            child: Center(
              child: carregando
                  ? IndicadorCarregando(cor: aparencia.frente)
                  : Icon(icone, size: 28, color: aparencia.frente),
            ),
          );
        },
      ),
    );
  }
}

enum _EstiloBotao { principal, marca, contorno }

/// Cores e borda de um botão num estado.
class _Aparencia {
  const _Aparencia({
    required this.fundo,
    required this.frente,
    this.borda,
    this.tracejado,
  });

  final Color fundo;
  final Color frente;
  final Border? borda;

  /// Cor do contorno tracejado (desabilitado).
  final Color? tracejado;

  static const _transparente = Color(0x00000000);

  static _Aparencia de(
    CoresObra c,
    _EstiloBotao estilo,
    EstadoToque e, {
    bool carregando = false,
  }) {
    // Carregando não é desabilitado: mantém as cores, só não aceita toque.
    if (!e.habilitado && !carregando) {
      return _Aparencia(
        fundo: _transparente,
        frente: c.grafite2,
        tracejado: c.traco,
      );
    }
    final pressionado = e.pressionado && !carregando;
    return switch (estilo) {
      _EstiloBotao.principal => _Aparencia(
          fundo: pressionado ? c.grafite2 : c.grafite,
          frente: c.sobreGrafite,
        ),
      _EstiloBotao.marca => _Aparencia(
          fundo: pressionado ? c.marcaPressionada : c.marca,
          frente: c.sobreMarca,
        ),
      _EstiloBotao.contorno => _Aparencia(
          fundo: pressionado ? c.folhaRebaixada : _transparente,
          frente: c.grafite,
          borda: Border.all(color: c.grafite, width: Traco.forte),
        ),
    };
  }
}

/// A caixa do botão: fundo, borda (cheia ou tracejada) e anel de foco.
class _Moldura extends StatelessWidget {
  const _Moldura({
    required this.aparencia,
    required this.focado,
    required this.child,
    this.largura,
    this.altura,
    this.minimo,
    this.preenchimento,
  });

  final _Aparencia aparencia;
  final bool focado;
  final Widget child;
  final double? largura;
  final double? altura;
  final double? minimo;
  final EdgeInsetsGeometry? preenchimento;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    Widget caixa = AnimatedContainer(
      duration: context.duracao(Movimento.rapido),
      curve: Movimento.entrar,
      width: largura,
      height: altura,
      constraints: minimo == null
          ? null
          : BoxConstraints(minHeight: minimo!, minWidth: minimo!),
      padding: preenchimento,
      decoration: BoxDecoration(
        color: aparencia.fundo,
        borderRadius: Raio.cantoPequeno,
        border: aparencia.borda,
      ),
      foregroundDecoration: focado
          ? BoxDecoration(
              borderRadius: Raio.cantoPequeno,
              border: Border.all(color: c.marcaTexto, width: 3),
            )
          : null,
      child: child,
    );
    final tracejado = aparencia.tracejado;
    if (tracejado != null) {
      caixa = CustomPaint(
        foregroundPainter: ContornoTracejado(cor: tracejado),
        child: caixa,
      );
    }
    return caixa;
  }
}

class _Botao extends StatelessWidget {
  const _Botao({
    required this.estilo,
    required this.rotulo,
    required this.aoTocar,
    required this.icone,
    required this.grande,
    required this.carregando,
    required this.expandir,
    required this.vibrar,
    required this.dicaSemantica,
  });

  final _EstiloBotao estilo;
  final String rotulo;
  final VoidCallback? aoTocar;
  final IconData? icone;
  final bool grande;
  final bool carregando;
  final bool expandir;
  final bool vibrar;
  final String? dicaSemantica;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    Widget botao = AreaPressionavel(
      aoTocar: carregando ? null : aoTocar,
      vibrar: vibrar,
      rotuloSemantico: carregando ? '$rotulo, carregando' : rotulo,
      dicaSemantica: dicaSemantica,
      construtor: (context, e) {
        final aparencia = _Aparencia.de(c, estilo, e, carregando: carregando);
        final frente = aparencia.frente;
        final Widget? marca = carregando
            ? IndicadorCarregando(cor: frente)
            : (icone == null ? null : Icon(icone, size: 24, color: frente));
        return _Moldura(
          aparencia: aparencia,
          focado: e.focado,
          minimo: grande ? Alvo.principal : Alvo.mestre,
          preenchimento: EdgeInsets.symmetric(
            horizontal: grande ? Espaco.e24 : Espaco.e16,
            vertical: Espaco.e8,
          ),
          // Largura do conteúdo, a menos que o pai imponha (expandir,
          // Expanded, coluna esticada); a altura nunca encolhe do mínimo.
          child: Align(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (marca != null) ...[
                  marca,
                  const SizedBox(width: Espaco.e8),
                ],
                Flexible(
                  child: Text(
                    rotulo,
                    style: Tipografia.subtitulo.copyWith(
                      color: frente,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (expandir) botao = SizedBox(width: double.infinity, child: botao);
    return botao;
  }
}
