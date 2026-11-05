// A planta da obra: a central com a maquete da planta (no teste, a reserva:
// a planta desenhada), a tela da planta, a ficha de um cômodo e a vista
// 360° (no teste, as paredes desdobradas).
//
//   CAPTURAR=depois flutter test test/visual/depois_planta_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';

const _obra = '/obras/${IdsExemplo.obra}';

DadosExemplo _comPlanta() => DadosExemplo.padrao().comPlanta();

void main() {
  if (serieDeCaptura == 'antes') {
    test('capturas do antes', () {}, skip: 'a planta não existia antes');
    return;
  }
  setUpAll(prepararCapturas);

  for (final (sufixo, brilho) in [
    ('', Brightness.light),
    ('_escuro', Brightness.dark),
  ]) {
    capturarCena(Cena(
      '02c_obra_dono_planta$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: _obra,
      brilho: brilho,
      dados: _comPlanta,
    ));
    capturarCena(Cena(
      '14_planta_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      dados: _comPlanta,
    ));
    capturarCena(Cena(
      '14b_planta_comodo_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      dados: _comPlanta,
      acao: (tester) async {
        await tester.ensureVisible(find.text('Quarto 2'));
        await tester.pump();
        await tester.tap(find.text('Quarto 2'));
      },
    ));
    capturarCena(Cena(
      '14c_planta_vazia_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
    ));
    capturarCena(Cena(
      '15_vista360_quarto$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta/quarto-2/360',
      brilho: brilho,
      dados: _comPlanta,
    ));
  }
}
