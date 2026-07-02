// lib/screens/cronograma/cronograma_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../constants/app_theme.dart';
import '../../constants/app_constants.dart';

class CronogramaScreen extends StatelessWidget {
  final String obraId;
  const CronogramaScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return StreamBuilder<List<CronogramaModel>>(
      stream: provider.firebaseService.streamCronograma(obraId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final fases = snapshot.data ?? [];

        return Scaffold(
          body: fases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 64, color: AppTheme.border),
                      const SizedBox(height: 16),
                      const Text('Nenhuma fase no cronograma'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: fases.length,
                  itemBuilder: (context, i) => _FaseCard(fase: fases[i]),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _mostrarFormFase(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _mostrarFormFase(BuildContext context) {
    String faseSel = AppConstants.fasesObra.first;
    DateTime inicio = DateTime.now();
    DateTime fim = DateTime.now().add(const Duration(days: 30));

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
              Text('Adicionar fase', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: faseSel,
                decoration: const InputDecoration(labelText: 'Fase'),
                items: AppConstants.fasesObra
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => faseSel = v!),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Início'),
                subtitle: Text(
                  '${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')}/${inicio.year}',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: inicio,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => inicio = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Término previsto'),
                subtitle: Text(
                  '${fim.day.toString().padLeft(2, '0')}/${fim.month.toString().padLeft(2, '0')}/${fim.year}',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: fim,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => fim = d);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final cron = CronogramaModel(
                    id: const Uuid().v4(),
                    obraId: obraId,
                    fase: faseSel,
                    dataInicio: inicio,
                    dataFim: fim,
                    percentualConcluido: 0,
                  );
                  await context
                      .read<AppProvider>()
                      .firebaseService
                      .salvarCronograma(cron);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaseCard extends StatelessWidget {
  final CronogramaModel fase;
  const _FaseCard({required this.fase});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy');

    Color cor;
    if (fase.percentualConcluido == 100) {
      cor = AppTheme.success;
    } else if (fase.atrasado) {
      cor = AppTheme.error;
    } else {
      cor = AppTheme.primary;
    }

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
                Text(fase.fase,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (fase.atrasado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Atrasado',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.error,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${fmt.format(fase.dataInicio)} → ${fmt.format(fase.dataFim)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fase.percentualConcluido / 100,
                      backgroundColor: AppTheme.border,
                      valueColor: AlwaysStoppedAnimation(cor),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${fase.percentualConcluido}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: cor, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
