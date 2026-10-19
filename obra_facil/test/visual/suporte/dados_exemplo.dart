// Dados de exemplo das capturas de tela — fictícios, fixos e coerentes.
//
// O MESMO conjunto alimenta as capturas do "antes" e do "depois" do
// redesenho: não mude valores, nomes ou datas sem refazer as duas séries,
// senão a comparação lado a lado deixa de valer.
//
// Datas fixas em 2026 (a obra está em outubro de 2026). Algumas telas
// comparam com o relógio real (DateTime.now) — ver LEIA-ME-capturas.md.

import 'package:obra_facil/models/models.dart';

/// Ids estáveis, usados nas rotas (`/obras/<id>`).
abstract class IdsExemplo {
  static const obra = 'sobrado-vila-izabel';
  static const obraReforma = 'reforma-apto-802';
  static const obraConcluida = 'casa-santa-felicidade';

  static const dono = 'u-marina';
  static const mestre = 'u-joaquim';
  static const cliente = 'u-paulo';
}

DateTime _d(int ano, int mes, int dia, [int hora = 10]) =>
    DateTime(ano, mes, dia, hora);

/// Pessoas: dono, mestre de obras e cliente.
abstract class UsuariosExemplo {
  static final dono = UsuarioModel(
    id: IdsExemplo.dono,
    nome: 'Marina Souza',
    email: 'marina.souza@exemplo.com',
    perfil: PerfilUsuario.dono,
    criadoEm: _d(2025, 2, 3),
  );

  static final mestre = UsuarioModel(
    id: IdsExemplo.mestre,
    nome: 'Joaquim Pereira',
    email: 'joaquim.pereira@exemplo.com',
    perfil: PerfilUsuario.mestre,
    criadoEm: _d(2025, 2, 10),
  );

  static final cliente = UsuarioModel(
    id: IdsExemplo.cliente,
    nome: 'Paulo Andrade',
    email: 'paulo.andrade@exemplo.com',
    perfil: PerfilUsuario.cliente,
    criadoEm: _d(2026, 4, 22),
  );

  static final todos = [dono, mestre, cliente];
}

/// O conjunto completo de dados que o FirestoreService falso devolve.
class DadosExemplo {
  final List<ObraModel> obras;
  final Map<String, List<LancamentoModel>> lancamentos;
  final Map<String, List<CronogramaFaseModel>> cronograma;
  final Map<String, List<DiarioEntradaModel>> diario;
  final Map<String, List<EstoqueItemModel>> estoque;
  final Map<String, List<MovimentoEstoqueModel>> movimentos;
  final Map<String, List<FotoObraModel>> fotos;
  final List<FornecedorModel> fornecedores;

  const DadosExemplo({
    required this.obras,
    required this.lancamentos,
    required this.cronograma,
    required this.diario,
    required this.estoque,
    required this.movimentos,
    required this.fotos,
    required this.fornecedores,
  });

  /// A obra principal das capturas.
  ObraModel get sobrado => obras.firstWhere((o) => o.id == IdsExemplo.obra);

  factory DadosExemplo.padrao() {
    const id = IdsExemplo.obra;
    return DadosExemplo(
      obras: _obras(),
      lancamentos: {id: _lancamentos()},
      cronograma: {id: _cronograma()},
      diario: {id: _diario()},
      estoque: {id: _estoque()},
      movimentos: {id: _movimentos()},
      fotos: {id: const []},
      fornecedores: _fornecedores(),
    );
  }
}

// ------------------------------------------------------------------ Obras

List<ObraModel> _obras() => [
      ObraModel(
        id: IdsExemplo.obra,
        nome: 'Sobrado Vila Izabel',
        endereco: 'Rua das Araucárias, 210 – Vila Izabel, Curitiba/PR',
        cliente: 'Família Andrade',
        orcamento: 260000,
        dataInicio: _d(2026, 5, 4, 0),
        previsaoTermino: _d(2027, 3, 26, 0),
        status: StatusObra.emAndamento,
        donoId: IdsExemplo.dono,
        equipeIds: const [IdsExemplo.mestre],
        clientesIds: const [IdsExemplo.cliente],
        codigoConvite: 'VZ4K7P',
        codigoCliente: 'CL8M2R',
        criadoEm: _d(2026, 4, 20),
      ),
      ObraModel(
        id: IdsExemplo.obraReforma,
        nome: 'Reforma Apto 802 – Água Verde',
        endereco: 'Av. República Argentina, 1450, ap. 802 – Água Verde, '
            'Curitiba/PR',
        orcamento: 68000,
        dataInicio: _d(2026, 3, 2, 0),
        previsaoTermino: _d(2026, 11, 27, 0),
        status: StatusObra.pausada,
        donoId: IdsExemplo.dono,
        codigoConvite: 'AV8T2Q',
        criadoEm: _d(2026, 2, 16),
      ),
      ObraModel(
        id: IdsExemplo.obraConcluida,
        nome: 'Casa térrea Santa Felicidade',
        endereco: 'Rua Via Vêneto, 88 – Santa Felicidade, Curitiba/PR',
        orcamento: 410000,
        dataInicio: _d(2025, 3, 10, 0),
        previsaoTermino: _d(2026, 2, 27, 0),
        status: StatusObra.concluida,
        donoId: IdsExemplo.dono,
        equipeIds: const [IdsExemplo.mestre],
        codigoConvite: 'SF3N9W',
        criadoEm: _d(2025, 3, 1),
      ),
    ];

// ------------------------------------------------------------- Lançamentos

LancamentoModel _lanc(
  String id,
  DateTime data,
  String descricao,
  double valor,
  CategoriaCusto categoria, {
  StatusLancamento status = StatusLancamento.aprovado,
  OrigemLancamento origem = OrigemLancamento.manual,
  String? fornecedor,
  bool doDono = false,
  List<ItemMaterialModel> itens = const [],
  String? motivoRejeicao,
}) {
  final moderado = status != StatusLancamento.pendente;
  return LancamentoModel(
    id: id,
    obraId: IdsExemplo.obra,
    descricao: descricao,
    valor: valor,
    categoria: categoria,
    status: status,
    origem: origem,
    fornecedorId: fornecedor == null ? null : _idFornecedor(fornecedor),
    fornecedorNome: fornecedor,
    itens: itens,
    data: data,
    criadoPorId: doDono ? IdsExemplo.dono : IdsExemplo.mestre,
    criadoPorNome: doDono ? 'Marina Souza' : 'Joaquim Pereira',
    aprovadoPorId: moderado ? IdsExemplo.dono : null,
    motivoRejeicao: motivoRejeicao,
    moderadoEm: moderado ? data.add(const Duration(hours: 6)) : null,
    criadoEm: data,
  );
}

/// 16 aprovados somando R$ 112.380,00; 1 rejeitado; 3 pendentes somando
/// R$ 4.912,40.
List<LancamentoModel> _lancamentos() {
  const mat = CategoriaCusto.material;
  const mao = CategoriaCusto.maoDeObra;
  const equ = CategoriaCusto.equipamento;
  final lista = [
    // Fundação
    _lanc('l01', _d(2026, 5, 11), 'Locação de retroescavadeira (2 dias)', 2400,
        equ,
        fornecedor: 'Terraplenagem Iguaçu', doDono: true),
    _lanc('l02', _d(2026, 5, 18),
        'Concreto usinado fck 25 – sapatas e baldrame (14 m³)', 7840, mat,
        fornecedor: 'Concreteira Barigui', doDono: true),
    _lanc(
        'l03', _d(2026, 5, 22), 'Vergalhão CA-50 10 mm (80 barras)', 4160, mat,
        fornecedor: 'Aço Paraná',
        origem: OrigemLancamento.ocr,
        itens: const [
          ItemMaterialModel(
              material: 'Vergalhão CA-50 10 mm', quantidade: 80, unidade: 'br'),
        ]),
    _lanc('l04', _d(2026, 5, 29), 'Empreitada da fundação – equipe', 9800, mao,
        doDono: true),
    // Estrutura
    _lanc('l05', _d(2026, 6, 19), 'Formas e escoramento – locação', 3250, equ,
        fornecedor: 'Andaimes Curitiba'),
    _lanc('l06', _d(2026, 7, 3),
        'Concreto usinado – pilares e laje do térreo (22 m³)', 12980, mat,
        fornecedor: 'Concreteira Barigui', doDono: true),
    _lanc('l07', _d(2026, 7, 10), 'Vergalhão e tela soldada da laje', 6720, mat,
        fornecedor: 'Aço Paraná', origem: OrigemLancamento.ocr),
    _lanc('l08', _d(2026, 7, 31), 'Empreitada da estrutura – 1ª etapa', 14500,
        mao,
        doDono: true),
    _lanc('l09', _d(2026, 8, 14), 'Laje superior – concreto e bombeamento',
        11640, mat,
        fornecedor: 'Concreteira Barigui', doDono: true),
    _lanc('l10', _d(2026, 8, 28), 'Empreitada da estrutura – 2ª etapa', 12300,
        mao,
        doDono: true),
    // Alvenaria
    _lanc(
        'l11', _d(2026, 9, 11), 'Bloco cerâmico 14x19x29 (4.000 un)', 6200, mat,
        fornecedor: 'Casa do Construtor',
        origem: OrigemLancamento.ocr,
        itens: const [
          ItemMaterialModel(
              material: 'Bloco cerâmico 14x19x29',
              quantidade: 4000,
              unidade: 'un'),
        ]),
    _lanc('l12', _d(2026, 9, 18), 'Cimento CP-II 50 kg (60 sacos)', 2340, mat,
        fornecedor: 'Casa do Construtor',
        origem: OrigemLancamento.ocr,
        itens: const [
          ItemMaterialModel(
              material: 'Cimento CP-II 50 kg', quantidade: 60, unidade: 'sc'),
        ]),
    _lanc('l13', _d(2026, 9, 25), 'Empreitada da alvenaria – medição 1', 8600,
        mao,
        doDono: true),
    _lanc('l14', _d(2026, 10, 2), 'Andaime tubular – locação mensal', 1150, equ,
        fornecedor: 'Andaimes Curitiba'),
    _lanc('l15', _d(2026, 10, 9), 'Empreitada da alvenaria – medição 2', 6630,
        mao,
        doDono: true),
    _lanc(
        'l16', _d(2026, 10, 13), 'Argamassa e cal para assentamento', 1870, mat,
        fornecedor: 'Casa do Construtor',
        origem: OrigemLancamento.voz,
        itens: const [
          ItemMaterialModel(
              material: 'Argamassa de assentamento',
              quantidade: 30,
              unidade: 'sc'),
          ItemMaterialModel(
              material: 'Cal hidratada', quantidade: 20, unidade: 'sc'),
        ]),
    // Rejeitado
    _lanc(
        'l17', _d(2026, 10, 7), 'Disco de corte diamantado (5 un)', 189.90, equ,
        status: StatusLancamento.rejeitado,
        fornecedor: 'Casa do Construtor',
        motivoRejeicao: 'Já temos discos no estoque.'),
    // Pendentes (a fila de aprovação da Marina)
    _lanc('l18', _d(2026, 10, 14, 15), 'Bloco cerâmico 9 furos', 2380, mat,
        status: StatusLancamento.pendente,
        fornecedor: 'Casa do Construtor',
        origem: OrigemLancamento.ocr,
        itens: const [
          ItemMaterialModel(
              material: 'Bloco cerâmico 9 furos',
              quantidade: 2000,
              unidade: 'un'),
        ]),
    _lanc('l19', _d(2026, 10, 14, 11), 'Areia média', 1290, mat,
        status: StatusLancamento.pendente,
        fornecedor: 'Areial São Jorge',
        origem: OrigemLancamento.voz,
        itens: const [
          ItemMaterialModel(
              material: 'Areia média', quantidade: 6, unidade: 'm³'),
        ]),
    _lanc('l20', _d(2026, 10, 13, 17), 'Diária de servente (3 dias)', 1242.40,
        mao,
        status: StatusLancamento.pendente),
  ];
  return lista;
}

// ------------------------------------------------------------- Cronograma

List<CronogramaFaseModel> _cronograma() {
  // (fase, início, fim, %) — as 10 fases padrão, na ordem de
  // AppConstants.fasesPadrao: Fundação e Estrutura prontas, Alvenaria em
  // 60% e o resto por começar.
  final fases = <(String, DateTime, DateTime, int)>[
    ('Fundação', _d(2026, 5, 4, 0), _d(2026, 6, 5, 0), 100),
    ('Estrutura', _d(2026, 6, 8, 0), _d(2026, 8, 28, 0), 100),
    ('Alvenaria', _d(2026, 9, 1, 0), _d(2026, 11, 13, 0), 60),
    ('Cobertura', _d(2026, 11, 16, 0), _d(2026, 12, 18, 0), 0),
    ('Instalações elétricas', _d(2026, 11, 23, 0), _d(2027, 1, 29, 0), 0),
    ('Instalações hidráulicas', _d(2026, 11, 9, 0), _d(2027, 1, 29, 0), 0),
    ('Reboco e contrapiso', _d(2026, 12, 14, 0), _d(2027, 2, 12, 0), 0),
    ('Revestimentos', _d(2027, 1, 11, 0), _d(2027, 3, 5, 0), 0),
    ('Pintura', _d(2027, 2, 22, 0), _d(2027, 3, 26, 0), 0),
    ('Acabamento', _d(2027, 3, 1, 0), _d(2027, 3, 26, 0), 0),
  ];
  return [
    for (var i = 0; i < fases.length; i++)
      CronogramaFaseModel(
        id: 'fase-$i',
        obraId: IdsExemplo.obra,
        nome: fases[i].$1,
        ordem: i,
        dataInicio: fases[i].$2,
        dataFim: fases[i].$3,
        percentualConcluido: fases[i].$4,
      ),
  ];
}

// ------------------------------------------------------------------ Diário

List<DiarioEntradaModel> _diario() {
  DiarioEntradaModel e(String id, DateTime data, String clima, int pessoas,
          String descricao) =>
      DiarioEntradaModel(
        id: id,
        obraId: IdsExemplo.obra,
        descricao: descricao,
        fase: 'Alvenaria',
        numeroPessoas: pessoas,
        clima: clima,
        registradoPorId: IdsExemplo.mestre,
        registradoPorNome: 'Joaquim Pereira',
        data: data,
        criadoEm: data.add(const Duration(hours: 8)),
      );
  return [
    e(
        'd1',
        _d(2026, 10, 14, 8),
        'Ensolarado',
        6,
        'Elevação da alvenaria do pavimento superior, lado da rua. Chegou o '
            'bloco 9 furos da Casa do Construtor.'),
    e(
        'd2',
        _d(2026, 10, 13, 8),
        'Nublado',
        7,
        'Primeira fiada dos quartos do pavimento superior e vergas das '
            'janelas da fachada.'),
    e(
        'd3',
        _d(2026, 10, 12, 8),
        'Chuvoso',
        3,
        'Chuva a manhã toda. Equipe reduzida organizou o canteiro e conferiu '
            'o prumo das paredes do térreo.'),
    e(
        'd4',
        _d(2026, 10, 9, 8),
        'Ensolarado',
        6,
        'Fechamento das paredes da cozinha e da lavanderia; vergas e '
            'contravergas das janelas do térreo.'),
    e('d5', _d(2026, 10, 8, 8), 'Nublado', 5,
        'Alvenaria da garagem concluída. Andaime montado na fachada.'),
  ];
}

// ----------------------------------------------------------------- Estoque

List<EstoqueItemModel> _estoque() {
  EstoqueItemModel i(
          String id, String material, double qtd, String un, double minimo) =>
      EstoqueItemModel(
        id: id,
        obraId: IdsExemplo.obra,
        material: material,
        quantidade: qtd,
        unidade: un,
        quantidadeMinima: minimo,
        atualizadoEm: _d(2026, 10, 14, 17),
      );
  return [
    i('e1', 'Areia média', 1.5, 'm³', 3),
    i('e2', 'Argamassa de assentamento', 14, 'sc', 10),
    i('e3', 'Bloco cerâmico 14x19x29', 620, 'un', 400),
    i('e4', 'Cal hidratada', 9, 'sc', 5),
    i('e5', 'Cimento CP-II 50 kg', 22, 'sc', 15),
    i('e6', 'Eletroduto corrugado 3/4"', 4, 'pc', 2),
    i('e7', 'Vergalhão CA-50 8 mm', 12, 'br', 10),
  ];
}

List<MovimentoEstoqueModel> _movimentos() {
  MovimentoEstoqueModel m(String id, DateTime data, String material,
          TipoMovimentoEstoque tipo, double qtd, String un,
          {String origem = 'manual', String? lancamentoId}) =>
      MovimentoEstoqueModel(
        id: id,
        obraId: IdsExemplo.obra,
        material: material,
        tipo: tipo,
        quantidade: qtd,
        unidade: un,
        origem: origem,
        lancamentoId: lancamentoId,
        data: data,
      );
  const ent = TipoMovimentoEstoque.entrada;
  const sai = TipoMovimentoEstoque.saida;
  return [
    m('m1', _d(2026, 9, 11), 'Bloco cerâmico 14x19x29', ent, 4000, 'un',
        origem: 'aprovacao', lancamentoId: 'l11'),
    m('m2', _d(2026, 9, 18), 'Cimento CP-II 50 kg', ent, 60, 'sc',
        origem: 'aprovacao', lancamentoId: 'l12'),
    m('m3', _d(2026, 9, 25), 'Bloco cerâmico 14x19x29', sai, 1600, 'un'),
    m('m4', _d(2026, 10, 2), 'Bloco cerâmico 14x19x29', sai, 1080, 'un'),
    m('m5', _d(2026, 10, 2), 'Cimento CP-II 50 kg', sai, 20, 'sc'),
    m('m6', _d(2026, 10, 9), 'Bloco cerâmico 14x19x29', sai, 700, 'un'),
    m('m7', _d(2026, 10, 9), 'Cimento CP-II 50 kg', sai, 18, 'sc'),
    m('m8', _d(2026, 10, 13), 'Argamassa de assentamento', ent, 30, 'sc',
        origem: 'aprovacao', lancamentoId: 'l16'),
    m('m9', _d(2026, 10, 13), 'Cal hidratada', ent, 20, 'sc',
        origem: 'aprovacao', lancamentoId: 'l16'),
    m('m10', _d(2026, 10, 14), 'Argamassa de assentamento', sai, 16, 'sc'),
    m('m11', _d(2026, 10, 14), 'Cal hidratada', sai, 11, 'sc'),
  ];
}

// ------------------------------------------------------------ Fornecedores

String _idFornecedor(String nome) =>
    'f-${nome.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';

List<FornecedorModel> _fornecedores() {
  FornecedorModel f(String nome, String telefone) => FornecedorModel(
        id: _idFornecedor(nome),
        donoId: IdsExemplo.dono,
        nome: nome,
        telefone: telefone,
        criadoEm: _d(2026, 5, 4),
      );
  return [
    f('Aço Paraná', '(41) 3000-0101'),
    f('Andaimes Curitiba', '(41) 3000-0102'),
    f('Areial São Jorge', '(41) 3000-0103'),
    f('Casa do Construtor', '(41) 3000-0104'),
    f('Concreteira Barigui', '(41) 3000-0105'),
    f('Terraplenagem Iguaçu', '(41) 3000-0106'),
  ];
}
