import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/material_vision_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/estado_vazio.dart';

class EstoqueScreen extends StatelessWidget {
  final String obraId;

  const EstoqueScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Estoque')),
      body: StreamBuilder<List<EstoqueItemModel>>(
        stream: db.estoque(obraId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final itens = snapshot.data ?? const <EstoqueItemModel>[];
          if (itens.isEmpty) {
            return EstadoVazio(
              icone: Icons.inventory_2,
              titulo: 'Estoque vazio',
              mensagem:
                  'Cadastre os materiais do canteiro para receber alertas '
                  'quando estiverem acabando.',
              rotuloAcao: 'Adicionar material',
              onAcao: () => _abrirFormulario(context),
            );
          }
          final emAlerta = itens.where((i) => i.estoqueBaixo).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (emAlerta.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.erro.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.erro.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: AppColors.erro, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${emAlerta.length} '
                          'material${emAlerta.length > 1 ? 'is' : ''} com '
                          'estoque baixo: '
                          '${emAlerta.map((i) => i.material).join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final item in itens) ...[
                _CartaoEstoque(
                  item: item,
                  onTap: () => _abrirFormulario(context, item: item),
                  onAjuste: (delta) {
                    final nova =
                        (item.quantidade + delta).clamp(0.0, 999999.0);
                    db.salvarEstoqueItem(item.copyWith(quantidade: nova));
                  },
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 70),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context),
        icon: const Icon(Icons.add),
        label: const Text('Material'),
      ),
    );
  }

  void _abrirFormulario(BuildContext context, {EstoqueItemModel? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormEstoque(obraId: obraId, item: item),
    );
  }
}

class _CartaoEstoque extends StatelessWidget {
  final EstoqueItemModel item;
  final VoidCallback onTap;
  final void Function(double delta) onAjuste;

  const _CartaoEstoque({
    required this.item,
    required this.onTap,
    required this.onAjuste,
  });

  @override
  Widget build(BuildContext context) {
    final baixo = item.estoqueBaixo;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (baixo ? AppColors.erro : AppColors.laranja)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  baixo ? Icons.warning_amber : Icons.inventory_2,
                  color: baixo ? AppColors.erro : AppColors.laranja,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.material,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.quantidade(item.quantidade)} ${item.unidade}'
                      '${baixo ? ' · abaixo do mínimo (${Formatters.quantidade(item.quantidadeMinima)})' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: baixo
                                ? AppColors.erro
                                : AppColors.textoSecundario,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => onAjuste(-1),
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.textoSecundario,
              ),
              IconButton(
                onPressed: () => onAjuste(1),
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.laranja,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormEstoque extends StatefulWidget {
  final String obraId;
  final EstoqueItemModel? item;

  const _FormEstoque({required this.obraId, this.item});

  @override
  State<_FormEstoque> createState() => _FormEstoqueState();
}

class _FormEstoqueState extends State<_FormEstoque> {
  final _formKey = GlobalKey<FormState>();
  late final _materialCtrl =
      TextEditingController(text: widget.item?.material ?? '');
  late final _qtdCtrl = TextEditingController(
      text: widget.item != null
          ? Formatters.quantidade(widget.item!.quantidade)
          : '');
  late final _minCtrl = TextEditingController(
      text: widget.item != null
          ? Formatters.quantidade(widget.item!.quantidadeMinima)
          : '');
  late String _unidade = widget.item?.unidade ?? 'un';
  bool _reconhecendo = false;
  String? _resultadoVisao;

  @override
  void dispose() {
    _materialCtrl.dispose();
    _qtdCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  /// IA de visão: fotografa o material e sugere o nome.
  Future<void> _identificarPelaCamera() async {
    final xfile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (xfile == null || !mounted) return;

    setState(() {
      _reconhecendo = true;
      _resultadoVisao = null;
    });
    final visao = MaterialVisionService();
    try {
      final detectados = await visao.reconhecer(xfile.path);
      if (!mounted) return;
      setState(() {
        if (detectados.isEmpty) {
          _resultadoVisao =
              'Não reconheci um material de construção nesta foto.';
        } else {
          final melhor = detectados.first;
          _materialCtrl.text = melhor.material;
          _resultadoVisao =
              'Reconhecido: ${melhor.material} '
              '(${(melhor.confianca * 100).toStringAsFixed(0)}% de confiança'
              '${detectados.length > 1 ? '; alternativas: ${detectados.skip(1).map((d) => d.material).join(', ')}' : ''})';
        }
      });
    } finally {
      visao.dispose();
      if (mounted) setState(() => _reconhecendo = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final db = context.read<FirestoreService>();
    await db.salvarEstoqueItem(EstoqueItemModel(
      id: widget.item?.id ?? '',
      obraId: widget.obraId,
      material: _materialCtrl.text.trim(),
      quantidade: Formatters.parseValor(_qtdCtrl.text) ?? 0,
      unidade: _unidade,
      quantidadeMinima: Formatters.parseValor(_minCtrl.text) ?? 0,
      atualizadoEm: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _excluir() async {
    final db = context.read<FirestoreService>();
    await db.excluirEstoqueItem(widget.obraId, widget.item!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.item == null ? 'Novo material' : 'Editar material',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _materialCtrl.text),
                    optionsBuilder: (v) => v.text.isEmpty
                        ? const Iterable<String>.empty()
                        : AppConstants.materiaisComuns.where((m) => m
                            .toLowerCase()
                            .contains(v.text.toLowerCase())),
                    onSelected: (v) => _materialCtrl.text = v,
                    fieldViewBuilder:
                        (context, ctrl, focus, onSubmit) {
                      ctrl.addListener(
                          () => _materialCtrl.text = ctrl.text);
                      return TextFormField(
                        controller: ctrl,
                        focusNode: focus,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            labelText: 'Material'),
                        validator: (v) =>
                            Validators.obrigatorio(v, 'O material'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Identificar pela câmera (IA)',
                  onPressed: _reconhecendo ? null : _identificarPelaCamera,
                  icon: _reconhecendo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.camera_alt),
                ),
              ],
            ),
            if (_resultadoVisao != null) ...[
              const SizedBox(height: 8),
              Text(
                _resultadoVisao!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.amareloCapacete),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtdCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Quantidade'),
                    validator: Validators.numero,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unidade,
                    decoration: const InputDecoration(labelText: 'Unidade'),
                    items: [
                      for (final u in AppConstants.unidades)
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unidade = v ?? 'un'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantidade mínima (alerta)',
                helperText: 'Avisa quando o estoque ficar igual ou abaixo',
              ),
              validator: Validators.numero,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _salvar,
              child: const Text('Salvar'),
            ),
            if (widget.item != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _excluir,
                child: const Text('Excluir material',
                    style: TextStyle(color: AppColors.erro)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
