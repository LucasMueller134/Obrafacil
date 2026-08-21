import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';

/// Acesso ao Firestore.
///
/// Estrutura de dados:
/// - usuarios/{uid}
/// - obras/{obraId} (subcoleções: lancamentos, estoque, diario, cronograma, fotos)
/// - convites/{codigo} (aponta para a obra, sem carregar dado financeiro)
/// - fornecedores/{id} (campo donoId — compartilhados entre as obras do dono)
///
/// O modo offline usa a persistência local nativa do Firestore: leituras vêm
/// do cache e escritas entram numa fila que sincroniza quando a conexão volta.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _obras =>
      _db.collection('obras');

  CollectionReference<Map<String, dynamic>> get _convites =>
      _db.collection('convites');

  CollectionReference<Map<String, dynamic>> _sub(
          String obraId, String nome) =>
      _obras.doc(obraId).collection(nome);

  // ---------------------------------------------------------------- Obras

  /// Obras onde o usuário é dono ou faz parte da equipe.
  Stream<List<ObraModel>> obrasDoUsuario(String uid) {
    return _obras
        .where(
          Filter.or(
            Filter('donoId', isEqualTo: uid),
            Filter('equipeIds', arrayContains: uid),
          ),
        )
        .snapshots()
        .map((s) => s.docs.map((d) => ObraModel.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm)));
  }

  /// Obras que o cliente acompanha.
  ///
  /// Consulta separada de propósito: o Firestore aceita um único
  /// `arrayContains` por consulta, então juntar equipe e clientes num OR
  /// quebraria — e manter separado deixa explícito que é outro acesso.
  Stream<List<ObraModel>> obrasDoCliente(String uid) => _obras
      .where('clientesIds', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => ObraModel.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm)));

  Stream<ObraModel?> obra(String obraId) => _obras.doc(obraId).snapshots().map(
      (d) => d.exists ? ObraModel.fromMap(d.id, d.data()!) : null);

  Future<String> criarObra(ObraModel obra) async {
    final ref = await _obras.add(obra.toMap());
    await _publicarConvite(obra.codigoConvite, ref.id, 'equipe', obra.nome);
    return ref.id;
  }

  /// Publica o código numa coleção à parte, com o mínimo necessário para
  /// alguém entrar na obra: id e nome.
  ///
  /// Existe porque o documento da obra guarda o orçamento. Se a busca por
  /// código fosse feita direto nas obras, todo usuário logado precisaria
  /// conseguir lê-las — e o cliente enxergaria o dinheiro pela porta dos
  /// fundos. Aqui ele só alcança o que o convite carrega.
  Future<void> _publicarConvite(
      String codigo, String obraId, String tipo, String nomeObra) {
    if (codigo.isEmpty) return Future.value();
    return _convites.doc(codigo).set({
      'obraId': obraId,
      'tipo': tipo,
      'nomeObra': nomeObra,
    });
  }

  /// Obra apontada por um código, se o código for do tipo esperado.
  Future<String?> _obraIdDoConvite(String codigo, String tipo) async {
    final limpo = codigo.trim().toUpperCase();
    if (limpo.isEmpty) return null;
    final doc = await _convites.doc(limpo).get();
    final dados = doc.data();
    if (dados == null || dados['tipo'] != tipo) return null;
    return dados['obraId'] as String?;
  }

  /// Republica os convites de uma obra criada antes desta coleção existir.
  /// Idempotente — o dono chama ao abrir a obra e o acesso se conserta.
  Future<void> garantirConvites(ObraModel obra) async {
    await _publicarConvite(obra.codigoConvite, obra.id, 'equipe', obra.nome);
    await _publicarConvite(obra.codigoCliente, obra.id, 'cliente', obra.nome);
  }

  Future<void> atualizarObra(ObraModel obra) =>
      _obras.doc(obra.id).update(obra.toMap());

  Future<void> excluirObra(String obraId) => _obras.doc(obraId).delete();

  /// Gera um código de convite curto e legível (sem 0/O, 1/I).
  static String gerarCodigoConvite() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  /// Mestre entra numa obra usando o código de convite do dono.
  /// Retorna a obra, ou null se o código não existir.
  Future<ObraModel?> entrarNaObraPorCodigo(String codigo, String uid) =>
      _entrarPorConvite(codigo, uid, tipo: 'equipe', campo: 'equipeIds');

  /// Cliente entra na obra com o código que o dono passou para ele.
  /// Retorna a obra, ou null se o código não existir.
  Future<ObraModel?> entrarComoClientePorCodigo(String codigo, String uid) =>
      _entrarPorConvite(codigo, uid, tipo: 'cliente', campo: 'clientesIds');

  Future<ObraModel?> _entrarPorConvite(
    String codigo,
    String uid, {
    required String tipo,
    required String campo,
  }) async {
    final obraId = await _obraIdDoConvite(codigo, tipo);
    if (obraId == null) return null;
    // Entrar primeiro, ler depois: a leitura da obra exige ser membro.
    await _obras.doc(obraId).update({
      campo: FieldValue.arrayUnion([uid]),
    });
    final doc = await _obras.doc(obraId).get();
    return doc.exists ? ObraModel.fromMap(doc.id, doc.data()!) : null;
  }

  /// Código de convite do cliente, criando na hora se a obra ainda não tem
  /// (as obras criadas antes deste recurso não têm).
  Future<String> codigoDoClienteDaObra(ObraModel obra) async {
    if (obra.codigoCliente.isNotEmpty) {
      await _publicarConvite(obra.codigoCliente, obra.id, 'cliente', obra.nome);
      return obra.codigoCliente;
    }
    final codigo = gerarCodigoConvite();
    await _obras.doc(obra.id).update({'codigoCliente': codigo});
    await _publicarConvite(codigo, obra.id, 'cliente', obra.nome);
    return codigo;
  }

  /// Tira o acesso de um cliente à obra.
  Future<void> removerCliente(String obraId, String uid) =>
      _obras.doc(obraId).update({
        'clientesIds': FieldValue.arrayRemove([uid]),
      });

  // ----------------------------------------------------------- Lançamentos

  Stream<List<LancamentoModel>> lancamentos(String obraId) =>
      _sub(obraId, 'lancamentos').snapshots().map((s) => s.docs
          .map((d) => LancamentoModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data)));

  Future<String> criarLancamento(LancamentoModel l) async {
    final ref = await _sub(l.obraId, 'lancamentos').add(l.toMap());
    return ref.id;
  }

  Future<void> atualizarLancamento(LancamentoModel l) =>
      _sub(l.obraId, 'lancamentos').doc(l.id).update(l.toMap());

  Future<void> excluirLancamento(String obraId, String id) =>
      _sub(obraId, 'lancamentos').doc(id).delete();

  Future<void> moderarLancamento({
    required LancamentoModel lancamento,
    required bool aprovar,
    required String donoId,
    String? motivoRejeicao,
  }) =>
      _sub(lancamento.obraId, 'lancamentos').doc(lancamento.id).update({
        'status': aprovar
            ? StatusLancamento.aprovado.name
            : StatusLancamento.rejeitado.name,
        'aprovadoPorId': donoId,
        'motivoRejeicao': motivoRejeicao,
        'moderadoEm': DateTime.now().toIso8601String(),
      });

  /// Interligação financeiro → estoque: dá entrada no estoque de cada
  /// material identificado no lançamento aprovado e registra o movimento
  /// (histórico que alimenta a previsão de término).
  /// Retorna um resumo por item para exibir ao usuário.
  Future<List<String>> aplicarLancamentoNoEstoque(
      LancamentoModel l) async {
    final resumo = <String>[];
    for (final item in l.itens) {
      final col = _sub(l.obraId, 'estoque');
      final existente = await col
          .where('material', isEqualTo: item.material)
          .limit(1)
          .get();
      if (existente.docs.isNotEmpty) {
        final atual = EstoqueItemModel.fromMap(
            existente.docs.first.id, existente.docs.first.data());
        await existente.docs.first.reference.update({
          'quantidade': atual.quantidade + item.quantidade,
          'atualizadoEm': DateTime.now().toIso8601String(),
        });
      } else {
        await col.add(EstoqueItemModel(
          id: '',
          obraId: l.obraId,
          material: item.material,
          quantidade: item.quantidade,
          unidade: item.unidade,
          quantidadeMinima: 0,
          atualizadoEm: DateTime.now(),
        ).toMap());
      }
      await criarMovimento(MovimentoEstoqueModel(
        id: '',
        obraId: l.obraId,
        material: item.material,
        tipo: TipoMovimentoEstoque.entrada,
        quantidade: item.quantidade,
        unidade: item.unidade,
        origem: 'aprovacao',
        lancamentoId: l.id.isEmpty ? null : l.id,
        data: DateTime.now(),
      ));
      resumo.add('+${item.resumo}');
    }
    return resumo;
  }

  // --------------------------------------------- Movimentos de estoque

  Stream<List<MovimentoEstoqueModel>> movimentos(String obraId) =>
      _sub(obraId, 'movimentos').snapshots().map((s) => s.docs
          .map((d) => MovimentoEstoqueModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data)));

  Future<void> criarMovimento(MovimentoEstoqueModel m) =>
      _sub(m.obraId, 'movimentos').add(m.toMap());

  // --------------------------------------------------------------- Estoque

  Stream<List<EstoqueItemModel>> estoque(String obraId) =>
      _sub(obraId, 'estoque').snapshots().map((s) => s.docs
          .map((d) => EstoqueItemModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.material.compareTo(b.material)));

  Future<void> salvarEstoqueItem(EstoqueItemModel item) {
    final col = _sub(item.obraId, 'estoque');
    if (item.id.isEmpty) return col.add(item.toMap());
    return col.doc(item.id).set(item.toMap());
  }

  Future<void> excluirEstoqueItem(String obraId, String id) =>
      _sub(obraId, 'estoque').doc(id).delete();

  // ---------------------------------------------------------------- Diário

  Stream<List<DiarioEntradaModel>> diario(String obraId) =>
      _sub(obraId, 'diario').snapshots().map((s) => s.docs
          .map((d) => DiarioEntradaModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data)));

  Future<void> criarEntradaDiario(DiarioEntradaModel entrada) =>
      _sub(entrada.obraId, 'diario').add(entrada.toMap());

  Future<void> excluirEntradaDiario(String obraId, String id) =>
      _sub(obraId, 'diario').doc(id).delete();

  // ------------------------------------------------------------ Cronograma

  Stream<List<CronogramaFaseModel>> cronograma(String obraId) =>
      _sub(obraId, 'cronograma').snapshots().map((s) => s.docs
          .map((d) => CronogramaFaseModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.ordem.compareTo(b.ordem)));

  Future<void> salvarFase(CronogramaFaseModel fase) {
    final col = _sub(fase.obraId, 'cronograma');
    if (fase.id.isEmpty) return col.add(fase.toMap());
    return col.doc(fase.id).set(fase.toMap());
  }

  Future<void> excluirFase(String obraId, String id) =>
      _sub(obraId, 'cronograma').doc(id).delete();

  // ----------------------------------------------------------------- Fotos

  Stream<List<FotoObraModel>> fotos(String obraId) =>
      _sub(obraId, 'fotos').snapshots().map((s) => s.docs
          .map((d) => FotoObraModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.data.compareTo(a.data)));

  Future<void> criarFoto(FotoObraModel foto) =>
      _sub(foto.obraId, 'fotos').add(foto.toMap());

  Future<void> excluirFoto(String obraId, String id) =>
      _sub(obraId, 'fotos').doc(id).delete();

  // ----------------------------------------------------------- Fornecedores

  Stream<List<FornecedorModel>> fornecedores(String donoId) => _db
      .collection('fornecedores')
      .where('donoId', isEqualTo: donoId)
      .snapshots()
      .map((s) => s.docs
          .map((d) => FornecedorModel.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase())));

  Future<void> salvarFornecedor(FornecedorModel f) {
    final col = _db.collection('fornecedores');
    if (f.id.isEmpty) return col.add(f.toMap());
    return col.doc(f.id).set(f.toMap());
  }

  Future<void> excluirFornecedor(String id) =>
      _db.collection('fornecedores').doc(id).delete();

  /// Cadastro automático: reaproveita o fornecedor pelo nome (ou CNPJ)
  /// se já existir; senão cria um novo. Usado pelo OCR e pela voz.
  Future<FornecedorModel> obterOuCriarFornecedor({
    required String donoId,
    required String nome,
    String? cnpj,
  }) async {
    final col = _db.collection('fornecedores');
    if (cnpj != null && cnpj.isNotEmpty) {
      final porCnpj = await col
          .where('donoId', isEqualTo: donoId)
          .where('cnpj', isEqualTo: cnpj)
          .limit(1)
          .get();
      if (porCnpj.docs.isNotEmpty) {
        final d = porCnpj.docs.first;
        return FornecedorModel.fromMap(d.id, d.data());
      }
    }
    final porNome = await col
        .where('donoId', isEqualTo: donoId)
        .where('nome', isEqualTo: nome.trim())
        .limit(1)
        .get();
    if (porNome.docs.isNotEmpty) {
      final d = porNome.docs.first;
      return FornecedorModel.fromMap(d.id, d.data());
    }
    final novo = FornecedorModel(
      id: '',
      donoId: donoId,
      nome: nome.trim(),
      cnpj: cnpj,
      criadoEm: DateTime.now(),
    );
    final ref = await col.add(novo.toMap());
    return FornecedorModel.fromMap(ref.id, novo.toMap());
  }
}
