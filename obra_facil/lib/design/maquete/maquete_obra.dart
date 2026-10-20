import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';

import 'cena_maquete.dart';
import 'diagnostico_maquete.dart';
import 'medidor_quadros.dart';
import 'plano_maquete.dart';
import 'progresso_maquete.dart';

/// Carrega a cena 3D; troca-se nos testes para simular o carregamento.
typedef CarregadorCenaMaquete = Future<Cena3dMaquete> Function({
  required TemaMaquete tema,
});

/// A maquete 3D da obra (design system Prancheta, seção 7): o que já foi
/// construído em material de verdade, o que falta em desenho tracejado.
///
/// Em tempo real com flutter_scene (Flutter GPU sobre Impeller). Mostra a
/// imagem pré-renderizada do mesmo quadro (`assets/3d/reserva/`) enquanto o
/// 3D carrega, e fica nela quando:
/// * o Flutter GPU, o modelo ou a cena não iniciam (exceção; é o que
///   acontece nos testes e em aparelho sem Impeller), ou a carga passa de
///   [tempoMaximoDeCarga];
/// * desenhar a cena lança (no quadro ou no aquecimento dos shaders);
/// * o 3D não aparece em [tempoMaximoDeAquecimento] (aquecimento que não
///   termina);
/// * o sistema pede "reduzir animações" ([MediaQuery.disableAnimationsOf]):
///   aí o Flutter GPU nem é iniciado;
/// * os primeiros 90 quadros desenhados com o 3D têm p90 acima de 20 ms (a
///   decisão fica guardada por 30 dias, ver [DecisaoDesempenho]);
/// * [forcarReserva] é `true`.
///
/// Não gira sozinha (bateria): arrastar na horizontal gira em volta do eixo
/// vertical. A cena só é redesenhada sem parar durante a medição inicial
/// (~1,5 s, nunca mais que [prazoDaMedicao]); depois, só quando algo muda
/// (arrasto, avanço, tema), e não quando só o pai reconstrói. Rota encoberta
/// ou app em segundo plano param o relógio dela ([TickerMode]). A medição só
/// conta os quadros em que a cena andou: quadros de outra tela (uma rota por
/// cima, a transição) não decidem nada.
///
/// Toque longo abre o painel de depuração (em modo debug, com
/// `--dart-define=MAQUETE_DEPURACAO=true` ou com [painelDepuracao]): modo,
/// motivo e tempos de quadro. O mesmo retrato sai em [diagnostico] e em
/// [MaqueteObra.diagnosticoGlobal].
///
/// Ocupa a largura disponível e [altura] de altura; a imagem e o 3D usam o
/// mesmo enquadramento (a imagem inteira cabe na caixa, sobra papel dos
/// lados ou em cima e embaixo).
class MaqueteObra extends StatefulWidget {
  const MaqueteObra({
    super.key,
    required this.progresso,
    this.altura = 220,
    this.interativa = true,
    this.legenda = true,
    this.forcarReserva = false,
    this.painelDepuracao,
    this.cortarPorDesempenho,
    this.diagnostico,
  });

  /// Avanço por fase (veja [ProgressoMaquete.doCronograma]).
  final ProgressoMaquete progresso;

  /// Altura da maquete em pontos lógicos.
  final double altura;

  /// Arrastar na horizontal gira a maquete (só no tempo real).
  final bool interativa;

  /// Legenda "ainda não construído" com o traço do fantasma, no canto de
  /// baixo, enquanto houver fase por fazer.
  final bool legenda;

  /// Sempre a imagem, nunca o 3D.
  final bool forcarReserva;

  /// Permite o painel de depuração no toque longo. `null`: em modo debug ou
  /// com `--dart-define=MAQUETE_DEPURACAO=true` (para medir num build de
  /// profile, onde os tempos de quadro valem).
  final bool? painelDepuracao;

  /// Troca para a imagem (e guarda a decisão) quando a medição reprova o
  /// aparelho. `null`: só fora do modo debug, porque em debug os tempos de
  /// quadro não valem (JIT e asserts); em debug a medição só aparece no
  /// painel.
  final bool? cortarPorDesempenho;

  /// Recebe o retrato atual (modo, motivo, tempos de quadro).
  final ValueNotifier<DiagnosticoMaquete>? diagnostico;

  /// O retrato da maquete que mudou por último, de qualquer instância.
  static final ValueNotifier<DiagnosticoMaquete> diagnosticoGlobal =
      ValueNotifier(const DiagnosticoMaquete());

  /// Duração da troca de imagem, da entrada do 3D e da transição do avanço
  /// (`Movimento.lento` da spec).
  static const Duration duracaoTroca = Duration(milliseconds: 360);

  /// Quanto o carregamento da cena (Flutter GPU + modelo) pode levar antes
  /// de a maquete desistir e ficar na imagem. Num aparelho bom leva poucas
  /// centenas de milissegundos; o aquecimento dos shaders vem depois, no
  /// SceneView, com a imagem ainda na tela.
  static const Duration tempoMaximoDeCarga = Duration(seconds: 15);

  /// Quanto o 3D pode levar para aparecer depois de carregado (aquecimento
  /// dos shaders no SceneView). Até lá o relógio da cena anda a cada quadro
  /// e a tela fica na imagem; se o aquecimento travar ou falhar, a maquete
  /// fica na imagem e o relógio para. Não conta enquanto o app está em
  /// segundo plano ou a rota está encoberta.
  static const Duration tempoMaximoDeAquecimento = Duration(seconds: 20);

  /// Prazo da medição inicial, contado do primeiro quadro do 3D. Se os 90
  /// quadros não chegarem até lá (rota encoberta, tempos de quadro que não
  /// chegam), ela decide com o que tem, ou não decide, e o relógio para.
  static const Duration prazoDaMedicao = Duration(seconds: 10);

  /// `--dart-define=MAQUETE_DEPURACAO=true` libera o painel fora do debug.
  static const bool _depuracaoPorDefine =
      bool.fromEnvironment('MAQUETE_DEPURACAO');

  /// Imagem de reserva do [estado] (0 a 10) no tema claro ou escuro.
  static String caminhoReserva({required int estado, required bool escuro}) {
    final n = estado.clamp(0, ProgressoMaquete.totalFases);
    return 'assets/3d/reserva/${escuro ? 'escuro' : 'claro'}/'
        'estado_${n.toString().padLeft(2, '0')}.webp';
  }

  /// Chave do widget da imagem de reserva em uso (para testes e capturas).
  static ValueKey<String> chaveImagem(String caminho) =>
      ValueKey('maquete-reserva:$caminho');

  /// Apaga a decisão "aparelho lento": a próxima maquete mede de novo.
  static Future<void> esquecerDecisaoDeDesempenho() =>
      DecisaoDesempenho.esquecer();

  /// Falha do Flutter GPU/cena neste processo: não adianta tentar de novo a
  /// cada maquete aberta.
  static Object? _falhaGpu;

  /// Troca o carregamento da cena (testes).
  @visibleForTesting
  static CarregadorCenaMaquete carregadorDeCena = CenaMaquete.carregar;

  /// Número do quadro em andamento, o mesmo de [ui.FrameTiming.frameNumber]
  /// (-1 se o motor não numera, como no `flutter test`). Troca-se nos testes.
  @visibleForTesting
  static int Function() numeroDoQuadro = _numeroDoQuadroDoMotor;

  static int _numeroDoQuadroDoMotor() =>
      SchedulerBinding.instance.platformDispatcher.frameData.frameNumber;

  /// Volta ao estado de processo novo (testes).
  @visibleForTesting
  static void reiniciarParaTeste() {
    _falhaGpu = null;
    carregadorDeCena = CenaMaquete.carregar;
    numeroDoQuadro = _numeroDoQuadroDoMotor;
    diagnosticoGlobal.value = const DiagnosticoMaquete();
  }

  @override
  State<MaqueteObra> createState() => _MaqueteObraState();
}

class _MaqueteObraState extends State<MaqueteObra>
    with SingleTickerProviderStateMixin {
  Cena3dMaquete? _cena;

  /// Muda a cada carregamento e a cada vez que a cena é solta: um
  /// carregamento antigo que termina depois disso é jogado fora.
  int _geracao = 0;
  bool _carregando = false;
  bool _descartado = false;

  /// Motivo da imagem que não depende dos parâmetros (falha, lentidão,
  /// decisão guardada). Os outros ([MotivoMaquete.forcada],
  /// [MotivoMaquete.reduzirAnimacoes]) são calculados a cada build.
  MotivoMaquete? _motivoFixo;
  String? _detalhe;

  bool _escuro = false;
  bool _reduzir = false;
  bool _appVisivel = true;

  MedidorQuadros _medidor = MedidorQuadros();
  bool _ouvindoQuadros = false;

  /// Números dos quadros em que o relógio da cena andou durante a medição
  /// inicial (saem daqui quando o tempo deles chega). Só esses contam.
  final Set<int> _quadrosDaCena = <int>{};

  /// O motor numerou algum quadro da cena: a medição filtra por número.
  bool _numerou = false;

  /// A numeração dos quadros não bate com a dos tempos (nenhum tempo casou
  /// com centenas de quadros da cena): a medição volta a contar tudo.
  bool _numeracaoFalhou = false;
  static const int _maxQuadrosSemTempo = 360;

  /// Vigias: o 3D tem de aparecer e a medição tem de acabar.
  Timer? _vigiaAquecimento;
  Timer? _prazoMedicao;

  /// O widget do 3D da última vez e o que ele mostra. Um SceneView novo
  /// redesenha a cena; ele só é refeito quando algo do 3D muda, não a cada
  /// vez que o pai reconstrói a maquete.
  Widget? _vistaGuardada;
  Object? _chaveVista;

  /// Muda a cada plano ou tema aplicado à cena.
  int _versaoCena = 0;

  /// O 3D já desenhou um quadro (passou do aquecimento dos shaders).
  bool _revelada = false;

  /// O 3D terminou de entrar por cima da imagem; a imagem sai da árvore.
  bool _trocaFeita = false;
  bool _renderContinuo = false;
  bool _painelAberto = false;

  double _giro = 0;
  late List<double> _fasesMostradas;
  List<double> _fasesDe = const [];
  List<double> _fasesPara = const [];
  late final AnimationController _transicao =
      AnimationController(vsync: this, duration: MaqueteObra.duracaoTroca)
        ..addListener(_aoAnimar);

  late final AppLifecycleListener _ciclo;
  DiagnosticoMaquete _diag = const DiagnosticoMaquete();
  bool _publicacaoAgendada = false;

  bool get _cortar => widget.cortarPorDesempenho ?? !kDebugMode;
  bool get _painelPermitido =>
      widget.painelDepuracao ?? (kDebugMode || MaqueteObra._depuracaoPorDefine);

  /// Depois da medição, os tempos de quadro só servem para o painel e para
  /// quem pediu o [MaqueteObra.diagnostico].
  bool get _ouvirDepoisDaMedicao =>
      _painelPermitido || widget.diagnostico != null;

  MotivoMaquete? get _motivoImagem {
    if (widget.forcarReserva) return MotivoMaquete.forcada;
    if (_reduzir) return MotivoMaquete.reduzirAnimacoes;
    return _motivoFixo;
  }

  ModoMaquete get _modo {
    if (_motivoImagem != null) return ModoMaquete.imagem;
    return _cena == null ? ModoMaquete.carregando : ModoMaquete.tempoReal;
  }

  /// O relógio da cena só anda na medição inicial (ou com o "desenhar sem
  /// parar" do painel). Fora disso a cena só é redesenhada quando este
  /// widget reconstrói.
  bool get _relogioLigado =>
      _appVisivel && (!_medidor.decidido || _renderContinuo);

  @override
  void initState() {
    super.initState();
    _fasesMostradas = widget.progresso.avancoPorFase;
    _ciclo = AppLifecycleListener(onStateChange: _aoMudarCiclo);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final escuro = Theme.of(context).brightness == Brightness.dark;
    if (escuro != _escuro) {
      _escuro = escuro;
      _aplicarTema();
    }
    _reduzir = MediaQuery.disableAnimationsOf(context);
    _atualizarFonte();
    _publicar();
  }

  @override
  void didUpdateWidget(MaqueteObra antigo) {
    super.didUpdateWidget(antigo);
    if (widget.progresso != antigo.progresso) _mudarProgresso();
    if (widget.forcarReserva != antigo.forcarReserva) _atualizarFonte();
    _publicar();
  }

  @override
  void dispose() {
    _descartado = true;
    _geracao++;
    _pararVigias();
    _ouvirQuadros(false);
    _ciclo.dispose();
    _transicao.dispose();
    // O SceneView (filho) já saiu da árvore: pode soltar a cena agora.
    _cena?.descartar();
    _cena = null;
    super.dispose();
  }

  // ------------------------------------------------------------ início

  /// Inicia o 3D quando nada manda usar a imagem; com "reduzir animações"
  /// ou [MaqueteObra.forcarReserva] o Flutter GPU nem é iniciado, e uma cena
  /// já carregada é solta (volta a carregar se a condição sumir).
  /// Chamado durante o build: não chama setState.
  void _atualizarFonte() {
    if (widget.forcarReserva || _reduzir) {
      if (_cena != null || _carregando) _soltarCena();
      return;
    }
    if (_cena == null && !_carregando && _motivoFixo == null) {
      unawaited(_iniciar());
    }
  }

  bool _vale(int geracao) => !_descartado && mounted && geracao == _geracao;

  Future<void> _iniciar() async {
    final geracao = ++_geracao;
    _carregando = true;
    _medidor = MedidorQuadros();
    try {
      // Chamado do didChangeDependencies: o resto roda depois do build, e o
      // setState de _fixarImagem nunca cai no meio dele.
      await Future<void>.value();
      if (!_vale(geracao)) return;
      if (_cortar) {
        final p90 = await DecisaoDesempenho.ler();
        if (!_vale(geracao)) return;
        if (p90 != null) {
          _fixarImagem(
            MotivoMaquete.decisaoGuardada,
            'p90 de ${p90.toStringAsFixed(1)} ms na última medição',
          );
          return;
        }
      }
      final falha = MaqueteObra._falhaGpu;
      if (falha != null) {
        _fixarImagem(MotivoMaquete.semSuporte, _resumo(falha));
        return;
      }
      final Cena3dMaquete cena;
      Future<Cena3dMaquete>? carga;
      try {
        carga = MaqueteObra.carregadorDeCena(
          tema: TemaMaquete.de(escuro: _escuro),
        );
        cena = await carga.timeout(MaqueteObra.tempoMaximoDeCarga);
      } catch (erro) {
        if (erro is TimeoutException && carga != null) {
          // A carga ainda pode terminar: a cena que chegar tarde é solta.
          unawaited(carga.then<void>(
            (atrasada) => atrasada.descartar(),
            onError: (Object _) {},
          ));
        }
        MaqueteObra._falhaGpu = erro;
        if (_vale(geracao)) {
          _fixarImagem(MotivoMaquete.semSuporte, _resumo(erro));
        }
        return;
      }
      if (!_vale(geracao)) {
        cena.descartar();
        return;
      }
      setState(() => _cena = cena);
      // O tema pode ter mudado durante o carregamento.
      _aplicarTema();
      _aplicarPlano(_fasesMostradas);
      _ouvirQuadros(true);
      _armarVigiaDoAquecimento();
      _publicar();
    } finally {
      if (geracao == _geracao) _carregando = false;
    }
  }

  static String _resumo(Object erro) {
    final texto = '$erro'.split('\n').first.trim();
    return texto.length > 160 ? '${texto.substring(0, 157)}...' : texto;
  }

  void _fixarImagem(MotivoMaquete motivo, String detalhe) {
    if (_descartado || !mounted) return;
    setState(() {
      _motivoFixo = motivo;
      _detalhe = detalhe;
      _soltarCena();
    });
    _publicar();
  }

  /// Solta a cena (memória de GPU) e zera o estado do 3D. A cena é
  /// descartada depois do quadro, quando o SceneView já saiu da árvore
  /// (desenhar uma cena descartada lança). Não chama setState.
  void _soltarCena() {
    _geracao++;
    _carregando = false;
    _ouvirQuadros(false);
    _pararVigias();
    _transicao.stop();
    final cena = _cena;
    _cena = null;
    _vistaGuardada = null;
    _chaveVista = null;
    _quadrosDaCena.clear();
    _revelada = false;
    _trocaFeita = false;
    _renderContinuo = false;
    if (cena != null) {
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => cena.descartar())
        ..ensureVisualUpdate();
    }
  }

  void _pararVigias() {
    _vigiaAquecimento?.cancel();
    _vigiaAquecimento = null;
    _prazoMedicao?.cancel();
    _prazoMedicao = null;
  }

  /// Desenhar a cena lançou (a [Cena3dMaquete] já parou de desenhar). Pode
  /// chegar no meio da pintura: a troca para a imagem fica para depois do
  /// quadro.
  void _aoFalharCena(Cena3dMaquete cena, Object erro) {
    MaqueteObra._falhaGpu ??= erro;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (!identical(cena, _cena)) return;
        _fixarImagem(
          MotivoMaquete.semSuporte,
          'falha ao desenhar: ${_resumo(erro)}',
        );
      })
      ..ensureVisualUpdate();
  }

  void _armarVigiaDoAquecimento() {
    _vigiaAquecimento?.cancel();
    _vigiaAquecimento = Timer(
      MaqueteObra.tempoMaximoDeAquecimento,
      _aoEstourarAquecimento,
    );
  }

  void _aoEstourarAquecimento() {
    _vigiaAquecimento = null;
    if (_descartado || !mounted || _cena == null || _revelada) return;
    // Parado de propósito (app em segundo plano, rota por cima): o relógio
    // do SceneView não anda e não há como o 3D aparecer. Espera de novo.
    if (!_appVisivel || !TickerMode.getValuesNotifier(context).value.enabled) {
      _armarVigiaDoAquecimento();
      return;
    }
    final erro = TimeoutException(
      'o 3D não apareceu (aquecimento dos shaders)',
      MaqueteObra.tempoMaximoDeAquecimento,
    );
    MaqueteObra._falhaGpu ??= erro;
    _fixarImagem(MotivoMaquete.semSuporte, _resumo(erro));
  }

  void _aplicarTema() {
    final cena = _cena;
    if (cena == null) return;
    cena.aplicarTema(TemaMaquete.de(escuro: _escuro));
    _versaoCena++;
  }

  void _aplicarPlano(List<double> fases) {
    final cena = _cena;
    if (cena == null) return;
    cena.aplicar(PlanoMaquete.calcular(fases));
    _versaoCena++;
  }

  // ---------------------------------------------------------- avanço

  void _mudarProgresso() {
    final novo = widget.progresso.avancoPorFase;
    if (_modo == ModoMaquete.tempoReal) {
      _fasesDe = List.of(_fasesMostradas);
      _fasesPara = novo;
      unawaited(_transicao.forward(from: 0));
    } else {
      _transicao.stop();
      _fasesMostradas = novo;
      _aplicarPlano(novo);
    }
  }

  void _aoAnimar() {
    final t = Curves.easeOutCubic.transform(_transicao.value);
    _fasesMostradas = [
      for (var i = 0; i < ProgressoMaquete.totalFases; i++)
        ui.lerpDouble(_fasesDe[i], _fasesPara[i], t)!,
    ];
    _aplicarPlano(_fasesMostradas);
    // Um SceneView novo (versão da cena mudou) pede um novo desenho.
    setState(() {});
  }

  // --------------------------------------------------------- medição

  void _ouvirQuadros(bool ouvir) {
    if (ouvir == _ouvindoQuadros) return;
    _ouvindoQuadros = ouvir;
    if (ouvir) {
      SchedulerBinding.instance.addTimingsCallback(_aoMedirQuadros);
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_aoMedirQuadros);
    }
  }

  /// A cada quadro em que o relógio da cena anda (no quadro, antes do
  /// build).
  void _aoTicar() {
    // Quadros de antes daqui (carregamento, aquecimento) não contam.
    _medidor.inicioUs ??=
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    _anotarQuadroDaCena();
    if (_revelada) return;
    _vigiaAquecimento?.cancel();
    _vigiaAquecimento = null;
    _prazoMedicao?.cancel();
    _prazoMedicao = Timer(MaqueteObra.prazoDaMedicao, _aoEstourarMedicao);
    setState(() => _revelada = true);
    _publicar();
  }

  /// Guarda o número deste quadro: a cena andou nele.
  void _anotarQuadroDaCena() {
    if (_numeracaoFalhou || _medidor.decidido) return;
    final n = MaqueteObra.numeroDoQuadro();
    if (n < 0) return;
    _numerou = true;
    _quadrosDaCena.add(n);
    if (_quadrosDaCena.length > _maxQuadrosSemTempo) {
      _numeracaoFalhou = true;
      _quadrosDaCena.clear();
    }
  }

  /// O quadro conta na medição inicial: foi um em que a cena andou (ou o
  /// motor não numera os quadros, e aí vale o filtro por tempo do medidor).
  bool _contaNaMedicao(ui.FrameTiming q) {
    if (!_numerou || _numeracaoFalhou || q.frameNumber < 0) return true;
    return _quadrosDaCena.remove(q.frameNumber);
  }

  void _aoMedirQuadros(List<ui.FrameTiming> quadros) {
    if (!_revelada || !_appVisivel || _modo != ModoMaquete.tempoReal) return;
    var fechou = false;
    for (final q in quadros) {
      if (!_medidor.decidido && !_contaNaMedicao(q)) continue;
      fechou |= _medidor.registrarTiming(q);
    }
    if (fechou) _aoConcluirMedicao();
    _publicar();
  }

  void _aoEstourarMedicao() {
    _prazoMedicao = null;
    if (_descartado || !mounted || _modo != ModoMaquete.tempoReal) return;
    if (_medidor.encerrar()) {
      _aoConcluirMedicao();
      _publicar();
    }
  }

  void _aoConcluirMedicao() {
    _prazoMedicao?.cancel();
    _prazoMedicao = null;
    _quadrosDaCena.clear();
    final inicial = _medidor.inicial;
    final cortar = _medidor.lento && _cortar;
    debugPrint('MaqueteObra: medição de '
        '${inicial ?? 'só ${_medidor.quadrosMedidos} quadros (prazo)'} -> '
        '${cortar ? 'imagem' : 'tempo real'}');
    if (cortar) {
      unawaited(DecisaoDesempenho.gravar(inicial!.p90Ms));
      _fixarImagem(
        MotivoMaquete.quadrosLentos,
        'p90 ${inicial.p90Ms.toStringAsFixed(1)} ms > '
        '${_medidor.limiteP90Ms.toStringAsFixed(0)} ms',
      );
    } else if (mounted) {
      if (!_ouvirDepoisDaMedicao) _ouvirQuadros(false);
      // Medição feita: o relógio da cena para (TickerMode).
      setState(() {});
    }
  }

  void _aoMudarCiclo(AppLifecycleState estado) {
    final visivel = estado == AppLifecycleState.resumed ||
        estado == AppLifecycleState.inactive;
    if (visivel == _appVisivel || !mounted) return;
    // Os primeiros quadros ao voltar do segundo plano não contam.
    if (visivel) _medidor.pularProximos();
    setState(() => _appVisivel = visivel);
  }

  // ----------------------------------------------------- diagnóstico

  /// Publica o retrato. Durante o build, adia para depois do quadro (quem
  /// ouve o notifier pode chamar setState).
  void _publicar() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_publicacaoAgendada) return;
      _publicacaoAgendada = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _publicacaoAgendada = false;
        if (!_descartado) _publicarAgora();
      });
      return;
    }
    _publicarAgora();
  }

  void _publicarAgora() {
    final quadro = _cena?.ultimoQuadro;
    final motivo = _motivoImagem;
    final d = DiagnosticoMaquete(
      modo: _modo,
      motivo: motivo ?? MotivoMaquete.nenhum,
      detalhe: motivo != null && motivo == _motivoFixo ? _detalhe : null,
      revelada: _revelada && _modo == ModoMaquete.tempoReal,
      estadoReserva: widget.progresso.estadoReserva,
      quadrosMedidos: _medidor.quadrosMedidos,
      quadrosParaDecidir: _medidor.quadrosParaDecidir,
      medicao: _medidor.parcial,
      medicaoConcluida: _medidor.decidido,
      recente: _medidor.decidido ? _medidor.recente : null,
      cpuCenaMs: quadro?.$1,
      chamadasDeDesenho: quadro?.$2,
    );
    _diag = d;
    widget.diagnostico?.value = d;
    MaqueteObra.diagnosticoGlobal.value = d;
    if (_painelAberto && mounted) setState(() {});
  }

  // ----------------------------------------------------------- gestos

  void _girar(double radianos) {
    setState(() => _giro = (_giro + radianos) % (2 * math.pi));
  }

  void _alternarPainel() {
    setState(() => _painelAberto = !_painelAberto);
    _publicar();
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final tema = TemaMaquete.de(escuro: _escuro);
    final cena = _modo == ModoMaquete.tempoReal ? _cena : null;
    final mostrarImagem = cena == null || !_trocaFeita;

    Widget maquete = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: tema.papel),
        if (mostrarImagem)
          ExcludeSemantics(
            key: const ValueKey('maquete-imagem'),
            child: _ImagemReserva(
              caminho: MaqueteObra.caminhoReserva(
                estado: widget.progresso.estadoReserva,
                escuro: _escuro,
              ),
              duracao: _reduzir ? Duration.zero : MaqueteObra.duracaoTroca,
            ),
          ),
        if (cena != null)
          ExcludeSemantics(
            key: const ValueKey('maquete-3d'),
            child: _vista3d(cena),
          ),
        if (widget.legenda && !widget.progresso.concluida)
          Positioned(
            key: const ValueKey('maquete-legenda'),
            left: 12,
            bottom: 8,
            child: ExcludeSemantics(child: _Legenda(escuro: _escuro)),
          ),
        if (_painelAberto && _painelPermitido)
          Positioned.fill(
            key: const ValueKey('maquete-painel'),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: _PainelDepuracao(
                  diagnostico: _diag,
                  escuro: _escuro,
                  renderContinuo: _renderContinuo,
                  aoAlternarContinuo: cena != null
                      ? () => setState(() => _renderContinuo = !_renderContinuo)
                      : null,
                  aoEsquecer: () => unawaited(DecisaoDesempenho.esquecer()),
                  aoFechar: _alternarPainel,
                ),
              ),
            ),
          ),
      ],
    );
    if (_painelPermitido) {
      maquete = GestureDetector(onLongPress: _alternarPainel, child: maquete);
    }

    return Semantics(
      container: true,
      image: true,
      label: widget.progresso.descricao,
      customSemanticsActions: cena != null && widget.interativa
          ? {
              const CustomSemanticsAction(
                label: 'Girar a maquete para a esquerda',
              ): () => _girar(-math.pi / 6),
              const CustomSemanticsAction(
                label: 'Girar a maquete para a direita',
              ): () => _girar(math.pi / 6),
            }
          : null,
      child: SizedBox(
        height: widget.altura,
        width: double.infinity,
        child: ClipRect(child: maquete),
      ),
    );
  }

  /// O 3D, que entra por cima da imagem (mesmo enquadramento) depois do
  /// primeiro quadro desenhado. Enquanto a opacidade é zero, o SceneView nem
  /// é pintado.
  Widget _vista3d(Cena3dMaquete cena) {
    Widget vista = LayoutBuilder(
      builder: (context, caixa) {
        final proporcao = caixa.maxHeight > 0 && caixa.maxWidth.isFinite
            ? caixa.maxWidth / caixa.maxHeight
            : CameraMaquete.proporcaoReserva;
        // O mesmo widget de antes se nada do 3D mudou: o Flutter nem
        // atualiza o SceneView, e a cena não é desenhada de novo.
        final chave = (cena, proporcao, _giro, _versaoCena);
        var guardada = _vistaGuardada;
        if (guardada == null || chave != _chaveVista) {
          guardada = _vistaGuardada = cena.vista(
            proporcao: proporcao,
            giro: _giro,
            aoDesenhar: _aoTicar,
            aoFalhar: (erro) => _aoFalharCena(cena, erro),
          );
          _chaveVista = chave;
        }
        return TickerMode(enabled: _relogioLigado, child: guardada);
      },
    );
    if (widget.interativa) {
      vista = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) =>
            _girar(d.delta.dx * CameraMaquete.giroPorPonto),
        child: vista,
      );
    }
    return AnimatedOpacity(
      opacity: _revelada ? 1 : 0,
      duration: MaqueteObra.duracaoTroca,
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (mounted && _revelada && !_trocaFeita) {
          setState(() => _trocaFeita = true);
        }
      },
      child: vista,
    );
  }
}

/// A imagem de reserva, com troca suave: a nova entra por cima da antiga
/// só depois de decodificada, então não pisca papel no meio da troca.
class _ImagemReserva extends StatefulWidget {
  const _ImagemReserva({required this.caminho, required this.duracao});

  final String caminho;
  final Duration duracao;

  @override
  State<_ImagemReserva> createState() => _ImagemReservaState();
}

class _ImagemReservaState extends State<_ImagemReserva> {
  /// A que fica embaixo durante a troca.
  String? _anterior;
  late String _atual = widget.caminho;

  /// A atual já foi decodificada. A primeira imagem entra sem transição
  /// (movimento só informa mudança).
  bool _atualPronta = true;
  bool _avisoAgendado = false;

  @override
  void didUpdateWidget(_ImagemReserva antigo) {
    super.didUpdateWidget(antigo);
    if (widget.caminho == _atual) return;
    // Fica embaixo a última imagem que estava inteira na tela.
    if (_atualPronta) _anterior = _atual;
    _atual = widget.caminho;
    _atualPronta = false;
  }

  void _aoDecodificar() {
    if (_atualPronta || _avisoAgendado) return;
    _avisoAgendado = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _avisoAgendado = false;
      if (!mounted || _atualPronta) return;
      setState(() {
        _atualPronta = true;
        // Sem animação (reduzir animações) a de baixo sai já.
        if (widget.duracao == Duration.zero) _anterior = null;
      });
    });
  }

  void _aoTerminarTroca() {
    // Com duração zero, o fim chega no meio do build e _anterior já é null.
    if (_anterior == null || !_atualPronta || !mounted) return;
    setState(() => _anterior = null);
  }

  @override
  Widget build(BuildContext context) {
    final anterior = _anterior;
    return LayoutBuilder(
      builder: (context, caixa) {
        final largura = _larguraDecodificada(context, caixa);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (anterior != null)
              Image.asset(
                anterior,
                key: ValueKey('maquete-reserva-anterior:$anterior'),
                fit: BoxFit.contain,
                cacheWidth: largura,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: _semImagem,
              ),
            AnimatedOpacity(
              // Uma por imagem: a nova começa transparente.
              key: ValueKey('maquete-reserva-opacidade:$_atual'),
              opacity: _atualPronta ? 1 : 0,
              duration: widget.duracao,
              curve: Curves.easeOutCubic,
              onEnd: _aoTerminarTroca,
              child: Image.asset(
                _atual,
                key: MaqueteObra.chaveImagem(_atual),
                fit: BoxFit.contain,
                cacheWidth: largura,
                excludeFromSemantics: true,
                // Sem decodificar, a de baixo (se houver) continua na tela.
                errorBuilder: _semImagem,
                frameBuilder: (context, child, quadro, sincrono) {
                  if (quadro != null) _aoDecodificar();
                  return child;
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _semImagem(BuildContext context, Object erro, StackTrace? _) {
    debugPrint('MaqueteObra: imagem de reserva não decodificou: $erro');
    return const SizedBox.expand();
  }

  /// Largura em pixels em que a imagem (1080x720) aparece na caixa, em
  /// degraus de 120 px, para decodificar só o necessário (1080x720 em RGBA
  /// são 3 MB).
  static int? _larguraDecodificada(BuildContext context, BoxConstraints caixa) {
    final visivel = math.min(
      caixa.maxWidth,
      caixa.maxHeight * CameraMaquete.proporcaoReserva,
    );
    if (!visivel.isFinite || visivel <= 0) return null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final px = (visivel * dpr / 120).ceil() * 120;
    return px >= 1080 ? null : px;
  }
}

/// "ainda não construído", com o traço do fantasma, como na tela aprovada
/// da direção B. Fundo de papel: o texto nunca fica sobre a maquete.
class _Legenda extends StatelessWidget {
  const _Legenda({required this.escuro});

  final bool escuro;

  // Cores da spec (seção 2), fixas aqui de propósito: os tokens
  // (context.cores) estão sendo feitos em paralelo.
  static const _grafite2Claro = Color(0xFF4B5058);
  static const _grafite2Escuro = Color(0xFFA9ADB3);

  @override
  Widget build(BuildContext context) {
    final tema = TemaMaquete.de(escuro: escuro);
    return DecoratedBox(
      decoration: BoxDecoration(color: tema.papel),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(24, 2),
              painter: _TracoFantasma(tema.fantasma),
            ),
            const SizedBox(width: 8),
            Text(
              'ainda não construído',
              style: TextStyle(
                fontFamily: 'Atkinson',
                fontSize: 15,
                height: 1.2,
                fontWeight: FontWeight.w400,
                color: escuro ? _grafite2Escuro : _grafite2Claro,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Traço interrompido com a cor e a cadência do fantasma (28 cm de traço,
/// 15 de vão, em escala).
class _TracoFantasma extends CustomPainter {
  const _TracoFantasma(this.cor);

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()
      ..color = cor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    const traco = 6.0, vao = 3.0;
    for (var x = 0.0; x < size.width; x += traco + vao) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + traco, size.width), y),
        tinta,
      );
    }
  }

  @override
  bool shouldRepaint(_TracoFantasma antigo) => antigo.cor != cor;
}

/// Painel de depuração: aparece no toque longo (modo debug ou flag). É um
/// cartão opaco sobre a maquete, sem nada animado atrás do texto.
class _PainelDepuracao extends StatelessWidget {
  const _PainelDepuracao({
    required this.diagnostico,
    required this.escuro,
    required this.renderContinuo,
    required this.aoAlternarContinuo,
    required this.aoEsquecer,
    required this.aoFechar,
  });

  final DiagnosticoMaquete diagnostico;
  final bool escuro;
  final bool renderContinuo;
  final VoidCallback? aoAlternarContinuo;
  final VoidCallback aoEsquecer;
  final VoidCallback aoFechar;

  // Cores do design system (seção 2), fixas aqui de propósito: os tokens
  // (context.cores) estão sendo feitos em paralelo.
  static const _folhaClaro = Color(0xFFFFFFFF);
  static const _folhaEscuro = Color(0xFF1A1C1F);
  static const _grafiteClaro = Color(0xFF1A1C1F);
  static const _grafiteEscuro = Color(0xFFECEDE9);

  @override
  Widget build(BuildContext context) {
    final tinta = escuro ? _grafiteEscuro : _grafiteClaro;
    final estilo = TextStyle(
      fontFamily: 'PlexMono',
      fontSize: 13,
      height: 1.35,
      color: tinta,
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );
    final botao = TextButton.styleFrom(
      foregroundColor: tinta,
      minimumSize: const Size(48, 48),
      textStyle: estilo.copyWith(fontWeight: FontWeight.w500),
    );
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: escuro ? _folhaEscuro : _folhaClaro,
          border: Border.all(color: tinta, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
          child: DefaultTextStyle(
            style: estilo,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final linha in diagnostico.linhas) Text(linha),
                Wrap(
                  spacing: 4,
                  children: [
                    if (aoAlternarContinuo != null)
                      TextButton(
                        style: botao,
                        onPressed: aoAlternarContinuo,
                        child: Text(
                          renderContinuo
                              ? 'parar relógio'
                              : 'desenhar sem parar',
                        ),
                      ),
                    TextButton(
                      style: botao,
                      onPressed: aoEsquecer,
                      child: const Text('esquecer decisão'),
                    ),
                    TextButton(
                      style: botao,
                      onPressed: aoFechar,
                      child: const Text('fechar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
