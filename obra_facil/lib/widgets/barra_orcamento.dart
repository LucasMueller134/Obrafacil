import 'package:flutter/material.dart';

import '../design/design.dart';
import '../utils/formatters.dart';

/// O orçamento da obra na linguagem da prancheta: quanto já foi gasto
/// (aprovado), de quanto, e a régua de cota com o avanço físico marcado em
/// laranja. Quando o gasto passa do avanço em mais de 5 pontos, ou passa do
/// orçamento, uma nota de revisão diz quanto.
///
/// [compacta] troca o valor-herói por um título (a versão do mestre, dentro
/// de uma folha).
class BarraOrcamento extends StatelessWidget {
  final double gasto;
  final double orcamento;

  /// Avanço físico da obra, de 0 a 100 (média das fases do cronograma).
  /// Nulo: sem cronograma, a régua fica sem marcador.
  final int? avancoFisico;
  final bool compacta;

  const BarraOrcamento({
    super.key,
    required this.gasto,
    required this.orcamento,
    this.avancoFisico,
    this.compacta = false,
  });

  /// Pontos percentuais acima do avanço a partir dos quais a nota aparece.
  static const int toleranciaPontos = 5;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final temOrcamento = orcamento > 0;
    final fracao = temOrcamento ? gasto / orcamento : 0.0;
    final porcento = (fracao * 100).round();
    final avanco = avancoFisico;
    final acima = avanco == null || !temOrcamento ? 0 : porcento - avanco;
    final estourou = temOrcamento && gasto > orcamento;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (compacta) ...[
          const Rotulo('Gasto até agora'),
          const SizedBox(height: Espaco.e4),
          Text(
            Formatters.moeda(gasto),
            style: Tipografia.titulo.copyWith(color: c.grafite),
          ),
        ] else
          ValorHeroi(valor: gasto, rotulo: 'Gasto até agora'),
        const SizedBox(height: Espaco.e4),
        Text(
          temOrcamento
              ? 'de ${Formatters.moeda(orcamento)} · $porcento% do orçamento'
              : 'Orçamento não informado',
          style: Tipografia.apoio.copyWith(color: c.grafite2),
        ),
        const SizedBox(height: Espaco.e12),
        ReguaCota(
          valor: fracao,
          marcador: avanco == null ? null : avanco / 100,
          legenda: avanco == null ? null : 'avanço $avanco%',
          rotuloSemantico: 'Orçamento usado',
        ),
        if (estourou || acima > toleranciaPontos) ...[
          const SizedBox(height: Espaco.e12),
          Wrap(
            spacing: Espaco.e8,
            runSpacing: Espaco.e8,
            children: [
              if (estourou)
                NotaRevisao(
                  'Orçamento estourado em '
                  '${Formatters.moeda(gasto - orcamento)}',
                ),
              if (acima > toleranciaPontos)
                NotaRevisao(
                  '$acima ${acima == 1 ? 'ponto' : 'pontos'} acima do avanço',
                ),
            ],
          ),
        ],
      ],
    );
  }
}
