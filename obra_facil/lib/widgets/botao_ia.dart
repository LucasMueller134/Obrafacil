import 'package:flutter/material.dart';

import '../design/design.dart';

/// Entrada rápida por foto ou por voz: o par de escolhas grandes que abre
/// os formulários de lançamento e de diário.
///
/// Botão de contorno da prancheta: traço grafite de 2 dp, ícone de traço,
/// rótulo e uma linha de apoio, com 96 dp de altura no mínimo (o mestre
/// toca de luva). Na prancheta o fundo é a folha (a escolha se destaca do
/// papel como o carimbo); pressionado, fica recuado (cor sólida, nunca véu
/// translúcido); sem [onTap], o contorno fica tracejado e o texto em
/// grafite2. Lê as cores com `context.cores`: numa tela que ainda está no
/// tema antigo (sem a extensão), o fundo fica transparente sobre o dela.
class BotaoIa extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String descricao;
  final VoidCallback? onTap;

  const BotaoIa({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.descricao,
    this.onTap,
  });

  /// Altura mínima da escolha.
  static const double alturaMinima = 96;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final naPrancheta = Theme.of(context).extension<CoresObra>() != null;
    const transparente = Color(0x00000000);
    final fundo = naPrancheta ? c.folha : transparente;
    return AreaPressionavel(
      aoTocar: onTap,
      vibrar: true,
      construtor: (context, e) {
        final frente = e.habilitado ? c.grafite : c.grafite2;
        final caixa = AnimatedContainer(
          duration: context.duracao(Movimento.rapido),
          curve: Movimento.entrar,
          constraints: const BoxConstraints(minHeight: alturaMinima),
          padding: const EdgeInsets.fromLTRB(
            Espaco.e16,
            Espaco.e12,
            Espaco.e12,
            Espaco.e16,
          ),
          decoration: BoxDecoration(
            color: e.pressionado
                ? c.folhaRebaixada
                : (e.habilitado ? fundo : transparente),
            borderRadius: Raio.cantoPequeno,
            border: e.habilitado
                ? Border.all(color: c.grafite, width: Traco.forte)
                : null,
          ),
          foregroundDecoration: e.focado
              ? BoxDecoration(
                  borderRadius: Raio.cantoPequeno,
                  border: Border.all(color: c.marcaTexto, width: 3),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 32, color: frente),
              const SizedBox(height: Espaco.e8),
              Text(
                rotulo,
                style: Tipografia.subtitulo.copyWith(color: frente),
              ),
              const SizedBox(height: 2),
              Text(
                descricao,
                style: Tipografia.apoio.copyWith(color: c.grafite2),
              ),
            ],
          ),
        );
        if (e.habilitado) return caixa;
        return CustomPaint(
          foregroundPainter:
              ContornoTracejado(cor: c.traco, espessura: Traco.forte),
          child: caixa,
        );
      },
    );
  }
}

/// O que a leitura da foto ou da fala entendeu, e o quanto confiar nela:
/// uma nota de texto com borda, como a anotação na margem da prancha. Sem
/// brilho de "IA" e sem fundo translúcido: o texto fica em grafite (15:1)
/// e a borda e o ícone no laranja de traço.
class AvisoIa extends StatelessWidget {
  final String mensagem;

  const AvisoIa({super.key, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          Espaco.e12,
          Espaco.e12,
          Espaco.e16,
          Espaco.e12,
        ),
        decoration: BoxDecoration(
          borderRadius: Raio.cantoPequeno,
          border: Border.all(color: c.marcaTexto, width: Traco.fino),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, size: 22, color: c.marcaTexto),
            ),
            const SizedBox(width: Espaco.e12),
            Expanded(
              child: Text(
                mensagem,
                style:
                    Tipografia.corpo.copyWith(color: c.grafite, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
