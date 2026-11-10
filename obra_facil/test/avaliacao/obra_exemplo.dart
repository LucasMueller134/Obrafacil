import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/services/ia/perguntas_obra_service.dart';

/// "Agora" fixo da bateria de perguntas: terça-feira, 10/11/2026, fim do dia.
final agoraExemplo = DateTime(2026, 11, 10, 17, 30);

/// Obra de exemplo da bateria de perguntas (`casos/perguntas.json`).
///
/// Os números que os casos conferem saem daqui. Conferidos à mão:
///
/// | o quê | valor |
/// |---|---|
/// | gasto aprovado total | R$ 102.715,00 |
/// | material / mão de obra / equipamento / outros | 51.805 / 46.300 / 3.050 / 1.560 |
/// | jun / jul / ago / set / out / nov | 17.500 / 7.500 / 32.770 / 11.240 / 19.225 / 14.480 |
/// | semana passada (02 a 08/11) | R$ 13.280,00 |
/// | orçamento / saldo / usado | R$ 280.000,00 / R$ 177.285,00 / 37% |
/// | pendentes | 3, R$ 4.700,00 |
/// | recusados | pregos e parafusos (640), compactador (520) |
/// | maior gasto | empreitada da estrutura, R$ 15.500,00 |
/// | maior fornecedor | Cerâmica Vale Verde, R$ 14.300,00 |
/// | cimento nas notas | 60 sc (2.280) + 30 sc (1.185) = R$ 3.465,00 |
/// | equipe do Valdir (sem fornecedor, na descrição) | R$ 42.500,00 |
/// | estoque baixo | cimento 6 sc, areia 1,5 m³, tijolo 450 un, fio 150 m, prego 0 kg |
/// | andamento (média das fases, como nas telas) | 43% |
/// | fase atual (1ª começada e não terminada) | Alvenaria, 85% |
/// | fases atrasadas | Alvenaria (venceu 23/10), Instalações elétricas (venceu 30/10) |
/// | término previsto | 31/03/2027 (141 dias) |
/// | dias de chuva no diário | 27/10, 04/11 e 09/11 |
///
/// [cliente] devolve os dados como o app monta para quem contratou a obra:
/// só obra, diário e cronograma (`cliente_obra_screen.dart`).
DadosObraChat obraExemplo({bool cliente = false}) {
  final completo = DadosObraChat(
    obra: _obra,
    lancamentos: _lancamentos,
    diario: _diario,
    cronograma: _cronograma,
    estoque: _estoque,
    movimentos: _movimentos,
  );
  if (!cliente) return completo;
  return DadosObraChat(
    obra: _obra,
    lancamentos: const [],
    diario: _diario,
    cronograma: _cronograma,
    estoque: const [],
    movimentos: const [],
  );
}

const _id = 'obra-exemplo';

DateTime _d(int mes, int dia, [int ano = 2026]) => DateTime(ano, mes, dia);

final _obra = ObraModel(
  id: _id,
  nome: 'Casa Moura',
  endereco: 'Rua das Acácias, 210 — Jaraguá do Sul',
  cliente: 'Paula Moura',
  orcamento: 280000,
  dataInicio: _d(6, 1),
  previsaoTermino: _d(3, 31, 2027),
  donoId: 'dono',
  codigoConvite: 'OBR123',
  codigoCliente: 'CLI456',
  criadoEm: _d(5, 20),
);

ItemMaterialModel _item(String material, double qtd, String un, double total) =>
    ItemMaterialModel(
      material: material,
      quantidade: qtd,
      unidade: un,
      valorUnitario: total / qtd,
      valorTotal: total,
    );

LancamentoModel _lanc(
  String id,
  DateTime data,
  CategoriaCusto categoria,
  String descricao,
  double valor, {
  String? fornecedor,
  List<ItemMaterialModel> itens = const [],
  StatusLancamento status = StatusLancamento.aprovado,
  String? motivo,
}) =>
    LancamentoModel(
      id: id,
      obraId: _id,
      descricao: descricao,
      valor: valor,
      categoria: categoria,
      status: status,
      fornecedorNome: fornecedor,
      itens: itens,
      data: data,
      criadoPorId: 'mestre',
      criadoPorNome: 'Valdir',
      motivoRejeicao: motivo,
      criadoEm: data,
    );

const _mat = CategoriaCusto.material;
const _mao = CategoriaCusto.maoDeObra;
const _equip = CategoriaCusto.equipamento;
const _outros = CategoriaCusto.outros;

final _lancamentos = <LancamentoModel>[
  // ── aprovados ──
  _lanc('l01', _d(6, 3), _mat, 'Cimento, areia e brita da fundação', 4850,
      fornecedor: 'Depósito Bom Preço',
      itens: [
        _item('Cimento', 60, 'sc', 2280),
        _item('Areia', 8, 'm³', 1280),
        _item('Brita', 6, 'm³', 1290),
      ]),
  _lanc('l02', _d(6, 5), _equip, 'Aluguel de betoneira (junho)', 650,
      fornecedor: 'Locadora Sul Andaimes'),
  _lanc('l03', _d(6, 26), _mao, 'Empreitada da fundação — equipe do Valdir',
      12000),
  _lanc('l04', _d(7, 3), _mat, 'Vergalhões e arame', 6320,
      fornecedor: 'Ferragens Schmitt',
      itens: [
        _item('Vergalhão 10 mm', 150, 'br', 5520),
        _item('Arame recozido', 40, 'kg', 800),
      ]),
  _lanc('l05', _d(7, 17), _outros, 'Taxa do alvará', 1180,
      fornecedor: 'Prefeitura de Jaraguá do Sul'),
  _lanc('l06', _d(8, 7), _mao, 'Empreitada da estrutura — equipe do Valdir',
      15500),
  _lanc('l07', _d(8, 14), _mat, 'Concreto usinado da laje', 9870,
      fornecedor: 'Concreteira Norte',
      itens: [_item('Concreto usinado', 21, 'm³', 9870)]),
  _lanc('l08', _d(8, 24), _mat, 'Tijolos 6 furos', 7400,
      fornecedor: 'Cerâmica Vale Verde',
      itens: [_item('Tijolo 6 furos', 8000, 'un', 7400)]),
  _lanc('l09', _d(9, 11), _mao, 'Alvenaria, 1ª medição — equipe do Valdir',
      9000),
  _lanc('l10', _d(9, 23), _mat, 'Canos e conexões de PVC', 2240,
      fornecedor: 'Hidráulica Center',
      itens: [
        _item('Cano PVC 100 mm', 12, 'br', 1140),
        _item('Cano PVC 25 mm', 40, 'br', 1100),
      ]),
  _lanc('l11', _d(10, 5), _mat, 'Fios e eletrodutos', 3150,
      fornecedor: 'Elétrica Luz Forte',
      itens: [
        _item('Fio 2,5 mm', 1000, 'm', 1950),
        _item('Eletroduto', 300, 'm', 1200),
      ]),
  _lanc('l12', _d(10, 9), _equip, 'Andaimes (outubro)', 1200,
      fornecedor: 'Locadora Sul Andaimes'),
  _lanc('l13', _d(10, 15), _mat, 'Madeira do telhado', 8600,
      fornecedor: 'Madeireira Itapocu',
      itens: [_item('Madeira', 4.3, 'm³', 8600)]),
  _lanc('l14', _d(10, 21), _mao, 'Instalação elétrica, 1ª etapa', 3800,
      fornecedor: 'Rogério Eletricista'),
  _lanc('l15', _d(10, 28), _mat, 'Cimento e argamassa', 2475,
      fornecedor: 'Depósito Bom Preço',
      itens: [
        _item('Cimento', 30, 'sc', 1185),
        _item('Argamassa AC-I', 30, 'sc', 1290),
      ]),
  _lanc('l16', _d(11, 3), _mat, 'Telhas cerâmicas', 6900,
      fornecedor: 'Cerâmica Vale Verde',
      itens: [_item('Telha cerâmica', 3000, 'un', 6900)]),
  _lanc('l17', _d(11, 5), _mao, 'Alvenaria, 2ª medição — equipe do Valdir',
      6000),
  _lanc('l18', _d(11, 6), _outros, 'Caçamba de entulho', 380,
      fornecedor: 'Caçambas Jaraguá'),
  _lanc('l19', _d(11, 9), _equip, 'Andaimes (novembro)', 1200,
      fornecedor: 'Locadora Sul Andaimes'),

  // ── pendentes ──
  _lanc('p01', _d(11, 8), _mat, 'Areia e brita', 1350,
      fornecedor: 'Depósito Bom Preço',
      status: StatusLancamento.pendente,
      itens: [
        _item('Areia', 5, 'm³', 850),
        _item('Brita', 2, 'm³', 500),
      ]),
  _lanc('p02', _d(11, 9), _mao, 'Instalação elétrica, 2ª etapa', 2900,
      fornecedor: 'Rogério Eletricista', status: StatusLancamento.pendente),
  _lanc('p03', _d(11, 10), _outros, 'Frete das telhas', 450,
      status: StatusLancamento.pendente),

  // ── recusados ──
  _lanc('r01', _d(10, 30), _mat, 'Pregos e parafusos', 640,
      fornecedor: 'Ferragens Schmitt',
      status: StatusLancamento.rejeitado,
      motivo: 'Lançado em dobro'),
  _lanc('r02', _d(11, 4), _equip, 'Compactador de solo', 520,
      fornecedor: 'Locadora Sul Andaimes',
      status: StatusLancamento.rejeitado,
      motivo: 'O equipamento não chegou'),
];

DiarioEntradaModel _dia(DateTime data, String fase, int pessoas, String clima,
        String descricao) =>
    DiarioEntradaModel(
      id: 'd-${data.month}-${data.day}',
      obraId: _id,
      descricao: descricao,
      fase: fase,
      numeroPessoas: pessoas,
      clima: clima,
      registradoPorId: 'mestre',
      registradoPorNome: 'Valdir',
      data: data,
      criadoEm: data.add(const Duration(hours: 17)),
    );

// Sem registro em 01/11 (domingo), 02/11 (Finados), 07/11 (sábado) e
// 08/11 (domingo).
final _diario = <DiarioEntradaModel>[
  _dia(_d(10, 26), 'Alvenaria', 6, 'Ensolarado',
      'Levantamos as paredes do quarto do casal e do banheiro social.'),
  _dia(_d(10, 27), 'Alvenaria', 5, 'Chuvoso',
      'Chuva à tarde. De manhã, vergas e contravergas das janelas da frente.'),
  _dia(_d(10, 28), 'Alvenaria', 6, 'Nublado',
      'Chegou o cimento e a argamassa. Paredes da cozinha até a altura da laje.'),
  _dia(_d(10, 29), 'Instalações hidráulicas', 4, 'Ensolarado',
      'Encanador passou a tubulação de esgoto do banheiro social.'),
  _dia(_d(10, 30), 'Instalações elétricas', 5, 'Ensolarado',
      'Rasgos nas paredes para os eletrodutos dos quartos.'),
  _dia(_d(10, 31), 'Alvenaria', 3, 'Nublado',
      'Meio período: limpeza da obra e organização do material.'),
  _dia(_d(11, 3), 'Cobertura', 6, 'Ensolarado',
      'Chegaram as telhas. Começamos o madeiramento do telhado.'),
  _dia(_d(11, 4), 'Instalações hidráulicas', 2, 'Chuvoso',
      'Choveu o dia todo. Sem serviço externo; adiantamos o corte dos canos.'),
  _dia(_d(11, 5), 'Alvenaria', 7, 'Nublado',
      'Platibanda e parede da lavanderia. O eletricista não veio.'),
  _dia(_d(11, 6), 'Instalações elétricas', 4, 'Ensolarado',
      'Eletrodutos da sala e da cozinha passados. Caçamba de entulho trocada.'),
  _dia(_d(11, 9), 'Alvenaria', 3, 'Chuva forte',
      'Chuva forte de manhã; a equipe só trabalhou à tarde, no chapisco da '
          'cozinha. Paguei R\$ 450,00 de frete das telhas.'),
  _dia(_d(11, 10), 'Cobertura', 5, 'Ensolarado',
      'Madeiramento do telhado da ala dos quartos terminado. Começamos a '
          'colocar as telhas.'),
];

CronogramaFaseModel _fase(int ordem, String nome, DateTime inicio,
        DateTime fim, int pct) =>
    CronogramaFaseModel(
      id: 'f$ordem',
      obraId: _id,
      nome: nome,
      ordem: ordem,
      dataInicio: inicio,
      dataFim: fim,
      percentualConcluido: pct,
    );

final _cronograma = <CronogramaFaseModel>[
  _fase(0, 'Fundação', _d(6, 1), _d(7, 10), 100),
  _fase(1, 'Estrutura', _d(7, 6), _d(8, 31), 100),
  _fase(2, 'Alvenaria', _d(8, 17), _d(10, 23), 85), // atrasada
  _fase(3, 'Cobertura', _d(10, 19), _d(11, 28), 30), // em dia
  _fase(4, 'Instalações elétricas', _d(9, 14), _d(10, 30), 55), // atrasada
  _fase(5, 'Instalações hidráulicas', _d(9, 21), _d(12, 11), 60), // em dia
  _fase(6, 'Reboco e contrapiso', _d(11, 30), _d(1, 15, 2027), 0),
  _fase(7, 'Revestimentos', _d(1, 11, 2027), _d(2, 12, 2027), 0),
  _fase(8, 'Pintura', _d(2, 8, 2027), _d(3, 12, 2027), 0),
  _fase(9, 'Acabamento', _d(3, 1, 2027), _d(3, 31, 2027), 0),
];

EstoqueItemModel _est(String material, double qtd, String un, double minimo) =>
    EstoqueItemModel(
      id: 'e-${material.toLowerCase().replaceAll(' ', '-')}',
      obraId: _id,
      material: material,
      quantidade: qtd,
      unidade: un,
      quantidadeMinima: minimo,
      atualizadoEm: _d(11, 10),
    );

final _estoque = <EstoqueItemModel>[
  _est('Cimento', 6, 'sc', 10), // baixo
  _est('Areia', 1.5, 'm³', 2), // baixo
  _est('Brita', 3, 'm³', 1),
  _est('Tijolo 6 furos', 450, 'un', 500), // baixo
  _est('Argamassa AC-I', 14, 'sc', 5),
  _est('Telha cerâmica', 2650, 'un', 200),
  _est('Vergalhão 10 mm', 18, 'br', 10),
  _est('Fio 2,5 mm', 150, 'm', 200), // baixo
  _est('Cano PVC 100 mm', 5, 'br', 3),
  _est('Prego 17x27', 0, 'kg', 2), // acabou
];

var _seqMov = 0;

MovimentoEstoqueModel _mov(String material, TipoMovimentoEstoque tipo,
        double qtd, String un, DateTime data,
        {String? lancamentoId}) =>
    MovimentoEstoqueModel(
      id: 'm${_seqMov++}',
      obraId: _id,
      material: material,
      tipo: tipo,
      quantidade: qtd,
      unidade: un,
      origem: lancamentoId == null ? 'diario' : 'lancamento',
      lancamentoId: lancamentoId,
      data: data,
    );

const _entra = TipoMovimentoEstoque.entrada;
const _sai = TipoMovimentoEstoque.saida;

final _movimentos = <MovimentoEstoqueModel>[
  // Cimento: 1 sc + 30 sc que chegaram em 28/10, 25 sc usados → 6 sc.
  _mov('Cimento', _entra, 30, 'sc', _d(10, 28), lancamentoId: 'l15'),
  for (final (m, d, q) in [
    (10, 29, 4.0), (10, 31, 3.0), (11, 3, 4.0), (11, 4, 2.0),
    (11, 5, 4.0), (11, 6, 3.0), (11, 9, 2.0), (11, 10, 3.0),
  ])
    _mov('Cimento', _sai, q, 'sc', _d(m, d)),
  // Argamassa: 30 sc em 28/10, 16 sc usados → 14 sc.
  _mov('Argamassa AC-I', _entra, 30, 'sc', _d(10, 28), lancamentoId: 'l15'),
  for (final (m, d, q) in [
    (11, 3, 4.0), (11, 5, 5.0), (11, 6, 4.0), (11, 9, 3.0),
  ])
    _mov('Argamassa AC-I', _sai, q, 'sc', _d(m, d)),
  // Tijolo: consumo das últimas semanas de alvenaria.
  for (final (m, d, q) in [
    (10, 26, 300.0), (10, 28, 350.0), (10, 30, 300.0), (11, 3, 250.0),
    (11, 5, 400.0), (11, 6, 200.0), (11, 9, 150.0),
  ])
    _mov('Tijolo 6 furos', _sai, q, 'un', _d(m, d)),
  // Areia.
  for (final (m, d) in [(10, 29), (11, 3), (11, 5), (11, 9)])
    _mov('Areia', _sai, 0.5, 'm³', _d(m, d)),
  // Telha: 3000 em 03/11, 350 colocadas hoje → 2650.
  _mov('Telha cerâmica', _entra, 3000, 'un', _d(11, 3), lancamentoId: 'l16'),
  _mov('Telha cerâmica', _sai, 350, 'un', _d(11, 10)),
  // Fio e prego.
  _mov('Fio 2,5 mm', _sai, 120, 'm', _d(11, 6)),
  _mov('Prego 17x27', _sai, 1, 'kg', _d(10, 30)),
  _mov('Prego 17x27', _sai, 1.5, 'kg', _d(11, 5)),
];
