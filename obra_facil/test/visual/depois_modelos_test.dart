// Os modelos prontos: montar a planta pelo modelo (casa e prédio), a
// planta de um sobrado e de um prédio, e a nova obra com o tipo da
// construção. Claro e escuro.
//
//   CAPTURAR=depois flutter test test/visual/depois_modelos_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/models.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';

const _obra = '/obras/${IdsExemplo.obra}';

DadosExemplo Function() _com(PedidoModelo p) =>
    () => DadosExemplo.padrao().comPlantaDe(ModelosPlanta.montar(p));

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await assentar(tester);
}

void main() {
  if (serieDeCaptura == 'antes') {
    test('capturas do antes', () {}, skip: 'os modelos não existiam antes');
    return;
  }
  setUpAll(prepararCapturas);

  for (final (sufixo, brilho) in [
    ('', Brightness.light),
    ('_escuro', Brightness.dark),
  ]) {
    capturarCena(Cena(
      '28_modelo_casa_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      acao: (t) => _tocar(t, find.text('Montar pelo modelo')),
    ));
    capturarCena(Cena(
      '28b_modelo_predio_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      acao: (t) async {
        await _tocar(t, find.text('Montar pelo modelo'));
        await _tocar(t, find.bySemanticsLabel('Prédio'));
      },
    ));
    capturarCena(Cena(
      '29_planta_sobrado_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      dados: _com(const PedidoModelo(
          tipo: TipoModelo.casa, area: 150, quartos: 3, sobrado: true)),
      acao: (t) => _tocar(t, find.bySemanticsLabel('Superior')),
    ));
    capturarCena(Cena(
      '29b_planta_predio_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      dados: _com(const PedidoModelo(
          tipo: TipoModelo.predio,
          area: 60,
          quartos: 2,
          apartamentos: 12,
          andares: 4)),
    ));
    capturarCena(Cena(
      '29c_planta_geminado_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      dados: _com(const PedidoModelo(
          tipo: TipoModelo.geminado, area: 70, quartos: 2, unidades: 3)),
    ));
    capturarCena(Cena(
      '18b_nova_obra_construcao_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '/obras/nova',
      brilho: brilho,
      acao: (t) async {
        await t.scrollUntilVisible(find.bySemanticsLabel('Geminado'), 300,
            scrollable: find.byType(Scrollable).first);
        await _tocar(t, find.bySemanticsLabel('Geminado'));
      },
    ));
  }
}
