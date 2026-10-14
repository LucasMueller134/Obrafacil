import 'texto_br.dart';

/// Corrige o ruído do reconhecedor de voz no vocabulário de obra.
///
/// Com betoneira ligada e martelete batendo, o reconhecedor parte a palavra
/// de obra em duas que ele conhece ("verga lhão", "contra piso") ou troca
/// por uma que soa igual ("cesta feira", "semento"). Os parsers procuram
/// "vergalhão", "contrapiso", "sexta-feira" — sem esta correção o resto da
/// IA nem chega a ver o termo.
///
/// É conservador de propósito, porque corrigir errado é pior que não
/// corrigir: o usuário não percebe que "serpente" virou "servente".
/// - trocas explícitas, listadas uma a uma;
/// - junção de duas palavras só quando juntas formam exatamente um termo
///   de obra e nenhuma delas é palavra de ligação ("telha do" fica);
/// - correção aproximada só para palavras longas, a uma letra de distância
///   de um único termo de obra, com a mesma inicial, e nunca quando a
///   diferença é só a terminação (pedreira, telhada, estrutural são
///   palavras de verdade) nem em palavras comuns conhecidas.
abstract class VocabularioObra {
  /// Trocas explícitas, comparadas sem acento e por palavra inteira.
  /// Cada uma é um erro de reconhecimento que não tem como ser deduzido
  /// pelas regras gerais (a palavra ouvida existe, ou a inicial muda).
  static const Map<String, String> _trocas = {
    // junções com palavras que existem sozinhas
    'balde drame': 'baldrame',
    'balde drames': 'baldrames',
    'chapa isco': 'chapisco',
    'verga leao': 'vergalhão',
    'verga leoes': 'vergalhões',
    'em boco': 'emboço',
    'para fuso': 'parafuso',
    'para fusos': 'parafusos',
    'tubo lacao': 'tubulação',
    'beto neira': 'betoneira',
    'porcela nato': 'porcelanato',
    'dry wall': 'drywall',
    'drai wall': 'drywall',
    'caixa dagua': "caixa d'água",
    'caixa d agua': "caixa d'água",
    'caixa da agua': "caixa d'água",
    // homófonos (a inicial muda, a regra aproximada não pega)
    'semento': 'cimento',
    'sementos': 'cimentos',
    'simento': 'cimento',
    'valdrame': 'baldrame',
    'xapisco': 'chapisco',
    'hadie': 'radier',
    'radie': 'radier',
    'draiwol': 'drywall',
    // dias da semana
    'cesta feira': 'sexta-feira',
    'cesta-feira': 'sexta-feira',
    'sesta feira': 'sexta-feira',
    'sesta-feira': 'sexta-feira',
    'sexta feira': 'sexta-feira',
  };

  /// "sem reais" só pode ser "cem reais"; "sento e vinte", "cento e vinte".
  static final RegExp _semCem =
      RegExp(r'(?<![a-z0-9])sem(?=\s+(?:reais|real|contos?|pilas?|mangos?)\b)');
  static final RegExp _sentoCento = RegExp(
      r'(?<![a-z0-9])sento(?=\s+e\s+(?:\d|um\b|uma\b|dois\b|duas\b|tres\b|'
      r'quatro\b|cinco\b|seis\b|sete\b|oito\b|nove\b|dez\b|onze\b|doze\b|'
      r'treze\b|quatorze\b|catorze\b|quinze\b|dezesseis\b|dezessete\b|'
      r'dezoito\b|dezenove\b|vinte\b|trinta\b|quarenta\b|cinquenta\b|'
      r'sessenta\b|setenta\b|oitenta\b|noventa\b))');

  /// Termos de obra que as correções podem produzir (forma com acento).
  /// Junção aceita a partir de 6 letras; a correção aproximada, só a
  /// partir de 7 — palavra curta tem vizinhas demais.
  static const List<String> _vocabulario = [
    'alicerce',
    'alvenaria',
    'andaime',
    'argamassa',
    'assentamento',
    'azulejista',
    'azulejo',
    'baldrame',
    'betoneira',
    'britadeira',
    'caçamba',
    'carpinteiro',
    'cerâmica',
    'chapisco',
    'cimento',
    'compactador',
    'concretagem',
    'concreto',
    'conduíte',
    'contramarco',
    'contrapiso',
    'contraverga',
    'cumeeira',
    'disjuntor',
    'drywall',
    'eletricista',
    'eletroduto',
    'emboço',
    'empreiteiro',
    'encanador',
    'encanamento',
    'escavação',
    'escoramento',
    'esmerilhadeira',
    'esquadria',
    'ferragem',
    'fundação',
    'furadeira',
    'gesseiro',
    'grafiato',
    'hidráulica',
    'impermeabilização',
    'impermeabilizante',
    'interruptor',
    'lixadeira',
    'madeiramento',
    'madeireira',
    'madeirite',
    'marceneiro',
    'martelete',
    'parafuso',
    'pedreiro',
    'pedrisco',
    'policorte',
    'pontalete',
    'porcelanato',
    'radier',
    'reboco',
    'rejuntamento',
    'rejunte',
    'retroescavadeira',
    'revestimento',
    'rodapé',
    'sapata',
    'servente',
    'serralheiro',
    'telhado',
    'terraplanagem',
    'terraplenagem', // as duas grafias valem: nenhuma "corrige" a outra
    'textura',
    'tubulação',
    'vergalhão',
  ];

  /// Palavras comuns a uma letra de um termo de obra, no meio da palavra
  /// (a regra da terminação não as protege). Nunca são corrigidas.
  static const Set<String> _protegidas = {
    'serpente',
    'serpentes',
    'concerto',
    'concertos',
    'talhado',
    'talhados',
    'talhada',
    'cacimba',
    'cacimbas',
    'botoneira',
    'botoneiras',
    'encantador',
    'encantadores',
    'encantadora',
    'encantamento',
    'esquadra',
    'esquadras',
    'pintora',
    'pintoras',
    'ferrugem',
    'solteira',
    'semente',
    'sementes',
    'ciumento',
    'ciumentos',
    'comento',
    'forragem',
    'forragens',
    'ferrugens',
    'assentimento',
    'assentimentos',
  };

  /// Palavras de ligação: nunca entram numa junção ("telha do" não é
  /// "telhado", "a reia" não é "areia").
  static const Set<String> _ligacao = {
    'a',
    'o',
    'as',
    'os',
    'um',
    'uma',
    'de',
    'do',
    'da',
    'dos',
    'das',
    'no',
    'na',
    'nos',
    'nas',
    'em',
    'e',
    'ou',
    'que',
    'se',
    'por',
    'pra',
    'pro',
    'para',
    'com',
    'sem',
    'ao',
    'aos',
    'mais',
    'meu',
    'minha',
    'seu',
    'sua',
    'ele',
    'ela',
    'eu',
    'ta',
    'to',
    'la',
    'ai',
    'ja',
    'so',
  };

  /// Termos de obra para a contagem de [contarTermos] — inclui os curtos,
  /// que não entram nas correções mas mostram que a frase é de obra.
  static const List<String> _termosCurtos = [
    'areia',
    'brita',
    'tijolo',
    'bloco',
    'telha',
    'tinta',
    'cal',
    'gesso',
    'piso',
    'cano',
    'fio',
    'prego',
    'arame',
    'massa',
    'laje',
    'viga',
    'pilar',
    'estaca',
    'vala',
    'muro',
    'parede',
    'porta',
    'janela',
    'forro',
    'calha',
    'reboco',
    'saco',
    'lata',
    'barra',
    'metro',
    'diaria',
    'ajudante',
    'pintor',
    'pintura',
    'obra',
    'frete',
    'escora',
    'madeira',
    'ferro',
    'ripa',
    'caibro',
    'demao',
    'selador',
    'registro',
    'tomada',
    'pedra',
    'cobertura',
    'estrutura',
    'material',
  ];

  static final Map<String, String> _formas = _montarFormas();

  static final Set<String> _termosObra = {
    ..._formas.keys,
    for (final t in _termosCurtos) ...[t, '${t}s'],
  };

  static final RegExp _palavra = RegExp(r"[a-z0-9à-ÿ]+(?:['’][a-z]+)?");

  // ------------------------------------------------------------- API

  /// O [texto] com o vocabulário de obra corrigido. Pontuação, números e
  /// tudo o que não é ruído conhecido ficam exatamente como vieram.
  static String corrigir(String texto) {
    if (texto.trim().isEmpty) return texto;
    var t = _aplicarTrocas(texto);
    t = _juntarPartidas(t);
    return _aproximar(t);
  }

  /// Quantas palavras de obra o [texto] tem — sinal de que a hipótese do
  /// reconhecedor ouviu a frase certa, e não uma parecida.
  static int contarTermos(String texto) {
    final normalizado = TextoBr.normalizar(corrigir(texto));
    var n = 0;
    for (final m in _palavra.allMatches(normalizado)) {
      if (_termosObra.contains(m.group(0))) n++;
    }
    return n;
  }

  // ------------------------------------------------------ Estratégias

  static String _aplicarTrocas(String texto) {
    final normalizado = TextoBr.normalizar(texto);
    // A normalização troca letra por letra: as posições valem no original.
    if (normalizado.length != texto.length) return texto;

    final trocas = <(int, int, String)>[];
    void anotar(int inicio, int fim, String por) {
      for (final t in trocas) {
        if (inicio < t.$2 && fim > t.$1) return;
      }
      trocas.add((inicio, fim, por));
    }

    // As frases mais longas primeiro: "cesta feira" antes de "cesta".
    final chaves = _trocas.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final chave in chaves) {
      final padrao = RegExp('(?<![a-z0-9])'
          '${RegExp.escape(chave).replaceAll(' ', r'\s+')}'
          '(?![a-z0-9])');
      for (final m in padrao.allMatches(normalizado)) {
        anotar(m.start, m.end, _trocas[chave]!);
      }
    }
    for (final m in _semCem.allMatches(normalizado)) {
      anotar(m.start, m.end, 'cem');
    }
    for (final m in _sentoCento.allMatches(normalizado)) {
      anotar(m.start, m.end, 'cento');
    }
    return _substituir(texto, trocas);
  }

  /// "contra piso" → "contrapiso", "eletro dutos" → "eletrodutos".
  static String _juntarPartidas(String texto) {
    final normalizado = TextoBr.normalizar(texto);
    if (normalizado.length != texto.length) return texto;

    final palavras = _palavra.allMatches(normalizado).toList();
    final trocas = <(int, int, String)>[];
    for (var i = 0; i + 1 < palavras.length; i++) {
      final a = palavras[i];
      final b = palavras[i + 1];
      // Só espaço entre as duas: vírgula ou ponto separam de verdade.
      if (normalizado.substring(a.end, b.start) != ' ') continue;
      final pa = a.group(0)!;
      final pb = b.group(0)!;
      if (pa.length < 2 || pb.length < 2) continue;
      if (_ligacao.contains(pa) || _ligacao.contains(pb)) continue;
      // Duas palavras de obra lado a lado já estão certas.
      if (_formas.containsKey(pa) || _formas.containsKey(pb)) continue;
      final junto = '$pa$pb';
      final forma = _formas[junto];
      if (forma == null || junto.length < 6) continue;
      trocas.add((a.start, b.end, forma));
      i++; // a segunda palavra já foi usada
    }
    return _substituir(texto, trocas);
  }

  /// "baudrame" → "baldrame", "cumieira" → "cumeeira".
  static String _aproximar(String texto) {
    final normalizado = TextoBr.normalizar(texto);
    if (normalizado.length != texto.length) return texto;

    final trocas = <(int, int, String)>[];
    for (final m in _palavra.allMatches(normalizado)) {
      final palavra = m.group(0)!;
      if (palavra.length < 7 || !RegExp(r'^[a-z]+$').hasMatch(palavra)) {
        continue;
      }
      if (_formas.containsKey(palavra) || _protegidas.contains(palavra)) {
        continue;
      }
      // Maiúscula no meio da frase é nome próprio (fornecedor, pessoa).
      final inicial = texto[m.start];
      if (m.start > 0 && inicial != inicial.toLowerCase()) continue;

      String? escolhida;
      var empate = false;
      for (final entrada in _formas.entries) {
        final forma = entrada.key;
        if (forma.length < 7 || forma[0] != palavra[0]) continue;
        if ((forma.length - palavra.length).abs() > 1) continue;
        if (_soTerminacao(palavra, forma)) continue;
        if (_distancia(palavra, forma) != 1) continue;
        if (escolhida != null && escolhida != entrada.value) empate = true;
        escolhida = entrada.value;
      }
      if (escolhida == null || empate) continue;
      trocas.add((m.start, m.end, escolhida));
    }
    return _substituir(texto, trocas);
  }

  // ------------------------------------------------------------ Apoio

  /// A diferença é só a terminação: uma palavra é começo da outra
  /// (cimento/cimentou, estrutura/estrutural) ou só a última letra muda
  /// (pedreira/pedreiro). É flexão ou outra palavra — não ruído.
  static bool _soTerminacao(String a, String b) {
    if (a.startsWith(b) || b.startsWith(a)) return true;
    if (a.length != b.length) return false;
    return a.substring(0, a.length - 1) == b.substring(0, b.length - 1);
  }

  /// Distância de edição com transposição de letras vizinhas (o erro mais
  /// comum de quem digita e de quem reconhece fala).
  static int _distancia(String a, String b) {
    final n = a.length;
    final m = b.length;
    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= m; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final custo = a[i - 1] == b[j - 1] ? 0 : 1;
        var v = d[i - 1][j] + 1;
        if (d[i][j - 1] + 1 < v) v = d[i][j - 1] + 1;
        if (d[i - 1][j - 1] + custo < v) v = d[i - 1][j - 1] + custo;
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1] &&
            d[i - 2][j - 2] + 1 < v) {
          v = d[i - 2][j - 2] + 1;
        }
        d[i][j] = v;
      }
    }
    return d[n][m];
  }

  /// Aplica as trocas da direita para a esquerda (as posições continuam
  /// válidas) e mantém a maiúscula inicial de quem foi trocado.
  static String _substituir(String texto, List<(int, int, String)> trocas) {
    if (trocas.isEmpty) return texto;
    trocas.sort((a, b) => b.$1.compareTo(a.$1));
    var t = texto;
    for (final (inicio, fim, por) in trocas) {
      final original = t.substring(inicio, fim);
      final maiuscula =
          original.isNotEmpty && original[0] != original[0].toLowerCase();
      final novo = maiuscula ? por[0].toUpperCase() + por.substring(1) : por;
      t = t.replaceRange(inicio, fim, novo);
    }
    return t;
  }

  /// Forma sem acento → forma escrita, no singular e no plural.
  static Map<String, String> _montarFormas() {
    final formas = <String, String>{};
    for (final termo in _vocabulario) {
      formas[TextoBr.normalizar(termo)] = termo;
      final plural = _plural(termo);
      formas[TextoBr.normalizar(plural)] = plural;
    }
    return formas;
  }

  static String _plural(String termo) {
    if (termo.endsWith('ão')) {
      return '${termo.substring(0, termo.length - 2)}ões';
    }
    if (RegExp(r'[rz]$').hasMatch(termo)) return '${termo}es';
    if (termo.endsWith('l')) {
      return '${termo.substring(0, termo.length - 1)}is';
    }
    if (termo.endsWith('m')) {
      return '${termo.substring(0, termo.length - 1)}ns';
    }
    return '${termo}s';
  }
}
