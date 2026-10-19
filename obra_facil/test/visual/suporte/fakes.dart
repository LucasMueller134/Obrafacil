// Substitutos do Firebase para as capturas de tela: as telas leem os
// dados de exemplo sem rede e sem Firebase.
//
// FirestoreService e AuthService criam FirebaseFirestore.instance /
// FirebaseAuth.instance num campo, então não dá para estender: os falsos
// IMPLEMENTAM a interface. O que as telas leem está implementado com os
// dados de exemplo; as escritas não fazem nada (só ficam registradas em
// [FirestoreFalso.escritas]). Um método novo que ainda não esteja aqui cai
// no noSuchMethod com uma mensagem que diz o que acrescentar.

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:obra_facil/models/models.dart';
import 'package:obra_facil/services/auth_service.dart';
import 'package:obra_facil/services/firestore_service.dart';

import 'dados_exemplo.dart';

/// Stream que se comporta como um `snapshots()` do Firestore: entrega o
/// valor atual a cada novo ouvinte e nunca fecha (ConnectionState.active).
///
/// A mesma instância é devolvida para a mesma consulta: as telas chamam
/// `db.obra(id)` dentro do build e, com uma Stream nova a cada build, o
/// StreamBuilder reassinaria e voltaria a "carregando".
class _Consulta<T> {
  final T valor;
  late final Stream<T> stream = Stream<T>.multi((c) => c.add(valor));

  _Consulta(this.valor);
}

class FirestoreFalso implements FirestoreService {
  final DadosExemplo dados;

  /// Escritas que alguma tela tentou fazer (para depuração do harness).
  final List<String> escritas = [];

  final Map<String, Object> _consultas = {};

  FirestoreFalso(this.dados);

  /// Mesma Stream para a mesma consulta.
  Stream<T> _mesma<T>(String chave, T Function() calcular) =>
      (_consultas.putIfAbsent(chave, () => _Consulta<T>(calcular()))
              as _Consulta<T>)
          .stream;

  List<T> _de<T>(Map<String, List<T>> mapa, String obraId) =>
      List<T>.of(mapa[obraId] ?? const []);

  Future<void> _escrita(String o) async => escritas.add(o);

  // ---------------------------------------------------------------- Obras

  @override
  Stream<List<ObraModel>> obrasDoUsuario(String uid) =>
      _mesma('obrasDoUsuario/$uid', () {
        return dados.obras
            .where((o) => o.donoId == uid || o.equipeIds.contains(uid))
            .toList()
          ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
      });

  @override
  Stream<List<ObraModel>> obrasDoCliente(String uid) =>
      _mesma('obrasDoCliente/$uid', () {
        return dados.obras.where((o) => o.clientesIds.contains(uid)).toList()
          ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
      });

  @override
  Stream<ObraModel?> obra(String obraId) => _mesma<ObraModel?>('obra/$obraId',
      () => dados.obras.where((o) => o.id == obraId).firstOrNull);

  @override
  Future<String> criarObra(ObraModel obra) async {
    await _escrita('criarObra ${obra.nome}');
    return 'nova-obra';
  }

  @override
  Future<void> garantirConvites(ObraModel obra) =>
      _escrita('garantirConvites ${obra.id}');

  @override
  Future<void> atualizarObra(ObraModel obra) =>
      _escrita('atualizarObra ${obra.id}');

  @override
  Future<void> excluirObra(String obraId) => _escrita('excluirObra $obraId');

  @override
  Future<ObraModel?> entrarNaObraPorCodigo(String codigo, String uid) async =>
      dados.obras.where((o) => o.codigoConvite == codigo).firstOrNull;

  @override
  Future<ObraModel?> entrarComoClientePorCodigo(
          String codigo, String uid) async =>
      dados.obras.where((o) => o.codigoCliente == codigo).firstOrNull;

  @override
  Future<String> codigoDoClienteDaObra(ObraModel obra) async =>
      obra.codigoCliente.isEmpty ? 'CL0000' : obra.codigoCliente;

  @override
  Future<void> removerCliente(String obraId, String uid) =>
      _escrita('removerCliente $obraId $uid');

  // ----------------------------------------------------------- Lançamentos

  @override
  Stream<List<LancamentoModel>> lancamentos(String obraId) =>
      _mesma('lancamentos/$obraId', () {
        return _de(dados.lancamentos, obraId)
          ..sort((a, b) => b.data.compareTo(a.data));
      });

  @override
  Future<String> criarLancamento(LancamentoModel l) async {
    await _escrita('criarLancamento ${l.descricao}');
    return 'novo-lancamento';
  }

  @override
  Future<void> atualizarLancamento(LancamentoModel l) =>
      _escrita('atualizarLancamento ${l.id}');

  @override
  Future<void> excluirLancamento(String obraId, String id) =>
      _escrita('excluirLancamento $id');

  @override
  Future<void> moderarLancamento({
    required LancamentoModel lancamento,
    required bool aprovar,
    required String donoId,
    String? motivoRejeicao,
  }) =>
      _escrita('moderarLancamento ${lancamento.id} $aprovar');

  @override
  Future<List<String>> aplicarLancamentoNoEstoque(LancamentoModel l) async {
    await _escrita('aplicarLancamentoNoEstoque ${l.id}');
    return [for (final i in l.itens) '+${i.resumo}'];
  }

  // --------------------------------------------------------------- Estoque

  @override
  Stream<List<MovimentoEstoqueModel>> movimentos(String obraId) =>
      _mesma('movimentos/$obraId', () {
        return _de(dados.movimentos, obraId)
          ..sort((a, b) => b.data.compareTo(a.data));
      });

  @override
  Future<void> criarMovimento(MovimentoEstoqueModel m) =>
      _escrita('criarMovimento ${m.material}');

  @override
  Stream<List<EstoqueItemModel>> estoque(String obraId) =>
      _mesma('estoque/$obraId', () {
        return _de(dados.estoque, obraId)
          ..sort((a, b) => a.material.compareTo(b.material));
      });

  @override
  Future<void> salvarEstoqueItem(EstoqueItemModel item) =>
      _escrita('salvarEstoqueItem ${item.material}');

  @override
  Future<void> excluirEstoqueItem(String obraId, String id) =>
      _escrita('excluirEstoqueItem $id');

  // ---------------------------------------------------------------- Diário

  @override
  Stream<List<DiarioEntradaModel>> diario(String obraId) =>
      _mesma('diario/$obraId', () {
        return _de(dados.diario, obraId)
          ..sort((a, b) => b.data.compareTo(a.data));
      });

  @override
  Future<void> criarEntradaDiario(DiarioEntradaModel entrada) =>
      _escrita('criarEntradaDiario');

  @override
  Future<void> excluirEntradaDiario(String obraId, String id) =>
      _escrita('excluirEntradaDiario $id');

  // ------------------------------------------------------------ Cronograma

  @override
  Stream<List<CronogramaFaseModel>> cronograma(String obraId) =>
      _mesma('cronograma/$obraId', () {
        return _de(dados.cronograma, obraId)
          ..sort((a, b) => a.ordem.compareTo(b.ordem));
      });

  @override
  Future<void> salvarFase(CronogramaFaseModel fase) =>
      _escrita('salvarFase ${fase.nome}');

  @override
  Future<void> excluirFase(String obraId, String id) =>
      _escrita('excluirFase $id');

  // ----------------------------------------------------------------- Fotos

  @override
  Stream<List<FotoObraModel>> fotos(String obraId) =>
      _mesma('fotos/$obraId', () {
        return _de(dados.fotos, obraId)
          ..sort((a, b) => b.data.compareTo(a.data));
      });

  @override
  Future<void> criarFoto(FotoObraModel foto) => _escrita('criarFoto');

  @override
  Future<void> excluirFoto(String obraId, String id) =>
      _escrita('excluirFoto $id');

  // ---------------------------------------------------------- Fornecedores

  @override
  Stream<List<FornecedorModel>> fornecedores(String donoId) =>
      _mesma('fornecedores/$donoId', () {
        return dados.fornecedores.where((f) => f.donoId == donoId).toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));
      });

  @override
  Future<void> salvarFornecedor(FornecedorModel f) =>
      _escrita('salvarFornecedor ${f.nome}');

  @override
  Future<void> excluirFornecedor(String id) =>
      _escrita('excluirFornecedor $id');

  @override
  Future<FornecedorModel> obterOuCriarFornecedor({
    required String donoId,
    required String nome,
    String? cnpj,
  }) async =>
      dados.fornecedores.where((f) => f.nome == nome.trim()).firstOrNull ??
      FornecedorModel(
        id: 'f-novo',
        donoId: donoId,
        nome: nome.trim(),
        cnpj: cnpj,
        criadoEm: DateTime(2026, 10, 15),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'FirestoreFalso (test/visual/suporte/fakes.dart) não implementa '
      '${invocation.memberName}. Acrescente esse método ao falso para a '
      'tela poder ser capturada.');
}

/// Usuário do Firebase Auth falso: só o que o AuthProvider lê.
class UsuarioFirebaseFalso implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final bool emailVerified;

  UsuarioFirebaseFalso(this.uid, {this.email, this.emailVerified = true});

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'UsuarioFirebaseFalso não implementa ${invocation.memberName}.');
}

/// AuthService falso: alimenta um AuthProvider DE VERDADE com o perfil
/// escolhido, sem Firebase.
class AuthServiceFalso implements AuthService {
  final UsuarioModel usuario;
  final bool emailConfirmado;
  late final UsuarioFirebaseFalso _user = UsuarioFirebaseFalso(
    usuario.id,
    email: usuario.email,
    emailVerified: emailConfirmado,
  );

  AuthServiceFalso(this.usuario, {this.emailConfirmado = true});

  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(_user);

  @override
  User? get usuarioFirebase => _user;

  @override
  Future<UsuarioModel?> carregarPerfil(String uid) async =>
      UsuariosExemplo.todos.where((u) => u.id == uid).firstOrNull;

  @override
  bool get emailVerificado => emailConfirmado;

  @override
  String? get emailAtual => usuario.email;

  @override
  Future<void> reenviarVerificacao() async {}

  @override
  Future<bool> recarregarVerificacao() async => emailConfirmado;

  @override
  Future<UsuarioModel?> entrar({
    required String email,
    required String senha,
  }) async =>
      usuario;

  @override
  Future<UsuarioModel> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required PerfilUsuario perfil,
  }) async =>
      usuario;

  @override
  Future<void> sair() async {}

  @override
  Future<void> recuperarSenha(String email) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'AuthServiceFalso não implementa ${invocation.memberName}.');
}
