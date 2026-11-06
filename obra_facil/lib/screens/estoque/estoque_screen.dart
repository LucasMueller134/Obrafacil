import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../design/design.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/material_vision_service.dart';
import '../../services/ia/mensagens_erro.dart';
import '../../services/ia/previsao_estoque_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/botao_ia.dart';

/// O estoque do canteiro: cada material com a quantidade, o mínimo e a
/// previsão de quando acaba no ritmo atual. − e + ajustam na hora (e
/// guardam o movimento, que alimenta a previsão).
class EstoqueScreen extends StatelessWidget {
  final String obraId;

  const EstoqueScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) =>
      TemaPrancheta(child: _Estoque(obraId: obraId));
}

class _Estoque extends StatefulWidget {
  const _Estoque({required this.obraId});

  final String obraId;

  @override
  State<_Estoque> createState() => _EstoqueState();
}

class _EstoqueState extends State<_Estoque> {
  late final FirestoreService _db = context.read<FirestoreService>();
  late final Stream<List<MovimentoEstoqueModel>> _movimentos =
      _db.movimentos(widget.obraId);
  late final Stream<List<DiarioEntradaModel>> _diario =
      _db.diario(widget.obraId);
  late final Stream<List<EstoqueItemModel>> _estoque =
      _db.estoque(widget.obraId);
  late final Stream<ObraModel?> _obra = _db.obra(widget.obraId);

  String get obraId => widget.obraId;

  void _ajustar(EstoqueItemModel item, double delta) {
    final nova = (item.quantidade + delta).clamp(0.0, 999999.0);
    if (nova == item.quantidade) return;
    unawaited(Tato.leve());
    _db.salvarEstoqueItem(item.copyWith(quantidade: nova));
    // Histórico de consumo — alimenta a previsão de término.
    _db.criarMovimento(MovimentoEstoqueModel(
      id: '',
      obraId: obraId,
      material: item.material,
      tipo:
          delta > 0 ? TipoMovimentoEstoque.entrada : TipoMovimentoEstoque.saida,
      quantidade: delta.abs(),
      unidade: item.unidade,
      origem: 'manual',
      data: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    return Scaffold(
      appBar: AppBar(),
      body: StreamBuilder<List<MovimentoEstoqueModel>>(
        stream: _movimentos,
        builder: (context, movSnap) => StreamBuilder<List<DiarioEntradaModel>>(
          stream: _diario,
          builder: (context, diarioSnap) =>
              StreamBuilder<List<EstoqueItemModel>>(
            stream: _estoque,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  padding: const EdgeInsets.all(Espaco.margem),
                  children: const [
                    EsqueletoFolha(
                        linhas: 4, rotuloSemantico: 'Contando os materiais'),
                  ],
                );
              }
              final itens = snapshot.data ?? const <EstoqueItemModel>[];
              final emAlerta = itens.where((i) => i.estoqueBaixo).toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    Espaco.margem, Espaco.e4, Espaco.margem, Espaco.e32),
                children: [
                  StreamBuilder<ObraModel?>(
                    stream: _obra,
                    builder: (context, obra) => Carimbo(linhas: [
                      [
                        CelulaCarimbo(
                          rotulo: 'Estoque',
                          conteudo: Semantics(
                            header: true,
                            child: Text(
                              obra.data?.nome ?? 'Obra',
                              style: Tipografia.tituloTela
                                  .copyWith(color: c.grafite),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      [
                        CelulaCarimbo(
                            rotulo: 'Materiais', valor: '${itens.length}'),
                        CelulaCarimbo(
                          rotulo: 'Abaixo do mínimo',
                          valor: '${emAlerta.length}',
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: Espaco.e16),
                  if (itens.isEmpty)
                    const AvisoVazio(
                      icone: Icons.inventory_2_outlined,
                      titulo: 'Estoque vazio',
                      texto: 'Cadastre os materiais do canteiro para receber '
                          'alertas quando estiverem acabando.',
                    )
                  else ...[
                    if (emAlerta.isNotEmpty) ...[
                      Semantics(
                        container: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SeloStatus(StatusSelo.aviso,
                                texto: emAlerta.length == 1
                                    ? '1 acabando'
                                    : '${emAlerta.length} acabando'),
                            const SizedBox(width: Espaco.e12),
                            Expanded(
                              child: Text(
                                emAlerta.map((i) => i.material).join(', '),
                                style:
                                    Tipografia.apoio.copyWith(color: c.grafite),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Espaco.e16),
                    ],
                    for (final (i, item) in itens.indexed) ...[
                      if (i > 0) const SizedBox(height: Espaco.e12),
                      _CartaoEstoque(
                        item: item,
                        previsao: PrevisaoEstoqueService.calcular(
                          item: item,
                          movimentos: movSnap.data ?? const [],
                          diario: diarioSnap.data ?? const [],
                        ),
                        onTap: () => _abrirFormulario(context, item: item),
                        onAjuste: (delta) => _ajustar(item, delta),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: BarraDeAcao(
        principal: BotaoPrincipal(
          rotulo: 'Adicionar material',
          icone: Icons.add,
          grande: true,
          expandir: true,
          aoTocar: () => _abrirFormulario(context),
        ),
      ),
    );
  }

  void _abrirFormulario(BuildContext context, {EstoqueItemModel? item}) {
    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormEstoque(obraId: obraId, item: item),
    ));
  }
}

class _CartaoEstoque extends StatelessWidget {
  final EstoqueItemModel item;
  final PrevisaoEstoque? previsao;
  final VoidCallback onTap;
  final void Function(double delta) onAjuste;

  const _CartaoEstoque({
    required this.item,
    this.previsao,
    required this.onTap,
    required this.onAjuste,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final baixo = item.estoqueBaixo;
    final p = previsao;
    final quantidade =
        '${Formatters.quantidade(item.quantidade)} ${item.unidade}';
    return Folha(
      destaque: baixo,
      preenchimento: const EdgeInsets.fromLTRB(
          Espaco.e12, Espaco.e12, Espaco.e8, Espaco.e12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: AreaPressionavel(
              aoTocar: onTap,
              escala: 1,
              rotuloSemantico: '${item.material}: $quantidade'
                  '${baixo ? ', abaixo do mínimo' : ''}',
              dicaSemantica: 'Editar o material',
              construtor: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.material,
                      style: Tipografia.corpoForte.copyWith(color: c.grafite)),
                  const SizedBox(height: Espaco.e4),
                  Text(
                    quantidade,
                    style: Tipografia.subtitulo.copyWith(
                        color: c.grafite, fontFeatures: Tipografia.tabular),
                  ),
                  if (baixo) ...[
                    const SizedBox(height: Espaco.e4),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: c.revisao),
                        const SizedBox(width: Espaco.e4),
                        Flexible(
                          child: Text(
                            'Abaixo do mínimo '
                            '(${Formatters.quantidade(item.quantidadeMinima)})',
                            style: Tipografia.apoio.copyWith(
                                color: c.revisao, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (p != null) ...[
                    const SizedBox(height: Espaco.e4),
                    Text(
                      'No ritmo atual acaba em ~${p.diasRestantes} '
                      'dia${p.diasRestantes == 1 ? '' : 's'} '
                      '(${Formatters.dataCurta(p.dataTermino)})'
                      '${p.consideraEquipe ? ' · ajustado pela equipe' : ''}',
                      style: Tipografia.apoio.copyWith(
                        color: p.critico
                            ? c.revisao
                            : p.atencao
                                ? c.marcaTexto
                                : c.grafite2,
                        fontWeight:
                            p.critico || p.atencao ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: Espaco.e8),
          BotaoIcone(
            icone: Icons.remove,
            rotulo: 'Tirar 1 ${item.unidade} de ${item.material}',
            tamanho: Alvo.minimo + 8,
            aoTocar: item.quantidade <= 0 ? null : () => onAjuste(-1),
          ),
          const SizedBox(width: Espaco.e8),
          BotaoIcone(
            icone: Icons.add,
            rotulo: 'Pôr 1 ${item.unidade} de ${item.material}',
            tamanho: Alvo.minimo + 8,
            aoTocar: () => onAjuste(1),
          ),
        ],
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

  /// Controller interno do campo visível do Autocomplete — necessário para
  /// refletir o material reconhecido pela câmera na tela.
  TextEditingController? _campoMaterialVisivel;

  @override
  void dispose() {
    _materialCtrl.dispose();
    _qtdCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  /// IA de visão: fotografa o material e sugere o nome.
  Future<void> _identificarPelaCamera() async {
    final XFile? xfile;
    try {
      xfile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1600,
      );
    } catch (e) {
      debugPrint('Estoque: falha ao abrir a câmera: $e');
      // Esta tela só tem a câmera: sem ela, a saída é digitar o material.
      if (mounted) {
        setState(() =>
            _resultadoVisao = MensagensErro.daCamera(e, temGaleria: false));
      }
      return;
    }
    if (xfile == null || !mounted) return;
    final caminho = xfile.path;

    setState(() {
      _reconhecendo = true;
      _resultadoVisao = null;
    });
    final visao = MaterialVisionService();
    try {
      final detectados = await visao.reconhecer(caminho);
      if (!mounted) return;
      setState(() {
        if (detectados.isEmpty) {
          _resultadoVisao =
              'Não reconheci um material de construção nesta foto. '
              'Fotografe de perto, com o nome da embalagem aparecendo.';
        } else {
          final melhor = detectados.first;
          _materialCtrl.text = melhor.material;
          _campoMaterialVisivel?.text = melhor.material;
          _resultadoVisao = 'Reconhecido: ${melhor.material} '
              '(${(melhor.confianca * 100).toStringAsFixed(0)}% de confiança'
              '${detectados.length > 1 ? '; alternativas: ${detectados.skip(1).map((d) => d.material).join(', ')}' : ''})';
        }
      });
    } catch (e) {
      // Sem este catch a falha do reconhecimento escapava da tela e o
      // campo ficava como estava, sem explicação nenhuma.
      debugPrint('Estoque: falha ao reconhecer o material: $e');
      if (mounted) {
        setState(() =>
            _resultadoVisao = MensagensErro.daAnalise(e, oQue: 'o material'));
      }
    } finally {
      visao.dispose();
      if (mounted) setState(() => _reconhecendo = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(Tato.erro());
      return;
    }
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
    unawaited(Tato.confirmar());
    if (mounted) Navigator.pop(context);
  }

  /// Exclui na hora, com desfazer (grava o mesmo material de volta).
  Future<void> _excluir() async {
    final db = context.read<FirestoreService>();
    final item = widget.item!;
    await db.excluirEstoqueItem(widget.obraId, item.id);
    unawaited(Tato.confirmar());
    if (!mounted) return;
    mostrarAviso(context, '${item.material} saiu do estoque.',
        aoDesfazer: () => unawaited(db.salvarEstoqueItem(item)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cores;
    final numeros = Tipografia.corpo
        .copyWith(color: c.grafite, fontFeatures: Tipografia.tabular);
    return Padding(
      padding: EdgeInsets.only(
        left: Espaco.margem,
        right: Espaco.margem,
        top: Espaco.e8,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            Espaco.e16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Rotulo('Estoque'),
              const SizedBox(height: Espaco.e4),
              Text(
                widget.item == null ? 'Novo material' : 'Editar material',
                style: Tipografia.titulo.copyWith(color: c.grafite),
              ),
              const SizedBox(height: Espaco.e16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Autocomplete<String>(
                      initialValue: TextEditingValue(text: _materialCtrl.text),
                      optionsBuilder: (v) => v.text.isEmpty
                          ? const Iterable<String>.empty()
                          : AppConstants.materiaisComuns.where((m) =>
                              m.toLowerCase().contains(v.text.toLowerCase())),
                      onSelected: (v) => _materialCtrl.text = v,
                      fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                        _campoMaterialVisivel = ctrl;
                        return TextFormField(
                          controller: ctrl,
                          focusNode: focus,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (v) => _materialCtrl.text = v,
                          decoration:
                              const InputDecoration(labelText: 'Material'),
                          validator: (v) =>
                              Validators.obrigatorio(v, 'O material'),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: Espaco.e8),
                  BotaoIcone(
                    icone: Icons.photo_camera_outlined,
                    rotulo: 'Identificar pela câmera (IA)',
                    carregando: _reconhecendo,
                    aoTocar: _reconhecendo ? null : _identificarPelaCamera,
                  ),
                ],
              ),
              if (_resultadoVisao != null) ...[
                const SizedBox(height: Espaco.e12),
                AvisoIa(mensagem: _resultadoVisao!),
              ],
              const SizedBox(height: Espaco.e16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtdCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: numeros,
                      decoration:
                          const InputDecoration(labelText: 'Quantidade'),
                      validator: Validators.numero,
                    ),
                  ),
                  const SizedBox(width: Espaco.e12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidade,
                      isExpanded: true,
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
              const SizedBox(height: Espaco.e16),
              TextFormField(
                controller: _minCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: numeros,
                decoration: const InputDecoration(
                  labelText: 'Quantidade mínima (alerta)',
                  helperText: 'Avisa quando o estoque ficar igual ou abaixo',
                ),
                validator: Validators.numero,
              ),
              const SizedBox(height: Espaco.e24),
              BotaoPrincipal(
                rotulo: 'Salvar',
                icone: Icons.check,
                grande: true,
                expandir: true,
                aoTocar: () => unawaited(_salvar()),
              ),
              if (widget.item != null) ...[
                const SizedBox(height: Espaco.e8),
                TextButton.icon(
                  onPressed: () => unawaited(_excluir()),
                  style: TextButton.styleFrom(foregroundColor: c.revisao),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir material'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
