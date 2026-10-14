import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../constants/app_constants.dart';
import '../../models/item_material_model.dart';
import '../../models/lancamento_model.dart';
import 'data_falada.dart';
import 'escuta_voz.dart';
import 'hipoteses_voz.dart';
import 'itens_parser.dart';
import 'numero_extenso.dart';
import 'texto_br.dart';
import 'valor_falado.dart';
import 'vocabulario_obra.dart';

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
/// fala → transcrição → vocabulário de obra → números por extenso →
/// extração de valor (pelo contexto de cada número, com parcelas, preço
/// unitário, negociação e total), fornecedor (em qualquer posição, mesmo
/// minúsculo), data, materiais e categoria por peso de evidência — e a
/// descrição é reconstruída sem os trechos já entendidos.
///
/// Toda comparação de palavra passa pelo [TextoBr]: sem acento (a
/// transcrição erra acento o tempo todo) e por palavra inteira, para
/// "calçada" não ser classificada como o material cal.
///
/// A escuta é 100% no aparelho por padrão (sem internet, sem custo). O
/// reconhecimento online do Google só é usado numa gravação quando o
/// usuário escolhe, depois de ver que falta o pacote offline.
class VozService {
  /// O plugin é um só para o app inteiro: cada VozService aponta os
  /// ouvintes de erro e de estado para si quando começa a ouvir.
  final SpeechToText _stt = SpeechToText();
  bool _inicializado = false;

  final MonitorDeFala _monitor = MonitorDeFala();
  Timer? _vigia;

  /// Prazo para o próximo passo da gravação chegar (o início, o resultado
  /// final ou o erro). Sem ele, um aviso que o plugin não manda deixava a
  /// tela "ouvindo" para sempre.
  Timer? _prazo;

  // Gravação em andamento.
  void Function(ErroVoz erro)? _aoErro;
  void Function()? _aoTerminar;
  bool _gravacaoOnline = false;
  bool _comecouAOuvir = false;
  bool _recebeuResultado = false;
  bool _terminou = true;

  /// O plugin devolve "não começou" sem erro quando o reconhecedor ainda
  /// está preso à gravação anterior: sem o "listening", não há escuta.
  static const Duration _limiteDoInicio = Duration(seconds: 2);

  /// Depois que o microfone fecha, o plugin só avisa "done" quando chega o
  /// resultado final — que às vezes não vem.
  static const Duration _limiteDoFinal = Duration(seconds: 3);

  /// O Android avisa "done" antes do erro que causou o fim (o erro sai
  /// numa fila depois): sem resultado nenhum, espera um instante por ele
  /// para o painel mostrar "não entendi" em vez de "não ouvi nada".
  static const Duration _esperaDoErro = Duration(milliseconds: 500);

  Future<bool> inicializar() async {
    if (_inicializado) return true;
    try {
      _inicializado = await _stt.initialize(
        onError: _erroDoPlugin,
        onStatus: _estadoDoPlugin,
      );
    } on Exception {
      // Sem serviço de reconhecimento no aparelho: a tela avisa.
      _inicializado = false;
    }
    return _inicializado;
  }

  bool get ouvindo => _stt.isListening;

  /// Começa a ouvir. [onTexto] recebe cada resultado (parcial e final).
  ///
  /// - [online]: usa o reconhecimento online do Google nesta gravação —
  ///   só quando o usuário escolheu; o padrão é no aparelho.
  /// - [onResultado]: o resultado com todas as hipóteses e a confiança.
  /// - [onErro]: o erro do reconhecedor já traduzido; a escuta acabou.
  /// - [onFim]: a gravação acabou (resultado final, limite, silêncio ou
  ///   erro). Chamado uma vez só por gravação, sempre depois dos outros.
  Future<void> ouvir(
    void Function(String textoParcial, bool finalizou) onTexto, {
    bool online = false,
    void Function(ResultadoVoz resultado)? onResultado,
    void Function(ErroVoz erro)? onErro,
    void Function()? onFim,
  }) async {
    _aoErro = onErro;
    _aoTerminar = onFim;
    _gravacaoOnline = online;
    _comecouAOuvir = false;
    _recebeuResultado = false;
    _terminou = false;
    _stt.errorListener = _erroDoPlugin;
    _stt.statusListener = _estadoDoPlugin;
    _monitor.reiniciar();
    _vigiarSilencio();
    _esperar(_limiteDoInicio, () {
      if (!_comecouAOuvir) _falhar(ErroVoz.naoComecou);
    });

    try {
      await _stt.listen(
        // Modo ditado: tolera pausas na fala em vez de encerrar na
        // primeira respiração. Encerra após ~4s sem palavra nova (o
        // [MonitorDeFala], que funciona com barulho), ~6s de silêncio
        // real, quando o usuário toca em "Concluir" ou em 2 minutos.
        listenOptions: SpeechListenOptions(
          localeId: 'pt_BR',
          onDevice: !online,
          cancelOnError: true,
          partialResults: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 6),
        ),
        onResult: (SpeechRecognitionResult r) {
          if (_terminou) return; // resultado atrasado de gravação encerrada
          _recebeuResultado = true;
          _monitor.registrar(r.recognizedWords, DateTime.now());
          onResultado?.call(ResultadoVoz(
            [
              for (final a in r.alternates)
                if (a.recognizedWords.trim().isNotEmpty)
                  (a.recognizedWords, a.confidence),
            ],
            finalizou: r.finalResult,
          ));
          onTexto(r.recognizedWords, r.finalResult);
          if (r.finalResult) _terminar();
        },
      );
    } on Exception {
      // O listen nem começou (reconhecedor ausente ou preso a outro app):
      // sem isto o painel ficava esperando uma fala que nunca chega.
      _falhar(ErroVoz.naoComecou);
    }
  }

  /// Para de ouvir e pede o resultado final (que chega pelo [ouvir]).
  Future<void> parar() {
    _pararVigia();
    return _stt.stop();
  }

  /// Descarta a gravação: nenhum ouvinte é chamado depois disto.
  Future<void> cancelar() {
    _pararVigia();
    _prazo?.cancel();
    _terminou = true;
    _aoErro = null;
    _aoTerminar = null;
    return _stt.cancel();
  }

  /// Confere a cada meio segundo se a fala acabou — com barulho de obra o
  /// silêncio do Android pode nunca chegar.
  void _vigiarSilencio() {
    _pararVigia();
    _vigia = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_monitor.deveEncerrar(DateTime.now())) {
        _pararVigia();
        if (_stt.isListening) unawaited(_stt.stop()); // gera o final
      }
    });
  }

  void _pararVigia() {
    _vigia?.cancel();
    _vigia = null;
  }

  void _erroDoPlugin(SpeechRecognitionError erro) {
    // Erro passageiro (só no iOS) não encerra a escuta: o plugin continua.
    if (!erro.permanent) return;
    _falhar(ErroVoz.de(erro.errorMsg, online: _gravacaoOnline));
  }

  void _estadoDoPlugin(String estado) {
    if (_terminou) return;
    if (estado == SpeechToText.listeningStatus) {
      _comecouAOuvir = true;
      _prazo?.cancel();
      return;
    }
    // O fim de uma gravação cancelada no "Regravar" pode chegar depois de
    // a nova começar: só vale o que vem depois do "listening" desta.
    if (!_comecouAOuvir) return;
    if (estado == SpeechToText.doneStatus) {
      if (_recebeuResultado) {
        _terminar();
      } else {
        _esperar(_esperaDoErro, _terminar);
      }
    } else if (estado == SpeechToText.notListeningStatus) {
      _pararVigia();
      _esperar(_limiteDoFinal, _terminar);
    }
  }

  void _esperar(Duration limite, void Function() aoVencer) {
    _prazo?.cancel();
    _prazo = Timer(limite, () {
      if (!_terminou) aoVencer();
    });
  }

  /// Avisa o erro e encerra a gravação — um erro por gravação basta.
  void _falhar(ErroVoz erro) {
    if (_terminou) return;
    final ouvinte = _aoErro;
    _aoErro = null;
    ouvinte?.call(erro);
    _terminar();
  }

  void _terminar() {
    _pararVigia();
    _prazo?.cancel();
    _prazo = null;
    if (_terminou) return;
    _terminou = true;
    _aoErro = null;
    final fim = _aoTerminar;
    _aoTerminar = null;
    fim?.call();
  }

  // ============================================================= Parser

  /// Fornecedor em qualquer posição da frase, mesmo todo minúsculo
  /// (a transcrição de voz raramente capitaliza): "no depósito são josé",
  /// "na casa do construtor", "lá na madeireira do zé". Aceita até duas
  /// palavras de nome antes do tipo ("na silva materiais de construção").
  static final RegExp _fornecedorComTipo = RegExp(
      r'\b(?:n[oa]|d[oa]|em|l[aá]\s+n[oa]|ali\s+n[oa])\s+'
      r'((?:(?!(?:n[oa]s?|d[oa]s?|em|de|e|o|a|os|as|um|uma|que|por|com|pra|'
      r'pro|para)\b)[a-zA-Zà-ÿÀ-Ý]+\s+){0,2}?'
      r'(?:loja|dep[oó]sito|deposito|casa|mercado|supermercado|mercadinho|'
      r'madeireira|ferragens?|ferragista|atacad(?:o|ao|ão)|agropecu[aá]ria|'
      r'distribuidora|comercial|construtora|materiais|material|serralheria|'
      r'vidra[cç]aria|marmoraria|armaz[eé]m|olaria|areal|home\s*center)\b'
      r"[a-zA-Zà-ÿÀ-Ý' ]{0,45})",
      caseSensitive: false);

  /// Nome próprio capitalizado após na/no/da/do (quando a transcrição
  /// capitaliza): "no Depósito São José", "na Leroy".
  static final RegExp _fornecedorCapitalizado =
      RegExp(r'\b(?:n[oa]|d[oa]|em)\s+'
          r'([A-ZÀ-Ý][\wà-ÿ]+(?:\s+(?:d[oae]s?\s+)?[A-ZÀ-Ý][\wà-ÿ]+){0,3})');

  /// Redes conhecidas ditas sem preposição ("comprei na leroy merlin").
  static const List<String> _redesConhecidas = [
    'leroy merlin',
    'leroy',
    'telhanorte',
    'obramax',
    'cassol',
    'balaroti',
    'tumelero',
    'chatuba',
    'dicico',
    'sodimac',
    'ferreira costa',
    'tenda atacado',
    'havan',
    'casa do construtor',
  ];

  /// Palavras onde o nome do fornecedor termina: o resto da frase não é
  /// nome ("lá na madeireira do zé PEGUEI a madeira do telhado").
  static const Set<String> _fimDoFornecedor = {
    'o',
    'a',
    'os',
    'as',
    'um',
    'uma',
    'por',
    'que',
    'com',
    'para',
    'pra',
    'pro',
    'pros',
    'pras',
    'no',
    'na',
    'nos',
    'nas',
    'em',
    'onde',
    'quando',
    'ai',
    'la',
    'ali',
    'aqui',
    'tambem',
    'mais',
    'e',
    'ou',
    'mas',
    'so',
    'ja',
    'entao',
    'dai',
    'depois',
    'antes',
    'hoje',
    'ontem',
    'anteontem',
    'dia',
    'semana',
    'mes',
    'reais',
    'real',
    'cartao',
    'pix',
    'dinheiro',
    'vista',
    'valendo',
    'custou',
    'custando',
    'custaram',
    'saiu',
    'deu',
    'foi',
    'foram',
    'ficou',
    'fechou',
    'perto',
    'ao',
    'aos',
    'porque',
    'pois',
    'segunda',
    'terca',
    'quarta',
    'quinta',
    'sexta',
    'sabado',
    'domingo',
    'feira',
    'ta',
    'ne',
    'viu',
    'certo',
    'ok',
    'beleza',
    'tipo',
    'tudo',
    'cada',
    'pelo',
    'pela',
    'meu',
    'minha',
    'seu',
    'sua',
    'ele',
    'ela',
    'eu',
    'tem',
    'tinha',
    'esta',
    'era',
  };

  /// Material logo depois do nome também o encerra ("no depósito são josé
  /// cimento…"); depois de "do/da" ele faz parte ("Mundo das Tintas").
  static const Set<String> _materiaisNoFornecedor = {
    'cimento',
    'areia',
    'brita',
    'tijolo',
    'tijolos',
    'bloco',
    'blocos',
    'telha',
    'telhas',
    'tinta',
    'tintas',
    'madeira',
    'ferro',
    'cano',
    'canos',
    'fio',
    'fios',
    'piso',
    'porta',
    'portas',
    'cal',
    'gesso',
    'argamassa',
    'vergalhao',
    'pedra',
    'saco',
    'sacos',
  };

  static const Set<String> _conectoresDoNome = {
    'de',
    'do',
    'da',
    'dos',
    'das',
  };

  /// Palavras que não dão nome a um estabelecimento: o tipo de loja e o
  /// que ela vende. "Na madeireira", "na loja de material de construção",
  /// "na ferragista do bairro" dizem onde, mas não qual — o usuário
  /// preenche o nome; um nome genérico ele talvez nem corrigisse.
  static const Set<String> _naoFornecedor = {
    'obra',
    'obras',
    'total',
    'terreno',
    'servico',
    'canteiro',
    'estoque',
    'valor',
    'casa',
    'loja',
    'mercado',
    'supermercado',
    'mercadinho',
    'material',
    'materiais',
    'construcao',
    'deposito',
    'oficina',
    'semana',
    'conta',
    'olaria',
    'areal',
    'armazem',
    'comercial',
    'madeireira',
    'ferragem',
    'ferragens',
    'ferragista',
    'serralheria',
    'vidracaria',
    'marmoraria',
    'agropecuaria',
    'distribuidora',
    'construtora',
    'atacado',
    'bairro',
    'esquina',
    'cidade',
    'centro',
    'frente',
    'perto',
  };

  /// Verbo conjugado pela terminação — encerra o nome do fornecedor.
  static final RegExp _pareceVerbo =
      RegExp(r'^(?:[a-z]{2,}ei|[a-z]{3,}(?:amos|emos|imos|aram|eram|iram)|'
          r'[a-z]{2,}ou)$');

  /// Verbos/aberturas de comando no começo da frase.
  static final RegExp _aberturas = RegExp(
      r'^\s*(?:anota(?:r)?\s+a[ií]|anota(?:r)?|registra(?:r)?(?:\s+pra\s+mim)?|'
      r'lan[cç]a(?:r)?|faz\s+um\s+lan[cç]amento\s+de|lan[cç]amento\s+de|'
      r'coloca(?:r)?|bota(?:r)?|comprei|compramos|paguei|pagamos|gastei|'
      r'gastamos|aluguei|alugamos|peguei|pegamos|levei|levamos|adquiri|'
      r'contratei|contratamos|mandei|fiz)\s+',
      caseSensitive: false);

  /// Aluguel de equipamento não é compra de material: nada vai ao estoque.
  static final RegExp _aluguel = RegExp(
      r'\b(?:alug\w*|loca[cç](?:ao|ão|oes|ões)|locad[oa]s?|locamos|loquei)\b',
      caseSensitive: false);

  /// Equipamento que se aluga — sob aluguel, não é item de estoque.
  static const List<String> _equipamentos = [
    'andaime',
    'betoneira',
    'escora',
    'forma',
    'container',
    'cacamba',
    'compactador',
    'gerador',
    'martelete',
    'furadeira',
    'serra',
    'placa vibratoria',
    'bomba',
    'vibrador',
    'guincho',
    'elevador',
    'balancim',
    'plataforma',
    'torre',
    'retroescavadeira',
    'maquina',
    'equipamento',
    'britadeira',
    'policorte',
    'lixadeira',
    'esmerilhadeira',
  ];

  /// Palavras por categoria — sem acento e comparadas por palavra inteira
  /// (o plural é aceito automaticamente).
  static const Map<CategoriaCusto, List<String>> _palavrasCategoria = {
    CategoriaCusto.maoDeObra: [
      'pedreiro',
      'servente',
      'diaria',
      'mao de obra',
      'eletricista',
      'encanador',
      'bombeiro hidraulico',
      'pintor',
      'ajudante',
      'empreiteiro',
      'carpinteiro',
      'salario',
      'pagamento do',
      'semana do',
      'gesseiro',
      'azulejista',
      'armador',
      'soldador',
      'marceneiro',
      'serralheiro',
      'jardineiro',
      'mestre de obra',
      'empreita',
      'funcionario',
      'equipe',
      'peao',
      'meio dia de trabalho',
      'vale',
    ],
    CategoriaCusto.material: [
      'cimento',
      'areia',
      'brita',
      'tijolo',
      'bloco',
      'vergalhao',
      'ferro',
      'aco',
      'madeira',
      'telha',
      'tinta',
      'cano',
      'pvc',
      'fio',
      'cabo',
      'argamassa',
      'cal',
      'piso',
      'ceramica',
      'porcelanato',
      'porta',
      'janela',
      'prego',
      'parafuso',
      'material',
      'saco',
      'massa corrida',
      'reboco',
      'gesso',
      'vidro',
      'esquadria',
      'tubo',
      'conexao',
      'granito',
      'marmore',
      'concreto',
      'laje',
      'manta',
      'impermeabilizante',
      'rejunte',
      'selador',
      'verniz',
      'disjuntor',
      'tomada',
      'interruptor',
      'registro',
      'torneira',
      'caixa d',
      'ripa',
      'caibro',
      'viga',
      'pedrisco',
      'arame',
      'lixa',
      'silicone',
      'espuma expansiva',
      'azulejo',
      'rodape',
      'eletroduto',
      'conduite',
    ],
    CategoriaCusto.equipamento: [
      'betoneira',
      'andaime',
      'furadeira',
      'serra',
      'martelete',
      'aluguel',
      'alugou',
      'aluguei',
      'locacao',
      'equipamento',
      'maquina',
      'compactador',
      'gerador',
      'escora',
      'cacamba',
      'container',
      'retroescavadeira',
      'vibrador',
      'bomba de concreto',
      'esmerilhadeira',
      'lixadeira',
      'guincho',
      'placa vibratoria',
      'britadeira',
      'policorte',
      'alugamos',
    ],
  };

  /// Sinais fortes (profissões, aluguel): pesam o dobro na classificação.
  /// "Paguei a diária do pedreiro e comprei cimento" é mão de obra,
  /// mesmo com material citado — e o cimento ainda vai para o estoque.
  static const List<String> _sinaisFortes = [
    'pedreiro',
    'servente',
    'diaria',
    'mao de obra',
    'eletricista',
    'encanador',
    'pintor',
    'ajudante',
    'empreiteiro',
    'carpinteiro',
    'gesseiro',
    'azulejista',
    'armador',
    'soldador',
    'salario',
    'aluguel',
    'alugou',
    'aluguei',
    'alugamos',
    'locacao',
    'empreita',
  ];

  /// Parser puro (testável): interpreta a frase transcrita.
  /// Chamado ao vivo a cada resultado parcial — precisa ser leve.
  /// [agora] fixa o "hoje" das datas relativas nos testes.
  static LancamentoPorVoz interpretar(String transcricao, {DateTime? agora}) {
    final original = transcricao.trim();
    // "verga lhão" → "vergalhão"; "trezentos e cinquenta reais" → "350 reais"
    final texto = NumeroExtenso.normalizar(VocabularioObra.corrigir(original));

    final fornecedorInfo = _extrairFornecedorInfo(texto);
    final data = DataFalada.extrair(texto, agora: agora);
    final localizados = ItensParser.localizar(texto);
    final valorInfo = ValorFalado.extrair(
      texto,
      itens: localizados,
      ignorar: [if (fornecedorInfo != null) fornecedorInfo.trecho],
    );
    final itens = _itensDoEstoque(texto, localizados, valorInfo.inicios);

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
      valor: valorInfo.valor,
      categoria: _classificarCategoria(texto),
      fornecedorNome: fornecedorInfo?.nome,
      data: data,
      itens: itens,
      transcricao: original,
    );
  }

  /// Interpreta as hipóteses do reconhecedor (a 1ª é a principal;
  /// confiança 0..1, ou <= 0 quando o aparelho não informa) e devolve o
  /// lançamento da melhor — a 1ª, a menos que outra seja claramente melhor
  /// para a obra. A transcrição do resultado é a hipótese escolhida.
  static LancamentoPorVoz interpretarHipoteses(List<(String, double)> hipoteses,
      {DateTime? agora}) {
    return HipotesesVoz.escolher<LancamentoPorVoz>(
      hipoteses,
      interpretar: (t) => interpretar(t, agora: agora),
      pontuar: pontuar,
    );
  }

  /// Quanto da frase o parser entendeu — base da escolha de hipótese.
  static double pontuar(LancamentoPorVoz r, String texto) {
    var p = 0.0;
    if (r.valor != null) p += 2;
    if (r.categoria != CategoriaCusto.outros) p += 1;
    final conhecidos =
        r.itens.where((i) => AppConstants.materiaisComuns.contains(i.material));
    p += conhecidos.length.clamp(0, 2).toDouble();
    if (r.fornecedorNome != null) p += 0.5;
    if (r.data != null) p += 0.5;
    p += 0.25 * VocabularioObra.contarTermos(texto).clamp(0, 4);
    return p;
  }

  // ------------------------------------------------------------ Itens

  /// Os itens que vão ao estoque: sem os números que eram dinheiro
  /// ("gastei 300 de cimento") e sem equipamento alugado.
  static List<ItemMaterialModel> _itensDoEstoque(
      String texto, List<ItemNoTexto> localizados, Set<int> dinheiro) {
    final aluguel = _aluguel.hasMatch(texto);
    final vistos = <String>{};
    return [
      for (final i in localizados)
        if (!dinheiro.contains(i.inicio) &&
            !(aluguel && _ehEquipamento(i.item.material)) &&
            vistos.add(i.item.material.toLowerCase()))
          i.item,
    ];
  }

  static bool _ehEquipamento(String material) =>
      TextoBr.primeiroQueCasa(TextoBr.normalizar(material), _equipamentos) !=
      null;

  // -------------------------------------------------------- Fornecedor

  static _FornecedorInfo? _extrairFornecedorInfo(String texto) {
    final normalizado = TextoBr.normalizar(texto);
    for (final rede in _redesConhecidas) {
      if (!TextoBr.contemPalavra(normalizado, rede)) continue;
      final inicio = normalizado.indexOf(rede);
      // "na casa do construtor": a preposição sai junto da descrição.
      final preposicao =
          _preposicaoAntes.firstMatch(normalizado.substring(0, inicio));
      return _FornecedorInfo(_capitalizarNome(rede),
          (preposicao?.start ?? inicio, inicio + rede.length));
    }

    for (final padrao in [_fornecedorComTipo, _fornecedorCapitalizado]) {
      for (final m in padrao.allMatches(texto)) {
        final bruto = m.group(1)!;
        final inicioGrupo = m.end - bruto.length;
        final (nome, fim) = _cortarNome(bruto);
        if (nome.length < 3) continue;
        if (_nomeGenerico(nome)) continue;
        return _FornecedorInfo(
            _capitalizarNome(nome), (m.start, inicioGrupo + fim));
      }
    }
    return null;
  }

  static final RegExp _preposicaoAntes =
      RegExp(r'(?<![a-z0-9])(?:(?:la|ali)\s+)?(?:n[oa]|d[oa]|em|pel[oa])\s+$');

  /// Nome feito só de tipo de loja, do que ela vende e de onde fica
  /// ("loja de material de construção", "ferragista do bairro").
  static bool _nomeGenerico(String nome) => TextoBr.normalizar(nome)
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty && !_conectoresDoNome.contains(p))
      .every(_naoFornecedor.contains);

  /// O nome do fornecedor até onde ele termina, e a posição desse fim
  /// dentro de [bruto]. Nome é: o tipo ("madeireira"), nomes próprios e
  /// "do/da" + nome ("do Zé"); para no primeiro verbo, artigo, número,
  /// data ou material solto.
  static (String, int) _cortarNome(String bruto) {
    final palavras = RegExp(r"[\wà-ÿÀ-Ý']+").allMatches(bruto).toList();
    var ultima = -1;
    for (var i = 0; i < palavras.length && i < 8; i++) {
      final n = TextoBr.normalizar(palavras[i].group(0)!);
      final depoisDeConector =
          i > 0 && _conectoresDoNome.contains(_norm(palavras[i - 1]));
      if (_conectoresDoNome.contains(n)) {
        // "do" só fica se vier um nome depois dele.
        if (i + 1 >= palavras.length) break;
        final seguinte = _norm(palavras[i + 1]);
        if (_fimDoFornecedor.contains(seguinte) ||
            _pareceVerbo.hasMatch(seguinte) ||
            RegExp(r'\d').hasMatch(seguinte)) {
          break;
        }
        continue;
      }
      if (i > 0 &&
          (_fimDoFornecedor.contains(n) ||
              _pareceVerbo.hasMatch(n) ||
              RegExp(r'\d').hasMatch(n) ||
              (!depoisDeConector && _materiaisNoFornecedor.contains(n)))) {
        break;
      }
      ultima = i;
    }
    if (ultima < 0) return ('', 0);
    final fim = palavras[ultima].end;
    return (bruto.substring(palavras.first.start, fim), fim);
  }

  static String _norm(RegExpMatch m) => TextoBr.normalizar(m.group(0)!);

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
    final t = TextoBr.normalizar(texto);
    var melhor = CategoriaCusto.outros;
    var melhorPontos = 0;
    for (final entry in _palavrasCategoria.entries) {
      var pontos = 0;
      for (final palavra in entry.value) {
        if (!TextoBr.contemPalavra(t, palavra)) continue;
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

    // Trechos sobrepostos (a negociação inteira contém o valor) viram um
    // só, para a remoção de um não deslocar a do outro.
    final ordenados = List<(int, int)>.from(remover)
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final unidos = <(int, int)>[];
    for (final (inicio, fim) in ordenados) {
      if (inicio < 0 || fim > d.length || inicio >= fim) continue;
      if (unidos.isNotEmpty && inicio <= unidos.last.$2) {
        final ultimo = unidos.removeLast();
        unidos.add((ultimo.$1, fim > ultimo.$2 ? fim : ultimo.$2));
      } else {
        unidos.add((inicio, fim));
      }
    }
    for (final (inicio, fim) in unidos.reversed) {
      d = d.replaceRange(inicio, fim, ' ');
    }

    if (removerData) {
      for (final padrao in DataFalada.padroesLimpeza) {
        d = d.replaceFirst(padrao, ' ');
      }
    }

    d = d.replaceFirst(_aberturas, '');
    // conectores órfãos nas pontas ("de", "no", "por", "e"…)
    final orfaos = RegExp(
        r'^(?:de|do|da|no|na|em|por|com|e|a|o|ao|mas|mais|,|\.)\s+',
        caseSensitive: false);
    // ... e a fala de enchimento que sobra no fim ("andaime tá").
    final orfaosFim = RegExp(
        r'\s+(?:de|do|da|no|na|em|por|com|e|a|o|ao|que|mas|mais|t[aá]|n[eé]|'
        r'viu|ok|certo|beleza|blz|entendeu|hein|t[aá]\s+bom|e\s+tal|sabe|'
        r'l[aá]|a[ií]|ent[aã]o|ele|ela|,|\.)$',
        caseSensitive: false);
    var anterior = '';
    while (anterior != d) {
      anterior = d;
      d = d.trim().replaceFirst(orfaos, '').trim();
      d = d.replaceFirst(orfaosFim, '').trim();
      d = d.replaceAllMapped(RegExp(r'\s+([,.;])'), (m) => m.group(1)!);
      d = d.replaceFirst(RegExp(r'^[,.;]\s*'), '');
      d = d.replaceFirst(RegExp(r'\s*[,;]$'), '');
    }
    d = d.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    if (d.length < 3) {
      if (itens.isNotEmpty) {
        return itens.map((i) => i.resumo).join(' e ');
      }
      d = texto.trim();
      if (d.isEmpty) return '';
    }
    return d[0].toUpperCase() + d.substring(1);
  }
}

class _FornecedorInfo {
  final String nome;
  final (int, int) trecho;

  const _FornecedorInfo(this.nome, this.trecho);
}
