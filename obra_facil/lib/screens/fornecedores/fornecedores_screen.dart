import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/validators.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/estado_vazio.dart';

class FornecedoresScreen extends StatelessWidget {
  const FornecedoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final usuario = context.watch<AuthProvider>().usuario;
    if (usuario == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Fornecedores')),
      body: StreamBuilder<List<FornecedorModel>>(
        stream: db.fornecedores(usuario.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fornecedores = snapshot.data ?? const <FornecedorModel>[];
          if (fornecedores.isEmpty) {
            return EstadoVazio(
              icone: Icons.storefront,
              titulo: 'Nenhum fornecedor',
              mensagem:
                  'Fornecedores são cadastrados automaticamente quando '
                  'aparecem em notas fiscais e lançamentos — ou adicione '
                  'manualmente.',
              rotuloAcao: 'Adicionar fornecedor',
              onAcao: () => _abrirFormulario(context, usuario.id),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
            itemCount: fornecedores.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final f = fornecedores[i];
              return Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.laranja.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront,
                        color: AppColors.laranja, size: 22),
                  ),
                  title: Text(f.nome,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      if (f.telefone != null && f.telefone!.isNotEmpty)
                        f.telefone!,
                      if (f.cnpj != null && f.cnpj!.isNotEmpty)
                        'CNPJ ${f.cnpj}',
                    ].join(' · '),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textoSecundario),
                  ),
                  onTap: () =>
                      _abrirFormulario(context, usuario.id, fornecedor: f),
                ),
              ).aparecer(i);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, usuario.id),
        icon: const Icon(Icons.add),
        label: const Text('Fornecedor'),
      ),
    );
  }

  void _abrirFormulario(BuildContext context, String donoId,
      {FornecedorModel? fornecedor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormFornecedor(donoId: donoId, fornecedor: fornecedor),
    );
  }
}

class _FormFornecedor extends StatefulWidget {
  final String donoId;
  final FornecedorModel? fornecedor;

  const _FormFornecedor({required this.donoId, this.fornecedor});

  @override
  State<_FormFornecedor> createState() => _FormFornecedorState();
}

class _FormFornecedorState extends State<_FormFornecedor> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeCtrl =
      TextEditingController(text: widget.fornecedor?.nome ?? '');
  late final _telefoneCtrl =
      TextEditingController(text: widget.fornecedor?.telefone ?? '');
  late final _emailCtrl =
      TextEditingController(text: widget.fornecedor?.email ?? '');
  late final _cnpjCtrl =
      TextEditingController(text: widget.fornecedor?.cnpj ?? '');
  late final _obsCtrl =
      TextEditingController(text: widget.fornecedor?.observacoes ?? '');

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _cnpjCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final db = context.read<FirestoreService>();
    await db.salvarFornecedor(FornecedorModel(
      id: widget.fornecedor?.id ?? '',
      donoId: widget.donoId,
      nome: _nomeCtrl.text.trim(),
      telefone:
          _telefoneCtrl.text.trim().isEmpty ? null : _telefoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      cnpj: _cnpjCtrl.text.trim().isEmpty ? null : _cnpjCtrl.text.trim(),
      observacoes: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      criadoEm: widget.fornecedor?.criadoEm ?? DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _excluir() async {
    final db = context.read<FirestoreService>();
    await db.excluirFornecedor(widget.fornecedor!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.fornecedor == null
                    ? 'Novo fornecedor'
                    : 'Editar fornecedor',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => Validators.obrigatorio(v, 'O nome'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _telefoneCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Telefone (opcional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'E-mail (opcional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cnpjCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'CNPJ (opcional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _obsCtrl,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Observações (opcional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _salvar, child: const Text('Salvar')),
              if (widget.fornecedor != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _excluir,
                  child: const Text('Excluir fornecedor',
                      style: TextStyle(color: AppColors.erro)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
