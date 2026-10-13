import 'texto_br.dart';

/// Chave de acesso da NF-e / NFC-e: 44 dígitos que identificam a nota.
///
/// É o dado mais confiável da nota. Vem do QR Code ou do código de barras,
/// que o leitor decodifica sem erro de OCR, e mesmo lida do texto tem
/// dígito verificador — um dígito trocado pelo OCR é detectado. E ela
/// carrega o CNPJ do emitente e o mês da emissão, que servem para conferir
/// o que o OCR leu no resto do papel.
///
/// Layout: cUF(2) AAMM(4) CNPJ(14) modelo(2) série(3) número(9)
/// tpEmis(1) código(8) DV(1). No CF-e SAT (modelo 59) os campos depois do
/// modelo são outros, mas UF, AAMM e CNPJ ficam no mesmo lugar.
class ChaveAcesso {
  /// Os 44 dígitos, sem espaço.
  final String digitos;

  const ChaveAcesso._(this.digitos);

  /// A chave contida em [texto] (só os dígitos contam), ou null se não
  /// forem 44 dígitos com o DV certo.
  static ChaveAcesso? validar(String texto) {
    final d = texto.replaceAll(RegExp(r'\D'), '');
    return dvValido(d) ? ChaveAcesso._(d) : null;
  }

  /// Módulo 11 dos 43 primeiros dígitos, pesos 2..9 da direita para a
  /// esquerda (recomeçando em 2 depois do 9). Resto 0 ou 1 dá DV 0.
  static int calcularDv(String digitos43) {
    var soma = 0;
    var peso = 2;
    for (var i = digitos43.length - 1; i >= 0; i--) {
      soma += (digitos43.codeUnitAt(i) - 48) * peso;
      peso = peso == 9 ? 2 : peso + 1;
    }
    final dv = 11 - soma % 11;
    return dv >= 10 ? 0 : dv;
  }

  static bool dvValido(String digitos) =>
      digitos.length == 44 &&
      RegExp(r'^\d{44}$').hasMatch(digitos) &&
      calcularDv(digitos.substring(0, 43)) == digitos.codeUnitAt(43) - 48;

  /// Código IBGE da UF do emitente.
  String get uf => digitos.substring(0, 2);
  int get ano => 2000 + int.parse(digitos.substring(2, 4));
  int get mes => int.parse(digitos.substring(4, 6));

  /// CNPJ do emitente (ou "000" + CPF, quando o emitente é pessoa física).
  String get cnpj => digitos.substring(6, 20);

  /// 55 = NF-e (DANFE), 65 = NFC-e (cupom), 59 = CF-e SAT.
  String get modelo => digitos.substring(20, 22);
  String get serie => digitos.substring(22, 25);
  String get numero => digitos.substring(25, 34);

  /// 1 = normal, 9 = contingência offline da NFC-e.
  String get tipoEmissao => digitos.substring(34, 35);
  String get codigo => digitos.substring(35, 43);
  int get dv => digitos.codeUnitAt(43) - 48;

  bool get ehNfce => modelo == '65';
  bool get ehNfe => modelo == '55';
  bool get emContingencia => modelo != '59' && tipoEmissao == '9';

  /// Em grupos de 4, como vem impressa na nota.
  String get formatada => [
        for (var i = 0; i < 44; i += 4) digitos.substring(i, i + 4),
      ].join(' ');

  /// A data de emissão tem de cair no ano e mês da chave.
  bool mesmoMes(DateTime data) => data.year == ano && data.month == mes;

  static const Set<String> _ufs = {
    '11', '12', '13', '14', '15', '16', '17', //
    '21', '22', '23', '24', '25', '26', '27', '28', '29', //
    '31', '32', '33', '35', '41', '42', '43', '50', '51', '52', '53',
  };

  static const Set<String> _modelosDeCompra = {'55', '65', '59'};

  /// UF que existe, mês válido e modelo de nota de compra. No texto, 44
  /// dígitos com DV certo ainda podem ser coincidência (1 em 11); com a
  /// estrutura conferida, a chance some.
  bool get estruturaPlausivel =>
      _ufs.contains(uf) &&
      mes >= 1 &&
      mes <= 12 &&
      _modelosDeCompra.contains(modelo);

  // ------------------------------------------------------------ Texto

  /// Procura a chave impressa: 44 dígitos, juntos ou em grupos de 4
  /// separados por espaço, às vezes quebrados em duas linhas e com letra
  /// no lugar de dígito ("432O 0612 ..."). O DV e a estrutura decidem —
  /// sem eles, qualquer sequência longa de números passaria por chave.
  static ChaveAcesso? procurarNoTexto(String texto) {
    var grupos = <String>[];
    // os dois-pontos também separam: "ACESSO:2626 0611..." colado
    for (final m in RegExp(r'[^\s:]+').allMatches(texto)) {
      final digitos = _digitosDoToken(m.group(0)!);
      if (digitos != null) {
        grupos.add(digitos);
        continue;
      }
      final achada = _naSequencia(grupos);
      if (achada != null) return achada;
      grupos = [];
    }
    return _naSequencia(grupos);
  }

  static final RegExp _pontuacaoNasPontas =
      RegExp(r'^[.,;:()\[\]\-]+|[.,;:()\[\]\-]+$');

  /// Dígitos de um pedaço do texto que é número, mesmo com uma ou outra
  /// letra que o OCR trocou; null se for palavra.
  static String? _digitosDoToken(String token) {
    final limpo = token
        .replaceAll(_pontuacaoNasPontas, '')
        .replaceAll(RegExp(r'[.\-]'), '');
    if (limpo.isEmpty) return null;
    final reais = RegExp(r'\d').allMatches(limpo).length;
    // "SOB" viraria "508": só aceita letra no meio de um número
    if (reais * 4 < limpo.length * 3) return null;
    final corrigido = TextoBr.corrigirDigitos(limpo);
    return RegExp(r'^\d+$').hasMatch(corrigido) ? corrigido : null;
  }

  static ChaveAcesso? _naSequencia(List<String> grupos) {
    final todos = grupos.join();
    if (todos.length < 44) return null;
    // A chave impressa começa num grupo: tenta essas posições primeiro e
    // só depois desliza, para o caso de um número colado na frente.
    final inicios = <int>[];
    var posicao = 0;
    for (final g in grupos) {
      inicios.add(posicao);
      posicao += g.length;
    }
    for (final i in [
      ...inicios,
      for (var i = 0; i + 44 <= todos.length; i++) i
    ]) {
      if (i + 44 > todos.length) continue;
      final chave = validar(todos.substring(i, i + 44));
      if (chave != null && chave.estruturaPlausivel) return chave;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ChaveAcesso && other.digitos == digitos;

  @override
  int get hashCode => digitos.hashCode;

  @override
  String toString() => formatada;
}

/// O que um código lido na foto (QR Code da NFC-e, QR do CF-e SAT, código
/// de barras do DANFE) informa sobre a nota.
class DadosDoCodigo {
  final ChaveAcesso chave;

  /// Dia da emissão: só o QR da contingência offline traz (o mês e o ano
  /// estão na chave).
  final int? diaEmissao;

  /// Data completa: QR do CF-e SAT e QR da versão 1 da NFC-e.
  final DateTime? dataEmissao;

  /// Valor total da nota (vNF): QR offline, SAT e versão 1.
  final double? valorTotal;

  const DadosDoCodigo(
    this.chave, {
    this.diaEmissao,
    this.dataEmissao,
    this.valorTotal,
  });

  /// Interpreta o conteúdo de um QR Code ou código de barras; null se não
  /// for de nota fiscal.
  ///
  /// - NFC-e, QR versão 2/3: URL com `p=CHAVE|versão|tpAmb|...`. Emitida
  ///   online: `CHAVE|2|tpAmb|idCSC|hash`; em contingência offline:
  ///   `CHAVE|2|tpAmb|DIA|VALOR|DIGVAL|idCSC|hash`, VALOR com ponto decimal.
  /// - NFC-e, QR versão 1: URL com `chNFe=`, `vNF=` e `dhEmi=` (em hexa).
  /// - CF-e SAT: `CHAVE|AAAAMMDDhhmmss|VALOR|...`.
  /// - DANFE: o CODE-128 traz só os 44 dígitos.
  static DadosDoCodigo? ler(String conteudo) {
    final texto = conteudo.trim();

    final p = RegExp(r'(?:^|[?&])p=([^&#\s]+)').firstMatch(texto);
    if (p != null) return _dePartes(_decodificar(p.group(1)!).split('|'));

    final ch = RegExp(r'chNFe=(\d{44})').firstMatch(texto);
    if (ch != null) {
      final chave = ChaveAcesso.validar(ch.group(1)!);
      if (chave == null) return null;
      final vnf = RegExp(r'vNF=(\d+(?:\.\d{1,2})?)(?!\d)').firstMatch(texto);
      final dh = RegExp(r'dhEmi=([0-9a-fA-F]+)').firstMatch(texto);
      return DadosDoCodigo(
        chave,
        valorTotal: vnf == null ? null : double.parse(vnf.group(1)!),
        dataEmissao: dh == null ? null : _dataDeHexa(dh.group(1)!),
      );
    }

    if (texto.contains('|')) return _dePartes(texto.split('|'));

    // Código de barras do DANFE: só dígitos (o leitor pode devolver com
    // espaço ou com o prefixo "NFe" do identificador do XML).
    final semPrefixo = texto.replaceFirst(RegExp(r'^[A-Za-z]{2,3}'), '');
    if (!RegExp(r'^[\d\s]+$').hasMatch(semPrefixo)) return null;
    final chave = ChaveAcesso.validar(semPrefixo);
    return chave == null ? null : DadosDoCodigo(chave);
  }

  static DadosDoCodigo? _dePartes(List<String> partes) {
    final chave = ChaveAcesso.validar(
        partes.first.trim().replaceFirst(RegExp(r'^[A-Za-z]{2,3}'), ''));
    if (chave == null) return null;
    final p = partes.map((s) => s.trim()).toList();

    // CF-e SAT: a 2ª parte é a data e hora da emissão.
    if (p.length >= 3 && RegExp(r'^\d{14}$').hasMatch(p[1])) {
      return DadosDoCodigo(
        chave,
        dataEmissao: _data(int.parse(p[1].substring(0, 4)),
            int.parse(p[1].substring(4, 6)), int.parse(p[1].substring(6, 8))),
        valorTotal: _valor(p[2]),
      );
    }

    // Contingência offline: dia e valor logo depois de versão e ambiente.
    // Na emissão online essas posições têm o id do CSC e o hash — que
    // nunca têm cara de dia + valor com centavos, então não se confundem.
    if (p.length >= 6) {
      final dia = RegExp(r'^\d{1,2}$').hasMatch(p[3]) ? int.parse(p[3]) : null;
      final valor = _valor(p[4]);
      if (dia != null && dia >= 1 && dia <= 31 && valor != null) {
        return DadosDoCodigo(chave, diaEmissao: dia, valorTotal: valor);
      }
    }
    return DadosDoCodigo(chave);
  }

  /// Valor com ponto decimal e centavos ("350.00"), como o QR escreve.
  static double? _valor(String s) =>
      RegExp(r'^\d+\.\d{2}$').hasMatch(s) ? double.parse(s) : null;

  static String _decodificar(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      // "%" solto quebra o decode: basta recuperar o separador
      return s.replaceAll(RegExp('%7C', caseSensitive: false), '|');
    }
  }

  /// dhEmi do QR versão 1: a data ISO ("2020-06-15T14:32:00-03:00")
  /// escrita em hexadecimal, dois dígitos por caractere.
  static DateTime? _dataDeHexa(String hexa) {
    if (hexa.length.isOdd) return null;
    final codigos = <int>[];
    for (var i = 0; i < hexa.length; i += 2) {
      codigos.add(int.parse(hexa.substring(i, i + 2), radix: 16));
    }
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})')
        .firstMatch(String.fromCharCodes(codigos));
    if (m == null) return null;
    return _data(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  static DateTime? _data(int ano, int mes, int dia) {
    if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
    final d = DateTime(ano, mes, dia);
    return d.month == mes && d.day == dia ? d : null;
  }
}
