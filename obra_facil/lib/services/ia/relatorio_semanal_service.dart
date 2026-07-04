import '../../models/models.dart';
import '../../utils/formatters.dart';
import 'previsao_estoque_service.dart';
import 'previsao_orcamento_service.dart';

enum TipoSecao {
  visaoGeral,
  financeiro,
  pendencias,
  estoque,
  canteiro,
  previsao,
}

class SecaoRelatorio {
  final TipoSecao tipo;
  final String titulo;
  final List<String> paragrafos;

  const SecaoRelatorio({
    required this.tipo,
    required this.titulo,
    required this.paragrafos,
  });
}

class RelatorioSemanal {
  final String nomeObra;
  final DateTime geradoEm;
  final List<SecaoRelatorio> secoes;

  /// "O que fazer agora" — ações concretas extraídas da análise.
  final List<String> acoes;

  const RelatorioSemanal({
    required this.nomeObra,
    required this.geradoEm,
    required this.secoes,
    required this.acoes,
  });

  /// Versão em texto puro para compartilhar (WhatsApp, e-mail).
  String get textoCompartilhavel {
    const emojis = {
      TipoSecao.visaoGeral: '🏗️',
      TipoSecao.financeiro: '💰',
      TipoSecao.pendencias: '⏳',
      TipoSecao.estoque: '📦',
      TipoSecao.canteiro: '👷',
      TipoSecao.previsao: '🔮',
    };
    final b = StringBuffer();
    b.writeln('RELATÓRIO SEMANAL — ${nomeObra.toUpperCase()}');
    b.writeln('Gerado em ${Formatters.data(geradoEm)} pelo ObraFácil');
    for (final s in secoes) {
      b.writeln();
      b.writeln('${emojis[s.tipo]} ${s.titulo.toUpperCase()}');
      s.paragrafos.forEach(b.writeln);
    }
    if (acoes.isNotEmpty) {
      b.writeln();
      b.writeln('✅ O QUE FAZER AGORA');
      for (final a in acoes) {
        b.writeln('• $a');
      }
    }
    return b.toString().trimRight();
  }
}

/// IA on-device nº 3b — relatório semanal em linguagem natural.
///
/// Gera uma análise coerente da obra cruzando todas as fontes de dados:
/// o equilíbrio entre prazo decorrido, orçamento consumido e avanço
/// físico; o ritmo de gastos dos últimos 7 dias; pendências; estoque com
/// previsão de término; diário do canteiro; e a projeção de estouro.
/// Tudo por regras, no aparelho — as janelas são móveis (últimos 7 dias),
/// então o texto faz sentido em qualquer dia da semana.
class RelatorioSemanalService {
  static RelatorioSemanal gerar({
    required ObraModel obra,
    required List<LancamentoModel> lancamentos,
    required List<DiarioEntradaModel> diario,
    required List<CronogramaFaseModel> cronograma,
    List<EstoqueItemModel> estoque = const [],
    List<MovimentoEstoqueModel> movimentos = const [],
    DateTime? referencia,
  }) {
    final agora = referencia ?? DateTime.now();
    final inicio7d = agora.subtract(const Duration(days: 7));
    final inicio14d = agora.subtract(const Duration(days: 14));

    final aprovados = lancamentos
        .where((l) => l.status == StatusLancamento.aprovado)
        .toList();
    final pendentes = lancamentos
        .where((l) => l.status == StatusLancamento.pendente)
        .toList();
    final ultimos7 =
        aprovados.where((l) => l.data.isAfter(inicio7d)).toList();
    final anteriores7 = aprovados
        .where((l) =>
            l.data.isAfter(inicio14d) && !l.data.isAfter(inicio7d))
        .toList();

    final gastoTotal = aprovados.fold<double>(0, (s, l) => s + l.valor);
    final previsaoOrcamento = PrevisaoOrcamentoService.calcular(
        obra: obra, lancamentos: lancamentos);

    // Percentuais que dão o "nexo" da análise.
    final pctPrazo = obra.duracaoDias <= 0
        ? 0
        : (obra.diasDecorridos / obra.duracaoDias * 100).round();
    final pctGasto = obra.orcamento <= 0
        ? 0
        : (gastoTotal / obra.orcamento * 100).round();
    final pctFisico = cronograma.isEmpty
        ? null
        : (cronograma.fold<int>(0, (s, f) => s + f.percentualConcluido) /
                cronograma.length)
            .round();

    final acoes = <String>[];
    final secoes = <SecaoRelatorio>[
      _visaoGeral(obra, agora, gastoTotal, pctPrazo, pctGasto, pctFisico,
          acoes),
      if (_temConteudoFinanceiro(ultimos7, anteriores7))
        _financeiro(ultimos7, anteriores7),
      if (pendentes.isNotEmpty) _pendencias(pendentes, agora, acoes),
      ..._estoqueSecao(estoque, movimentos, diario, agora, acoes),
      ..._canteiroSecao(diario, cronograma, agora, acoes),
      _previsaoSecao(previsaoOrcamento, obra, acoes),
    ];

    if (acoes.isEmpty) {
      acoes.add('Nenhuma ação urgente — continue registrando gastos, '
          'diário e estoque para as previsões ficarem cada vez melhores.');
    }

    return RelatorioSemanal(
      nomeObra: obra.nome,
      geradoEm: agora,
      secoes: secoes,
      acoes: acoes,
    );
  }

  // ------------------------------------------------------- Visão geral

  static SecaoRelatorio _visaoGeral(
    ObraModel obra,
    DateTime agora,
    double gastoTotal,
    int pctPrazo,
    int pctGasto,
    int? pctFisico,
    List<String> acoes,
  ) {
    final paragrafos = <String>[
      'A obra está no ${obra.diasDecorridos}º dia de um cronograma de '
          '${obra.duracaoDias} dias ($pctPrazo% do prazo decorrido). '
          'Até aqui foram aprovados ${Formatters.moeda(gastoTotal)}, o que '
          'representa $pctGasto% do orçamento de '
          '${Formatters.moeda(obra.orcamento)}.',
    ];

    if (pctFisico != null) {
      paragrafos.add('O avanço físico registrado no cronograma é de '
          '$pctFisico%.');
      // O cruzamento que interessa: dinheiro × obra construída.
      if (pctGasto >= pctFisico + 10) {
        paragrafos.add(
            'Ponto de atenção: o consumo do orçamento ($pctGasto%) está '
            'correndo à frente do avanço físico ($pctFisico%). Em geral '
            'isso indica desperdício de material, preços acima do previsto '
            'ou retrabalho — vale investigar antes que a diferença cresça.');
        acoes.add('Investigar por que o gasto ($pctGasto%) supera o '
            'avanço físico ($pctFisico%): desperdício, preço ou retrabalho.');
      } else if (pctFisico >= pctGasto + 10) {
        paragrafos.add(
            'Bom sinal: a obra avançou $pctFisico% consumindo apenas '
            '$pctGasto% do orçamento — o dinheiro está rendendo mais que '
            'o planejado.');
      } else {
        paragrafos.add(
            'Gasto e avanço físico caminham equilibrados — é o cenário '
            'saudável.');
      }
      if (pctPrazo >= pctFisico + 15) {
        paragrafos.add(
            'Em relação ao calendário, porém, a obra está atrasada: '
            '$pctPrazo% do prazo já passou para $pctFisico% de obra '
            'concluída.');
        acoes.add('Replanejar o cronograma ou reforçar a equipe: o prazo '
            'corre mais rápido que a obra.');
      }
    }
    return SecaoRelatorio(
      tipo: TipoSecao.visaoGeral,
      titulo: 'Visão geral',
      paragrafos: paragrafos,
    );
  }

  // -------------------------------------------------------- Financeiro

  static bool _temConteudoFinanceiro(
          List<LancamentoModel> ultimos7, List<LancamentoModel> anteriores7) =>
      ultimos7.isNotEmpty || anteriores7.isNotEmpty;

  static SecaoRelatorio _financeiro(
    List<LancamentoModel> ultimos7,
    List<LancamentoModel> anteriores7,
  ) {
    final paragrafos = <String>[];
    final total7 = ultimos7.fold<double>(0, (s, l) => s + l.valor);
    final totalAnt = anteriores7.fold<double>(0, (s, l) => s + l.valor);

    if (ultimos7.isEmpty) {
      paragrafos.add('Nos últimos 7 dias não houve gastos aprovados — na '
          'semana anterior haviam sido ${Formatters.moeda(totalAnt)}. Se a '
          'obra continuou ativa, confira se os lançamentos estão sendo '
          'registrados.');
    } else {
      var frase = 'Os últimos 7 dias somaram ${Formatters.moeda(total7)} '
          'em ${ultimos7.length} lançamento${ultimos7.length > 1 ? 's' : ''} '
          'aprovado${ultimos7.length > 1 ? 's' : ''}';
      if (totalAnt > 0) {
        final variacao = (total7 - totalAnt) / totalAnt * 100;
        if (variacao >= 15) {
          frase += ' — ${variacao.toStringAsFixed(0)}% a mais que nos 7 '
              'dias anteriores';
        } else if (variacao <= -15) {
          frase += ' — ${variacao.abs().toStringAsFixed(0)}% a menos que '
              'nos 7 dias anteriores';
        } else {
          frase += ', ritmo parecido com o dos 7 dias anteriores';
        }
      }
      paragrafos.add('$frase.');

      // Onde o dinheiro foi.
      final porCategoria = <CategoriaCusto, double>{};
      for (final l in ultimos7) {
        porCategoria[l.categoria] =
            (porCategoria[l.categoria] ?? 0) + l.valor;
      }
      final dominante =
          porCategoria.entries.reduce((a, b) => b.value > a.value ? b : a);
      final pctDominante = (dominante.value / total7 * 100).round();
      if (pctDominante >= 50) {
        paragrafos.add(
            '${dominante.key.label} concentrou $pctDominante% do gasto do '
            'período (${Formatters.moeda(dominante.value)}).');
      }

      final maior = ultimos7.reduce((a, b) => b.valor > a.valor ? b : a);
      paragrafos.add('O maior lançamento foi "${maior.descricao}", de '
          '${Formatters.moeda(maior.valor)}'
          '${maior.fornecedorNome != null ? ', com ${maior.fornecedorNome}' : ''}'
          ' (${Formatters.data(maior.data)}).');
    }

    return SecaoRelatorio(
      tipo: TipoSecao.financeiro,
      titulo: 'Últimos 7 dias',
      paragrafos: paragrafos,
    );
  }

  // -------------------------------------------------------- Pendências

  static SecaoRelatorio _pendencias(
    List<LancamentoModel> pendentes,
    DateTime agora,
    List<String> acoes,
  ) {
    final total = pendentes.fold<double>(0, (s, l) => s + l.valor);
    final maisAntigo = pendentes
        .reduce((a, b) => a.criadoEm.isBefore(b.criadoEm) ? a : b);
    final diasParado = agora.difference(maisAntigo.criadoEm).inDays;

    final paragrafos = <String>[
      '${pendentes.length} lançamento${pendentes.length > 1 ? 's' : ''} '
          'aguarda${pendentes.length > 1 ? 'm' : ''} aprovação, somando '
          '${Formatters.moeda(total)}'
          '${diasParado >= 2 ? ' — o mais antigo está parado há $diasParado dias' : ''}. '
          'Enquanto não forem aprovados, esses valores ficam fora dos '
          'gráficos, do estoque e das previsões.',
    ];
    acoes.add('Revisar ${pendentes.length} '
        'lançamento${pendentes.length > 1 ? 's' : ''} '
        'pendente${pendentes.length > 1 ? 's' : ''} '
        '(${Formatters.moeda(total)}).');

    return SecaoRelatorio(
      tipo: TipoSecao.pendencias,
      titulo: 'Pendências',
      paragrafos: paragrafos,
    );
  }

  // ----------------------------------------------------------- Estoque

  static List<SecaoRelatorio> _estoqueSecao(
    List<EstoqueItemModel> estoque,
    List<MovimentoEstoqueModel> movimentos,
    List<DiarioEntradaModel> diario,
    DateTime agora,
    List<String> acoes,
  ) {
    if (estoque.isEmpty) return const [];
    final paragrafos = <String>[];

    final abaixoMinimo = estoque.where((i) => i.estoqueBaixo).toList();
    if (abaixoMinimo.isNotEmpty) {
      paragrafos.add(
          '${abaixoMinimo.map((i) => i.material).join(', ')} '
          '${abaixoMinimo.length > 1 ? 'estão' : 'está'} abaixo do nível '
          'mínimo definido.');
    }

    // Previsões de término (o modelo que aprende com o consumo real).
    final criticos = <String>[];
    for (final item in estoque) {
      final p = PrevisaoEstoqueService.calcular(
        item: item,
        movimentos: movimentos,
        diario: diario,
        referencia: agora,
      );
      if (p != null && p.atencao) {
        criticos.add('${item.material} deve acabar por volta de '
            '${Formatters.data(p.dataTermino)} (em ~${p.diasRestantes} '
            'dia${p.diasRestantes == 1 ? '' : 's'})');
        acoes.add('Programar compra de ${item.material} antes de '
            '${Formatters.dataCurta(p.dataTermino)}.');
      }
    }
    if (criticos.isNotEmpty) {
      paragrafos.add('No ritmo de consumo atual, ${criticos.join('; ')}. '
          'Comprar antes de faltar evita parar a equipe.');
    }

    if (paragrafos.isEmpty) {
      paragrafos.add('Nenhum material em nível crítico nem com término '
          'previsto para as próximas duas semanas.');
    }
    return [
      SecaoRelatorio(
        tipo: TipoSecao.estoque,
        titulo: 'Estoque',
        paragrafos: paragrafos,
      ),
    ];
  }

  // ---------------------------------------------------------- Canteiro

  static List<SecaoRelatorio> _canteiroSecao(
    List<DiarioEntradaModel> diario,
    List<CronogramaFaseModel> cronograma,
    DateTime agora,
    List<String> acoes,
  ) {
    final paragrafos = <String>[];
    final inicio7d = agora.subtract(const Duration(days: 7));
    final registros =
        diario.where((d) => d.data.isAfter(inicio7d)).toList();

    if (registros.isNotEmpty) {
      final diasComRegistro =
          registros.map((d) => '${d.data.year}-${d.data.month}-${d.data.day}')
              .toSet()
              .length;
      final mediaEquipe = registros.fold<int>(
              0, (s, d) => s + d.numeroPessoas) /
          registros.length;
      var frase = 'O diário registrou atividade em $diasComRegistro '
          'do${diasComRegistro > 1 ? 's' : ''} últimos 7 dias, com equipe '
          'média de ${mediaEquipe.toStringAsFixed(0)} '
          'pessoa${mediaEquipe >= 2 ? 's' : ''}';
      final diasChuva = registros
          .where((d) => d.clima.toLowerCase().contains('chuv'))
          .length;
      if (diasChuva > 0) {
        frase += '. Choveu em $diasChuva '
            'dia${diasChuva > 1 ? 's' : ''}, o que pode ter segurado o ritmo';
      }
      paragrafos.add('$frase.');
    }

    final emAndamento = cronograma.where((f) => f.emAndamento).toList();
    if (emAndamento.isNotEmpty) {
      paragrafos.add('A fase em andamento é '
          '${emAndamento.map((f) => '${f.nome} (${f.percentualConcluido}%)').join(' e ')}.');
    }
    final atrasadas = cronograma.where((f) => f.atrasada).toList();
    if (atrasadas.isNotEmpty) {
      paragrafos.add('Atenção: '
          '${atrasadas.map((f) => f.nome).join(', ')} '
          '${atrasadas.length > 1 ? 'passaram' : 'passou'} da data prevista '
          'sem chegar a 100%.');
      acoes.add('Atualizar (ou replanejar) a fase '
          '${atrasadas.map((f) => f.nome).join(', ')} no cronograma.');
    }

    if (paragrafos.isEmpty) return const [];
    return [
      SecaoRelatorio(
        tipo: TipoSecao.canteiro,
        titulo: 'Canteiro',
        paragrafos: paragrafos,
      ),
    ];
  }

  // ---------------------------------------------------------- Previsão

  static SecaoRelatorio _previsaoSecao(
    PrevisaoOrcamento previsao,
    ObraModel obra,
    List<String> acoes,
  ) {
    final paragrafos = <String>[];
    if (previsao.dadosSuficientes) {
      paragrafos.add(
          'Projetando o ritmo atual até o fim da obra, o gasto total '
          'chegaria a ${Formatters.moeda(previsao.gastoProjetadoFinal)}'
          '${previsao.dataEstouroPrevista != null ? ', com o orçamento estourando por volta de ${Formatters.data(previsao.dataEstouroPrevista!)}' : ''}.');
    }
    paragrafos.add(previsao.recomendacao);
    if (previsao.risco == NivelRisco.alto) {
      acoes.add('Frear novos gastos não essenciais e renegociar com '
          'fornecedores — risco real de estouro.');
    }
    return SecaoRelatorio(
      tipo: TipoSecao.previsao,
      titulo: 'Previsão do orçamento — ${previsao.risco.label}',
      paragrafos: paragrafos,
    );
  }
}
