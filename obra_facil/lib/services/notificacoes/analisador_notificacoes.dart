import '../../models/models.dart';
import '../../utils/formatters.dart';
import '../ia/previsao_estoque_service.dart';

/// Uma notificação que merece ser mostrada.
class NotificacaoPendente {
  final String titulo;
  final String corpo;
  final String canal; // 'aprovacoes' | 'alertas'

  /// Chave de deduplicação: a mesma chave nunca notifica duas vezes.
  final String chave;

  const NotificacaoPendente({
    required this.titulo,
    required this.corpo,
    required this.canal,
    required this.chave,
  });

  int get id => chave.hashCode & 0x7fffffff;
}

/// Regras puras do verificador em segundo plano: recebe os dados das obras
/// e decide o que vale uma notificação. Sem plugin, sem rede — 100% testável.
abstract class AnalisadorNotificacoes {
  static List<NotificacaoPendente> analisar({
    required UsuarioModel usuario,
    required List<ObraModel> obras,
    required Map<String, List<LancamentoModel>> lancamentosPorObra,
    required Map<String, List<EstoqueItemModel>> estoquePorObra,
    required Map<String, List<MovimentoEstoqueModel>> movimentosPorObra,
    required Map<String, List<DiarioEntradaModel>> diarioPorObra,
    required Map<String, List<CronogramaFaseModel>> cronogramaPorObra,
    required DateTime ultimaChecagem,
    required Set<String> chavesJaNotificadas,
    DateTime? agora,
  }) {
    final ref = agora ?? DateTime.now();
    final hoje = '${ref.year}-${ref.month}-${ref.day}';
    final saida = <NotificacaoPendente>[];

    void adicionar(NotificacaoPendente n) {
      if (chavesJaNotificadas.contains(n.chave)) return;
      if (saida.any((s) => s.chave == n.chave)) return;
      saida.add(n);
    }

    for (final obra in obras) {
      final lancamentos = lancamentosPorObra[obra.id] ?? const [];
      final souDono = obra.donoId == usuario.id;

      // ----- Dono: lançamentos novos aguardando aprovação
      if (souDono) {
        final novosPendentes = lancamentos
            .where((l) =>
                l.status == StatusLancamento.pendente &&
                l.criadoEm.isAfter(ultimaChecagem))
            .toList();
        if (novosPendentes.length > 3) {
          final total =
              novosPendentes.fold<double>(0, (s, l) => s + l.valor);
          adicionar(NotificacaoPendente(
            titulo: '🔔 ${novosPendentes.length} lançamentos para aprovar',
            corpo: '${obra.nome}: ${Formatters.moeda(total)} aguardando '
                'sua aprovação. Deslize para moderar.',
            canal: 'aprovacoes',
            chave: 'pend_lote_${obra.id}_${novosPendentes.length}_$hoje',
          ));
        } else {
          for (final l in novosPendentes) {
            adicionar(NotificacaoPendente(
              titulo: '🔔 Novo lançamento para aprovar',
              corpo: '${l.criadoPorNome} lançou "${l.descricao}" '
                  '(${Formatters.moeda(l.valor)}) na ${obra.nome}.',
              canal: 'aprovacoes',
              chave: 'pend_${l.id}',
            ));
          }
        }
      }

      // ----- Mestre: meus lançamentos moderados
      for (final l in lancamentos) {
        if (l.criadoPorId != usuario.id) continue;
        if (l.moderadoEm == null ||
            !l.moderadoEm!.isAfter(ultimaChecagem)) {
          continue;
        }
        if (l.status == StatusLancamento.aprovado) {
          adicionar(NotificacaoPendente(
            titulo: '✅ Lançamento aprovado!',
            corpo: '"${l.descricao}" (${Formatters.moeda(l.valor)}) foi '
                'aprovado na ${obra.nome}'
                '${l.itens.isNotEmpty ? ' — materiais já entraram no estoque' : ''}.',
            canal: 'aprovacoes',
            chave: 'aprov_${l.id}',
          ));
        } else if (l.status == StatusLancamento.rejeitado) {
          adicionar(NotificacaoPendente(
            titulo: '❌ Lançamento rejeitado',
            corpo: '"${l.descricao}" foi rejeitado na ${obra.nome}'
                '${l.motivoRejeicao != null ? ': ${l.motivoRejeicao}' : ''}.',
            canal: 'aprovacoes',
            chave: 'rejei_${l.id}',
          ));
        }
      }

      // ----- Estoque: abaixo do mínimo e término próximo (1x/dia)
      final estoque = estoquePorObra[obra.id] ?? const [];
      final movimentos = movimentosPorObra[obra.id] ?? const [];
      final diario = diarioPorObra[obra.id] ?? const [];
      for (final item in estoque) {
        if (item.estoqueBaixo) {
          adicionar(NotificacaoPendente(
            titulo: '📦 ${item.material} no fim',
            corpo: '${obra.nome}: restam '
                '${Formatters.quantidade(item.quantidade)} ${item.unidade} '
                '(mínimo: ${Formatters.quantidade(item.quantidadeMinima)}). '
                'Hora de repor.',
            canal: 'alertas',
            chave: 'estq_${obra.id}_${item.material}_$hoje',
          ));
          continue;
        }
        final previsao = PrevisaoEstoqueService.calcular(
          item: item,
          movimentos: movimentos,
          diario: diario,
          referencia: ref,
        );
        if (previsao != null && previsao.diasRestantes <= 5) {
          adicionar(NotificacaoPendente(
            titulo: '⏳ ${item.material} acaba em '
                '~${previsao.diasRestantes} dia'
                '${previsao.diasRestantes == 1 ? '' : 's'}',
            corpo: '${obra.nome}: no ritmo atual, termina em '
                '${Formatters.data(previsao.dataTermino)}. '
                'Programe a compra.',
            canal: 'alertas',
            chave: 'term_${obra.id}_${item.material}_$hoje',
          ));
        }
      }

      // ----- Dono: orçamento passando de 90% (1x/dia por faixa)
      if (souDono && obra.orcamento > 0) {
        final gasto = lancamentos
            .where((l) => l.status == StatusLancamento.aprovado)
            .fold<double>(0, (s, l) => s + l.valor);
        final pct = (gasto / obra.orcamento * 100).round();
        if (pct >= 100) {
          adicionar(NotificacaoPendente(
            titulo: '💰 Orçamento estourado!',
            corpo: '${obra.nome} já consumiu $pct% do orçamento '
                '(${Formatters.moeda(gasto)} de '
                '${Formatters.moeda(obra.orcamento)}).',
            canal: 'alertas',
            chave: 'orc_${obra.id}_100_$hoje',
          ));
        } else if (pct >= 90) {
          adicionar(NotificacaoPendente(
            titulo: '💰 Orçamento em $pct%',
            corpo: '${obra.nome}: restam '
                '${Formatters.moeda(obra.orcamento - gasto)}. '
                'Vale segurar os gastos não essenciais.',
            canal: 'alertas',
            chave: 'orc_${obra.id}_90_$hoje',
          ));
        }
      }

      // ----- Dono: fase do cronograma atrasada (1x/dia)
      if (souDono) {
        final atrasadas = (cronogramaPorObra[obra.id] ?? const [])
            .where((f) => f.atrasada)
            .toList();
        if (atrasadas.isNotEmpty) {
          adicionar(NotificacaoPendente(
            titulo: '🚧 Fase atrasada na ${obra.nome}',
            corpo: '${atrasadas.map((f) => f.nome).join(', ')} '
                '${atrasadas.length > 1 ? 'passaram' : 'passou'} do prazo. '
                'Atualize o cronograma ou replaneje.',
            canal: 'alertas',
            chave:
                'fase_${obra.id}_${atrasadas.map((f) => f.id).join('_')}_$hoje',
          ));
        }
      }
    }
    return saida;
  }
}
