import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/models.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/estado_vazio.dart';

class CronogramaScreen extends StatelessWidget {
  final String obraId;

  const CronogramaScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cronograma')),
      body: StreamBuilder<List<CronogramaFaseModel>>(
        stream: db.cronograma(obraId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final fases = snapshot.data ?? const <CronogramaFaseModel>[];
          if (fases.isEmpty) {
            return EstadoVazio(
              icone: Icons.timeline,
              titulo: 'Sem cronograma',
              mensagem: 'Adicione as fases da obra para acompanhar o '
                  'percentual de conclusão de cada etapa.',
              rotuloAcao: 'Adicionar fase',
              onAcao: () => _abrirFormulario(context, ordem: 0),
            );
          }
          final progressoGeral = fases.fold<int>(
                  0, (s, f) => s + f.percentualConcluido) /
              fases.length;
          return ListView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.superficie,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borda),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progresso geral',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(
                          '${progressoGeral.toStringAsFixed(0)}%',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  color: AppColors.laranja,
                                  fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressoGeral / 100,
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final (i, fase) in fases.indexed) ...[
                _CartaoFase(
                  fase: fase,
                  onPercentual: (v) =>
                      db.salvarFase(fase.copyWith(percentualConcluido: v)),
                  onExcluir: () => db.excluirFase(obraId, fase.id),
                ).aparecer(i),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final fases = await db.cronograma(obraId).first;
          if (context.mounted) {
            _abrirFormulario(context, ordem: fases.length);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Fase'),
      ),
    );
  }

  void _abrirFormulario(BuildContext context, {required int ordem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FormFase(obraId: obraId, ordem: ordem),
    );
  }
}

class _CartaoFase extends StatelessWidget {
  final CronogramaFaseModel fase;
  final void Function(int) onPercentual;
  final VoidCallback onExcluir;

  const _CartaoFase({
    required this.fase,
    required this.onPercentual,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final cor = fase.concluida
        ? AppColors.sucesso
        : fase.atrasada
            ? AppColors.erro
            : fase.emAndamento
                ? AppColors.laranja
                : AppColors.textoSecundario;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  fase.concluida
                      ? Icons.check_circle
                      : fase.atrasada
                          ? Icons.error
                          : Icons.radio_button_unchecked,
                  size: 18,
                  color: cor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fase.nome,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (fase.atrasada)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.erro.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Atrasada',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.erro,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                PopupMenuButton<String>(
                  iconSize: 18,
                  onSelected: (_) => _confirmarExclusao(context),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir fase'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${Formatters.data(fase.dataInicio)} → ${Formatters.data(fase.dataFim)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: fase.percentualConcluido.toDouble(),
                    max: 100,
                    divisions: 20,
                    label: '${fase.percentualConcluido}%',
                    onChanged: (_) {},
                    onChangeEnd: (v) => onPercentual(v.round()),
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${fase.percentualConcluido}%',
                    textAlign: TextAlign.end,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700, color: cor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir a fase "${fase.nome}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: AppColors.erro))),
        ],
      ),
    );
    if (ok == true) onExcluir();
  }
}

class _FormFase extends StatefulWidget {
  final String obraId;
  final int ordem;

  const _FormFase({required this.obraId, required this.ordem});

  @override
  State<_FormFase> createState() => _FormFaseState();
}

class _FormFaseState extends State<_FormFase> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  DateTime _inicio = DateTime.now();
  DateTime _fim = DateTime.now().add(const Duration(days: 14));

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _escolherData(bool inicio) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fim,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida == null) return;
    setState(() {
      if (inicio) {
        _inicio = escolhida;
        if (!_fim.isAfter(_inicio)) {
          _fim = _inicio.add(const Duration(days: 7));
        }
      } else {
        _fim = escolhida;
      }
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final db = context.read<FirestoreService>();
    await db.salvarFase(CronogramaFaseModel(
      id: '',
      obraId: widget.obraId,
      nome: _nomeCtrl.text.trim(),
      ordem: widget.ordem,
      dataInicio: _inicio,
      dataFim: _fim,
    ));
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nova fase', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome da fase',
                hintText: 'Ex.: Estrutura do 2º andar',
              ),
              validator: (v) => Validators.obrigatorio(v, 'O nome'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _escolherData(true),
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Início'),
                      child: Text(Formatters.data(_inicio)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _escolherData(false),
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Fim'),
                      child: Text(Formatters.data(_fim)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _salvar, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
