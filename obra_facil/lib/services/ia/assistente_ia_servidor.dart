import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

/// Resposta da IA do servidor do assistente.
class RespostaIa {
  final String texto;
  final String? respostaId;

  const RespostaIa(this.texto, {this.respostaId});
}

/// Fala com a IA própria do assistente (modelo aberto no servidor do dono do
/// projeto), para as perguntas que o assistente de regras não entende.
///
/// O endereço vem do build: `--dart-define=IA_URL=https://...`. Sem ele, fica
/// desligado e o app segue só com as regras, offline. A identidade é o token
/// do login do Firebase, conferido no servidor. Qualquer falha (sem internet,
/// servidor fora do ar, demora) devolve null e o chat segue com as regras.
class AssistenteIaServidor {
  static const urlDoBuild = String.fromEnvironment('IA_URL');

  final String url;
  final Future<String?> Function() _token;
  final HttpClient Function() _cliente;
  final Duration tempoMaximo;

  AssistenteIaServidor({
    String? url,
    Future<String?> Function()? token,
    HttpClient Function()? cliente,
    this.tempoMaximo = const Duration(seconds: 120),
  })  : url = (url ?? urlDoBuild).replaceAll(RegExp(r'/+$'), ''),
        _token = token ?? _tokenDoFirebase,
        _cliente = cliente ?? HttpClient.new;

  bool get ligado => url.startsWith('https://') || url.startsWith('http://');

  static Future<String?> _tokenDoFirebase() async {
    try {
      return await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  /// [perfil]: `dono`, `mestre` ou `cliente`. [obra]: o resumo de
  /// [resumoObraParaIa]. [historico]: as últimas falas, no formato
  /// `{"role": "user"|"assistant", "content": "..."}`.
  Future<RespostaIa?> perguntar({
    required String pergunta,
    required String perfil,
    required Map<String, Object?> obra,
    List<Map<String, String>> historico = const [],
  }) async {
    if (!ligado) return null;
    final http = _cliente()..connectionTimeout = const Duration(seconds: 15);
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return null;
      final req = await http.postUrl(Uri.parse('$url/api/obra/pergunta'));
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.add(utf8.encode(jsonEncode({
        'pergunta': pergunta,
        'perfil': perfil,
        'obra': obra,
        'historico': historico.length > 6 ? historico.sublist(historico.length - 6) : historico,
      })));
      final resp = await req.close().timeout(tempoMaximo);
      final corpo = await resp.transform(utf8.decoder).join().timeout(tempoMaximo);
      if (resp.statusCode != 200) return null;
      final d = jsonDecode(corpo);
      if (d is! Map || d['texto'] is! String || (d['texto'] as String).trim().isEmpty) return null;
      return RespostaIa((d['texto'] as String).trim(), respostaId: d['resposta_id'] as String?);
    } catch (_) {
      return null;
    } finally {
      http.close(force: true);
    }
  }
}
