import '../../models/lancamento_model.dart';
import '../../models/obra_model.dart';

enum NivelRisco {
  ok,
  atencao,
  alto;

  String get label => switch (this) {
        NivelRisco.ok => 'Sob controle',
        NivelRisco.atencao => 'Atenção',
        NivelRisco.alto => 'Risco de estouro',
      };
}

class PrevisaoOrcamento {
  final NivelRisco risco;
  final double gastoAtual;
  final double orcamento;

  /// Gasto projetado para a data prevista de término da obra.
  final double gastoProjetadoFinal;

  /// Data estimada em que o gasto ultrapassa o orçamento (null = não estoura).
  final DateTime? dataEstouroPrevista;

  /// Média de gasto por dia estimada pela regressão.
  final double gastoDiarioMedio;

  /// Quantos pontos (dias com dados) alimentaram o modelo.
  final int amostras;
  final String recomendacao;

  const PrevisaoOrcamento({
    required this.risco,
    required this.gastoAtual,
    required this.orcamento,
    required this.gastoProjetadoFinal,
    this.dataEstouroPrevista,
    required this.gastoDiarioMedio,
    required this.amostras,
    required this.recomendacao,
  });

  double get percentualGasto =>
      orcamento <= 0 ? 0 : (gastoAtual / orcamento).clamp(0, 2);

  bool get dadosSuficientes => amostras >= 3;
}

/// IA on-device nº 3 — previsão de estouro de orçamento.
///
/// Ajusta uma regressão linear (mínimos quadrados) sobre o gasto acumulado
/// da obra ao longo dos dias e projeta a curva até o fim previsto. Roda em
/// Dart puro, no aparelho, sem servidor.
class PrevisaoOrcamentoService {
  static PrevisaoOrcamento calcular({
    required ObraModel obra,
    required List<LancamentoModel> lancamentos,
  }) {
    final aprovados = lancamentos
        .where((l) => l.status == StatusLancamento.aprovado)
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    final gastoAtual =
        aprovados.fold<double>(0, (soma, l) => soma + l.valor);

    // Série: x = dias desde o início da obra, y = gasto acumulado no dia.
    final pontos = <(double, double)>[];
    var acumulado = 0.0;
    for (final l in aprovados) {
      acumulado += l.valor;
      final dias = l.data.difference(obra.dataInicio).inDays.toDouble();
      final x = dias < 0 ? 0.0 : dias;
      if (pontos.isNotEmpty && pontos.last.$1 == x) {
        pontos[pontos.length - 1] = (x, acumulado);
      } else {
        pontos.add((x, acumulado));
      }
    }

    if (pontos.length < 3) {
      return PrevisaoOrcamento(
        risco: NivelRisco.ok,
        gastoAtual: gastoAtual,
        orcamento: obra.orcamento,
        gastoProjetadoFinal: gastoAtual,
        gastoDiarioMedio: 0,
        amostras: pontos.length,
        recomendacao:
            'Ainda há poucos lançamentos aprovados para prever o comportamento '
            'do orçamento. Continue registrando os gastos.',
      );
    }

    // Regressão linear y = a + b·x por mínimos quadrados.
    final n = pontos.length;
    final somaX = pontos.fold<double>(0, (s, p) => s + p.$1);
    final somaY = pontos.fold<double>(0, (s, p) => s + p.$2);
    final somaXY = pontos.fold<double>(0, (s, p) => s + p.$1 * p.$2);
    final somaX2 = pontos.fold<double>(0, (s, p) => s + p.$1 * p.$1);
    final denominador = n * somaX2 - somaX * somaX;
    final b = denominador == 0 ? 0.0 : (n * somaXY - somaX * somaY) / denominador;
    final a = (somaY - b * somaX) / n;

    final duracao = obra.duracaoDias.toDouble();
    final gastoProjetadoFinal =
        b <= 0 ? gastoAtual : (a + b * duracao).clamp(gastoAtual, double.infinity);

    DateTime? dataEstouro;
    if (b > 0 && obra.orcamento > 0) {
      final xEstouro = (obra.orcamento - a) / b;
      final jaEstourou = gastoAtual >= obra.orcamento;
      if (jaEstourou) {
        dataEstouro = DateTime.now();
      } else if (xEstouro > 0) {
        dataEstouro =
            obra.dataInicio.add(Duration(days: xEstouro.ceil()));
      }
    }

    final NivelRisco risco;
    if (gastoAtual >= obra.orcamento ||
        (dataEstouro != null &&
            !dataEstouro.isAfter(obra.previsaoTermino))) {
      risco = NivelRisco.alto;
    } else if (gastoProjetadoFinal >= obra.orcamento * 0.9) {
      risco = NivelRisco.atencao;
    } else {
      risco = NivelRisco.ok;
    }

    return PrevisaoOrcamento(
      risco: risco,
      gastoAtual: gastoAtual,
      orcamento: obra.orcamento,
      gastoProjetadoFinal: gastoProjetadoFinal.toDouble(),
      dataEstouroPrevista: dataEstouro,
      gastoDiarioMedio: b < 0 ? 0 : b,
      amostras: n,
      recomendacao: _recomendacao(risco, obra, gastoProjetadoFinal.toDouble()),
    );
  }

  static String _recomendacao(
      NivelRisco risco, ObraModel obra, double projetado) {
    switch (risco) {
      case NivelRisco.alto:
        final excesso = projetado - obra.orcamento;
        return 'No ritmo atual de gastos, o orçamento estoura antes do fim da '
            'obra${excesso > 0 ? ' (excesso projetado de aproximadamente '
                'R\$ ${excesso.toStringAsFixed(0)})' : ''}. Reveja os custos '
            'de material e renegocie com fornecedores agora — quanto antes a '
            'correção, menor o impacto.';
      case NivelRisco.atencao:
        return 'A projeção indica que a obra deve consumir mais de 90% do '
            'orçamento. Monitore os lançamentos com atenção e evite compras '
            'não planejadas nas próximas semanas.';
      case NivelRisco.ok:
        return 'O ritmo de gastos está compatível com o orçamento planejado. '
            'Mantenha os registros em dia para a previsão continuar precisa.';
    }
  }
}
