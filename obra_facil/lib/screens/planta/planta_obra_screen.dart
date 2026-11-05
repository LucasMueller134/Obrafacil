import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import 'como_vai_ficar.dart';
import 'enviar_planta.dart';
import 'ficha_comodo.dart';

/// A planta de exemplo que vem no app (uma casa térrea de 7 x 20 m, do
/// projeto aberto casa-3d, licença MIT): serve para ver a maquete gerada
/// pela planta antes de enviar a da obra.
const String caminhoPlantaExemplo = 'assets/plantas/casa_7x20.json';

Future<PlantaObra> carregarPlantaExemplo([AssetBundle? bundle]) async {
  final texto = await (bundle ?? rootBundle).loadString(caminhoPlantaExemplo);
  return PlantaObra.fromMap(jsonDecode(texto) as Map<String, dynamic>);
}

/// A planta da obra: a planta desenhada (tocar num cômodo abre a ficha
/// dele) e a lista de cômodos. Sem planta, o dono envia a da obra ou usa a
/// de exemplo. É daqui que a maquete da central sai igual à obra.
class PlantaObraScreen extends StatelessWidget {
  const PlantaObraScreen({super.key, required this.obraId});

  final String obraId;

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _PlantaDaObra(obraId: obraId));
}

class _PlantaDaObra extends StatefulWidget {
  const _PlantaDaObra({required this.obraId});

  final String obraId;

  @override
  State<_PlantaDaObra> createState() => _PlantaDaObraState();
}

class _PlantaDaObraState extends State<_PlantaDaObra> {
  late final Stream<PlantaObra?> _planta =
      context.read<FirestoreService>().planta(widget.obraId);
  late final Stream<ObraModel?> _obra =
      context.read<FirestoreService>().obra(widget.obraId);
  late final Stream<List<ImagemIaModel>> _imagens =
      context.read<FirestoreService>().imagens(widget.obraId);
  String? _selecionado;
  bool _salvando = false;
  final _chaveFicha = GlobalKey();

  /// Escolhe o cômodo e, depois do quadro, rola até a ficha dele.
  void _escolher(String? id, {bool rolar = false}) {
    unawaited(Tato.leve());
    setState(() => _selecionado = id);
    if (!rolar) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ficha = _chaveFicha.currentContext;
      if (ficha == null || !ficha.mounted) return;
      unawaited(Scrollable.ensureVisible(
        ficha,
        duration: ficha.duracao(Movimento.medio),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ehDono = context.watch<AuthProvider>().ehDono;
    return StreamBuilder<ObraModel?>(
      stream: _obra,
      builder: (context, obraSnap) => StreamBuilder<PlantaObra?>(
        stream: _planta,
        builder: (context, snap) {
          final carregando = snap.connectionState == ConnectionState.waiting;
          final planta = snap.data;
          return Scaffold(
            appBar: AppBar(
              actions: [
                if (ehDono && planta != null)
                  PopupMenuButton<String>(
                    tooltip: 'Ações da planta',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (acao) => acao == 'enviar'
                        ? unawaited(enviarPlanta(context, widget.obraId))
                        : _remover(context, planta),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'enviar', child: Text('Enviar outra planta')),
                      PopupMenuItem(
                          value: 'remover', child: Text('Remover a planta')),
                    ],
                  ),
                const SizedBox(width: Espaco.e4),
              ],
            ),
            body: carregando
                ? ListView(
                    padding: const EdgeInsets.all(Espaco.margem),
                    children: const [
                      EsqueletoFolha(
                          linhas: 2, rotuloSemantico: 'Abrindo a planta'),
                    ],
                  )
                : _corpo(context, obraSnap.data, planta, ehDono),
            bottomNavigationBar: !carregando && planta == null && ehDono
                ? BarraDeAcao(
                    principal: BotaoPrincipal(
                      rotulo: 'Enviar a planta',
                      icone: Icons.upload_file_outlined,
                      grande: true,
                      expandir: true,
                      aoTocar: () => unawaited(enviarPlanta(context, widget.obraId)),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _corpo(
      BuildContext context, ObraModel? obra, PlantaObra? planta, bool ehDono) {
    final c = context.cores;
    final cabecalho = Carimbo(linhas: [
      [
        CelulaCarimbo(
          rotulo: 'Planta',
          conteudo: Semantics(
            header: true,
            child: Text(
              obra?.nome ?? 'Obra',
              style: Tipografia.tituloTela.copyWith(color: c.grafite),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      if (planta != null)
        [
          CelulaCarimbo(
            rotulo: 'Construído',
            valor: '${planta.areaConstruida.toStringAsFixed(0)} m²',
          ),
          CelulaCarimbo(
            rotulo: 'Terreno',
            valor: '${_m(planta.largura)} × ${_m(planta.profundidade)} m',
          ),
        ],
    ]);

    if (planta == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
            Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
        children: [
          cabecalho,
          const SizedBox(height: Espaco.e24),
          AvisoVazio(
            icone: Icons.architecture_outlined,
            titulo: 'Sem planta ainda',
            texto: ehDono
                ? 'Com a planta, a maquete da central fica igual à sua obra '
                    'e o cliente vê cada cômodo, até em 360°. Qualquer '
                    'formato serve: foto, PDF ou o arquivo do CAD.'
                : 'O dono da obra ainda não enviou a planta.',
            acao: ehDono
                ? BotaoContorno(
                    rotulo: 'Usar a casa de exemplo (7 × 20 m)',
                    expandir: true,
                    carregando: _salvando,
                    aoTocar: _salvando ? null : () => _usarExemplo(context),
                  )
                : null,
          ),
        ],
      );
    }

    final comodos = [...planta.comodos]
      ..sort((a, b) => (b.coberto ? 1 : 0).compareTo(a.coberto ? 1 : 0));
    // A legenda: o mesmo número na planta e na lista.
    final numeros = {
      for (var i = 0; i < comodos.length; i++) comodos[i].id: i + 1,
    };
    final selecionado =
        planta.comodos.where((x) => x.id == _selecionado).firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
      children: [
        cabecalho,
        const SizedBox(height: Espaco.e16),
        Folha(
          preenchimento: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, caixa) => SizedBox(
              height: PlantaDesenhada.alturaPara(planta, caixa.maxWidth),
              child: PlantaDesenhada(
                planta: planta,
                numeros: numeros,
                selecionado: _selecionado,
                aoTocarComodo: (comodo) => _escolher(
                    _selecionado == comodo.id ? null : comodo.id,
                    rolar: true),
              ),
            ),
          ),
        ),
        const SizedBox(height: Espaco.e8),
        Text(
          'Toque num cômodo para ver as medidas. Os números são os da lista.',
          style: Tipografia.apoio.copyWith(color: c.grafite2),
        ),
        if (selecionado != null) ...[
          const SizedBox(height: Espaco.e16),
          FichaComodo(
            key: _chaveFicha,
            planta: planta,
            comodo: selecionado,
            acao: BotaoPrincipal(
              rotulo: 'Ver em 360°',
              icone: Icons.threesixty,
              expandir: true,
              aoTocar: () => context
                  .push('/obras/${widget.obraId}/planta/${selecionado.id}/360'),
            ),
          ),
        ],
        _ComoVaiFicar(
          obraId: widget.obraId,
          planta: planta,
          imagens: _imagens,
          ehDono: ehDono,
        ),
        const SizedBox(height: Espaco.e24),
        Semantics(
          header: true,
          container: true,
          child: LinhaCota(legenda: '${comodos.length} cômodos'),
        ),
        const SizedBox(height: Espaco.e16),
        Folha(
          preenchimento: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < comodos.length; i++)
                LinhaLista(
                  inicio: NumeroDeLegenda(i + 1),
                  titulo: comodos[i].nome,
                  apoio: '${medidasDoComodo(comodos[i])} · '
                      '${comodos[i].coberto ? comodos[i].piso.rotulo : 'descoberto'}',
                  valor: areaDoComodo(comodos[i]),
                  margemHorizontal: Espaco.e12,
                  divisoria: i < comodos.length - 1,
                  aoTocar: () => _abrirFicha(context, planta, comodos[i]),
                ),
            ],
          ),
        ),
        if (planta.fonte != null) ...[
          const SizedBox(height: Espaco.e16),
          Text(
            'Fonte da planta: ${planta.fonte}',
            style: Tipografia.apoio.copyWith(color: c.grafite2),
          ),
        ],
      ],
    );
  }

  static String _m(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  /// Da lista: a ficha sobe numa folha (a planta, lá em cima, também
  /// destaca o cômodo).
  void _abrirFicha(BuildContext context, PlantaObra planta, ComodoPlanta c) {
    unawaited(Tato.leve());
    setState(() => _selecionado = c.id);
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              Espaco.margem, Espaco.e8, Espaco.margem, Espaco.e16),
          child: FichaComodo(
            planta: planta,
            comodo: c,
            acao: BotaoPrincipal(
              rotulo: 'Ver em 360°',
              icone: Icons.threesixty,
              expandir: true,
              aoTocar: () {
                Navigator.pop(ctx);
                context.push('/obras/${widget.obraId}/planta/${c.id}/360');
              },
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> _usarExemplo(BuildContext context) async {
    setState(() => _salvando = true);
    final db = context.read<FirestoreService>();
    try {
      final planta =
          await carregarPlantaExemplo(DefaultAssetBundle.of(context));
      await db.salvarPlanta(widget.obraId, planta);
      unawaited(Tato.confirmar());
      if (context.mounted) {
        mostrarAviso(
          context,
          'Planta de exemplo na obra. A maquete da central já é esta casa.',
          aoDesfazer: () => unawaited(db.excluirPlanta(widget.obraId)),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _remover(BuildContext context, PlantaObra planta) {
    final db = context.read<FirestoreService>();
    unawaited(db.excluirPlanta(widget.obraId));
    unawaited(Tato.confirmar());
    setState(() => _selecionado = null);
    mostrarAviso(
      context,
      'Planta removida. A maquete volta a ser a casa-padrão.',
      aoDesfazer: () => unawaited(db.salvarPlanta(widget.obraId, planta)),
    );
  }
}

/// As imagens "como vai ficar" (Nano Banana Pro, numa Cloud Function) e,
/// para o dono, o botão de gerar a da fachada. Cômodos: pela vista 360°.
class _ComoVaiFicar extends StatelessWidget {
  const _ComoVaiFicar({
    required this.obraId,
    required this.planta,
    required this.imagens,
    required this.ehDono,
  });

  final String obraId;
  final PlantaObra planta;
  final Stream<List<ImagemIaModel>> imagens;
  final bool ehDono;

  void _gerarFachada(BuildContext context) {
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TemaPrancheta(
        child: GerarImagemScreen(
          obraId: obraId,
          pedido: const PedidoImagem.fachada(),
          maquete: LayoutBuilder(
            builder: (context, caixa) => MaqueteObra(
              progresso: ProgressoMaquete.fases(
                  List<double>.filled(ProgressoMaquete.totalFases, 1)),
              fonte: FontePlanta(planta),
              altura: caixa.maxHeight,
              legenda: false,
            ),
          ),
        ),
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return StreamBuilder<List<ImagemIaModel>>(
      stream: imagens,
      builder: (context, snap) {
        final lista = snap.data ?? const <ImagemIaModel>[];
        if (lista.isEmpty && !ehDono) return const SizedBox.shrink();
        final temFachada = lista.any((i) => i.ehFachada);
        return Padding(
          padding: const EdgeInsets.only(top: Espaco.e24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                container: true,
                child: const LinhaCota(legenda: 'Como vai ficar'),
              ),
              const SizedBox(height: Espaco.e12),
              if (lista.isNotEmpty) ...[
                GaleriaComoVaiFicar(imagens: lista),
                const SizedBox(height: Espaco.e12),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: Espaco.e12),
                  child: Text(
                    'Uma foto realista da casa pronta, pintada pela IA por '
                    'cima da maquete, com as medidas da planta. Os cômodos '
                    'se geram pela vista 360°.',
                    style: Tipografia.corpo.copyWith(color: c.grafite2),
                  ),
                ),
              if (ehDono)
                BotaoContorno(
                  rotulo: temFachada
                      ? 'Gerar a fachada de novo'
                      : 'Gerar a fachada',
                  icone: Icons.auto_awesome_outlined,
                  expandir: true,
                  aoTocar: () => _gerarFachada(context),
                ),
            ],
          ),
        );
      },
    );
  }
}
