import '../../models/models.dart';
import '../../utils/formatters.dart';
import 'numero_extenso.dart';
import 'previsao_estoque_service.dart';
import 'previsao_orcamento_service.dart';

/// Tudo que o assistente precisa saber sobre a obra para responder.
class DadosObraChat {
  final ObraModel obra;
  final List<LancamentoModel> lancamentos;
  final List<DiarioEntradaModel> diario;
  final List<CronogramaFaseModel> cronograma;
  final List<EstoqueItemModel> estoque;
  final List<MovimentoEstoqueModel> movimentos;

  const DadosObraChat({
    required this.obra,
    required this.lancamentos,
    required this.diario,
    required this.cronograma,
    required this.estoque,
    required this.movimentos,
  });

  List<LancamentoModel> get aprovados => lancamentos
      .where((l) => l.status == StatusLancamento.aprovado)
      .toList();

  List<LancamentoModel> get pendentes => lancamentos
      .where((l) => l.status == StatusLancamento.pendente)
      .toList();
}

class RespostaObra {
  final String texto;

  /// Perguntas de continuação sugeridas (viram chips no chat).
  final List<String> sugestoes;

  const RespostaObra(this.texto, {this.sugestoes = const []});
}

/// IA on-device nº 7 — assistente de perguntas da obra.
///
/// Entende perguntas em português sobre a obra (intenção + entidades:
/// categoria, material, fornecedor e período) e responde em linguagem
/// natural cruzando lançamentos, estoque, previsões, cronograma e diário.
/// Roda 100% no aparelho, sem internet.
abstract class PerguntasObraService {
  static const sugestoesIniciais = [
    'Quanto já gastei?',
    'Como está o orçamento?',
    'O que está acabando no estoque?',
    'Estamos atrasados?',
  ];

  static RespostaObra responder(String pergunta, DadosObraChat dados,
      {DateTime? agora}) {
    final ref = agora ?? DateTime.now();
    final hoje = DateTime(ref.year, ref.month, ref.day);
    // normaliza: números por extenso, minúsculas, sem acentos
    final t = _semAcentos(NumeroExtenso.normalizar(pergunta).toLowerCase());

    final material = _acharMaterial(t, dados);
    final fornecedor = _acharFornecedor(t, dados);
    final categoria = _acharCategoria(t);
    final periodo = _acharPeriodo(t, hoje);

    // Da intenção mais específica para a mais genérica.
    if (material != null && _tem(t, ['quando acaba', 'vai acabar', 'vai durar', 'termina'])) {
      return _terminoMaterial(material, dados, hoje);
    }
    if (material != null &&
        _tem(t, ['quanto tem', 'quantos', 'quantas', 'estoque', 'sobra', 'resta', 'tem de', 'tem no'])) {
      return _estoqueMaterial(material, dados, hoje);
    }
    if (_tem(t, ['acabando', 'faltando', 'repor', 'comprar material']) ||
        (_tem(t, ['estoque']) && material == null)) {
      return _estoqueGeral(dados, hoje);
    }
    if (_tem(t, ['pendente', 'pendencia', 'aprovar', 'aguardando', 'falta aprovar'])) {
      return _pendencias(dados, hoje);
    }
    if (_tem(t, ['maior gasto', 'mais caro', 'maior lancamento', 'maior despesa', 'maior compra'])) {
      return _maiorGasto(dados, periodo);
    }
    if (_tem(t, ['ultimos', 'ultimo']) &&
        _tem(t, ['gasto', 'lancamento', 'compra', 'despesa'])) {
      return _ultimosGastos(dados);
    }
    if (fornecedor != null) {
      return _gastoFornecedor(fornecedor, dados);
    }
    if (_tem(t, ['fornecedor', 'fornecedores', 'onde compro', 'onde mais compro'])) {
      return _topFornecedores(dados);
    }
    if (_tem(t, ['orcamento', 'estourar', 'estouro', 'vai faltar dinheiro', 'quanto resta', 'quanto sobra'])) {
      return _orcamento(dados);
    }
    if (_tem(t, ['atrasad', 'cronograma', 'fase', 'prazo', 'quando termina a obra', 'quando acaba a obra', 'quanto falta da obra'])) {
      return _cronograma(dados, hoje);
    }
    if (_tem(t, ['equipe', 'pessoas', 'trabalhador', 'choveu', 'chuva', 'clima', 'canteiro', 'diario'])) {
      return _canteiro(dados, hoje);
    }
    if (_tem(t, ['quanto', 'gast', 'custou', 'custo', 'total', 'paguei', 'comprei'])) {
      return _gasto(dados, categoria: categoria, periodo: periodo);
    }
    return _naoEntendi();
  }

  // ================================================== Respostas por intenção

  static RespostaObra _gasto(DadosObraChat dados,
      {CategoriaCusto? categoria, _Periodo? periodo}) {
    var itens = dados.aprovados;
    if (categoria != null) {
      itens = itens.where((l) => l.categoria == categoria).toList();
    }
    if (periodo != null) {
      itens = itens.where((l) => periodo.contem(l.data)).toList();
    }

    final contexto = [
      if (categoria != null) 'com ${categoria.label.toLowerCase()}',
      if (periodo != null) periodo.rotulo,
    ].join(' ');

    if (itens.isEmpty) {
      final extra = dados.pendentes.isNotEmpty
          ? ' Há ${dados.pendentes.length} lançamento'
              '${dados.pendentes.length > 1 ? 's' : ''} pendente'
              '${dados.pendentes.length > 1 ? 's' : ''} que ainda não '
              'conta${dados.pendentes.length > 1 ? 'm' : ''} aqui.'
          : '';
      return RespostaObra(
        'Não encontrei gastos aprovados'
        '${contexto.isEmpty ? '' : ' $contexto'}.$extra',
        sugestoes: const ['Quanto já gastei?', 'Tem lançamento pendente?'],
      );
    }

    final total = itens.fold<double>(0, (s, l) => s + l.valor);
    final b = StringBuffer(
        'Você gastou ${Formatters.moeda(total)}${contexto.isEmpty ? '' : ' $contexto'}, '
        'em ${itens.length} lançamento${itens.length > 1 ? 's' : ''} aprovado'
        '${itens.length > 1 ? 's' : ''}.');

    if (categoria == null) {
      final porCategoria = <CategoriaCusto, double>{};
      for (final l in itens) {
        porCategoria[l.categoria] = (porCategoria[l.categoria] ?? 0) + l.valor;
      }
      final maior =
          porCategoria.entries.reduce((a, c) => c.value > a.value ? c : a);
      b.write(' O maior peso é ${maior.key.label.toLowerCase()}, com '
          '${Formatters.moeda(maior.value)} '
          '(${(maior.value / total * 100).round()}%).');
    } else {
      final maior = itens.reduce((a, c) => c.valor > a.valor ? c : a);
      b.write(' O maior foi "${maior.descricao}" '
          '(${Formatters.moeda(maior.valor)}).');
    }
    if (periodo == null && dados.obra.orcamento > 0) {
      b.write(' Isso representa '
          '${(total / dados.obra.orcamento * 100).round()}% do orçamento.');
    }
    return RespostaObra(
      b.toString(),
      sugestoes: [
        if (categoria == null) 'Quanto gastei com material?',
        'Qual foi o maior gasto?',
        'Como está o orçamento?',
      ],
    );
  }

  static RespostaObra _orcamento(DadosObraChat dados) {
    final previsao = PrevisaoOrcamentoService.calcular(
        obra: dados.obra, lancamentos: dados.lancamentos);
    final restante = dados.obra.orcamento - previsao.gastoAtual;
    final b = StringBuffer(
        'Do orçamento de ${Formatters.moeda(dados.obra.orcamento)}, já foram '
        'usados ${Formatters.moeda(previsao.gastoAtual)} '
        '(${(previsao.percentualGasto * 100).round()}%). '
        '${restante >= 0 ? 'Restam ${Formatters.moeda(restante)}.' : 'O orçamento já estourou em ${Formatters.moeda(-restante)}.'}');
    if (previsao.dadosSuficientes) {
      b.write(' No ritmo atual, a projeção para o fim da obra é de '
          '${Formatters.moeda(previsao.gastoProjetadoFinal)}'
          '${previsao.dataEstouroPrevista != null ? ', com estouro estimado em ${Formatters.data(previsao.dataEstouroPrevista!)}' : ''}.');
    }
    b.write(' ${previsao.recomendacao}');
    return RespostaObra(
      b.toString(),
      sugestoes: const ['Qual foi o maior gasto?', 'Quanto gastei este mês?'],
    );
  }

  static RespostaObra _pendencias(DadosObraChat dados, DateTime hoje) {
    final pendentes = dados.pendentes;
    if (pendentes.isEmpty) {
      return const RespostaObra(
        'Nenhum lançamento pendente — está tudo aprovado. 👌',
        sugestoes: ['Quanto já gastei?', 'O que está acabando no estoque?'],
      );
    }
    final total = pendentes.fold<double>(0, (s, l) => s + l.valor);
    final maisAntigo =
        pendentes.reduce((a, b) => a.criadoEm.isBefore(b.criadoEm) ? a : b);
    final dias = hoje.difference(maisAntigo.criadoEm).inDays;
    return RespostaObra(
      'Há ${pendentes.length} lançamento${pendentes.length > 1 ? 's' : ''} '
      'aguardando aprovação, somando ${Formatters.moeda(total)}'
      '${dias >= 2 ? ' — o mais antigo está parado há $dias dias' : ''}. '
      'Enquanto não forem aprovados, ficam fora dos totais e do estoque.',
      sugestoes: const ['Quanto já gastei?'],
    );
  }

  static RespostaObra _maiorGasto(DadosObraChat dados, _Periodo? periodo) {
    var itens = dados.aprovados;
    if (periodo != null) {
      itens = itens.where((l) => periodo.contem(l.data)).toList();
    }
    if (itens.isEmpty) {
      return const RespostaObra('Ainda não há gastos aprovados para comparar.',
          sugestoes: ['Tem lançamento pendente?']);
    }
    final maior = itens.reduce((a, c) => c.valor > a.valor ? c : a);
    return RespostaObra(
      'O maior gasto${periodo != null ? ' ${periodo.rotulo}' : ''} foi '
      '"${maior.descricao}", de ${Formatters.moeda(maior.valor)} '
      '(${maior.categoria.label.toLowerCase()}'
      '${maior.fornecedorNome != null ? ', com ${maior.fornecedorNome}' : ''}), '
      'em ${Formatters.data(maior.data)}.',
      sugestoes: const ['Qual meu maior fornecedor?', 'Últimos lançamentos'],
    );
  }

  static RespostaObra _ultimosGastos(DadosObraChat dados) {
    final itens = List<LancamentoModel>.from(dados.aprovados)
      ..sort((a, b) => b.data.compareTo(a.data));
    if (itens.isEmpty) {
      return const RespostaObra('Ainda não há gastos aprovados registrados.',
          sugestoes: ['Tem lançamento pendente?']);
    }
    final ultimos = itens.take(3).toList();
    final linhas = ultimos
        .map((l) => '• ${Formatters.dataCurta(l.data)} — ${l.descricao} '
            '(${Formatters.moeda(l.valor)})')
        .join('\n');
    return RespostaObra(
      'Os últimos gastos aprovados foram:\n$linhas',
      sugestoes: const ['Qual foi o maior gasto?', 'Quanto gastei essa semana?'],
    );
  }

  static RespostaObra _gastoFornecedor(String fornecedor, DadosObraChat dados) {
    final doFornecedor = dados.aprovados
        .where((l) =>
            l.fornecedorNome != null &&
            _semAcentos(l.fornecedorNome!.toLowerCase()).contains(fornecedor))
        .toList();
    if (doFornecedor.isEmpty) {
      return RespostaObra(
          'Não encontrei gastos aprovados com esse fornecedor.',
          sugestoes: const ['Qual meu maior fornecedor?']);
    }
    final nome = doFornecedor.first.fornecedorNome!;
    final total = doFornecedor.fold<double>(0, (s, l) => s + l.valor);
    final ultimo = doFornecedor.reduce(
        (a, b) => a.data.isAfter(b.data) ? a : b);
    return RespostaObra(
      'Com $nome você gastou ${Formatters.moeda(total)} em '
      '${doFornecedor.length} compra${doFornecedor.length > 1 ? 's' : ''}. '
      'A última foi "${ultimo.descricao}" em ${Formatters.data(ultimo.data)}.',
      sugestoes: const ['Qual meu maior fornecedor?', 'Últimos lançamentos'],
    );
  }

  static RespostaObra _topFornecedores(DadosObraChat dados) {
    final porFornecedor = <String, double>{};
    for (final l in dados.aprovados) {
      if (l.fornecedorNome == null) continue;
      porFornecedor[l.fornecedorNome!] =
          (porFornecedor[l.fornecedorNome!] ?? 0) + l.valor;
    }
    if (porFornecedor.isEmpty) {
      return const RespostaObra(
          'Ainda não há gastos com fornecedor identificado. Dica: o OCR da '
          'nota e a voz preenchem o fornecedor automaticamente.',
          sugestoes: ['Quanto já gastei?']);
    }
    final top = porFornecedor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final linhas = top
        .take(3)
        .map((e) => '• ${e.key}: ${Formatters.moeda(e.value)}')
        .join('\n');
    return RespostaObra(
      'Seus maiores fornecedores são:\n$linhas',
      sugestoes: const ['Qual foi o maior gasto?'],
    );
  }

  static RespostaObra _estoqueMaterial(
      EstoqueItemModel item, DadosObraChat dados, DateTime hoje) {
    final b = StringBuffer(
        'Tem ${Formatters.quantidade(item.quantidade)} ${item.unidade} de '
        '${item.material} no estoque');
    if (item.estoqueBaixo) {
      b.write(' — abaixo do mínimo de '
          '${Formatters.quantidade(item.quantidadeMinima)} ${item.unidade}!');
    } else {
      b.write('.');
    }
    final previsao = PrevisaoEstoqueService.calcular(
      item: item,
      movimentos: dados.movimentos,
      diario: dados.diario,
      referencia: hoje,
    );
    if (previsao != null) {
      b.write(' No ritmo de consumo atual, deve acabar por volta de '
          '${Formatters.data(previsao.dataTermino)} '
          '(~${previsao.diasRestantes} dias).');
    }
    return RespostaObra(
      b.toString(),
      sugestoes: ['Quando acaba o ${item.material.toLowerCase()}?',
        'O que está acabando no estoque?'],
    );
  }

  static RespostaObra _terminoMaterial(
      EstoqueItemModel item, DadosObraChat dados, DateTime hoje) {
    final previsao = PrevisaoEstoqueService.calcular(
      item: item,
      movimentos: dados.movimentos,
      diario: dados.diario,
      referencia: hoje,
    );
    if (previsao == null) {
      return RespostaObra(
        'Ainda não tenho histórico de consumo suficiente do '
        '${item.material} para prever — registre as saídas no estoque '
        '(botão −) que eu aprendo o ritmo. Hoje tem '
        '${Formatters.quantidade(item.quantidade)} ${item.unidade}.',
        sugestoes: const ['O que está acabando no estoque?'],
      );
    }
    return RespostaObra(
      'No ritmo de consumo atual (~${previsao.consumoDiario.toStringAsFixed(1)} '
      '${item.unidade}/dia${previsao.consideraEquipe ? ', ajustado pelo tamanho da equipe' : ''}), '
      'o ${item.material} deve acabar por volta de '
      '${Formatters.data(previsao.dataTermino)} — daqui a '
      '~${previsao.diasRestantes} dia${previsao.diasRestantes == 1 ? '' : 's'}. '
      '${previsao.critico ? 'Vale programar a compra já!' : 'Dá para planejar a compra com calma.'}',
      sugestoes: const ['O que está acabando no estoque?', 'Quanto gastei com material?'],
    );
  }

  static RespostaObra _estoqueGeral(DadosObraChat dados, DateTime hoje) {
    if (dados.estoque.isEmpty) {
      return const RespostaObra(
          'O estoque ainda está vazio. Os materiais entram sozinhos quando '
          'um lançamento com itens é aprovado.',
          sugestoes: ['Quanto gastei com material?']);
    }
    final alertas = <String>[];
    for (final item in dados.estoque) {
      if (item.estoqueBaixo) {
        alertas.add('${item.material} está abaixo do mínimo '
            '(${Formatters.quantidade(item.quantidade)} ${item.unidade})');
        continue;
      }
      final p = PrevisaoEstoqueService.calcular(
        item: item,
        movimentos: dados.movimentos,
        diario: dados.diario,
        referencia: hoje,
      );
      if (p != null && p.atencao) {
        alertas.add('${item.material} acaba em ~${p.diasRestantes} dias '
            '(${Formatters.dataCurta(p.dataTermino)})');
      }
    }
    if (alertas.isEmpty) {
      return RespostaObra(
        'Estoque sob controle: nenhum dos ${dados.estoque.length} materiais '
        'está em nível crítico nem com término previsto para as próximas '
        'duas semanas.',
        sugestoes: const ['Quanto tem de cimento?'],
      );
    }
    return RespostaObra(
      'Atenção no estoque:\n${alertas.map((a) => '• $a').join('\n')}',
      sugestoes: const ['Quanto gastei com material?'],
    );
  }

  static RespostaObra _cronograma(DadosObraChat dados, DateTime hoje) {
    final obra = dados.obra;
    final pctPrazo = obra.duracaoDias <= 0
        ? 0
        : (obra.diasDecorridos / obra.duracaoDias * 100).round();
    final b = StringBuffer();

    if (dados.cronograma.isEmpty) {
      b.write('A obra está no ${obra.diasDecorridos}º dia de '
          '${obra.duracaoDias} ($pctPrazo% do prazo), com término previsto '
          'para ${Formatters.data(obra.previsaoTermino)}. Não há fases '
          'cadastradas no cronograma para medir o avanço físico.');
      return RespostaObra(b.toString(),
          sugestoes: const ['Como está o orçamento?']);
    }

    final pctFisico = (dados.cronograma
                .fold<int>(0, (s, f) => s + f.percentualConcluido) /
            dados.cronograma.length)
        .round();
    b.write('A obra está $pctFisico% concluída, com $pctPrazo% do prazo '
        'decorrido (término previsto: '
        '${Formatters.data(obra.previsaoTermino)}).');

    if (pctPrazo >= pctFisico + 15) {
      b.write(' Ou seja: está atrasada em relação ao calendário.');
    } else if (pctFisico >= pctPrazo) {
      b.write(' O avanço está adiantado em relação ao calendário. 👏');
    } else {
      b.write(' O ritmo está próximo do planejado.');
    }

    final emAndamento =
        dados.cronograma.where((f) => f.emAndamento).toList();
    if (emAndamento.isNotEmpty) {
      b.write(' Fase atual: '
          '${emAndamento.map((f) => '${f.nome} (${f.percentualConcluido}%)').join(' e ')}.');
    }
    final atrasadas = dados.cronograma.where((f) => f.atrasada).toList();
    if (atrasadas.isNotEmpty) {
      b.write(' ⚠️ ${atrasadas.map((f) => f.nome).join(', ')} '
          '${atrasadas.length > 1 ? 'passaram' : 'passou'} do prazo sem '
          'chegar a 100%.');
    }
    return RespostaObra(b.toString(),
        sugestoes: const ['Como está o orçamento?', 'Quantas pessoas na obra?']);
  }

  static RespostaObra _canteiro(DadosObraChat dados, DateTime hoje) {
    final janela = hoje.subtract(const Duration(days: 7));
    final registros =
        dados.diario.where((d) => d.data.isAfter(janela)).toList();
    if (registros.isEmpty) {
      return const RespostaObra(
          'Não há registros no diário nos últimos 7 dias. Registrar o dia a '
          'dia melhora as previsões de estoque e o relatório.',
          sugestoes: ['Como está o cronograma?']);
    }
    final media = registros.fold<int>(0, (s, d) => s + d.numeroPessoas) /
        registros.length;
    final chuva = registros
        .where((d) => d.clima.toLowerCase().contains('chuv'))
        .length;
    final ultimo =
        registros.reduce((a, b) => a.data.isAfter(b.data) ? a : b);
    return RespostaObra(
      'Nos últimos 7 dias o diário tem ${registros.length} '
      'registro${registros.length > 1 ? 's' : ''}, com equipe média de '
      '${media.toStringAsFixed(0)} pessoa${media >= 2 ? 's' : ''}'
      '${chuva > 0 ? ' e chuva em $chuva dia${chuva > 1 ? 's' : ''}' : ''}. '
      'Último registro (${Formatters.dataCurta(ultimo.data)}): '
      '"${ultimo.descricao}".',
      sugestoes: const ['Estamos atrasados?', 'O que está acabando no estoque?'],
    );
  }

  static RespostaObra _naoEntendi() => const RespostaObra(
        'Não entendi essa — mas sei responder sobre gastos ("quanto gastei '
        'com material este mês?"), orçamento ("vai estourar?"), estoque '
        '("quando acaba o cimento?"), fornecedores, cronograma, pendências '
        'e equipe. Tenta uma dessas 👇',
        sugestoes: sugestoesIniciais,
      );

  // ======================================================== Entidades

  static bool _tem(String t, List<String> termos) =>
      termos.any(t.contains);

  static CategoriaCusto? _acharCategoria(String t) {
    if (_tem(t, ['mao de obra', 'pedreiro', 'diaria', 'servente', 'salario'])) {
      return CategoriaCusto.maoDeObra;
    }
    if (_tem(t, ['equipamento', 'aluguel', 'betoneira', 'andaime', 'maquina'])) {
      return CategoriaCusto.equipamento;
    }
    if (_tem(t, ['material', 'materiais'])) return CategoriaCusto.material;
    return null;
  }

  static EstoqueItemModel? _acharMaterial(String t, DadosObraChat dados) {
    for (final item in dados.estoque) {
      final nome = _semAcentos(item.material.toLowerCase());
      if (t.contains(nome)) return item;
      // primeira palavra ("cimento" acha "Cimento CP-II")
      final primeira = nome.split(' ').first;
      if (primeira.length >= 4 && t.contains(primeira)) return item;
    }
    return null;
  }

  static String? _acharFornecedor(String t, DadosObraChat dados) {
    final nomes = dados.aprovados
        .map((l) => l.fornecedorNome)
        .whereType<String>()
        .toSet();
    for (final nome in nomes) {
      final limpo = _semAcentos(nome.toLowerCase());
      if (limpo.length >= 4 && t.contains(limpo)) return limpo;
      // duas primeiras palavras ("deposito sao jose" acha por "sao jose")
      final palavras =
          limpo.split(' ').where((p) => p.length >= 4).toList();
      if (palavras.length >= 2 &&
          t.contains('${palavras[palavras.length - 2]} ${palavras.last}')) {
        return limpo;
      }
    }
    return null;
  }

  static _Periodo? _acharPeriodo(String t, DateTime hoje) {
    if (t.contains('hoje')) return _Periodo(hoje, hoje, 'hoje');
    if (t.contains('ontem')) {
      final d = hoje.subtract(const Duration(days: 1));
      return _Periodo(d, d, 'ontem');
    }
    if (_tem(t, ['essa semana', 'esta semana', 'nessa semana', 'ultimos 7'])) {
      return _Periodo(
          hoje.subtract(const Duration(days: 6)), hoje, 'nos últimos 7 dias');
    }
    if (t.contains('semana passada')) {
      return _Periodo(hoje.subtract(const Duration(days: 13)),
          hoje.subtract(const Duration(days: 7)), 'na semana passada');
    }
    if (_tem(t, ['esse mes', 'este mes', 'neste mes', 'nesse mes'])) {
      return _Periodo(DateTime(hoje.year, hoje.month, 1), hoje, 'neste mês');
    }
    if (t.contains('mes passado')) {
      final inicio = DateTime(hoje.year, hoje.month - 1, 1);
      final fim = DateTime(hoje.year, hoje.month, 0);
      return _Periodo(inicio, fim, 'no mês passado');
    }
    const meses = {
      'janeiro': 1, 'fevereiro': 2, 'marco': 3, 'abril': 4, 'maio': 5,
      'junho': 6, 'julho': 7, 'agosto': 8, 'setembro': 9, 'outubro': 10,
      'novembro': 11, 'dezembro': 12,
    };
    for (final e in meses.entries) {
      if (t.contains('em ${e.key}') || t.contains('de ${e.key}')) {
        var ano = hoje.year;
        if (e.value > hoje.month) ano--; // mês ainda não chegou → ano passado
        final inicio = DateTime(ano, e.value, 1);
        final fim = DateTime(ano, e.value + 1, 0);
        return _Periodo(inicio, fim, 'em ${e.key}');
      }
    }
    return null;
  }

  static String _semAcentos(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const para = 'aaaaaeeeeiiiiooooouuuuc';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? para[i] : ch);
    }
    return b.toString();
  }
}

class _Periodo {
  final DateTime inicio;
  final DateTime fim;
  final String rotulo;

  const _Periodo(this.inicio, this.fim, this.rotulo);

  bool contem(DateTime d) {
    final dia = DateTime(d.year, d.month, d.day);
    return !dia.isBefore(inicio) &&
        !dia.isAfter(DateTime(fim.year, fim.month, fim.day));
  }
}
