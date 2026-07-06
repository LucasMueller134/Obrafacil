/// Interpreta a data falada dentro de uma frase em pt-BR.
///
/// Entende os jeitos comuns de falar a data de um gasto:
/// - relativas: "hoje", "ontem", "anteontem", "há 3 dias", "3 dias atrás",
///   "semana passada", "semana retrasada", "mês passado";
/// - dia da semana: "sexta passada", "na segunda", "sábado", "terça-feira";
/// - dia do mês: "dia 5", "dia 5 de julho", "dia 5 do 7", "primeiro de maio";
/// - numéricas: "05/07" e "05/07/2026".
///
/// O texto deve chegar já normalizado pelo NumeroExtenso
/// ("dia cinco de julho" → "dia 5 de julho").
///
/// Gasto de obra não acontece no futuro: datas sem ano são resolvidas para
/// a ocorrência mais recente no passado ("dia 25" falado em 6 de julho é
/// 25 de junho) e datas explícitas futuras são descartadas.
abstract class DataFalada {
  static const Map<String, int> _meses = {
    'janeiro': 1, 'fevereiro': 2, 'março': 3, 'marco': 3, 'abril': 4,
    'maio': 5, 'junho': 6, 'julho': 7, 'agosto': 8, 'setembro': 9,
    'outubro': 10, 'novembro': 11, 'dezembro': 12,
  };

  // DateTime.weekday: 1 = segunda … 7 = domingo.
  static const Map<String, int> _diasSemana = {
    'segunda': 1, 'terca': 2, 'terça': 2, 'quarta': 3, 'quinta': 4,
    'sexta': 5, 'sabado': 6, 'sábado': 6, 'domingo': 7,
  };

  static final RegExp _numerica =
      RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b');

  // "dia 5", "no dia 5 de julho", "dia 5 do 7", "dia 5 de julho de 2026".
  // O lookbehind evita "meio dia 30" virar dia 30; "diária" não casa porque
  // exige espaço + número logo após "dia".
  static final RegExp _comPalavraDia = RegExp(
      r'(?<![\wà-ÿ])(?<!meio[ -])dia\s+(\d{1,2}|primeiro)[ºo°]?'
      r'(?:\s+d[eo]\s+([\wà-ÿ]+))?(?:\s+de\s+(\d{2,4}))?',
      caseSensitive: false);

  // "5 de julho", "primeiro de maio de 2026" — sem a palavra "dia",
  // só quando o mês é falado por nome.
  static final RegExp _diaDeMesNome = RegExp(
      r'\b(\d{1,2}|primeiro)[ºo°]?\s+de\s+([a-zà-ÿ]+)(?:\s+de\s+(\d{2,4}))?',
      caseSensitive: false);

  static final RegExp _anteontem =
      RegExp(r'\banteontem\b|\bantes\s+de\s+ontem\b', caseSensitive: false);
  static final RegExp _ontem = RegExp(r'\bontem\b', caseSensitive: false);
  static final RegExp _hoje = RegExp(r'\bhoje\b', caseSensitive: false);
  static final RegExp _diasAtras = RegExp(
      r'\b(?:h[aá]|faz)\s+(\d{1,3})\s+dias?\b|\b(\d{1,3})\s+dias?\s+atr[aá]s\b',
      caseSensitive: false);
  static final RegExp _semanaPassada =
      RegExp(r'\bsemana\s+(passada|retrasada)\b', caseSensitive: false);
  static final RegExp _mesPassado =
      RegExp(r'\bm[eê]s\s+passado\b', caseSensitive: false);

  // "segunda" a "sexta" também são ordinais ("segunda parcela"), então só
  // valem como dia da semana com um qualificador: "na sexta", "sexta-feira",
  // "sexta passada". Sábado e domingo podem aparecer sozinhos.
  static final RegExp _diaSemana = RegExp(
      r'\b(?:(n[ao]|últim[ao]|ultim[ao]|nest[ea]|ness[ea]|est[ea]|ess[ea])\s+)?'
      r'(segunda|ter[cç]a|quarta|quinta|sexta|s[aá]bado|domingo)'
      r'(\s*-\s*feira|\s+feira)?'
      r'(?:\s+(passad[ao]|retrasad[ao]))?',
      caseSensitive: false);

  /// Data mais provável falada no [texto], ou null se nenhuma foi dita.
  /// [agora] existe para os testes fixarem o "hoje".
  static DateTime? extrair(String texto, {DateTime? agora}) {
    final ref = agora ?? DateTime.now();
    final hoje = DateTime(ref.year, ref.month, ref.day);

    final data = _explicita(texto, hoje) ??
        _relativa(texto, hoje) ??
        _porDiaDaSemana(texto, hoje);
    if (data == null) return null;
    // Fora da faixa aceita pelo formulário (2020 até hoje) é quase sempre
    // erro de transcrição — melhor manter a data padrão que chutar errado.
    if (data.isAfter(hoje) || data.year < 2020) return null;
    return data;
  }

  // -------------------------------------------------------- Estratégias

  static DateTime? _explicita(String texto, DateTime hoje) {
    final numerica = _numerica.firstMatch(texto);
    if (numerica != null) {
      final dia = int.parse(numerica.group(1)!);
      final mes = int.parse(numerica.group(2)!);
      if (mes >= 1 && mes <= 12) {
        return _comMes(dia, mes, _lerAno(numerica.group(3)), hoje);
      }
    }

    final comDia = _comPalavraDia.firstMatch(texto);
    if (comDia != null) {
      final dia = _lerDia(comDia.group(1)!);
      final mes = _lerMes(comDia.group(2));
      if (mes != null) {
        return _comMes(dia, mes, _lerAno(comDia.group(3)), hoje);
      }
      return _soDia(dia, hoje);
    }

    final comNome = _diaDeMesNome.firstMatch(texto);
    if (comNome != null) {
      final mes = _lerMes(comNome.group(2));
      if (mes != null) {
        return _comMes(_lerDia(comNome.group(1)!), mes,
            _lerAno(comNome.group(3)), hoje);
      }
    }
    return null;
  }

  static DateTime? _relativa(String texto, DateTime hoje) {
    if (_anteontem.hasMatch(texto)) return _diasAntes(hoje, 2);
    if (_ontem.hasMatch(texto)) return _diasAntes(hoje, 1);
    if (_hoje.hasMatch(texto)) return hoje;

    final atras = _diasAtras.firstMatch(texto);
    if (atras != null) {
      final n = int.parse(atras.group(1) ?? atras.group(2)!);
      return _diasAntes(hoje, n);
    }

    final semana = _semanaPassada.firstMatch(texto);
    if (semana != null) {
      return _diasAntes(
          hoje, semana.group(1)!.toLowerCase() == 'retrasada' ? 14 : 7);
    }

    if (_mesPassado.hasMatch(texto)) {
      // Mesmo dia do mês anterior; se não existir (31 de julho → junho),
      // usa o último dia daquele mês.
      return _montar(hoje.year, hoje.month - 1, hoje.day) ??
          DateTime(hoje.year, hoje.month, 0);
    }
    return null;
  }

  static DateTime? _porDiaDaSemana(String texto, DateTime hoje) {
    for (final m in _diaSemana.allMatches(texto)) {
      final alvo = _diasSemana[m.group(2)!.toLowerCase()];
      if (alvo == null) continue;
      final qualificado =
          m.group(1) != null || m.group(3) != null || m.group(4) != null;
      final ambiguo = alvo <= 5; // segunda…sexta são também ordinais
      if (ambiguo && !qualificado) continue;

      // Ocorrência mais recente (hoje conta); "passada" força a anterior.
      var dias = (hoje.weekday - alvo) % 7;
      final sufixo = m.group(4)?.toLowerCase();
      if (sufixo != null && sufixo.startsWith('retrasad')) {
        dias += dias == 0 ? 14 : 7;
      } else if (sufixo != null && dias == 0) {
        dias = 7;
      }
      return _diasAntes(hoje, dias);
    }
    return null;
  }

  // ---------------------------------------------------------- Apoios

  static int _lerDia(String token) =>
      token.toLowerCase() == 'primeiro' ? 1 : int.parse(token);

  static int? _lerMes(String? token) {
    if (token == null) return null;
    final numero = int.tryParse(token);
    if (numero != null) return (numero >= 1 && numero <= 12) ? numero : null;
    return _meses[token.toLowerCase()];
  }

  static int? _lerAno(String? token) {
    if (token == null) return null;
    final ano = int.parse(token);
    return ano < 100 ? 2000 + ano : ano;
  }

  /// Dia + mês conhecidos: sem ano explícito, usa o ano corrente e recua
  /// um ano se a data ainda não chegou ("5 de dezembro" falado em julho).
  static DateTime? _comMes(int dia, int mes, int? ano, DateTime hoje) {
    if (ano != null) return _montar(ano, mes, dia);
    final nesteAno = _montar(hoje.year, mes, dia);
    if (nesteAno != null && !nesteAno.isAfter(hoje)) return nesteAno;
    return _montar(hoje.year - 1, mes, dia);
  }

  /// Só o dia ("dia 25"): mês corrente, recuando até achar um mês em que
  /// esse dia já passou e existe (dia 31 pula meses de 30).
  static DateTime? _soDia(int dia, DateTime hoje) {
    for (var k = 0; k <= 12; k++) {
      final candidata = _montar(hoje.year, hoje.month - k, dia);
      if (candidata != null && !candidata.isAfter(hoje)) return candidata;
    }
    return null;
  }

  static DateTime? _montar(int ano, int mes, int dia) {
    if (dia < 1 || dia > 31) return null;
    final d = DateTime(ano, mes, dia);
    // "31 de fevereiro" rolaria para março — rejeita.
    return d.day == dia ? d : null;
  }

  static DateTime _diasAntes(DateTime hoje, int n) =>
      DateTime(hoje.year, hoje.month, hoje.day - n);
}
