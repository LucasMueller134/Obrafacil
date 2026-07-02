import '../../models/models.dart';
import '../../utils/formatters.dart';
import 'previsao_orcamento_service.dart';

/// IA on-device nº 3b — relatório semanal em linguagem natural.
///
/// Gera um resumo textual da semana a partir dos dados da obra
/// (lançamentos, diário, cronograma e previsão de orçamento), usando
/// geração de texto baseada em regras — tudo no aparelho.
class RelatorioSemanalService {
  static String gerar({
    required ObraModel obra,
    required List<LancamentoModel> lancamentos,
    required List<DiarioEntradaModel> diario,
    required List<CronogramaFaseModel> cronograma,
    DateTime? referencia,
  }) {
    final agora = referencia ?? DateTime.now();
    final inicioSemana = agora.subtract(Duration(days: agora.weekday - 1));
    final inicio = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
    final inicioAnterior = inicio.subtract(const Duration(days: 7));

    final aprovados = lancamentos
        .where((l) => l.status == StatusLancamento.aprovado)
        .toList();
    final daSemana = aprovados
        .where((l) => !l.data.isBefore(inicio) && l.data.isBefore(inicio.add(const Duration(days: 7))))
        .toList();
    final semanaAnterior = aprovados
        .where((l) => !l.data.isBefore(inicioAnterior) && l.data.isBefore(inicio))
        .toList();
    final pendentes = lancamentos
        .where((l) => l.status == StatusLancamento.pendente)
        .toList();

    final previsao = PrevisaoOrcamentoService.calcular(
      obra: obra,
      lancamentos: lancamentos,
    );

    final b = StringBuffer();
    b.writeln('RELATÓRIO SEMANAL — ${obra.nome.toUpperCase()}');
    b.writeln('Semana de ${Formatters.data(inicio)} a '
        '${Formatters.data(inicio.add(const Duration(days: 6)))}');
    b.writeln();

    _secaoFinanceiro(b, obra, daSemana, semanaAnterior, previsao);
    _secaoPendencias(b, pendentes);
    _secaoAvancoFisico(b, cronograma);
    _secaoCanteiro(b, diario, inicio);
    _secaoRecomendacao(b, previsao);

    return b.toString().trimRight();
  }

  static void _secaoFinanceiro(
    StringBuffer b,
    ObraModel obra,
    List<LancamentoModel> daSemana,
    List<LancamentoModel> anterior,
    PrevisaoOrcamento previsao,
  ) {
    b.writeln('💰 FINANCEIRO');
    final totalSemana = daSemana.fold<double>(0, (s, l) => s + l.valor);
    final totalAnterior = anterior.fold<double>(0, (s, l) => s + l.valor);

    if (daSemana.isEmpty) {
      b.writeln('Nenhum gasto aprovado nesta semana.');
    } else {
      b.writeln('A semana fechou com ${Formatters.moeda(totalSemana)} em '
          '${daSemana.length} lançamento${daSemana.length > 1 ? 's' : ''} '
          'aprovado${daSemana.length > 1 ? 's' : ''}.');

      final porCategoria = <CategoriaCusto, double>{};
      for (final l in daSemana) {
        porCategoria[l.categoria] = (porCategoria[l.categoria] ?? 0) + l.valor;
      }
      final maior = porCategoria.entries
          .reduce((a, c) => c.value > a.value ? c : a);
      b.writeln('O maior peso foi ${maior.key.label.toLowerCase()} '
          '(${Formatters.moeda(maior.value)}, '
          '${(maior.value / totalSemana * 100).toStringAsFixed(0)}% da semana).');
    }

    if (totalAnterior > 0 && daSemana.isNotEmpty) {
      final variacao = (totalSemana - totalAnterior) / totalAnterior * 100;
      if (variacao.abs() >= 5) {
        b.writeln(variacao > 0
            ? 'Os gastos subiram ${variacao.toStringAsFixed(0)}% em relação à semana passada.'
            : 'Os gastos caíram ${variacao.abs().toStringAsFixed(0)}% em relação à semana passada.');
      } else {
        b.writeln('Os gastos se mantiveram estáveis em relação à semana passada.');
      }
    }

    b.writeln('Total da obra: ${Formatters.moeda(previsao.gastoAtual)} de '
        '${Formatters.moeda(obra.orcamento)} '
        '(${(previsao.percentualGasto * 100).toStringAsFixed(0)}% do orçamento).');
    b.writeln();
  }

  static void _secaoPendencias(StringBuffer b, List<LancamentoModel> pendentes) {
    if (pendentes.isEmpty) return;
    final total = pendentes.fold<double>(0, (s, l) => s + l.valor);
    b.writeln('⏳ PENDÊNCIAS');
    b.writeln('${pendentes.length} lançamento${pendentes.length > 1 ? 's' : ''} '
        'aguardando aprovação, somando ${Formatters.moeda(total)}.');
    b.writeln();
  }

  static void _secaoAvancoFisico(
      StringBuffer b, List<CronogramaFaseModel> cronograma) {
    if (cronograma.isEmpty) return;
    b.writeln('🏗️ AVANÇO FÍSICO');
    final media = cronograma.fold<int>(0, (s, f) => s + f.percentualConcluido) /
        cronograma.length;
    b.writeln('Progresso geral da obra: ${media.toStringAsFixed(0)}%.');

    final emAndamento = cronograma.where((f) => f.emAndamento).toList();
    for (final fase in emAndamento) {
      b.writeln('Fase atual: ${fase.nome} (${fase.percentualConcluido}%).');
    }
    final atrasadas = cronograma.where((f) => f.atrasada).toList();
    if (atrasadas.isNotEmpty) {
      b.writeln('⚠️ ${atrasadas.length} fase${atrasadas.length > 1 ? 's' : ''} '
          'atrasada${atrasadas.length > 1 ? 's' : ''}: '
          '${atrasadas.map((f) => f.nome).join(', ')}.');
    }
    b.writeln();
  }

  static void _secaoCanteiro(
      StringBuffer b, List<DiarioEntradaModel> diario, DateTime inicio) {
    final daSemana = diario
        .where((d) => !d.data.isBefore(inicio) &&
            d.data.isBefore(inicio.add(const Duration(days: 7))))
        .toList();
    if (daSemana.isEmpty) return;

    b.writeln('📋 CANTEIRO');
    b.writeln('${daSemana.length} registro${daSemana.length > 1 ? 's' : ''} '
        'no diário de obra.');

    final diasChuva = daSemana
        .where((d) => d.clima.toLowerCase().contains('chuv'))
        .length;
    if (diasChuva > 0) {
      b.writeln('Houve chuva em $diasChuva dia${diasChuva > 1 ? 's' : ''} — '
          'possível impacto no cronograma.');
    }
    final mediaPessoas =
        daSemana.fold<int>(0, (s, d) => s + d.numeroPessoas) / daSemana.length;
    if (mediaPessoas > 0) {
      b.writeln('Equipe média no canteiro: '
          '${mediaPessoas.toStringAsFixed(0)} pessoa${mediaPessoas >= 2 ? 's' : ''}/dia.');
    }
    b.writeln();
  }

  static void _secaoRecomendacao(StringBuffer b, PrevisaoOrcamento previsao) {
    b.writeln('🔮 PREVISÃO DO ORÇAMENTO — ${previsao.risco.label.toUpperCase()}');
    if (previsao.dadosSuficientes &&
        previsao.dataEstouroPrevista != null) {
      b.writeln('Estimativa de estouro: '
          '${Formatters.data(previsao.dataEstouroPrevista!)}.');
    }
    b.writeln(previsao.recomendacao);
  }
}
