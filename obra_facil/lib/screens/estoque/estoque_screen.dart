// lib/screens/estoque/estoque_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../constants/app_theme.dart';

class EstoqueScreen extends StatelessWidget {
  final String obraId;
  const EstoqueScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return StreamBuilder<List<EstoqueModel>>(
      stream: provider.firebaseService.streamEstoque(obraId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final itens = snapshot.data ?? [];
        final baixos = itens.where((e) => e.estaBaixo).toList();

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (baixos.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: AppTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${baixos.length} material(is) com estoque baixo: ${baixos.map((e) => e.material).join(', ')}',
                          style: TextStyle(color: AppTheme.warning, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (itens.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.border),
                      const SizedBox(height: 16),
                      const Text('Nenhum material no estoque'),
                    ],
                  ),
                )
              else
                ...itens.map((e) => _EstoqueCard(item: e, obraId: obraId)),
              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _mostrarFormEstoque(context, obraId),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _mostrarFormEstoque(BuildContext context, String obraId) {
    final matCtrl = TextEditingController();
    final qtdCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    String unidade = 'un';

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
            Text('Adicionar material',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: matCtrl,
              decoration: const InputDecoration(labelText: 'Material'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: qtdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Mínimo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final item = EstoqueModel(
                  id: const Uuid().v4(),
                  obraId: obraId,
                  material: matCtrl.text.trim(),
                  quantidade: double.tryParse(qtdCtrl.text) ?? 0,
                  unidade: unidade,
                  quantidadeMinima: double.tryParse(minCtrl.text) ?? 0,
                  atualizadoEm: DateTime.now(),
                );
                await context.read<AppProvider>().firebaseService.atualizarEstoque(item);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstoqueCard extends StatelessWidget {
  final EstoqueModel item;
  final String obraId;
  const _EstoqueCard({required this.item, required this.obraId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.estaBaixo
                ? AppTheme.warning.withOpacity(0.1)
                : AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            color: item.estaBaixo ? AppTheme.warning : AppTheme.primary,
            size: 20,
          ),
        ),
        title: Text(item.material,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('Mínimo: ${item.quantidadeMinima} ${item.unidade}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${item.quantidade} ${item.unidade}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: item.estaBaixo ? AppTheme.warning : AppTheme.textPrimary,
              ),
            ),
            if (item.estaBaixo)
              Text('Baixo!',
                  style: TextStyle(fontSize: 10, color: AppTheme.warning)),
          ],
        ),
      ),
    );
  }
}
