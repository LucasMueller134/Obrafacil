import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/relatorio_semanal_service.dart';

/// Relatório semanal gerado no aparelho a partir dos dados da obra.
class RelatorioScreen extends StatefulWidget {
  final String obraId;

  const RelatorioScreen({super.key, required this.obraId});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  String? _relatorio;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _gerar();
  }

  Future<void> _gerar() async {
    setState(() {
      _relatorio = null;
      _erro = null;
    });
    try {
      final db = context.read<FirestoreService>();
      final obra = await db.obra(widget.obraId).first;
      if (obra == null) throw Exception('Obra não encontrada');
      final lancamentos = await db.lancamentos(widget.obraId).first;
      final diario = await db.diario(widget.obraId).first;
      final cronograma = await db.cronograma(widget.obraId).first;

      final texto = RelatorioSemanalService.gerar(
        obra: obra,
        lancamentos: lancamentos,
        diario: diario,
        cronograma: cronograma,
      );
      if (mounted) setState(() => _relatorio = texto);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório semanal'),
        actions: [
          IconButton(
            tooltip: 'Gerar novamente',
            icon: const Icon(Icons.refresh),
            onPressed: _gerar,
          ),
          if (_relatorio != null)
            IconButton(
              tooltip: 'Compartilhar',
              icon: const Icon(Icons.share),
              onPressed: () => Share.share(_relatorio!),
            ),
        ],
      ),
      body: _erro != null
          ? Center(child: Text('Erro ao gerar relatório: $_erro'))
          : _relatorio == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Analisando os dados da obra…'),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16,
                      MediaQuery.of(context).padding.bottom + 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            AppColors.amareloCapacete.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.amareloCapacete
                                .withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 18, color: AppColors.amareloCapacete),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Gerado automaticamente no seu aparelho, a partir '
                              'dos lançamentos, diário e cronograma da obra.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.superficie,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borda),
                      ),
                      child: SelectableText(
                        _relatorio!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
    );
  }
}
