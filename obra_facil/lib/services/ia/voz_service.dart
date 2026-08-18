import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/item_material_model.dart';
import '../../models/lancamento_model.dart';
import 'data_falada.dart';
import 'itens_parser.dart';
import 'numero_extenso.dart';
import 'texto_br.dart';

/// Lançamento interpretado a partir da fala.
class LancamentoPorVoz {
  final String descricao;
  final double? valor;
  final CategoriaCusto categoria;
  final String? fornecedorNome;

  /// Data falada ("ontem", "dia 5 de julho") — null quando o usuário
  /// não disse quando foi, e aí a tela mantém a data de hoje.
  final DateTime? data;

  /// Materiais detectados na fala — vão para o estoque na aprovação.
  final List<ItemMaterialModel> itens;
  final String transcricao;

  const LancamentoPorVoz({
    required this.descricao,
    this.valor,
    required this.categoria,
    this.fornecedorNome,
    this.data,
    this.itens = const [],
    required this.transcricao,
  });

  bool get temAlgo => valor != null || itens.isNotEmpty;
}

/// IA on-device nº 2b — lançamento por voz.
///
/// Interpreta a frase como um todo, não só palavras soltas:
/// fala → transcrição → números por extenso → extração de valor (com soma
/// de múltiplos valores, preço unitário "cada" e detecção de qual número é
/// o total), fornecedor (em qualquer posição, mesmo minúsculo), data,
/// materiais e categoria por peso de evidência — e a descrição é
/// reconstruída sem os trechos já entendidos.
///
/// Toda comparação de palavra passa pelo [TextoBr]: sem acento (a
/// transcrição erra acento o tempo todo) e por palavra inteira, para
/// "calçada" não ser classificada como o material cal.
class VozService {
  final SpeechToText _stt = SpeechToText();
  bool _inicializado = false;

  Future<bool> inicializar() async {
    if (_inicializado) return true;
    _inicializado = await _stt.initialize();
    return _inicializado;
  }

  bool get ouvindo => _stt.isListening;

  Future<void> ouvir(
      void Function(String textoParcial, bool finalizou) onTexto) async {
    await _stt.listen(
      // Modo ditado: tolera pausas na fala em vez de encerrar na primeira
      // respiração. Encerra após ~6s de silêncio ou quando o usuário toca
      // em "Concluir" (limite máximo de 2 minutos).
      listenOptions: SpeechListenOptions(
        localeId: 'pt_BR',
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
      ),
      onResult: (SpeechRecognitionResult r) =>
          onTexto(r.recognizedWords, r.finalResult),
    );
  }

  Future<void> parar() => _stt.stop();

  Future<void> cancelar() => _stt.cancel();

  // ============================================================= Parser

  /// Um número em português, com milhar e centavos opcionais:
  /// "350", "1.200", "1.234,56", "89,90".
  static const String _numeroBr =
      r'\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?';

  /// Valor em reais, com centavos opcionais:
  /// "350 reais", "89,90 reais", "25 reais e 50 centavos", "40 conto".
  static final RegExp _valorReais = RegExp(
      '($_numeroBr)'
      r'\s*(?:reais|real|conto[s]?|pila[s]?|mango[s]?|prata[s]?|pau)'
      r'(?:\s*e\s*(\d{1,2})\s*centavos?)?',
      caseSensitive: false);
  static final RegExp _valorComRs =
      RegExp('r\\\$\\s*($_numeroBr)', caseSensitive: false);

  /// Valor anunciado por um verbo de preço, sem a palavra "reais":
  /// "por 350", "custou 89,90", "saiu 1200", "ficou em 300", "deu 450".
  static final RegExp _valorAposVerbo = RegExp(
      r'\b(?:por|custou|custaram|saiu|sairam|sa[ií]ram|deu|deram|foi|ficou'
      r'(?:\s+em)?|fechou(?:\s+em)?|no\s+valor\s+de|valor\s+de|total\s+de)\s+'
      '(?:r\\\$\\s*)?($_numeroBr)'
      r'\b',
      caseSensitive: false);

  /// Lê o número no formato brasileiro: ponto separa milhar, vírgula separa
  /// centavos. "1.200" é mil e duzentos, não um vírgula dois.
  static double? _lerNumeroBr(String bruto) {
    final s = bruto.trim();
    if (RegExp(r'^\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?$').hasMatch(s)) {
      return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'));
    }
    return double.tryParse(s.replaceAll(',', '.'));
  }

  /// Marca de que aquele número é o total, e não mais uma parcela a somar.
  static final RegExp _antecedeTotal = RegExp(
      r'\b(?:no\s+total|ao\s+todo|total\s+de|deu\s+tudo|tudo|fechou'
      r'(?:\s+em)?|somou)\s*(?:de\s+)?$',
      caseSensitive: false);

  /// Preço unitário logo depois do valor: "40 reais cada", "35 a unidade".
  static final RegExp _marcaUnitario = RegExp(
      r'^\s*(?:cada(?:\s+um[a]?)?|a\s+unidade|por\s+unidade|o\s+saco|'
      r'a\s+pe[cç]a)\b',
      caseSensitive: false);

  /// Fornecedor em qualquer posição da frase, mesmo todo minúsculo
  /// (a transcrição de voz raramente capitaliza): "no depósito são josé",
  /// "na casa do construtor", "no atacadão da construção".
  static final RegExp _fornecedorComTipo = RegExp(
      r'\b(?:n[oa]|d[oa]|em|l[aá] n[oa])\s+'
      r'((?:loja|dep[oó]sito|deposito|casa|mercado|supermercado|madeireira|'
      r'ferragens?|ferragista|atacad(?:o|ao|ão)|agropecu[aá]ria|'
      r'distribuidora|comercial|construtora|materiais|material|serralheria|'
      r'vidra[cç]aria|marmoraria|home\s*center)\b'
      r'[a-zA-Zà-ÿÀ-Ý ]{0,34})',
      caseSensitive: false);

  /// Nome próprio capitalizado após na/no/da/do (quando a transcrição
  /// capitaliza): "no Depósito São José", "na Leroy".
  static final RegExp _fornecedorCapitalizado = RegExp(
      r'\b(?:n[oa]|d[oa]|em)\s+'
      r'([A-ZÀ-Ý][\wà-ÿ]+(?:\s+(?:d[oae]s?\s+)?[A-ZÀ-Ý][\wà-ÿ]+){0,3})');

  /// Redes conhecidas ditas sem preposição ("comprei na leroy merlin").
  static const List<String> _redesConhecidas = [
    'leroy merlin', 'leroy', 'telhanorte', 'obramax', 'cassol', 'balaroti',
    'tumelero', 'chatuba', 'dicico', 'sodimac', 'ferreira costa',
    'tenda atacado', 'havan', 'casa do construtor',
  ];

  /// Onde o nome do fornecedor termina dentro da captura.
  static final RegExp _corteFornecedor = RegExp(
      r'\s+(por|que|onde|quando|ontem|hoje|anteontem|dia|valendo|custou|'
      r'custando|custaram|saiu|deu|foi|ficou|fechou|com|para|pra|e)\b.*$',
      caseSensitive: false);

  /// Palavras que sozinhas não são nome de estabelecimento.
  static const List<String> _naoFornecedor = [
    'obra', 'total', 'terreno', 'servico', 'canteiro', 'estoque', 'valor',
    'casa', 'loja', 'mercado', 'material', 'materiais', 'deposito',
    'oficina', 'semana', 'conta',
  ];

  /// Verbos/aberturas de comando no começo da frase.
  static final RegExp _aberturas = RegExp(
      r'^\s*(?:anota(?:r)?\s+a[ií]|anota(?:r)?|registra(?:r)?(?:\s+pra\s+mim)?|'
      r'lan[cç]a(?:r)?|faz\s+um\s+lan[cç]amento\s+de|lan[cç]amento\s+de|'
      r'coloca(?:r)?|bota(?:r)?|comprei|compramos|paguei|pagamos|gastei|'
      r'gastamos|aluguei|alugamos|peguei|pegamos|levei|levamos|adquiri|'
      r'contratei|contratamos|mandei|fiz)\s+',
      caseSensitive: false);

  /// Palavras por categoria — sem acento e comparadas por palavra inteira
  /// (o plural é aceito automaticamente).
  static const Map<CategoriaCusto, List<String>> _palavrasCategoria = {
    CategoriaCusto.maoDeObra: [
      'pedreiro', 'servente', 'diaria', 'mao de obra', 'eletricista',
      'encanador', 'bombeiro hidraulico', 'pintor', 'ajudante', 'empreiteiro',
      'carpinteiro', 'salario', 'pagamento do', 'semana do', 'gesseiro',
      'azulejista', 'armador', 'soldador', 'marceneiro', 'serralheiro',
      'jardineiro', 'mestre de obra', 'empreita', 'funcionario', 'equipe',
      'peao', 'meio dia de trabalho', 'vale',
    ],
    CategoriaCusto.material: [
      'cimento', 'areia', 'brita', 'tijolo', 'bloco', 'vergalhao', 'ferro',
      'aco', 'madeira', 'telha', 'tinta', 'cano', 'pvc', 'fio', 'cabo',
      'argamassa', 'cal', 'piso', 'ceramica', 'porcelanato', 'porta',
      'janela', 'prego', 'parafuso', 'material', 'saco', 'massa corrida',
      'reboco', 'gesso', 'vidro', 'esquadria', 'tubo', 'conexao', 'granito',
      'marmore', 'concreto', 'laje', 'manta', 'impermeabilizante', 'rejunte',
      'selador', 'verniz', 'disjuntor', 'tomada', 'interruptor', 'registro',
      'torneira', 'caixa d', 'ripa', 'caibro', 'viga', 'pedrisco', 'arame',
      'lixa', 'silicone', 'espuma expansiva', 'azulejo', 'rodape',
    ],
    CategoriaCusto.equipamento: [
      'betoneira', 'andaime', 'furadeira', 'serra', 'martelete', 'aluguel',
      'alugou', 'aluguei', 'locacao', 'equipamento', 'maquina', 'compactador',
      'gerador', 'escora', 'cacamba', 'container', 'retroescavadeira',
      'vibrador', 'bomba de concreto', 'esmerilhadeira', 'lixadeira',
      'guincho', 'placa vibratoria', 'britadeira', 'policorte',
    ],
  };

  /// Sinais fortes (profissões, aluguel): pesam o dobro na classificação.
  /// "Paguei a diária do pedreiro e comprei cimento" é mão de obra,
  /// mesmo com material citado — e o cimento ainda vai para o estoque.
  static const List<String> _sinaisFortes = [
    'pedreiro', 'servente', 'diaria', 'mao de obra', 'eletricista',
    'encanador', 'pintor', 'ajudante', 'empreiteiro', 'carpinteiro',
    'gesseiro', 'azulejista', 'armador', 'soldador', 'salario', 'aluguel',
    'alugou', 'aluguei', 'locacao', 'empreita',
  ];

  /// Parser puro (testável): interpreta a frase transcrita.
  /// Chamado ao vivo a cada resultado parcial — precisa ser leve.
  /// [agora] fixa o "hoje" das datas relativas nos testes.
  static LancamentoPorVoz interpretar(String transcricao, {DateTime? agora}) {
    final original = transcricao.trim();
    // "trezentos e cinquenta reais" → "350 reais"
    final texto = NumeroExtenso.normalizar(original);

    final valorInfo = _extrairValorInfo(texto);
    final fornecedorInfo = _extrairFornecedorInfo(texto);
    final data = DataFalada.extrair(texto, agora: agora);
    final itens = ItensParser.deTexto(texto);

    // Preço unitário: "5 sacos por 40 reais cada" → 5 × 40 = 200.
    var valor = valorInfo.valor;
    if (valor != null && valorInfo.unitario && itens.isNotEmpty) {
      valor = valor * itens.first.quantidade;
    }

    return LancamentoPorVoz(
      descricao: _montarDescricao(
        texto,
        remover: [
          ...valorInfo.trechos,
          if (fornecedorInfo != null) fornecedorInfo.trecho,
        ],
        removerData: data != null,
        itens: itens,
      ),
      valor: valor,
      categoria: _classificarCategoria(texto),
      fornecedorNome: fornecedorInfo?.nome,
      data: data,
      itens: itens,
      transcricao: original,
    );
  }

  // ------------------------------------------------------------- Valor

  static _ValorInfo _extrairValorInfo(String texto) {
    final ocorrencias = <_Ocorrencia>[];

    void adicionar(int inicio, int fim, double valor) {
      if (valor <= 0) return;
      for (final o in ocorrencias) {
        if (inicio < o.fim && fim > o.inicio) return; // sobrepõe
      }
      ocorrencias.add(_Ocorrencia(inicio, fim, valor,
          ehTotal: _antecedeTotal.hasMatch(texto.substring(0, inicio))));
    }

    for (final m in _valorReais.allMatches(texto)) {
      final base = _lerNumeroBr(m.group(1)!) ?? 0;
      final centavos = int.tryParse(m.group(2) ?? '') ?? 0;
      adicionar(m.start, m.end, base + centavos / 100);
    }
    for (final m in _valorComRs.allMatches(texto)) {
      adicionar(m.start, m.end, _lerNumeroBr(m.group(1)!) ?? 0);
    }
    for (final m in _valorAposVerbo.allMatches(texto)) {
      adicionar(m.start, m.end, _lerNumeroBr(m.group(1)!) ?? 0);
    }

    if (ocorrencias.isEmpty) return const _ValorInfo(null, false, []);
    ocorrencias.sort((a, b) => a.inicio.compareTo(b.inicio));

    // "cada" logo após o valor → preço unitário.
    final unitario = ocorrencias.length == 1 &&
        _marcaUnitario.hasMatch(texto.substring(ocorrencias.first.fim));

    final trechos = ocorrencias.map((o) {
      var inicio = o.inicio;
      var fim = o.fim;
      // inclui o "por " anterior e o "cada" seguinte na limpeza
      final porAntes =
          RegExp(r'(?:\bpor|\bde)\s+$').firstMatch(texto.substring(0, inicio));
      if (porAntes != null) inicio = porAntes.start;
      final cadaDepois = _marcaUnitario.firstMatch(texto.substring(fim));
      if (cadaDepois != null) fim += cadaDepois.end;
      return (inicio, fim);
    }).toList();

    return _ValorInfo(_totalDe(ocorrencias, unitario), unitario, trechos);
  }

  /// Decide qual número da frase é o valor do lançamento.
  static double? _totalDe(List<_Ocorrencia> ocorrencias, bool unitario) {
    if (unitario) return ocorrencias.first.valor;
    if (ocorrencias.length == 1) return ocorrencias.first.valor;

    // "…cimento 300 e areia 150, no total 450" — quem foi anunciado como
    // total manda, senão somaríamos o total junto com as parcelas.
    final anunciado = ocorrencias.where((o) => o.ehTotal);
    if (anunciado.isNotEmpty) return anunciado.last.valor;

    // Um dos valores é a soma dos outros: ele é o total, os demais são as
    // parcelas detalhadas. Com só dois números seria ambíguo (150 e 150),
    // então a regra vale a partir de três.
    if (ocorrencias.length >= 3) {
      for (final o in ocorrencias) {
        final resto = ocorrencias
            .where((x) => !identical(x, o))
            .fold<double>(0, (s, x) => s + x.valor);
        if (resto > 0 && (resto - o.valor).abs() < 0.01) return o.valor;
      }
    }

    // Vários gastos na mesma frase ("300 de cimento e 150 de areia") → soma.
    return ocorrencias.fold<double>(0, (s, o) => s + o.valor);
  }

  // -------------------------------------------------------- Fornecedor

  static _FornecedorInfo? _extrairFornecedorInfo(String texto) {
    final normalizado = TextoBr.normalizar(texto);
    for (final rede in _redesConhecidas) {
      if (!TextoBr.contemPalavra(normalizado, rede)) continue;
      final inicio = normalizado.indexOf(rede);
      return _FornecedorInfo(
          _capitalizarNome(rede), (inicio, inicio + rede.length));
    }

    final m = _fornecedorComTipo.firstMatch(texto) ??
        _fornecedorCapitalizado.firstMatch(texto);
    if (m == null) return null;

    final bruto = m.group(1)!;
    final nome = bruto.replaceFirst(_corteFornecedor, '').trim();
    if (nome.length < 3) return null;
    if (_naoFornecedor.contains(TextoBr.normalizar(nome))) return null;

    // fim do trecho na frase original = início do grupo + nome mantido
    final inicioGrupo = m.end - bruto.length;
    return _FornecedorInfo(
      _capitalizarNome(nome),
      (m.start, inicioGrupo + nome.length),
    );
  }

  static String _capitalizarNome(String nome) {
    const minusculas = {'de', 'do', 'da', 'dos', 'das', 'e'};
    return nome.split(' ').where((p) => p.isNotEmpty).map((p) {
      final lower = p.toLowerCase();
      if (minusculas.contains(lower)) return lower;
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  // --------------------------------------------------------- Categoria

  static CategoriaCusto _classificarCategoria(String texto) {
    final t = TextoBr.normalizar(texto);
    var melhor = CategoriaCusto.outros;
    var melhorPontos = 0;
    for (final entry in _palavrasCategoria.entries) {
      var pontos = 0;
      for (final palavra in entry.value) {
        if (!TextoBr.contemPalavra(t, palavra)) continue;
        pontos += _sinaisFortes.contains(palavra) ? 2 : 1;
      }
      if (pontos > melhorPontos) {
        melhorPontos = pontos;
        melhor = entry.key;
      }
    }
    return melhor;
  }

  // --------------------------------------------------------- Descrição

  /// Reconstrói a descrição a partir do que sobrou da frase depois de
  /// remover o que já foi entendido (valor, fornecedor, data, verbo).
  static String _montarDescricao(
    String texto, {
    required List<(int, int)> remover,
    required bool removerData,
    required List<ItemMaterialModel> itens,
  }) {
    var d = texto;

    final ordenados = List<(int, int)>.from(remover)
      ..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (inicio, fim) in ordenados) {
      if (inicio < 0 || fim > d.length || inicio >= fim) continue;
      d = d.replaceRange(inicio, fim, ' ');
    }

    if (removerData) {
      for (final padrao in DataFalada.padroesLimpeza) {
        d = d.replaceFirst(padrao, ' ');
      }
    }

    d = d.replaceFirst(_aberturas, '');
    // conectores órfãos nas pontas ("de", "no", "por", "e"…)
    final orfaos = RegExp(r'^(?:de|do|da|no|na|em|por|com|e|a|o|,|\.)\s+',
        caseSensitive: false);
    final orfaosFim = RegExp(r'\s+(?:de|do|da|no|na|em|por|com|e|a|o|que|,|\.)$',
        caseSensitive: false);
    var anterior = '';
    while (anterior != d) {
      anterior = d;
      d = d.trim().replaceFirst(orfaos, '').trim();
      d = d.replaceFirst(orfaosFim, '').trim();
    }
    d = d.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    if (d.length < 3) {
      if (itens.isNotEmpty) {
        return itens.map((i) => i.resumo).join(' e ');
      }
      d = texto.trim();
    }
    return d[0].toUpperCase() + d.substring(1);
  }
}

class _Ocorrencia {
  final int inicio;
  final int fim;
  final double valor;

  /// A frase anunciou este número como o total ("no total 450").
  final bool ehTotal;

  const _Ocorrencia(this.inicio, this.fim, this.valor,
      {required this.ehTotal});
}

class _ValorInfo {
  final double? valor;
  final bool unitario;
  final List<(int, int)> trechos;

  const _ValorInfo(this.valor, this.unitario, this.trechos);
}

class _FornecedorInfo {
  final String nome;
  final (int, int) trecho;

  const _FornecedorInfo(this.nome, this.trecho);
}
