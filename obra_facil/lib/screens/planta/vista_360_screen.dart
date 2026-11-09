import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:provider/provider.dart';
// O vector_math chega pelo flutter_scene (ver cena_maquete.dart).
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math.dart' as vm;

import '../../design/design.dart';
import '../../design/maquete/cena_maquete.dart';
import '../../design/maquete/gerador/gerador_maquete.dart';
import '../../design/maquete/maquete.dart';
import '../../design/maquete/plano_maquete.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'como_vai_ficar.dart';
import 'ficha_comodo.dart';

/// A vista 360° de um cômodo: a câmera dentro da casa pronta (gerada pela
/// planta), na altura dos olhos. Arrastar olha em volta; pinçar aproxima.
/// Sem 3D no aparelho, as quatro paredes do cômodo desdobradas, com portas
/// e janelas.
class Vista360Screen extends StatelessWidget {
  const Vista360Screen({
    super.key,
    required this.obraId,
    required this.comodoId,
  });

  final String obraId;
  final String comodoId;

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _Vista360(obraId: obraId, comodoId: comodoId));
}

class _Vista360 extends StatefulWidget {
  const _Vista360({required this.obraId, required this.comodoId});

  final String obraId;
  final String comodoId;

  @override
  State<_Vista360> createState() => _Vista360State();
}

class _Vista360State extends State<_Vista360> {
  late final Stream<PlantaObra?> _planta =
      context.read<FirestoreService>().planta(widget.obraId);
  late final Stream<List<ImagemIaModel>> _imagens =
      context.read<FirestoreService>().imagens(widget.obraId);
  final _chaveVista = GlobalKey();
  bool _capturando = false;

  /// O cômodo da vista: começa no da rota e muda pelo mapa ou pela lista,
  /// sem recarregar a casa.
  late String _comodoId = widget.comodoId;

  void _irPara(String id) {
    if (id == _comodoId) return;
    setState(() => _comodoId = id);
  }

  /// Fotografa o ângulo que o dono escolheu e abre a geração da imagem.
  Future<void> _gerarFoto(PlantaObra planta, ComodoPlanta comodo) async {
    setState(() => _capturando = true);
    final guia = await capturarVista(_chaveVista);
    if (!mounted) return;
    setState(() => _capturando = false);
    if (guia == null) {
      unawaited(Tato.erro());
      mostrarAviso(context,
          'Não deu para fotografar o 3D neste aparelho. Espere a vista abrir e tente de novo.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TemaPrancheta(
        child: GerarImagemScreen(
          obraId: widget.obraId,
          pedido: PedidoImagem.comodo(
            vista: comodo.id,
            nomeComodo: comodo.nome,
            guia: guia,
            medidas: '${medidasDoComodo(comodo)}, pé-direito '
                '${planta.alturas.peDireito.toStringAsFixed(2).replaceAll('.', ',')} m',
            piso: comodo.piso.rotulo,
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final ehDono = context.watch<AuthProvider>().ehDono;
    return StreamBuilder<PlantaObra?>(
      stream: _planta,
      builder: (context, snap) {
        final planta = snap.data;
        final comodo =
            planta?.todosOsComodos.where((x) => x.id == _comodoId).firstOrNull;
        // A planta do pavimento do cômodo (vãos, ficha, paredes).
        final indice = planta?.plantaDoComodo(_comodoId) ?? 0;
        final doAndar = planta?.planta(math.max(0, indice));
        final podeGerar = ehDono &&
            planta != null &&
            comodo != null &&
            comodo.coberto &&
            !MaqueteObra.semSuporteGpu;
        return Scaffold(
          appBar: AppBar(),
          bottomNavigationBar: podeGerar
              ? BarraDeAcao(
                  principal: BotaoContorno(
                    rotulo: 'Gerar foto deste ângulo',
                    icone: Icons.auto_awesome_outlined,
                    expandir: true,
                    carregando: _capturando,
                    aoTocar: _capturando
                        ? null
                        : () => unawaited(_gerarFoto(planta, comodo)),
                  ),
                )
              : null,
          body: planta == null || comodo == null
              ? Padding(
                  padding: const EdgeInsets.all(Espaco.margem),
                  child: snap.connectionState == ConnectionState.waiting
                      ? const EsqueletoFolha(
                          rotuloSemantico: 'Abrindo o cômodo')
                      : const AvisoVazio(
                          icone: Icons.architecture_outlined,
                          titulo: 'Cômodo não encontrado',
                          texto: 'A planta da obra mudou. Volte e escolha o '
                              'cômodo de novo.',
                        ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: Espaco.e32),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Espaco.margem),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Rotulo('Vista 360°'),
                          const SizedBox(height: Espaco.e4),
                          Semantics(
                            header: true,
                            child: Text(
                              comodo.nome,
                              style: Tipografia.tituloTela
                                  .copyWith(color: c.grafite),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Espaco.e12),
                    SizedBox(
                      height: math.min(
                          MediaQuery.sizeOf(context).height * 0.55, 460),
                      child: Interior360(
                        planta: planta,
                        comodo: comodo,
                        pavimento:
                            planta.pavimentoDaPlanta(math.max(0, indice)),
                        aoTrocarComodo: _irPara,
                        chaveDaCena: _chaveVista,
                      ),
                    ),
                    const SizedBox(height: Espaco.e12),
                    _OutrosComodos(
                      planta: planta,
                      atual: comodo,
                      aoEscolher: _irPara,
                    ),
                    StreamBuilder<List<ImagemIaModel>>(
                      stream: _imagens,
                      builder: (context, snap) {
                        final daqui = (snap.data ?? const <ImagemIaModel>[])
                            .where((i) => i.vista == comodo.id)
                            .toList();
                        if (daqui.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                              Espaco.margem, Espaco.e16, Espaco.margem, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const LinhaCota(legenda: 'Como vai ficar'),
                              const SizedBox(height: Espaco.e12),
                              GaleriaComoVaiFicar(imagens: daqui),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: Espaco.e16),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Espaco.margem),
                      child: FichaComodo(planta: doAndar!, comodo: comodo),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Os outros cômodos cobertos da mesma casa (ou apartamento), numa faixa
/// que rola de lado: tocar troca a vista na hora.
class _OutrosComodos extends StatelessWidget {
  const _OutrosComodos({
    required this.planta,
    required this.atual,
    required this.aoEscolher,
  });

  final PlantaObra planta;
  final ComodoPlanta atual;
  final ValueChanged<String> aoEscolher;

  @override
  Widget build(BuildContext context) {
    final comodos = [
      for (final k in planta.todosOsComodos)
        if (k.coberto && k.unidade == atual.unidade && k.tipo != 'escada') k,
    ];
    if (comodos.length < 2) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Outros cômodos',
      child: SizedBox(
        height: Alvo.minimo,
        child: ListView.separated(
          key: const ValueKey('outros-comodos'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Espaco.margem),
          itemCount: comodos.length,
          separatorBuilder: (_, __) => const SizedBox(width: Espaco.e8),
          itemBuilder: (context, i) {
            final k = comodos[i];
            return ChoiceChip(
              label: Text(k.nome),
              selected: k.id == atual.id,
              onSelected: (_) => aoEscolher(k.id),
            );
          },
        ),
      ),
    );
  }
}

/// O cômodo por dentro: 3D em tempo real quando o aparelho tem Flutter GPU;
/// senão, as quatro paredes desdobradas ([ParedesDoComodo]).
///
/// A casa vem pronta e mobiliada. Arrastar olha em volta (e o giro segue
/// um pouco depois de soltar), pinçar aproxima, dois toques voltam ao
/// começo. O botão do sol troca dia e noite (de noite as luminárias
/// acendem) e o mapa no canto mostra onde a pessoa está e para onde olha:
/// tocar noutro cômodo vai para ele sem recarregar a casa.
class Interior360 extends StatefulWidget {
  const Interior360({
    super.key,
    required this.planta,
    required this.comodo,
    this.pavimento = 0,
    this.giroInicial,
    this.aoTrocarComodo,
    this.noiteInicial = false,
    this.chaveDaCena,
  });

  /// O RepaintBoundary só da cena (sem os botões e o mapa), para a foto
  /// do ângulo.
  final GlobalKey? chaveDaCena;

  /// Para onde o olhar começa (radianos); nulo: o lado mais comprido.
  final double? giroInicial;

  /// A planta inteira (a cena tem todos os pavimentos).
  final PlantaObra planta;
  final ComodoPlanta comodo;

  /// Em que pavimento o cômodo está (0 = térreo): a altura do olho.
  final int pavimento;

  /// Tocar num cômodo do mapa (nulo: o mapa não troca de cômodo).
  final ValueChanged<String>? aoTrocarComodo;

  /// Começa de noite (testes e capturas).
  final bool noiteInicial;

  @override
  State<Interior360> createState() => _Interior360State();
}

class _Interior360State extends State<Interior360>
    with SingleTickerProviderStateMixin {
  CenaMaquete? _cena;
  Map<String, fs.PointLight> _luzes = const {};
  bool _semTresD = false;
  bool _descartado = false;
  late bool _noite = widget.noiteInicial;
  bool _mexeu = false;

  /// Para onde o olho aponta: giro (em volta do eixo vertical) e
  /// inclinação (para cima/baixo), em radianos; e o campo de visão.
  double _giro = 0;
  double _inclinacao = -0.08;
  double _campo = 70 * math.pi / 180;
  double _campoNoInicio = 0;
  int _dedos = 0;

  /// O giro que continua depois de soltar o dedo.
  late final AnimationController _inercia =
      AnimationController.unbounded(vsync: this)
        ..addListener(() => setState(() => _giro = _inercia.value));

  static const double _alturaDoOlho = 1.6;
  static const double _radianosPorPonto = 0.006;

  @override
  void initState() {
    super.initState();
    _giro = widget.giroInicial ?? _giroInicial();
    // O tema e a MediaQuery só podem ser lidos depois do initState.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_carregar());
    });
  }

  @override
  void didUpdateWidget(Interior360 antes) {
    super.didUpdateWidget(antes);
    if (antes.comodo.id != widget.comodo.id) {
      _inercia.stop();
      _giro = _giroInicial();
      _inclinacao = -0.08;
      _campo = 70 * math.pi / 180;
      // A sombra dos móveis vem da luz do cômodo onde a pessoa está.
      final cena = _cena;
      if (cena != null) {
        LuzMaquete.horario(cena.cena, _luzes,
            noite: _noite, comodo: widget.comodo.id);
      }
    }
  }

  /// Começa olhando para o lado mais comprido do cômodo.
  double _giroInicial() {
    final r = widget.comodo.principal;
    return r.largura >= r.profundidade ? math.pi / 2 : 0;
  }

  Future<void> _carregar() async {
    if (MaqueteObra.semSuporteGpu) {
      setState(() => _semTresD = true);
      return;
    }
    try {
      final cena = await CenaMaquete.carregarDaPlanta(
        tema: TemaMaquete.de(
            escuro: Theme.of(context).brightness == Brightness.dark),
        fonte: FontePlanta(widget.planta, interior: true),
      );
      if (_descartado || !mounted) {
        cena.descartar();
        return;
      }
      // A casa pronta e mobiliada, sem o tracejado, com a luz de dentro.
      cena.aplicar(PlanoMaquete.calcular(
          List<double>.filled(ProgressoMaquete.totalFases, 1)));
      final luzes = LuzMaquete.deDentro(cena.cena, cena.luzes,
          comodo: widget.comodo.id, noite: _noite);
      setState(() {
        _cena = cena;
        _luzes = luzes;
      });
    } catch (erro) {
      MaqueteObra.anotarFalhaGpu(erro);
      if (mounted) setState(() => _semTresD = true);
    }
  }

  @override
  void dispose() {
    _descartado = true;
    _inercia.dispose();
    final cena = _cena;
    _cena = null;
    if (cena != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => cena.descartar());
    }
    super.dispose();
  }

  void _trocarHorario() {
    final cena = _cena;
    if (cena == null) return;
    unawaited(Tato.leve());
    setState(() => _noite = !_noite);
    LuzMaquete.horario(cena.cena, _luzes,
        noite: _noite, comodo: widget.comodo.id);
  }

  void _recentrar() {
    _inercia.stop();
    setState(() {
      _giro = _giroInicial();
      _inclinacao = -0.08;
      _campo = 70 * math.pi / 180;
    });
  }

  /// Onde a pessoa fica: no meio do cômodo; na garagem, ao lado do carro.
  (double, double) get _ondeFica {
    final r = widget.comodo.principal;
    var (x, y) = ((r.x + r.x1) / 2, (r.y + r.y1) / 2);
    if (widget.comodo.tipo == 'garagem' && widget.comodo.coberto) {
      if (r.profundidade >= r.largura) {
        x = r.x + math.max(0.45, (r.largura - 1.8) / 4);
      } else {
        y = r.y + math.max(0.45, (r.profundidade - 1.8) / 4);
      }
    }
    return (x, y);
  }

  fs.PerspectiveCamera _camera() {
    final (cx, cy) = GeradorMaquete.centroDe(widget.planta);
    final (px, py) = _ondeFica;
    // Planta -> glTF (X, Z) -> flutter_scene (Z invertido).
    final x = px - cx;
    final z = -(py - cy);
    final y = NiveisMaquete.piso +
        widget.pavimento *
            (widget.planta.alturas.peDireito + NiveisMaquete.espessuraLaje) +
        _alturaDoOlho;
    final direcao = vm.Vector3(
      math.sin(_giro) * math.cos(_inclinacao),
      math.sin(_inclinacao),
      math.cos(_giro) * math.cos(_inclinacao),
    );
    final olho = vm.Vector3(x, y, z);
    return fs.PerspectiveCamera(
      fovRadiansY: _campo,
      position: olho,
      target: olho + direcao,
      up: vm.Vector3(0, 1, 0),
      fovNear: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final cena = _cena;
    if (_semTresD) {
      final indice = widget.planta.plantaDoComodo(widget.comodo.id);
      return ParedesDoComodo(
          planta: widget.planta.planta(math.max(0, indice)),
          comodo: widget.comodo);
    }
    if (cena == null) {
      return ColoredBox(
        color: c.folhaRebaixada,
        child: const Center(child: IndicadorCarregando()),
      );
    }
    final indice = math.max(0, widget.planta.plantaDoComodo(widget.comodo.id));
    return LayoutBuilder(builder: (context, caixa) {
      final proporcao = caixa.maxWidth / math.max(1, caixa.maxHeight);
      return Semantics(
        label: 'Vista 360° de ${widget.comodo.nome}, '
            '${_noite ? 'de noite' : 'de dia'}. Arraste para olhar em volta.',
        image: true,
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Olhar para a esquerda'): () =>
              setState(() => _giro += math.pi / 4),
          const CustomSemanticsAction(label: 'Olhar para a direita'): () =>
              setState(() => _giro -= math.pi / 4),
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _recentrar,
              onScaleStart: (d) {
                _inercia.stop();
                _campoNoInicio = _campo;
                _dedos = d.pointerCount;
              },
              onScaleUpdate: (d) => setState(() {
                _mexeu = true;
                _dedos = math.max(_dedos, d.pointerCount);
                if (d.pointerCount > 1) {
                  _campo = (_campoNoInicio / d.scale)
                      .clamp(40 * math.pi / 180, 95 * math.pi / 180);
                } else {
                  _giro += d.focalPointDelta.dx * _radianosPorPonto;
                  _inclinacao = (_inclinacao + d.focalPointDelta.dy * 0.004)
                      .clamp(-0.7, 0.7);
                }
              }),
              onScaleEnd: (d) {
                if (_dedos > 1) return;
                final v = d.velocity.pixelsPerSecond.dx * _radianosPorPonto;
                if (v.abs() < 0.3) return;
                _inercia.value = _giro;
                unawaited(_inercia.animateWith(
                    FrictionSimulation(0.08, _giro, v.clamp(-6.0, 6.0))));
              },
              child: RepaintBoundary(
                key: widget.chaveDaCena,
                child: fs.SceneView(
                  cena.cena,
                  camera: _camera(),
                  warmUp: true,
                  loadingBuilder: (context, _) => ColoredBox(
                    color: c.folhaRebaixada,
                    child: const Center(child: IndicadorCarregando()),
                  ),
                ),
              ),
            ),
            Positioned(
              right: Espaco.e8,
              top: Espaco.e8,
              child: Column(
                children: [
                  _NoPapel(
                    child: BotaoIcone(
                      icone: _noite
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_outlined,
                      rotulo: _noite ? 'Ver de dia' : 'Ver de noite',
                      tamanho: Alvo.minimo,
                      aoTocar: _trocarHorario,
                    ),
                  ),
                  const SizedBox(height: Espaco.e8),
                  _NoPapel(
                    child: BotaoIcone(
                      icone: Icons.center_focus_strong_outlined,
                      rotulo: 'Voltar ao começo',
                      tamanho: Alvo.minimo,
                      aoTocar: _recentrar,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: Espaco.e8,
              bottom: Espaco.e8,
              child: MapaDoAndar(
                planta: widget.planta.planta(indice),
                comodo: widget.comodo,
                onde: _ondeFica,
                giro: _giro,
                campoHorizontal:
                    2 * math.atan(math.tan(_campo / 2) * proporcao),
                aoTocar: widget.aoTrocarComodo,
              ),
            ),
            Positioned(
              left: Espaco.margem,
              bottom: Espaco.e12,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _mexeu ? 0 : 1,
                  duration: const Duration(milliseconds: 400),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.papel,
                      borderRadius: Raio.cantoPequeno,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Espaco.e8, vertical: Espaco.e4),
                      child: Text(
                        'Arraste para olhar em volta',
                        style: Tipografia.apoio.copyWith(color: c.grafite),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Fundo de papel atrás de um botão que fica sobre a cena 3D (de noite a
/// cena escurece e o botão de contorno sumiria).
class _NoPapel extends StatelessWidget {
  const _NoPapel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.cores.papel.withValues(alpha: 0.92),
          borderRadius: Raio.cantoPequeno,
        ),
        child: child,
      );
}

/// O andar visto de cima no canto da vista 360°: os cômodos, o atual em
/// destaque, onde a pessoa está e o cone para onde ela olha. Tocar num
/// cômodo coberto chama [aoTocar] com o id dele.
class MapaDoAndar extends StatelessWidget {
  const MapaDoAndar({
    super.key,
    required this.planta,
    required this.comodo,
    required this.onde,
    required this.giro,
    required this.campoHorizontal,
    this.aoTocar,
  });

  final PlantaObra planta;
  final ComodoPlanta comodo;
  final (double, double) onde;
  final double giro;
  final double campoHorizontal;
  final ValueChanged<String>? aoTocar;

  static const double lado = 112;

  /// Escala e deslocamento da planta para caber no quadrado.
  (double, double, double) _encaixe() {
    const borda = 8.0;
    final escala = (lado - 2 * borda) /
        math.max(planta.largura, math.max(planta.profundidade, 1));
    final dx = (lado - planta.largura * escala) / 2;
    final dy = (lado - planta.profundidade * escala) / 2;
    return (escala, dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final (escala, dx, dy) = _encaixe();
    return Semantics(
      label: 'Mapa do andar: você está em ${comodo.nome}.'
          '${aoTocar != null ? ' Toque noutro cômodo para ir até ele.' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: aoTocar == null
            ? null
            : (d) {
                final x = (d.localPosition.dx - dx) / escala;
                final y = (d.localPosition.dy - dy) / escala;
                for (final k in planta.comodos) {
                  if (!k.coberto || k.id == comodo.id) continue;
                  if (k.retangulos.any(
                      (r) => x >= r.x && x <= r.x1 && y >= r.y && y <= r.y1)) {
                    unawaited(Tato.leve());
                    aoTocar!(k.id);
                    return;
                  }
                }
              },
        child: Container(
          width: lado,
          height: lado,
          decoration: BoxDecoration(
            color: c.papel.withValues(alpha: 0.92),
            borderRadius: Raio.cantoPequeno,
            border: Border.all(color: c.traco, width: Traco.fino),
          ),
          child: CustomPaint(
            painter: _PintorMapa(
              planta: planta,
              atual: comodo.id,
              onde: onde,
              giro: giro,
              campo: campoHorizontal,
              escala: escala,
              dx: dx,
              dy: dy,
              cores: c,
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorMapa extends CustomPainter {
  _PintorMapa({
    required this.planta,
    required this.atual,
    required this.onde,
    required this.giro,
    required this.campo,
    required this.escala,
    required this.dx,
    required this.dy,
    required this.cores,
  });

  final PlantaObra planta;
  final String atual;
  final (double, double) onde;
  final double giro, campo, escala, dx, dy;
  final CoresObra cores;

  Offset _p(double x, double y) => Offset(dx + x * escala, dy + y * escala);

  @override
  void paint(Canvas canvas, Size size) {
    final cheio = Paint()..color = cores.folha;
    final fora = Paint()..color = cores.folhaRebaixada;
    final contorno = Paint()
      ..color = cores.grafite2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final destaque = Paint()..color = cores.marca.withValues(alpha: 0.28);
    for (final k in planta.comodos) {
      for (final r in k.retangulos) {
        final ret = Rect.fromPoints(_p(r.x, r.y), _p(r.x1, r.y1));
        canvas.drawRect(ret, k.coberto ? cheio : fora);
        if (k.id == atual) canvas.drawRect(ret, destaque);
        canvas.drawRect(ret, contorno);
      }
    }
    // O cone de visão: na planta, olhar no giro g é andar (sen g, -cos g).
    final o = _p(onde.$1, onde.$2);
    const alcance = 26.0;
    final cone = Path()..moveTo(o.dx, o.dy);
    for (var i = 0; i <= 12; i++) {
      final a = giro - campo / 2 + campo * i / 12;
      cone.lineTo(o.dx + math.sin(a) * alcance, o.dy - math.cos(a) * alcance);
    }
    cone.close();
    canvas.drawPath(cone, Paint()..color = cores.marca.withValues(alpha: 0.35));
    canvas.drawCircle(o, 3.5, Paint()..color = cores.marca);
  }

  @override
  bool shouldRepaint(covariant _PintorMapa old) =>
      old.giro != giro ||
      old.campo != campo ||
      old.atual != atual ||
      old.onde != onde ||
      old.cores != cores ||
      old.planta != planta;
}

/// As quatro paredes do cômodo desdobradas, como num desenho de
/// elevações: cada lado com a largura dele, o pé-direito, as portas (do
/// chão) e as janelas (no peitoril). É o 360° sem 3D.
class ParedesDoComodo extends StatelessWidget {
  const ParedesDoComodo(
      {super.key, required this.planta, required this.comodo});

  final PlantaObra planta;
  final ComodoPlanta comodo;

  /// Os lados do retângulo principal, na ordem de quem gira olhando em
  /// volta: fundo, direita, frente, esquerda.
  List<(String, double, List<(double, double, AberturaPlanta)>)> _lados() {
    final r = comodo.principal;
    final lados = [
      ('Fundo', (r.x, r.y), (r.x1, r.y)),
      ('Direita', (r.x1, r.y), (r.x1, r.y1)),
      ('Frente', (r.x1, r.y1), (r.x, r.y1)),
      ('Esquerda', (r.x, r.y1), (r.x, r.y)),
    ];
    final saida = <(String, double, List<(double, double, AberturaPlanta)>)>[];
    for (final (nome, a, b) in lados) {
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
      final comprimento = math.sqrt(dx * dx + dy * dy);
      final ux = dx / comprimento, uy = dy / comprimento;
      final vaos = <(double, double, AberturaPlanta)>[];
      for (final w in planta.paredes) {
        for (final v in w.aberturas) {
          final p0 = w.pontoEm(v.inicio), p1 = w.pontoEm(v.inicio + v.largura);
          final meio = ((p0.$1 + p1.$1) / 2, (p0.$2 + p1.$2) / 2);
          // Distância do meio do vão à linha deste lado.
          final rx = meio.$1 - a.$1, ry = meio.$2 - a.$2;
          final ao = rx * ux + ry * uy;
          final fora = (rx * -uy + ry * ux).abs();
          if (fora > w.espessura / 2 + 0.15 || ao < 0 || ao > comprimento) {
            continue;
          }
          double proj((double, double) p) =>
              (p.$1 - a.$1) * ux + (p.$2 - a.$2) * uy;
          final s0 = proj(p0), s1 = proj(p1);
          vaos.add((
            math.max(0, math.min(s0, s1)),
            math.min(comprimento, math.max(s0, s1)),
            v,
          ));
        }
      }
      saida.add((nome, comprimento, vaos));
    }
    return saida;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final lados = _lados();
    final pe = comodo.coberto ? planta.alturas.peDireito : 2.2;
    return LayoutBuilder(builder: (context, caixa) {
      // Uma escala para os quatro lados (as proporções valem entre eles).
      final escala = (caixa.maxHeight - 64) / pe;
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Espaco.margem),
        children: [
          for (final (nome, comprimento, vaos) in lados)
            Padding(
              padding: const EdgeInsets.only(right: Espaco.e12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: math.max(comprimento * escala, 60),
                    height: pe * escala,
                    decoration: BoxDecoration(
                      color: c.folha,
                      border: Border.all(color: c.grafite, width: Traco.forte),
                    ),
                    child: CustomPaint(
                      painter: _Elevacao(
                        comprimento: comprimento,
                        altura: pe,
                        vaos: vaos,
                        alturas: planta.alturas,
                        cores: c,
                      ),
                    ),
                  ),
                  const SizedBox(height: Espaco.e8),
                  Text(
                    '${nome.toUpperCase()} · '
                    '${comprimento.toStringAsFixed(2).replaceAll('.', ',')} m',
                    style: Tipografia.rotulo.copyWith(color: c.grafite2),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

class _Elevacao extends CustomPainter {
  _Elevacao({
    required this.comprimento,
    required this.altura,
    required this.vaos,
    required this.alturas,
    required this.cores,
  });

  final double comprimento;
  final double altura;
  final List<(double, double, AberturaPlanta)> vaos;
  final AlturasPlanta alturas;
  final CoresObra cores;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / comprimento, sy = size.height / altura;
    for (final (u0, u1, v) in vaos) {
      final base = v.base(alturas), topo = math.min(v.topo(alturas), altura);
      final r = Rect.fromLTRB(
          u0 * sx, size.height - topo * sy, u1 * sx, size.height - base * sy);
      canvas.drawRect(
          r,
          Paint()
            ..color = v.tipo.ehJanela ? cores.folhaRebaixada : cores.papel);
      canvas.drawRect(
          r,
          Paint()
            ..color = cores.grafite
            ..style = PaintingStyle.stroke
            ..strokeWidth = Traco.fino);
      if (v.tipo.ehJanela) {
        // Folhas da janela.
        canvas.drawLine(
            r.topCenter,
            r.bottomCenter,
            Paint()
              ..color = cores.traco
              ..strokeWidth = Traco.fino);
      } else if (v.tipo == TipoAbertura.porta ||
          v.tipo == TipoAbertura.portaPivotante) {
        // Maçaneta.
        canvas.drawCircle(Offset(r.right - 8, r.center.dy), 2.5,
            Paint()..color = cores.grafite);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Elevacao old) =>
      old.comprimento != comprimento || old.vaos != vaos || old.cores != cores;
}
