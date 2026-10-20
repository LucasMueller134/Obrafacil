import 'package:flutter/foundation.dart';

import 'medidor_quadros.dart';

/// Como a maquete está sendo mostrada.
enum ModoMaquete {
  /// Ainda decidindo (lendo a decisão guardada, iniciando o Flutter GPU,
  /// carregando a cena). Enquanto isso aparece a imagem.
  carregando,

  /// 3D em tempo real (flutter_scene).
  tempoReal,

  /// Imagem pré-renderizada (`assets/3d/reserva/`).
  imagem,
}

/// Por que a maquete está na imagem (ou [nenhum] no tempo real).
enum MotivoMaquete {
  nenhum('—'),
  forcada('imagem forçada pelo parâmetro forcarReserva'),
  reduzirAnimacoes('"reduzir animações" ligado no sistema'),
  semSuporte('Flutter GPU, o modelo ou a cena não iniciaram'),
  quadrosLentos('quadros lentos na medição (p90 acima do limite)'),
  decisaoGuardada('aparelho já medido como lento (decisão guardada)');

  const MotivoMaquete(this.texto);

  /// Explicação curta, para o painel de depuração.
  final String texto;
}

/// O retrato do momento da maquete: modo, motivo e tempos de quadro. Usado
/// pelo painel de depuração (toque longo na maquete em modo debug) e por
/// quem quiser medir o desempenho no aparelho
/// (`MaqueteObra.diagnosticoGlobal`).
@immutable
class DiagnosticoMaquete {
  final ModoMaquete modo;
  final MotivoMaquete motivo;

  /// Detalhe do motivo: a mensagem da exceção, o p90 que reprovou...
  final String? detalhe;

  /// O 3D já apareceu na tela (passou do aquecimento dos shaders).
  final bool revelada;

  /// Estado da imagem de reserva em uso (0 a 10).
  final int estadoReserva;

  /// Quadros contados na medição inicial.
  final int quadrosMedidos;

  /// Quadros que a medição inicial precisa para decidir.
  final int quadrosParaDecidir;

  /// Medição inicial (parcial enquanto não termina).
  final EstatisticaQuadros? medicao;

  /// A medição inicial terminou.
  final bool medicaoConcluida;

  /// Últimos quadros (janela móvel), para medir enquanto se gira.
  final EstatisticaQuadros? recente;

  /// Tempo de CPU do último `Scene.render` (ms) e chamadas de desenho.
  final double? cpuCenaMs;
  final int? chamadasDeDesenho;

  const DiagnosticoMaquete({
    this.modo = ModoMaquete.carregando,
    this.motivo = MotivoMaquete.nenhum,
    this.detalhe,
    this.revelada = false,
    this.estadoReserva = 0,
    this.quadrosMedidos = 0,
    this.quadrosParaDecidir = 90,
    this.medicao,
    this.medicaoConcluida = false,
    this.recente,
    this.cpuCenaMs,
    this.chamadasDeDesenho,
  });

  DiagnosticoMaquete copiar({
    ModoMaquete? modo,
    MotivoMaquete? motivo,
    String? detalhe,
    bool limparDetalhe = false,
    bool? revelada,
    int? estadoReserva,
    int? quadrosMedidos,
    int? quadrosParaDecidir,
    EstatisticaQuadros? medicao,
    bool? medicaoConcluida,
    EstatisticaQuadros? recente,
    double? cpuCenaMs,
    int? chamadasDeDesenho,
  }) =>
      DiagnosticoMaquete(
        modo: modo ?? this.modo,
        motivo: motivo ?? this.motivo,
        detalhe: limparDetalhe ? null : (detalhe ?? this.detalhe),
        revelada: revelada ?? this.revelada,
        estadoReserva: estadoReserva ?? this.estadoReserva,
        quadrosMedidos: quadrosMedidos ?? this.quadrosMedidos,
        quadrosParaDecidir: quadrosParaDecidir ?? this.quadrosParaDecidir,
        medicao: medicao ?? this.medicao,
        medicaoConcluida: medicaoConcluida ?? this.medicaoConcluida,
        recente: recente ?? this.recente,
        cpuCenaMs: cpuCenaMs ?? this.cpuCenaMs,
        chamadasDeDesenho: chamadasDeDesenho ?? this.chamadasDeDesenho,
      );

  /// Linhas de texto do painel de depuração.
  List<String> get linhas => [
        'modo: ${modo.name}${modo == ModoMaquete.tempoReal && !revelada ? ' (aquecendo)' : ''}',
        if (motivo != MotivoMaquete.nenhum) 'motivo: ${motivo.texto}',
        if (detalhe != null) 'detalhe: $detalhe',
        'imagem: estado_${estadoReserva.toString().padLeft(2, '0')}',
        if (modo == ModoMaquete.tempoReal || medicao != null)
          'medição: $quadrosMedidos/$quadrosParaDecidir'
              '${medicaoConcluida ? ' (concluída)' : ''}',
        if (medicao != null)
          '  p50 ${_ms(medicao!.p50Ms)} · p90 ${_ms(medicao!.p90Ms)} '
              '(UI ${_ms(medicao!.p90ConstrucaoMs)} · raster ${_ms(medicao!.p90RasterMs)})',
        if (recente != null)
          'recentes (${recente!.quadros}): p50 ${_ms(recente!.p50Ms)} · '
              'p90 ${_ms(recente!.p90Ms)} · ~${recente!.fpsMediano.toStringAsFixed(0)} fps',
        if (cpuCenaMs != null)
          'cena: CPU ${_ms(cpuCenaMs!)} · ${chamadasDeDesenho ?? '?'} desenhos',
      ];

  static String _ms(double v) => '${v.toStringAsFixed(1)} ms';

  @override
  String toString() => linhas.join('\n');
}
