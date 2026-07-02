// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/obra_model.dart';
import '../models/lancamento_model.dart';
import '../models/models.dart';
import '../constants/app_constants.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== OBRAS ====================

  Future<ObraModel> criarObra(ObraModel obra) async {
    await _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obra.id)
        .set(obra.toMap());
    return obra;
  }

  Future<void> atualizarObra(ObraModel obra) async {
    await _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obra.id)
        .update(obra.toMap());
  }

  Future<void> deletarObra(String obraId) async {
    await _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obraId)
        .delete();
  }

  Stream<List<ObraModel>> streamObras(String donoId) {
    return _firestore
        .collection(AppConstants.obrasCollection)
        .where('donoId', isEqualTo: donoId)
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ObraModel.fromMap(d.data())).toList());
  }

  Stream<List<ObraModel>> streamObrasMestre(String mestreId) {
    return _firestore
        .collection(AppConstants.obrasCollection)
        .where('mestreId', isEqualTo: mestreId)
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ObraModel.fromMap(d.data())).toList());
  }

  // ==================== LANÇAMENTOS ====================

  Future<void> criarLancamento(LancamentoModel lancamento) async {
    final batch = _firestore.batch();

    final lancRef = _firestore
        .collection(AppConstants.obrasCollection)
        .doc(lancamento.obraId)
        .collection(AppConstants.lancamentosCollection)
        .doc(lancamento.id);

    batch.set(lancRef, lancamento.toMap());

    // Atualiza custo da obra
    final obraRef = _firestore
        .collection(AppConstants.obrasCollection)
        .doc(lancamento.obraId);
    batch.update(obraRef, {
      'custoAtual': FieldValue.increment(lancamento.valorTotal),
      'atualizadoEm': DateTime.now().toIso8601String(),
    });

    await batch.commit();
  }

  Stream<List<LancamentoModel>> streamLancamentos(String obraId) {
    return _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obraId)
        .collection(AppConstants.lancamentosCollection)
        .orderBy('data', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => LancamentoModel.fromMap(d.data())).toList());
  }

  Future<List<LancamentoModel>> getLancamentosSemana(String obraId) async {
    final inicioSemana = DateTime.now().subtract(const Duration(days: 7));
    final snap = await _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obraId)
        .collection(AppConstants.lancamentosCollection)
        .where('data', isGreaterThan: inicioSemana.toIso8601String())
        .get();
    return snap.docs.map((d) => LancamentoModel.fromMap(d.data())).toList();
  }

  // ==================== FORNECEDORES ====================

  Future<FornecedorModel> criarFornecedor(FornecedorModel fornecedor) async {
    await _firestore
        .collection(AppConstants.fornecedoresCollection)
        .doc(fornecedor.id)
        .set(fornecedor.toMap());
    return fornecedor;
  }

  Stream<List<FornecedorModel>> streamFornecedores(String donoId) {
    return _firestore
        .collection(AppConstants.fornecedoresCollection)
        .where('donoId', isEqualTo: donoId)
        .orderBy('nome')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FornecedorModel.fromMap(d.data())).toList());
  }

  // ==================== ESTOQUE ====================

  Future<void> atualizarEstoque(EstoqueModel estoque) async {
    await _firestore
        .collection(AppConstants.obrasCollection)
        .doc(estoque.obraId)
        .collection(AppConstants.estoqueCollection)
        .doc(estoque.id)
        .set(estoque.toMap());
  }

  Stream<List<EstoqueModel>> streamEstoque(String obraId) {
    return _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obraId)
        .collection(AppConstants.estoqueCollection)
        .orderBy('material')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => EstoqueModel.fromMap(d.data())).toList());
  }

  // ==================== DIÁRIO ====================

  Future<void> criarDiario(DiarioModel diario) async {
    await _firestore
        .collection(AppConstants.obrasCollection)
        .doc(diario.obraId)
        .collection(AppConstants.diarioCollection)
        .doc(diario.id)
        .set(diario.toMap());
  }

  Stream<List<DiarioModel>> streamDiario(String obraId) {
    return _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obraId)
        .collection(AppConstants.diarioCollection)
        .orderBy('data', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => DiarioModel.fromMap(d.data())).toList());
  }

  // ==================== CRONOGRAMA ====================

  Future<void> salvarCronograma(CronogramaModel cronograma) async {
    await _firestore
        .collection(AppConstants.obrasCollection)
        .doc(cronograma.obraId)
        .collection(AppConstants.cronogramaCollection)
        .doc(cronograma.id)
        .set(cronograma.toMap());
  }

  Stream<List<CronogramaModel>> streamCronograma(String obraId) {
    return _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obraId)
        .collection(AppConstants.cronogramaCollection)
        .orderBy('dataInicio')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CronogramaModel.fromMap(d.data())).toList());
  }

  // ==================== GALERIA ====================

  Future<String> uploadFoto(File foto, String obraId, String nome) async {
    final ref = _storage.ref().child('obras/$obraId/fotos/$nome');
    await ref.putFile(foto);
    return await ref.getDownloadURL();
  }

  Future<String> uploadNotaFiscal(File nota, String obraId, String nome) async {
    final ref = _storage.ref().child('obras/$obraId/notas/$nome');
    await ref.putFile(nota);
    return await ref.getDownloadURL();
  }

  Future<void> salvarFotoGaleria(GaleriaModel galeria) async {
    await _firestore
        .collection(AppConstants.obrasCollection)
        .doc(galeria.obraId)
        .collection(AppConstants.galeriaCollection)
        .doc(galeria.id)
        .set(galeria.toMap());
  }

  Stream<List<GaleriaModel>> streamGaleria(String obraId) {
    return _firestore
        .collection(AppConstants.obrasCollection)
        .doc(obraId)
        .collection(AppConstants.galeriaCollection)
        .orderBy('data', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GaleriaModel.fromMap(d.data())).toList());
  }
}
