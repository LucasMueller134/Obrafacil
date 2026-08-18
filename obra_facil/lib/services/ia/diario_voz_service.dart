import '../../constants/app_constants.dart';
import 'data_falada.dart';
import 'numero_extenso.dart';
import 'texto_br.dart';

/// Registro do diário interpretado a partir da fala.
class DiarioPorVoz {
  /// O relato do dia, já sem o "anota aí" do começo.
  final String descricao;

  /// Uma das [AppConstants.climas], ou null se o usuário não falou do tempo.
  final String? clima;

  /// Quantas pessoas trabalharam, somando as profissões citadas.
  final int? numeroPessoas;

  /// Uma das [AppConstants.fasesPadrao] deduzida do que foi relatado.
  final String? fase;

  /// Dia do registro ("ontem", "sexta passada"), null = hoje.
  final DateTime? data;

  final String transcricao;

  const DiarioPorVoz({
    required this.descricao,
    this.clima,
    this.numeroPessoas,
    this.fase,
    this.data,
    required this.transcricao,
  });

  /// Se a IA conseguiu preencher algum campo além do texto.
  bool get temAlgo => clima != null || numeroPessoas != null || fase != null;
}

/// IA on-device nº 5 — diário de obra por voz.
///
/// O encarregado conta o dia como contaria para o dono ("hoje choveu de
/// manhã, trabalharam três pedreiros e dois serventes, terminamos o reboco
/// da fachada") e a IA separa o relato em clima, tamanho da equipe, fase e
/// data — os campos que o formulário do diário pede. Tudo offline, no
/// mesmo motor de texto do lançamento por voz.
abstract class DiarioVozService {
  /// Do mais específico para o mais genérico: "chuva forte" tem de ganhar
  /// de "chuva", e "sem sol" de "sol".
  static const List<(String, List<String>)> _clima = [
    ('Chuva forte', [
      'chuva forte', 'chuveu muito', 'choveu muito', 'temporal', 'tempestade',
      'chuvarada', 'pancada de chuva', 'toro de chuva', 'chuva pesada',
      'enxurrada', 'alagou', 'dilúvio', 'diluvio',
    ]),
    ('Chuvoso', [
      'chuva', 'chuvoso', 'choveu', 'chovendo', 'chuvisco', 'garoa',
      'garoou', 'garoando', 'chuviscando', 'molhado', 'tempo fechado',
    ]),
    ('Nublado', [
      'nublado', 'encoberto', 'sem sol', 'ceu fechado', 'nuvens', 'nublou',
      'ceu cinza', 'tempo nublado', 'sombrio',
    ]),
    ('Ensolarado', [
      'sol', 'ensolarado', 'ceu limpo', 'tempo bom', 'tempo firme', 'quente',
      'calor', 'abafado', 'sol forte', 'limpo',
    ]),
  ];

  /// Palavras que revelam a fase da obra dentro do relato do dia.
  static const Map<String, List<String>> _fases = {
    'Fundação': [
      'fundacao', 'sapata', 'baldrame', 'estaca', 'broca', 'radier',
      'escavacao', 'escavando', 'vala', 'alicerce', 'gabarito', 'aterro',
    ],
    'Estrutura': [
      'estrutura', 'laje', 'pilar', 'viga', 'concretagem', 'concretar',
      'concretamos', 'concreto', 'ferragem', 'armacao', 'forma', 'formas',
      'escoramento', 'escora', 'vergalhao',
    ],
    'Alvenaria': [
      'alvenaria', 'parede', 'tijolo', 'bloco', 'muro', 'assentamento',
      'levantando parede', 'levantamos', 'verga', 'contraverga',
    ],
    'Cobertura': [
      'cobertura', 'telhado', 'telha', 'madeiramento', 'tesoura', 'calha',
      'forro', 'rufo', 'beiral',
    ],
    'Instalações elétricas': [
      'eletrica', 'fiacao', 'conduite', 'eletroduto', 'tomada',
      'interruptor', 'quadro de luz', 'disjuntor', 'passagem de fio',
      'eletricista', 'ponto de luz',
    ],
    'Instalações hidráulicas': [
      'hidraulica', 'encanamento', 'cano', 'tubulacao', 'esgoto', 'caixa d',
      'registro de agua', 'encanador', 'ralo', 'sifao', 'coluna de agua',
    ],
    'Reboco e contrapiso': [
      'reboco', 'rebocar', 'rebocando', 'emboco', 'chapisco', 'contrapiso',
      'massa grossa', 'regularizacao', 'nivelamento de piso',
    ],
    'Revestimentos': [
      'revestimento', 'azulejo', 'ceramica', 'porcelanato', 'assentar piso',
      'assentamento de piso', 'rejunte', 'rejuntamento', 'pastilha',
    ],
    'Pintura': [
      'pintura', 'pintar', 'pintando', 'pintamos', 'tinta', 'massa corrida',
      'selador', 'demao', 'primeira demao', 'grafiato', 'textura',
    ],
    'Acabamento': [
      'acabamento', 'rodape', 'soleira', 'porta', 'janela', 'louca',
      'metais', 'bancada', 'limpeza fina', 'batente', 'ferragens',
    ],
  };

  /// "3 pedreiros", "2 serventes", "5 pessoas" — o total do canteiro é a
  /// soma das profissões citadas.
  static final RegExp _pessoasPorProfissao = RegExp(
      r'(\d+)\s+(pessoas?|pedreiros?|serventes?|ajudantes?|funcionarios?|'
      r'homens|caras|profissionais|trabalhadores|oficiais?|eletricistas?|'
      r'encanadores?|pintores?|carpinteiros?|gesseiros?|azulejistas?|'
      r'armadores?|soldadores?|marceneiros?|mestres?|peoes?|meninos?|'
      r'rapazes|colaboradores?)\b');

  /// "equipe de 6", "estávamos em 4", "trabalharam 5", "somos 3".
  static final RegExp _pessoasPorGrupo = RegExp(
      r'\b(?:equipe de|turma de|estavamos em|estavamos|eramos|somos|'
      r'trabalharam|trabalhamos em|ficamos em|tinha|tinham|veio|vieram)\s+'
      r'(\d+)\b');

  static final RegExp _sozinho =
      RegExp(r'\b(?:sozinho|so eu|apenas eu|somente eu)\b');

  /// Aberturas de comando que não fazem parte do relato.
  static final RegExp _aberturas = RegExp(
      r'^\s*(?:anota(?:r)?\s+a[ií]|anota(?:r)?|registra(?:r)?|escreve(?:r)?|'
      r'coloca(?:r)?|bota(?:r)?|poe|p[oõ]e)\s+'
      r'(?:no\s+di[aá]rio\s*)?(?:que\s+)?',
      caseSensitive: false);

  /// Interpreta o relato falado do dia. [agora] fixa o "hoje" nos testes.
  static DiarioPorVoz interpretar(String transcricao, {DateTime? agora}) {
    final original = transcricao.trim();
    // "três pedreiros" → "3 pedreiros"
    final texto = NumeroExtenso.normalizar(original);
    final normalizado = TextoBr.normalizar(texto);

    return DiarioPorVoz(
      descricao: _montarDescricao(texto),
      clima: _extrairClima(normalizado),
      numeroPessoas: _extrairPessoas(normalizado),
      fase: _extrairFase(normalizado),
      data: DataFalada.extrair(texto, agora: agora),
      transcricao: original,
    );
  }

  static String? _extrairClima(String normalizado) {
    for (final (clima, palavras) in _clima) {
      if (palavras.any((p) => TextoBr.contemPalavra(normalizado, p))) {
        return clima;
      }
    }
    return null;
  }

  static int? _extrairPessoas(String normalizado) {
    final ocorrencias = <(int, int, int)>[];

    void adicionar(int inicio, int fim, int quantidade) {
      if (quantidade <= 0 || quantidade > 500) return;
      for (final o in ocorrencias) {
        if (inicio < o.$2 && fim > o.$1) return; // já contado
      }
      ocorrencias.add((inicio, fim, quantidade));
    }

    // A profissão vem primeiro: "trabalharam 3 pedreiros" são 3 pessoas,
    // não 3 do grupo mais 3 pedreiros.
    for (final m in _pessoasPorProfissao.allMatches(normalizado)) {
      adicionar(m.start, m.end, int.tryParse(m.group(1)!) ?? 0);
    }
    for (final m in _pessoasPorGrupo.allMatches(normalizado)) {
      adicionar(m.start, m.end, int.tryParse(m.group(1)!) ?? 0);
    }

    if (ocorrencias.isEmpty) {
      return _sozinho.hasMatch(normalizado) ? 1 : null;
    }
    return ocorrencias.fold<int>(0, (s, o) => s + o.$3);
  }

  static String? _extrairFase(String normalizado) {
    String? melhor;
    var melhorPontos = 0;
    for (final entrada in _fases.entries) {
      final pontos =
          TextoBr.quantosCasam(normalizado, entrada.value);
      if (pontos > melhorPontos) {
        melhorPontos = pontos;
        melhor = entrada.key;
      }
    }
    // A fase precisa existir na lista do formulário para ser selecionável.
    return AppConstants.fasesPadrao.contains(melhor) ? melhor : null;
  }

  /// O relato é o texto quase inteiro — só tira o comando de abertura,
  /// porque no diário a frase falada já é a descrição do dia.
  static String _montarDescricao(String texto) {
    var d = texto.replaceFirst(_aberturas, '').trim();
    d = d.replaceAll(RegExp(r'\s{2,}'), ' ');
    if (d.length < 3) return texto.trim();
    return d[0].toUpperCase() + d.substring(1);
  }
}
