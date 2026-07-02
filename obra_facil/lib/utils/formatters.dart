import 'package:intl/intl.dart';

/// Formatação de valores para exibição (pt_BR).
abstract class Formatters {
  static final NumberFormat _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final NumberFormat _moedaCompacta =
      NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$');
  static final DateFormat _data = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dataCurta = DateFormat('dd/MM', 'pt_BR');
  static final DateFormat _dataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final DateFormat _diaSemana = DateFormat('EEEE, dd/MM', 'pt_BR');

  static String moeda(double valor) => _moeda.format(valor);

  static String moedaCompacta(double valor) => _moedaCompacta.format(valor);

  static String data(DateTime d) => _data.format(d);

  static String dataCurta(DateTime d) => _dataCurta.format(d);

  static String dataHora(DateTime d) => _dataHora.format(d);

  static String diaSemana(DateTime d) {
    final s = _diaSemana.format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  static String percentual(double fracao) =>
      '${(fracao * 100).toStringAsFixed(0)}%';

  /// Converte texto digitado ("1.234,56" ou "1234.56") em double.
  static double? parseValor(String texto) {
    var t = texto.trim().replaceAll('R\$', '').trim();
    if (t.isEmpty) return null;
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(t);
  }

  static String quantidade(double q) {
    if (q == q.roundToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(2).replaceAll('.', ',');
  }
}
