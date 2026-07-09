import 'dart:math' as math;

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
/// Compreensão em camadas: normalização (números por extenso, acentos,
/// saudações) → correção fuzzy de digitação (distância de edição contra o
/// vocabulário do domínio e os nomes reais da obra) → extração de entidades
/// (categoria, material, fornecedor, período) → intenção por sinônimos.
/// Responde em linguagem natural cruzando todos os dados. 100% offline.
abstract class PerguntasObraService {
  static const sugestoesIniciais = [
    'Como está a obra?',
    'Quanto já gastei?',
    'O que está acabando no estoque?',
    'Estamos atrasados?',
  ];

  static final RegExp _saudacaoRegex = RegExp(
      r'^(bom dia|boa tarde|boa noite|oi|ola|eai|e ai|opa|salve|fala|hey)'
      r'(?=[\s,!.?]|$)[\s,!.?]*',
      caseSensitive: false);

  static RespostaObra responder(String pergunta, DadosObraChat dados,
      {DateTime? agora}) {
    final ref = agora ?? DateTime.now();
    final hoje = DateTime(ref.year, ref.month, ref.day);

    // normaliza: números por extenso, minúsculas, sem acentos
    var t = _semAcentos(NumeroExtenso.normalizar(pergunta).toLowerCase())
        .trim();

    // saudação: responde se for só isso, senão remove e segue
    final saudacao = _saudacaoRegex.firstMatch(t);
    if (saudacao != null) {
      final resto = t.substring(saudacao.end).trim();
      if (resto.isEmpty || resto == 'tudo bem' || resto == 'tudo bem?') {
        return RespostaObra(
          '${_saudacaoDeVolta(saudacao.group(1)!)} Tudo pronto por aqui. '
          'O que você quer saber sobre a ${dados.obra.nome}?',
          sugestoes: sugestoesIniciais,
        );
      }
      t = resto;
    }

    final tokens = _tokens(t);
    bool tem(List<String> termos) => _casa(t, tokens, termos);

    if (tem(['obrigado', 'obrigada', 'valeu', 'brigado', 'show', 'perfeito', 'boa!'])) {
      return const RespostaObra(
          'Tamo junto! 👷 Qualquer coisa é só perguntar.',
          sugestoes: sugestoesIniciais);
    }
    if (tem(['o que voce sabe', 'o que voce faz', 'o que posso perguntar', 'me ajuda', 'ajuda', 'comandos'])) {
      return _naoEntendi(inicio: 'Posso te contar tudo sobre a obra:');
    }

    final material = _acharMaterial(t, tokens, dados);
    final fornecedor = _acharFornecedor(t, dados);
    final categoria = _acharCategoria(t, tokens);
    final periodo = _acharPeriodo(t, hoje);

    // Da intenção mais específica para a mais genérica.
    if (material != null &&
        tem(['quando acaba', 'vai acabar', 'vai durar', 'termina', 'quando falta'])) {
      return _terminoMaterial(material, dados, hoje);
    }
    if (material != null &&
        tem(['gastei', 'gasto', 'gastamos', 'custou', 'custa', 'paguei', 'comprei', 'investi'])) {
      return _gastoDeMaterial(material, dados);
    }
    if (material != null) {
      return _estoqueMaterial(material, dados, hoje);
    }
    if (tem(['acabando', 'faltando', 'repor', 'comprar material', 'estoque', 'material sobrando'])) {
      return _estoqueGeral(dados, hoje);
    }
    if (tem(['pendente', 'pendencia', 'aprovar', 'aguardando', 'falta aprovar', 'para aprovar'])) {
      return _pendencias(dados, hoje);
    }
    if (tem(['maior gasto', 'mais caro', 'maior lancamento', 'maior despesa', 'maior compra', 'gasto mais alto'])) {
      return _maiorGasto(dados, periodo);
    }
    if (tem(['ultimos gastos', 'ultimo gasto', 'ultimos lancamentos', 'ultimo lancamento', 'ultimas compras', 'ultima compra', 'recentes'])) {
      return _ultimosGastos(dados);
    }
    if (fornecedor != null) {
      return _gastoFornecedor(fornecedor, dados);
    }
    if (tem(['fornecedor', 'fornecedores', 'onde compro', 'onde mais compro', 'de quem compro'])) {
      return _topFornecedores(dados);
    }
    if (tem(['orcamento', 'estourar', 'estouro', 'vai faltar dinheiro', 'quanto resta', 'quanto sobra', 'saldo', 'falta gastar', 'posso gastar', 'quanto ainda tenho'])) {
      return _orcamento(dados);
    }
    if (tem(['atrasad', 'cronograma', 'fase', 'prazo', 'em dia', 'no prazo', 'adiantad', 'quando termina a obra', 'quando acaba a obra', 'quanto falta da obra', 'falta muito', 'vai demorar'])) {
      return _cronograma(dados, hoje);
    }
    if (tem(['equipe', 'pessoas', 'trabalhador', 'trabalharam', 'choveu', 'chuva', 'clima', 'canteiro', 'diario'])) {
      return _canteiro(dados, hoje);
    }
    if (tem(['quanto', 'gastei', 'gasto', 'gastamos', 'gastou', 'custou', 'custo', 'total', 'paguei', 'pagamos', 'comprei', 'despesa', 'investi'])) {
      return _gasto(dados, categoria: categoria, periodo: periodo);
    }
    // "como está a obra?", "situação", "contexto", "resumo", "novidades"…
    if (tem(['como esta', 'como vai', 'como anda', 'como estao', 'situacao', 'contexto', 'resumo', 'panorama', 'status', 'andamento', 'novidade', 'visao geral', 'me atualiza', 'tudo bem'])) {
      return _resumoGeral(dados, hoje);
    }
    return _naoEntendi();
  }

  // ================================================== Respostas por intenção

  /// Panorama executivo — a resposta para "como está a obra?".
  static RespostaObra _resumoGeral(DadosObraChat dados, DateTime hoje) {
    final obra = dados.obra;
    final gasto = dados.aprovados.fold<double>(0, (s, l) => s + l.valor);
    final pctGasto =
        obra.orcamento <= 0 ? 0 : (gasto / obra.orcamento * 100).round();
    final pctPrazo = obra.duracaoDias <= 0
        ? 0
        : (obra.diasDecorridos / obra.duracaoDias * 100).round();

    final b = StringBuffer(
        'Panorama da ${obra.nome}: ${obra.diasDecorridos}º dia de '
        '${obra.duracaoDias} ($pctPrazo% do prazo). Gasto aprovado de '
        '${Formatters.moeda(gasto)} — $pctGasto% do orçamento de '
        '${Formatters.moeda(obra.orcamento)}.');

    if (dados.cronograma.isNotEmpty) {
      final pctFisico = (dados.cronograma
                  .fold<int>(0, (s, f) => s + f.percentualConcluido) /
              dados.cronograma.length)
          .round();
      b.write(' Avanço físico: $pctFisico%');
      final atual = dados.cronograma.where((f) => f.emAndamento).toList();
      if (atual.isNotEmpty) {
        b.write(' (fase atual: ${atual.map((f) => f.nome).join(' e ')})');
      }
      b.write(pctPrazo >= pctFisico + 15
          ? ' — atrasada em relação ao calendário.'
          : '.');
    }

    if (dados.pendentes.isNotEmpty) {
      final totalPend =
          dados.pendentes.fold<double>(0, (s, l) => s + l.valor);
      b.write(' Há ${dados.pendentes.length} lançamento'
          '${dados.pendentes.length > 1 ? 's' : ''} pendente'
          '${dados.pendentes.length > 1 ? 's' : ''} '
          '(${Formatters.moeda(totalPend)}).');
    }

    final criticos = <String>[];
    for (final item in dados.estoque) {
      if (item.estoqueBaixo) {
        criticos.add(item.material);
        continue;
      }
      final p = PrevisaoEstoqueService.calcular(
          item: item,
          movimentos: dados.movimentos,
          diario: dados.diario,
          referencia: hoje);
      if (p != null && p.atencao) criticos.add(item.material);
    }
    if (criticos.isNotEmpty) {
      b.write(' No estoque, fique de olho em: ${criticos.join(', ')}.');
    }

    return RespostaObra(
      b.toString(),
      sugestoes: const [
        'Como está o orçamento?',
        'Estamos atrasados?',
        'Tem lançamento pendente?',
      ],
    );
  }

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

  /// "Quanto gastei com cimento?" — soma os lançamentos ligados ao material
  /// (pelos itens estruturados ou pela descrição).
  static RespostaObra _gastoDeMaterial(
      EstoqueItemModel item, DadosObraChat dados) {
    final chave = _semAcentos(item.material.toLowerCase()).split(' ').first;
    final ligados = dados.aprovados.where((l) {
      if (l.itens.any(
          (i) => _semAcentos(i.material.toLowerCase()).contains(chave))) {
        return true;
      }
      return _semAcentos(l.descricao.toLowerCase()).contains(chave);
    }).toList();

    if (ligados.isEmpty) {
      return RespostaObra(
        'Não encontrei gastos aprovados ligados a ${item.material}. '
        'No estoque há ${Formatters.quantidade(item.quantidade)} '
        '${item.unidade}.',
        sugestoes: ['Quanto tem de ${item.material.toLowerCase()}?'],
      );
    }
    final total = ligados.fold<double>(0, (s, l) => s + l.valor);
    final ultimo =
        ligados.reduce((a, b) => a.data.isAfter(b.data) ? a : b);
    return RespostaObra(
      'Com ${item.material} você gastou ${Formatters.moeda(total)} em '
      '${ligados.length} lançamento${ligados.length > 1 ? 's' : ''}. '
      'O mais recente foi "${ultimo.descricao}" em '
      '${Formatters.data(ultimo.data)}.',
      sugestoes: ['Quando acaba o ${item.material.toLowerCase()}?'],
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

  static RespostaObra _naoEntendi({String? inicio}) => RespostaObra(
        '${inicio ?? 'Não entendi essa — mas sei responder sobre'} '
        'gastos ("quanto gastei com material este mês?"), orçamento '
        '("vai estourar?"), estoque ("quando acaba o cimento?"), '
        'fornecedores, cronograma, pendências, equipe e um resumo geral '
        '("como está a obra?"). Tenta uma dessas 👇',
        sugestoes: sugestoesIniciais,
      );

  static String _saudacaoDeVolta(String saudacao) {
    if (saudacao.startsWith('bom dia')) return 'Bom dia! ☀️';
    if (saudacao.startsWith('boa tarde')) return 'Boa tarde!';
    if (saudacao.startsWith('boa noite')) return 'Boa noite!';
    return 'Opa!';
  }

  // ================================== Compreensão (fuzzy + entidades)

  static List<String> _tokens(String t) => t
      .split(RegExp(r'[^a-z0-9]+'))
      .where((p) => p.isNotEmpty)
      .toList();

  /// Um termo casa se aparece no texto ou, para palavras únicas, se algum
  /// token está a 1-2 erros de digitação dele ("orsamento" → "orcamento").
  static bool _casa(String t, List<String> tokens, List<String> termos) {
    for (final termo in termos) {
      if (t.contains(termo)) return true;
      if (!termo.contains(' ') && termo.length >= 5) {
        for (final token in tokens) {
          if (_parecido(token, termo)) return true;
        }
      }
    }
    return false;
  }

  static bool _parecido(String token, String palavra) {
    if (token == palavra) return true;
    if (palavra.length < 5) return false;
    final maxErros = palavra.length >= 8 ? 2 : 1;
    if ((token.length - palavra.length).abs() > maxErros) return false;
    return _distancia(token, palavra) <= maxErros;
  }

  /// Distância de edição (Levenshtein) com duas linhas de memória.
  static int _distancia(String a, String b) {
    var anterior = List<int>.generate(b.length + 1, (i) => i);
    final atual = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      atual[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final custo = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        atual[j] = math.min(
            math.min(atual[j - 1] + 1, anterior[j] + 1),
            anterior[j - 1] + custo);
      }
      anterior = List<int>.from(atual);
    }
    return anterior[b.length];
  }

  static CategoriaCusto? _acharCategoria(String t, List<String> tokens) {
    if (_casa(t, tokens, ['mao de obra', 'pedreiro', 'diaria', 'servente', 'salario'])) {
      return CategoriaCusto.maoDeObra;
    }
    if (_casa(t, tokens, ['equipamento', 'aluguel', 'betoneira', 'andaime', 'maquina'])) {
      return CategoriaCusto.equipamento;
    }
    if (_casa(t, tokens, ['material', 'materiais'])) {
      return CategoriaCusto.material;
    }
    return null;
  }

  static EstoqueItemModel? _acharMaterial(
      String t, List<String> tokens, DadosObraChat dados) {
    for (final item in dados.estoque) {
      final nome = _semAcentos(item.material.toLowerCase());
      if (t.contains(nome)) return item;
      final primeira = nome.split(' ').first;
      if (primeira.length >= 4) {
        if (t.contains(primeira)) return item;
        // tolera digitação: "cimeto" acha "cimento"
        for (final token in tokens) {
          if (_parecido(token, primeira)) return item;
        }
      }
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
    if (_casaSimples(t, ['essa semana', 'esta semana', 'nessa semana', 'ultimos 7'])) {
      return _Periodo(
          hoje.subtract(const Duration(days: 6)), hoje, 'nos últimos 7 dias');
    }
    if (t.contains('semana passada')) {
      return _Periodo(hoje.subtract(const Duration(days: 13)),
          hoje.subtract(const Duration(days: 7)), 'na semana passada');
    }
    if (_casaSimples(t, ['esse mes', 'este mes', 'neste mes', 'nesse mes'])) {
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

  static bool _casaSimples(String t, List<String> termos) =>
      termos.any(t.contains);

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
