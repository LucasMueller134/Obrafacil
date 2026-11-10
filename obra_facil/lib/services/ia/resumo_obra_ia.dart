import 'perguntas_obra_service.dart';
import 'previsao_estoque_service.dart';
import 'previsao_orcamento_service.dart';
import '../../models/models.dart';

/// Resumo da obra que vai para a IA do servidor quando o assistente de
/// regras não entende a pergunta.
///
/// Só entram dados que a pessoa já vê no app. No [modoCliente] o dinheiro
/// não é escondido depois: os campos de valor nem são montados (e o
/// servidor ainda apaga qualquer campo de dinheiro que chegar, como segunda
/// barreira). O avanço da obra é a média das fases, a mesma conta da central.
Map<String, Object?> resumoObraParaIa(DadosObraChat d,
    {required bool modoCliente, DateTime? agora}) {
  final ref = agora ?? DateTime.now();
  final hoje = DateTime(ref.year, ref.month, ref.day);
  final fases = [...d.cronograma]..sort((a, b) => a.ordem.compareTo(b.ordem));

  String situacao(CronogramaFaseModel f) {
    if (f.percentualConcluido >= 100) return 'concluída';
    if (hoje.isAfter(f.dataFim)) return 'atrasada';
    if (!hoje.isBefore(f.dataInicio)) return 'em andamento';
    return 'a começar';
  }

  CronogramaFaseModel? atual;
  for (final f in fases) {
    if (f.percentualConcluido < 100) {
      atual = f;
      break;
    }
  }
  final diario = [...d.diario]..sort((a, b) => b.data.compareTo(a.data));

  final resumo = <String, Object?>{
    'nome': d.obra.nome,
    'status': d.obra.status.label,
    'hoje': _data(hoje),
    'inicio': _data(d.obra.dataInicio),
    'termino_previsto': _data(d.obra.previsaoTermino),
    if (fases.isNotEmpty)
      'avanco_obra_pct':
          (fases.fold<int>(0, (s, f) => s + f.percentualConcluido) / fases.length).round(),
    if (atual != null) 'fase_atual': {'nome': atual.nome, 'pct': atual.percentualConcluido},
    'fases': [
      for (final f in fases.take(15))
        {
          'nome': f.nome,
          'pct': f.percentualConcluido,
          'situacao': situacao(f),
          'inicio': _data(f.dataInicio),
          'fim': _data(f.dataFim),
        },
    ],
    'estoque': [
      for (final e in d.estoque.take(25))
        {
          'material': e.material,
          'quantidade': '${_num(e.quantidade)} ${e.unidade}',
          'minimo': '${_num(e.quantidadeMinima)} ${e.unidade}',
          'abaixo_do_minimo': e.estoqueBaixo,
          if (_previsao(e, d, ref) case final p?) 'acaba_em_dias': p.diasRestantes,
        },
    ],
    'diario_ultimos': [
      for (final x in diario.take(5))
        {
          'data': _data(x.data),
          'clima': x.clima,
          'pessoas': x.numeroPessoas,
          if (x.fase.isNotEmpty) 'fase': x.fase,
          'o_que': x.descricao.length > 200 ? '${x.descricao.substring(0, 200)}…' : x.descricao,
        },
    ],
  };
  if (modoCliente) return resumo;

  final aprovados = d.aprovados;
  final pendentes = d.pendentes;
  double soma(Iterable<LancamentoModel> ls) => ls.fold(0, (s, l) => s + l.valor);
  final porCategoria = <String, double>{};
  for (final l in aprovados) {
    porCategoria[l.categoria.label] = (porCategoria[l.categoria.label] ?? 0) + l.valor;
  }
  final porFornecedor = <String, double>{};
  for (final l in aprovados) {
    final nome = l.fornecedorNome;
    if (nome != null && nome.trim().isNotEmpty) {
      porFornecedor[nome] = (porFornecedor[nome] ?? 0) + l.valor;
    }
  }
  final fornecedores = porFornecedor.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final recentes = [...aprovados]..sort((a, b) => b.data.compareTo(a.data));
  final previsao = PrevisaoOrcamentoService.calcular(obra: d.obra, lancamentos: d.lancamentos);

  resumo.addAll({
    'orcamento': _reais(d.obra.orcamento),
    'gastos_aprovados_total': _reais(soma(aprovados)),
    'gastos_aprovados_mes': _reais(soma(aprovados.where((l) => l.data.year == hoje.year && l.data.month == hoje.month))),
    'gastos_aprovados_7_dias': _reais(soma(aprovados.where((l) => !l.data.isBefore(hoje.subtract(const Duration(days: 6)))))),
    'gastos_por_categoria': {for (final e in porCategoria.entries) e.key: _reais(e.value)},
    'pendentes_de_aprovacao': {'quantidade': pendentes.length, 'total': _reais(soma(pendentes))},
    'maiores_fornecedores': [
      for (final e in fornecedores.take(5)) {'nome': e.key, 'total': _reais(e.value)},
    ],
    'ultimos_gastos': [
      for (final l in recentes.take(5))
        {
          'data': _data(l.data),
          'descricao': l.descricao,
          'valor': _reais(l.valor),
          'categoria': l.categoria.label,
          if (l.fornecedorNome != null) 'fornecedor': l.fornecedorNome,
        },
    ],
    'previsao_orcamento': {
      'situacao': previsao.risco.label,
      'gasto_projetado_no_fim': _reais(previsao.gastoProjetadoFinal),
      if (previsao.dataEstouroPrevista != null) 'data_estouro_prevista': _data(previsao.dataEstouroPrevista!),
    },
  });
  return resumo;
}

PrevisaoEstoque? _previsao(EstoqueItemModel e, DadosObraChat d, DateTime ref) {
  try {
    // O serviço filtra as movimentações do material sozinho.
    return PrevisaoEstoqueService.calcular(
        item: e, movimentos: d.movimentos, diario: d.diario, referencia: ref);
  } catch (_) {
    return null;
  }
}

String _dois(int n) => n.toString().padLeft(2, '0');
String _data(DateTime x) => '${x.year}-${_dois(x.month)}-${_dois(x.day)}';
String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Valor em reais, como texto: a IA repete o número igualzinho ao app.
String _reais(double v) {
  final centavos = (v * 100).round();
  final inteiro = (centavos ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < inteiro.length; i++) {
    if (i > 0 && (inteiro.length - i) % 3 == 0) buf.write('.');
    buf.write(inteiro[i]);
  }
  return 'R\$ $buf,${_dois(centavos % 100)}';
}
