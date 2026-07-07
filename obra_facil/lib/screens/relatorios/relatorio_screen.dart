import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/relatorio_semanal_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/carregando_obra.dart';

/// Relatório semanal gerado no aparelho, cruzando lançamentos, diário,
/// cronograma e estoque da obra.
class RelatorioScreen extends StatefulWidget {
  final String obraId;

  const RelatorioScreen({super.key, required this.obraId});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  RelatorioSemanal? _relatorio;
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
      final estoque = await db.estoque(widget.obraId).first;
      final movimentos = await db.movimentos(widget.obraId).first;

      final relatorio = RelatorioSemanalService.gerar(
        obra: obra,
        lancamentos: lancamentos,
        diario: diario,
        cronograma: cronograma,
        estoque: estoque,
        movimentos: movimentos,
      );
      if (mounted) setState(() => _relatorio = relatorio);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    }
  }

  IconData _icone(TipoSecao tipo) => switch (tipo) {
        TipoSecao.visaoGeral => Icons.apartment,
        TipoSecao.financeiro => Icons.payments,
        TipoSecao.pendencias => Icons.hourglass_top,
        TipoSecao.estoque => Icons.inventory_2,
        TipoSecao.canteiro => Icons.engineering,
        TipoSecao.previsao => Icons.query_stats,
      };

  @override
  Widget build(BuildContext context) {
    final r = _relatorio;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório semanal'),
        actions: [
          IconButton(
            tooltip: 'Gerar novamente',
            icon: const Icon(Icons.refresh),
            onPressed: _gerar,
          ),
          if (r != null)
            IconButton(
              tooltip: 'Compartilhar',
              icon: const Icon(Icons.share),
              onPressed: () => Share.share(r.textoCompartilhavel),
            ),
        ],
      ),
      body: _erro != null
          ? Center(child: Text('Erro ao gerar relatório: $_erro'))
          : r == null
              ? const CarregandoObra(mensagem: 'Cruzando os dados da obra…')
              : ListView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16,
                      MediaQuery.of(context).padding.bottom + 16),
                  children: [
                    Text(
                      r.nomeObra,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ).aparecerSecao(0),
                    const SizedBox(height: 2),
                    Text(
                      'Análise gerada no aparelho em '
                      '${Formatters.data(r.geradoEm)}, cruzando lançamentos, '
                      'diário, cronograma e estoque.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textoSecundario),
                    ).aparecerSecao(0),
                    const SizedBox(height: 16),
                    for (final (i, secao) in r.secoes.indexed) ...[
                      _CartaoSecao(
                        icone: _icone(secao.tipo),
                        titulo: secao.titulo,
                        paragrafos: secao.paragrafos,
                      ).aparecerSecao(i + 1),
                      const SizedBox(height: 12),
                    ],
                    _CartaoAcoes(acoes: r.acoes)
                        .aparecerSecao(r.secoes.length + 1),
                  ],
                ),
    );
  }
}

class _CartaoSecao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final List<String> paragrafos;

  const _CartaoSecao({
    required this.icone,
    required this.titulo,
    required this.paragrafos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            children: [
              Icon(icone, size: 18, color: AppColors.laranja),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (i, p) in paragrafos.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(
              p,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartaoAcoes extends StatelessWidget {
  final List<String> acoes;

  const _CartaoAcoes({required this.acoes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.laranja.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.laranja.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: AppColors.laranja),
              const SizedBox(width: 8),
              Text(
                'O que fazer agora',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final acao in acoes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.arrow_right,
                        size: 18, color: AppColors.laranja),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      acao,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
