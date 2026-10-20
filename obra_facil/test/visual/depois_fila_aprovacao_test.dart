// Fila de aprovação (/obras/:id/lancamentos) depois do redesenho.
//
//   CAPTURAR=depois flutter test test/visual/depois_fila_aprovacao_test.dart
//
// grava em docs/redesign/depois/ as mesmas cenas do "antes" desta tela
// (04, 05 e 06, celular e _longa), as versões _escuro e uma cena a mais,
// o aviso de desfazer logo depois de tocar em Aprovar (11), com os mesmos
// dados de exemplo. Sem CAPTURAR, os testes são pulados. Ver
// docs/redesign/LEIA-ME-capturas.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/design.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';

const _fila = '/obras/${IdsExemplo.obra}/lancamentos';

void main() {
  setUpAll(() async {
    if (capturando) await prepararCapturas();
  });

  for (final (sufixo, brilho) in [
    ('', Brightness.light),
    ('_escuro', Brightness.dark),
  ]) {
    // 04 do antes era o filtro "Todos". O dono com pendentes agora abre
    // em "Pendentes" (cena 05); aqui ele toca em "Todos".
    capturarCena(Cena(
      '04_lancamentos_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: _fila,
      brilho: brilho,
      acao: (tester) => tester.tap(find.text('Todos')),
    ));

    // Como a central abre a fila: já no filtro "Pendentes".
    capturarCena(Cena(
      '05_lancamentos_pendentes_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_fila?filtro=pendentes',
      brilho: brilho,
    ));

    // Tocar no cartão abre a folha de detalhe.
    capturarCena(Cena(
      '06_lancamento_pendente_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: _fila,
      brilho: brilho,
      acao: (tester) => tester.tap(find.text('Bloco cerâmico 9 furos')),
    ));

    // Tocou em Aprovar no primeiro cartão: o cartão saiu e o aviso
    // "Aprovado" oferece Desfazer (a foto sai antes dos 4 s).
    capturarCena(Cena(
      '11_fila_aprovado_desfazer_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_fila?filtro=pendentes',
      brilho: brilho,
      acao: (tester) =>
          tester.tap(find.widgetWithText(BotaoPrincipal, 'Aprovar').first),
    ));
  }
}
