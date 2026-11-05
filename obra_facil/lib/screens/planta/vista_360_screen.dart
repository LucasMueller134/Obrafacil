import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../../services/firestore_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return StreamBuilder<PlantaObra?>(
      stream: _planta,
      builder: (context, snap) {
        final planta = snap.data;
        final comodo =
            planta?.comodos.where((x) => x.id == widget.comodoId).firstOrNull;
        return Scaffold(
          appBar: AppBar(),
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
                      child: Interior360(planta: planta, comodo: comodo),
                    ),
                    const SizedBox(height: Espaco.e16),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Espaco.margem),
                      child: FichaComodo(planta: planta, comodo: comodo),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// O cômodo por dentro: 3D em tempo real quando o aparelho tem Flutter GPU;
/// senão, as quatro paredes desdobradas ([ParedesDoComodo]).
class Interior360 extends StatefulWidget {
  const Interior360({super.key, required this.planta, required this.comodo});

  final PlantaObra planta;
  final ComodoPlanta comodo;

  @override
  State<Interior360> createState() => _Interior360State();
}

class _Interior360State extends State<Interior360> {
  CenaMaquete? _cena;
  bool _semTresD = false;
  bool _descartado = false;

  /// Para onde o olho aponta: giro (em volta do eixo vertical) e
  /// inclinação (para cima/baixo), em radianos; e o campo de visão.
  double _giro = 0;
  double _inclinacao = -0.08;
  double _campo = 70 * math.pi / 180;
  double _campoNoInicio = 0;

  static const double _alturaDoOlho = 1.6;

  @override
  void initState() {
    super.initState();
    _giro = _giroInicial();
    // O tema e a MediaQuery só podem ser lidos depois do initState.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_carregar());
    });
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
        fonte: FontePlanta(widget.planta),
      );
      if (_descartado || !mounted) {
        cena.descartar();
        return;
      }
      // A casa pronta, sem o tracejado; luz sem sombra (dentro, a laje
      // deixaria tudo no escuro).
      cena.aplicar(PlanoMaquete.calcular(
          List<double>.filled(ProgressoMaquete.totalFases, 1)));
      cena.cena.directionalLight = fs.DirectionalLight(
        direction: CenaMaquete.direcaoDaLuz,
        color: vm.Vector3(1.0, 0.975, 0.945),
        intensity: CenaMaquete.intensidadeDaLuz,
      );
      setState(() => _cena = cena);
    } catch (erro) {
      MaqueteObra.anotarFalhaGpu(erro);
      if (mounted) setState(() => _semTresD = true);
    }
  }

  @override
  void dispose() {
    _descartado = true;
    final cena = _cena;
    _cena = null;
    if (cena != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => cena.descartar());
    }
    super.dispose();
  }

  fs.PerspectiveCamera _camera() {
    final r = widget.comodo.principal;
    final (cx, cy) = GeradorMaquete.centroDe(widget.planta);
    // Planta -> glTF (X, Z) -> flutter_scene (Z invertido).
    final x = (r.x + r.x1) / 2 - cx;
    final z = -((r.y + r.y1) / 2 - cy);
    final y = NiveisMaquete.piso + _alturaDoOlho;
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
      return ParedesDoComodo(planta: widget.planta, comodo: widget.comodo);
    }
    if (cena == null) {
      return ColoredBox(
        color: c.folhaRebaixada,
        child: const Center(child: IndicadorCarregando()),
      );
    }
    return Semantics(
      label:
          'Vista 360° de ${widget.comodo.nome}. Arraste para olhar em volta.',
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
            onScaleStart: (_) => _campoNoInicio = _campo,
            onScaleUpdate: (d) => setState(() {
              if (d.pointerCount > 1) {
                _campo = (_campoNoInicio / d.scale)
                    .clamp(40 * math.pi / 180, 95 * math.pi / 180);
              } else {
                _giro += d.focalPointDelta.dx * 0.006;
                _inclinacao = (_inclinacao + d.focalPointDelta.dy * 0.004)
                    .clamp(-0.7, 0.7);
              }
            }),
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
          Positioned(
            left: Espaco.margem,
            bottom: Espaco.e12,
            child: IgnorePointer(
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
        ],
      ),
    );
  }
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
      } else if (v.tipo == TipoAbertura.porta) {
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
