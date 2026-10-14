import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../constants/app_constants.dart';
import 'cores_foto.dart';
import 'modelo_fases.dart';

/// Rótulo devolvido pelo modelo de visão, já num formato testável.
class RotuloFoto {
  final String label;
  final double confianca;

  const RotuloFoto(this.label, this.confianca);
}

/// O que a IA enxergou na foto do canteiro.
class AnaliseFotoDiario {
  /// Materiais de construção reconhecidos, do mais confiante ao menos.
  final List<String> materiais;

  /// Fase provável da obra, quando a cena permite deduzir.
  final String? faseSugerida;

  /// Clima provável, deduzido do céu que aparece na foto.
  final String? climaSugerido;

  /// A foto mostra gente trabalhando (o modelo não conta quantas).
  final bool temPessoas;

  /// Rascunho de descrição para o campo do diário — o usuário edita.
  final String descricaoSugerida;

  /// Tudo que o modelo devolveu, para a tela mostrar "o que a IA viu".
  final List<RotuloFoto> rotulos;

  /// Composição de cores da foto — a evidência que não vem do modelo.
  final PaletaObra paleta;

  /// Quanta evidência sustentou a fase sugerida (0 a 1). Abaixo de 0,5 a
  /// tela avisa que é só um palpite.
  final double confiancaFase;

  const AnaliseFotoDiario({
    this.materiais = const [],
    this.faseSugerida,
    this.climaSugerido,
    this.temPessoas = false,
    this.descricaoSugerida = '',
    this.rotulos = const [],
    this.paleta = const PaletaObra(),
    this.confiancaFase = 0,
  });

  bool get encontrouAlgo =>
      materiais.isNotEmpty ||
      faseSugerida != null ||
      climaSugerido != null ||
      temPessoas;
}

/// IA on-device nº 6 — leitura da foto do canteiro para o diário.
///
/// Usa o classificador de imagens do ML Kit (TensorFlow Lite embarcado,
/// offline) e traduz os rótulos genéricos do modelo para o vocabulário da
/// obra: material aparente, fase provável, clima do céu e presença de
/// equipe. O resultado é um rascunho do registro do dia — nunca um
/// registro pronto, porque a foto sozinha não sabe o que foi feito.
///
/// O modelo é de uso geral, não de construção: ele chama de "Roof"
/// qualquer estrutura vista de cima e de "Wire" qualquer tela de aço.
/// Por isso rótulo ambíguo aqui não decide nada sozinho — precisa de um
/// segundo rótulo que confirme a leitura.
///
/// Quando o app traz um modelo treinado com as fotos da obra
/// ([ModeloFases]), ele roda junto do modelo base e os rótulos dele — as
/// próprias fases, como "fundacao" — entram como evidência forte.
class DiarioFotoService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.40),
  );

  /// Classificador do modelo próprio, criado na primeira foto se o app tiver
  /// o modelo.
  ImageLabeler? _labelerProprio;

  /// O modelo próprio falhou (ou não existe): não tenta de novo nesta tela.
  bool _semModeloProprio = false;

  Future<AnaliseFotoDiario> analisar(String caminhoImagem) async {
    final input = InputImage.fromFilePath(caminhoImagem);
    final labels = await _labeler.processImage(input);
    final proprios = await _rotulosDoModeloProprio(input);
    // A análise de cor roda em paralelo ao modelo e não pode derrubar a
    // leitura: sem ela sobra o classificador, como era antes.
    PaletaObra paleta = const PaletaObra();
    try {
      paleta = await CoresFoto.analisarArquivo(
          await File(caminhoImagem).readAsBytes());
    } catch (_) {}

    return interpretar(
      [
        for (final l in labels) RotuloFoto(l.label, l.confidence),
        ...proprios,
      ],
      paleta: paleta,
    );
  }

  /// Rótulos do modelo próprio, ou nada. Nunca lança: modelo ausente,
  /// corrompido ou incompatível com o ML Kit deixa a leitura com o modelo
  /// base, como era antes de existir modelo próprio.
  Future<List<RotuloFoto>> _rotulosDoModeloProprio(InputImage input) async {
    if (_semModeloProprio) return const [];
    try {
      final caminho = await ModeloFases.caminhoLocal();
      if (caminho == null) {
        _semModeloProprio = true;
        return const [];
      }
      _labelerProprio ??= ImageLabeler(
        options: LocalLabelerOptions(
          modelPath: caminho,
          confidenceThreshold: 0.30,
          maxCount: 3,
        ),
      );
      final labels = await _labelerProprio!.processImage(input);
      return [for (final l in labels) RotuloFoto(l.label, l.confidence)];
    } catch (e) {
      // Fica no log: é a única pista de por que o modelo treinado não
      // aparece em "Ver o que a IA viu".
      debugPrint('Modelo próprio de fases não carregou: $e');
      _semModeloProprio = true;
      return const [];
    }
  }

  void dispose() {
    _labeler.close();
    _labelerProprio?.close();
  }

  // ------------------------------------------------------------- Parser

  /// Rótulos que só têm uma leitura possível no canteiro.
  ///
  /// Tijolo, concreto e telha ficam de fora de propósito: o mesmo rótulo
  /// quer dizer materiais diferentes conforme o resto da cena (ver
  /// [_materialDoRotulo]).
  static const Map<String, String> _materiaisDiretos = {
    'wood': 'Madeira',
    'lumber': 'Madeira',
    'plank': 'Madeira',
    'plywood': 'Madeira',
    'cement': 'Cimento',
    'sand': 'Areia',
    'gravel': 'Brita',
    'rock': 'Brita',
    'stone': 'Brita',
    'metal': 'Vergalhão de aço',
    'steel': 'Vergalhão de aço',
    'iron': 'Vergalhão de aço',
    'rebar': 'Vergalhão de aço',
    'pipe': 'Cano PVC',
    'plumbing': 'Cano PVC',
    'tile': 'Piso cerâmico',
    'flooring': 'Piso cerâmico',
    'paint': 'Tinta',
    'door': 'Porta',
    'window': 'Janela',
    'glass': 'Vidro',
  };

  /// Rótulos ambíguos: só viram material se outro rótulo confirmar.
  ///
  /// "Floor" num contrapiso é concreto, não piso cerâmico; e "Wire" numa
  /// armação de ferragem é o próprio vergalhão, não fio elétrico.
  static const Map<String, (String, List<String>)> _materiaisCorroborados = {
    'floor': ('Piso cerâmico', ['tile', 'flooring']),
    'wire': ('Fio elétrico', ['cable', 'electricity', 'socket', 'switch']),
    'cable': ('Fio elétrico', ['wire', 'electricity', 'socket', 'switch']),
  };

  /// Rótulo → (fase provável, peso da evidência).
  ///
  /// Peso 3 = evidência forte, específica daquela etapa. Peso 1 = indício
  /// fraco, que o modelo genérico erra com facilidade. Como a fase precisa
  /// de 2 pontos, nenhum indício fraco sugere fase sozinho.
  static const Map<String, (String, int)> _fases = {
    // Fundação
    'excavation': ('Fundação', 3),
    'trench': ('Fundação', 3),
    'foundation': ('Fundação', 3),
    'digging': ('Fundação', 3),
    'soil': ('Fundação', 2),
    'dirt': ('Fundação', 2),
    'mud': ('Fundação', 1),
    'ground': ('Fundação', 1),
    'clay': ('Fundação', 1),
    // Estrutura
    'rebar': ('Estrutura', 3),
    'formwork': ('Estrutura', 3),
    'concrete': ('Estrutura', 2),
    'scaffolding': ('Estrutura', 2),
    'beam': ('Estrutura', 2),
    'column': ('Estrutura', 2),
    'metal': ('Estrutura', 1),
    'steel': ('Estrutura', 1),
    'iron': ('Estrutura', 1),
    // Alvenaria
    'brick': ('Alvenaria', 3),
    'brickwork': ('Alvenaria', 3),
    'masonry': ('Alvenaria', 3),
    'cinder block': ('Alvenaria', 3),
    'wall': ('Alvenaria', 1),
    // Cobertura
    'shingle': ('Cobertura', 3),
    'roof tile': ('Cobertura', 3),
    'roof': ('Cobertura', 1),
    'rooftop': ('Cobertura', 1),
    'ceiling': ('Cobertura', 1),
    // Instalações
    'plumbing': ('Instalações hidráulicas', 3),
    'pipe': ('Instalações hidráulicas', 3),
    'socket': ('Instalações elétricas', 3),
    'switch': ('Instalações elétricas', 3),
    'wire': ('Instalações elétricas', 1),
    'cable': ('Instalações elétricas', 1),
    // Acabamentos
    'tile': ('Revestimentos', 3),
    'flooring': ('Revestimentos', 2),
    'paint': ('Pintura', 3),
    'painting': ('Pintura', 2),
    'door': ('Acabamento', 2),
    'window': ('Acabamento', 2),
    'furniture': ('Acabamento', 1),
  };

  /// Terra à mostra na foto — o marco que separa o começo do fim da obra.
  static const List<String> _terra = [
    'soil',
    'dirt',
    'mud',
    'excavation',
    'trench',
    'digging',
    'clay',
    'ground',
  ];

  /// Chão de terra ou areia aparecendo. É o que decide se o marrom da foto
  /// pode ser solo: sem nenhum destes, o modelo não viu chão nenhum.
  static const Set<String> _solo = {
    'soil',
    'dirt',
    'mud',
    'sand',
    'ground',
    'clay',
  };

  /// Solo que pode ser vermelho (terra roxa); areia nunca é.
  static const Set<String> _soloQuePodeSerVermelho = {
    'soil',
    'dirt',
    'mud',
    'ground',
    'clay',
  };

  static const Set<String> _madeira = {'wood', 'plank', 'lumber', 'plywood'};

  static const Set<String> _alvenaria = {
    'brick',
    'brickwork',
    'masonry',
    'cinder block',
  };

  static const Set<String> _telhado = {
    'roof',
    'rooftop',
    'shingle',
    'roof tile',
  };

  /// Só existem em telhado. "Roof" sozinho, não: o modelo devolve "Roof"
  /// para laje, forma e baldrame vistos de cima.
  static const Set<String> _telhadoEspecifico = {'shingle', 'roof tile'};

  static const Set<String> _ceu = {
    'sky',
    'cloud',
    'overcast',
    'sunlight',
    'sunset',
    'sun',
  };

  static const Set<String> _cimenticio = {'concrete', 'cement'};

  /// Ferragem, madeira e forma: o que separa a estrutura do reboco.
  static const Set<String> _sinaisDeEstrutura = {
    ..._madeira,
    'metal',
    'steel',
    'iron',
    'rebar',
    'wire',
    'formwork',
    'beam',
    'column',
  };

  /// Com estes, madeira no chão é piso pronto ou móvel, não forma de laje.
  static const Set<String> _acabamento = {
    'flooring',
    'hardwood',
    'laminate flooring',
    'wood flooring',
    'parquet',
    'wood stain',
    'tile',
    'furniture',
    'paint',
    'painting',
  };

  /// O que só aparece onde há obra acontecendo. Terra sozinha pode ser um
  /// lote vazio ou um monte de areia esperando a betoneira: fundação
  /// precisa de material, ferramenta, máquina ou escavação na foto.
  static const Set<String> _indiciosDeObra = {
    ..._madeira,
    ..._alvenaria,
    ..._cimenticio,
    'metal',
    'steel',
    'iron',
    'rebar',
    'wire',
    'formwork',
    'scaffolding',
    'beam',
    'column',
    'pipe',
    'plumbing',
    'excavation',
    'trench',
    'digging',
    'foundation',
    'construction',
    'construction worker',
    'crane',
    'excavator',
    'bulldozer',
    'helmet',
    'hard hat',
    'worker',
  };

  /// Rótulo do modelo → clima aparente no céu da foto.
  static const Map<String, String> _clima = {
    'rain': 'Chuvoso',
    'storm': 'Chuva forte',
    'thunderstorm': 'Chuva forte',
    'umbrella': 'Chuvoso',
    'cloud': 'Nublado',
    'overcast': 'Nublado',
    'fog': 'Nublado',
    'sky': 'Ensolarado',
    'sunlight': 'Ensolarado',
    'sunset': 'Ensolarado',
    'sun': 'Ensolarado',
  };

  static const List<String> _pessoas = [
    'person',
    'people',
    'crowd',
    'worker',
    'helmet',
    'hard hat',
  ];

  /// Com um único rótulo de madeira, o marrom até esta fração da foto é a
  /// própria forma ou tábua; acima disso a foto é tomada pelo marrom, e
  /// tanta madeira assim numa foto aberta de canteiro é rara — é barranco.
  static const double _terraDominante = 0.50;

  /// Madeira aparente o bastante para contar como uma evidência a mais.
  static const double _madeiraAparente = 0.20;

  /// Com terra à mostra, telhado só vale com esta pontuação: duas
  /// evidências fortes de telhado. O baldrame visto de cima traz "Roof" e
  /// até "Shingle", e não tem telha nenhuma.
  static const int _telhadoMuitoForte = 6;

  /// Parte pura da IA — recebe os rótulos e monta o rascunho do registro.
  static AnaliseFotoDiario interpretar(List<RotuloFoto> rotulos,
      {PaletaObra paleta = const PaletaObra()}) {
    final ordenados = [...rotulos]
      ..sort((a, b) => b.confianca.compareTo(a.confianca));
    final chaves = [
      for (final r in ordenados) r.label.toLowerCase().trim(),
    ];
    final cena = _lerCena(chaves.toSet(), paleta);

    final materiais = <String>[];
    final pontosPorFase = <String, int>{};
    final fasesComEvidenciaForte = <String>{};
    void somar(String fase, int peso) {
      pontosPorFase[fase] = (pontosPorFase[fase] ?? 0) + peso;
      if (peso >= 3) fasesComEvidenciaForte.add(fase);
    }

    final pontosDoModelo = <String, int>{};

    String? clima;
    var temPessoas = false;
    final vistos = <String>{};

    for (var i = 0; i < chaves.length; i++) {
      final chave = chaves[i];
      if (!vistos.add(chave)) continue;

      // Rótulo do modelo treinado com as fotos da obra: é a própria fase, e
      // pesa pela confiança dele — a partir de 0,5 já é evidência forte, e
      // perto de 1 decide sozinho. Fica separado porque as correções feitas
      // para o modelo genérico não valem para ele (ver [_escolherFase]).
      final faseDoModelo = ModeloFases.faseDoRotulo(chave);
      if (faseDoModelo != null) {
        pontosDoModelo[faseDoModelo] =
            (ordenados[i].confianca * 6).round().clamp(0, 6);
        continue;
      }

      final material = _materialDoRotulo(chave, cena);
      if (material != null && !materiais.contains(material)) {
        materiais.add(material);
      }

      final fase = _faseDoRotulo(chave, cena);
      if (fase != null) somar(fase.$1, fase.$2);

      // O primeiro rótulo de céu manda: é o mais confiante.
      clima ??= _clima[chave];

      if (_pessoas.contains(chave)) temPessoas = true;
    }

    // A cor entra como uma segunda opinião, com o mesmo peso das outras
    // evidências fortes: ela não sabe o que é uma laje, mas sabe que dois
    // terços da foto são barranco. O que cada cor quer dizer já foi
    // decidido em [_lerCena], com os rótulos do lado.
    if (cena.terra >= 0.34) {
      somar('Fundação', 3);
    } else if (cena.terra >= 0.20) {
      somar('Fundação', 2);
    }
    final faseDoVermelho = cena.vermelhoEhTelha ? 'Cobertura' : 'Alvenaria';
    if (cena.vermelho >= 0.16) {
      somar(faseDoVermelho, 3);
    } else if (cena.vermelho >= 0.08) {
      somar(faseDoVermelho, 2);
    }
    // Cinza domina qualquer obra bruta: vale como indício, nunca sozinho.
    if (paleta.concreto >= 0.40) somar(cena.faseDoCinza, 2);
    // Parede clara e lisa é obra que já passou do reboco.
    if (paleta.claro >= 0.34 && cena.terra < 0.12) somar('Pintura', 2);
    if (cena.formaDeLaje) somar('Estrutura', 3);

    final (faseSugerida, pontosDaFase) = _escolherFase(
        pontosPorFase, fasesComEvidenciaForte, cena,
        doModeloProprio: pontosDoModelo);

    // Clima: o céu medido na foto é mais confiável que o rótulo "Sky",
    // que o modelo devolve para qualquer fundo claro. Chuva é exceção —
    // ali o rótulo é específico e a cor não sabe distinguir.
    if (clima != 'Chuvoso' && clima != 'Chuva forte') {
      clima = paleta.climaPeloCeu ?? clima;
    }

    return AnaliseFotoDiario(
      materiais: materiais,
      faseSugerida: faseSugerida,
      climaSugerido: clima,
      temPessoas: temPessoas,
      descricaoSugerida: _montarDescricao(materiais, faseSugerida, temPessoas),
      rotulos: ordenados,
      paleta: paleta,
      confiancaFase: _confianca(pontosDaFase),
    );
  }

  /// Lê a cena inteira antes de pontuar qualquer coisa, porque o que cada
  /// evidência quer dizer depende das outras: o marrom é barranco ou forma?
  /// O vermelho é tijolo, telha ou terra roxa? O cinza é estrutura, bloco
  /// ou reboco? Decidir isso rótulo a rótulo é o que fazia a laje virar
  /// fundação e o telhado virar alvenaria.
  static _Cena _lerCena(Set<String> r, PaletaObra p) {
    bool algum(Set<String> grupo) => grupo.any(r.contains);

    final rotulosDeMadeira = _madeira.where(r.contains).length;
    final temSolo = algum(_solo);
    final temAlvenaria = algum(_alvenaria);
    final temTelhado = algum(_telhado);
    final telhadoEspecifico = algum(_telhadoEspecifico);
    final temParede = r.contains('wall');

    var terra = p.terra;
    var madeira = p.madeira;
    var vermelho = p.tijolo;
    // A madeira que a própria cor mediu. A que vier da terra reinterpretada
    // abaixo não conta como evidência a mais: ela só virou madeira porque
    // o modelo disse "Wood" — contá-la de novo seria ouvir o mesmo rótulo
    // duas vezes.
    var madeiraDaCor = p.madeira;

    // Marrom: madeira crua de forma e barranco caem no mesmo tom. Quem
    // desempata é o modelo: vendo madeira e nenhum chão, o marrom moderado
    // é a forma — e, com dois rótulos de madeira, a madeira é o assunto da
    // foto e explica até um marrom dominante. Vendo chão e nenhuma
    // madeira, o marrom claro é areia ou solo seco ao sol. Com os dois, a
    // foto tem os dois (é o baldrame), e a cor fica como foi medida.
    if (rotulosDeMadeira > 0 &&
        !temSolo &&
        (rotulosDeMadeira >= 2 || terra < _terraDominante)) {
      madeira += terra;
      terra = 0;
    } else if (temSolo && rotulosDeMadeira == 0) {
      terra += madeira;
      madeira = 0;
      madeiraDaCor = 0;
    }

    // Vermelho com o modelo vendo solo e nenhuma parede ou alvenaria é
    // terra roxa — o solo vermelho comum no Sul e no Sudeste —, não tijolo.
    // Rótulo de telhado não muda isso: com solo à mostra o vermelho não
    // pode ser telha (ver [vermelhoEhTelha]), e o "Roof" do baldrame visto
    // de cima mandaria a terra roxa para a alvenaria.
    if (algum(_soloQuePodeSerVermelho) && !temAlvenaria && !temParede) {
      terra += vermelho;
      vermelho = 0;
    }

    final terraVisivel = _terra.any(r.contains) || terra >= 0.20;
    final ceuVisivel = algum(_ceu) || p.climaPeloCeu != null;

    // Vermelho debaixo de céu, com rótulo de telhado e sem rótulo de
    // alvenaria, é telha cerâmica. Com "Shingle" ou "Roof tile" o modelo
    // já disse que é telhado, e até o "Brick" que vier junto é a telha.
    final vermelhoEhTelha = vermelho >= 0.08 &&
        temTelhado &&
        !terraVisivel &&
        (telhadoEspecifico || (ceuVisivel && !temAlvenaria));

    // Bloco de concreto: o modelo vê alvenaria, mas a parede é cinza, sem
    // o vermelho da cerâmica. Só vale com a cor medida — sem ela não há
    // como saber de que é feita a parede, e tijolo continua o palpite.
    final blocoDeConcreto = r.contains('cinder block') ||
        (temAlvenaria && p.medida && p.concreto >= 0.25 && vermelho < 0.06);

    // Reboco e contrapiso: superfície cimentícia (parede ou piso) sem nada
    // que indique estrutura sendo feita — sem ferragem, madeira ou forma.
    // Concreto com forma e vergalhão é estrutura; concreto liso na parede
    // ou no chão é o reboco e o contrapiso.
    final revestimento = algum(_cimenticio) &&
        (temParede || r.contains('floor')) &&
        !temAlvenaria &&
        !algum(_sinaisDeEstrutura) &&
        !terraVisivel &&
        madeira < _madeiraAparente &&
        (!p.medida || p.concreto >= 0.25);

    // Forma de laje vista de cima: madeira confirmada duas vezes (dois
    // rótulos, ou um rótulo e a cor) num plano horizontal, sem chão de
    // terra e sem nada de acabamento. "Roof" só conta como plano sem céu
    // na foto — com céu, madeira e "Roof" são o madeiramento do telhado.
    final sinaisDeMadeira =
        rotulosDeMadeira + (madeiraDaCor >= _madeiraAparente ? 1 : 0);
    final planoHorizontal =
        r.contains('floor') || (r.contains('roof') && !ceuVisivel);
    final formaDeLaje = sinaisDeMadeira >= 2 &&
        planoHorizontal &&
        !algum(_acabamento) &&
        !terraVisivel &&
        !telhadoEspecifico;

    // Telha precisa de duas evidências de telhado; com terra à mostra,
    // de duas fortes.
    var sinaisDeTelhado = _telhado.where(r.contains).length;
    var pontosDeTelhado = 0;
    for (final rotulo in _telhado) {
      if (r.contains(rotulo)) pontosDeTelhado += _fases[rotulo]!.$2;
    }
    if (vermelhoEhTelha) {
      sinaisDeTelhado++;
      pontosDeTelhado += vermelho >= 0.16 ? 3 : 2;
    }
    final telhadoConfirmado = sinaisDeTelhado >= 2 &&
        (!terraVisivel || pontosDeTelhado >= _telhadoMuitoForte);

    return _Cena(
      rotulos: r,
      terra: terra,
      madeira: madeira,
      vermelho: vermelho,
      vermelhoEhTelha: vermelhoEhTelha,
      terraVisivel: terraVisivel,
      // O modelo próprio só conhece fases de obra: qualquer rótulo dele já
      // é sinal de obra na foto.
      indicioDeObra: algum(_indiciosDeObra) ||
          r.any((rotulo) => ModeloFases.faseDoRotulo(rotulo) != null),
      temAlvenaria: temAlvenaria,
      blocoDeConcreto: blocoDeConcreto,
      revestimento: revestimento,
      formaDeLaje: formaDeLaje,
      telhadoConfirmado: telhadoConfirmado,
    );
  }

  static String? _materialDoRotulo(String chave, _Cena cena) {
    // "Wall" só diz o material junto de um rótulo de alvenaria.
    if (_alvenaria.contains(chave) || (chave == 'wall' && cena.temAlvenaria)) {
      return cena.materialDaAlvenaria;
    }
    if (_telhado.contains(chave)) {
      return cena.telhadoConfirmado ? 'Telha' : null;
    }
    // Na parede de bloco, o "Concrete" é o próprio bloco, já listado.
    if (chave == 'concrete') return cena.blocoDeConcreto ? null : 'Concreto';

    final direto = _materiaisDiretos[chave];
    if (direto != null) return direto;
    final corroborado = _materiaisCorroborados[chave];
    if (corroborado != null && corroborado.$2.any(cena.rotulos.contains)) {
      return corroborado.$1;
    }
    return null;
  }

  /// Fase que o rótulo indica nesta cena. O concreto é o caso que muda:
  /// numa parede de bloco ele é a própria alvenaria, numa parede lisa ou
  /// num piso é o reboco e o contrapiso.
  static (String, int)? _faseDoRotulo(String chave, _Cena cena) {
    final base = _fases[chave];
    if (base != null && _cimenticio.contains(chave)) {
      if (cena.blocoDeConcreto) return ('Alvenaria', base.$2);
      if (cena.revestimento) return ('Reboco e contrapiso', base.$2);
    }
    if (cena.revestimento && (chave == 'wall' || chave == 'floor')) {
      return ('Reboco e contrapiso', 1);
    }
    return base;
  }

  /// Traduz os pontos acumulados numa confiança de 0 a 1. Seis pontos
  /// (duas evidências fortes concordando) já é o teto.
  static double _confianca(int pontos) => (pontos / 6).clamp(0.0, 1.0);

  /// Escolhe a fase e devolve também os pontos que a sustentam — já com o
  /// que foi transferido de uma fase para outra, porque é isso que a
  /// confiança tem de medir.
  static (String?, int) _escolherFase(
    Map<String, int> pontos,
    Set<String> evidenciaForte,
    _Cena cena, {
    Map<String, int> doModeloProprio = const {},
  }) {
    final placar = Map<String, int>.from(pontos);
    final comEvidenciaForte = {...evidenciaForte};
    final terraVisivel = cena.terraVisivel;

    // Concreto e ferragem com a vala ainda aberta é fundação: a estrutura
    // só começa depois que a terra some da foto. Sem essa regra, a sapata
    // armada de uma obra recém-iniciada vira "Estrutura".
    final daEstrutura = placar['Estrutura'] ?? 0;
    if (terraVisivel && daEstrutura > 0) {
      placar['Fundação'] = (placar['Fundação'] ?? 0) + daEstrutura;
      if (comEvidenciaForte.contains('Estrutura')) {
        comEvidenciaForte.add('Fundação');
      }
      placar.remove('Estrutura');
    }

    // Terra sem nenhum sinal de obra é terreno, não fundação: monte de
    // areia, lote baldio, barranco de estrada.
    if (!cena.indicioDeObra) placar.remove('Fundação');

    // O modelo próprio entra depois das correções acima: elas existem
    // porque o modelo genérico confunde laje com telhado e sapata com
    // estrutura; o modelo treinado com as fotos da obra já aprendeu a
    // diferença, e a "estrutura" dele com terra à mostra é estrutura.
    for (final entrada in doModeloProprio.entries) {
      placar[entrada.key] = (placar[entrada.key] ?? 0) + entrada.value;
      if (entrada.value >= 3) comEvidenciaForte.add(entrada.key);
    }

    final indiceCobertura = AppConstants.fasesPadrao.indexOf('Cobertura');
    String? melhorFase;
    var melhorPontos = 0;

    // Percorre na ordem natural da obra: no empate, ganha a etapa mais
    // adiantada, que é a leitura conservadora da cena.
    for (var i = 0; i < AppConstants.fasesPadrao.length; i++) {
      final fase = AppConstants.fasesPadrao[i];
      final ponto = placar[fase] ?? 0;
      // Um único indício fraco não basta para sugerir uma fase.
      if (ponto < 2) continue;
      // Com terra à mostra, etapa de acabamento precisa de evidência forte:
      // é o que impede o "Roof" solto de virar cobertura numa foto de
      // baldrame, que foi o erro relatado no canteiro.
      if (terraVisivel &&
          i >= indiceCobertura &&
          !comEvidenciaForte.contains(fase)) {
        continue;
      }
      // E telhado, com terra à mostra, precisa de mais que uma evidência
      // forte: o baldrame visto de cima chega a ganhar "Shingle".
      if (terraVisivel && i == indiceCobertura && ponto < _telhadoMuitoForte) {
        continue;
      }
      if (ponto > melhorPontos) {
        melhorPontos = ponto;
        melhorFase = fase;
      }
    }
    return (melhorFase, melhorPontos);
  }

  /// Rascunho em português de obra — curto, para o usuário completar.
  static String _montarDescricao(
      List<String> materiais, String? fase, bool temPessoas) {
    final partes = <String>[];
    if (fase != null) {
      partes.add('Trabalho na fase de ${fase.toLowerCase()}');
    } else if (materiais.isNotEmpty || temPessoas) {
      partes.add('Registro fotográfico do canteiro');
    }
    if (materiais.isNotEmpty) {
      final lista = materiais.take(3).map((m) => m.toLowerCase()).toList();
      partes.add('material na foto: ${_juntar(lista)}');
    }
    if (temPessoas) partes.add('equipe trabalhando no local');
    if (partes.isEmpty) return '';
    final texto = partes.join(', ');
    return '${texto[0].toUpperCase()}${texto.substring(1)}.';
  }

  static String _juntar(List<String> itens) {
    if (itens.length == 1) return itens.first;
    return '${itens.sublist(0, itens.length - 1).join(', ')} e ${itens.last}';
  }
}

/// A cena já lida: cada cor com o significado que os rótulos lhe deram.
class _Cena {
  final Set<String> rotulos;

  /// Marrom que é solo (barranco, aterro, terra roxa).
  final double terra;

  /// Marrom que é madeira (forma, tábua, compensado).
  final double madeira;

  /// Vermelho cerâmico — tijolo ou telha, conforme [vermelhoEhTelha].
  final double vermelho;
  final bool vermelhoEhTelha;
  final bool terraVisivel;
  final bool indicioDeObra;
  final bool temAlvenaria;
  final bool blocoDeConcreto;

  /// Parede rebocada ou contrapiso.
  final bool revestimento;
  final bool formaDeLaje;
  final bool telhadoConfirmado;

  const _Cena({
    required this.rotulos,
    required this.terra,
    required this.madeira,
    required this.vermelho,
    required this.vermelhoEhTelha,
    required this.terraVisivel,
    required this.indicioDeObra,
    required this.temAlvenaria,
    required this.blocoDeConcreto,
    required this.revestimento,
    required this.formaDeLaje,
    required this.telhadoConfirmado,
  });

  /// De que é feita a alvenaria que o modelo viu.
  String get materialDaAlvenaria {
    if (vermelhoEhTelha) return 'Telha';
    if (blocoDeConcreto) return 'Bloco de concreto';
    return 'Tijolo';
  }

  /// O que o cinza da foto quer dizer nesta cena.
  String get faseDoCinza {
    if (blocoDeConcreto) return 'Alvenaria';
    if (revestimento) return 'Reboco e contrapiso';
    return 'Estrutura';
  }
}
