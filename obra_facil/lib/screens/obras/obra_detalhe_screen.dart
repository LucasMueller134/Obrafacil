import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../design/design.dart';
import '../../design/maquete/maquete.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/ia/previsao_orcamento_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/barra_orcamento.dart';
import '../../widgets/cartao_resumo.dart';
import '../../widgets/grafico_categorias.dart';
import '../../widgets/grafico_semanal.dart';

part 'obra_detalhe_secoes.dart';

/// Central da obra, na linguagem da prancheta: o carimbo e a maquete no
/// topo e, embaixo, o que cada perfil precisa. O dono vê primeiro os gastos
/// para aprovar, o orçamento contra o avanço, os gráficos, os módulos e os
/// convites; o mestre tem "lançar gasto" e "diário de hoje" no rodapé e vê
/// os lançamentos dele que esperam aprovação.
class ObraDetalheScreen extends StatelessWidget {
  final String obraId;

  const ObraDetalheScreen({super.key, required this.obraId});

  @override
  Widget build(BuildContext context) {
    final db = context.read<FirestoreService>();
    final auth = context.watch<AuthProvider>();

    return TemaPrancheta(
      child: StreamBuilder<ObraModel?>(
        stream: db.obra(obraId),
        builder: (context, obraSnap) {
          final obra = obraSnap.data;
          if (obra == null) {
            return const _AbrindoObra();
          }
          return StreamBuilder<List<LancamentoModel>>(
            stream: db.lancamentos(obraId),
            builder: (context, lancSnap) {
              final lancamentos = lancSnap.data ?? const <LancamentoModel>[];
              // Só leitura: o avanço da maquete e o resumo dos módulos.
              return _LeiturasDoAndamento(
                obraId: obraId,
                construtor: (context, cronograma, cronogramaFalhou, diario) =>
                    _Dashboard(
                  obra: obra,
                  lancamentos: lancamentos,
                  cronograma: cronograma,
                  cronogramaFalhou: cronogramaFalhou,
                  diario: diario,
                  ehDono: auth.ehDono,
                  usuarioId: auth.usuario?.id,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// As duas leituras que a central acrescentou (só leitura): o cronograma,
/// para a maquete, a fase e o avanço, e o diário, para o resumo do módulo.
///
/// As streams são abertas uma vez, quando a central monta, e guardadas
/// aqui: o StreamBuilder reassina sempre que recebe uma Stream nova, e
/// pedi-las a cada build fecharia e reabriria os dois listeners do
/// Firestore a cada mudança na obra ou nos lançamentos.
class _LeiturasDoAndamento extends StatefulWidget {
  const _LeiturasDoAndamento({required this.obraId, required this.construtor});

  final String obraId;
  final Widget Function(
    BuildContext context,
    List<CronogramaFaseModel>? cronograma,
    bool cronogramaFalhou,
    List<DiarioEntradaModel>? diario,
  ) construtor;

  @override
  State<_LeiturasDoAndamento> createState() => _LeiturasDoAndamentoState();
}

class _LeiturasDoAndamentoState extends State<_LeiturasDoAndamento> {
  late Stream<List<CronogramaFaseModel>> _cronograma;
  late Stream<List<DiarioEntradaModel>> _diario;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void didUpdateWidget(_LeiturasDoAndamento antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.obraId != widget.obraId) _abrir();
  }

  void _abrir() {
    final db = context.read<FirestoreService>();
    _cronograma = db.cronograma(widget.obraId);
    _diario = db.diario(widget.obraId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CronogramaFaseModel>>(
      stream: _cronograma,
      builder: (context, cronoSnap) => StreamBuilder<List<DiarioEntradaModel>>(
        stream: _diario,
        builder: (context, diarioSnap) => widget.construtor(
          context,
          cronoSnap.data,
          cronoSnap.hasError,
          diarioSnap.data,
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final ObraModel obra;
  final List<LancamentoModel> lancamentos;

  /// Nulo enquanto carrega.
  final List<CronogramaFaseModel>? cronograma;

  /// A leitura do cronograma deu erro (o cronograma não vai chegar).
  final bool cronogramaFalhou;
  final List<DiarioEntradaModel>? diario;
  final bool ehDono;
  final String? usuarioId;

  const _Dashboard({
    required this.obra,
    required this.lancamentos,
    required this.cronograma,
    required this.cronogramaFalhou,
    required this.diario,
    required this.ehDono,
    required this.usuarioId,
  });

  @override
  Widget build(BuildContext context) {
    final aprovados = lancamentos
        .where((l) => l.status == StatusLancamento.aprovado)
        .toList();
    final pendentes = lancamentos
        .where((l) => l.status == StatusLancamento.pendente)
        .toList();
    final gastoAprovado = aprovados.fold<double>(0, (s, l) => s + l.valor);
    final valorPendente = pendentes.fold<double>(0, (s, l) => s + l.valor);
    final previsao = PrevisaoOrcamentoService.calcular(
      obra: obra,
      lancamentos: lancamentos,
    );

    final resumo = _ResumoObra(
      obra: obra,
      cronograma: cronograma,
      cronogramaFalhou: cronogramaFalhou,
      diario: diario,
      aprovados: aprovados.length,
      pendentes: pendentes.length,
    );
    final rotas = _Rotas(obra.id);

    final List<Widget> corpo;
    final Widget barra;
    if (ehDono) {
      corpo = _corpoDono(
        context,
        resumo: resumo,
        rotas: rotas,
        pendentes: pendentes,
        valorPendente: valorPendente,
        gastoAprovado: gastoAprovado,
        previsao: previsao,
      );
      barra = _BarraDono(pendentes: pendentes.length, rotas: rotas);
    } else {
      final meusPendentes = [
        for (final l in pendentes)
          if (usuarioId != null && l.criadoPorId == usuarioId) l,
      ];
      corpo = _corpoMestre(
        context,
        resumo: resumo,
        rotas: rotas,
        meusPendentes: meusPendentes,
        aprovados: aprovados.length,
        pendentes: pendentes.length,
        valorPendente: valorPendente,
        gastoAprovado: gastoAprovado,
        previsao: previsao,
      );
      barra = _BarraMestre(rotas: rotas);
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (ehDono)
            PopupMenuButton<String>(
              tooltip: 'Ações da obra',
              icon: const Icon(Icons.more_vert),
              onSelected: (acao) => _executarAcao(context, acao),
              itemBuilder: (_) => [
                if (obra.status != StatusObra.concluida)
                  const PopupMenuItem(
                    value: 'concluir',
                    child: _ItemMenu(
                      icone: Icons.check_circle_outline,
                      texto: 'Marcar como concluída',
                    ),
                  ),
                if (obra.status == StatusObra.emAndamento)
                  const PopupMenuItem(
                    value: 'pausar',
                    child: _ItemMenu(
                      icone: Icons.pause_circle_outline,
                      texto: 'Pausar obra',
                    ),
                  ),
                if (obra.status != StatusObra.emAndamento)
                  const PopupMenuItem(
                    value: 'retomar',
                    child: _ItemMenu(
                      icone: Icons.play_circle_outline,
                      texto: 'Retomar obra',
                    ),
                  ),
                const PopupMenuItem(
                  value: 'excluir',
                  child: _ItemMenu(
                    icone: Icons.delete_outline,
                    texto: 'Excluir obra',
                    destrutivo: true,
                  ),
                ),
              ],
            ),
          const SizedBox(width: Espaco.e4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: Espaco.e4, bottom: Espaco.e32),
        children: corpo,
      ),
      bottomNavigationBar: barra,
    );
  }

  List<Widget> _corpoDono(
    BuildContext context, {
    required _ResumoObra resumo,
    required _Rotas rotas,
    required List<LancamentoModel> pendentes,
    required double valorPendente,
    required double gastoAprovado,
    required PrevisaoOrcamento previsao,
  }) {
    return [
      _CarimboObra(obra: obra, resumo: resumo),
      const SizedBox(height: Espaco.e12),
      _MaqueteComAvanco(resumo: resumo),
      if (pendentes.isNotEmpty) ...[
        const SizedBox(height: Espaco.e24),
        _NaMargem(
          _FolhaPendentes(
            titulo: '${pendentes.length} '
                '${pendentes.length == 1 ? 'gasto' : 'gastos'} para aprovar',
            pendentes: pendentes,
            total: valorPendente,
            destaque: true,
            aoTocar: () => context.push(rotas.fila),
          ),
        ),
      ],
      const SizedBox(height: Espaco.e24),
      _NaMargem(
        BarraOrcamento(
          gasto: gastoAprovado,
          orcamento: obra.orcamento,
          avancoFisico: resumo.avancoFisico,
        ),
      ),
      const SizedBox(height: Espaco.e24),
      _NaMargem(_LinhaPrevisao(
        previsao: previsao,
        fimPrevisto: obra.previsaoTermino,
      )),
      _Secao(
        titulo: 'Gastos por categoria',
        child: GraficoCategorias(lancamentos: lancamentos),
      ),
      _Secao(
        titulo: 'Gastos por semana',
        child: GraficoSemanal(lancamentos: lancamentos),
      ),
      _Secao(
        titulo: 'Módulos da obra',
        child: _ListaModulos(resumo: resumo, rotas: rotas),
      ),
      _Secao(
        titulo: 'Convites',
        child: _Convites(obra: obra),
      ),
    ];
  }

  List<Widget> _corpoMestre(
    BuildContext context, {
    required _ResumoObra resumo,
    required _Rotas rotas,
    required List<LancamentoModel> meusPendentes,
    required int aprovados,
    required int pendentes,
    required double valorPendente,
    required double gastoAprovado,
    required PrevisaoOrcamento previsao,
  }) {
    final meuTotal = meusPendentes.fold<double>(0, (s, l) => s + l.valor);
    return [
      _CarimboObra(obra: obra, resumo: resumo),
      const SizedBox(height: Espaco.e12),
      _MaqueteComAvanco(resumo: resumo),
      if (meusPendentes.isNotEmpty) ...[
        const SizedBox(height: Espaco.e24),
        _NaMargem(
          _FolhaPendentes(
            rotulo: 'Lançados por você',
            titulo: '${meusPendentes.length} esperando aprovação',
            pendentes: meusPendentes,
            total: meuTotal,
            destaque: false,
            aoTocar: () => context.push(rotas.fila),
          ),
        ),
      ],
      // Direto no papel, como o do dono: dentro de uma folha, as células de
      // aprovados e pendentes viravam caixa dentro de caixa.
      _Secao(
        titulo: 'Orçamento',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarraOrcamento(
              gasto: gastoAprovado,
              orcamento: obra.orcamento,
              avancoFisico: resumo.avancoFisico,
              compacta: true,
            ),
            const SizedBox(height: Espaco.e16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CartaoResumo(
                      rotulo: 'Aprovados',
                      valor: '$aprovados',
                      simbolo: Icon(
                        Icons.check,
                        size: 18,
                        color: context.cores.ok,
                      ),
                    ),
                  ),
                  const SizedBox(width: Espaco.e8),
                  Expanded(
                    child: CartaoResumo(
                      rotulo: 'Pendentes',
                      valor: '$pendentes',
                      apoio: pendentes == 0
                          ? null
                          : Formatters.moeda(valorPendente),
                      simbolo: const CaixaHachurada(
                        largura: 10,
                        altura: 14,
                        espacamento: 3.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Espaco.e16),
            _LinhaPrevisao(
              previsao: previsao,
              fimPrevisto: obra.previsaoTermino,
            ),
          ],
        ),
      ),
      _Secao(
        titulo: 'Módulos da obra',
        child: _ListaModulos(resumo: resumo, rotas: rotas),
      ),
      _Secao(
        titulo: 'Gastos por categoria',
        child: GraficoCategorias(lancamentos: lancamentos),
      ),
      _Secao(
        titulo: 'Gastos por semana',
        child: GraficoSemanal(lancamentos: lancamentos),
      ),
    ];
  }

  Future<void> _executarAcao(BuildContext context, String acao) async {
    final db = context.read<FirestoreService>();
    switch (acao) {
      case 'concluir':
        await db.atualizarObra(obra.copyWith(status: StatusObra.concluida));
        unawaited(Tato.confirmar());
      case 'pausar':
        await db.atualizarObra(obra.copyWith(status: StatusObra.pausada));
        unawaited(Tato.confirmar());
      case 'retomar':
        await db.atualizarObra(obra.copyWith(status: StatusObra.emAndamento));
        unawaited(Tato.confirmar());
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
                style: TextButton.styleFrom(
                  foregroundColor: ctx.cores.revisao,
                ),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
        if (confirmar == true && context.mounted) {
          await db.excluirObra(obra.id);
          unawaited(Tato.confirmar());
          if (context.mounted) context.go('/obras');
        }
    }
  }
}

/// Copia o código da equipe, republicando o convite antes.
///
/// As obras criadas antes da coleção de convites não têm o código
/// publicado lá, e sem isso o mestre não consegue entrar. Republicar no
/// momento em que o dono vai compartilhar conserta essas obras sozinho.
Future<void> _convidarEquipe(BuildContext context, ObraModel obra) async {
  final db = context.read<FirestoreService>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await db.garantirConvites(obra);
  } catch (_) {
    // Sem rede o convite já publicado antes continua valendo.
  }
  await Clipboard.setData(ClipboardData(text: obra.codigoConvite));
  messenger.showSnackBar(const SnackBar(
      content: Text('Código copiado! Envie para o mestre de obras.')));
}

/// Gera (na primeira vez) e copia o código de acompanhamento do cliente.
Future<void> _convidarCliente(BuildContext context, ObraModel obra) async {
  final db = context.read<FirestoreService>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final codigo = await db.codigoDoClienteDaObra(obra);
    await Clipboard.setData(ClipboardData(text: codigo));
    messenger.showSnackBar(SnackBar(
      content: Text('Código do cliente: $codigo (copiado). Ele acompanha o '
          'andamento da obra, sem ver custos.'),
      duration: const Duration(seconds: 5),
    ));
  } catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o código: $e')));
  }
}
