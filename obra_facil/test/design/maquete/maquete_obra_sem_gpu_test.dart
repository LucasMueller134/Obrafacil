// A MaqueteObra com o carregador de verdade (CenaMaquete.carregar): no
// `flutter test` não há Impeller, então o Flutter GPU lança e a maquete tem
// de cair na imagem de reserva sem erro. Um teste só neste arquivo: o
// flutter_scene guarda futuros da inicialização, e cada testWidgets tem a
// sua própria zona de tempo falso (um futuro de um teste nunca termina no
// seguinte).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/maquete.dart';

void main() {
  testWidgets('sem Impeller: imagem de reserva, motivo e nada lançado',
      (tester) async {
    MaqueteObra.reiniciarParaTeste();
    final diag = ValueNotifier(const DiagnosticoMaquete());
    final caminho = MaqueteObra.caminhoReserva(estado: 3, escuro: false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MaqueteObra(
          progresso: ProgressoMaquete.estado(3),
          diagnostico: diag,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(diag.value.modo, ModoMaquete.imagem);
    expect(diag.value.motivo, MotivoMaquete.semSuporte);
    expect(
      diag.value.detalhe,
      startsWith('Exception: Flutter GPU requires the Impeller rendering '
          'backend'),
    );
    expect(MaqueteObra.diagnosticoGlobal.value.modo, ModoMaquete.imagem);
    expect(find.byKey(MaqueteObra.chaveImagem(caminho)), findsOneWidget);

    // A imagem (webp do asset) decodifica de verdade.
    RawImage raw() => tester.widget<RawImage>(find.descendant(
          of: find.byKey(MaqueteObra.chaveImagem(caminho)),
          matching: find.byType(RawImage),
        ));
    for (var i = 0; i < 100 && raw().image == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(raw().image, isNotNull);
    expect(raw().image!.width / raw().image!.height, closeTo(1.5, 0.01));

    // Uma segunda maquete não tenta o GPU de novo (e não fica carregando).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MaqueteObra(
          key: UniqueKey(),
          progresso: ProgressoMaquete.estado(5),
        ),
      ),
    ));
    await tester.pump();
    expect(MaqueteObra.diagnosticoGlobal.value.modo, ModoMaquete.imagem);
    expect(MaqueteObra.diagnosticoGlobal.value.estadoReserva, 5);

    // Desmonta sem timer pendente nem erro.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
    MaqueteObra.reiniciarParaTeste();
  });
}
