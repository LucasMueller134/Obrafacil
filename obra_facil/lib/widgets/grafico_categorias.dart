import 'package:flutter/material.dart';

import '../design/design.dart';
import '../models/lancamento_model.dart';
import '../utils/formatters.dart';

/// Gasto aprovado por categoria, na linguagem da prancheta: uma barra por
/// categoria, do maior para o menor, com o nome, o valor e a fatia escritos
/// direto ao lado (sem legenda). As categorias se separam por luminância e
/// forma, não por matiz: grafite, traço, marca e hachura.
class GraficoCategorias extends StatelessWidget {
  final List<LancamentoModel> lancamentos;

  const GraficoCategorias({super.key, required this.lancamentos});

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final porCategoria = <CategoriaCusto, double>{};
    for (final l in lancamentos) {
      if (l.status != StatusLancamento.aprovado) continue;
      porCategoria[l.categoria] = (porCategoria[l.categoria] ?? 0) + l.valor;
    }
    final total = porCategoria.values.fold<double>(0, (s, v) => s + v);

    if (total <= 0) {
      return Text(
        'Sem gastos aprovados ainda',
        style: Tipografia.apoio.copyWith(color: c.grafite2),
      );
    }

    final entradas = porCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entradas.length; i++) ...[
          if (i > 0) const SizedBox(height: Espaco.e16),
          _LinhaCategoria(
            categoria: entradas[i].key,
            valor: entradas[i].value,
            fatia: entradas[i].value / total,
          ),
        ],
      ],
    );
  }
}

class _LinhaCategoria extends StatelessWidget {
  const _LinhaCategoria({
    required this.categoria,
    required this.valor,
    required this.fatia,
  });

  final CategoriaCusto categoria;
  final double valor;
  final double fatia;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final porcento = '${(fatia * 100).round()}%';
    final moeda = Formatters.moeda(valor);
    return Semantics(
      container: true,
      label: '${categoria.label}: $moeda, $porcento do gasto aprovado',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ParComValor(
            fracaoMaxima: 0.55,
            esquerda: Text(
              categoria.label,
              style: Tipografia.corpoForte.copyWith(color: c.grafite),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            direita: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                moeda,
                style: Tipografia.subtitulo.copyWith(color: c.grafite),
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(height: Espaco.e4),
          Row(
            children: [
              Expanded(child: _Barra(categoria: categoria, fatia: fatia)),
              const SizedBox(width: Espaco.e12),
              SizedBox(
                width: 48,
                child: Text(
                  porcento,
                  textAlign: TextAlign.end,
                  style: Tipografia.apoio.copyWith(
                    color: c.grafite,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A barra da categoria: trilho com contorno grafite e o preenchimento até
/// a fatia, no tom da categoria.
class _Barra extends StatelessWidget {
  const _Barra({required this.categoria, required this.fatia});

  final CategoriaCusto categoria;
  final double fatia;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final Widget preenchimento = switch (categoria) {
      CategoriaCusto.material => ColoredBox(color: c.grafite),
      CategoriaCusto.maoDeObra => ColoredBox(color: c.traco),
      CategoriaCusto.equipamento => ColoredBox(color: c.marca),
      CategoriaCusto.outros =>
        CaixaHachurada(cor: c.grafite, contorno: false, espacamento: 4),
    };
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: c.folhaRebaixada,
        border: Border.all(color: c.grafite, width: Traco.fino),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fatia.clamp(0.0, 1.0),
        heightFactor: 1,
        // A ponta do preenchimento em grafite: o laranja no trilho claro
        // fica em 2,4:1, e a ponta marca onde a fatia termina (3:1 ou mais
        // nos dois temas).
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: c.grafite, width: Traco.fino),
            ),
          ),
          child: preenchimento,
        ),
      ),
    );
  }
}
