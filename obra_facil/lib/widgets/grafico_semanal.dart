import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/design.dart';
import '../models/lancamento_model.dart';
import '../utils/formatters.dart';

/// Gasto aprovado por semana (últimas 6 semanas), na linguagem da
/// prancheta: barras grafite sobre uma linha de base, o valor escrito em
/// cima de cada barra (sem precisar tocar) e a semana embaixo. A semana
/// atual vai em laranja e com o rótulo "atual".
class GraficoSemanal extends StatelessWidget {
  final List<LancamentoModel> lancamentos;

  const GraficoSemanal({super.key, required this.lancamentos});

  static const double _alturaBarras = 96;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    const numSemanas = 6;
    final agora = DateTime.now();
    final inicioSemanaAtual = DateTime(agora.year, agora.month, agora.day)
        .subtract(Duration(days: agora.weekday - 1));

    final inicios = List.generate(
      numSemanas,
      (i) =>
          inicioSemanaAtual.subtract(Duration(days: 7 * (numSemanas - 1 - i))),
    );

    final valores = List<double>.filled(numSemanas, 0);
    for (final l in lancamentos) {
      if (l.status != StatusLancamento.aprovado) continue;
      for (var i = 0; i < numSemanas; i++) {
        final fim = inicios[i].add(const Duration(days: 7));
        if (!l.data.isBefore(inicios[i]) && l.data.isBefore(fim)) {
          valores[i] += l.valor;
          break;
        }
      }
    }

    final maior = valores.fold<double>(0, (m, v) => v > m ? v : m);
    if (maior <= 0) {
      return Text(
        'Sem gastos nas últimas semanas',
        style: Tipografia.apoio.copyWith(color: c.grafite2),
      );
    }

    final escala = _Escala.para(maior);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Em ${escala.unidade}, de segunda a domingo.',
          style: Tipografia.apoio.copyWith(color: c.grafite2),
        ),
        const SizedBox(height: Espaco.e12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < numSemanas; i++)
              Expanded(
                child: _Coluna(
                  valor: valores[i],
                  fracao: valores[i] / maior,
                  rotuloValor: escala.formatar(valores[i]),
                  inicio: inicios[i],
                  atual: i == numSemanas - 1,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Unidade dos rótulos: reais, mil ou milhões, conforme a maior semana.
class _Escala {
  const _Escala(this.unidade, this.divisor, this.formato);

  final String unidade;
  final double divisor;
  final NumberFormat formato;

  static _Escala para(double maior) {
    if (maior >= 1e6) {
      return _Escala('R\$ milhões', 1e6, NumberFormat('#,##0.0#', 'pt_BR'));
    }
    if (maior >= 1e3) {
      return _Escala('R\$ mil', 1e3, NumberFormat('#,##0.#', 'pt_BR'));
    }
    return _Escala('R\$', 1, NumberFormat('#,##0', 'pt_BR'));
  }

  String formatar(double valor) => formato.format(valor / divisor);
}

class _Coluna extends StatelessWidget {
  const _Coluna({
    required this.valor,
    required this.fracao,
    required this.rotuloValor,
    required this.inicio,
    required this.atual,
  });

  final double valor;
  final double fracao;
  final String rotuloValor;
  final DateTime inicio;
  final bool atual;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final altura = valor <= 0
        ? 0.0
        : math.max(Traco.forte * 2, GraficoSemanal._alturaBarras * fracao);
    final estiloValor = Tipografia.apoio.copyWith(
      color: c.grafite,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final escala = MediaQuery.textScalerOf(context);

    // Cada texto numa faixa de altura fixa (a de uma linha na fonte do
    // sistema): se não couber na largura da coluna, ele encolhe dentro da
    // faixa, e a linha de base fica na mesma altura em todas as colunas.
    // O recuo de 2 dp de cada lado separa as datas vizinhas.
    Widget faixa(TextStyle estilo, Widget texto) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SizedBox(
            height: escala.scale(estilo.fontSize!) * estilo.height!,
            child: FittedBox(fit: BoxFit.scaleDown, child: texto),
          ),
        );

    return Semantics(
      container: true,
      label: '${atual ? 'Semana atual' : 'Semana'} de '
          '${Formatters.dataCurta(inicio)}: ${Formatters.moeda(valor)}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          faixa(
            estiloValor,
            Text(rotuloValor, style: estiloValor, maxLines: 1),
          ),
          const SizedBox(height: Espaco.e4),
          // A barra cresce de baixo para cima, sobre a linha de base. Semana
          // sem gasto não tem barra (nem o contorno da semana atual, que
          // pareceria um gasto pequeno).
          SizedBox(
            height: GraficoSemanal._alturaBarras,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: altura == 0
                  ? const SizedBox.shrink()
                  : Container(
                      width: 24,
                      height: altura,
                      decoration: BoxDecoration(
                        color: atual ? c.marca : c.grafite,
                        border: atual
                            ? Border.all(color: c.grafite, width: Traco.fino)
                            : null,
                      ),
                    ),
            ),
          ),
          // Linha de base contínua: cada coluna desenha o seu trecho.
          Container(height: Traco.forte, color: c.grafite),
          const SizedBox(height: Espaco.e4),
          faixa(
            estiloValor,
            Text(
              Formatters.dataCurta(inicio),
              style: estiloValor.copyWith(
                color: atual ? c.grafite : c.grafite2,
                fontWeight: atual ? FontWeight.w700 : FontWeight.w400,
              ),
              maxLines: 1,
            ),
          ),
          // A faixa do "atual" existe em todas as colunas, para as datas
          // ficarem alinhadas.
          faixa(
            Tipografia.rotulo,
            atual
                ? const Rotulo('atual')
                : const Opacity(opacity: 0, child: Rotulo('atual')),
          ),
        ],
      ),
    );
  }
}
