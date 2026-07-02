// lib/screens/obras/nova_obra_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../models/obra_model.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';

class NovaObraScreen extends StatefulWidget {
  final ObraModel? obraParaEditar;
  const NovaObraScreen({super.key, this.obraParaEditar});

  @override
  State<NovaObraScreen> createState() => _NovaObraScreenState();
}

class _NovaObraScreenState extends State<NovaObraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _orcamentoCtrl = TextEditingController();
  String _status = AppConstants.statusEmAndamento;
  String _fase = AppConstants.fasesObra.first;
  DateTime _dataInicio = DateTime.now();
  DateTime? _dataPrevisaoFim;
  bool _carregando = false;

  bool get _editando => widget.obraParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      final o = widget.obraParaEditar!;
      _nomeCtrl.text = o.nome;
      _enderecoCtrl.text = o.endereco;
      _orcamentoCtrl.text = o.orcamentoTotal.toString();
      _status = o.status;
      _fase = o.faseAtual;
      _dataInicio = o.dataInicio;
      _dataPrevisaoFim = o.dataPrevisaoFim;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _enderecoCtrl.dispose();
    _orcamentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);

    try {
      final provider = context.read<AppProvider>();
      final usuario = provider.usuario!;
      final agora = DateTime.now();

      final obra = ObraModel(
        id: _editando ? widget.obraParaEditar!.id : const Uuid().v4(),
        nome: _nomeCtrl.text.trim(),
        endereco: _enderecoCtrl.text.trim(),
        status: _status,
        faseAtual: _fase,
        orcamentoTotal: double.tryParse(
                _orcamentoCtrl.text.replaceAll(',', '.')) ??
            0,
        custoAtual: _editando ? widget.obraParaEditar!.custoAtual : 0,
        mestreId: usuario.id,
        donoId: usuario.isDono ? usuario.id : '',
        dataInicio: _dataInicio,
        dataPrevisaoFim: _dataPrevisaoFim,
        criadoEm: _editando ? widget.obraParaEditar!.criadoEm : agora,
        atualizadoEm: agora,
      );

      if (_editando) {
        await provider.firebaseService.atualizarObra(obra);
      } else {
        await provider.firebaseService.criarObra(obra);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editando ? 'Obra atualizada!' : 'Obra criada!'),
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
      appBar: AppBar(
        title: Text(_editando ? 'Editar Obra' : 'Nova Obra'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome da obra *',
                  hintText: 'Ex: Geminado Rua Lucas nº 12',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o nome da obra' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _enderecoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Endereço completo *',
                  hintText: 'Rua, número, bairro, cidade',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Informe o endereço' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _orcamentoCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Orçamento total (R\$)',
                  hintText: '0,00',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _fase,
                decoration: const InputDecoration(
                  labelText: 'Fase atual',
                  prefixIcon: Icon(Icons.layers_outlined),
                ),
                items: AppConstants.fasesObra
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _fase = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: [
                  AppConstants.statusEmAndamento,
                  AppConstants.statusPausada,
                  AppConstants.statusConcluida,
                ]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 16),
              // Data início
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Data de início'),
                subtitle: Text(
                  '${_dataInicio.day.toString().padLeft(2, '0')}/${_dataInicio.month.toString().padLeft(2, '0')}/${_dataInicio.year}',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dataInicio,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _dataInicio = d);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Previsão de término'),
                subtitle: Text(
                  _dataPrevisaoFim != null
                      ? '${_dataPrevisaoFim!.day.toString().padLeft(2, '0')}/${_dataPrevisaoFim!.month.toString().padLeft(2, '0')}/${_dataPrevisaoFim!.year}'
                      : 'Não definida',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _dataPrevisaoFim ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _dataPrevisaoFim = d);
                },
              ),
              const SizedBox(height: 32),
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
                      : Text(_editando ? 'Salvar alterações' : 'Criar obra'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
