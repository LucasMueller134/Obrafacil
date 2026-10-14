import '../../constants/app_constants.dart';
import '../../models/item_material_model.dart';
import 'numero_extenso.dart';
import 'texto_br.dart';

/// Extrai itens de material (quantidade + unidade + nome) de texto livre.
///
/// É o elo que interliga o financeiro ao estoque: a frase falada
/// ("comprei 10 sacos de cimento"), a descrição digitada e as linhas de
/// item da nota fiscal viram entradas de estoque na aprovação.
abstract class ItensParser {
  /// Normalização de unidades faladas/escritas → unidades do estoque.
  static const Map<String, String> _unidades = {
    'saco': 'sc',
    'sacos': 'sc',
    'sc': 'sc',
    'kg': 'kg',
    'quilo': 'kg',
    'quilos': 'kg',
    'kilo': 'kg',
    'kilos': 'kg',
    'litro': 'L',
    'litros': 'L',
    'l': 'L',
    'lata': 'lt',
    'latas': 'lt',
    'lt': 'lt',
    'barra': 'br',
    'barras': 'br',
    'br': 'br',
    'pacote': 'pc',
    'pacotes': 'pc',
    'pc': 'pc',
    'cx': 'pc',
    'caixa': 'pc',
    'caixas': 'pc',
    'unidade': 'un',
    'unidades': 'un',
    'un': 'un',
    'peca': 'un',
    'pecas': 'un',
    'peça': 'un',
    'peças': 'un',
    'metro': 'm',
    'metros': 'm',
    'm': 'm',
    'mt': 'm',
    'm2': 'm²',
    'm²': 'm²',
    'm3': 'm³',
    'm³': 'm³',
  };

  /// Apelidos comuns → material canônico do app. As chaves são comparadas
  /// sem acento e por palavra inteira, então "cano" casa com "canos" mas
  /// "cal" não casa com "calçada".
  static const Map<String, String> _apelidos = {
    'ferro': 'Vergalhão de aço',
    'ferragem': 'Vergalhão de aço',
    'vergalhao': 'Vergalhão de aço',
    'vergalhoes': 'Vergalhão de aço',
    'aco': 'Vergalhão de aço',
    'ceramica': 'Piso cerâmico',
    'porcelanato': 'Piso cerâmico',
    'azulejo': 'Piso cerâmico',
    'revestimento': 'Piso cerâmico',
    'massa': 'Argamassa',
    'argamassa': 'Argamassa',
    'rejunte': 'Argamassa',
    'bloco': 'Bloco de concreto',
    'blocos': 'Bloco de concreto',
    'fio': 'Fio elétrico',
    'cabo': 'Fio elétrico',
    'cano': 'Cano PVC',
    'pvc': 'Cano PVC',
    'tubo': 'Cano PVC',
    'conexao': 'Cano PVC',
    'joelho': 'Cano PVC',
    'tabua': 'Madeira',
    'ripa': 'Madeira',
    'caibro': 'Madeira',
    'sarrafo': 'Madeira',
    'compensado': 'Madeira',
    'pontalete': 'Madeira',
    'telhas': 'Telha',
    'esmalte': 'Tinta',
    'latex': 'Tinta',
    'selador': 'Tinta',
    'pedra': 'Brita',
    'pedrisco': 'Brita',
  };

  /// Unidades ditas por extenso e recipientes. "3 metros cúbicos de
  /// areia" é 3 m³, não 3 m de "cúbicos de areia".
  static const Map<String, String> _unidadesFaladas = {
    'metro cubico': 'm³',
    'metros cubicos': 'm³',
    'metro quadrado': 'm²',
    'metros quadrados': 'm²',
    'metro linear': 'm',
    'metros lineares': 'm',
    'tonelada': 'kg',
    'toneladas': 'kg',
    'milheiro': 'un',
    'milheiros': 'un',
    'duzia': 'un',
    'duzias': 'un',
    'rolo': 'un',
    'rolos': 'un',
    'galao': 'un',
    'galoes': 'un',
    'balde': 'un',
    'baldes': 'un',
    'carrinho': 'un',
    'carrinhos': 'un',
    'carrada': 'un',
    'carradas': 'un',
    'caminhao': 'un',
    'caminhoes': 'un',
    'feixe': 'un',
    'feixes': 'un',
    'fardo': 'un',
    'fardos': 'un',
    'folha': 'un',
    'folhas': 'un',
    'chapa': 'un',
    'chapas': 'un',
    'placa': 'un',
    'placas': 'un',
    'bobina': 'un',
    'bobinas': 'un',
  };

  /// Unidades que multiplicam a quantidade ("2 milheiros de tijolo" são
  /// 2000 tijolos; "1 tonelada" são 1000 kg).
  static const Map<String, double> _fatorUnidade = {
    'tonelada': 1000,
    'toneladas': 1000,
    'milheiro': 1000,
    'milheiros': 1000,
    'duzia': 12,
    'duzias': 12,
  };

  /// Recipientes não dizem o que é o material: "1 caminhão de entulho"
  /// não é estoque. Com eles o item só vale se o material for conhecido —
  /// como era antes de eles virarem unidade.
  static const Set<String> _recipientes = {
    'rolo',
    'rolos',
    'galao',
    'galoes',
    'balde',
    'baldes',
    'carrinho',
    'carrinhos',
    'carrada',
    'carradas',
    'caminhao',
    'caminhoes',
    'feixe',
    'feixes',
    'fardo',
    'fardos',
    'folha',
    'folhas',
    'chapa',
    'chapas',
    'placa',
    'placas',
    'bobina',
    'bobinas',
  };

  /// Número em pt-BR: "1.200" é mil e duzentos (ponto de milhar), "2,5" e
  /// "2.5" são dois e meio.
  static const String _numeroTexto =
      r'\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+(?:[.,]\d+)?';

  static final RegExp _regexTexto = RegExp(
      '(?<![\\d.,])($_numeroTexto)'
      // "2 e meio sacos" — meia unidade antes da unidade
      r'((?:\s+e\s+mei[oa])?)\s*'
      // unidade precisa terminar em fronteira ("3 madeiras" não é "3 m");
      // as de duas palavras vêm antes de "metro" sozinho.
      r'(?:(metros?\s+c[uú]bicos?|metros?\s+quadrados?|metros?\s+lineares|'
      r'metro\s+linear|sacos?|sc|kg|quilos?|kilos?|toneladas?|litros?|'
      r'latas?|barras?|pacotes?|caixas?|unidades?|pe[cç]as?|milheiros?|'
      r'd[uú]zias?|rolos?|gal(?:[aã]o|[oõ]es)|baldes?|carrinhos?|carradas?|'
      r'caminh(?:[aã]o|[oõ]es)|feixes?|fardos?|folhas?|chapas?|placas?|'
      r'bobinas?|metros?|m[23²³]?)(?![a-zA-ZÀ-ÿ0-9]))?'
      // "2 sacos e meio de cimento" — meia unidade depois da unidade
      r'((?:\s+e\s+mei[oa])?)\s*'
      r'(de\s+)?'
      r'([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ ]{2,30})',
      caseSensitive: false);

  /// "meio saco de cimento", "meia lata de tinta" — quantidade sem número.
  static final RegExp _regexMeio = RegExp(
      r'\bmei[oa]\s+'
      r'(metro\s+c[uú]bico|metro\s+quadrado|saco|lata|barra|pacote|caixa|'
      r'metro|quilo|litro|balde|pe[cç]a|tonelada|milheiro|d[uú]zia)s?\s*'
      r'(de\s+)?'
      r'([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ ]{2,30})',
      caseSensitive: false);

  /// Material dito antes da quantidade: "comprei porcelanato 40 metros
  /// quadrados", "areia 3 metros cúbicos por 450", "tinta 3 latas". Só
  /// com unidade dita e material conhecido — "cimento 300 areia 150" é
  /// preço, não quantidade.
  static final RegExp _regexMaterialAntes = RegExp(
      r'(?<![a-zA-ZÀ-ÿ0-9])([a-zA-ZÀ-ÿ]{3,})\s+'
      '(?<![\\d.,])($_numeroTexto)'
      r'((?:\s+e\s+mei[oa])?)\s*'
      r'(metros?\s+c[uú]bicos?|metros?\s+quadrados?|metros?\s+lineares|'
      r'metro\s+linear|sacos?|sc|kg|quilos?|kilos?|toneladas?|litros?|'
      r'latas?|barras?|pacotes?|caixas?|unidades?|pe[cç]as?|milheiros?|'
      r'd[uú]zias?|rolos?|gal(?:[aã]o|[oõ]es)|baldes?|carrinhos?|carradas?|'
      r'caminh(?:[aã]o|[oõ]es)|feixes?|fardos?|folhas?|chapas?|placas?|'
      r'bobinas?|metros?|m[23²³]?)(?![a-zA-ZÀ-ÿ0-9])',
      caseSensitive: false);

  /// Segunda palavra de uma unidade de duas ("metros QUADRADOS"): nunca é
  /// o nome do material — sem isto, "40 metros quadrados" no fim da frase
  /// virava 40 m do material "Quadrados".
  static const Set<String> _continuacaoDeUnidade = {
    'quadrado',
    'quadrados',
    'cubico',
    'cubicos',
    'linear',
    'lineares',
  };

  /// Materiais de nome curto demais para a busca geral (que exige quatro
  /// letras, por causa do texto ruidoso da nota). Na fala, por palavra
  /// inteira, "cal" é o material — "calçada" continua de fora.
  static const Map<String, String> _curtosDaFala = {'cal': 'Cal'};

  /// "e", vírgula ou "mais" entre dois itens de uma lista ditada.
  static final RegExp _ligacaoDeLista =
      RegExp(r'^\s*(?:,\s*(?:e\s+|mais\s+)?|e\s+|mais\s+)$');

  /// Palavras de dinheiro no lugar do material ("300 reais de cimento"
  /// é valor, não 300 unidades de cimento).
  static final RegExp _comecaComMoeda = RegExp(
      r'^(reais|real|conto|pila|centavo|mango|prata)',
      caseSensitive: false);

  /// Palavras onde o nome do material termina ("...cimento POR 350
  /// reais", "...andaime TÁ"). Comparadas sem acento.
  static const Set<String> _fimDoNome = {
    'por', 'no', 'na', 'nos', 'nas', 'do', 'da', 'dos', 'das', 'para',
    'pra', 'pro', 'pros', 'pras', 'com', 'reais', 'real', 'que', 'ontem',
    'hoje', 'anteontem', 'custou', 'custaram', 'saiu', 'deu', 'foi',
    'foram', 'ficou', 'e', 'cada', 'valendo', 'custando', 'mais',
    'tambem', 'pelo', 'pela', 'em', 'ao', 'aos', 'ou', 'quando', 'onde',
    'mas', 'porque', 'pois', 'dia', 'semana', 'mes',
    // fala que gruda no fim da frase
    'la', 'aqui', 'ali', 'ai', 'ta', 'to', 'ne', 'viu', 'certo', 'beleza',
    'ok', 'tipo', 'entao', 'dai', 'hein', 'po', 'cara', 'mano', 'bom',
    'olha', 'sabe', 'entendeu', 'blz', 'valeu', 'so',
  };

  /// Artigo ou preposição pendurado no fim do nome ("andaime a 15 cada").
  static const Set<String> _pendurados = {
    'a',
    'o',
    'as',
    'os',
    'um',
    'uma',
    'de',
    'e',
  };

  /// Verbo conjugado também encerra o nome ("cimento PAGUEI 350"). A
  /// terminação basta: nenhum material comum termina assim.
  static final RegExp _verbo =
      RegExp(r'^(?:[a-z]{2,}ei|[a-z]{3,}(?:amos|emos|imos|aram|eram|iram)|'
          r'[a-z]{2,}ou)$');

  static final RegExp _palavraAntes = RegExp(r'([a-zA-ZÀ-ÿ]+)\s*$');

  /// Interpreta texto livre (fala ou descrição digitada).
  static List<ItemMaterialModel> deTexto(String textoBruto) {
    // "dez sacos de cimento" → "10 sacos de cimento"
    final texto = NumeroExtenso.normalizar(textoBruto);
    return _semDuplicados([for (final i in localizar(texto)) i.item]);
  }

  /// Os itens do [texto] com a posição em que cada um foi dito. O texto
  /// já deve vir com os números em dígitos (NumeroExtenso.normalizar) —
  /// as posições valem nele.
  static List<ItemNoTexto> localizar(String texto) {
    final achados = <ItemNoTexto>[];

    for (final m in _regexTexto.allMatches(texto)) {
      var quantidade = _lerQuantidade(m.group(1)!);
      // "e meio" antes ou depois da unidade soma 0,5
      if ((m.group(2)?.isNotEmpty ?? false) ||
          (m.group(4)?.isNotEmpty ?? false)) {
        quantidade += 0.5;
      }
      final nomeCru = m.group(6)!;
      final inicioNome = m.end - nomeCru.length;
      final item = _montarItem(
        texto,
        inicio: m.start,
        fimQuantidade: inicioNome - (m.group(5)?.length ?? 0),
        inicioNome: inicioNome,
        quantidade: quantidade,
        unidadeBruta: m.group(3),
        nomeCru: nomeCru,
        palavraAntes:
            _palavraAntes.firstMatch(texto.substring(0, m.start))?.group(1),
      );
      if (item != null) achados.add(item);
    }

    for (final m in _regexMeio.allMatches(texto)) {
      final nomeCru = m.group(3)!;
      final inicioNome = m.end - nomeCru.length;
      final item = _montarItem(
        texto,
        inicio: m.start,
        fimQuantidade: inicioNome - (m.group(2)?.length ?? 0),
        inicioNome: inicioNome,
        quantidade: 0.5,
        unidadeBruta: m.group(1),
        nomeCru: nomeCru,
      );
      if (item != null) achados.add(item);
    }

    for (final m in _regexMaterialAntes.allMatches(texto)) {
      final item = _itemComMaterialAntes(m);
      if (item == null) continue;
      // O número já virou item pelo jeito comum ("3 latas de tinta").
      if (achados.any((a) => a.inicio == item.inicio)) continue;
      achados.add(item);
    }
    achados.sort((a, b) => a.inicio.compareTo(b.inicio));
    return _herdarUnidade(texto, achados);
  }

  /// "comprei porcelanato 40 metros quadrados": o material vem antes.
  static ItemNoTexto? _itemComMaterialAntes(RegExpMatch m) {
    final canonico = _materialDaFala(m.group(1)!);
    if (canonico == null) return null;
    final chaveUnidade = _chaveDaUnidade(m.group(4)!);
    var quantidade = _lerQuantidade(m.group(2)!);
    if (m.group(3)?.isNotEmpty ?? false) quantidade += 0.5;
    final total = quantidade * (_fatorUnidade[chaveUnidade] ?? 1);
    if (total <= 0 || total > 100000) return null;
    // A quantidade começa depois do material e do espaço.
    final inicio =
        m.start + m.group(0)!.indexOf(m.group(2)!, m.group(1)!.length);
    return ItemNoTexto(
      ItemMaterialModel(
        material: canonico,
        quantidade: total,
        unidade: _unidadeNoEstoque(chaveUnidade, canonico),
      ),
      inicio: inicio,
      fimQuantidade: m.end,
      fim: m.end,
      quantidadeClara: true,
      unidadeFalada: chaveUnidade,
    );
  }

  /// "10 sacos de cimento e 5 de areia": quem fala não repete a unidade,
  /// e a segunda quantidade é na mesma unidade da primeira — não 5
  /// unidades de areia. Só herda colada na anterior (por "e" ou vírgula)
  /// e com o "de" de quantidade; "e 20 tijolos" é contagem própria.
  static List<ItemNoTexto> _herdarUnidade(
      String texto, List<ItemNoTexto> itens) {
    final saida = <ItemNoTexto>[];
    for (final atual in itens) {
      final anterior = saida.isEmpty ? null : saida.last;
      final unidade = anterior?.unidadeFalada;
      final herda = anterior != null &&
          unidade != null &&
          atual.unidadeFalada == null &&
          atual.comDe &&
          anterior.fim <= atual.inicio &&
          _ligacaoDeLista.hasMatch(
              TextoBr.normalizar(texto.substring(anterior.fim, atual.inicio)));
      if (!herda) {
        saida.add(atual);
        continue;
      }
      saida.add(ItemNoTexto(
        ItemMaterialModel(
          material: atual.item.material,
          quantidade: atual.item.quantidade * (_fatorUnidade[unidade] ?? 1),
          unidade: _unidadeNoEstoque(unidade, atual.item.material),
        ),
        inicio: atual.inicio,
        fimQuantidade: atual.fimQuantidade,
        fim: atual.fim,
        quantidadeClara: true,
        unidadeFalada: unidade,
        comDe: true,
      ));
    }
    return saida;
  }

  static String _chaveDaUnidade(String bruta) =>
      TextoBr.normalizar(bruta).replaceAll(RegExp(r'\s+'), ' ');

  /// A unidade do estoque para a unidade dita. Areia e brita não se
  /// compram por metro linear: no canteiro, "2 metros de areia" são 2 m³.
  static String _unidadeNoEstoque(String? chave, String material) {
    final unidade = _unidades[chave] ?? _unidadesFaladas[chave] ?? 'un';
    final linearDito = chave != null && !chave.contains('linea');
    if (unidade == 'm' && linearDito && _aGranel.contains(material)) {
      return 'm³';
    }
    return unidade;
  }

  static const Set<String> _aGranel = {'Areia', 'Brita'};

  static double _lerQuantidade(String bruto) {
    var s = bruto;
    if (RegExp(r'^\d{1,3}(?:\.\d{3})+').hasMatch(s)) {
      s = s.replaceAll('.', '');
    }
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }

  static ItemNoTexto? _montarItem(
    String texto, {
    required int inicio,
    required int fimQuantidade,
    required int inicioNome,
    required double quantidade,
    required String? unidadeBruta,
    required String nomeCru,
    String? palavraAntes,
  }) {
    // "300 reais de cimento" é dinheiro, não quantidade de material
    if (_comecaComMoeda.hasMatch(nomeCru.trim())) return null;

    final chaveUnidade =
        unidadeBruta == null ? null : _chaveDaUnidade(unidadeBruta);
    final total = quantidade * (_fatorUnidade[chaveUnidade] ?? 1);
    if (total <= 0 || total > 100000) return null;

    final (nome, fimNome) = _limparNome(nomeCru);
    if (nome.length < 3) return null;
    final primeira = nome.split(' ').first;
    if (_continuacaoDeUnidade.contains(TextoBr.normalizar(primeira))) {
      return null;
    }

    final canonico = _materialDaFala(nome);
    final comDe = fimQuantidade < inicioNome;
    if (chaveUnidade == null || _recipientes.contains(chaveUnidade)) {
      // Sem unidade de medida, só aceita material conhecido, e logo no
      // começo do nome: "500 tijolos", "10 de cimento" — mas não
      // "250 e o cimento", onde o número é de outra coisa.
      if (canonico == null) return null;
      if (_materialDaFala(primeira) == null) return null;
      // Entre dois materiais ("cimento 300 areia 150") o número é do
      // primeiro — o preço dele —, não a quantidade do segundo.
      if (unidadeBruta == null &&
          fimQuantidade == inicioNome &&
          palavraAntes != null &&
          _materialDaFala(palavraAntes) != null) {
        return null;
      }
    }

    final material = canonico ?? _capitalizar(nome);
    return ItemNoTexto(
      ItemMaterialModel(
        material: material,
        quantidade: total,
        unidade: _unidadeNoEstoque(chaveUnidade, material),
      ),
      inicio: inicio,
      fimQuantidade: texto.substring(0, fimQuantidade).trimRight().length,
      fim: inicioNome + fimNome,
      quantidadeClara: chaveUnidade != null || !comDe,
      unidadeFalada: chaveUnidade,
      comDe: comDe,
    );
  }

  /// O material do app citado na fala: a busca geral e os nomes curtos.
  static String? _materialDaFala(String nome) {
    final canonico = _materialCanonico(nome);
    if (canonico != null) return canonico;
    final normalizado = TextoBr.normalizar(nome);
    for (final entrada in _curtosDaFala.entries) {
      if (TextoBr.contemPalavra(normalizado, entrada.key)) return entrada.value;
    }
    return null;
  }

  /// O nome do material até a primeira palavra que não faz parte dele, e
  /// onde ele termina dentro de [nomeCru].
  static (String, int) _limparNome(String nomeCru) {
    final palavras = RegExp(r'\S+').allMatches(nomeCru).toList();
    var ultima = -1;
    for (var i = 0; i < palavras.length; i++) {
      final p = TextoBr.normalizar(palavras[i].group(0)!);
      if (_fimDoNome.contains(p) || _verbo.hasMatch(p)) break;
      ultima = i;
    }
    while (ultima >= 0 &&
        _pendurados.contains(TextoBr.normalizar(palavras[ultima].group(0)!))) {
      ultima--;
    }
    if (ultima < 0) return ('', 0);
    final fim = palavras[ultima].end;
    return (nomeCru.substring(palavras.first.start, fim), fim);
  }

  // ------------------------------------------------- Linhas de nota fiscal

  static const String _unidadesNota = 'SC|UN|KG|LT|BR|PC|CX|MT|M2|M3|M|L';

  /// "10 SC CIMENTO CP-II 32,50 325,00" — quantidade antes do nome.
  static final RegExp _linhaQtdAntes = RegExp(
      '^\\s*(?:\\d{1,3}\\s+)?(\\d+(?:[.,]\\d+)?)\\s*($_unidadesNota)'
      r'\b[\s.:x-]*(.+?)\s+\d+[.,]\d{2}\b',
      caseSensitive: false);

  /// "001 7891234 CIMENTO CP-II 10 SC X 32,50 325,00" — nome antes,
  /// layout mais comum da NFC-e.
  static final RegExp _linhaNomeAntes = RegExp(
      r'^\s*(?:\d{1,4}\s+)?(?:\d{6,14}\s+)?(.+?)\s+'
      '(\\d+(?:[.,]\\d+)?)\\s*($_unidadesNota)'
      r'\b\s*[x*]\s*\d+[.,]\d{2}',
      caseSensitive: false);

  /// "10 SC x 32,50    325,00" — o nome do produto ficou na linha de cima.
  static final RegExp _linhaSoQtd = RegExp(
      '^\\s*(\\d+(?:[.,]\\d+)?)\\s*($_unidadesNota)'
      r'\b\s*[x*]\s*\d+[.,]\d{2}',
      caseSensitive: false);

  /// Linhas de fechamento do cupom nunca são item.
  static final RegExp _linhaDeFechamento = RegExp(
      r'\b(total|subtotal|troco|desconto|acr[eé]scimo|tributo|imposto|'
      r'forma de pagamento|dinheiro|cart[aã]o|pix)\b',
      caseSensitive: false);

  /// Interpreta o texto cru do OCR da nota, linha a linha.
  static List<ItemMaterialModel> deNotaOcr(String textoOcr) {
    final linhas = textoOcr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final itens = <ItemMaterialModel>[];
    for (var i = 0; i < linhas.length; i++) {
      final linha = linhas[i];
      if (_linhaDeFechamento.hasMatch(linha)) continue;

      final qtdAntes = _linhaQtdAntes.firstMatch(linha);
      if (qtdAntes != null) {
        final item = _itemDaNota(
            qtdAntes.group(1)!, qtdAntes.group(2)!, qtdAntes.group(3)!);
        if (item != null) {
          itens.add(item);
          continue;
        }
      }

      final nomeAntes = _linhaNomeAntes.firstMatch(linha);
      if (nomeAntes != null) {
        final item = _itemDaNota(
            nomeAntes.group(2)!, nomeAntes.group(3)!, nomeAntes.group(1)!);
        if (item != null) {
          itens.add(item);
          continue;
        }
      }

      // Quantidade e preço numa linha, nome do produto na linha anterior.
      final soQtd = _linhaSoQtd.firstMatch(linha);
      if (soQtd != null &&
          i > 0 &&
          !_linhaDeFechamento.hasMatch(linhas[i - 1])) {
        final item =
            _itemDaNota(soQtd.group(1)!, soQtd.group(2)!, linhas[i - 1]);
        if (item != null) itens.add(item);
      }
    }
    return _semDuplicados(itens);
  }

  static ItemMaterialModel? _itemDaNota(
      String quantidadeBruta, String unidade, String nomeBruto) {
    final quantidade =
        double.tryParse(quantidadeBruta.replaceAll(',', '.')) ?? 0;
    if (quantidade <= 0 || quantidade > 100000) return null;

    // remove código de produto e numeração do começo ("7891234 CIMENTO…")
    var nome = nomeBruto.trim().replaceFirst(RegExp(r'^[\d\W]+'), '').trim();
    // e o preço/quantidade que sobrou no fim ("CIMENTO 50KG 32,50")
    nome = nome.replaceFirst(RegExp(r'\s+\d+[.,]\d{2}.*$'), '').trim();
    if (nome.length < 3) return null;

    final canonico = _materialCanonico(nome);
    return ItemMaterialModel(
      material: canonico ?? _capitalizar(nome),
      quantidade: quantidade,
      unidade: _unidades[unidade.toLowerCase()] ?? 'un',
    );
  }

  /// Procura o material canônico do app dentro do nome lido.
  static String? _materialCanonico(String nome) {
    final normalizado = TextoBr.normalizar(nome);
    for (final entrada in _apelidos.entries) {
      if (TextoBr.contemPalavra(normalizado, entrada.key)) return entrada.value;
    }
    for (final material in AppConstants.materiaisComuns) {
      final primeiraPalavra = TextoBr.normalizar(material.split(' ').first);
      if (primeiraPalavra.length >= 4 &&
          TextoBr.contemPalavra(normalizado, primeiraPalavra)) {
        return material;
      }
    }
    return null;
  }

  static List<ItemMaterialModel> _semDuplicados(List<ItemMaterialModel> itens) {
    final vistos = <String>{};
    return itens.where((i) => vistos.add(i.material.toLowerCase())).toList();
  }

  static String _capitalizar(String s) {
    final limpo = s.trim().toLowerCase();
    return limpo[0].toUpperCase() + limpo.substring(1);
  }
}

/// Item de material achado na frase, com a posição em que foi dito.
///
/// O lançamento por voz precisa saber que o "10" de "10 sacos" é
/// quantidade (e não dinheiro) e a que item um preço "cada" se refere.
class ItemNoTexto {
  final ItemMaterialModel item;

  /// Início da quantidade e fim do nome do material na frase.
  final int inicio;
  final int fim;

  /// Fim da quantidade (número, "e meio" e unidade), antes do nome.
  final int fimQuantidade;

  /// A unidade foi dita ("10 sacos") ou o material veio colado no número
  /// ("500 tijolos"). Sem isso ("300 de cimento") o número pode ser
  /// dinheiro, e quem decide é o contexto da frase.
  final bool quantidadeClara;

  /// A unidade como foi dita, sem acento ("saco", "galoes", "metros
  /// cubicos"), ou null. O preço "a 120 o galão" procura o item dito em
  /// galões, mesmo que no estoque ele vire "un".
  final String? unidadeFalada;

  /// A quantidade veio com "de" e sem unidade ("5 de areia").
  final bool comDe;

  const ItemNoTexto(
    this.item, {
    required this.inicio,
    required this.fim,
    required this.fimQuantidade,
    required this.quantidadeClara,
    this.unidadeFalada,
    this.comDe = false,
  });
}
