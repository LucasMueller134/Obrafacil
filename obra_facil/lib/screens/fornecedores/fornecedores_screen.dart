// lib/screens/fornecedores/fornecedores_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../constants/app_theme.dart';

class FornecedoresScreen extends StatelessWidget {
  const FornecedoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final usuario = provider.usuario;
    if (usuario == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Fornecedores')),
      body: StreamBuilder<List<FornecedorModel>>(
        stream: provider.firebaseService.streamFornecedores(usuario.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fornecedores = snapshot.data ?? [];
          if (fornecedores.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 64, color: AppTheme.border),
                  const SizedBox(height: 16),
                  const Text('Nenhum fornecedor cadastrado'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: fornecedores.length,
            itemBuilder: (context, i) =>
                _FornecedorCard(fornecedor: fornecedores[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormFornecedor(context, usuario.id),
        icon: const Icon(Icons.add),
        label: const Text('Novo Fornecedor'),
      ),
    );
  }

  void _mostrarFormFornecedor(BuildContext context, String donoId) {
    final nomeCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final obsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Novo fornecedor',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome / Empresa *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: obsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Ex: Entrega rápida, bom preço...',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final f = FornecedorModel(
                  id: const Uuid().v4(),
                  nome: nomeCtrl.text.trim(),
                  telefone: telCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  observacoes: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
                  criadoEm: DateTime.now(),
                );
                await context.read<AppProvider>().firebaseService.criarFornecedor(f);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar fornecedor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FornecedorCard extends StatelessWidget {
  final FornecedorModel fornecedor;
  const _FornecedorCard({required this.fornecedor});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.store_outlined, color: AppTheme.primary),
        ),
        title: Text(fornecedor.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fornecedor.telefone.isNotEmpty) Text(fornecedor.telefone),
            if (fornecedor.observacoes != null)
              Text(fornecedor.observacoes!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        isThreeLine: fornecedor.observacoes != null,
        trailing: fornecedor.totalGasto > 0
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total gasto',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    fmt.format(fornecedor.totalGasto),
                    style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
