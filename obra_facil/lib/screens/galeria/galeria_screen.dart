import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../design/design.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/mensagens_erro.dart';
import '../../services/ia/progresso_foto_service.dart';
import '../../services/imagem_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/botao_ia.dart';
import '../../widgets/imagem_obra.dart';

/// A galeria da obra: as fotos em linha do tempo, por mês. Dá para
/// comparar duas fotos (a IA mede o quanto a cena mudou).
class GaleriaScreen extends StatelessWidget {
  final String obraId;

  const GaleriaScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _Galeria(obraId: obraId));
}

class _Galeria extends StatefulWidget {
  const _Galeria({required this.obraId});

  final String obraId;

  @override
  State<_Galeria> createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<_Galeria> {
  /// Modo de comparação visual por IA: seleciona 2 fotos.
  bool _comparando = false;
  final List<FotoObraModel> _selecionadas = [];

  late final Stream<List<FotoObraModel>> _fotos =
      context.read<FirestoreService>().fotos(widget.obraId);
  late final Stream<ObraModel?> _obra =
      context.read<FirestoreService>().obra(widget.obraId);

  void _alternarComparacao() {
    unawaited(Tato.leve());
    setState(() {
      _comparando = !_comparando;
      _selecionadas.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<List<FotoObraModel>>(
        stream: _fotos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.all(Espaco.margem),
              children: const [
                EsqueletoFolha(linhas: 3, rotuloSemantico: 'Abrindo as fotos'),
              ],
            );
          }
          final fotos = snapshot.data ?? const <FotoObraModel>[];

          // Agrupa por mês para a linha do tempo.
          final grupos = <String, List<FotoObraModel>>{};
          final formatoMes = DateFormat("MMMM 'de' yyyy", 'pt_BR');
          for (final f in fotos) {
            final chave = formatoMes.format(f.data);
            grupos.putIfAbsent(chave, () => []).add(f);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
            children: [
              StreamBuilder<ObraModel?>(
                stream: _obra,
                builder: (context, obra) => Carimbo(linhas: [
                  [
                    CelulaCarimbo(
                      rotulo: 'Galeria',
                      conteudo: Semantics(
                        header: true,
                        child: Text(
                          obra.data?.nome ?? 'Obra',
                          style:
                              Tipografia.tituloTela.copyWith(color: c.grafite),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  [
                    CelulaCarimbo(rotulo: 'Fotos', valor: '${fotos.length}'),
                    CelulaCarimbo(
                      rotulo: 'Última',
                      valor: fotos.isEmpty
                          ? '—'
                          : Formatters.data(fotos.first.data),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: Espaco.e16),
              if (fotos.isEmpty)
                const AvisoVazio(
                  icone: Icons.photo_library_outlined,
                  titulo: 'Nenhuma foto ainda',
                  texto: 'Registre a evolução da obra com fotos: elas viram '
                      'uma linha do tempo do canteiro.',
                )
              else ...[
                if (_comparando)
                  Semantics(
                    liveRegion: true,
                    child: NotaRevisao(
                      'Toque em 2 fotos para comparar '
                      '(${_selecionadas.length}/2)',
                      tipo: TipoNota.marca,
                      icone: Icons.compare_outlined,
                    ),
                  )
                else if (fotos.length >= 2)
                  BotaoContorno(
                    rotulo: 'Comparar duas fotos (IA)',
                    icone: Icons.compare_outlined,
                    expandir: true,
                    aoTocar: _alternarComparacao,
                  ),
                for (final grupo in grupos.entries) ...[
                  const SizedBox(height: Espaco.e24),
                  LinhaCota(
                    legenda:
                        grupo.key[0].toUpperCase() + grupo.key.substring(1),
                  ),
                  const SizedBox(height: Espaco.e12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    mainAxisSpacing: Espaco.e8,
                    crossAxisSpacing: Espaco.e8,
                    children: [
                      for (final foto in grupo.value)
                        _MiniaturaFoto(
                          foto: foto,
                          selecionada: _selecionadas.contains(foto),
                          onTap: () => _comparando
                              ? _alternarSelecao(foto)
                              : _abrirFoto(foto),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: _comparando
            ? BotaoContorno(
                rotulo: 'Cancelar comparação',
                icone: Icons.close,
                expandir: true,
                aoTocar: _alternarComparacao,
              )
            : BotaoPrincipal(
                rotulo: 'Adicionar foto',
                icone: Icons.add_a_photo_outlined,
                grande: true,
                expandir: true,
                aoTocar: () => unawaited(_adicionarFoto()),
              ),
      ),
    );
  }

  void _alternarSelecao(FotoObraModel foto) {
    setState(() {
      if (_selecionadas.contains(foto)) {
        _selecionadas.remove(foto);
      } else if (_selecionadas.length < 2) {
        _selecionadas.add(foto);
      }
    });
    unawaited(Tato.leve());
    if (_selecionadas.length == 2) unawaited(_compararSelecionadas());
  }

  Future<void> _compararSelecionadas() async {
    final fotos = List<FotoObraModel>.from(_selecionadas)
      ..sort((a, b) => a.data.compareTo(b.data));
    setState(() {
      _comparando = false;
      _selecionadas.clear();
    });

    if (!fotos.every((f) => ImagemService.ehDataUri(f.url))) {
      mostrarAviso(
          context, 'Comparação disponível apenas para fotos salvas no app.');
      return;
    }

    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Folha(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IndicadorCarregando(),
              const SizedBox(width: Espaco.e12),
              Text('Comparando as fotos…',
                  style: Tipografia.corpo.copyWith(color: ctx.cores.grafite)),
            ],
          ),
        ),
      ),
    ));
    final ComparacaoFotos resultado;
    try {
      resultado = await ProgressoFotoService.compararBytes(
        ImagemService.bytesDe(fotos[0].url),
        ImagemService.bytesDe(fotos[1].url),
      );
    } catch (e) {
      // Sem isto, uma foto ilegível deixava o carregamento aberto para
      // sempre, sem como fechar.
      debugPrint('Galeria: falha ao comparar as fotos: $e');
      if (!mounted) return;
      Navigator.pop(context); // fecha o loading
      unawaited(Tato.erro());
      mostrarAviso(context, MensagensErro.daAnalise(e, oQue: 'as fotos'));
      return;
    }
    if (!mounted) return;
    Navigator.pop(context); // fecha o loading

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.cores;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                Espaco.margem, Espaco.e8, Espaco.margem, Espaco.e16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Rotulo('Comparação das fotos (IA)'),
                const SizedBox(height: Espaco.e4),
                Text(
                  'Mudança visual: '
                  '${(resultado.indiceMudanca * 100).toStringAsFixed(0)}%',
                  style: Tipografia.titulo.copyWith(
                      color: c.grafite, fontFeatures: Tipografia.tabular),
                ),
                const SizedBox(height: Espaco.e12),
                Row(
                  children: [
                    for (final (i, f) in fotos.indexed) ...[
                      if (i > 0) const SizedBox(width: Espaco.e8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: Raio.cantoPequeno,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ImagemObra(f.url),
                              ),
                            ),
                            const SizedBox(height: Espaco.e4),
                            Text(
                              '${i == 0 ? 'Antes' : 'Depois'} · '
                              '${Formatters.data(f.data)}',
                              style: Tipografia.apoio.copyWith(
                                  color: c.grafite,
                                  fontFeatures: Tipografia.tabular),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Espaco.e16),
                Text(resultado.interpretacao,
                    style: Tipografia.corpo.copyWith(color: c.grafite)),
                if (resultado.luzMuitoDiferente) ...[
                  const SizedBox(height: Espaco.e12),
                  AvisoIa(
                    mensagem: 'As fotos têm luz bem diferente. A comparação '
                        'já desconta isso, mas mede melhor com fotos no '
                        'mesmo horário.',
                  ),
                ],
                const SizedBox(height: Espaco.e12),
                Text(
                  'Análise experimental feita no aparelho: compara as formas '
                  'e bordas das duas imagens, já descontando a diferença de '
                  'luz. Mostra o quanto a cena mudou, não o quanto a obra '
                  'avançou. Para comparar, fotografe sempre do mesmo ponto.',
                  style: Tipografia.apoio.copyWith(color: c.grafite2),
                ),
                const SizedBox(height: Espaco.e16),
                BotaoContorno(
                  rotulo: 'Fechar',
                  expandir: true,
                  aoTocar: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _adicionarFoto() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinhaLista(
              icone: Icons.photo_camera_outlined,
              titulo: 'Tirar foto',
              divisoria: true,
              aoTocar: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            LinhaLista(
              icone: Icons.photo_library_outlined,
              titulo: 'Escolher da galeria',
              aoTocar: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origem == null || !mounted) return;

    final xfile = await ImagePicker().pickImage(
      source: origem,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (xfile == null || !mounted) return;

    String? fase;
    final descricaoCtrl = TextEditingController();
    final salvar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: Espaco.margem,
            right: Espaco.margem,
            top: Espaco.e8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).viewPadding.bottom +
                Espaco.e16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Rotulo('Galeria'),
                const SizedBox(height: Espaco.e4),
                Text('Nova foto',
                    style:
                        Tipografia.titulo.copyWith(color: ctx.cores.grafite)),
                const SizedBox(height: Espaco.e12),
                ClipRRect(
                  borderRadius: Raio.cantoPequeno,
                  child: Image.file(File(xfile.path),
                      height: 200, fit: BoxFit.cover),
                ),
                const SizedBox(height: Espaco.e16),
                DropdownButtonFormField<String>(
                  initialValue: fase,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Fase (opcional)'),
                  items: [
                    for (final f in AppConstants.fasesPadrao)
                      DropdownMenuItem(value: f, child: Text(f)),
                  ],
                  onChanged: (v) => setSheet(() => fase = v),
                ),
                const SizedBox(height: Espaco.e16),
                TextField(
                  controller: descricaoCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(labelText: 'Descrição (opcional)'),
                ),
                const SizedBox(height: Espaco.e24),
                BotaoPrincipal(
                  rotulo: 'Salvar foto',
                  icone: Icons.check,
                  grande: true,
                  expandir: true,
                  aoTocar: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (salvar != true || !mounted) return;

    final db = context.read<FirestoreService>();
    final usuario = context.read<AuthProvider>().usuario!;
    final dataUri = await ImagemService.comprimirParaDataUri(File(xfile.path));
    await db.criarFoto(FotoObraModel(
      id: '',
      obraId: widget.obraId,
      url: dataUri,
      fase: fase,
      descricao:
          descricaoCtrl.text.trim().isEmpty ? null : descricaoCtrl.text.trim(),
      registradoPorNome: usuario.nome,
      data: DateTime.now(),
    ));
    unawaited(Tato.confirmar());
    if (mounted) mostrarAviso(context, 'Foto na galeria da obra.');
  }

  void _abrirFoto(FotoObraModel foto) {
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TemaPrancheta(
        child: _FotoCheia(
          foto: foto,
          aoExcluir: () {
            final db = context.read<FirestoreService>();
            unawaited(db.excluirFoto(widget.obraId, foto.id));
            unawaited(Tato.confirmar());
            mostrarAviso(context, 'Foto excluída.',
                aoDesfazer: () => unawaited(db.criarFoto(foto)));
          },
        ),
      ),
    )));
  }
}

/// A foto em tela cheia, com zoom, a data, a fase e quem tirou.
class _FotoCheia extends StatelessWidget {
  const _FotoCheia({required this.foto, required this.aoExcluir});

  final FotoObraModel foto;
  final VoidCallback aoExcluir;

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(
        title: Text(Formatters.data(foto.data)),
        actions: [
          IconButton(
            tooltip: 'Excluir foto',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.pop(context);
              aoExcluir();
            },
          ),
          const SizedBox(width: Espaco.e4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: c.folhaRebaixada,
              child: InteractiveViewer(
                maxScale: 6,
                child: ImagemObra(foto.url, fit: BoxFit.contain),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Espaco.margem),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (foto.fase != null)
                    Text(foto.fase!.toUpperCase(),
                        style: Tipografia.rotulo.copyWith(color: c.marcaTexto)),
                  if (foto.descricao != null) ...[
                    const SizedBox(height: Espaco.e4),
                    Text(foto.descricao!,
                        style: Tipografia.corpo.copyWith(color: c.grafite)),
                  ],
                  const SizedBox(height: Espaco.e4),
                  Text(
                    '${Formatters.diaSemana(foto.data)} · por '
                    '${foto.registradoPorNome}',
                    style: Tipografia.apoio.copyWith(color: c.grafite2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniaturaFoto extends StatelessWidget {
  final FotoObraModel foto;
  final bool selecionada;
  final VoidCallback onTap;

  const _MiniaturaFoto({
    required this.foto,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return AreaPressionavel(
      aoTocar: onTap,
      selecionado: selecionada,
      rotuloSemantico: 'Foto de ${Formatters.data(foto.data)}'
          '${foto.fase != null ? ', ${foto.fase}' : ''}',
      construtor: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: Raio.cantoPequeno,
            child: ImagemObra(foto.url),
          ),
          if (selecionada)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: Raio.cantoPequeno,
                border: Border.all(color: c.grafite, width: 4),
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(Espaco.e4),
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(color: c.marca, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(Espaco.e4),
                      child: Icon(Icons.check, size: 20, color: c.sobreMarca),
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
