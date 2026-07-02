// lib/services/ia_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';

class DadosNotaFiscal {
  final String? fornecedor;
  final String? descricao;
  final double? quantidade;
  final String? unidade;
  final double? valorUnitario;
  final double? valorTotal;
  final String? data;
  final String? categoria;

  DadosNotaFiscal({
    this.fornecedor,
    this.descricao,
    this.quantidade,
    this.unidade,
    this.valorUnitario,
    this.valorTotal,
    this.data,
    this.categoria,
  });
}

class DadosAudio {
  final String transcricao;
  final String? descricao;
  final double? quantidade;
  final String? unidade;
  final double? valorUnitario;
  final double? valorTotal;
  final String? fornecedor;
  final String? categoria;

  DadosAudio({
    required this.transcricao,
    this.descricao,
    this.quantidade,
    this.unidade,
    this.valorUnitario,
    this.valorTotal,
    this.fornecedor,
    this.categoria,
  });
}

class IaService {
  // ==================== NOTA FISCAL ====================

  Future<DadosNotaFiscal> extrairDadosNotaFiscal(File imagem) async {
    try {
      final bytes = await imagem.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = imagem.path.split('.').last.toLowerCase();
      final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final response = await http.post(
        Uri.parse(AppConstants.claudeApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': AppConstants.claudeApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-opus-4-5',
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mediaType,
                    'data': base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text': '''Analise esta nota fiscal ou recibo e extraia os dados.
Retorne APENAS um JSON válido com os campos abaixo (sem texto adicional):
{
  "fornecedor": "nome da loja/empresa",
  "descricao": "descrição do item principal",
  "quantidade": 0.0,
  "unidade": "un/kg/sc/m/m2/m3/L",
  "valorUnitario": 0.0,
  "valorTotal": 0.0,
  "data": "DD/MM/YYYY",
  "categoria": "Materiais ou Mão de Obra ou Transporte ou Serviços Terceirizados ou Outros"
}
Se não encontrar algum campo, deixe como null.''',
                },
              ],
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['content'][0]['text'] as String;
        final jsonText = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final map = jsonDecode(jsonText) as Map<String, dynamic>;

        return DadosNotaFiscal(
          fornecedor: map['fornecedor'],
          descricao: map['descricao'],
          quantidade: (map['quantidade'] as num?)?.toDouble(),
          unidade: map['unidade'],
          valorUnitario: (map['valorUnitario'] as num?)?.toDouble(),
          valorTotal: (map['valorTotal'] as num?)?.toDouble(),
          data: map['data'],
          categoria: map['categoria'],
        );
      }
      throw Exception('Erro ao processar nota fiscal');
    } catch (e) {
      throw Exception('Não foi possível extrair os dados: $e');
    }
  }

  // ==================== ÁUDIO ====================

  Future<DadosAudio> processarAudio(File audio) async {
    // Passo 1: Transcrever com Whisper
    final transcricao = await _transcreverAudio(audio);

    // Passo 2: Interpretar com Claude
    final dados = await _interpretarTranscricao(transcricao);

    return dados;
  }

  Future<String> _transcreverAudio(File audio) async {
    final dio = Dio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audio.path,
        filename: 'audio.m4a',
      ),
      'model': 'whisper-1',
      'language': 'pt',
    });

    final response = await dio.post(
      AppConstants.whisperApiUrl,
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${AppConstants.openAiApiKey}',
        },
      ),
    );

    if (response.statusCode == 200) {
      return response.data['text'] as String;
    }
    throw Exception('Erro ao transcrever áudio');
  }

  Future<DadosAudio> _interpretarTranscricao(String transcricao) async {
    final response = await http.post(
      Uri.parse(AppConstants.claudeApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.claudeApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-opus-4-5',
        'max_tokens': 512,
        'messages': [
          {
            'role': 'user',
            'content': '''Interprete este texto falado de um mestre de obras e extraia informações de compra/gasto.
Texto: "$transcricao"

Retorne APENAS um JSON válido (sem texto adicional):
{
  "descricao": "o que foi comprado/pago",
  "quantidade": 0.0,
  "unidade": "un/kg/sc/m/m2/m3/L",
  "valorUnitario": 0.0,
  "valorTotal": 0.0,
  "fornecedor": "nome da loja/pessoa",
  "categoria": "Materiais ou Mão de Obra ou Transporte ou Serviços Terceirizados ou Outros"
}
Se não encontrar algum campo, deixe como null.''',
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['content'][0]['text'] as String;
      final jsonText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final map = jsonDecode(jsonText) as Map<String, dynamic>;

      return DadosAudio(
        transcricao: transcricao,
        descricao: map['descricao'],
        quantidade: (map['quantidade'] as num?)?.toDouble(),
        unidade: map['unidade'],
        valorUnitario: (map['valorUnitario'] as num?)?.toDouble(),
        valorTotal: (map['valorTotal'] as num?)?.toDouble(),
        fornecedor: map['fornecedor'],
        categoria: map['categoria'],
      );
    }
    throw Exception('Erro ao interpretar áudio');
  }

  // ==================== RELATÓRIO SEMANAL ====================

  Future<String> gerarRelatorioSemanal({
    required String nomeObra,
    required List<Map<String, dynamic>> lancamentos,
    required double totalSemana,
    required String faseAtual,
  }) async {
    final resumo = lancamentos
        .map((l) => '- ${l['descricao']}: R\$ ${l['valorTotal']}')
        .join('\n');

    final response = await http.post(
      Uri.parse(AppConstants.claudeApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.claudeApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': 'claude-opus-4-5',
        'max_tokens': 512,
        'messages': [
          {
            'role': 'user',
            'content': '''Gere um relatório semanal curto e natural para uma obra de construção civil.
Obra: $nomeObra
Fase atual: $faseAtual
Total gasto esta semana: R\$ ${totalSemana.toStringAsFixed(2)}
Lançamentos da semana:
$resumo

Escreva em português de forma simples e direta, como se fosse um resumo para o dono da empresa.
Exemplo de formato: "Esta semana na obra [nome], foram gastos R\$ X, com foco na [fase]. Os principais gastos foram [itens]. [Alguma observação relevante]."
Máximo 4 linhas.''',
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] as String;
    }
    return 'Relatório indisponível no momento.';
  }
}
