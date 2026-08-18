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
    'saco': 'sc', 'sacos': 'sc', 'sc': 'sc',
    'kg': 'kg', 'quilo': 'kg', 'quilos': 'kg', 'kilo': 'kg', 'kilos': 'kg',
    'litro': 'L', 'litros': 'L', 'l': 'L',
    'lata': 'lt', 'latas': 'lt', 'lt': 'lt',
    'barra': 'br', 'barras': 'br', 'br': 'br',
    'pacote': 'pc', 'pacotes': 'pc', 'pc': 'pc', 'cx': 'pc',
    'caixa': 'pc', 'caixas': 'pc',
    'unidade': 'un', 'unidades': 'un', 'un': 'un',
    'peca': 'un', 'pecas': 'un', 'peça': 'un', 'peças': 'un',
    'metro': 'm', 'metros': 'm', 'm': 'm', 'mt': 'm',
    'm2': 'm²', 'm²': 'm²',
    'm3': 'm³', 'm³': 'm³',
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

  static final RegExp _regexTexto = RegExp(
      r'(\d+(?:[.,]\d+)?)'
      // "2 e meio sacos" — meia unidade antes da unidade
      r'((?:\s+e\s+mei[oa])?)\s*'
      // unidade precisa terminar em fronteira ("3 madeiras" não é "3 m")
      r'(?:(sacos?|sc|kg|quilos?|kilos?|litros?|latas?|barras?|pacotes?|caixas?|unidades?|pe[cç]as?|metros?|m[23²³]?)(?![a-zA-ZÀ-ÿ0-9]))?'
      // "2 sacos e meio de cimento" — meia unidade depois da unidade
      r'((?:\s+e\s+mei[oa])?)\s*'
      r'(?:de\s+)?'
      r'([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ ]{2,30})',
      caseSensitive: false);

  /// "meio saco de cimento", "meia lata de tinta" — quantidade sem número.
  static final RegExp _regexMeio = RegExp(
      r'\bmei[oa]\s+'
      r'(saco|lata|barra|pacote|caixa|metro|quilo|litro|balde|pe[cç]a)s?\s*'
      r'(?:de\s+)?'
      r'([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ ]{2,30})',
      caseSensitive: false);

  /// Palavras de dinheiro no lugar do material ("300 reais de cimento"
  /// é valor, não 300 unidades de cimento).
  static final RegExp _comecaComMoeda = RegExp(
      r'^(reais|real|conto|pila|centavo|mango|prata)',
      caseSensitive: false);

  /// Palavras onde o nome do material termina ("...cimento POR 350 reais").
  static final RegExp _corteNome = RegExp(
      r'\s+(por|no|na|nos|nas|do|da|dos|das|para|pra|com|reais|real|r\$|que|'
      r'ontem|hoje|anteontem|custou|saiu|deu|foi|ficou|e)\b.*$',
      caseSensitive: false);

  /// Interpreta texto livre (fala ou descrição digitada).
  static List<ItemMaterialModel> deTexto(String textoBruto) {
    // "dez sacos de cimento" → "10 sacos de cimento"
    final texto = NumeroExtenso.normalizar(textoBruto);
    final itens = <ItemMaterialModel>[];

    for (final m in _regexTexto.allMatches(texto)) {
      var quantidade = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
      // "e meio" antes ou depois da unidade soma 0,5
      if ((m.group(2)?.isNotEmpty ?? false) ||
          (m.group(4)?.isNotEmpty ?? false)) {
        quantidade += 0.5;
      }
      final item = _montarItem(
        quantidade: quantidade,
        unidadeBruta: m.group(3)?.toLowerCase(),
        nomeCru: m.group(5)!,
      );
      if (item != null) itens.add(item);
    }

    for (final m in _regexMeio.allMatches(texto)) {
      final item = _montarItem(
        quantidade: 0.5,
        unidadeBruta: m.group(1)!.toLowerCase(),
        nomeCru: m.group(2)!,
      );
      if (item != null) itens.add(item);
    }
    return _semDuplicados(itens);
  }

  static ItemMaterialModel? _montarItem({
    required double quantidade,
    required String? unidadeBruta,
    required String nomeCru,
  }) {
    if (quantidade <= 0 || quantidade > 100000) return null;
    // "300 reais de cimento" é dinheiro, não quantidade de material
    if (_comecaComMoeda.hasMatch(nomeCru.trim())) return null;

    final nome = nomeCru.trim().replaceFirst(_corteNome, '').trim();
    if (nome.length < 3) return null;

    final canonico = _materialCanonico(nome);
    // Sem unidade explícita, só aceita se reconhecer o material —
    // evita transformar "350 reais" em item de estoque.
    if (unidadeBruta == null && canonico == null) return null;

    return ItemMaterialModel(
      material: canonico ?? _capitalizar(nome),
      quantidade: quantidade,
      unidade: _unidades[unidadeBruta] ?? 'un',
    );
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
      if (soQtd != null && i > 0 && !_linhaDeFechamento.hasMatch(linhas[i - 1])) {
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
