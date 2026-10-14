import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'diario_foto_service.dart' show RotuloFoto;
import 'texto_br.dart';

export 'diario_foto_service.dart' show RotuloFoto;

class MaterialDetectado {
  /// Nome do material em português (ex.: "Tijolo").
  final String material;

  /// De onde veio a leitura: o rótulo original do modelo de visão (ex.:
  /// "Brick") ou o trecho lido na embalagem (ex.: `"CIMENTO" na embalagem`).
  final String labelOriginal;

  /// 0 a 1.
  final double confianca;

  const MaterialDetectado({
    required this.material,
    required this.labelOriginal,
    required this.confianca,
  });
}

/// Termo procurado no texto da embalagem e o quanto ele prova o material.
///
/// Peso perto de 1 é o nome do produto ("CIMENTO", "ARGAMASSA"); perto de
/// 0,8, uma marca ou código que só existe naquele produto ("Votoran",
/// "CA-50"); 0,25, uma palavra que aparece em outros produtos e só ajuda a
/// desempatar ("Nacional", "cerâmico", a marca que vende de tudo, como
/// Tigre ou Gerdau) — sozinha ela fica abaixo do corte para listar.
class _Termo {
  final String texto;
  final double peso;

  /// Aceita o plural ("argamassas", "telhas"). Desligado onde o plural é
  /// outra coisa: "Votorantim Cimentos" é a empresa, não o produto.
  final bool plural;

  const _Termo(this.texto, this.peso, {this.plural = true});
}

/// IA on-device nº 1 — reconhecimento de material pela câmera.
///
/// Junta duas leituras da mesma foto, as duas feitas no aparelho e offline
/// pelo Google ML Kit: o classificador de imagens (rótulos genéricos em
/// inglês, como "Brick" ou "Metal") e o OCR do texto impresso na
/// embalagem. O texto é a evidência mais forte: o classificador vê uma lata
/// e diz "Metal", mas a lata diz "TINTA ACRÍLICA".
class MaterialVisionService {
  /// Abaixo disso o rótulo do classificador é ruído. É o mesmo corte do
  /// [ImageLabeler] — vale também em [interpretar], para que a parte pura
  /// dê o mesmo resultado que a câmera.
  static const double confiancaMinima = 0.45;

  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: confiancaMinima),
  );
  final TextRecognizer _leitor =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Analisa a foto e retorna os materiais reconhecidos, do mais
  /// provável para o menos.
  Future<List<MaterialDetectado>> reconhecer(String caminhoImagem) async {
    final input = InputImage.fromFilePath(caminhoImagem);
    // Os dois modelos leem a mesma foto ao mesmo tempo. O OCR é a segunda
    // opinião: se falhar, o classificador sozinho ainda responde, como
    // era antes.
    final textoLido = _leitor
        .processImage(input)
        .then((lido) => lido.text)
        .onError((_, __) => '');
    final labels = await _labeler.processImage(input);
    return interpretar(
      [for (final l in labels) RotuloFoto(l.label, l.confidence)],
      texto: await textoLido,
    );
  }

  void dispose() {
    _labeler.close();
    _leitor.close();
  }

  // ------------------------------------------------------------- Parser

  /// Abaixo disso o material não é listado: melhor o campo vazio do que um
  /// palpite que o usuário pode nem perceber que está errado.
  static const double _confiancaParaListar = 0.30;

  /// Rótulo do classificador → (material, peso).
  ///
  /// Peso 1 = o rótulo só tem uma leitura no estoque. Até
  /// [_pesoDeRotuloGenerico], o rótulo também descreve embalagem ou objeto
  /// comum: "Metal" é o vergalhão, mas também a lata de tinta e a porta de
  /// aço; "Roof" é a telha, mas também qualquer coisa fotografada de cima.
  static const Map<String, (String, double)> _rotulos = {
    'brick': ('Tijolo', 1),
    'brickwork': ('Tijolo', 1),
    'cinder block': ('Bloco de concreto', 1),
    'wood': ('Madeira', 1),
    'lumber': ('Madeira', 1),
    'plank': ('Madeira', 1),
    'plywood': ('Madeira', 1),
    'cement': ('Cimento', 1),
    'sand': ('Areia', 1),
    'gravel': ('Brita', 1),
    'rock': ('Brita', 0.7),
    'stone': ('Brita', 0.7),
    'rebar': ('Vergalhão de aço', 1),
    'metal': ('Vergalhão de aço', 0.5),
    'steel': ('Vergalhão de aço', 0.5),
    'iron': ('Vergalhão de aço', 0.5),
    'wire': ('Fio elétrico', 0.8),
    'cable': ('Fio elétrico', 0.8),
    'pipe': ('Cano PVC', 1),
    'plumbing': ('Cano PVC', 1),
    'tile': ('Piso cerâmico', 1),
    'flooring': ('Piso cerâmico', 1),
    'shingle': ('Telha', 1),
    'roof tile': ('Telha', 1),
    'roof': ('Telha', 0.6),
    'paint': ('Tinta', 1),
    'door': ('Porta', 1),
    'window': ('Janela', 1),
  };

  /// Rótulo com peso até aqui descreve o objeto, não o material: só vale
  /// quando a foto não tem texto legível que diga outra coisa.
  static const double _pesoDeRotuloGenerico = 0.7;

  /// Nenhum rótulo do classificador passa disto: ele foi treinado em fotos
  /// do dia a dia, não de canteiro, e o nome impresso na embalagem é mais
  /// específico do que qualquer rótulo dele.
  static const double _tetoDoRotulo = 0.85;

  /// Nem o texto dá certeza absoluta: o OCR também lê errado.
  static const double _tetoDaConfianca = 0.98;

  /// O que a embalagem diz → material. Texto comparado sem acento, por
  /// palavra inteira (com plural), já com a pontuação trocada por espaço:
  /// "CP-II", "CP II" e "cp ii" são o mesmo termo.
  static const Map<String, List<_Termo>> _termos = {
    'Cimento': [
      _Termo('cimento', 1, plural: false),
      _Termo('portland', 0.9),
      _Termo('cp i', 0.85),
      _Termo('cp ii', 0.85),
      _Termo('cp iii', 0.85),
      _Termo('cp iv', 0.85),
      _Termo('cp v', 0.85),
      _Termo('cpi', 0.85),
      _Termo('cpii', 0.85),
      _Termo('cpiii', 0.85),
      _Termo('cpiv', 0.85),
      _Termo('cpv', 0.85),
      _Termo('votoran', 0.8),
      _Termo('itambe', 0.8),
      _Termo('caue', 0.8),
      _Termo('tupi', 0.8),
      _Termo('mizu', 0.8),
      _Termo('ciplan', 0.8),
      _Termo('holcim', 0.8),
      // "Nacional" é marca de cimento e também "indústria nacional" em
      // qualquer rótulo: sozinho, só desempata.
      _Termo('nacional', 0.25),
    ],
    'Argamassa': [
      _Termo('argamassa', 1),
      _Termo('ac i', 0.85),
      _Termo('ac ii', 0.85),
      _Termo('ac iii', 0.85),
      _Termo('aci', 0.85),
      _Termo('acii', 0.85),
      _Termo('aciii', 0.85),
      _Termo('quartzolit', 0.8),
      _Termo('precon', 0.8),
      _Termo('votomassa', 0.8),
      _Termo('cimentcola', 0.8),
    ],
    'Tinta': [
      _Termo('tinta', 1),
      _Termo('acrilica', 0.85),
      _Termo('acrilico', 0.85),
      _Termo('latex', 0.9),
      _Termo('esmalte', 0.9),
      _Termo('suvinil', 0.8),
      _Termo('coral', 0.8),
      _Termo('sherwin williams', 0.8),
      _Termo('lukscolor', 0.8),
      _Termo('iquine', 0.8),
    ],
    'Cano PVC': [
      _Termo('cano', 1),
      _Termo('pvc', 0.85),
      _Termo('esgoto', 0.8),
      _Termo('soldavel', 0.9),
      // "Tubo" é também a embalagem de selante e silicone, e Tigre, Amanco
      // e Krona vendem caixa d'água e conexão: sozinhos, só desempatam.
      _Termo('tubo', 0.25),
      _Termo('tigre', 0.25),
      _Termo('amanco', 0.25),
      _Termo('krona', 0.25),
    ],
    'Vergalhão de aço': [
      _Termo('vergalhao', 1),
      _Termo('ca 50', 0.9),
      _Termo('ca 60', 0.9),
      _Termo('ca50', 0.9),
      _Termo('ca60', 0.9),
      // Usinas que vendem também arame, prego e tela.
      _Termo('gerdau', 0.25),
      _Termo('arcelormittal', 0.25),
      _Termo('arcelor', 0.25),
      _Termo('belgo', 0.25),
    ],
    'Fio elétrico': [
      _Termo('fio', 1),
      _Termo('cabo flexivel', 1),
      _Termo('fio flexivel', 1),
      _Termo('cabo', 0.6),
      _Termo('mm2', 0.8),
      _Termo('sil', 0.8),
      _Termo('corfio', 0.8),
      _Termo('prysmian', 0.8),
      _Termo('cobrecom', 0.8),
      _Termo('induscabos', 0.8),
    ],
    'Cal': [
      _Termo('cal hidratada', 1),
      _Termo('cal virgem', 1),
      _Termo('cal', 0.85),
      _Termo('ch i', 0.8),
      _Termo('ch ii', 0.8),
      _Termo('ch iii', 0.8),
    ],
    'Piso cerâmico': [
      _Termo('piso', 1),
      _Termo('porcelanato', 1),
      _Termo('azulejo', 0.9),
      _Termo('pei', 0.9),
      _Termo('revestimento', 0.6),
      // Cerâmica também é telha e bloco: o adjetivo sozinho só desempata.
      _Termo('ceramica', 0.25),
      _Termo('ceramico', 0.25),
      _Termo('eliane', 0.8),
      _Termo('portobello', 0.8),
      _Termo('cecrisa', 0.8),
      _Termo('portinari', 0.8),
      _Termo('incepa', 0.8),
      _Termo('biancogres', 0.8),
      _Termo('ceusa', 0.8),
    ],
    'Telha': [
      _Termo('telha', 1),
      _Termo('fibrocimento', 0.9),
      _Termo('cumeeira', 0.8),
      // Tipo impresso na peça: com a marca valendo só desempate, é o que
      // reconhece a telha que não traz a palavra "telha".
      _Termo('ondulada', 0.8),
      // Também fabricam caixa d'água.
      _Termo('eternit', 0.25),
      _Termo('brasilit', 0.25),
      _Termo('imbralit', 0.25),
    ],
    'Bloco de concreto': [
      _Termo('bloco de concreto', 1),
      _Termo('blocos de concreto', 1),
      _Termo('bloco concreto', 1),
      _Termo('bloco estrutural', 0.6),
    ],
    'Tijolo': [
      _Termo('tijolo', 1),
      _Termo('tijolinho', 1),
      _Termo('bloco ceramico', 1),
      _Termo('blocos ceramicos', 1),
      _Termo('furos', 0.6),
    ],
    'Areia': [
      _Termo('areia', 1),
    ],
    'Brita': [
      _Termo('brita', 1),
      _Termo('pedra britada', 1),
      _Termo('pedrisco', 0.8),
    ],
    'Madeira': [
      _Termo('madeira', 1),
      _Termo('compensado', 0.9),
      _Termo('pinus', 0.8),
      _Termo('eucalipto', 0.8),
      _Termo('sarrafo', 0.8),
      _Termo('caibro', 0.8),
      _Termo('tabua', 0.8),
      _Termo('ripa', 0.7),
      _Termo('osb', 0.8),
    ],
    'Porta': [
      _Termo('porta', 0.9),
    ],
    'Janela': [
      _Termo('janela', 0.9),
      _Termo('basculante', 0.7),
    ],
  };

  /// Palavras que, numa linha, transformam o que vem depois em modo de
  /// uso ou composição: "ideal PARA argamassa", "à BASE de cimento",
  /// "assentar COM argamassa colante", "ISOLAÇÃO PVC". O que vem antes
  /// delas é o nome do produto; o que vem depois é só citado — e a
  /// embalagem de um produto cita vários outros.
  static const List<String> _deixasDeUso = [
    'para',
    'com',
    'sobre',
    'base',
    'contem',
    'composicao',
    'indicado',
    'indicada',
    'ideal',
    'utilizar',
    'utilize',
    'usar',
    'use',
    'aplicar',
    'aplique',
    'assentar',
    'assente',
    'misturar',
    'misture',
    'rende',
    'rendimento',
    'isolacao',
    'isolamento',
    'isolado',
    'isolada',
    // Cabeçalhos da lista de usos: "Uso: concretos, argamassas".
    'uso',
    'aplicacao',
    'aplicacoes',
    'indicacao',
    'indicacoes',
  ];

  /// Quantas linhas abaixo de um cabeçalho de uso ("Indicado para:")
  /// ainda são a lista. Passar do fim da lista só deixa de listar o que
  /// vem depois (o campo fica vazio); parar antes deixa um material citado
  /// valer como o produto, e esse vai para o campo.
  static const int _linhasDaLista = 4;

  /// Peso máximo de um material só citado. Fica abaixo do corte de
  /// [_confiancaParaListar]: citação desempata, nunca lista sozinha.
  static const double _pesoCitacao = 0.25;

  /// Parte pura da IA — rótulos do classificador + texto lido na
  /// embalagem → materiais, do mais provável ao menos provável.
  static List<MaterialDetectado> interpretar(
    List<RotuloFoto> rotulos, {
    String texto = '',
  }) {
    final evidencias = <String, _Evidencia>{};
    _Evidencia de(String material) =>
        evidencias.putIfAbsent(material, () => _Evidencia(material));

    // ----- Texto da embalagem
    final linhas = _linhasNormalizadas(texto);
    // O OCR devolve cada linha impressa separada, e a lista de usos quase
    // nunca cabe na linha da deixa: "Indicado para:" numa linha, "reboco,
    // concreto, blocos de concreto," e "telhas" nas de baixo. Por isso a
    // citação passa para as linhas seguintes enquanto a lista continua.
    var linhasDeLista = 0;
    for (var n = 0; n < linhas.length; n++) {
      final (:linha, :continua) = linhas[n];
      final corte = _inicioDoUso(linha);
      // Linha com deixa própria começa outra frase e é lida por ela; a
      // quantidade ("3,6 L", "50 kg") encerra a lista.
      final herdada =
          linhasDeLista > 0 && corte == -1 && !RegExp('^[0-9]').hasMatch(linha);
      for (final entrada in _termos.entries) {
        for (final termo in entrada.value) {
          final posicao =
              _posicaoDaPalavra(linha, termo.texto, plural: termo.plural);
          if (posicao == -1) continue;
          de(entrada.key).somarTexto(
            termo,
            citado: herdada || (corte != -1 && posicao > corte),
            posicao: n * 1000 + posicao,
          );
        }
      }
      if (corte != -1 && _deixasDeUso.contains(linha.split(' ').last)) {
        // Cabeçalho: a deixa fecha a linha e a lista vem embaixo.
        linhasDeLista = _linhasDaLista;
      } else if (herdada) {
        linhasDeLista--;
      } else {
        linhasDeLista = 0;
      }
      // Linha citada que termina em vírgula ou "e" segue na de baixo.
      if ((corte != -1 || herdada) && continua && linhasDeLista < 1) {
        linhasDeLista = 1;
      }
    }

    // Texto legível que não fala do material de um rótulo genérico "diz
    // outra coisa": o "Metal" é a lata, o "Roof" é o ângulo da foto. Duas
    // palavras de verdade bastam — vergalhão de obra não vem com texto
    // impresso que não seja a etiqueta dele mesmo.
    final palavras = linhas
        .expand((l) => l.linha.split(' '))
        .where((p) => RegExp('[a-z]').allMatches(p).length >= 3);
    final textoLegivel = palavras.length >= 2;

    // ----- Classificador
    for (final r in rotulos) {
      if (r.confianca < confiancaMinima) continue;
      final mapeado = _rotulos[r.label.toLowerCase().trim()];
      if (mapeado == null) continue;
      final (material, peso) = mapeado;
      // Só confirma o texto que listaria o material sozinho: a palavra que
      // só desempata ("BELGO" no arame) não transforma a lata ou o rolo
      // de arame do "Metal" em vergalhão.
      final textoConfirma =
          (evidencias[material]?.doProduto ?? 0) >= _confiancaParaListar;
      if (peso <= _pesoDeRotuloGenerico && textoLegivel && !textoConfirma) {
        continue;
      }
      de(material).somarRotulo(
        r.label,
        (r.confianca * peso).clamp(0.0, _tetoDoRotulo),
        especifico: peso > _pesoDeRotuloGenerico,
      );
    }

    // Pelo mesmo motivo, quando alguma coisa na foto aponta um material
    // com clareza (o nome na embalagem ou um rótulo específico como
    // "Paint"), o rótulo genérico que sobrou é a embalagem: a lata de
    // tinta é "Metal", e listar vergalhão como alternativa só confunde.
    if (evidencias.values.any((e) => !e.soGenerica)) {
      evidencias.removeWhere((_, e) => e.soGenerica);
    }

    // Parede de bloco: "Concrete" junto de um rótulo de alvenaria é o
    // bloco de concreto, não o tijolo — o que a foto do diário faz com a
    // cor cinza, aqui feito com o rótulo.
    final concreto = _maiorConfianca(rotulos, 'concrete');
    final tijolo = evidencias['Tijolo'];
    if (concreto >= confiancaMinima &&
        tijolo != null &&
        tijolo.doTexto == 0 &&
        tijolo.doRotulo > 0) {
      evidencias.remove('Tijolo');
      de('Bloco de concreto').somarRotulo(
        'Concrete + ${tijolo.melhorFonte}',
        tijolo.doRotulo < concreto ? tijolo.doRotulo : concreto,
        especifico: true,
      );
    }

    final detectados = [
      for (final e in evidencias.values)
        if (e.confianca >= _confiancaParaListar) e,
    ]..sort((a, b) {
        final porConfianca = b.confianca.compareTo(a.confianca);
        if (porConfianca != 0) return porConfianca;
        // Empate: o que a embalagem cita primeiro costuma ser o nome do
        // produto, em letra grande no alto.
        return a.primeiraPosicao.compareTo(b.primeiraPosicao);
      });
    return [
      for (final e in detectados)
        MaterialDetectado(
          material: e.material,
          labelOriginal: e.melhorFonte,
          confianca: e.confianca.clamp(0.0, _tetoDaConfianca),
        ),
    ];
  }

  static double _maiorConfianca(List<RotuloFoto> rotulos, String chave) {
    var maior = 0.0;
    for (final r in rotulos) {
      if (r.label.toLowerCase().trim() == chave && r.confianca > maior) {
        maior = r.confianca;
      }
    }
    return maior;
  }

  /// Texto do OCR → linhas sem acento, em minúsculas, com pontuação e
  /// hífen trocados por espaço ("CP-II-F" vira "cp ii f", "mm²" vira
  /// "mm2") e com os dígitos que o OCR troca por letra corrigidos dentro
  /// das palavras ("CIMENT0" vira "cimento").
  ///
  /// [continua] diz se a frase segue na linha de baixo — termina em
  /// vírgula, ponto e vírgula, "e" ou "ou" —, o que só dá para ver antes
  /// de a pontuação sumir.
  static List<({String linha, bool continua})> _linhasNormalizadas(
      String texto) {
    final linhas = <({String linha, bool continua})>[];
    for (final bruta in texto.split(RegExp(r'[\n\r]+'))) {
      final limpa = TextoBr.normalizar(bruta)
          .replaceAll('²', '2')
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      if (limpa.isEmpty) continue;
      final palavras = limpa.split(' ').map(_corrigirLetras).toList();
      final continua = RegExp(r'[,;]\s*$').hasMatch(bruta) ||
          palavras.last == 'e' ||
          palavras.last == 'ou';
      linhas.add((linha: palavras.join(' '), continua: continua));
    }
    return linhas;
  }

  /// Numa palavra que é quase toda letra, o dígito no meio é uma letra
  /// lida errado. Código como "CA50" ou "mm2" fica como está: ali o dígito
  /// é dígito.
  static String _corrigirLetras(String palavra) {
    final letras = RegExp('[a-z]').allMatches(palavra).length;
    final digitos = palavra.length - letras;
    if (digitos == 0 || letras < 4 || digitos * 3 > letras) return palavra;
    const trocas = {'0': 'o', '1': 'i', '5': 's'};
    return palavra.split('').map((c) => trocas[c] ?? c).join();
  }

  /// Posição da primeira deixa de uso na linha, ou -1.
  static int _inicioDoUso(String linha) {
    var primeira = -1;
    for (final deixa in _deixasDeUso) {
      final posicao = _posicaoDaPalavra(linha, deixa);
      if (posicao != -1 && (primeira == -1 || posicao < primeira)) {
        primeira = posicao;
      }
    }
    return primeira;
  }

  /// Onde [termo] aparece em [linha] como palavra inteira — aceitando o
  /// plural, como [TextoBr.contemPalavra], se [plural] —, ou -1. A linha já
  /// vem de [_linhasNormalizadas]: palavras separadas por um espaço só.
  static int _posicaoDaPalavra(String linha, String termo,
      {bool plural = true}) {
    var i = linha.indexOf(termo);
    while (i != -1) {
      final fim = i + termo.length;
      final comeca = i == 0 || linha.codeUnitAt(i - 1) == 32;
      var fimDaPalavra = linha.indexOf(' ', fim);
      if (fimDaPalavra == -1) fimDaPalavra = linha.length;
      final sobra = linha.substring(fim, fimDaPalavra);
      if (comeca &&
          (sobra.isEmpty || (plural && (sobra == 's' || sobra == 'es')))) {
        return i;
      }
      i = linha.indexOf(termo, i + 1);
    }
    return -1;
  }
}

/// Tudo que apontou para um material: o que o texto disse e o que o
/// classificador viu, guardados separados porque pesam diferente.
class _Evidencia {
  final String material;

  /// Prova do texto em posição de nome de produto (0 a 1), somando termos
  /// independentes.
  double doProduto = 0;

  /// Maior citação do material em modo de uso ou composição.
  double doCitado = 0;

  /// Melhor rótulo do classificador para este material (0 a 1).
  double doRotulo = 0;

  /// Algum rótulo específico (não genérico como "Metal") apontou para cá.
  bool _rotuloEspecifico = false;

  /// Onde o material apareceu primeiro no texto (linha e coluna).
  int primeiraPosicao = 1 << 30;

  final Set<String> _termosVistos = {};
  String _fonteTexto = '';
  double _maiorTermo = 0;
  String _fonteRotulo = '';

  _Evidencia(this.material);

  double get doTexto => 1 - (1 - doProduto) * (1 - doCitado);

  /// Texto e imagem concordando valem mais do que cada um sozinho.
  double get confianca => 1 - (1 - doTexto) * (1 - doRotulo);

  String get melhorFonte => doTexto >= doRotulo && _fonteTexto.isNotEmpty
      ? _fonteTexto
      : _fonteRotulo;

  void somarTexto(_Termo termo, {required bool citado, required int posicao}) {
    if (posicao < primeiraPosicao) primeiraPosicao = posicao;
    if (citado) {
      final peso = termo.peso * MaterialVisionService._pesoCitacao;
      if (peso > doCitado) doCitado = peso;
    } else {
      // Termo repetido na embalagem não é prova nova. Termos diferentes
      // são: cada um cobre parte do que falta para a certeza.
      if (!_termosVistos.add(termo.texto)) return;
      doProduto = 1 - (1 - doProduto) * (1 - termo.peso);
    }
    final peso =
        citado ? termo.peso * MaterialVisionService._pesoCitacao : termo.peso;
    if (peso > _maiorTermo) {
      _maiorTermo = peso;
      _fonteTexto = '"${termo.texto.toUpperCase()}" na embalagem';
    }
  }

  /// Só rótulo genérico, sem nada no texto: a leitura mais fraca que há.
  bool get soGenerica => doTexto == 0 && !_rotuloEspecifico;

  void somarRotulo(String rotulo, double peso, {required bool especifico}) {
    if (especifico) _rotuloEspecifico = true;
    if (peso <= doRotulo) return;
    doRotulo = peso;
    _fonteRotulo = rotulo;
  }
}
