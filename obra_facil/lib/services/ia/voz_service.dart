import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/item_material_model.dart';
import '../../models/lancamento_model.dart';
import 'data_falada.dart';
import 'itens_parser.dart';
import 'numero_extenso.dart';

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
/// de múltiplos valores e preço unitário "cada"), fornecedor (em qualquer
/// posição, mesmo minúsculo), data, materiais e categoria por peso de
/// evidência — e a descrição é reconstruída sem os trechos já entendidos.
class VozService {
  final SpeechToText _stt = SpeechToText();
  bool _inicializado = false;

  Future<bool> inicializar() async {
    if (_inicializado) return true;
    _inicializado = await _stt.initialize();
    return _inicializado;
  }

  bool get ouvindo => _stt.isListening;

  Future<void> ouvir(void Function(String textoParcial, bool finalizou) onTexto) async {
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

  /// Valor em reais, com centavos opcionais:
  /// "350 reais", "89,90 reais", "25 reais e 50 centavos", "40 conto".
  static final RegExp _valorReais = RegExp(
      r'(\d+(?:[.,]\d{1,2})?)\s*(?:reais|real|conto[s]?|pila[s]?)'
      r'(?:\s*e\s*(\d{1,2})\s*centavos?)?',
      caseSensitive: false);
  static final RegExp _valorComRs = RegExp(
      r'r\$\s*(\d+(?:[.,]\d{1,2})?)',
      caseSensitive: false);
  static final RegExp _valorAposPor = RegExp(
      r'\bpor\s+(?:r\$\s*)?(\d+(?:[.,]\d{1,2})?)\b',
      caseSensitive: false);

  /// Fornecedor em qualquer posição da frase, mesmo todo minúsculo
  /// (a transcrição de voz raramente capitaliza): "no depósito são josé",
  /// "na casa do construtor", "no atacadão da construção".
  static final RegExp _fornecedorComTipo = RegExp(
      r'\b(?:n[oa]|d[oa]|em|l[aá] n[oa])\s+'
      r'((?:loja|dep[oó]sito|deposito|casa|mercado|supermercado|madeireira|'
      r'ferragens?|ferragista|atacad(?:o|ao|ão)|agropecu[aá]ria|'
      r'distribuidora|comercial|construtora|materiais|material)\b'
      r'[a-zA-Zà-ÿÀ-Ý ]{0,34})',
      caseSensitive: false);

  /// Nome próprio capitalizado após na/no/da/do (quando a transcrição
  /// capitaliza): "no Depósito São José", "na Leroy".
  static final RegExp _fornecedorCapitalizado = RegExp(
      r'\b(?:n[oa]|d[oa]|em)\s+'
      r'([A-ZÀ-Ý][\wà-ÿ]+(?:\s+(?:d[oae]s?\s+)?[A-ZÀ-Ý][\wà-ÿ]+){0,3})');

  /// Onde o nome do fornecedor termina dentro da captura.
  static final RegExp _corteFornecedor = RegExp(
      r'\s+(por|que|onde|quando|ontem|hoje|anteontem|dia|valendo|custou|'
      r'custando|saiu|deu|foi|com|para|pra|e)\b.*$',
      caseSensitive: false);

  static const List<String> _naoFornecedor = [
    'obra', 'total', 'terreno', 'servico', 'serviço', 'canteiro',
    'estoque', 'valor',
  ];

  /// Verbos/aberturas de comando no começo da frase.
  static final RegExp _aberturas = RegExp(
      r'^\s*(?:anota(?:r)?\s+a[ií]|anota(?:r)?|registra(?:r)?(?:\s+pra\s+mim)?|'
      r'lan[cç]a(?:r)?|faz\s+um\s+lan[cç]amento\s+de|lan[cç]amento\s+de|'
      r'coloca(?:r)?|bota(?:r)?|comprei|compramos|paguei|pagamos|gastei|'
      r'gastamos|aluguei|alugamos)\s+',
      caseSensitive: false);

  static const Map<CategoriaCusto, List<String>> _palavrasCategoria = {
    CategoriaCusto.maoDeObra: [
      'pedreiro', 'servente', 'diária', 'diaria', 'mão de obra', 'mao de obra',
      'eletricista', 'encanador', 'pintor', 'ajudante', 'empreiteiro',
      'carpinteiro', 'salário', 'salario', 'pagamento do', 'semana do',
      'gesseiro', 'azulejista', 'armador', 'soldador', 'marceneiro',
      'serralheiro', 'jardineiro', 'mestre de obra', 'empreita',
    ],
    CategoriaCusto.material: [
      'cimento', 'areia', 'brita', 'tijolo', 'bloco', 'vergalhão', 'vergalhao',
      'ferro', 'madeira', 'telha', 'tinta', 'cano', 'pvc', 'fio', 'cabo',
      'argamassa', 'cal', 'piso', 'cerâmica', 'ceramica', 'porta', 'janela',
      'prego', 'parafuso', 'material', 'saco', 'massa corrida', 'reboco',
      'gesso', 'vidro', 'esquadria', 'tubo', 'conexão', 'conexao', 'granito',
      'mármore', 'marmore', 'concreto', 'laje', 'manta', 'impermeabilizante',
      'rejunte', 'selador', 'verniz', 'disjuntor', 'tomada', 'interruptor',
      'registro', 'torneira', 'caixa d', 'ripa', 'caibro', 'viga',
    ],
    CategoriaCusto.equipamento: [
      'betoneira', 'andaime', 'furadeira', 'serra', 'martelete',
      'aluguel', 'alugou', 'aluguei', 'locação', 'locacao', 'equipamento',
      'máquina', 'maquina', 'compactador', 'gerador', 'escora', 'caçamba',
      'cacamba', 'container', 'retroescavadeira', 'vibrador',
      'bomba de concreto', 'esmerilhadeira', 'lixadeira', 'guincho',
    ],
  };

  /// Sinais fortes (profissões, aluguel): pesam o dobro na classificação.
  /// "Paguei a diária do pedreiro e comprei cimento" é mão de obra,
  /// mesmo com material citado — e o cimento ainda vai para o estoque.
  static const List<String> _sinaisFortes = [
    'pedreiro', 'servente', 'diária', 'diaria', 'mão de obra', 'mao de obra',
    'eletricista', 'encanador', 'pintor', 'ajudante', 'empreiteiro',
    'carpinteiro', 'gesseiro', 'azulejista', 'armador', 'soldador',
    'salário', 'salario', 'aluguel', 'alugou', 'aluguei', 'locação',
    'locacao', 'empreita',
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
    final ocorrencias = <(int, int, double)>[];

    void adicionar(int inicio, int fim, double valor) {
      if (valor <= 0) return;
      for (final o in ocorrencias) {
        if (inicio < o.$2 && fim > o.$1) return; // sobrepõe
      }
      ocorrencias.add((inicio, fim, valor));
    }

    for (final m in _valorReais.allMatches(texto)) {
      final base = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
      final centavos = int.tryParse(m.group(2) ?? '') ?? 0;
      adicionar(m.start, m.end, base + centavos / 100);
    }
    for (final m in _valorComRs.allMatches(texto)) {
      adicionar(m.start, m.end,
          double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0);
    }
    for (final m in _valorAposPor.allMatches(texto)) {
      adicionar(m.start, m.end,
          double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0);
    }

    if (ocorrencias.isEmpty) return const _ValorInfo(null, false, []);
    ocorrencias.sort((a, b) => a.$1.compareTo(b.$1));

    // "cada" logo após o valor → preço unitário.
    final unitario = ocorrencias.length == 1 &&
        RegExp(r'^\s*cada\b')
            .hasMatch(texto.substring(ocorrencias.first.$2));

    // Vários valores na frase ("300 de cimento e 150 de areia") → soma.
    final total = ocorrencias.fold<double>(0, (s, o) => s + o.$3);

    final trechos = ocorrencias.map((o) {
      var inicio = o.$1;
      var fim = o.$2;
      // inclui o "por " anterior e o "cada" seguinte na limpeza
      final antes = texto.substring(0, inicio);
      final porAntes = RegExp(r'(?:\bpor|\bde)\s+$').firstMatch(antes);
      if (porAntes != null) inicio = porAntes.start;
      final cadaDepois =
          RegExp(r'^\s*cada\b').firstMatch(texto.substring(fim));
      if (cadaDepois != null) fim += cadaDepois.end;
      return (inicio, fim);
    }).toList();

    return _ValorInfo(
        unitario ? ocorrencias.first.$3 : total, unitario, trechos);
  }

  // -------------------------------------------------------- Fornecedor

  static _FornecedorInfo? _extrairFornecedorInfo(String texto) {
    final m = _fornecedorComTipo.firstMatch(texto) ??
        _fornecedorCapitalizado.firstMatch(texto);
    if (m == null) return null;

    final bruto = m.group(1)!;
    final nome = bruto.replaceFirst(_corteFornecedor, '').trim();
    if (nome.length < 3) return null;
    if (_naoFornecedor.contains(nome.toLowerCase())) return null;

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
    final t = texto.toLowerCase();
    var melhor = CategoriaCusto.outros;
    var melhorPontos = 0;
    for (final entry in _palavrasCategoria.entries) {
      var pontos = 0;
      for (final palavra in entry.value) {
        if (!t.contains(palavra)) continue;
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
    final orfaos =
        RegExp(r'^(?:de|do|da|no|na|em|por|com|e|a|o|,|\.)\s+', caseSensitive: false);
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
