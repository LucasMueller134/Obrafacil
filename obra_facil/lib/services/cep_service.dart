import 'dart:convert';
import 'dart:io';

/// Endereço devolvido pela consulta de CEP.
class EnderecoCep {
  final String cep;
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;

  const EnderecoCep({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });

  /// Endereço em uma linha, do jeito que vai para o cadastro da obra.
  String get linha {
    final partes = [
      if (logradouro.isNotEmpty) logradouro,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) '$cidade${uf.isNotEmpty ? ' - $uf' : ''}',
    ];
    return partes.join(', ');
  }

  String get cepFormatado => CepService.formatar(cep);
}

/// Como terminou a consulta de um CEP.
enum SituacaoCep {
  /// CEP existe e o endereço veio junto.
  encontrado,

  /// Formato inválido — nem chegou a consultar.
  formatoInvalido,

  /// Consulta respondeu que este CEP não existe.
  inexistente,

  /// Sem internet ou serviço fora do ar: não dá para afirmar nada.
  semResposta,
}

class ResultadoCep {
  final SituacaoCep situacao;
  final EnderecoCep? endereco;

  const ResultadoCep(this.situacao, {this.endereco});

  bool get valido => situacao == SituacaoCep.encontrado;

  /// Mensagem pronta para a tela.
  String get mensagem => switch (situacao) {
        SituacaoCep.encontrado => 'CEP confirmado: ${endereco!.linha}.',
        SituacaoCep.formatoInvalido => 'CEP precisa ter 8 números.',
        SituacaoCep.inexistente =>
          'Este CEP não existe nos Correios. Confira o número.',
        SituacaoCep.semResposta =>
          'Não consegui conferir o CEP agora (sem internet). Você pode '
              'seguir e digitar o endereço à mão.',
      };
}

/// Verificação de CEP pelos Correios, via ViaCEP.
///
/// Formato o app confere sozinho; existência só o serviço sabe dizer —
/// CEP não tem dígito verificador. Sem internet a consulta falha, e aí o
/// cadastro segue com o endereço digitado à mão: no canteiro é comum não
/// ter sinal, e travar o cadastro por isso seria pior que o dado imperfeito.
abstract class CepService {
  static const String _host = 'viacep.com.br';

  /// Só os dígitos do CEP, ou null se não forem 8.
  static String? normalizar(String cep) {
    final digitos = cep.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 8) return null;
    // 00000000 passa no formato mas não é CEP de lugar nenhum.
    if (RegExp(r'^0{8}$').hasMatch(digitos)) return null;
    return digitos;
  }

  static String formatar(String cep) {
    final digitos = cep.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 8) return cep;
    return '${digitos.substring(0, 5)}-${digitos.substring(5)}';
  }

  static Future<ResultadoCep> consultar(String cep) async {
    final digitos = normalizar(cep);
    if (digitos == null) {
      return const ResultadoCep(SituacaoCep.formatoInvalido);
    }

    final cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final requisicao = await cliente
          .getUrl(Uri.https(_host, '/ws/$digitos/json/'))
          .timeout(const Duration(seconds: 8));
      final resposta = await requisicao.close().timeout(
            const Duration(seconds: 8),
          );
      if (resposta.statusCode != 200) {
        return const ResultadoCep(SituacaoCep.semResposta);
      }
      final corpo = await resposta.transform(utf8.decoder).join();
      return interpretar(corpo, digitos);
    } catch (_) {
      // Sem rede, DNS bloqueado, timeout: não afirmamos que o CEP é falso.
      return const ResultadoCep(SituacaoCep.semResposta);
    } finally {
      cliente.close(force: true);
    }
  }

  /// Parte pura (testável sem rede): lê a resposta do ViaCEP.
  static ResultadoCep interpretar(String corpo, String cepConsultado) {
    try {
      final json = jsonDecode(corpo);
      if (json is! Map<String, dynamic>) {
        return const ResultadoCep(SituacaoCep.semResposta);
      }
      // O ViaCEP responde 200 com {"erro": true} para CEP inexistente.
      final erro = json['erro'];
      if (erro == true || erro == 'true') {
        return const ResultadoCep(SituacaoCep.inexistente);
      }
      final cep = (json['cep'] ?? cepConsultado).toString();
      final localidade = (json['localidade'] ?? '').toString();
      if (localidade.isEmpty) {
        return const ResultadoCep(SituacaoCep.inexistente);
      }
      return ResultadoCep(
        SituacaoCep.encontrado,
        endereco: EnderecoCep(
          cep: cep,
          logradouro: (json['logradouro'] ?? '').toString(),
          bairro: (json['bairro'] ?? '').toString(),
          cidade: localidade,
          uf: (json['uf'] ?? '').toString(),
        ),
      );
    } catch (_) {
      return const ResultadoCep(SituacaoCep.semResposta);
    }
  }
}
