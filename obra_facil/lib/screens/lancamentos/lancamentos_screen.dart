import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/estado_vazio.dart';
import '../../widgets/imagem_obra.dart';

class LancamentosScreen extends StatefulWidget {
  final String obraId;

  const LancamentosScreen({super.key, required this.obraId});

  @override
  State<LancamentosScreen> createState() => _LancamentosScreenState();
}

class _LancamentosScreenState extends State<LancamentosScreen> {
  StatusLancamento? _filtro;

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtro == null,
                  onSelected: (_) => setState(() => _filtro = null),
                ),
                const SizedBox(width: 8),
                for (final status in StatusLancamento.values) ...[
                  ChoiceChip(
                    label: Text(status.label),
                    selected: _filtro == status,
                    onSelected: (_) => setState(() => _filtro = status),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LancamentoModel>>(
              stream: db.lancamentos(widget.obraId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var itens = snapshot.data ?? const <LancamentoModel>[];
                if (_filtro != null) {
                  itens = itens.where((l) => l.status == _filtro).toList();
                }
                if (itens.isEmpty) {
                  return EstadoVazio(
                    icone: Icons.receipt_long,
                    titulo: 'Nenhum lançamento',
                    mensagem: _filtro == null
                        ? 'Registre o primeiro gasto da obra — digitando, '
                            'por foto da nota ou por voz.'
                        : 'Nenhum lançamento ${_filtro!.label.toLowerCase()}.',
                    rotuloAcao: _filtro == null ? 'Lançar gasto' : null,
                    onAcao: _filtro == null
                        ? () => context
                            .push('/obras/${widget.obraId}/lancamentos/novo')
                        : null,
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 16, 16,
                      MediaQuery.of(context).padding.bottom + 96),
                  itemCount: itens.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CartaoLancamento(
                    lancamento: itens[i],
                    onTap: () => _abrirDetalhes(context, itens[i], auth),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/obras/${widget.obraId}/lancamentos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
    );
  }

  void _abrirDetalhes(
      BuildContext context, LancamentoModel l, AuthProvider auth) {
    final db = context.read<FirestoreService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).viewPadding.bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(l.categoria.icone, color: l.categoria.cor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.descricao,
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              Formatters.moeda(l.valor),
              style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                    color: AppColors.laranja,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _LinhaInfo('Categoria', l.categoria.label),
            _LinhaInfo('Data', Formatters.data(l.data)),
            _LinhaInfo('Origem', l.origem.label),
            _LinhaInfo('Registrado por', l.criadoPorNome),
            if (l.fornecedorNome != null)
              _LinhaInfo('Fornecedor', l.fornecedorNome!),
            _LinhaInfo('Status', l.status.label),
            if (l.motivoRejeicao != null)
              _LinhaInfo('Motivo da rejeição', l.motivoRejeicao!),
            if (l.fotoNotaUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: ImagemObra(l.fotoNotaUrl!),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (auth.ehDono && l.status == StatusLancamento.pendente)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.erro,
                        side: const BorderSide(color: AppColors.erro),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _rejeitar(context, l, db, auth.usuario!.id);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Rejeitar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sucesso),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await db.moderarLancamento(
                          lancamento: l,
                          aprovar: true,
                          donoId: auth.usuario!.id,
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Aprovar'),
                    ),
                  ),
                ],
              )
            else if (!auth.ehDono &&
                l.status == StatusLancamento.pendente &&
                l.criadoPorId == auth.usuario!.id)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.erro,
                  side: const BorderSide(color: AppColors.erro),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await db.excluirLancamento(l.obraId, l.id);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir lançamento'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejeitar(BuildContext context, LancamentoModel l,
      FirestoreService db, String donoId) async {
    final ctrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeitar lançamento'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Ex.: valor não confere com a nota',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.erro),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );
    if (motivo == null) return;
    await db.moderarLancamento(
      lancamento: l,
      aprovar: false,
      donoId: donoId,
      motivoRejeicao: motivo.trim().isEmpty ? null : motivo.trim(),
    );
  }
}

class _CartaoLancamento extends StatelessWidget {
  final LancamentoModel lancamento;
  final VoidCallback onTap;

  const _CartaoLancamento({required this.lancamento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = lancamento;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: l.categoria.cor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(l.categoria.icone,
                    color: l.categoria.cor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.descricao,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          Formatters.dataCurta(l.data),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textoSecundario),
                        ),
                        if (l.origem != OrigemLancamento.manual) ...[
                          const SizedBox(width: 6),
                          Icon(
                            l.origem == OrigemLancamento.ocr
                                ? Icons.document_scanner
                                : Icons.mic,
                            size: 13,
                            color: AppColors.amareloCapacete,
                          ),
                        ],
                        if (l.fornecedorNome != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l.fornecedorNome!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.textoSecundario),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.moeda(l.valor),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: l.status.cor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: l.status.cor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinhaInfo extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _LinhaInfo(this.rotulo, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              rotulo,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textoSecundario),
            ),
          ),
          Expanded(
            child: Text(valor, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
