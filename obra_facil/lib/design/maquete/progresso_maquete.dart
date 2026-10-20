import 'package:flutter/foundation.dart';

import '../../constants/app_constants.dart';
import '../../models/cronograma_fase_model.dart';

/// O avanço da obra do jeito que a maquete precisa: um número de 0 a 1 para
/// cada uma das 10 fases padrão ([AppConstants.fasesPadrao]), na ordem em que
/// a casa é construída.
///
/// Vem do cronograma ([ProgressoMaquete.doCronograma]): cada fase do
/// cronograma é casada com uma fase padrão pelo nome, sem acento e sem
/// diferença de caixa ("FUNDACAO" casa com "Fundação"). Fase com nome que não
/// é padrão (por exemplo "Muro de divisa") não tem peça na maquete e é
/// ignorada aqui; ela continua contando no [percentualObra], que é o mesmo
/// avanço físico mostrado no resto do app.
///
/// Fase padrão que não está no cronograma fica com 0 (aparece em desenho).
/// Se o cronograma tiver duas entradas com o mesmo nome padrão, vale a média.
@immutable
class ProgressoMaquete {
  /// Quantas fases a maquete tem (uma peça por fase padrão).
  static const int totalFases = 10;

  /// Avanço de cada fase, de 0 a 1, índice = posição em
  /// [AppConstants.fasesPadrao]. Sempre com [totalFases] itens.
  final List<double> avancoPorFase;

  /// Avanço físico da obra inteira (0 a 100): a média do percentual de todas
  /// as fases do cronograma, como nas outras telas do app.
  final int percentualObra;

  /// `true` quando não havia cronograma (ou ele estava vazio).
  final bool semCronograma;

  const ProgressoMaquete._(
    this.avancoPorFase,
    this.percentualObra,
    this.semCronograma,
  );

  /// Obra sem cronograma: só o tabuleiro, a casa inteira em desenho.
  static final ProgressoMaquete vazio = ProgressoMaquete._(
    List<double>.unmodifiable(List<double>.filled(totalFases, 0)),
    0,
    true,
  );

  /// Monta a partir do avanço de cada fase (0 a 1). Lista menor é completada
  /// com 0 e lista maior é cortada; valores fora de 0..1 são limitados.
  ///
  /// Sem [percentualObra], usa a média das 10 fases.
  factory ProgressoMaquete.fases(List<double> avanco, {int? percentualObra}) {
    final fases = List<double>.generate(
      totalFases,
      (i) => i < avanco.length ? _limitar(avanco[i]) : 0.0,
      growable: false,
    );
    final media = fases.fold<double>(0, (s, v) => s + v) / totalFases * 100;
    return ProgressoMaquete._(
      List<double>.unmodifiable(fases),
      (percentualObra ?? media.round()).clamp(0, 100),
      false,
    );
  }

  /// As primeiras [concluidas] fases prontas e as demais sem começar: o
  /// mesmo quadro da imagem `estado_XX` da reserva.
  factory ProgressoMaquete.estado(int concluidas) {
    final n = concluidas.clamp(0, totalFases);
    return ProgressoMaquete.fases([for (var i = 0; i < n; i++) 1.0]);
  }

  /// Converte o cronograma da obra. `null` ou vazio dá [vazio].
  factory ProgressoMaquete.doCronograma(List<CronogramaFaseModel>? cronograma) {
    if (cronograma == null || cronograma.isEmpty) return vazio;
    final soma = List<double>.filled(totalFases, 0);
    final contagem = List<int>.filled(totalFases, 0);
    for (final fase in cronograma) {
      final indice = indiceDaFase(fase.nome);
      if (indice == null) continue;
      soma[indice] += fase.percentualConcluido.clamp(0, 100) / 100;
      contagem[indice]++;
    }
    final fases = [
      for (var i = 0; i < totalFases; i++)
        contagem[i] == 0 ? 0.0 : soma[i] / contagem[i],
    ];
    final somaGeral = cronograma.fold<int>(
      0,
      (s, f) => s + f.percentualConcluido.clamp(0, 100),
    );
    return ProgressoMaquete.fases(
      fases,
      percentualObra: (somaGeral / cronograma.length).round(),
    );
  }

  /// Índice da fase padrão com esse nome (sem acento, sem caixa, espaços
  /// normalizados), ou `null` se o nome não é de uma fase padrão.
  static int? indiceDaFase(String nome) {
    final chave = _normalizar(nome);
    if (chave.isEmpty) return null;
    final i = _fasesNormalizadas.indexOf(chave);
    return i < 0 ? null : i;
  }

  /// Nome da fase como no app ("Instalações elétricas").
  static String nomeDaFase(int indice) => AppConstants.fasesPadrao[indice];

  /// Quantas fases seguidas, a partir da fundação, estão concluídas (0 a
  /// 10). É o número da imagem de reserva: `estado_03` = fundação, estrutura
  /// e alvenaria prontas.
  int get estadoReserva {
    var n = 0;
    while (n < totalFases && avancoPorFase[n] >= 1) {
      n++;
    }
    return n;
  }

  /// Fases começadas e não terminadas, em ordem.
  List<int> get fasesEmAndamento => [
        for (var i = 0; i < totalFases; i++)
          if (avancoPorFase[i] > 0 && avancoPorFase[i] < 1) i,
      ];

  /// A fase em que a obra está: a primeira em andamento; se nenhuma está em
  /// andamento, a primeira que falta. `null` com todas concluídas.
  int? get faseAtual {
    final andamento = fasesEmAndamento;
    if (andamento.isNotEmpty) return andamento.first;
    final proxima = estadoReserva;
    return proxima < totalFases ? proxima : null;
  }

  /// Todas as 10 fases concluídas.
  bool get concluida => estadoReserva == totalFases;

  /// Texto para o leitor de tela, por exemplo
  /// "Maquete da obra: Alvenaria em andamento, 38% da obra".
  String get descricao {
    if (semCronograma) {
      return 'Maquete da obra: sem cronograma, a casa toda em desenho';
    }
    if (concluida) {
      return 'Maquete da obra: todas as fases concluídas, '
          '$percentualObra% da obra';
    }
    final andamento = fasesEmAndamento;
    final String situacao;
    if (andamento.isNotEmpty) {
      situacao = '${_juntar(andamento.map(nomeDaFase).toList())} em andamento';
    } else {
      situacao = 'próxima fase ${nomeDaFase(faseAtual!)}';
    }
    return 'Maquete da obra: $situacao, $percentualObra% da obra';
  }

  @override
  bool operator ==(Object other) =>
      other is ProgressoMaquete &&
      other.percentualObra == percentualObra &&
      other.semCronograma == semCronograma &&
      listEquals(other.avancoPorFase, avancoPorFase);

  @override
  int get hashCode =>
      Object.hash(percentualObra, semCronograma, Object.hashAll(avancoPorFase));

  @override
  String toString() => 'ProgressoMaquete(${[
        for (final v in avancoPorFase) (v * 100).round()
      ].join(' ')} | obra $percentualObra%)';

  static double _limitar(double v) => v.isNaN ? 0 : v.clamp(0.0, 1.0);

  static String _juntar(List<String> nomes) {
    if (nomes.length == 1) return nomes.first;
    return '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
  }

  static final List<String> _fasesNormalizadas = [
    for (final f in AppConstants.fasesPadrao) _normalizar(f),
  ];

  static const String _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  static const String _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

  /// Minúsculas, sem acento e com os espaços normalizados.
  static String _normalizar(String texto) {
    final b = StringBuffer();
    for (final unidade in texto.toLowerCase().trim().runes) {
      final c = String.fromCharCode(unidade);
      final i = _comAcento.indexOf(c);
      b.write(i < 0 ? c : _semAcento[i]);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ');
  }
}
