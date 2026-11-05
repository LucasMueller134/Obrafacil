import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import '../../models/planta_obra.dart';

/// A leitura da planta pela IA: a planta (ainda não gravada) e o que o dono
/// precisa conferir.
class LeituraPlanta {
  const LeituraPlanta({
    required this.planta,
    this.avisos = const [],
    this.modelo,
    this.custoUsd,
  });

  final PlantaObra planta;
  final List<String> avisos;
  final String? modelo;
  final double? custoUsd;
}

/// A imagem "como vai ficar" gerada (já no Storage, com os dados em
/// `obras/{id}/imagens/{vista}`).
class ImagemGerada {
  const ImagemGerada({
    required this.url,
    required this.vista,
    this.restantes,
    this.custoUsd,
  });

  final String url;
  final String vista;

  /// Quantas vezes ainda dá para gerar esta vista.
  final int? restantes;
  final double? custoUsd;
}

/// Falha da IA, com a mensagem para o dono.
class FalhaIaPlanta implements Exception {
  const FalhaIaPlanta(this.mensagem, {this.naoPublicada = false});

  final String mensagem;

  /// As funções ainda não estão no Firebase (falta o deploy).
  final bool naoPublicada;

  @override
  String toString() => mensagem;
}

/// A IA da planta: ler a planta (Gemini) e gerar as imagens "como vai
/// ficar" (Nano Banana Pro). Roda nas Cloud Functions (pasta functions/
/// do repositório): a chave do Gemini nunca entra no app.
abstract class PlantaIaService {
  Future<LeituraPlanta> lerPlanta({
    required String obraId,
    required Uint8List bytes,
    required String nome,
    String? tipo,
  });

  Future<ImagemGerada> gerarImagem({
    required String obraId,
    required String vista,
    required Uint8List guia,
    Uint8List? referencia,
    String? referenciaTipo,
    String? nomeComodo,
    String? medidas,
    String? piso,
    String? detalhes,
  });
}

class PlantaIaFirebase implements PlantaIaService {
  PlantaIaFirebase([FirebaseFunctions? funcoes])
      : _funcoes = funcoes ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFunctions _funcoes;

  /// Ler a planta pode levar 1 ou 2 minutos (modelo com raciocínio).
  static const Duration _prazo = Duration(minutes: 5);

  @override
  Future<LeituraPlanta> lerPlanta({
    required String obraId,
    required Uint8List bytes,
    required String nome,
    String? tipo,
  }) async {
    final resposta = await _chamar('lerPlanta', {
      'obraId': obraId,
      'arquivo': {'nome': nome, 'tipo': tipo, 'base64': base64Encode(bytes)},
    });
    final planta = PlantaObra.fromMap(
        (resposta['planta'] as Map).cast<String, dynamic>());
    return LeituraPlanta(
      planta: planta,
      avisos: [for (final a in (resposta['avisos'] as List? ?? const [])) '$a'],
      modelo: resposta['modelo'] as String?,
      custoUsd: (resposta['custoUsd'] as num?)?.toDouble(),
    );
  }

  @override
  Future<ImagemGerada> gerarImagem({
    required String obraId,
    required String vista,
    required Uint8List guia,
    Uint8List? referencia,
    String? referenciaTipo,
    String? nomeComodo,
    String? medidas,
    String? piso,
    String? detalhes,
  }) async {
    final resposta = await _chamar('gerarImagem', {
      'obraId': obraId,
      'vista': vista,
      'guia': base64Encode(guia),
      if (referencia != null) 'referencia': base64Encode(referencia),
      if (referenciaTipo != null) 'referenciaTipo': referenciaTipo,
      if (nomeComodo != null) 'nomeComodo': nomeComodo,
      if (medidas != null) 'medidas': medidas,
      if (piso != null) 'piso': piso,
      if (detalhes != null && detalhes.trim().isNotEmpty) 'detalhes': detalhes,
    });
    return ImagemGerada(
      url: resposta['url'] as String,
      vista: resposta['vista'] as String? ?? vista,
      restantes: (resposta['restantes'] as num?)?.toInt(),
      custoUsd: (resposta['custoUsd'] as num?)?.toDouble(),
    );
  }

  Future<Map<String, dynamic>> _chamar(
      String funcao, Map<String, dynamic> dados) async {
    try {
      final r = await _funcoes
          .httpsCallable(funcao,
              options: HttpsCallableOptions(timeout: _prazo))
          .call<Map<Object?, Object?>>(dados);
      return r.data.cast<String, dynamic>();
    } on FirebaseFunctionsException catch (e) {
      throw traduzirFalha(e.code, e.message);
    }
  }

  /// A mensagem do erro da função para o dono.
  static FalhaIaPlanta traduzirFalha(String codigo, String? mensagem) {
    switch (codigo) {
      case 'not-found':
        // A função ainda não existe no projeto (ou a obra sumiu).
        if (mensagem == null ||
            RegExp(r'not[ _]found', caseSensitive: false).hasMatch(mensagem)) {
          return const FalhaIaPlanta(
            'A IA da planta ainda não foi publicada no Firebase. Veja o passo '
            'a passo em docs/ia/gemini-planta.md.',
            naoPublicada: true,
          );
        }
        return FalhaIaPlanta(mensagem);
      case 'unauthenticated':
        return const FalhaIaPlanta('Entre na sua conta de novo.');
      case 'permission-denied':
      case 'resource-exhausted':
      case 'invalid-argument':
        return FalhaIaPlanta(mensagem ?? 'Pedido recusado.');
      case 'deadline-exceeded':
        return const FalhaIaPlanta(
            'A IA demorou demais. Tente de novo, de preferência com o PDF.');
      case 'unavailable':
      case 'internal':
        return FalhaIaPlanta(mensagem ??
            'A IA não respondeu. Confira a internet e tente de novo.');
      default:
        return FalhaIaPlanta(mensagem ?? 'Não deu certo ($codigo).');
    }
  }
}
