import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tempos de um conjunto de quadros, em milissegundos.
///
/// O "quadro" de cada frame é o maior entre o tempo de construção (thread de
/// UI, onde o flutter_scene monta e codifica a cena) e o de rasterização
/// (thread de raster, onde a GPU desenha): as duas threads trabalham em
/// paralelo, então é a mais lenta que decide se o quadro cabe nos 16,7 ms de
/// 60 fps.
@immutable
class EstatisticaQuadros {
  final int quadros;
  final double p50Ms;
  final double p90Ms;
  final double p90ConstrucaoMs;
  final double p90RasterMs;

  const EstatisticaQuadros({
    required this.quadros,
    required this.p50Ms,
    required this.p90Ms,
    required this.p90ConstrucaoMs,
    required this.p90RasterMs,
  });

  /// Quadros por segundo que o aparelho sustenta no quadro mediano, limitado
  /// a 60 (a maquete pede no máximo 60).
  double get fpsMediano => math.min(60, 1000 / math.max(p50Ms, 1e-3));

  /// Percentil pelo método do posto mais próximo (sem interpolar).
  static double percentil(List<double> valores, double p) {
    if (valores.isEmpty) return 0;
    final ordenados = [...valores]..sort();
    final posto = (p * ordenados.length).ceil().clamp(1, ordenados.length);
    return ordenados[posto - 1];
  }

  static EstatisticaQuadros? de(List<double> construcao, List<double> raster) {
    if (construcao.isEmpty) return null;
    final quadro = [
      for (var i = 0; i < construcao.length; i++)
        math.max(construcao[i], raster[i]),
    ];
    return EstatisticaQuadros(
      quadros: quadro.length,
      p50Ms: percentil(quadro, 0.5),
      p90Ms: percentil(quadro, 0.9),
      p90ConstrucaoMs: percentil(construcao, 0.9),
      p90RasterMs: percentil(raster, 0.9),
    );
  }

  @override
  String toString() => '$quadros quadros, p50 ${p50Ms.toStringAsFixed(1)} ms, '
      'p90 ${p90Ms.toStringAsFixed(1)} ms '
      '(UI ${p90ConstrucaoMs.toStringAsFixed(1)}, '
      'raster ${p90RasterMs.toStringAsFixed(1)})';
}

/// Junta os tempos de quadro (de `SchedulerBinding.addTimingsCallback`) e
/// decide se o aparelho aguenta a maquete em tempo real.
///
/// Os quadros de antes de [inicioUs] (a tela de carregamento, o aquecimento
/// dos shaders) não contam: o motor entrega os tempos em lotes, e o primeiro
/// lote depois da revelação ainda traz quadros de antes dela. Dos que
/// contam, os primeiros [descartar] são ignorados (o quadro da revelação
/// ainda carrega trabalho de preparo) e os [quadrosParaDecidir] seguintes
/// formam a medição inicial. Se o p90 dela passar de [limiteP90Ms], a
/// maquete troca para a imagem. Depois disso, os quadros continuam entrando
/// numa janela móvel de [janelaRecente] para o painel de depuração.
///
/// A medição também pode ser [encerrar]da antes (prazo estourado): com pelo
/// menos [minimoParaDecidir] quadros ela decide com o que tem; com menos,
/// termina sem decisão ([decidido] sem [inicial]), e o 3D fica sem guardar
/// nada.
class MedidorQuadros {
  MedidorQuadros({
    this.quadrosParaDecidir = 90,
    this.limiteP90Ms = 20,
    this.descartar = 3,
    this.janelaRecente = 120,
    this.minimoParaDecidir = 30,
  });

  final int quadrosParaDecidir;
  final double limiteP90Ms;
  final int descartar;
  final int janelaRecente;
  final int minimoParaDecidir;

  final List<double> _construcao = [];
  final List<double> _raster = [];
  final List<double> _construcaoRecente = [];
  final List<double> _rasterRecente = [];
  int _descartados = 0;
  EstatisticaQuadros? _inicial;
  bool _encerrada = false;

  /// Começo da contagem, em microssegundos no relógio dos [ui.FrameTiming]
  /// (o mesmo de `SchedulerBinding.currentSystemFrameTimeStamp`). `null`
  /// conta tudo.
  int? inicioUs;

  /// Diferença acima da qual os dois relógios não são o mesmo (aí o filtro
  /// por [inicioUs] é desligado em vez de descartar tudo).
  static const int _relogiosDiferentesUs = 10 * 60 * 1000 * 1000;

  /// Quadros já contados na medição inicial.
  int get quadrosMedidos => _inicial?.quadros ?? _construcao.length;

  /// A medição inicial terminou (com ou sem decisão, ver [encerrar]).
  bool get decidido => _inicial != null || _encerrada;

  /// Resultado da medição inicial: null até [decidido], e também quando ela
  /// foi encerrada com menos de [minimoParaDecidir] quadros.
  EstatisticaQuadros? get inicial => _inicial;

  /// Parcial da medição inicial, enquanto ela não termina.
  EstatisticaQuadros? get parcial =>
      _inicial ?? EstatisticaQuadros.de(_construcao, _raster);

  /// Janela móvel dos últimos quadros.
  EstatisticaQuadros? get recente =>
      EstatisticaQuadros.de(_construcaoRecente, _rasterRecente);

  /// A medição inicial deu p90 acima do limite.
  bool get lento => _inicial != null && _inicial!.p90Ms > limiteP90Ms;

  /// Volta a descartar os próximos quadros (depois de o app voltar do
  /// segundo plano, por exemplo). O novo [inicioUs] vem de quem chama.
  void pularProximos() {
    _descartados = 0;
    inicioUs = null;
  }

  /// Registra um quadro do motor, se ele é de depois de [inicioUs].
  /// Devolve `true` no quadro que fecha a medição inicial.
  bool registrarTiming(ui.FrameTiming quadro) {
    final inicio = inicioUs;
    if (inicio != null) {
      final d =
          quadro.timestampInMicroseconds(ui.FramePhase.buildStart) - inicio;
      if (d < 0 && d > -_relogiosDiferentesUs) return false;
    }
    return registrar(quadro.buildDuration, quadro.rasterDuration);
  }

  /// Registra um quadro. Devolve `true` no quadro que fecha a medição
  /// inicial.
  bool registrar(Duration construcao, Duration raster) {
    final c = construcao.inMicroseconds / 1000;
    final r = raster.inMicroseconds / 1000;
    _construcaoRecente.add(c);
    _rasterRecente.add(r);
    if (_construcaoRecente.length > janelaRecente) {
      _construcaoRecente.removeAt(0);
      _rasterRecente.removeAt(0);
    }
    if (decidido) return false;
    if (_descartados < descartar) {
      _descartados++;
      return false;
    }
    _construcao.add(c);
    _raster.add(r);
    if (_construcao.length < quadrosParaDecidir) return false;
    _inicial = EstatisticaQuadros.de(_construcao, _raster);
    return true;
  }

  /// Encerra a medição inicial com os quadros que já entraram. Devolve
  /// `false` se ela já tinha terminado.
  bool encerrar() {
    if (decidido) return false;
    _encerrada = true;
    if (_construcao.length >= minimoParaDecidir) {
      _inicial = EstatisticaQuadros.de(_construcao, _raster);
    }
    return true;
  }
}

/// A decisão "este aparelho não aguenta a maquete em tempo real", guardada
/// em `shared_preferences` para a maquete já abrir na imagem nas próximas
/// vezes. Vale por [validade]; depois o aparelho é medido de novo (uma
/// atualização do sistema pode mudar o desempenho). Uma decisão com data no
/// futuro (relógio do aparelho adiantado quando ela foi gravada) não vale:
/// sem isso ela só expiraria quando o relógio alcançasse aquela data.
abstract final class DecisaoDesempenho {
  static const String chave = 'maquete_obra.quadros_lentos.v1';
  static const Duration validade = Duration(days: 30);

  /// Quanto a data gravada pode estar à frente do relógio (fuso, ajuste
  /// automático da hora) e ainda valer.
  static const Duration _folgaDoRelogio = Duration(days: 1);

  /// O p90 (ms) guardado, ou `null` se não há decisão válida. Nunca lança:
  /// sem `shared_preferences` (testes, plataforma sem plugin) é `null`.
  static Future<double?> ler({DateTime? agora}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(chave);
      if (texto == null) return null;
      final dados = jsonDecode(texto) as Map<String, dynamic>;
      final em = DateTime.tryParse(dados['em'] as String? ?? '');
      final p90 = (dados['p90'] as num?)?.toDouble();
      if (em == null || p90 == null) return null;
      final idade = (agora ?? DateTime.now()).difference(em);
      if (idade > validade || idade < -_folgaDoRelogio) return null;
      return p90;
    } catch (_) {
      return null;
    }
  }

  static Future<void> gravar(double p90Ms, {DateTime? agora}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        chave,
        jsonEncode({
          'p90': double.parse(p90Ms.toStringAsFixed(2)),
          'em': (agora ?? DateTime.now()).toIso8601String(),
        }),
      );
    } catch (_) {
      // Sem onde guardar: a maquete só mede de novo na próxima vez.
    }
  }

  static Future<void> esquecer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(chave);
    } catch (_) {}
  }
}
