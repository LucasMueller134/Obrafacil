// Acompanhamento do cliente (/cliente/:id) depois do redesenho, com a
// planta da obra: hoje, pronta e a ficha de um cômodo.
//
//   CAPTURAR=depois flutter test test/visual/depois_cliente_test.dart
//
// O antes é o 10_cliente_obra de sempre (capturas_test.dart, abfbef5).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';

const _rota = '/cliente/${IdsExemplo.obra}';

DadosExemplo _comPlanta() => DadosExemplo.padrao().comPlanta();

void main() {
  if (serieDeCaptura == 'antes') {
    test('capturas do antes', () {},
        skip: 'o antes desta tela é o 10_cliente_obra (capturas_test.dart)');
    return;
  }
  setUpAll(prepararCapturas);

  for (final (sufixo, brilho) in [
    ('', Brightness.light),
    ('_escuro', Brightness.dark),
  ]) {
    capturarCena(Cena(
      '10_cliente_obra$sufixo',
      usuario: UsuariosExemplo.cliente,
      rota: _rota,
      brilho: brilho,
      dados: _comPlanta,
    ));
    capturarCena(Cena(
      '10b_cliente_obra_pronta$sufixo',
      usuario: UsuariosExemplo.cliente,
      rota: _rota,
      brilho: brilho,
      dados: _comPlanta,
      acao: (tester) => tester.tap(find.bySemanticsLabel('Pronta')),
    ));
    capturarCena(Cena(
      '10c_cliente_comodo$sufixo',
      usuario: UsuariosExemplo.cliente,
      rota: _rota,
      brilho: brilho,
      dados: _comPlanta,
      acao: (tester) async {
        // A lista é preguiçosa: rola até o cômodo existir e aparecer.
        await tester.scrollUntilVisible(find.text('Quarto 2'), 300,
            scrollable: find.byType(Scrollable).first);
        await tester.pump();
        await tester.tap(find.text('Quarto 2'));
      },
    ));
  }
}
