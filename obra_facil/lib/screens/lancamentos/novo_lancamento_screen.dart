// lib/screens/lancamentos/novo_lancamento_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/app_provider.dart';
import '../../models/lancamento_model.dart';
import '../../services/ia_service.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';

class NovoLancamentoScreen extends StatefulWidget {
  final String obraId;
  const NovoLancamentoScreen({super.key, required this.obraId});

  @override
  State<NovoLancamentoScreen> createState() => _NovoLancamentoScreenState();
}

class _NovoLancamentoScreenState extends State<NovoLancamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _qtdCtrl = TextEditingController();
  final _vlrUnitCtrl = TextEditingController();
  final _vlrTotalCtrl = TextEditingController();
  final _fornecedorCtrl = TextEditingController();
  String _categoria = AppConstants.categorias.first;
  String _unidade = 'un';
  String _statusPag = AppConstants.pagamentoAPagar;
  String _fase = AppConstants.fasesObra.first;
  DateTime _data = DateTime.now();
  File? _notaFiscal;
  bool _carregando = false;
  bool _processandoIA = false;
  bool _gravando = false;
  final _recorder = AudioRecorder();
  String? _audioPath;

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _qtdCtrl.dispose();
    _vlrUnitCtrl.dispose();
    _vlrTotalCtrl.dispose();
    _fornecedorCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _calcularTotal() {
    final qtd = double.tryParse(_qtdCtrl.text.replaceAll(',', '.')) ?? 0;
    final vlr = double.tryParse(_vlrUnitCtrl.text.replaceAll(',', '.')) ?? 0;
    _vlrTotalCtrl.text = (qtd * vlr).toStringAsFixed(2);
  }

  Future<void> _tirarFotoNota() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xFile == null) return;

    final file = File(xFile.path);
    setState(() {
      _notaFiscal = file;
      _processandoIA = true;
    });

    try {
      final provider = context.read<AppProvider>();
      final dados = await provider.iaService.extrairDadosNotaFiscal(file);
      setState(() {
        if (dados.descricao != null) _descricaoCtrl.text = dados.descricao!;
        if (dados.fornecedor != null) _fornecedorCtrl.text = dados.fornecedor!;
        if (dados.quantidade != null)
          _qtdCtrl.text = dados.quantidade!.toString();
        if (dados.valorUnitario != null)
          _vlrUnitCtrl.text = dados.valorUnitario!.toStringAsFixed(2);
        if (dados.valorTotal != null)
          _vlrTotalCtrl.text = dados.valorTotal!.toStringAsFixed(2);
        if (dados.categoria != null &&
            AppConstants.categorias.contains(dados.categoria))
          _categoria = dados.categoria!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dados extraídos da nota fiscal!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível extrair os dados: $e'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
    } finally {
      setState(() => _processandoIA = false);
    }
  }

  Future<void> _iniciarGravacao() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getTemporaryDirectory();
    _audioPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      RecordConfig(encoder: AudioEncoder.aacLc),
      path: _audioPath!,
    );
    setState(() => _gravando = true);
  }

  Future<void> _pararGravacaoEProcessar() async {
    await _recorder.stop();
    setState(() {
      _gravando = false;
      _processandoIA = true;
    });

    try {
      final provider = context.read<AppProvider>();
      final dados = await provider.iaService.processarAudio(File(_audioPath!));
      setState(() {
        if (dados.descricao != null) _descricaoCtrl.text = dados.descricao!;
        if (dados.fornecedor != null) _fornecedorCtrl.text = dados.fornecedor!;
        if (dados.quantidade != null)
          _qtdCtrl.text = dados.quantidade!.toString();
        if (dados.valorUnitario != null)
          _vlrUnitCtrl.text = dados.valorUnitario!.toStringAsFixed(2);
        if (dados.valorTotal != null)
          _vlrTotalCtrl.text = dados.valorTotal!.toStringAsFixed(2);
        if (dados.categoria != null &&
            AppConstants.categorias.contains(dados.categoria))
          _categoria = dados.categoria!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎤 "${dados.transcricao}" — dados preenchidos!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar áudio: $e'),
              backgroundColor: AppTheme.warning),
        );
      }
    } finally {
      setState(() => _processandoIA = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    try {
      final provider = context.read<AppProvider>();
      final usuario = provider.usuario!;
      final agora = DateTime.now();
      final id = const Uuid().v4();

      String? notaUrl;
      if (_notaFiscal != null) {
        notaUrl = await provider.firebaseService
            .uploadNotaFiscal(_notaFiscal!, widget.obraId, 'nota_$id.jpg');
      }

      final lancamento = LancamentoModel(
        id: id,
        obraId: widget.obraId,
        categoria: _categoria,
        descricao: _descricaoCtrl.text.trim(),
        quantidade: double.tryParse(_qtdCtrl.text.replaceAll(',', '.')) ?? 1,
        unidade: _unidade,
        valorUnitario:
            double.tryParse(_vlrUnitCtrl.text.replaceAll(',', '.')) ?? 0,
        valorTotal:
            double.tryParse(_vlrTotalCtrl.text.replaceAll(',', '.')) ?? 0,
        fornecedorId: '',
        fornecedorNome: _fornecedorCtrl.text.trim(),
        statusPagamento: _statusPag,
        fase: _fase,
        notaFiscalUrl: notaUrl,
        lancadoPorId: usuario.id,
        lancadoPorNome: usuario.nome,
        data: _data,
        criadoEm: agora,
        sincronizado: true,
      );

      await provider.firebaseService.criarLancamento(lancamento);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lançamento salvo!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Lançamento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Botões de IA
            if (_processandoIA)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Processando com IA...'),
                    SizedBox(height: 16),
                  ],
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _tirarFotoNota,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Foto da Nota'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _gravando
                        ? ElevatedButton.icon(
                            onPressed: _pararGravacaoEProcessar,
                            icon: const Icon(Icons.stop),
                            label: const Text('Parar'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.error),
                          )
                        : OutlinedButton.icon(
                            onPressed: _iniciarGravacao,
                            icon: const Icon(Icons.mic_outlined),
                            label: const Text('Gravar Áudio'),
                          ),
                  ),
                ],
              ),
              if (_notaFiscal != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                    const SizedBox(width: 4),
                    Text('Nota fiscal anexada',
                        style: TextStyle(color: AppTheme.success, fontSize: 12)),
                  ],
                ),
              ],
              if (_gravando) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.fiber_manual_record,
                        color: AppTheme.error, size: 16),
                    const SizedBox(width: 4),
                    const Text('Gravando... toque em Parar quando terminar',
                        style: TextStyle(color: AppTheme.error, fontSize: 12)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            // Formulário
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _categoria,
                    decoration: const InputDecoration(labelText: 'Categoria *'),
                    items: AppConstants.categorias
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _categoria = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descricaoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descrição *',
                      hintText: 'Ex: Sacos de cimento CP-II',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Informe a descrição' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fornecedorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fornecedor',
                      hintText: 'Ex: Casa do Construtor',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _qtdCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Quantidade'),
                          onChanged: (_) => _calcularTotal(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _unidade,
                          decoration: const InputDecoration(labelText: 'Un.'),
                          items: ['un', 'kg', 'sc', 'm', 'm²', 'm³', 'L', 'cx']
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setState(() => _unidade = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _vlrUnitCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Valor unit. (R\$)'),
                          onChanged: (_) => _calcularTotal(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _vlrTotalCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Total (R\$)'),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Informe o valor' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _fase,
                    decoration: const InputDecoration(labelText: 'Fase da obra'),
                    items: AppConstants.fasesObra
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) => setState(() => _fase = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _statusPag,
                    decoration:
                        const InputDecoration(labelText: 'Status do pagamento'),
                    items: [
                      AppConstants.pagamentoPago,
                      AppConstants.pagamentoAPagar,
                      AppConstants.pagamentoParcelado,
                    ]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _statusPag = v!),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Data da compra'),
                    subtitle: Text(
                      '${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}',
                    ),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _data,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _data = d);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _salvar,
                      child: _carregando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Salvar Lançamento'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
