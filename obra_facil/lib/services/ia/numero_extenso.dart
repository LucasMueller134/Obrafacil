/// Converte números falados por extenso (pt-BR) em dígitos.
///
/// O reconhecedor de voz do Android costuma transcrever valores como
/// palavras ("trezentos e cinquenta reais"). Este normalizador reescreve
/// o texto com dígitos ("350 reais") antes dos parsers de valor e de
/// materiais — é o que faz a IA de voz entender qualquer jeito de falar.
///
/// O reconhecedor também mistura os dois jeitos: "2 mil reais", "1,5 mil",
/// "2 mil e 500". Dígito seguido de escala falada vira um número só —
/// senão o "2" ficava solto e o "mil" virava 1000 sozinho.
abstract class NumeroExtenso {
  static const Map<String, int> _unidades = {
    'zero': 0,
    'um': 1,
    'uma': 1,
    'dois': 2,
    'duas': 2,
    'tres': 3,
    'três': 3,
    'quatro': 4,
    'cinco': 5,
    'seis': 6,
    'sete': 7,
    'oito': 8,
    'nove': 9,
    'dez': 10,
    'onze': 11,
    'doze': 12,
    'treze': 13,
    'catorze': 14,
    'quatorze': 14,
    'quinze': 15,
    'dezesseis': 16,
    'dezessete': 17,
    'dezoito': 18,
    'dezenove': 19,
  };

  static const Map<String, int> _dezenas = {
    'vinte': 20,
    'trinta': 30,
    'quarenta': 40,
    'cinquenta': 50,
    'cinqüenta': 50,
    'sessenta': 60,
    'setenta': 70,
    'oitenta': 80,
    'noventa': 90,
  };

  static const Map<String, int> _centenas = {
    'cem': 100,
    'cento': 100,
    'duzentos': 200,
    'duzentas': 200,
    'trezentos': 300,
    'trezentas': 300,
    'quatrocentos': 400,
    'quatrocentas': 400,
    'quinhentos': 500,
    'quinhentas': 500,
    'seiscentos': 600,
    'seiscentas': 600,
    'setecentos': 700,
    'setecentas': 700,
    'oitocentos': 800,
    'oitocentas': 800,
    'novecentos': 900,
    'novecentas': 900,
  };

  /// Multiplicadores ditos depois do número ("dois mil", "um milhão").
  static const Map<String, int> _escalas = {
    'mil': 1000,
    'milhao': 1000000,
    'milhão': 1000000,
    'milhoes': 1000000,
    'milhões': 1000000,
  };

  static final RegExp _soDigitos = RegExp(r'^\d+$');

  /// Dígitos que podem anteceder uma escala: "2" mil, "1,5" mil, "2.5" mil
  /// (o reconhecedor às vezes usa o ponto decimal do inglês). "1.500" fica
  /// de fora: ali o ponto é de milhar.
  static final RegExp _digitosAntesDaEscala =
      RegExp(r'^(?:\d+(?:,\d{1,3})?|\d+\.\d{1,2})$');

  /// Pontuação colada no fim da palavra ("cinquenta,") — volta depois do
  /// número para não juntar "o pedreiro 250, o ajudante 150" num item só.
  static final RegExp _pontuacaoFinal = RegExp(r'[,.;:!?]+$');

  static const Set<String> _pronomeDepoisDeCada = {'um', 'uma'};

  /// Reescreve todo número por extenso do texto como dígitos.
  static String normalizar(String texto) {
    final tokens = texto.split(RegExp(r'\s+'));
    final saida = <String>[];
    var i = 0;
    while (i < tokens.length) {
      // "cada um", "cada uma": pronome, não o número 1 — "10 sacos, cada
      // um 35" virava "cada 1 35" e o preço unitário se perdia.
      if (i > 0 &&
          _limpa(tokens[i - 1]) == 'cada' &&
          _pronomeDepoisDeCada.contains(_limpa(tokens[i]))) {
        saida.add(tokens[i]);
        i++;
        continue;
      }
      final numero = _lerNumero(tokens, i);
      if (numero != null) {
        final (valor, proximo) =
            _comDecimal(tokens, _formatar(numero.$1), numero.$2);
        saida.add(valor + _pontuacaoDe(tokens[proximo - 1]));
        i = proximo;
        continue;
      }
      // Dígito já transcrito seguido de decimal falado: "35 vírgula 50".
      if (_soDigitos.hasMatch(tokens[i])) {
        final (valor, proximo) = _comDecimal(tokens, tokens[i], i + 1);
        saida.add(proximo == i + 1
            ? valor
            : valor + _pontuacaoDe(tokens[proximo - 1]));
        i = proximo;
        continue;
      }
      saida.add(tokens[i]);
      i++;
    }
    return saida.join(' ');
  }

  /// Junta a parte decimal falada ("35 vírgula 50" → "35,50"), dita por
  /// extenso ou já em dígitos.
  static (String, int) _comDecimal(
      List<String> tokens, String inteiro, int indice) {
    if (indice + 1 >= tokens.length || !_ehVirgula(_limpa(tokens[indice]))) {
      return (inteiro, indice);
    }
    var inicio = indice + 1;
    // "vírgula zero cinco" = ,05 — o zero à esquerda não soma nada, mas
    // muda o valor.
    var prefixo = '';
    if (_limpa(tokens[inicio]) == 'zero' && inicio + 1 < tokens.length) {
      prefixo = '0';
      inicio++;
    }
    final digitos = _digitos(tokens[inicio]);
    if (digitos != null) {
      return ('$inteiro,$prefixo$digitos', inicio + 1);
    }
    final decimal = _lerNumero(tokens, inicio);
    if (decimal == null) return (inteiro, indice);
    return ('$inteiro,$prefixo${_formatar(decimal.$1)}', decimal.$2);
  }

  /// A pontuação colada no último token lido, devolvida depois do número.
  static String _pontuacaoDe(String ultimoToken) =>
      _pontuacaoFinal.firstMatch(ultimoToken)?.group(0) ?? '';

  static bool _ehVirgula(String w) => w == 'virgula' || w == 'vírgula';

  static String _limpa(String token) =>
      token.toLowerCase().replaceAll(RegExp(r'[^\wà-ÿ]'), '');

  /// Dígitos do token, sem a pontuação final ("500," → 500). Aceita
  /// decimal só quando [comDecimal] — o "1,5" de "1,5 mil".
  static num? _digitos(String token, {bool comDecimal = false}) {
    final s = token.replaceFirst(_pontuacaoFinal, '');
    if (_soDigitos.hasMatch(s)) return int.parse(s);
    if (!comDecimal || !_digitosAntesDaEscala.hasMatch(s)) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  /// Inteiro sem casas quebradas por erro de ponto flutuante
  /// (2,3 × 1000 = 2299,9999…); decimal real sai com vírgula.
  static String _formatar(num valor) {
    final arredondado = (valor * 100).round() / 100;
    if (arredondado == arredondado.roundToDouble()) {
      return arredondado.round().toString();
    }
    return arredondado.toString().replaceAll('.', ',');
  }

  /// Lê uma sequência de palavras-número a partir de [inicio].
  /// Retorna (valor, índice seguinte) ou null se não houver número ali.
  static (num, int)? _lerNumero(List<String> tokens, int inicio) {
    final grupo = _Grupo();
    var i = inicio;

    // Dígito só entra no número se uma escala falada vier logo depois
    // ("2 mil", "1,5 mil") — "10 sacos" continua do jeito que está.
    final primeiro = _digitos(tokens[i], comDecimal: true);
    if (primeiro != null) {
      if (i + 1 >= tokens.length ||
          !_escalas.containsKey(_limpa(tokens[i + 1]))) {
        return null;
      }
      grupo.digitos(primeiro);
      i++;
    }

    while (i < tokens.length) {
      final w = _limpa(tokens[i]);
      // "e" só faz parte do número entre duas partes dele
      // ("trezentos E cinquenta", "2 mil E 500"), nunca no começo nem
      // antes de algo que não continua o número ("duzentos e o ajudante").
      if (w == 'e') {
        if (!grupo.achou || i + 1 >= tokens.length) break;
        final seguinte = tokens[i + 1];
        final digito = _digitos(seguinte);
        final continua = digito != null
            ? grupo.aceitaDigitosAposEscala(digito, veioDoE: true)
            : grupo.aceita(_limpa(seguinte));
        if (!continua) break;
        i++;
        continue;
      }
      // Dígitos logo após a escala: "dois mil e 500", "2 mil 500". Sem o
      // "e", só a centena cheia — "2 mil 3 sacos" são dois números.
      final digito = _digitos(tokens[i]);
      if (digito != null) {
        final veioDoE = i > inicio && _limpa(tokens[i - 1]) == 'e';
        if (!grupo.aceitaDigitosAposEscala(digito, veioDoE: veioDoE)) break;
        grupo.digitos(digito);
        i++;
        continue;
      }
      if (!grupo.aceita(w)) break;
      grupo.somar(w);
      i++;
    }

    if (!grupo.achou) return null;
    // Um "e" solto no fim ("duzentos e") não pertence ao número.
    return (grupo.valor, i);
  }
}

/// Estado da leitura de um número falado, casa a casa.
///
/// Cada casa (centena, dezena, unidade) só pode ser preenchida uma vez e
/// na ordem: "dez quinze sacos" são dois números ditos em sequência, não
/// 25 sacos; "vinte e cinco" é um só. Somar tudo o que parecesse número
/// transformava a correção de quem fala ("dez… quinze sacos") num valor
/// que ninguém disse.
class _Grupo {
  num _total = 0;
  num _corrente = 0;
  bool achou = false;

  // Casas já preenchidas no grupo corrente (abaixo de mil).
  bool _centena = false;
  bool _dezena = false;
  bool _unidade = false;

  /// O grupo corrente veio em dígitos ("2 mil e 500"): só aceita escala.
  bool _fechado = false;

  /// Última escala lida ("mil"): o que vem depois dela é a parte menor
  /// do mesmo número; um número maior seria outro valor.
  int? _ultimaEscala;

  num get valor => _total + _corrente;

  bool get _grupoVazio => !_centena && !_dezena && !_unidade && !_fechado;

  bool aceita(String w) {
    final escala = NumeroExtenso._escalas[w];
    if (escala != null) {
      // "mil" sozinho vale 1000; "mil mil" ou "mil milhões" não existem.
      return _ultimaEscala == null || escala < _ultimaEscala!;
    }
    if (_fechado) return false;
    if (NumeroExtenso._centenas.containsKey(w)) return _grupoVazio;
    if (NumeroExtenso._dezenas.containsKey(w)) return !_dezena && !_unidade;
    final unidade = NumeroExtenso._unidades[w];
    if (unidade == null) return false;
    // 10 a 19 ocupam dezena e unidade de uma vez ("cento e quinze").
    if (unidade >= 10) return !_dezena && !_unidade;
    return !_unidade;
  }

  /// Dígitos depois de uma escala completam o número só se couberem nela
  /// ("2 mil e 500"); sem o "e", só a centena cheia ("2 mil 500").
  bool aceitaDigitosAposEscala(num digito, {required bool veioDoE}) {
    final escala = _ultimaEscala;
    if (escala == null || !_grupoVazio || digito >= escala) return false;
    return veioDoE || (digito >= 100 && digito <= 999);
  }

  void digitos(num d) {
    _corrente = d;
    _fechado = true;
    achou = true;
  }

  void somar(String w) {
    achou = true;
    final escala = NumeroExtenso._escalas[w];
    if (escala != null) {
      _total += (_corrente == 0 ? 1 : _corrente) * escala;
      _corrente = 0;
      _centena = _dezena = _unidade = _fechado = false;
      _ultimaEscala = escala;
      return;
    }
    final centena = NumeroExtenso._centenas[w];
    if (centena != null) {
      _corrente += centena;
      _centena = true;
      return;
    }
    final dezena = NumeroExtenso._dezenas[w];
    if (dezena != null) {
      _corrente += dezena;
      _dezena = true;
      return;
    }
    final unidade = NumeroExtenso._unidades[w]!;
    _corrente += unidade;
    _unidade = true;
    if (unidade >= 10) _dezena = true;
  }
}
