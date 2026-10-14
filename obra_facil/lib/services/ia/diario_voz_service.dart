import '../../constants/app_constants.dart';
import 'data_falada.dart';
import 'hipoteses_voz.dart';
import 'numero_extenso.dart';
import 'texto_br.dart';
import 'vocabulario_obra.dart';

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
///
/// Campo que a fala não deixa claro fica vazio: o encarregado completa um
/// campo vazio sem pensar, mas um campo errado ele pode nem perceber.
abstract class DiarioVozService {
  // ============================================================== Clima

  /// Termos de cada clima, do mais forte para o mais fraco. Termo mais
  /// longo vence o mais curto que está dentro dele: "cara de chuva" é
  /// nublado, não chuvoso; "sem sol" é nublado, não ensolarado.
  static const List<(String, List<String>)> _clima = [
    (
      'Chuva forte',
      [
        'chuva forte',
        'chuva muito forte',
        'choveu forte',
        'chovendo forte',
        'chuveu muito',
        'choveu muito',
        'chovendo muito',
        'choveu bastante',
        'temporal',
        'tempestade',
        'chuvarada',
        'pancada de chuva',
        'toro',
        'toro de chuva',
        'chuva pesada',
        'chuva grossa',
        'enxurrada',
        'alagou',
        'dilúvio',
        'diluvio',
      ]
    ),
    (
      'Chuvoso',
      [
        'chuva',
        'chuvoso',
        'choveu',
        'chovendo',
        'chover',
        'chuvisco',
        'chuviscou',
        'chuviscando',
        'chuvinha',
        'garoa',
        'garoou',
        'garoando',
      ]
    ),
    (
      'Nublado',
      [
        'nublado',
        'encoberto',
        'sem sol',
        'ceu fechado',
        'tempo fechado',
        'nuvem',
        'nuvens',
        'nublou',
        'ceu cinza',
        'tempo nublado',
        'sombrio',
        'cara de chuva',
        'ameacou chover',
        'ameacando chover',
        'ameaca de chuva',
        'nebuloso',
      ]
    ),
    (
      'Ensolarado',
      [
        'sol',
        'ensolarado',
        'ceu limpo',
        'ceu azul',
        'tempo bom',
        'tempo firme',
        'tempo limpo',
        'quente',
        'calor',
        'abafado',
        'sol forte',
        'solzao',
        'sem nuvem',
        'sem nuvens',
        'sol o dia todo',
      ]
    ),
  ];

  /// O tempo dito com verbo no meio: "o tempo ficou fechado", "o céu
  /// estava limpo", "o tempo fechou". Só com verbo de estado logo depois
  /// de "tempo"/"céu" — "esperando o tempo ficar bom" não diz como foi.
  static final List<(RegExp, int)> _climaComVerbo = [
    (
      RegExp(r'(?<![a-z])(?:tempo|ceu)\s+(?:ficou|estava|esteve|tava|esta|'
          r'foi|continuou|permaneceu|amanheceu|seguiu)\s+'
          r'(?:(?:meio|bem|muito|todo|bastante)\s+)?'
          r'(?:fechado|encoberto|nublado|cinza|carregado)(?![a-z])'),
      2, // Nublado
    ),
    (
      RegExp(r'(?<![a-z])(?:tempo\s+fechou|fechou\s+o\s+tempo)(?![a-z])'),
      2, // Nublado
    ),
    (
      RegExp(r'(?<![a-z])(?:tempo|ceu)\s+(?:ficou|estava|esteve|tava|esta|'
          r'foi|continuou|permaneceu|amanheceu|seguiu)\s+'
          r'(?:(?:meio|bem|muito|todo|bastante)\s+)?'
          r'(?:limpo|azul|bom|firme|aberto|ensolarado)(?![a-z])'),
      3, // Ensolarado
    ),
  ];

  /// Negação antes do termo ("não choveu", "sem chuva", "nem garoou").
  static final RegExp _negacaoAntes =
      RegExp(r'(?:^|[^\w])(?:nao|sem|nem|nenhum|nenhuma|nada\s+de)'
          r'(?:\s+[a-z]+){0,2}\s*$');

  /// O que o termo não disse do dia de hoje: previsão e hipótese ("vai
  /// chover amanhã", "se chover").
  /// Também a expectativa que pode não ter acontecido: "achei que ia
  /// chover", "parecia que ia chover".
  static final RegExp _irrealAntes =
      RegExp(r'(?:^|[^\w])(?:vai|vao|deve|pode|previsao\s+de|previsao|se|caso|'
          r'ia|iam|iria|iriam)'
          r'(?:\s+[a-z]+){0,1}\s*$');

  /// Negação depois do substantivo: "o sol não apareceu".
  static final RegExp _negacaoDepois =
      RegExp(r'^\s+(?:nao|nem)\s+(?:apareceu|veio|saiu|deu|caiu|abriu)\b');

  /// "não parou de chover" choveu, sim — a negação é do "parar".
  static final RegExp _parouAntes =
      RegExp(r'(?:parou|parava|parar|deixou)\s+de\s*$');

  // ============================================================ Pessoas

  /// Quem trabalha no canteiro — singular e plural.
  static const Map<String, String> _trabalhadores = {
    'pessoa': 'pessoa',
    'pessoas': 'pessoa',
    'pedreiro': 'pedreiro',
    'pedreiros': 'pedreiro',
    'servente': 'servente',
    'serventes': 'servente',
    'ajudante': 'ajudante',
    'ajudantes': 'ajudante',
    'funcionario': 'funcionario',
    'funcionarios': 'funcionario',
    'homem': 'homem',
    'homens': 'homem',
    'cara': 'cara',
    'caras': 'cara',
    'profissional': 'profissional',
    'profissionais': 'profissional',
    'trabalhador': 'trabalhador',
    'trabalhadores': 'trabalhador',
    'oficial': 'oficial',
    'oficiais': 'oficial',
    'eletricista': 'eletricista',
    'eletricistas': 'eletricista',
    'encanador': 'encanador',
    'encanadores': 'encanador',
    'bombeiro': 'encanador',
    'bombeiros': 'encanador',
    'pintor': 'pintor',
    'pintores': 'pintor',
    'carpinteiro': 'carpinteiro',
    'carpinteiros': 'carpinteiro',
    'gesseiro': 'gesseiro',
    'gesseiros': 'gesseiro',
    'azulejista': 'azulejista',
    'azulejistas': 'azulejista',
    'armador': 'armador',
    'armadores': 'armador',
    'soldador': 'soldador',
    'soldadores': 'soldador',
    'marceneiro': 'marceneiro',
    'marceneiros': 'marceneiro',
    'serralheiro': 'serralheiro',
    'serralheiros': 'serralheiro',
    'mestre': 'mestre',
    'mestres': 'mestre',
    'encarregado': 'encarregado',
    'encarregados': 'encarregado',
    'peao': 'peao',
    'peoes': 'peao',
    'menino': 'menino',
    'meninos': 'menino',
    'rapaz': 'rapaz',
    'rapazes': 'rapaz',
    'colaborador': 'colaborador',
    'colaboradores': 'colaborador',
    'operario': 'operario',
    'operarios': 'operario',
    'telhadista': 'telhadista',
    'telhadistas': 'telhadista',
    'calheiro': 'calheiro',
    'calheiros': 'calheiro',
    'vidraceiro': 'vidraceiro',
    'vidraceiros': 'vidraceiro',
    'empreiteiro': 'empreiteiro',
    'empreiteiros': 'empreiteiro',
    'jardineiro': 'jardineiro',
    'jardineiros': 'jardineiro',
  };

  /// Quem só passou para ver não entra na conta: o campo do diário é a
  /// equipe que trabalhou no dia. Engenheiro, arquiteto, fiscal, cliente
  /// e dono acompanham a obra, mas não são mão de obra do canteiro.
  static const Set<String> _visitantes = {
    'engenheiro',
    'engenheira',
    'engenheiros',
    'arquiteto',
    'arquiteta',
    'arquitetos',
    'fiscal',
    'fiscais',
    'cliente',
    'clientes',
    'dono',
    'dona',
    'donos',
    'proprietario',
    'proprietaria',
    'vizinho',
    'vizinha',
    'corretor',
    'corretora',
    'motorista',
    'entregador',
    'visita',
  };

  /// "o servente faltou" — quem não veio não conta.
  static final RegExp _ausenciaDepois = RegExp(
      r'^(?:\s+[a-z]+){0,2}?\s+(?:faltou|faltaram|nao\s+veio|nao\s+vieram|'
      r'nao\s+apareceu|nao\s+apareceram|nao\s+trabalhou|nao\s+trabalharam|'
      r'folgou|folgaram|de\s+folga|ficou\s+doente)\b');

  /// Total anunciado: "equipe de 6", "éramos 5", "ao todo 7".
  static final RegExp _totalAnunciado = RegExp(
      r'(?:^|[^\w])(?:equipe\s+de|turma\s+de|estavamos\s+em|estavam\s+em|'
      r'estava\s+em|eramos(?:\s+em)?|eram|somos(?:\s+em)?|fomos(?:\s+em)?|'
      r'ficamos\s+em|ao\s+todo|no\s+total|total\s+de)\s+(\d+)\b');

  /// "trabalharam 5", "vieram 3", "tinha 4" — número de gente sem
  /// profissão.
  static final RegExp _grupoPorVerbo =
      RegExp(r'(?:^|[^\w])(?:trabalharam|trabalhamos\s+em|vieram|veio|tinha|'
          r'tinham|tivemos|estavam|ficaram|apareceram|compareceram)\s+(\d+)\b');

  /// "eu e mais 2", "o pedreiro e mais 1".
  static final RegExp _maisN = RegExp(r'(?:^|[^\w])mais\s+(\d+)\b');

  /// Depois do número, o que deixa claro que não é gente ("tinha 3
  /// sacos", "trabalharam 8 horas").
  static final RegExp _naoEhGente =
      RegExp(r'^\s+(?:sacos?|metros?|m|m2|m3|latas?|barras?|dias?|horas?|h|'
          r'minutos?|semanas?|meses|reais|real|vezes|kg|quilos?|litros?|'
          r'pecas?|unidades?|caminh(?:ao|oes)|viagens?|carrinhos?|baldes?|'
          r'tijolos?|blocos?|telhas?|andares|pavimentos?|comodos?|paredes?)\b');

  /// O falante conta quando se inclui na equipe: "eu e o ajudante", "eu e
  /// mais 2", "o ajudante comigo". "Choveu e eu fui embora" não é equipe.
  static final RegExp _euJunto = RegExp(
      r'(?:^|[^\w])(?:eu\s+e\s+(?:o|a|os|as|mais|meu|minha|meus|minhas|\d)|'
      r'eu\s+mais|comigo|(?:trabalhei|fiquei|estive)\s+com)(?![\w])');

  /// "eu, o pedreiro e 2 ajudantes": o falante abrindo a lista da equipe.
  /// Só conta quando a lista traz mais alguém — "eu, a princípio, acho"
  /// não é equipe.
  static final RegExp _euEmLista = RegExp(
      r'(?:^|[^\w])eu\s*,\s*(?:o|a|os|as|meu|minha|meus|minhas|\d)(?![\w])');

  /// "o pedreiro, o ajudante e eu": alguém da equipe nas palavras antes.
  static final RegExp _equipeEEu =
      RegExp(r'((?:[a-z]+\s+){1,3})e\s+eu(?![\w])');

  /// Quem trabalha junto sem ser profissão: "eu e meu filho", "meu irmão
  /// e eu", "trabalhei com meu sobrinho". Só ao lado do falante — "o
  /// filho do dono passou aí" não é equipe.
  static const Set<String> _parentes = {
    'filho',
    'filha',
    'irmao',
    'irma',
    'primo',
    'prima',
    'sobrinho',
    'sobrinha',
    'cunhado',
    'cunhada',
    'genro',
    'sogro',
    'pai',
    'tio',
    'socio',
    'socia',
    'colega',
    'parceiro',
    'companheiro',
    'amigo',
  };
  static final RegExp _parenteJunto = RegExp(
      r'(?:(?:^|[^\w])eu\s*(?:,|\s+e)\s+|'
      r'(?:trabalhei|fiquei|estive|trabalhamos)\s+com\s+)'
      r'(?:o|a|meu|minha)\s+([a-z]+)(?![\w])|'
      r'(?:^|[^\w])(?:o|a|meu|minha)\s+([a-z]+)\s+(?:e\s+eu|comigo)(?![\w])');

  /// No singular e sem número, estas não dizem gente: "cara de chuva",
  /// "o homem da entrega", "uma pessoa" (que já virou "1 pessoa").
  static const Set<String> _singularAmbiguo = {'cara', 'homem', 'pessoa'};

  static final RegExp _sozinho =
      RegExp(r'(?:^|[^\w])(?:sozinho|sozinha|so\s+eu|apenas\s+eu|somente\s+eu)'
          r'(?![\w])');

  // =============================================================== Fase

  /// Termos de cada fase com o peso da evidência: atividade (3) pesa
  /// mais que componente típico da fase (2), que pesa mais que objeto
  /// genérico (1). "Chapisco das paredes" é reboco — a parede é só onde.
  static const Map<String, List<(String, int)>> _fases = {
    'Fundação': [
      ('fundacao', 3),
      ('sapata', 3),
      ('baldrame', 3),
      ('estaca', 3),
      ('radier', 3),
      ('escavacao', 3),
      ('alicerce', 3),
      ('vala', 2),
      ('gabarito', 2),
      ('aterro', 2),
      ('broca', 1),
    ],
    'Estrutura': [
      ('estrutura', 2),
      ('laje', 2),
      ('pilar', 2),
      ('viga', 2),
      ('concretagem', 2),
      ('ferragem', 2),
      ('armacao', 2),
      ('formas', 2),
      ('desforma', 2),
      ('escoramento', 2),
      ('escora', 1),
      ('vergalhao', 1),
      ('concreto', 1),
    ],
    'Alvenaria': [
      ('alvenaria', 3),
      ('assentamento de bloco', 3),
      ('assentamento de tijolo', 3),
      ('levantando parede', 3),
      ('contraverga', 2),
      ('verga', 2),
      ('tijolo', 2),
      ('bloco', 2),
      ('muro', 2),
      ('parede', 1),
    ],
    'Cobertura': [
      ('cobertura', 3),
      ('telhado', 2),
      ('telha', 2),
      ('madeiramento', 2),
      ('cumeeira', 2),
      ('tesoura', 1),
      ('calha', 2),
      ('rufo', 2),
      ('beiral', 2),
      ('forro', 1),
    ],
    'Instalações elétricas': [
      ('eletrica', 3),
      ('instalacao eletrica', 3),
      ('fiacao', 3),
      ('enfiacao', 3),
      ('passagem de fio', 3),
      ('conduite', 2),
      ('eletroduto', 2),
      ('quadro de luz', 2),
      ('disjuntor', 2),
      ('ponto de luz', 2),
      ('tomada', 1),
      ('interruptor', 1),
    ],
    'Instalações hidráulicas': [
      ('hidraulica', 3),
      ('instalacao hidraulica', 3),
      ('encanamento', 3),
      ('tubulacao', 2),
      ('esgoto', 2),
      ("caixa d'agua", 2),
      ('caixa d', 2),
      ('registro de agua', 2),
      ('coluna de agua', 2),
      ('cano', 1),
      ('ralo', 1),
      ('sifao', 1),
    ],
    'Reboco e contrapiso': [
      ('reboco', 3),
      ('emboco', 3),
      ('chapisco', 3),
      ('contrapiso', 3),
      ('massa grossa', 3),
      ('regularizacao', 2),
      ('nivelamento de piso', 3),
    ],
    'Revestimentos': [
      ('revestimento', 3),
      ('assentamento de piso', 3),
      ('assentar piso', 3),
      ('rejuntamento', 3),
      ('rejunte', 2),
      ('azulejo', 2),
      ('ceramica', 2),
      ('porcelanato', 2),
      ('pastilha', 2),
      ('piso', 1),
    ],
    'Pintura': [
      ('pintura', 3),
      ('massa corrida', 2),
      ('selador', 2),
      ('demao', 2),
      ('grafiato', 2),
      ('textura', 2),
      ('tinta', 1),
    ],
    'Acabamento': [
      ('acabamento', 2),
      ('rodape', 2),
      ('soleira', 2),
      ('louca', 2),
      ('batente', 2),
      ('limpeza fina', 2),
      ('metais', 1),
      ('bancada', 1),
      ('porta', 1),
      ('janela', 1),
      ('ferragens', 1),
    ],
  };

  /// Profissional citado é só uma dica da fase ("o eletricista veio"):
  /// conta quando o relato não traz nenhum outro termo daquela fase —
  /// senão a mesma atividade seria contada duas vezes.
  static const Map<String, String> _dicasDeProfissao = {
    'armador': 'Estrutura',
    'telhadista': 'Cobertura',
    'calheiro': 'Cobertura',
    'eletricista': 'Instalações elétricas',
    'encanador': 'Instalações hidráulicas',
    'azulejista': 'Revestimentos',
    'pintor': 'Pintura',
    'gesseiro': 'Acabamento',
  };

  /// "passou uns fios", "umas tomadas": coisa pouca, menção secundária.
  static final RegExp _poucoAntes =
      RegExp(r'(?:^|[^\w])(?:uns|umas|alguns|algumas|um\s+pouco\s+de|'
          r'uma\s+parte\s+d[aoe])\s*$');

  /// Verbos de atividade (radical do infinitivo em -ar/-ir): "rebocamos",
  /// "pintaram", "concretamos", "chapisquei". Todos pesam como atividade.
  static const Map<String, (String, int)> _verbos = {
    'rebocar': ('Reboco e contrapiso', 3),
    'embocar': ('Reboco e contrapiso', 3),
    'chapiscar': ('Reboco e contrapiso', 3),
    'pintar': ('Pintura', 3),
    'emassar': ('Pintura', 3),
    'lixar': ('Pintura', 2),
    'concretar': ('Estrutura', 2),
    'escorar': ('Estrutura', 2),
    'escavar': ('Fundação', 3),
    'cavar': ('Fundação', 2),
    'rejuntar': ('Revestimentos', 3),
    'azulejar': ('Revestimentos', 3),
    'revestir': ('Revestimentos', 3),
    'telhar': ('Cobertura', 3),
    'encanar': ('Instalações hidráulicas', 3),
  };

  /// Verbos genéricos que viram atividade pelo objeto: "assentamos o
  /// piso" é revestimento, "assentamos os blocos" é alvenaria.
  static const Map<String, List<(List<String>, String)>> _verbosComObjeto = {
    'assentar': [
      (
        ['piso', 'ceramica', 'porcelanato', 'azulejo', 'pastilha'],
        'Revestimentos'
      ),
      (['tijolo', 'bloco', 'parede', 'alvenaria'], 'Alvenaria'),
      (['telha'], 'Cobertura'),
    ],
    'levantar': [
      (['parede', 'muro', 'alvenaria', 'bloco', 'tijolo'], 'Alvenaria'),
    ],
    'erguer': [
      (['parede', 'muro', 'alvenaria'], 'Alvenaria'),
    ],
    'passar': [
      (
        ['fio', 'fiacao', 'cabo', 'eletroduto', 'conduite'],
        'Instalações elétricas'
      ),
      (['cano', 'tubulacao', 'esgoto'], 'Instalações hidráulicas'),
    ],
    'puxar': [
      (['fio', 'fiacao', 'cabo'], 'Instalações elétricas'),
    ],
    'instalar': [
      (
        ['tomada', 'interruptor', 'disjuntor', 'quadro', 'luminaria'],
        'Instalações elétricas'
      ),
      (
        ['registro', 'torneira', 'vaso', 'pia', 'chuveiro', 'caixa d'],
        'Instalações hidráulicas'
      ),
      (
        ['porta', 'janela', 'rodape', 'soleira', 'louca', 'bancada'],
        'Acabamento'
      ),
    ],
    'colocar': [
      (['piso', 'azulejo', 'ceramica', 'porcelanato'], 'Revestimentos'),
      (['telha'], 'Cobertura'),
      (
        ['porta', 'janela', 'rodape', 'soleira', 'louca', 'bancada'],
        'Acabamento'
      ),
    ],
  };

  /// "pintou um problema" é "surgiu", não pintura.
  static final RegExp _pintouIdioma = RegExp(
      r'^(?:\s+(?:um|uma|uns|umas|1))?\s+(?:problema|problemas|imprevisto|'
      r'duvida|servico|trabalho|trampo|oportunidade|chance|galho|encrenca|'
      r'treta|bronca|novidade|convite|sujeira)\b');

  /// Plano não é o que foi feito hoje: "amanhã vamos começar a pintura"
  /// pesa metade.
  static final RegExp _futuro =
      RegExp(r'(?:^|[^\w])(?:amanha|vamos|vai|vao|semana\s+que\s+vem|proxima|'
          r'falta|faltou|ainda\s+falta|previsto|depois\s+vamos)(?![\w])');

  /// Componente citado como lugar ("subimos o material pra laje") diz
  /// onde, não o que foi feito.
  static final RegExp _lugarAntes =
      RegExp(r'(?:^|[^\w])(?:na|no|pra|pro|para\s+a|para\s+o|em\s+cima\s+da|'
          r'em\s+cima\s+do)\s*$');

  /// Aberturas de comando que não fazem parte do relato.
  static final RegExp _aberturas = RegExp(
      r'^\s*(?:anota(?:r)?\s+a[ií]|anota(?:r)?|registra(?:r)?|escreve(?:r)?|'
      r'coloca(?:r)?|bota(?:r)?|poe|p[oõ]e)\s+'
      r'(?:no\s+di[aá]rio\s*)?(?:que\s+)?',
      caseSensitive: false);

  // ================================================================ API

  /// Interpreta o relato falado do dia. [agora] fixa o "hoje" nos testes.
  static DiarioPorVoz interpretar(String transcricao, {DateTime? agora}) {
    final original = transcricao.trim();
    // "contra piso" → "contrapiso"; "três pedreiros" → "3 pedreiros"
    final texto = NumeroExtenso.normalizar(VocabularioObra.corrigir(original));
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

  /// Interpreta as hipóteses do reconhecedor (a 1ª é a principal;
  /// confiança 0..1, ou <= 0 quando o aparelho não informa) e devolve o
  /// registro da melhor — a 1ª, a menos que outra seja claramente melhor.
  static DiarioPorVoz interpretarHipoteses(List<(String, double)> hipoteses,
      {DateTime? agora}) {
    return HipotesesVoz.escolher<DiarioPorVoz>(
      hipoteses,
      interpretar: (t) => interpretar(t, agora: agora),
      pontuar: pontuar,
    );
  }

  /// Quanto do relato o parser entendeu — base da escolha de hipótese.
  static double pontuar(DiarioPorVoz r, String texto) {
    var p = 0.0;
    if (r.clima != null) p += 1;
    if (r.numeroPessoas != null) p += 1;
    if (r.fase != null) p += 1;
    if (r.data != null) p += 0.5;
    p += 0.25 * VocabularioObra.contarTermos(texto).clamp(0, 4);
    return p;
  }

  // ============================================================== Clima

  static String? _extrairClima(String t) {
    final achados = <(int, int, int)>[]; // início, fim, prioridade
    for (var prioridade = 0; prioridade < _clima.length; prioridade++) {
      for (final termo in _clima[prioridade].$2) {
        for (final (inicio, fim)
            in _ocorrencias(t, TextoBr.normalizar(termo))) {
          achados.add((inicio, fim, prioridade));
        }
      }
    }
    for (final (padrao, prioridade) in _climaComVerbo) {
      for (final m in padrao.allMatches(t)) {
        achados.add((m.start, m.end, prioridade));
      }
    }
    // O termo mais longo fica com o trecho: "cara de chuva" não é chuva.
    achados.sort((a, b) => (b.$2 - b.$1).compareTo(a.$2 - a.$1));
    final aceitos = <(int, int, int)>[];
    for (final a in achados) {
      if (aceitos.any((o) => a.$1 < o.$2 && a.$2 > o.$1)) continue;
      aceitos.add(a);
    }

    int? melhor;
    for (final (inicio, fim, prioridade) in aceitos) {
      final antes = _mesmaOracao(t.substring(0, inicio));
      if (_parouAntes.hasMatch(antes)) {
        // "não parou de chover": choveu.
      } else if (_negacaoAntes.hasMatch(antes) ||
          _irrealAntes.hasMatch(antes) ||
          _negacaoDepois.hasMatch(t.substring(fim))) {
        continue;
      }
      if (melhor == null || prioridade < melhor) melhor = prioridade;
    }
    return melhor == null ? null : _clima[melhor].$1;
  }

  // ============================================================ Pessoas

  static int? _extrairPessoas(String t) {
    // "equipe de 6: 2 pedreiros e 4 serventes" — o total anunciado manda.
    int? anunciado;
    for (final m in _totalAnunciado.allMatches(t)) {
      if (_naoEhGente.hasMatch(t.substring(m.end))) continue;
      anunciado = int.parse(m.group(1)!);
    }
    if (anunciado != null) return _plausivel(anunciado);

    final contados = <(int, int)>[]; // trechos já contados
    final comNumero = <String>{}; // profissões contadas com número
    var total = 0;

    bool livre(int inicio, int fim) =>
        !contados.any((c) => inicio < c.$2 && fim > c.$1);

    // Quem não veio, ou só vem amanhã, não estava no canteiro hoje.
    bool foraDoDia(int inicio, int fim) =>
        _ausenciaDepois.hasMatch(t.substring(fim)) ||
        _futuro.hasMatch(_mesmaOracao(t.substring(0, inicio)));

    // "3 pedreiros", "1 servente", "mais 2 ajudantes".
    final numerada = RegExp(r'(?<![\d.,])(\d+)\s+([a-z]+)');
    for (final m in numerada.allMatches(t)) {
      final profissao = _trabalhadores[m.group(2)];
      if (profissao == null) continue;
      if (foraDoDia(m.start, m.end)) {
        contados.add((m.start, m.end));
        continue;
      }
      total += int.parse(m.group(1)!);
      comNumero.add(profissao);
      contados.add((m.start, m.end));
    }

    // "trabalharam 5", "vieram 3": gente sem profissão dita.
    for (final m in [
      ..._grupoPorVerbo.allMatches(t),
      ..._maisN.allMatches(t)
    ]) {
      final inicioNumero = m.end - m.group(1)!.length;
      if (!livre(inicioNumero, m.end)) continue;
      final depois = t.substring(m.end);
      if (_naoEhGente.hasMatch(depois)) continue;
      // número seguido de profissão já foi contado acima
      final seguinte = RegExp(r'^\s+([a-z]+)').firstMatch(depois)?.group(1);
      if (seguinte != null && _visitantes.contains(seguinte)) continue;
      if (foraDoDia(m.start, m.end)) continue;
      total += int.parse(m.group(1)!);
      contados.add((inicioNumero, m.end));
    }

    // "o carpinteiro e o ajudante dele": cada profissão citada no
    // singular, sem número, é uma pessoa — uma vez só, por mais que o
    // relato fale dela de novo.
    final singulares = <String>{};
    var pluralSemNumero = false;
    for (final m in RegExp(r'[a-z]+').allMatches(t)) {
      final palavra = m.group(0)!;
      final profissao = _trabalhadores[palavra];
      if (profissao == null || !livre(m.start, m.end)) continue;
      if (comNumero.contains(profissao)) continue;
      if (foraDoDia(m.start, m.end)) continue;
      if (palavra == profissao) {
        if (_singularAmbiguo.contains(palavra)) continue;
        singulares.add(profissao);
      } else {
        // "os pedreiros" sem dizer quantos
        pluralSemNumero = true;
      }
    }
    // Quantos são "os pedreiros"? Sem número, qualquer total seria chute.
    if (pluralSemNumero) return null;
    total += singulares.length;

    // Filho, irmão, sócio ao lado do falante: uma pessoa cada, uma vez só.
    final parentes = <String>{
      for (final m in _parenteJunto.allMatches(t))
        if (_parentes.contains(m.group(1) ?? m.group(2)))
          m.group(1) ?? m.group(2)!,
    };
    total += parentes.length;

    final euNaEquipe = _euJunto.hasMatch(t) ||
        (total > 0 && _euEmLista.hasMatch(t)) ||
        _equipeEEu.allMatches(t).any((m) => m
            .group(1)!
            .split(RegExp(r'\s+'))
            .any((w) =>
                _trabalhadores.containsKey(w) ||
                _parentes.contains(w) ||
                const {'ele', 'ela', 'dele', 'dela'}.contains(w)));
    if (euNaEquipe) total += 1;
    if (total == 0 && _sozinho.hasMatch(t)) return 1;
    return total == 0 ? null : _plausivel(total);
  }

  static int? _plausivel(int n) => n > 0 && n <= 500 ? n : null;

  // =============================================================== Fase

  static String? _extrairFase(String t) {
    final pontos = <String, double>{};
    void somar(String fase, int peso, int inicio, int fim) {
      final antes = t.substring(0, inicio);
      final oracao = _mesmaOracao(antes);
      // "não deu pra rebocar": não aconteceu.
      if (_negacaoAntes.hasMatch(oracao)) return;
      var p = peso.toDouble();
      if (_futuro.hasMatch(oracao)) p /= 2;
      if (peso == 2 && _lugarAntes.hasMatch(antes)) p = 1;
      if (_poucoAntes.hasMatch(antes)) p /= 2;
      pontos[fase] = (pontos[fase] ?? 0) + p;
    }

    for (final entrada in _fases.entries) {
      for (final (termo, peso) in entrada.value) {
        for (final (inicio, fim) in _ocorrencias(t, termo)) {
          somar(entrada.key, peso, inicio, fim);
        }
      }
    }

    for (final m in RegExp(r'[a-z]+').allMatches(t)) {
      final palavra = m.group(0)!;
      final verbo = _verboDe(palavra, _verbos.keys);
      if (verbo != null) {
        if (verbo == 'pintar' && _pintouIdioma.hasMatch(t.substring(m.end))) {
          continue;
        }
        final (fase, peso) = _verbos[verbo]!;
        somar(fase, peso, m.start, m.end);
        continue;
      }
      final generico = _verboDe(palavra, _verbosComObjeto.keys);
      if (generico == null) continue;
      // o objeto vem nas próximas palavras ("assentamos os blocos")
      final objeto = RegExp(r'^(?:\s+[a-z]+){1,4}')
              .firstMatch(t.substring(m.end))
              ?.group(0) ??
          '';
      // Verbo genérico pesa menos que o verbo da própria atividade
      // ("rebocamos"): quem diz a fase é o objeto.
      for (final (objetos, fase) in _verbosComObjeto[generico]!) {
        final alvo = TextoBr.primeiroQueCasa(objeto, objetos);
        if (alvo != null) {
          final pouco =
              _poucoAntes.hasMatch(objeto.substring(0, objeto.indexOf(alvo)));
          somar(fase, pouco ? 1 : 2, m.start, m.end);
          break;
        }
      }
    }

    for (final (inicio, fim) in [
      for (final dica in _dicasDeProfissao.keys) ..._ocorrencias(t, dica),
    ]) {
      final fase = _dicasDeProfissao[
          t.substring(inicio, fim).replaceFirst(RegExp(r'(?:es|s)$'), '')];
      if (fase != null && !pontos.containsKey(fase)) {
        somar(fase, 1, inicio, fim);
      }
    }

    String? melhor;
    var melhorPontos = 0.0;
    var segundo = 0.0;
    for (final e in pontos.entries) {
      if (e.value > melhorPontos) {
        segundo = melhorPontos;
        melhorPontos = e.value;
        melhor = e.key;
      } else if (e.value > segundo) {
        segundo = e.value;
      }
    }
    // Uma menção solta a um objeto genérico ("a porta") não diz a fase;
    // e empate sem atividade dominante também não.
    if (melhor == null || melhorPontos < 2 || segundo >= melhorPontos) {
      return null;
    }
    // A fase precisa existir na lista do formulário para ser selecionável.
    return AppConstants.fasesPadrao.contains(melhor) ? melhor : null;
  }

  /// O infinitivo do qual [palavra] é uma conjugação comum ("rebocamos",
  /// "reboquei", "pintaram", "revestimos"), ou null.
  static String? _verboDe(String palavra, Iterable<String> infinitivos) {
    for (final inf in infinitivos) {
      if (_conjugacoes(inf).contains(palavra)) return inf;
    }
    return null;
  }

  static final Map<String, Set<String>> _cacheConjugacoes = {};

  static Set<String> _conjugacoes(String infinitivo) =>
      _cacheConjugacoes.putIfAbsent(infinitivo, () {
        final radical = infinitivo.substring(0, infinitivo.length - 2);
        if (infinitivo.endsWith('ir') || infinitivo.endsWith('er')) {
          final v = infinitivo[infinitivo.length - 2];
          return {
            infinitivo,
            '$radical${v}ndo',
            '${radical}ido',
            '${radical}ida',
            '${radical}idos',
            '${radical}idas',
            '$radical${v}mos',
            '$radical${v}ram',
            '${radical}iu',
            '${radical}eu',
          };
        }
        // c → qu e g → gu antes de "ei": "reboquei", "chapisquei".
        final radicalEi = radical.endsWith('c')
            ? '${radical.substring(0, radical.length - 1)}qu'
            : radical.endsWith('g')
                ? '${radical}u'
                : radical;
        return {
          infinitivo,
          '${radical}ando',
          '${radical}ado',
          '${radical}ada',
          '${radical}ados',
          '${radical}adas',
          '${radical}amos',
          '${radical}aram',
          '${radical}ou',
          '${radicalEi}ei',
          '${radical}ava',
          '${radical}avam',
          '${radical}aremos',
        };
      });

  // ============================================================== Apoio

  /// Posições de [termo] (sem acento) no texto, por palavra inteira e
  /// aceitando plural — o mesmo critério do TextoBr.contemPalavra.
  static Iterable<(int, int)> _ocorrencias(String texto, String termo) sync* {
    if (termo.isEmpty) return;
    var i = texto.indexOf(termo);
    while (i != -1) {
      final fim = i + termo.length;
      final antesOk = i == 0 || !_ehLetraOuDigito(texto.codeUnitAt(i - 1));
      if (antesOk) {
        final fimComPlural = _fimComPlural(texto, fim);
        if (fimComPlural != null) yield (i, fimComPlural);
      }
      i = texto.indexOf(termo, i + 1);
    }
  }

  static int? _fimComPlural(String texto, int fim) {
    bool fronteira(int j) =>
        j >= texto.length || !_ehLetraOuDigito(texto.codeUnitAt(j));
    if (fronteira(fim)) return fim;
    if (texto[fim] == 's' && fronteira(fim + 1)) return fim + 1;
    if (texto.startsWith('es', fim) && fronteira(fim + 2)) return fim + 2;
    return null;
  }

  static bool _ehLetraOuDigito(int c) =>
      (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || (c >= 192 && c <= 255);

  /// O trecho da mesma oração antes de um termo — negação e futuro não
  /// atravessam vírgula nem "mas" ("não choveu, sol o dia todo").
  static String _mesmaOracao(String antes) {
    final corte = RegExp(r'[,.;!?]|(?:^|[^\w])(?:mas|porem|so\s+que)(?![\w])')
        .allMatches(antes);
    if (corte.isEmpty) return antes;
    return antes.substring(corte.last.end);
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
