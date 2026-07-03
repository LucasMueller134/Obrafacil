import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/ocr_nota_service.dart';
import '../../services/ia/voz_service.dart';
import '../../services/imagem_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';

class NovoLancamentoScreen extends StatefulWidget {
  final String obraId;

  const NovoLancamentoScreen({super.key, required this.obraId});

  @override
  State<NovoLancamentoScreen> createState() => _NovoLancamentoScreenState();
}

class _NovoLancamentoScreenState extends State<NovoLancamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _fornecedorCtrl = TextEditingController();

  CategoriaCusto _categoria = CategoriaCusto.material;
  DateTime _data = DateTime.now();
  OrigemLancamento _origem = OrigemLancamento.manual;
  File? _fotoNota;
  String? _cnpjExtraido;
  String? _avisoIa;
  bool _processando = false;
  bool _salvando = false;

  final _ocr = OcrNotaService();
  final _voz = VozService();

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    _fornecedorCtrl.dispose();
    _ocr.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ OCR

  Future<void> _lerNotaFiscal() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tirar foto da nota'),
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
    if (origem == null) return;

    final xfile = await ImagePicker().pickImage(
      source: origem,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (xfile == null || !mounted) return;

    setState(() {
      _processando = true;
      _avisoIa = null;
    });

    try {
      final nota = await _ocr.lerNota(xfile.path);
      if (!mounted) return;
      setState(() {
        _fotoNota = File(xfile.path);
        _origem = OrigemLancamento.ocr;
        _categoria = CategoriaCusto.material;
        if (nota.valorTotal != null) {
          _valorCtrl.text =
              nota.valorTotal!.toStringAsFixed(2).replaceAll('.', ',');
        }
        if (nota.data != null) _data = nota.data!;
        if (nota.fornecedorNome != null) {
          _fornecedorCtrl.text = nota.fornecedorNome!;
          if (_descricaoCtrl.text.isEmpty) {
            _descricaoCtrl.text = 'Compra em ${nota.fornecedorNome}';
          }
        }
        _cnpjExtraido = nota.cnpj;
        _avisoIa = nota.encontrouAlgo
            ? 'Dados extraídos da nota pelo OCR — confira antes de salvar.'
            : 'Não consegui ler os dados desta nota (a foto ficou anexada). '
                'Notas impressas funcionam melhor que manuscritas — tente '
                'fotografar de frente, com boa luz e sem sombra.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _avisoIa = 'Erro ao ler a nota: $e');
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  // ------------------------------------------------------------------ Voz

  Future<void> _lancarPorVoz() async {
    final ok = await _voz.inicializar();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reconhecimento de voz indisponível. '
              'Verifique a permissão do microfone.')));
      return;
    }

    var transcricao = '';
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          if (!_voz.ouvindo) {
            _voz.ouvir((texto, finalizou) {
              transcricao = texto;
              setSheet(() {});
              if (finalizou) Navigator.pop(ctx);
            });
          }
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewPadding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic, size: 48, color: AppColors.laranja),
                const SizedBox(height: 12),
                Text('Fale o lançamento com calma',
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Pode pausar entre as palavras — só encerro depois de '
                  '6 segundos de silêncio ou quando você tocar em Concluir.\n'
                  'Ex.: "Comprei 10 sacos de cimento por 350 reais '
                  'no Depósito São José"',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 16),
                Text(
                  transcricao.isEmpty ? 'Ouvindo…' : transcricao,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.amareloCapacete),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _voz.parar();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Concluir'),
                ),
              ],
            ),
          );
        },
      ),
    );
    await _voz.parar();
    if (!mounted || transcricao.trim().isEmpty) return;

    final interpretado = VozService.interpretar(transcricao);
    setState(() {
      _origem = OrigemLancamento.voz;
      _descricaoCtrl.text = interpretado.descricao;
      if (interpretado.valor != null) {
        _valorCtrl.text =
            interpretado.valor!.toStringAsFixed(2).replaceAll('.', ',');
      }
      _categoria = interpretado.categoria;
      if (interpretado.fornecedorNome != null) {
        _fornecedorCtrl.text = interpretado.fornecedorNome!;
      }
      _avisoIa = interpretado.valor == null
          ? 'Entendi a descrição, mas não o valor — preencha o campo.'
          : 'Lançamento interpretado da sua fala — confira antes de salvar.';
    });
  }

  // ---------------------------------------------------------------- Salvar

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final db = context.read<FirestoreService>();
    final usuario = context.read<AuthProvider>().usuario!;

    try {
      final obra = await db.obra(widget.obraId).first;
      if (obra == null) throw Exception('Obra não encontrada');

      String? fornecedorId;
      String? fornecedorNome;
      if (_fornecedorCtrl.text.trim().isNotEmpty) {
        final fornecedor = await db.obterOuCriarFornecedor(
          donoId: obra.donoId,
          nome: _fornecedorCtrl.text,
          cnpj: _cnpjExtraido,
        );
        fornecedorId = fornecedor.id;
        fornecedorNome = fornecedor.nome;
      }

      String? fotoDataUri;
      if (_fotoNota != null) {
        fotoDataUri = await ImagemService.comprimirParaDataUri(_fotoNota!);
      }

      await db.criarLancamento(LancamentoModel(
        id: '',
        obraId: widget.obraId,
        descricao: _descricaoCtrl.text.trim(),
        valor: Formatters.parseValor(_valorCtrl.text)!,
        categoria: _categoria,
        // Lançamento do dono não precisa passar por aprovação.
        status: usuario.ehDono
            ? StatusLancamento.aprovado
            : StatusLancamento.pendente,
        origem: _origem,
        fornecedorId: fornecedorId,
        fornecedorNome: fornecedorNome,
        fotoNotaUrl: fotoDataUri,
        data: _data,
        criadoPorId: usuario.id,
        criadoPorNome: usuario.nome,
        aprovadoPorId: usuario.ehDono ? usuario.id : null,
        criadoEm: DateTime.now(),
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(usuario.ehDono
            ? 'Lançamento registrado.'
            : 'Lançamento enviado para aprovação do dono.'),
      ));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
    }
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo lançamento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BotaoIa(
                        icone: Icons.document_scanner,
                        rotulo: 'Foto da nota',
                        descricao: 'OCR preenche sozinho',
                        onTap: _processando ? null : _lerNotaFiscal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BotaoIa(
                        icone: Icons.mic,
                        rotulo: 'Por voz',
                        descricao: 'Fale o gasto',
                        onTap: _processando ? null : _lancarPorVoz,
                      ),
                    ),
                  ],
                ),
                if (_processando) ...[
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      SizedBox(width: 10),
                      Text('Lendo a nota fiscal…'),
                    ],
                  ),
                ],
                if (_avisoIa != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amareloCapacete.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.amareloCapacete.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 18, color: AppColors.amareloCapacete),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_avisoIa!,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descricaoCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex.: 10 sacos de cimento CP-II',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  validator: (v) => Validators.obrigatorio(v, 'A descrição'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: Validators.valor,
                ),
                const SizedBox(height: 16),
                Text('Categoria',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in CategoriaCusto.values)
                      ChoiceChip(
                        avatar: Icon(c.icone,
                            size: 16,
                            color: _categoria == c
                                ? AppColors.laranja
                                : AppColors.textoSecundario),
                        label: Text(c.label),
                        selected: _categoria == c,
                        onSelected: (_) => setState(() => _categoria = c),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final escolhida = await showDatePicker(
                      context: context,
                      initialDate: _data,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      locale: const Locale('pt', 'BR'),
                    );
                    if (escolhida != null) setState(() => _data = escolhida);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do gasto',
                      prefixIcon: Icon(Icons.calendar_today, size: 20),
                    ),
                    child: Text(Formatters.data(_data)),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fornecedorCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Fornecedor (opcional)',
                    hintText: 'Cadastrado automaticamente se for novo',
                    prefixIcon: Icon(Icons.storefront),
                  ),
                ),
                if (_fotoNota != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Image.file(_fotoNota!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                                backgroundColor: Colors.black54),
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _fotoNota = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Salvar lançamento'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotaoIa extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final String descricao;
  final VoidCallback? onTap;

  const _BotaoIa({
    required this.icone,
    required this.rotulo,
    required this.descricao,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.laranja.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.laranja.withValues(alpha: 0.45)),
        ),
        child: Column(
          children: [
            Icon(icone, color: AppColors.laranja, size: 26),
            const SizedBox(height: 8),
            Text(rotulo,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              descricao,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}
