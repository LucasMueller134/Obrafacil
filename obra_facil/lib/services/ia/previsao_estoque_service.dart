import '../../models/diario_entrada_model.dart';
import '../../models/estoque_item_model.dart';
import '../../models/movimento_estoque_model.dart';

class PrevisaoEstoque {
  /// Consumo estimado por dia, na unidade do item.
  final double consumoDiario;
  final int diasRestantes;
  final DateTime dataTermino;

  /// True quando o modelo usou o tamanho da equipe (diário) no ajuste.
  final bool consideraEquipe;

  /// Quantas saídas de estoque alimentaram o modelo.
  final int amostras;

  const PrevisaoEstoque({
    required this.consumoDiario,
    required this.diasRestantes,
    required this.dataTermino,
    required this.consideraEquipe,
    required this.amostras,
  });

  bool get critico => diasRestantes <= 7;
  bool get atencao => diasRestantes <= 14;
}

/// IA on-device nº 3c — previsão de término de material.
///
/// Aprende o ritmo real de consumo da obra a partir do histórico de
/// saídas do estoque, dando peso maior às últimas duas semanas (o ritmo
/// recente vale mais que o antigo). Quando o diário de obra tem dados de
/// equipe, o consumo é ajustado pela proporção entre o tamanho atual da
/// equipe e o tamanho médio do período — mais gente no canteiro, mais
/// consumo. Tudo calculado no aparelho.
class PrevisaoEstoqueService {
  static PrevisaoEstoque? calcular({
    required EstoqueItemModel item,
    required List<MovimentoEstoqueModel> movimentos,
    required List<DiarioEntradaModel> diario,
    DateTime? referencia,
  }) {
    final agora = referencia ?? DateTime.now();
    if (item.quantidade <= 0) return null;

    final janela = agora.subtract(const Duration(days: 90));
    final saidas = movimentos
        .where((m) =>
            m.tipo == TipoMovimentoEstoque.saida &&
            m.material.toLowerCase() == item.material.toLowerCase() &&
            m.data.isAfter(janela))
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    if (saidas.length < 2) return null;

    final primeiraSaida = saidas.first.data;
    final diasPeriodo =
        agora.difference(primeiraSaida).inDays.clamp(1, 90);
    final consumoTotal =
        saidas.fold<double>(0, (s, m) => s + m.quantidade);
    final taxaGeral = consumoTotal / diasPeriodo;

    // Ritmo recente (14 dias) pesa mais: a obra muda de fase e o
    // consumo muda junto — o modelo "aprende" acompanhando.
    final inicioRecente = agora.subtract(const Duration(days: 14));
    final saidasRecentes =
        saidas.where((m) => m.data.isAfter(inicioRecente)).toList();
    double taxa;
    if (saidasRecentes.length >= 2) {
      final consumoRecente =
          saidasRecentes.fold<double>(0, (s, m) => s + m.quantidade);
      final diasRecentes = diasPeriodo.clamp(1, 14);
      taxa = 0.65 * (consumoRecente / diasRecentes) + 0.35 * taxaGeral;
    } else {
      taxa = taxaGeral;
    }

    // Ajuste pela equipe: se o canteiro está com mais gente do que a
    // média do período, o material tende a acabar antes.
    var consideraEquipe = false;
    final entradasDiario = diario
        .where((d) => d.data.isAfter(janela) && d.numeroPessoas > 0)
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
    if (entradasDiario.length >= 3) {
      final mediaPeriodo = entradasDiario.fold<int>(
              0, (s, d) => s + d.numeroPessoas) /
          entradasDiario.length;
      final recentes = entradasDiario.length >= 5
          ? entradasDiario.sublist(entradasDiario.length - 5)
          : entradasDiario;
      final mediaRecente =
          recentes.fold<int>(0, (s, d) => s + d.numeroPessoas) /
              recentes.length;
      if (mediaPeriodo > 0 && mediaRecente > 0) {
        taxa *= mediaRecente / mediaPeriodo;
        consideraEquipe = true;
      }
    }

    if (taxa <= 0) return null;

    final dias = (item.quantidade / taxa).ceil().clamp(0, 365);
    return PrevisaoEstoque(
      consumoDiario: taxa,
      diasRestantes: dias,
      dataTermino: agora.add(Duration(days: dias)),
      consideraEquipe: consideraEquipe,
      amostras: saidas.length,
    );
  }
}
