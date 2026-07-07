import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/progresso_foto_service.dart';
import '../../services/imagem_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/carregando_obra.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/ilustracoes.dart';
import '../../widgets/imagem_obra.dart';

class GaleriaScreen extends StatefulWidget {
  final String obraId;

  const GaleriaScreen({super.key, required this.obraId});

  @override
  State<GaleriaScreen> createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  /// Modo de comparação por IA: seleciona 2 fotos.
  bool _comparando = false;
  final List<FotoObraModel> _selecionadas = [];

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_comparando
            ? 'Escolha 2 fotos (${_selecionadas.length}/2)'
            : 'Galeria da obra'),
        actions: [
          IconButton(
            tooltip: _comparando
                ? 'Cancelar comparação'
                : 'Comparar progresso (IA)',
            icon: Icon(_comparando ? Icons.close : Icons.compare),
            onPressed: () => setState(() {
              _comparando = !_comparando;
              _selecionadas.clear();
            }),
          ),
        ],
      ),
      body: StreamBuilder<List<FotoObraModel>>(
        stream: db.fotos(widget.obraId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CarregandoObra(mensagem: 'Revelando as fotos…');
          }
          final fotos = snapshot.data ?? const <FotoObraModel>[];
          if (fotos.isEmpty) {
            return EstadoVazio(
              icone: Icons.photo_library,
              ilustracao: const IlustracaoPolaroids(),
              titulo: 'Nenhuma foto ainda',
              mensagem: 'Registre a evolução da obra com fotos — elas viram '
                  'uma linha do tempo do canteiro.',
              rotuloAcao: 'Adicionar foto',
              onAcao: _adicionarFoto,
            );
          }

          // Agrupa por mês para a linha do tempo.
          final grupos = <String, List<FotoObraModel>>{};
          final formatoMes = DateFormat("MMMM 'de' yyyy", 'pt_BR');
          for (final f in fotos) {
            final chave = formatoMes.format(f.data);
            grupos.putIfAbsent(chave, () => []).add(f);
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
            children: [
              for (final grupo in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(
                    grupo.key[0].toUpperCase() + grupo.key.substring(1),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.textoSecundario),
                  ),
                ),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
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
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
      floatingActionButton: _comparando
          ? null
          : FloatingActionButton.extended(
              onPressed: _adicionarFoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Foto'),
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
    if (_selecionadas.length == 2) _compararSelecionadas();
  }

  Future<void> _compararSelecionadas() async {
    final fotos = List<FotoObraModel>.from(_selecionadas)
      ..sort((a, b) => a.data.compareTo(b.data));
    setState(() {
      _comparando = false;
      _selecionadas.clear();
    });

    if (!fotos.every((f) => ImagemService.ehDataUri(f.url))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Comparação disponível apenas para fotos salvas no app.')));
      return;
    }

    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ));
    final resultado = await ProgressoFotoService.compararBytes(
      ImagemService.bytesDe(fotos[0].url),
      ImagemService.bytesDe(fotos[1].url),
    );
    if (!mounted) return;
    Navigator.pop(context); // fecha o loading

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Progresso por foto (IA)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final f in fotos)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ImagemObra(f.url),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(Formatters.data(f.data),
                              style: Theme.of(ctx).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Índice de mudança: '
              '${(resultado.indiceMudanca * 100).toStringAsFixed(0)}%',
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.laranja),
            ),
            const SizedBox(height: 6),
            Text(resultado.interpretacao,
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              'Análise experimental feita no aparelho, comparando a '
              'estrutura das duas imagens.',
              style: Theme.of(ctx)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoDesabilitado),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _adicionarFoto() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
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
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).viewPadding.bottom +
                24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(xfile.path),
                    height: 160, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: fase,
                decoration:
                    const InputDecoration(labelText: 'Fase (opcional)'),
                items: [
                  for (final f in AppConstants.fasesPadrao)
                    DropdownMenuItem(value: f, child: Text(f)),
                ],
                onChanged: (v) => setSheet(() => fase = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descricaoCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(labelText: 'Descrição (opcional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar foto'),
              ),
            ],
          ),
        ),
      ),
    );
    if (salvar != true || !mounted) return;

    final db = context.read<FirestoreService>();
    final usuario = context.read<AuthProvider>().usuario!;
    final dataUri =
        await ImagemService.comprimirParaDataUri(File(xfile.path));
    await db.criarFoto(FotoObraModel(
      id: '',
      obraId: widget.obraId,
      url: dataUri,
      fase: fase,
      descricao: descricaoCtrl.text.trim().isEmpty
          ? null
          : descricaoCtrl.text.trim(),
      registradoPorNome: usuario.nome,
      data: DateTime.now(),
    ));
  }

  void _abrirFoto(FotoObraModel foto) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: ImagemObra(foto.url, width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${Formatters.data(foto.data)}'
                    '${foto.fase != null ? ' · ${foto.fase}' : ''}',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (foto.descricao != null) ...[
                    const SizedBox(height: 6),
                    Text(foto.descricao!,
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'por ${foto.registradoPorNome}',
                    style: Theme.of(ctx)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textoSecundario),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await context
                              .read<FirestoreService>()
                              .excluirFoto(widget.obraId, foto.id);
                        },
                        child: const Text('Excluir',
                            style: TextStyle(color: AppColors.erro)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Fechar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ImagemObra(foto.url),
          ),
          if (selecionada)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.laranja, width: 3),
                color: AppColors.laranja.withValues(alpha: 0.25),
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.laranja, size: 30),
            ),
        ],
      ),
    );
  }
}
