import 'data_falada.dart';
import 'itens_parser.dart';
import 'texto_br.dart';

/// O valor de um lançamento falado e onde ele foi dito na frase.
///
/// Quem fala no canteiro quase nunca diz "reais": "paguei o pedreiro 250",
/// "deu 45 no cimento", "...na casa do construtor 520". E a mesma frase
/// tem números que não são dinheiro: "10 sacos", "3 pedreiros", "2 dias",
/// "ferro de 8", "rua 15", "dia 5". Cada número é classificado pelo
/// contexto em volta:
/// 1. dinheiro com certeza: "R$", "reais", "conto";
/// 2. não é dinheiro: seguido de unidade, material, pessoa, tempo ou
///    medida; precedido de "dia", "rua", "número"; bitola ("cano de 100");
/// 3. dinheiro pelo contexto: logo depois de verbo de preço ou pagamento
///    ("paguei", "cobrou", "deixou por"), de "por", com marca de preço
///    unitário ("cada", "o saco"), ou solto no fim da frase;
/// 4. parcela: número sem contexto ligado por "e"/vírgula a um valor já
///    reconhecido ("o pedreiro 250 e o ajudante 150").
/// Na dúvida o número fica de fora — valor vazio o usuário vê e preenche;
/// valor errado ele pode nem perceber.
class ValorFalado {
  /// O valor do lançamento, ou null se nenhum número era dinheiro.
  final double? valor;

  /// Trechos da frase que são o valor — saem da descrição.
  final List<(int, int)> trechos;

  /// Início dos números que eram dinheiro. Um deles pode ter parecido
  /// quantidade ("gastei 300 de cimento"): esse item não vai ao estoque.
  final Set<int> inicios;

  const ValorFalado(this.valor, this.trechos, this.inicios);

  // ------------------------------------------------------- Vocabulário

  /// Número em pt-BR: "350", "1.200", "1.234,56", "89,90", "2.5". Não
  /// pega pedaço de data ("05/07"), de medida ("10x20") nem de "m3".
  static final RegExp _numero = RegExp(
      r'(?<![\w/.,])(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)'
      r'(?![\w/]|[.,]\d)');

  static final RegExp _moedaDepois =
      RegExp(r'^\s*(?:reais|real|contos?|pilas?|mangos?|pratas?|paus?)\b'
          r'(?:\s*e\s*(\d{1,2})\s*centavos?)?');
  static final RegExp _moedaAntes = RegExp(r'r\$\s*$');

  static const String _unidades =
      r'sacos?|sc|kg|quilos?|kilos?|gramas?|toneladas?|litros?|l|latas?|'
      r'gal(?:ao|oes)|barras?|br|pacotes?|caixas?|cx|unidades?|un|pecas?|'
      r'metros?|mt|m|m2|m3|m²|m³|rolos?|baldes?|carrinhos?|carradas?|'
      r'caminh(?:ao|oes)|feixes?|fardos?|folhas?|chapas?|placas?|bobinas?|'
      r'milheiros?|duzias?|pares?|kits?|jogos?';

  /// Tempo e serviço contado: "2 dias", "3 diárias", "8 horas".
  static const String _tempo =
      r'dias?|diarias?|horas?|h|hs|minutos?|min|semanas?|meses|mes|anos?|'
      r'vezes|vez|parcelas?|prestac(?:ao|oes)|turnos?|noites?|manhas?|'
      r'tardes?|viagens?|cargas?|da\s+(?:manha|tarde|noite)';

  static const String _pessoas =
      r'pessoas?|pedreiros?|serventes?|ajudantes?|funcionarios?|homens|'
      r'homem|caras?|profissionais|profissional|trabalhadores?|oficiais|'
      r'oficial|eletricistas?|encanador(?:es)?|pintor(?:es)?|carpinteiros?|'
      r'gesseiros?|azulejistas?|armador(?:es)?|soldador(?:es)?|marceneiros?|'
      r'mestres?|peoes|peao|meninos?|rapazes|rapaz|colaborador(?:es)?|'
      r'serralheiros?|operarios?';

  /// Contagem de gente vem no plural ("3 pedreiros"); no singular só com
  /// um ("1 servente"). "pedreiro 150 servente 100" é preço de cada um.
  static const String _pessoasNoPlural =
      r'pessoas|pedreiros|serventes|ajudantes|funcionarios|homens|caras|'
      r'profissionais|trabalhadores|oficiais|eletricistas|encanadores|'
      r'pintores|carpinteiros|gesseiros|azulejistas|armadores|soldadores|'
      r'marceneiros|mestres|peoes|meninos|rapazes|colaboradores|'
      r'serralheiros|operarios';

  static const String _medidas =
      r'mm|cm|milimetros?|centimetros?|polegadas?|pol|graus?|watts?|volts?|'
      r'amperes?|kw|kva|cv|hp|mpa|furos?|andares|andar|pavimentos?|'
      r'comodos?|quartos?|banheiros?|pontos?|vaos?|lados?|paredes?|'
      r'por\s+cento';

  static final RegExp _naoDinheiroDepois = RegExp('^\\s*(?:e\\s+mei[oa]\\s+)?'
      '(?:$_unidades|$_tempo|$_pessoasNoPlural|$_medidas)'
      r'(?![\w²³])|^\s*%');
  static final RegExp _umaPessoaDepois = RegExp('^\\s*(?:$_pessoas)\\b');

  /// Palavra no plural logo depois do número: algo contado ("3 vasos",
  /// "500 tijolos"). Conectores que terminam em "s" não contam.
  static final RegExp _pluralDepois = RegExp(r'^\s+([a-z]+s)\b');
  static const Set<String> _conectoresEmS = {
    'mas',
    'mais',
    'pois',
    'depois',
    'os',
    'as',
    'dos',
    'das',
    'nos',
    'nas',
    'aos',
    'pros',
    'pras',
    'pelos',
    'pelas',
    'apos',
    'antes',
    'menos',
    'meus',
    'seus',
    'nossos',
    'todos',
    'todas',
    'tres',
    'reais',
    'contos',
    'pilas',
    'mangos',
    'pratas',
    'paus',
  };

  static final RegExp _tempoDepois =
      RegExp(r'^\s*(dias?|diarias?|horas?|semanas?|meses|mes|viagens?|cargas?|'
          r'vezes|parcelas?)\b');
  static final RegExp _pessoaDepois = RegExp('^\\s*(?:$_pessoas)\\b');
  static final RegExp _unidadeDepois =
      RegExp('^\\s*(?:e\\s+mei[oa]\\s+)?($_unidades)(?![\\w²³])');

  /// Endereço, número de documento, data e hora antes do número.
  static final RegExp _naoDinheiroAntes = RegExp(
      r'(?:^|[^\w])(rua|avenida|av|travessa|alameda|rodovia|estrada|br|km|'
      r'numero|n[o°º]|lote|quadra|apto|apartamento|sala|cep|telefone|fone|'
      r'celular|whatsapp|zap|placa|andar|nota|nf|pedido|cupom|modelo|'
      r'versao|cp|tamanho|dia|as|das|parcela|etapa|medicao|fase)\.?\s*$');

  static final RegExp _anoAntes = RegExp(
      r'(?:janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|'
      r'outubro|novembro|dezembro)\s+de\s*$');

  /// Material que tem bitola ou tamanho: "ferro de 8", "cano de 100",
  /// "porta de 80" falam da medida, não do preço.
  static const String _materiaisComMedida =
      r'ferros?|vergalh(?:ao|oes)|acos?|canos?|tubos?|fios?|cabos?|'
      r'eletrodutos?|conduites?|mangueiras?|pregos?|parafusos?|brocas?|'
      r'discos?|portas?|janelas?|blocos?|tijolos?|telhas?|tabuas?|vigas?|'
      r'caibros?|ripas?|sarrafos?|chapas?|pisos?|porcelanatos?|azulejos?|'
      r'ceramicas?|lampadas?|registros?|joelhos?|luvas?|curvas?|caixas?|'
      r'sacos?|latas?|baldes?|barras?|telas?|malhas?|arames?|bitolas?|'
      r'buchas?|tomadas?|disjuntor(?:es)?';
  static final RegExp _medidaDoMaterial =
      RegExp('(?:^|[^\\w])(?:$_materiaisComMedida)\\s+de\\s*\$');

  /// Sem o "de" ("ferro 8", "cano 100") só é bitola quando o número é
  /// uma bitola comercial — "o ferro 450" continua sendo preço.
  /// Prego fica de fora: a medida dele é dita "18 por 27", e "pregos 25"
  /// é o preço.
  static final RegExp _materialComBitola = RegExp(
      r'(?:^|[^\w])(?:ferros?|vergalh(?:ao|oes)|acos?|canos?|tubos?|fios?|'
      r'cabos?|eletrodutos?|parafusos?|brocas?)\s*$');

  /// Bitolas comerciais: ferro (mm), cano e eletroduto (mm), fio (mm²).
  static final Set<double> _bitolas = {
    1.5, 2.5, 4, 4.2, 5, 6, 6.3, 8, 10, 12, 12.5, 16, 20, 25,
    // ferro, fio
    32, 35, 40, 50, 60, 75, 85, 100, 150,
    // cano, eletroduto
  };

  /// Verbo de preço ou de pagamento logo antes do número, com as
  /// palavrinhas que cabem entre eles ("paguei uns 300", "ficou em 89",
  /// "deixou por 1.200", "no valor de 1200").
  static const String _verbosDePreco =
      r'paguei|pagamos|pagou|pagaram|pago|paga|pagar|pagando|gastei|'
      r'gastamos|gastou|gastaram|gasto|gastar|gastando|dei|demos|deu|deram|'
      r'dando|cobrou|cobraram|cobra|cobram|cobrei|cobrando|cobrar|custou|'
      r'custaram|custa|custam|custando|custar|saiu|sairam|sai|saem|saindo|'
      r'ficou|ficaram|fica|ficam|ficando|fechou|fechamos|fechei|fechado|'
      r'fechando|foi|foram|vale|valeu|valia|totalizou|totalizando|somou|'
      r'somando|deixou|deixaram|deixa|fez|fizeram|faz|baixou|abaixou|'
      r'baixaram|desembolsei|investi|acertei|acertamos|acertou|torrei|'
      r'(?:no\s+)?valor|total|preco|era|eram';
  static const String _entreVerboENumero =
      r'(?:\s+(?:em|por|a|de|o|uns|umas|mais|so|apenas|cerca|quase|tipo|'
      r'no|total|ao|todo|tudo|pra|pro|para|ele|ela|eles|me|la|ai|isso|'
      r'r\$))*';
  static final RegExp _verboAntes = RegExp(
      '(?:^|[^\\w])((?:$_verbosDePreco)$_entreVerboENumero)\\s*(?:r\\\$\\s*)?\$');

  /// Verbos que, sozinhos, já põem dinheiro na frase — e por isso aceitam
  /// quem recebeu entre eles e o número ("paguei o pedreiro 250").
  static const Set<String> _verbosDePagamento = {
    'paguei',
    'pagamos',
    'pagou',
    'pagaram',
    'dei',
    'demos',
    'gastei',
    'gastamos',
    'gastou',
    'gastaram',
    'cobrou',
    'cobraram',
    'cobrei',
    'acertei',
    'acertamos',
    'acertou',
    'custou',
    'custaram',
    'saiu',
    'sairam',
    'ficou',
    'ficaram',
    'deu',
    'deram',
    'foi',
    'foram',
    'desembolsei',
    'investi',
  };

  /// Verbos de compra: "comprei a madeira 300". Só três palavras entre o
  /// verbo e o número, e nunca para número que parece quantidade.
  static const Set<String> _verbosDeCompra = {
    'comprei',
    'compramos',
    'comprou',
    'compraram',
    'peguei',
    'pegamos',
    'pegou',
    'levei',
    'levamos',
    'levou',
    'trouxe',
    'trouxemos',
    'mandei',
    'mandamos',
    'encomendei',
    'aluguei',
    'alugamos',
    'alugou',
    'contratei',
    'contratamos',
    'contratou',
    'fiz',
    'fizemos',
  };

  /// Verbo de quem gasta, para "300 de cimento" virar dinheiro: "gastei
  /// 300 de cimento" é dinheiro, "comprei 10 de cimento" é quantidade.
  static final RegExp _verboDeGastoAntes = RegExp(
      r'(?:^|[^\w])(?:paguei|pagamos|pagou|gastei|gastamos|gastou|dei|demos|'
      r'deu|deram|foi|foram|custou|custaram|saiu|ficou|sairam)'
      r'(?:\s+(?:uns|umas|mais|so|r\$))*\s*$');

  static const Set<String> _artigos = {'o', 'a', 'os', 'as'};

  /// Palavras que não são nome de coisa — numa lista ditada, não separam
  /// um valor do outro.
  static const Set<String> _palavrasDeLigacao = {
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
    'por',
    'pra',
    'pro',
    'para',
    'com',
    'que',
    'se',
    'ao',
    'aos',
    'ou',
    'mas',
    'ja',
    'so',
    'la',
    'ai',
    'aqui',
    'ali',
    'dia',
    'cada',
    'tudo',
    'total',
    'reais',
    'ontem',
    'hoje',
    'depois',
    'antes',
  };

  /// Verbo conjugado pela terminação — o que encerra uma locução.
  static final RegExp _pareceVerbo =
      RegExp(r'^(?:[a-z]{2,}ei|[a-z]{3,}(?:amos|emos|imos|aram|eram|iram)|'
          r'[a-z]{2,}ou)$');

  /// Preço unitário dito depois do número: "35 cada", "35 o saco",
  /// "38,50 a unidade", "150 a diária", "50 por dia".
  static const String _unidadesDePreco =
      r'unidade|peca|saco|lata|barra|metro(?:\s+(?:quadrado|cubico|linear))?|'
      r'm2|m3|quilo|kg|litro|milheiro|cento|duzia|rolo|galao|balde|carrada|'
      r'carrinho|caminhao|feixe|fardo|bobina|'
      r'viagem|carga|tonelada|caixa|pacote|par|diaria|dia|hora|semana|mes|'
      r'tijolo|bloco|telha|tabua|porta|janela|placa|chapa|folha|pessoa';
  static final RegExp _unitarioDepois = RegExp(r'^\s*(?:cada(?:\s+(?:um|uma|'
      '$_unidadesDePreco'
      r'))?\b|'
      r'(?:a|o|por|ao|cada)\s+('
      '$_unidadesDePreco'
      r')\b)');

  /// "cada saco saiu 35", "o saco ficou 35", "a diária do pedreiro 150".
  static final RegExp _unitarioAntes =
      RegExp(r'(?:^|[^\w])(?:cada(?:\s+(?:um|uma))?|(?:o|a)\s+('
          '$_unidadesDePreco'
          r'))\b');

  /// "a 35" depois de uma quantidade: "10 sacos a 35".
  static final RegExp _aAntes = RegExp(r'(?:^|[^\w])a\s+(?:r\$\s*)?$');

  /// "cada um 35", "cada saco 35" — o "cada" colado no número.
  static final RegExp _cadaColadoAntes =
      RegExp(r'(?:^|[^\w])cada\s+(?:(?:um|uma)|('
          '$_unidadesDePreco'
          r'))\s*(?:r\$\s*)?$');

  /// "3 diárias de 150", "2 dias a 200", "3 vezes de 200".
  /// Também com quem trabalhou no meio: "3 diárias do pedreiro de 150",
  /// "2 viagens do caminhão a 300".
  static final RegExp _contagemDeAntes =
      RegExp(r'(\d+(?:[.,]\d+)?)\s+(?:diarias?|dias?|horas?|viagens?|cargas?|'
          r'vezes|parcelas?)\s+(?:d[oa]s?\s+[a-z]+\s+)?'
          r'((?:de|a)\s+(?:r\$\s*)?)$');

  /// "10 sacos de cimento DE 50 kg": o tamanho de cada um, não uma
  /// contagem — não serve de base para "a 35 cada".
  static final RegExp _especificacaoAntes = RegExp(r'(?:^|[^\w])de\s*$');

  static final RegExp _porAntes = RegExp(r'(?:^|[^\w])por\s+(?:r\$\s*)?$');

  /// Marca de que aquele número é o total, e não mais uma parcela.
  static final RegExp _antecedeTotal =
      RegExp(r'(?:^|[^\w])(?:no\s+total|ao\s+todo|total\s+de|deu\s+tudo|tudo|'
          r'fechou(?:\s+em)?|somou|total)\s*(?:de\s+)?(?:r\$\s*)?$');
  static final RegExp _sucedeTotal =
      RegExp(r'^\s*(?:no\s+total|ao\s+todo|de\s+total|total)\b');

  static final RegExp _descontoDepois = RegExp(r'^\s*de\s+desconto\b');
  static final RegExp _descontoAntes =
      RegExp(r'(?:^|[^\w])desconto\s+(?:de\s+)?(?:r\$\s*)?$');

  /// Negociação: o valor dito depois substitui o anterior ("deu 1.230 mas
  /// ele deixou por 1.200").
  static final RegExp _negociacaoAntes = RegExp(
      r'(?:^|[^\w])(?:deixou|deixaram|deixa|fez|fizeram|faz|baixou|abaixou|'
      r'baixaram|fechou|fechamos|fechei|acertou|acertamos|acertei|'
      r'consegui|conseguimos|conseguiu)'
      r'(?:\s+(?:o\s+preco|tudo|pra\s+mim|pra\s+gente))?'
      r'(?:\s+(?:por|em|pra|para|a|de))?\s+(?:r\$\s*)?$');
  static final RegExp _correcao =
      RegExp(r'(?:^|[^\w])(?:quer\s+dizer|ou\s+melhor|na\s+verdade|alias|digo|'
          r'corrigindo|errei|me\s+enganei|nao\s+nao)(?![\w])');
  static final RegExp _contraste =
      RegExp(r'(?:^|[^\w])(?:mas|so\s+que|porem|no\s+final|no\s+fim|acabou|'
          r'desconto|chorei|pechinchei)(?![\w])');
  static final RegExp _resultadoAntes = RegExp(
      r'(?:^|[^\w])(?:ficou|saiu|deu|paguei|pagamos|pagou|foi|fechou|'
      r'custou|sai|fica)(?:\s+(?:em|por|so|tudo|pra\s+mim))*\s*(?:r\$\s*)?$');

  /// Depois do "mas", quem já estava na conversa cobrando de novo: "era
  /// 100 mas ele cobrou só 80", "mas fez por 80". Sem sujeito ou com "ele"
  /// é o mesmo preço renegociado — "mas o ajudante cobrou 150" traz outra
  /// pessoa, e é outro gasto.
  static final RegExp _reducaoAntes = RegExp(
      r'(?:^|[^\w])(?:mas|so\s+que|porem|no\s+final|no\s+fim)\s+'
      r'(?:(?:ele|ela|eles|elas|no\s+fim|no\s+final)\s+)?(?:me\s+|nos\s+)?'
      r'(?:cobrou|cobraram|fez|fizeram|vendeu|venderam)'
      r'(?:\s+(?:por|em|a|so|apenas|somente|tudo|pra\s+mim))*\s*(?:r\$\s*)?$');
  static final RegExp _aditivo =
      RegExp(r'(?:^|[^\w])(?:tambem|alem|mais)(?![\w])');

  /// O que pode sobrar depois do último valor sem que ele deixe de ser
  /// "o número solto no fim da frase".
  static final RegExp _restoDeFim = RegExp(
      r'^(?:\s|[,.;:!?]|(?:ta|ne|ok|certo|beleza|viu|ai|entendeu|blz|hein|'
      r'reais|ontem|hoje|anteontem|tudo|no\s+(?:pix|cartao|debito|credito|'
      r'dinheiro|boleto)|em\s+dinheiro|a\s+vista|parcelado|no\s+total|'
      r'ao\s+todo)(?![\w]))*$');

  // ------------------------------------------------------------- API

  /// Lê o valor do [texto] (já com números em dígitos). [itens] são os
  /// materiais localizados no mesmo texto; [ignorar] são trechos já
  /// entendidos (fornecedor) que não contam ao ver se um número é o
  /// último da frase.
  static ValorFalado extrair(
    String texto, {
    List<ItemNoTexto> itens = const [],
    List<(int, int)> ignorar = const [],
  }) {
    final t = TextoBr.normalizar(texto);
    // As posições valem nos dois textos só se a normalização não mudou o
    // tamanho (troca letra por letra) — é o caso do português.
    if (t.length != texto.length) return const ValorFalado(null, [], {});

    final numeros = _lerNumeros(t, itens);
    if (numeros.isEmpty) return const ValorFalado(null, [], {});

    final contagens = [
      for (final n in numeros)
        if (n.contagem != null) n,
    ];
    final quantidades = <_Quantidade>[
      for (final i in itens)
        _Quantidade(i.inicio, i.item.quantidade, i.item.unidade,
            TextoBr.normalizar(i.item.material),
            falada: _singular(i.unidadeFalada)),
      for (final c in contagens)
        _Quantidade(c.inicio, c.valor, c.contagem!, c.contagem!),
    ];

    for (final n in numeros) {
      if (n.papel == _Papel.naoDinheiro) continue;
      _avaliarContexto(t, n, quantidades, ignorar);
    }
    _propagarParcelas(t, numeros);

    final dinheiro = [
      for (final n in numeros)
        if (n.papel == _Papel.dinheiro) n,
    ];
    if (dinheiro.isEmpty) return const ValorFalado(null, [], {});

    for (final n in dinheiro) {
      _marcarRelacoes(t, n, dinheiro);
    }
    final valor = _total(dinheiro, quantidades, itens);
    return ValorFalado(
      valor,
      _trechos(dinheiro, itens),
      {for (final n in dinheiro) n.inicio},
    );
  }

  // ------------------------------------------------- Classificação

  static List<_Numero> _lerNumeros(String t, List<ItemNoTexto> itens) {
    final numeros = <_Numero>[];
    var consumidoAte = 0;
    for (final m in _numero.allMatches(t)) {
      if (m.start < consumidoAte) continue; // "e 50 centavos" já lido
      final n = _Numero(m.start, m.end, _lerNumeroBr(m.group(1)!));
      final antes = t.substring(0, m.start);
      final depois = t.substring(m.end);

      final moedaAntes = _moedaAntes.firstMatch(antes);
      final moedaDepois = _moedaDepois.firstMatch(depois);
      if (moedaAntes != null || moedaDepois != null) {
        n.papel = _Papel.dinheiro;
        n.forte = true;
        if (moedaAntes != null) n.inicioTrecho = moedaAntes.start;
        if (moedaDepois != null) {
          n.fimTrecho = m.end + moedaDepois.end;
          final centavos = int.tryParse(moedaDepois.group(1) ?? '');
          if (centavos != null) n.valor += centavos / 100;
        }
        consumidoAte = n.fimTrecho;
        numeros.add(n);
        continue;
      }

      ItemNoTexto? item;
      for (final i in itens) {
        if (i.inicio == m.start) item = i;
      }
      if (item != null) {
        n.papel =
            item.quantidadeClara ? _Papel.naoDinheiro : _Papel.quantidadeTalvez;
      } else if (_naoEhDinheiro(antes, depois, n.valor)) {
        n.papel = _Papel.naoDinheiro;
      }
      // Quantidade de tempo ou de gente serve de base para o preço
      // unitário ("3 diárias de 150", "3 pedreiros a 150 cada").
      // Unidade sem material conhecido também ("10 sacos a 35 cada").
      final tempo = _tempoDepois.firstMatch(depois);
      final unidade = _unidadeDepois.firstMatch(depois);
      if (tempo != null) {
        n.contagem = _singularTempo(tempo.group(1)!);
      } else if (_pessoaDepois.hasMatch(depois)) {
        n.contagem = 'pessoa';
      } else if (unidade != null &&
          item == null &&
          !_especificacaoAntes.hasMatch(antes)) {
        n.contagem = _unidadeDoEstoque(unidade.group(1)!);
      }
      numeros.add(n);
    }
    return numeros;
  }

  static bool _naoEhDinheiro(String antes, String depois, double valor) {
    if (_naoDinheiroDepois.hasMatch(depois)) return true;
    if (valor == 1 && _umaPessoaDepois.hasMatch(depois)) return true;
    final plural = _pluralDepois.firstMatch(depois);
    if (plural != null && !_conectoresEmS.contains(plural.group(1))) {
      return true;
    }
    // "1 vaso", "1 porta": um é quase sempre quantidade.
    if (valor == 1 && RegExp(r'^\s+[a-z]{3,}').hasMatch(depois)) {
      final palavra = RegExp(r'^\s+([a-z]+)').firstMatch(depois)!.group(1)!;
      if (!_conectoresEmS.contains(palavra) &&
          !const {'e', 'de', 'no', 'na', 'pro', 'pra', 'ao', 'com', 'por'}
              .contains(palavra)) {
        return true;
      }
    }
    if (RegExp(r'^\s*x\s*\d').hasMatch(depois) ||
        RegExp(r'\dx?\s*x\s*$').hasMatch(antes)) {
      return true; // medida: "10 x 20"
    }

    final antesM = _naoDinheiroAntes.firstMatch(antes);
    if (antesM != null) {
      final palavra = antesM.group(1)!;
      switch (palavra) {
        case 'dia':
          if (valor >= 1 && valor <= 31) return true; // "por dia 150" é preço
        case 'as' || 'das':
          if (valor <= 24) return true; // hora
        case 'parcela' || 'etapa' || 'medicao' || 'fase':
          if (valor < 100) return true; // ordinal
        default:
          return true;
      }
    }
    if (_anoAntes.hasMatch(antes)) return true;
    if (_medidaDoMaterial.hasMatch(antes)) return true;
    if (_materialComBitola.hasMatch(antes) && _bitolas.contains(valor)) {
      return true;
    }
    return false;
  }

  /// Procura no contexto a evidência de que o número é dinheiro.
  ///
  /// Roda também para quem já tem "reais": o preço unitário ("40 reais
  /// cada", "3 diárias de 150 reais") e o "por" do trecho valem para ele.
  static void _avaliarContexto(
    String t,
    _Numero n,
    List<_Quantidade> quantidades,
    List<(int, int)> ignorar,
  ) {
    final antes = t.substring(0, n.inicioTrecho);
    final depois = t.substring(n.fimTrecho);
    final talvez = n.papel == _Papel.quantidadeTalvez;

    // "300 de cimento" só é dinheiro com verbo de gasto logo antes.
    if (talvez) {
      final verbo = _verboDeGastoAntes.firstMatch(antes);
      if (verbo != null) {
        n.papel = _Papel.dinheiro;
        n.inicioTrecho = verbo.start + _espacoInicial(verbo.group(0)!);
      }
      return;
    }

    var evidencia = n.forte;
    final unitario = _unitarioDepois.firstMatch(depois);
    if (unitario != null) {
      evidencia = true;
      n.unidadePreco = unitario.group(1) ?? '';
      n.fimTrecho += unitario.end;
    }

    final contagem = _contagemDeAntes.firstMatch(antes);
    if (contagem != null) {
      evidencia = true;
      n.unidadePreco ??= '';
      n.quantidadeDireta = _lerNumeroBr(contagem.group(1)!);
      n.inicioTrecho = contagem.end - contagem.group(2)!.length;
    }

    final verbo = _verboAntes.firstMatch(antes);
    final por = _porAntes.firstMatch(antes);
    if (verbo != null) {
      evidencia = true;
      n.inicioTrecho = verbo.start + _espacoInicial(verbo.group(0)!);
    } else if (por != null) {
      evidencia = true;
      n.inicioTrecho = por.start + _espacoInicial(por.group(0)!);
    }

    final a = _aAntes.firstMatch(antes);
    if (a != null && quantidades.any((q) => q.inicio < n.inicio)) {
      evidencia = true;
      n.unidadePreco ??= '';
      n.inicioTrecho = a.start + _espacoInicial(a.group(0)!);
    }

    // "10 sacos, cada um 35", "cada saco 35": preço de cada coisa contada
    // é dinheiro, e o "cada" sai da descrição junto com o número.
    final cada = _cadaColadoAntes.firstMatch(antes);
    if (cada != null && quantidades.any((q) => q.inicio < n.inicio)) {
      evidencia = true;
      n.unidadePreco ??= cada.group(1) ?? '';
      n.inicioTrecho = cada.start + _espacoInicial(cada.group(0)!);
    }

    // "30 de desconto", "desconto de 30" (porcentagem já ficou de fora).
    if (_descontoDepois.hasMatch(depois) || _descontoAntes.hasMatch(antes)) {
      evidencia = true;
    }
    if (!evidencia && _verboComQuemRecebeu(antes)) evidencia = true;
    if (!evidencia && _ehUltimo(t, n, ignorar)) evidencia = true;

    if (n.unidadePreco == null) {
      final janela = _janelaAntes(antes);
      final u = _unitarioAntes.firstMatch(janela);
      if (u != null) n.unidadePreco = u.group(1) ?? '';
    }

    if (evidencia) n.papel = _Papel.dinheiro;
  }

  /// "paguei o pedreiro 250", "dei pro eletricista 200", "comprei a
  /// madeira 300": verbo de pagamento (ou de compra) e quem recebeu, sem
  /// outro número nem outro verbo no meio.
  static bool _verboComQuemRecebeu(String antes) {
    final m = RegExp(r'(?:^|[^\w])([a-z]+)((?:\s+[a-z]+){1,5})\s*$')
        .firstMatch(antes);
    if (m == null) return false;
    // Procura o verbo mais próximo dentro da janela, da direita para a
    // esquerda: tudo depois dele é quem recebeu.
    final palavras = '${m.group(1)}${m.group(2)}'.trim().split(RegExp(r'\s+'));
    for (var i = palavras.length - 2; i >= 0; i--) {
      final p = palavras[i];
      final meio = palavras.sublist(i + 1);
      if (meio.any((w) =>
          _pareceVerbo.hasMatch(w) ||
          _verbosDePagamento.contains(w) ||
          _verbosDeCompra.contains(w))) {
        continue;
      }
      if (_verbosDePagamento.contains(p)) return meio.length <= 5;
      if (_verbosDeCompra.contains(p)) return meio.length <= 3;
    }
    return false;
  }

  /// O número é o último da frase — tirando fala de enchimento, data,
  /// forma de pagamento e o fornecedor já entendido.
  static bool _ehUltimo(String t, _Numero n, List<(int, int)> ignorar) {
    var resto = t.substring(n.fimTrecho);
    final base = n.fimTrecho;
    final trechos = [...ignorar]..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (inicio, fim) in trechos) {
      if (fim <= base) continue;
      final i = (inicio - base).clamp(0, resto.length);
      final f = (fim - base).clamp(0, resto.length);
      resto = resto.replaceRange(i, f, ' ');
    }
    for (final padrao in DataFalada.padroesLimpeza) {
      resto = resto.replaceAll(padrao, ' ');
    }
    return _restoDeFim.hasMatch(resto);
  }

  /// As últimas palavras antes do número, até a pontuação ou o número
  /// anterior — onde mora o "cada saco" de "cada saco saiu 35".
  static String _janelaAntes(String antes) {
    final corte = antes.lastIndexOf(RegExp(r'[\d,.;]'));
    final trecho = corte == -1 ? antes : antes.substring(corte + 1);
    final palavras = trecho.trim().split(RegExp(r'\s+'));
    final ultimas =
        palavras.length > 6 ? palavras.sublist(palavras.length - 6) : palavras;
    return ' ${ultimas.join(' ')}';
  }

  /// Número sem contexto ligado por "e", vírgula ou "mais" a um valor já
  /// reconhecido é mais uma parcela: "o pedreiro 250 e o ajudante 150".
  static void _propagarParcelas(String t, List<_Numero> numeros) {
    var mudou = true;
    while (mudou) {
      mudou = false;
      for (var i = 0; i < numeros.length; i++) {
        final n = numeros[i];
        if (n.papel != _Papel.indefinido &&
            n.papel != _Papel.quantidadeTalvez) {
          continue;
        }
        final vizinhos = [
          if (i > 0) (numeros[i - 1], true),
          if (i + 1 < numeros.length) (numeros[i + 1], false),
        ];
        for (final (v, antes) in vizinhos) {
          if (v.papel != _Papel.dinheiro) continue;
          final lacuna = antes
              ? t.substring(v.fimTrecho, n.inicio)
              : t.substring(n.fim, v.inicioTrecho);
          if (!_lacunaDeParcela(lacuna)) continue;
          // "300 de cimento e 150 de areia": a parcela que parece
          // quantidade só entra se repete a forma da anterior.
          if (n.papel == _Papel.quantidadeTalvez &&
              !(antes && RegExp(r'^\s*de\s').hasMatch(lacuna))) {
            continue;
          }
          n.papel = _Papel.dinheiro;
          mudou = true;
          break;
        }
      }
    }
  }

  static bool _lacunaDeParcela(String lacuna) {
    if (RegExp(r'\d').hasMatch(lacuna)) return false;
    final palavras =
        lacuna.split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
    if (!RegExp(r',|\+|(?:^|[^\w])(?:e|mais|tambem)(?![\w])')
        .hasMatch(lacuna)) {
      // Lista ditada sem "e": "cimento 300 areia 150 brita 200" — entre
      // os valores só o nome da próxima coisa (com artigo, no máximo).
      final nomes = palavras.where((w) => !_artigos.contains(w)).toList();
      return nomes.isNotEmpty &&
          nomes.length <= 2 &&
          !nomes.any((w) =>
              _palavrasDeLigacao.contains(w) || _pareceVerbo.hasMatch(w));
    }
    if (palavras.length > 7) return false;
    // Outro verbo no meio começa outra história ("e trabalhou 3").
    for (final w in palavras) {
      if (_pareceVerbo.hasMatch(w) &&
          !_verbosDePagamento.contains(w) &&
          !_verbosDeCompra.contains(w)) {
        return false;
      }
    }
    return !RegExp(r'(?:^|[^\w])(?:cada|por)(?![\w])').hasMatch(lacuna);
  }

  // ------------------------------------------------------ Relações

  static void _marcarRelacoes(String t, _Numero n, List<_Numero> dinheiro) {
    final depois = t.substring(n.fimTrecho);
    final antesDoNumero = t.substring(0, n.inicio);
    if (_antecedeTotal.hasMatch(antesDoNumero) ||
        _sucedeTotal.hasMatch(depois)) {
      n.total = true;
    }
    if (_descontoDepois.hasMatch(depois) ||
        _descontoAntes.hasMatch(antesDoNumero)) {
      n.desconto = true;
    }

    final anterior =
        dinheiro.lastWhere((d) => d.inicio < n.inicio, orElse: () => n);
    if (identical(anterior, n)) return;
    final lacuna = t.substring(anterior.fimTrecho, n.inicio);
    if (_aditivo.hasMatch(lacuna)) return;
    if (_negociacaoAntes.hasMatch(antesDoNumero) ||
        _correcao.hasMatch(lacuna) ||
        (_contraste.hasMatch(lacuna) &&
            (_resultadoAntes.hasMatch(antesDoNumero) ||
                _reducaoAntes.hasMatch(antesDoNumero)))) {
      n.substitui = true;
    }
  }

  // ---------------------------------------------------------- Total

  static double? _total(List<_Numero> dinheiro, List<_Quantidade> quantidades,
      List<ItemNoTexto> itens) {
    // Quantidades que viraram dinheiro não servem de base para "cada".
    final usadas = {for (final n in dinheiro) n.inicio};
    final bases = [
      for (final q in quantidades)
        if (!usadas.contains(q.inicio)) q,
    ];

    var vigentes = <_Numero>[];
    for (final n in dinheiro) {
      n.parcela = n.valor * _quantidadeDoPreco(n, bases);
      // O valor negociado ou corrigido vence o que foi dito antes.
      if (n.substitui) vigentes = [];
      vigentes.add(n);
    }

    final descontos = vigentes.where((n) => n.desconto).toList();
    final parcelas = vigentes.where((n) => !n.desconto).toList();
    if (parcelas.isEmpty) return null;

    double soma;
    final anunciado = parcelas.where((o) => o.total);
    if (anunciado.isNotEmpty) {
      // "…cimento 300 e areia 150, no total 450" — quem foi anunciado
      // como total manda, senão somaríamos o total junto com as parcelas.
      soma = anunciado.last.parcela;
    } else {
      soma = _somaSemTotalRepetido(parcelas);
    }
    final desconto = descontos.fold<double>(0, (s, d) => s + d.parcela);
    if (desconto > 0 && desconto < soma) soma -= desconto;
    return soma > 0 ? (soma * 100).round() / 100 : null;
  }

  /// Um dos valores é a soma dos outros: ele é o total, os demais são as
  /// parcelas detalhadas. Com só dois números seria ambíguo (150 e 150),
  /// então a regra vale a partir de três.
  static double _somaSemTotalRepetido(List<_Numero> parcelas) {
    if (parcelas.length >= 3) {
      for (final o in parcelas) {
        final resto = parcelas
            .where((x) => !identical(x, o))
            .fold<double>(0, (s, x) => s + x.parcela);
        if (resto > 0 && (resto - o.parcela).abs() < 0.01) return o.parcela;
      }
    }
    return parcelas.fold<double>(0, (s, o) => s + o.parcela);
  }

  /// Por quanto o preço unitário multiplica: a quantidade do item (ou da
  /// contagem) a que ele se refere — a mais próxima antes, senão depois.
  static double _quantidadeDoPreco(_Numero n, List<_Quantidade> bases) {
    final unidade = n.unidadePreco;
    if (unidade == null) return 1;
    if (n.quantidadeDireta != null) return n.quantidadeDireta!;

    final alvo = _alvoDaUnidade(unidade);
    final ordenadas = [...bases]..sort((a, b) => a.inicio.compareTo(b.inicio));

    /// A quantidade compatível mais perto: a última antes do preço, senão
    /// a primeira depois.
    _Quantidade? maisPerto(bool Function(_Quantidade) compativel) {
      _Quantidade? escolhida;
      for (final q in ordenadas) {
        if (!compativel(q)) continue;
        if (q.inicio < n.inicio) {
          escolhida = q;
        } else {
          return escolhida ?? q;
        }
      }
      return escolhida;
    }

    if (alvo != null && alvo.$1 == 'tempo') {
      // "2 pedreiros a 150 a diária por 3 dias": tempo de trabalho é pago
      // por dia e por pessoa — conta as duas quando as duas foram ditas.
      // Viagem e carga são do caminhão, não de quem foi junto.
      final tempo = maisPerto((q) => q.unidade == alvo.$2);
      final porPessoa =
          const {'dia', 'hora', 'semana', 'mes'}.contains(alvo.$2);
      final pessoas =
          porPessoa ? maisPerto((q) => q.unidade == 'pessoa') : null;
      return (tempo?.quantidade ?? 1) * (pessoas?.quantidade ?? 1);
    }

    final dita = unidade.replaceAll(RegExp(r'\s+'), ' ');
    final escolhida = maisPerto((q) {
      if (alvo == null) return true; // "cada", "a 35": qualquer uma
      return q.unidade == alvo.$2 ||
          q.material.startsWith(alvo.$2) ||
          q.falada == dita;
    });
    // Sem a quantidade de que o preço fala, contar outra coisa erraria o
    // valor; "a diária" sozinha é uma diária.
    if (escolhida == null) return 1;
    return escolhida.quantidade / (alvo?.$3 ?? 1);
  }

  /// O que a unidade do preço procura: (tipo, unidade, divisor).
  static (String, String, double)? _alvoDaUnidade(String unidade) {
    final u = unidade.replaceAll(RegExp(r'\s+'), ' ');
    return switch (u) {
      '' || 'um' || 'uma' || 'unidade' || 'peca' || 'pessoa' => null,
      'saco' => ('item', 'sc', 1),
      'lata' => ('item', 'lt', 1),
      'barra' => ('item', 'br', 1),
      'metro' || 'metro linear' => ('item', 'm', 1),
      'metro quadrado' || 'm2' => ('item', 'm²', 1),
      'metro cubico' || 'm3' => ('item', 'm³', 1),
      'quilo' || 'kg' => ('item', 'kg', 1),
      'tonelada' => ('item', 'kg', 1000),
      'litro' => ('item', 'L', 1),
      'caixa' || 'pacote' => ('item', 'pc', 1),
      'milheiro' => ('item', 'un', 1000),
      'cento' => ('item', 'un', 100),
      'duzia' => ('item', 'un', 12),
      'diaria' || 'dia' => ('tempo', 'dia', 1),
      'hora' => ('tempo', 'hora', 1),
      'semana' => ('tempo', 'semana', 1),
      'mes' => ('tempo', 'mes', 1),
      'viagem' => ('tempo', 'viagem', 1),
      'carga' => ('tempo', 'carga', 1),
      _ => ('item', u, 1), // material: "o tijolo", "a telha"
    };
  }

  // -------------------------------------------------------- Trechos

  static List<(int, int)> _trechos(
      List<_Numero> dinheiro, List<ItemNoTexto> itens) {
    final trechos = <(int, int)>[
      for (final n in dinheiro) (n.inicioTrecho, n.fimTrecho),
    ];
    // "deu 1.230 mas ele deixou por 1.200": a negociação inteira sai da
    // descrição, desde que não leve um material junto.
    for (var i = 0; i < dinheiro.length; i++) {
      final n = dinheiro[i];
      if (!n.substitui || i == 0) continue;
      final primeiro = dinheiro[i - 1];
      final temItem =
          itens.any((it) => it.inicio < n.inicio && it.fim > primeiro.fim);
      if (!temItem) trechos.add((primeiro.inicioTrecho, n.fimTrecho));
    }
    return trechos;
  }

  // ---------------------------------------------------------- Apoio

  static int _espacoInicial(String s) => s.length - s.trimLeft().length;

  /// "sacos" → "sc": a unidade do estoque, para o "35 o saco" achar a
  /// quantidade certa quando o material não foi reconhecido.
  static String _unidadeDoEstoque(String palavra) {
    final p = palavra.replaceAll(RegExp(r'\s+'), ' ');
    if (RegExp(r'^(?:sacos?|sc)$').hasMatch(p)) return 'sc';
    if (RegExp(r'^(?:latas?)$').hasMatch(p)) return 'lt';
    if (RegExp(r'^(?:barras?|br)$').hasMatch(p)) return 'br';
    if (RegExp(r'^(?:m2|m²)$').hasMatch(p)) return 'm²';
    if (RegExp(r'^(?:m3|m³)$').hasMatch(p)) return 'm³';
    if (RegExp(r'^(?:metros?|mt|m)$').hasMatch(p)) return 'm';
    if (RegExp(r'^(?:kg|quilos?|kilos?)$').hasMatch(p)) return 'kg';
    if (RegExp(r'^(?:litros?|l)$').hasMatch(p)) return 'L';
    if (RegExp(r'^(?:pacotes?|caixas?|cx)$').hasMatch(p)) return 'pc';
    return 'un';
  }

  /// "galoes" → "galao", "metros cubicos" → "metro cubico".
  static String? _singular(String? unidade) {
    if (unidade == null) return null;
    return unidade.split(' ').map((p) {
      if (p.endsWith('oes')) return '${p.substring(0, p.length - 3)}ao';
      if (p.endsWith('es') && p.length > 4 && !p.endsWith('ees')) {
        // "lineares" → "linear"; "feixes" fica "feixe" pela regra do "s".
        final semEs = p.substring(0, p.length - 2);
        if (RegExp(r'[rz]$').hasMatch(semEs)) return semEs;
      }
      if (p.endsWith('s') && p.length > 2) return p.substring(0, p.length - 1);
      return p;
    }).join(' ');
  }

  static String _singularTempo(String palavra) {
    final p = palavra.replaceAll(RegExp(r'\s+'), ' ');
    if (p.startsWith('diaria') || p.startsWith('dia')) return 'dia';
    if (p.startsWith('hora')) return 'hora';
    if (p.startsWith('semana')) return 'semana';
    if (p.startsWith('mes')) return 'mes';
    if (p.startsWith('viage')) return 'viagem';
    if (p.startsWith('carga')) return 'carga';
    if (p.startsWith('parcela')) return 'parcela';
    return 'vez';
  }

  /// Lê o número no formato brasileiro: ponto separa milhar, vírgula
  /// separa centavos. "1.200" é mil e duzentos, não um vírgula dois.
  static double _lerNumeroBr(String bruto) {
    final s = bruto.trim();
    if (RegExp(r'^\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?$').hasMatch(s)) {
      return double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    }
    return double.tryParse(s.replaceAll(',', '.')) ?? 0;
  }
}

enum _Papel {
  /// Ainda sem evidência de nada.
  indefinido,

  /// É valor em dinheiro.
  dinheiro,

  /// Com certeza não é dinheiro (quantidade, medida, data, endereço…).
  naoDinheiro,

  /// "300 de cimento": quantidade, a menos que o contexto diga dinheiro.
  quantidadeTalvez,
}

class _Numero {
  final int inicio;
  final int fim;
  double valor;
  _Papel papel = _Papel.indefinido;
  bool forte = false;

  /// Trecho a tirar da descrição: com "R\$", verbo e "por" antes, e
  /// "reais", "cada" depois.
  int inicioTrecho;
  int fimTrecho;

  /// Preço unitário: '' para "cada"/"a 35", ou a unidade dita ("saco").
  String? unidadePreco;

  /// "3 diárias de 150": o 3 vem junto do preço.
  double? quantidadeDireta;

  /// Tipo da contagem quando o número é tempo ou gente ("dia", "pessoa").
  String? contagem;

  bool total = false;
  bool desconto = false;
  bool substitui = false;

  /// O que o número soma no lançamento (já multiplicado se unitário).
  double parcela = 0;

  _Numero(this.inicio, this.fim, this.valor)
      : inicioTrecho = inicio,
        fimTrecho = fim;
}

class _Quantidade {
  final int inicio;
  final double quantidade;

  /// Unidade do estoque ("sc", "m³") ou tipo da contagem ("dia").
  final String unidade;

  /// Material sem acento, para "o tijolo" achar o item de tijolo.
  final String material;

  /// A unidade como foi dita, no singular ("galao", "balde"): o estoque
  /// guarda "un", mas o preço "a 120 o galão" fala dela.
  final String? falada;

  const _Quantidade(this.inicio, this.quantidade, this.unidade, this.material,
      {this.falada});
}
