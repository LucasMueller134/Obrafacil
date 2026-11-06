// As telas que faltavam na prancheta: nova obra, cadastro, confirmar o
// e-mail, diário, estoque, galeria, fornecedores, notificações, relatório
// e a lista de obras do cliente. Claro e escuro.
//
//   CAPTURAR=depois flutter test test/visual/depois_restantes_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';

const _obra = '/obras/${IdsExemplo.obra}';

Future<void> _tocar(WidgetTester tester, String texto) async {
  final alvo = find.text(texto).first;
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
}

void main() {
  if (serieDeCaptura == 'antes') {
    test('capturas do antes', () {},
        skip: 'as do antes estão em capturas_test.dart');
    return;
  }
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await prepararCapturas();
  });

  for (final (sufixo, brilho) in [
    ('', Brightness.light),
    ('_escuro', Brightness.dark),
  ]) {
    capturarCena(Cena(
      '18_nova_obra_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '/obras/nova',
      brilho: brilho,
    ));
    capturarCena(Cena(
      '19_cadastro$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '/cadastro',
      brilho: brilho,
      situacao: SituacaoLogin.deslogado,
    ));
    capturarCena(Cena(
      '19b_cadastro_dados$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '/cadastro',
      brilho: brilho,
      situacao: SituacaoLogin.deslogado,
      acao: (t) => _tocar(t, PerfilUsuario.mestre.label),
    ));
    capturarCena(Cena(
      '20_verificar_email_cliente$sufixo',
      usuario: UsuariosExemplo.cliente,
      rota: '/verificar-email',
      brilho: brilho,
      situacao: SituacaoLogin.emailPendente,
    ));
    capturarCena(Cena(
      '21_diario_mestre$sufixo',
      usuario: UsuariosExemplo.mestre,
      rota: '$_obra/diario',
      brilho: brilho,
    ));
    capturarCena(Cena(
      '21b_diario_registro_mestre$sufixo',
      usuario: UsuariosExemplo.mestre,
      rota: '$_obra/diario',
      brilho: brilho,
      acao: (t) => _tocar(t, 'Registrar dia'),
    ));
    capturarCena(Cena(
      '22_estoque_mestre$sufixo',
      usuario: UsuariosExemplo.mestre,
      rota: '$_obra/estoque',
      brilho: brilho,
    ));
    capturarCena(Cena(
      '22b_estoque_material_mestre$sufixo',
      usuario: UsuariosExemplo.mestre,
      rota: '$_obra/estoque',
      brilho: brilho,
      acao: (t) => _tocar(t, 'Adicionar material'),
    ));
    capturarCena(Cena(
      '23_galeria_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/galeria',
      brilho: brilho,
    ));
    capturarCena(Cena(
      '24_fornecedores_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '/fornecedores',
      brilho: brilho,
    ));
    capturarCena(Cena(
      '25_notificacoes_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '/notificacoes',
      brilho: brilho,
    ));
    capturarCena(Cena(
      '26_relatorio_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/relatorio',
      brilho: brilho,
    ));
    capturarCena(Cena(
      '26b_relatorio_perguntar_dono$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/relatorio',
      brilho: brilho,
      // O SeletorGrande escreve com Text.rich: acha pelo rótulo.
      acao: (t) => t.tap(find.bySemanticsLabel('Perguntar')),
    ));
    capturarCena(Cena(
      '27_cliente_obras$sufixo',
      usuario: UsuariosExemplo.cliente,
      rota: '/cliente',
      brilho: brilho,
    ));
  }
}
