import 'texto_br.dart';

/// O que aconteceu de errado com a escuta, do jeito que a tela precisa.
enum TipoErroVoz {
  /// Ouviu barulho mas nenhuma palavra ("error_no_match").
  naoEntendi,

  /// O app não tem permissão de usar o microfone.
  microfone,

  /// Outro app (ou a gravação anterior) ainda está com o reconhecedor.
  ocupado,

  /// Falta o pacote de voz em português para reconhecer sem internet.
  pacoteOffline,

  /// No modo online, sem internet ou com o servidor fora.
  semInternet,

  /// O serviço online recusou por excesso de pedidos.
  muitasTentativas,

  /// O microfone não abriu (outro app gravando, defeito).
  audio,

  /// Qualquer outro erro do reconhecedor.
  desconhecido,
}

/// Erro do reconhecedor de voz traduzido para o encarregado: mensagem
/// clara e o que dá para fazer a seguir.
///
/// Antes um erro deixava o painel "ouvindo" para sempre. Agora cada código
/// do Android vira uma mensagem e uma saída: tentar de novo, liberar o
/// microfone ou — só quando falta o pacote offline — usar o reconhecimento
/// online do Google naquela gravação, por escolha do usuário.
class ErroVoz {
  final TipoErroVoz tipo;
  final String mensagem;

  /// Mostrar o botão "Usar reconhecimento online do Google".
  final bool ofereceOnline;

  const ErroVoz(this.tipo, this.mensagem, {this.ofereceOnline = false});

  /// Instrução para baixar o pacote de português offline — o caminho
  /// muda um pouco entre versões do Android, por isso as duas entradas.
  static const String instrucaoPacoteOffline =
      'Para ouvir sem internet, o aparelho precisa do pacote de voz em '
      'português. Baixe uma vez: abra as configurações de voz do Google '
      '(Configurações › Google › Voz, ou app Google › Configurações › '
      'Voz), entre em "Reconhecimento de voz offline" e baixe '
      '"Português (Brasil)". Depois toque em Tentar de novo.';

  /// Traduz o código do plugin ("error_no_match", "error_unknown (5)").
  /// [online] diz se a gravação usava o reconhecimento online: sem ele,
  /// erro de rede ou de servidor quer dizer que o aparelho não tinha o
  /// pacote offline e tentou a internet.
  static ErroVoz de(String codigo, {bool online = false}) {
    final c = codigo.trim().toLowerCase();
    bool e(String prefixo) => c.startsWith(prefixo);

    if (e('error_no_match') || e('error_speech_timeout')) {
      return const ErroVoz(
          TipoErroVoz.naoEntendi,
          'Não entendi o que foi dito. Tente de novo, falando perto do '
          'microfone.');
    }
    if (e('error_permission') || e('error_insufficient_permissions')) {
      return const ErroVoz(
          TipoErroVoz.microfone,
          'O ObraFácil está sem acesso ao microfone. Libere o microfone '
          'para o app nas configurações do aparelho e tente de novo.');
    }
    if (e('error_busy') || e('error_recognizer_busy')) {
      return const ErroVoz(
          TipoErroVoz.ocupado,
          'O reconhecimento de voz ainda está ocupado. Espere um instante '
          'e toque em Tentar de novo.');
    }
    if (e('error_too_many_requests')) {
      return const ErroVoz(
          TipoErroVoz.muitasTentativas,
          'Muitas tentativas seguidas. Espere alguns segundos e tente de '
          'novo.');
    }
    if (e('error_audio')) {
      return const ErroVoz(
          TipoErroVoz.audio,
          'Não consegui abrir o microfone. Feche outros apps que estejam '
          'gravando e tente de novo.');
    }
    final idioma =
        e('error_language_not_supported') || e('error_language_unavailable');
    final rede = e('error_network') || e('error_server');
    if (idioma || rede) {
      if (!online) {
        return const ErroVoz(TipoErroVoz.pacoteOffline, instrucaoPacoteOffline,
            ofereceOnline: true);
      }
      return ErroVoz(
          TipoErroVoz.semInternet,
          idioma
              ? 'O reconhecimento online do Google não está disponível em '
                  'português agora. Tente de novo mais tarde.'
              : 'Sem internet para o reconhecimento online. Confira o sinal '
                  'e tente de novo — ou baixe o pacote offline de português '
                  'para não depender da internet.');
    }
    if (e('error_client')) {
      return const ErroVoz(TipoErroVoz.desconhecido,
          'O reconhecimento parou antes da hora. Tente de novo.');
    }
    return const ErroVoz(TipoErroVoz.desconhecido,
        'O reconhecimento de voz falhou. Tente de novo.');
  }

  /// A escuta nem começou: o plugin recusou o listen (reconhecedor
  /// ausente no aparelho ou preso a outro app).
  static const ErroVoz naoComecou = ErroVoz(
      TipoErroVoz.ocupado,
      'Não consegui abrir o reconhecimento de voz. Espere um instante e '
      'toque em Tentar de novo.');

  /// Abaixo disso o reconhecedor está chutando: vale avisar.
  static const double limiarConfianca = 0.5;

  /// Aviso para a confiança final baixa, ou null. Confiança <= 0 é
  /// "o aparelho não informou" — não é motivo de alarme.
  static String? avisoDeConfianca(double? confianca) {
    if (confianca == null || confianca <= 0) return null;
    if (confianca >= limiarConfianca) return null;
    return 'Não tenho certeza do que ouvi — confira a transcrição.';
  }
}

/// Um resultado do reconhecedor: as hipóteses (a 1ª é a principal) com a
/// confiança de cada uma, e se é o resultado final.
class ResultadoVoz {
  final List<(String, double)> hipoteses;
  final bool finalizou;

  const ResultadoVoz(this.hipoteses, {required this.finalizou});

  /// A transcrição principal.
  String get texto => hipoteses.isEmpty ? '' : hipoteses.first.$1;

  /// Confiança da principal, ou null se o aparelho não informou.
  double? get confianca {
    if (hipoteses.isEmpty) return null;
    final c = hipoteses.first.$2;
    return c > 0 ? c : null;
  }

  /// Confiança da hipótese que a IA escolheu mostrar ([texto]), ou null
  /// se o aparelho não informou. O aviso de "confira" fala do que está na
  /// tela, que nem sempre é a principal.
  double? confiancaDe(String texto) {
    for (final (t, c) in hipoteses) {
      if (t.trim() == texto.trim()) return c > 0 ? c : null;
    }
    return null;
  }
}

/// Encerra a escuta quando a pessoa parou de falar, mesmo com barulho.
///
/// O detector de silêncio do Android escuta som, não fala: com betoneira
/// ligada ele nunca acha o silêncio e a gravação vai até o limite. Aqui o
/// critério é palavra nova — depois de já ter ouvido alguma coisa, se o
/// texto não ganha palavra por [silencio], a fala acabou. Revisão de uma
/// palavra (o reconhecedor trocando "sento" por "cento") não conta como
/// fala nova, senão o ruído manteria a gravação aberta.
class MonitorDeFala {
  final Duration silencio;

  MonitorDeFala({this.silencio = const Duration(seconds: 4)});

  var _maiorQuantidade = 0;
  DateTime? _ultimaPalavraNova;

  /// Registra o texto parcial ouvido em [agora]; true se trouxe palavra
  /// nova.
  bool registrar(String texto, DateTime agora) {
    final quantidade = TextoBr.normalizar(texto)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .length;
    if (quantidade <= _maiorQuantidade) return false;
    _maiorQuantidade = quantidade;
    _ultimaPalavraNova = agora;
    return true;
  }

  /// Já ouviu algo e faz [silencio] que não chega palavra nova.
  bool deveEncerrar(DateTime agora) {
    final ultima = _ultimaPalavraNova;
    return ultima != null && agora.difference(ultima) >= silencio;
  }

  /// Nova gravação, contagem do zero.
  void reiniciar() {
    _maiorQuantidade = 0;
    _ultimaPalavraNova = null;
  }
}
