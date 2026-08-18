import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../constants/app_constants.dart';

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

  const AnaliseFotoDiario({
    this.materiais = const [],
    this.faseSugerida,
    this.climaSugerido,
    this.temPessoas = false,
    this.descricaoSugerida = '',
    this.rotulos = const [],
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
class DiarioFotoService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.40),
  );

  Future<AnaliseFotoDiario> analisar(String caminhoImagem) async {
    final labels =
        await _labeler.processImage(InputImage.fromFilePath(caminhoImagem));
    return interpretar([
      for (final l in labels) RotuloFoto(l.label, l.confidence),
    ]);
  }

  void dispose() => _labeler.close();

  // ------------------------------------------------------------- Parser

  /// Rótulo do modelo → material do app.
  static const Map<String, String> _materiais = {
    'brick': 'Tijolo',
    'brickwork': 'Tijolo',
    'wall': 'Tijolo',
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
    'wire': 'Fio elétrico',
    'cable': 'Fio elétrico',
    'pipe': 'Cano PVC',
    'plumbing': 'Cano PVC',
    'tile': 'Piso cerâmico',
    'flooring': 'Piso cerâmico',
    'floor': 'Piso cerâmico',
    'roof': 'Telha',
    'paint': 'Tinta',
    'door': 'Porta',
    'window': 'Janela',
    'glass': 'Vidro',
  };

  /// Rótulo do modelo → fase provável da obra, com o peso da evidência.
  /// Telhado indica cobertura com mais força do que parede indica alvenaria.
  static const Map<String, (String, int)> _fases = {
    'roof': ('Cobertura', 3),
    'ceiling': ('Cobertura', 1),
    'brick': ('Alvenaria', 3),
    'brickwork': ('Alvenaria', 3),
    'wall': ('Alvenaria', 2),
    'rebar': ('Estrutura', 3),
    'concrete': ('Estrutura', 2),
    'scaffolding': ('Estrutura', 2),
    'beam': ('Estrutura', 2),
    'soil': ('Fundação', 2),
    'mud': ('Fundação', 1),
    'excavation': ('Fundação', 3),
    'trench': ('Fundação', 3),
    'paint': ('Pintura', 3),
    'painting': ('Pintura', 2),
    'tile': ('Revestimentos', 3),
    'flooring': ('Revestimentos', 2),
    'pipe': ('Instalações hidráulicas', 3),
    'plumbing': ('Instalações hidráulicas', 3),
    'wire': ('Instalações elétricas', 3),
    'cable': ('Instalações elétricas', 2),
    'door': ('Acabamento', 2),
    'window': ('Acabamento', 2),
    'furniture': ('Acabamento', 1),
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
    'person', 'people', 'crowd', 'worker', 'helmet', 'hard hat',
  ];

  /// Parte pura da IA — recebe os rótulos e monta o rascunho do registro.
  static AnaliseFotoDiario interpretar(List<RotuloFoto> rotulos) {
    final ordenados = [...rotulos]
      ..sort((a, b) => b.confianca.compareTo(a.confianca));

    final materiais = <String>[];
    final pontosPorFase = <String, int>{};
    String? clima;
    var temPessoas = false;

    for (final rotulo in ordenados) {
      final chave = rotulo.label.toLowerCase().trim();

      final material = _materiais[chave];
      if (material != null && !materiais.contains(material)) {
        materiais.add(material);
      }

      final fase = _fases[chave];
      if (fase != null) {
        pontosPorFase[fase.$1] = (pontosPorFase[fase.$1] ?? 0) + fase.$2;
      }

      // O primeiro rótulo de céu manda: é o mais confiante.
      clima ??= _clima[chave];

      if (_pessoas.contains(chave)) temPessoas = true;
    }

    String? faseSugerida;
    var melhorPontos = 0;
    for (final entrada in pontosPorFase.entries) {
      // Um único indício fraco não basta para sugerir uma fase.
      if (entrada.value > melhorPontos && entrada.value >= 2) {
        melhorPontos = entrada.value;
        faseSugerida = entrada.key;
      }
    }
    if (!AppConstants.fasesPadrao.contains(faseSugerida)) faseSugerida = null;

    return AnaliseFotoDiario(
      materiais: materiais,
      faseSugerida: faseSugerida,
      climaSugerido: clima,
      temPessoas: temPessoas,
      descricaoSugerida: _montarDescricao(materiais, faseSugerida, temPessoas),
      rotulos: ordenados,
    );
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
