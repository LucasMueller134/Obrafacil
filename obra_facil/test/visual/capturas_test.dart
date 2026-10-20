// Capturas das telas do redesenho, com os dados de exemplo.
//
//   CAPTURAR=antes flutter test test/visual/capturas_test.dart
//
// grava os PNG em docs/redesign/antes/. Sem CAPTURAR, os testes são
// pulados (o `flutter test` de sempre não escreve nada). Ver
// docs/redesign/LEIA-ME-capturas.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/models.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';
import 'suporte/plataforma.dart';

const _obra = '/obras/${IdsExemplo.obra}';

/// O que o mestre fala no painel de voz: primeiro o começo da frase (a
/// interpretação ao vivo), depois a frase inteira.
const _falaParcial = 'comprei seis metros de areia média por mil duzentos '
    'e noventa reais';
const _falaCompleta = '$_falaParcial no areial são jorge';

/// O painel de voz de hoje não cabe em 390 pontos: Cancelar + Regravar +
/// Concluir medem 350,4 e sobram 342 (a folha tem 24 de margem). Em
/// telas a partir de ~399 pontos cabe; no modo release não há faixa, o
/// Concluir sai cortado na borda direita (o scroll do painel recorta).
const _botoesDaVozNaoCabem =
    'A RenderFlex overflowed by 8.4 pixels on the right.';

Future<void> _abrirVoz(WidgetTester tester) async {
  await tester.tap(find.text('Por voz'));
  await assentar(tester, total: const Duration(milliseconds: 600));
  await microfoneAberto(tester);
}

void main() {
  // Estas cenas descrevem o visual antigo (o "antes" do redesenho). Com
  // outra série (ex.: CAPTURAR=depois) elas gravariam por cima das telas
  // novas; para refazer o antes, rode no commit abfbef5.
  if (serieDeCaptura != null && serieDeCaptura != 'antes') {
    test('capturas do antes', () {},
        skip: 'só rodam com CAPTURAR=antes, no visual antigo');
    return;
  }
  setUpAll(() async {
    if (capturando) await prepararCapturas();
  });

  capturarCena(Cena(
    '01_obras_dono',
    usuario: UsuariosExemplo.dono,
    rota: '/obras',
  ));

  capturarCena(Cena(
    '02_obra_dono',
    usuario: UsuariosExemplo.dono,
    rota: _obra,
  ));

  capturarCena(Cena(
    '03_obra_mestre',
    usuario: UsuariosExemplo.mestre,
    rota: _obra,
  ));

  // A fila de aprovação de hoje é a lista de lançamentos (o "Revisar 3
  // lançamentos pendentes" da central abre esta tela).
  capturarCena(Cena(
    '04_lancamentos_dono',
    usuario: UsuariosExemplo.dono,
    rota: '$_obra/lancamentos',
  ));

  capturarCena(Cena(
    '05_lancamentos_pendentes_dono',
    usuario: UsuariosExemplo.dono,
    rota: '$_obra/lancamentos',
    acao: (tester) => tester
        .tap(find.widgetWithText(ChoiceChip, StatusLancamento.pendente.label)),
  ));

  // Aprovar hoje: tocar no lançamento abre a folha com Aprovar/Rejeitar.
  capturarCena(Cena(
    '06_lancamento_pendente_dono',
    usuario: UsuariosExemplo.dono,
    rota: '$_obra/lancamentos',
    acao: (tester) => tester.tap(find.text('Bloco cerâmico 9 furos')),
  ));

  capturarCena(Cena(
    '07_novo_lancamento_mestre',
    usuario: UsuariosExemplo.mestre,
    rota: '$_obra/lancamentos/novo',
  ));

  // Painel de voz aberto, ouvindo, com a interpretação ao vivo.
  capturarCena(Cena(
    '08_novo_lancamento_voz_mestre',
    usuario: UsuariosExemplo.mestre,
    rota: '$_obra/lancamentos/novo',
    defeitoConhecido: _botoesDaVozNaoCabem,
    acao: (tester) async {
      await _abrirVoz(tester);
      await falaDoAparelho(tester, _falaParcial);
    },
  ));

  // Depois do "Concluir": o formulário preenchido pela fala.
  capturarCena(Cena(
    '09_novo_lancamento_voz_preenchido_mestre',
    usuario: UsuariosExemplo.mestre,
    rota: '$_obra/lancamentos/novo',
    defeitoConhecido: _botoesDaVozNaoCabem,
    acao: (tester) async {
      await _abrirVoz(tester);
      await falaDoAparelho(tester, _falaParcial);
      await falaDoAparelho(tester, _falaCompleta, finalizou: true);
      await assentar(tester, total: const Duration(milliseconds: 600));
      await tester.tap(find.text('Concluir'));
    },
  ));

  capturarCena(Cena(
    '10_cliente_obra',
    usuario: UsuariosExemplo.cliente,
    rota: '/cliente/${IdsExemplo.obra}',
  ));
}
