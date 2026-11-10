import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:obra_facil/services/ia/assistente_ia_servidor.dart';
import 'package:obra_facil/widgets/chat_obra.dart';

import 'avaliacao/obra_exemplo.dart';

/// IA do servidor de mentira: guarda o que recebeu e devolve uma resposta.
class _IaFalsa extends AssistenteIaServidor {
  final RespostaIa? resposta;
  final perguntas = <String>[];
  final perfis = <String>[];
  final obras = <Map<String, Object?>>[];

  _IaFalsa(this.resposta) : super(url: 'https://ia.teste', token: () async => 'tk');

  @override
  Future<RespostaIa?> perguntar(
      {required String pergunta,
      required String perfil,
      required Map<String, Object?> obra,
      List<Map<String, String>> historico = const []}) async {
    perguntas.add(pergunta);
    perfis.add(perfil);
    obras.add(obra);
    return resposta;
  }
}

Future<void> _perguntar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Widget tela(ChatObra chat) => MaterialApp(home: Scaffold(body: chat));

  testWidgets('o que as regras não entendem vai para a IA do servidor', (tester) async {
    final ia = _IaFalsa(const RespostaIa('A IA respondeu com os dados da obra.'));
    await tester.pumpWidget(tela(ChatObra(dados: obraExemplo(), perfil: 'mestre', ia: ia)));
    await _perguntar(tester, 'qual a cor preferida do encanador zxq?');
    expect(ia.perguntas, ['qual a cor preferida do encanador zxq?']);
    expect(ia.perfis, ['mestre']);
    expect(find.text('A IA respondeu com os dados da obra.'), findsOneWidget);
  });

  testWidgets('o que as regras entendem não gasta a IA', (tester) async {
    final ia = _IaFalsa(const RespostaIa('não devia aparecer'));
    await tester.pumpWidget(tela(ChatObra(dados: obraExemplo(), ia: ia)));
    await _perguntar(tester, 'como está a obra?');
    expect(ia.perguntas, isEmpty);
    expect(find.text('não devia aparecer'), findsNothing);
  });

  testWidgets('IA fora do ar: fica a resposta das regras', (tester) async {
    final ia = _IaFalsa(null);
    await tester.pumpWidget(tela(ChatObra(dados: obraExemplo(), ia: ia)));
    await _perguntar(tester, 'qual a cor preferida do encanador zxq?');
    expect(ia.perguntas, hasLength(1));
    expect(find.textContaining('Perguntando à IA'), findsNothing);
  });

  testWidgets('cliente: o resumo que vai para a IA não tem dinheiro', (tester) async {
    final ia = _IaFalsa(const RespostaIa('ok'));
    await tester.pumpWidget(tela(ChatObra(dados: obraExemplo(cliente: true), modoCliente: true, ia: ia)));
    await _perguntar(tester, 'qual a cor preferida do encanador zxq?');
    expect(ia.perfis, ['cliente']);
    final texto = ia.obras.single.toString();
    expect(texto.contains(r'R$'), isFalse, reason: texto);
  });
}
