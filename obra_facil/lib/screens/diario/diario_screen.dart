// lib/screens/diario/diario_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';

class DiarioScreen extends StatelessWidget {
  final String obraId;
  const DiarioScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return StreamBuilder<List<DiarioModel>>(
      stream: provider.firebaseService.streamDiario(obraId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final registros = snapshot.data ?? [];

        return Scaffold(
          body: registros.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined, size: 64, color: AppTheme.border),
                      const SizedBox(height: 16),
                      const Text('Nenhum registro no diário'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: registros.length,
                  itemBuilder: (context, i) => _DiarioCard(registro: registros[i]),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _mostrarFormDiario(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _mostrarFormDiario(BuildContext context) {
    final descCtrl = TextEditingController();
    final pessoasCtrl = TextEditingController();
    String fase = AppConstants.fasesObra.first;
    String clima = 'Bom';
    final usuario = context.read<AppProvider>().usuario!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Registro do dia',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'O que foi feito hoje?',
                  hintText: 'Ex: Concretagem da laje, colocação de tijolos...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: fase,
                      decoration: const InputDecoration(labelText: 'Fase'),
                      items: AppConstants.fasesObra
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (v) => setState(() => fase = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: clima,
                      decoration: const InputDecoration(labelText: 'Clima'),
                      items: ['Bom', 'Nublado', 'Chuva', 'Muito Quente']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => clima = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: pessoasCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Nº de pessoas trabalhando'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final diario = DiarioModel(
                    id: const Uuid().v4(),
                    obraId: obraId,
                    descricao: descCtrl.text.trim(),
                    fase: fase,
                    numeroPessoas: int.tryParse(pessoasCtrl.text) ?? 0,
                    clima: clima,
                    registradoPorNome: usuario.nome,
                    data: DateTime.now(),
                    criadoEm: DateTime.now(),
                  );
                  await context.read<AppProvider>().firebaseService.criarDiario(diario);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Salvar registro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiarioCard extends StatelessWidget {
  final DiarioModel registro;
  const _DiarioCard({required this.registro});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy', 'pt_BR');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(fmt.format(registro.data),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Row(
                  children: [
                    Icon(_iconeClima(registro.clima),
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(registro.clima,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(registro.descricao),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(texto: registro.fase, icone: Icons.layers_outlined),
                const SizedBox(width: 8),
                _InfoChip(
                  texto: '${registro.numeroPessoas} pessoas',
                  icone: Icons.people_outlined,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Registrado por ${registro.registradoPorNome}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  IconData _iconeClima(String clima) {
    switch (clima) {
      case 'Chuva': return Icons.umbrella_outlined;
      case 'Nublado': return Icons.cloud_outlined;
      case 'Muito Quente': return Icons.wb_sunny_outlined;
      default: return Icons.wb_sunny_outlined;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String texto;
  final IconData icone;
  const _InfoChip({required this.texto, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
