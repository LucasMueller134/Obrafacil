import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/previsao_orcamento_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/animacoes.dart';
import '../../widgets/barra_orcamento.dart';
import '../../widgets/carregando_obra.dart';
import '../../widgets/ilustracoes.dart';
import '../../widgets/cartao_resumo.dart';
import '../../widgets/grafico_categorias.dart';
import '../../widgets/grafico_semanal.dart';

/// Dashboard da obra: financeiro, previsão de IA, gráficos e módulos.
class ObraDetalheScreen extends StatelessWidget {
  final String obraId;

  const ObraDetalheScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final auth = context.watch<AuthProvider>();

    return StreamBuilder<ObraModel?>(
      stream: db.obra(obraId),
      builder: (context, obraSnap) {
        final obra = obraSnap.data;
        if (obra == null) {
          return const Scaffold(
            body: CarregandoObra(mensagem: 'Abrindo a obra…'),
          );
        }
        return StreamBuilder<List<LancamentoModel>>(
          stream: db.lancamentos(obraId),
          builder: (context, lancSnap) {
            final lancamentos = lancSnap.data ?? const <LancamentoModel>[];
            return _Dashboard(
              obra: obra,
              lancamentos: lancamentos,
              ehDono: auth.ehDono,
            );
          },
        );
      },
    );
  }
}

class _Dashboard extends StatelessWidget {
  final ObraModel obra;
  final List<LancamentoModel> lancamentos;
  final bool ehDono;

  const _Dashboard({
    required this.obra,
    required this.lancamentos,
    required this.ehDono,
  });

  @override
  Widget build(BuildContext context) {
    final aprovados = lancamentos
        .where((l) => l.status == StatusLancamento.aprovado)
        .toList();
    final pendentes = lancamentos
        .where((l) => l.status == StatusLancamento.pendente)
        .toList();
    final gastoAprovado =
        aprovados.fold<double>(0, (s, l) => s + l.valor);
    final valorPendente =
        pendentes.fold<double>(0, (s, l) => s + l.valor);
    final previsao = PrevisaoOrcamentoService.calcular(
      obra: obra,
      lancamentos: lancamentos,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(obra.nome, overflow: TextOverflow.ellipsis),
        actions: [
          if (ehDono)
            PopupMenuButton<String>(
              onSelected: (acao) => _executarAcao(context, acao),
              itemBuilder: (_) => [
                if (obra.status != StatusObra.concluida)
                  const PopupMenuItem(
                    value: 'concluir',
                    child: Text('Marcar como concluída'),
                  ),
                if (obra.status == StatusObra.emAndamento)
                  const PopupMenuItem(
                    value: 'pausar',
                    child: Text('Pausar obra'),
                  ),
                if (obra.status != StatusObra.emAndamento)
                  const PopupMenuItem(
                    value: 'retomar',
                    child: Text('Retomar obra'),
                  ),
                const PopupMenuItem(
                  value: 'excluir',
                  child: Text('Excluir obra',
                      style: TextStyle(color: AppColors.erro)),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 96),
        children: [
          _CabecalhoObra(obra: obra, ehDono: ehDono).aparecerSecao(0),
          const SizedBox(height: 16),

          // Financeiro
          _Secao(
            titulo: 'Financeiro',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BarraOrcamento(gasto: gastoAprovado, orcamento: obra.orcamento),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CartaoResumo(
                        rotulo: 'Aprovados',
                        valor: '${aprovados.length}',
                        icone: Icons.check_circle_outline,
                        cor: AppColors.sucesso,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CartaoResumo(
                        rotulo: 'Pendentes',
                        valor: pendentes.isEmpty
                            ? '0'
                            : '${pendentes.length} · ${Formatters.moedaCompacta(valorPendente)}',
                        icone: Icons.hourglass_top,
                        cor: AppColors.alerta,
                      ),
                    ),
                  ],
                ),
                if (ehDono && pendentes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/obras/${obra.id}/lancamentos'),
                    icon: const Icon(Icons.rule),
                    label: Text(
                        'Revisar ${pendentes.length} lançamento${pendentes.length > 1 ? 's' : ''} pendente${pendentes.length > 1 ? 's' : ''}'),
                  ),
                ],
              ],
            ),
          ).aparecerSecao(1),
          const SizedBox(height: 16),

          // Previsão IA
          _CartaoPrevisao(previsao: previsao).aparecerSecao(2),
          const SizedBox(height: 16),

          _Secao(
            titulo: 'Gastos por categoria',
            child: GraficoCategorias(lancamentos: lancamentos),
          ).aparecerSecao(3),
          const SizedBox(height: 16),
          _Secao(
            titulo: 'Gastos por semana',
            child: GraficoSemanal(lancamentos: lancamentos),
          ).aparecerSecao(4),
          const SizedBox(height: 16),

          // Módulos
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: [
              _Modulo(
                icone: Icons.receipt_long,
                rotulo: 'Lançamentos',
                cor: AppColors.laranja,
                onTap: () => context.push('/obras/${obra.id}/lancamentos'),
              ),
              _Modulo(
                icone: Icons.inventory_2,
                rotulo: 'Estoque',
                cor: AppColors.info,
                onTap: () => context.push('/obras/${obra.id}/estoque'),
              ),
              _Modulo(
                icone: Icons.menu_book,
                rotulo: 'Diário',
                cor: AppColors.amareloCapacete,
                onTap: () => context.push('/obras/${obra.id}/diario'),
              ),
              _Modulo(
                icone: Icons.timeline,
                rotulo: 'Cronograma',
                cor: AppColors.catEquipamento,
                onTap: () => context.push('/obras/${obra.id}/cronograma'),
              ),
              _Modulo(
                icone: Icons.photo_library,
                rotulo: 'Galeria',
                cor: AppColors.sucesso,
                onTap: () => context.push('/obras/${obra.id}/galeria'),
              ),
              _Modulo(
                icone: Icons.auto_awesome,
                rotulo: 'Relatório IA',
                cor: const Color(0xFF2DD4BF),
                onTap: () => context.push('/obras/${obra.id}/relatorio'),
              ),
            ],
          ).aparecerSecao(5),
          const SizedBox(height: 24),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/obras/${obra.id}/lancamentos/novo'),
        icon: const Icon(Icons.add),
        label: const Text('Lançar gasto'),
      ),
    );
  }

  Future<void> _executarAcao(BuildContext context, String acao) async {
    final db = context.read<FirestoreService>();
    switch (acao) {
      case 'concluir':
        await db.atualizarObra(obra.copyWith(status: StatusObra.concluida));
      case 'pausar':
        await db.atualizarObra(obra.copyWith(status: StatusObra.pausada));
      case 'retomar':
        await db.atualizarObra(obra.copyWith(status: StatusObra.emAndamento));
      case 'excluir':
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir obra?'),
            content: const Text(
                'Todos os lançamentos, fotos e registros desta obra serão '
                'perdidos. Essa ação não pode ser desfeita.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir',
                    style: TextStyle(color: AppColors.erro)),
              ),
            ],
          ),
        );
        if (confirmar == true && context.mounted) {
          await db.excluirObra(obra.id);
          if (context.mounted) context.go('/obras');
        }
    }
  }
}

class _CabecalhoObra extends StatelessWidget {
  final ObraModel obra;
  final bool ehDono;

  const _CabecalhoObra({required this.obra, required this.ehDono});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.laranjaEscuro, AppColors.laranja],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.laranja.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -12,
            bottom: -4,
            width: 170,
            height: 80,
            child: IgnorePointer(
              child: Opacity(opacity: 0.20, child: IlustracaoSkyline()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    obra.status.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.place, size: 15, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        obra.endereco +
                            (obra.cliente != null
                                ? ' · ${obra.cliente}'
                                : ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (ehDono) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: obra.codigoConvite));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Código copiado! Envie para o mestre de obras.')));
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(
                            'Equipe: ${obra.codigoConvite}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(Icons.copy,
                              size: 13, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoPrevisao extends StatelessWidget {
  final PrevisaoOrcamento previsao;

  const _CartaoPrevisao({required this.previsao});

  @override
  Widget build(BuildContext context) {
    final cor = switch (previsao.risco) {
      NivelRisco.ok => AppColors.sucesso,
      NivelRisco.atencao => AppColors.alerta,
      NivelRisco.alto => AppColors.erro,
    };
    final icone = switch (previsao.risco) {
      NivelRisco.ok => Icons.verified,
      NivelRisco.atencao => Icons.warning_amber,
      NivelRisco.alto => Icons.report,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: cor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Previsão de orçamento (IA): ${previsao.risco.label}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: cor, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (previsao.dadosSuficientes) ...[
            Text(
              'Projeção para o fim da obra: '
              '${Formatters.moeda(previsao.gastoProjetadoFinal)}'
              '${previsao.dataEstouroPrevista != null ? ' · estouro estimado em ${Formatters.data(previsao.dataEstouroPrevista!)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
          ],
          Text(
            previsao.recomendacao,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textoSecundario),
          ),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final Widget child;

  const _Secao({required this.titulo, required this.child});

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
          Text(
            titulo,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Modulo extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final Color cor;
  final VoidCallback onTap;

  const _Modulo({
    required this.icone,
    required this.rotulo,
    required this.cor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borda),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icone, color: cor, size: 22),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                rotulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
