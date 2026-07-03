import '../../constants/app_constants.dart';
import '../../models/item_material_model.dart';

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

  /// Apelidos comuns → material canônico do app.
  static const Map<String, String> _apelidos = {
    'ferro': 'Vergalhão de aço',
    'vergalhao': 'Vergalhão de aço',
    'vergalhão': 'Vergalhão de aço',
    'ceramica': 'Piso cerâmico',
    'cerâmica': 'Piso cerâmico',
    'massa': 'Argamassa',
    'bloco': 'Bloco de concreto',
    'blocos': 'Bloco de concreto',
    'fio': 'Fio elétrico',
    'fios': 'Fio elétrico',
    'cabo': 'Fio elétrico',
    'cano': 'Cano PVC',
    'canos': 'Cano PVC',
    'pvc': 'Cano PVC',
  };

  static final RegExp _regexTexto = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*'
      // unidade precisa terminar em fronteira ("3 madeiras" não é "3 m")
      r'(?:(sacos?|sc|kg|quilos?|kilos?|litros?|latas?|barras?|pacotes?|caixas?|unidades?|pe[cç]as?|metros?|m[23²³]?)(?![a-zA-ZÀ-ÿ0-9]))?\s*'
      r'(?:de\s+)?'
      r'([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ ]{2,30})',
      caseSensitive: false);

  /// Palavras onde o nome do material termina ("...cimento POR 350 reais").
  static final RegExp _corteNome = RegExp(
      r'\s+(por|no|na|nos|nas|do|da|dos|das|para|pra|com|reais|real|r\$)\b.*$',
      caseSensitive: false);

  /// Interpreta texto livre (fala ou descrição digitada).
  static List<ItemMaterialModel> deTexto(String texto) {
    final itens = <ItemMaterialModel>[];
    for (final m in _regexTexto.allMatches(texto)) {
      final quantidade =
          double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
      if (quantidade <= 0 || quantidade > 100000) continue;

      final unidadeBruta = m.group(2)?.toLowerCase();
      final nomeBruto =
          m.group(3)!.replaceFirst(_corteNome, '').trim();
      if (nomeBruto.length < 3) continue;

      final canonico = _materialCanonico(nomeBruto);
      // Sem unidade explícita, só aceita se reconhecer o material —
      // evita transformar "350 reais" em item de estoque.
      if (unidadeBruta == null && canonico == null) continue;

      itens.add(ItemMaterialModel(
        material: canonico ?? _capitalizar(nomeBruto),
        quantidade: quantidade,
        unidade: _unidades[unidadeBruta] ?? 'un',
      ));
    }
    return _semDuplicados(itens);
  }

  /// Linha de item típica de cupom/nota: "10 SC CIMENTO CP-II 32,50 325,00".
  static final RegExp _regexLinhaNota = RegExp(
      r'^\s*(?:\d{1,3}\s+)?(\d+(?:[.,]\d+)?)\s*(SC|UN|KG|LT|BR|PC|CX|MT|M2|M3|M|L)\b[\s.:x-]*(.+?)\s+\d+[.,]\d{2}\b',
      caseSensitive: false);

  /// Interpreta o texto cru do OCR da nota, linha a linha.
  static List<ItemMaterialModel> deNotaOcr(String textoOcr) {
    final itens = <ItemMaterialModel>[];
    for (final linha in textoOcr.split('\n')) {
      final m = _regexLinhaNota.firstMatch(linha.trim());
      if (m == null) continue;
      final quantidade =
          double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
      if (quantidade <= 0 || quantidade > 100000) continue;

      var nome = m.group(3)!.trim();
      // remove códigos de produto no começo ("7891234 CIMENTO...")
      nome = nome.replaceFirst(RegExp(r'^[\d\W]+'), '').trim();
      if (nome.length < 3) continue;

      final canonico = _materialCanonico(nome);
      itens.add(ItemMaterialModel(
        material: canonico ?? _capitalizar(nome),
        quantidade: quantidade,
        unidade: _unidades[m.group(2)!.toLowerCase()] ?? 'un',
      ));
    }
    return _semDuplicados(itens);
  }

  /// Procura o material canônico do app dentro do nome lido.
  static String? _materialCanonico(String nome) {
    final lower = nome.toLowerCase();
    for (final entrada in _apelidos.entries) {
      if (lower.contains(entrada.key)) return entrada.value;
    }
    for (final material in AppConstants.materiaisComuns) {
      final primeiraPalavra = material.split(' ').first.toLowerCase();
      if (primeiraPalavra.length >= 4 && lower.contains(primeiraPalavra)) {
        return material;
      }
    }
    return null;
  }

  static List<ItemMaterialModel> _semDuplicados(
      List<ItemMaterialModel> itens) {
    final vistos = <String>{};
    return itens
        .where((i) => vistos.add(i.material.toLowerCase()))
        .toList();
  }

  static String _capitalizar(String s) {
    final limpo = s.trim().toLowerCase();
    return limpo[0].toUpperCase() + limpo.substring(1);
  }
}
