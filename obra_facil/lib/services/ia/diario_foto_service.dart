import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../constants/app_constants.dart';
import 'cores_foto.dart';

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
class DiarioFotoService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.40),
  );

  Future<AnaliseFotoDiario> analisar(String caminhoImagem) async {
    final labels =
        await _labeler.processImage(InputImage.fromFilePath(caminhoImagem));
    // A análise de cor roda em paralelo ao modelo e não pode derrubar a
    // leitura: sem ela sobra o classificador, como era antes.
    PaletaObra paleta = const PaletaObra();
    try {
      paleta = await CoresFoto.analisarArquivo(
          await File(caminhoImagem).readAsBytes());
    } catch (_) {}

    return interpretar(
      [for (final l in labels) RotuloFoto(l.label, l.confidence)],
      paleta: paleta,
    );
  }

  void dispose() => _labeler.close();

  // ------------------------------------------------------------- Parser

  /// Rótulos que só têm uma leitura possível no canteiro.
  static const Map<String, String> _materiaisDiretos = {
    'brick': 'Tijolo',
    'brickwork': 'Tijolo',
    'masonry': 'Tijolo',
    'wood': 'Madeira',
    'lumber': 'Madeira',
    'plank': 'Madeira',
    'plywood': 'Madeira',
    'concrete': 'Concreto',
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
  /// "Roof" numa foto de baldrame é a laje/forma vista de cima, não telha;
  /// "Floor" num contrapiso é concreto, não piso cerâmico; e "Wire" numa
  /// armação de ferragem é o próprio vergalhão, não fio elétrico.
  static const Map<String, (String, List<String>)> _materiaisCorroborados = {
    'roof': ('Telha', ['shingle', 'roof tile', 'ceiling', 'rooftop']),
    'wall': ('Tijolo', ['brick', 'brickwork', 'masonry']),
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
    'soil', 'dirt', 'mud', 'excavation', 'trench', 'digging', 'clay',
    'ground',
  ];

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
    'person', 'people', 'crowd', 'worker', 'helmet', 'hard hat',
  ];

  /// Evidência de fase que vem da cor da foto, não do classificador.
  ///
  /// Os limiares são de proporção de pixel: mais de um terço da foto em
  /// tom de terra é barranco de escavação, não um vaso de planta.
  static Map<String, int> _fasesPelaCor(PaletaObra paleta) {
    final pontos = <String, int>{};
    void somar(String fase, int peso) =>
        pontos[fase] = (pontos[fase] ?? 0) + peso;

    if (paleta.terra >= 0.34) {
      somar('Fundação', 3);
    } else if (paleta.terra >= 0.20) {
      somar('Fundação', 2);
    }
    if (paleta.tijolo >= 0.16) {
      somar('Alvenaria', 3);
    } else if (paleta.tijolo >= 0.08) {
      somar('Alvenaria', 2);
    }
    // Cinza domina qualquer obra bruta: vale como indício, nunca sozinho.
    if (paleta.concreto >= 0.40) somar('Estrutura', 2);
    // Parede clara e lisa é obra que já passou do reboco.
    if (paleta.claro >= 0.34 && paleta.terra < 0.12) somar('Pintura', 2);
    return pontos;
  }

  /// Parte pura da IA — recebe os rótulos e monta o rascunho do registro.
  static AnaliseFotoDiario interpretar(List<RotuloFoto> rotulos,
      {PaletaObra paleta = const PaletaObra()}) {
    final ordenados = [...rotulos]
      ..sort((a, b) => b.confianca.compareTo(a.confianca));
    final chaves = [
      for (final r in ordenados) r.label.toLowerCase().trim(),
    ];
    final presentes = chaves.toSet();

    final materiais = <String>[];
    final pontosPorFase = <String, int>{};
    final fasesComEvidenciaForte = <String>{};
    String? clima;
    var temPessoas = false;
    final vistos = <String>{};

    for (final chave in chaves) {
      if (!vistos.add(chave)) continue;

      final direto = _materiaisDiretos[chave];
      if (direto != null && !materiais.contains(direto)) materiais.add(direto);

      final corroborado = _materiaisCorroborados[chave];
      if (corroborado != null &&
          corroborado.$2.any(presentes.contains) &&
          !materiais.contains(corroborado.$1)) {
        materiais.add(corroborado.$1);
      }

      final fase = _fases[chave];
      if (fase != null) {
        pontosPorFase[fase.$1] = (pontosPorFase[fase.$1] ?? 0) + fase.$2;
        if (fase.$2 >= 3) fasesComEvidenciaForte.add(fase.$1);
      }

      // O primeiro rótulo de céu manda: é o mais confiante.
      clima ??= _clima[chave];

      if (_pessoas.contains(chave)) temPessoas = true;
    }

    // A cor entra como uma segunda opinião, com o mesmo peso das outras
    // evidências fortes: ela não sabe o que é uma laje, mas sabe que dois
    // terços da foto são barranco.
    final porCor = _fasesPelaCor(paleta);
    for (final entrada in porCor.entries) {
      pontosPorFase[entrada.key] =
          (pontosPorFase[entrada.key] ?? 0) + entrada.value;
      if (entrada.value >= 3) fasesComEvidenciaForte.add(entrada.key);
    }

    final faseSugerida = _escolherFase(
      pontosPorFase,
      fasesComEvidenciaForte,
      // Terra à mostra vale tanto pelo rótulo quanto pela cor: numa foto
      // de baldrame o modelo costuma não dizer "soil", mas o barranco
      // ocupa metade da imagem.
      terraVisivel:
          _terra.any(presentes.contains) || paleta.terra >= 0.20,
    );

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
      descricaoSugerida:
          _montarDescricao(materiais, faseSugerida, temPessoas),
      rotulos: ordenados,
      paleta: paleta,
      confiancaFase: _confianca(pontosPorFase[faseSugerida] ?? 0),
    );
  }

  /// Traduz os pontos acumulados numa confiança de 0 a 1. Seis pontos
  /// (duas evidências fortes concordando) já é o teto.
  static double _confianca(int pontos) => (pontos / 6).clamp(0.0, 1.0);

  static String? _escolherFase(
    Map<String, int> pontos,
    Set<String> evidenciaForte, {
    required bool terraVisivel,
  }) {
    final placar = Map<String, int>.from(pontos);
    final comEvidenciaForte = {...evidenciaForte};

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
      if (ponto > melhorPontos) {
        melhorPontos = ponto;
        melhorFase = fase;
      }
    }
    return melhorFase;
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
