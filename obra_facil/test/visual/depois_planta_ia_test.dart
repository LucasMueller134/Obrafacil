// A IA da planta: lendo a planta, a leitura que falhou (função não
// publicada), a revisão e a geração da fachada. A IA é falsa: nada sai para
// a rede. No teste não há Flutter GPU, então o 3D aparece como a planta
// desenhada (a reserva).
//
//   CAPTURAR=depois flutter test test/visual/depois_planta_ia_test.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/design.dart';
import 'package:obra_facil/design/maquete/maquete.dart';
import 'package:obra_facil/screens/planta/como_vai_ficar.dart';
import 'package:obra_facil/screens/planta/enviar_planta.dart';
import 'package:obra_facil/services/ia/planta_ia_service.dart';

import 'suporte/captura.dart';
import 'suporte/dados_exemplo.dart';
import 'suporte/fakes.dart';

const _obra = '/obras/${IdsExemplo.obra}';

/// A leitura que nunca termina: a tela fica em "Lendo a planta".
class _IaLendo implements PlantaIaService {
  @override
  Future<LeituraPlanta> lerPlanta({
    required String obraId,
    required Uint8List bytes,
    required String nome,
    String? tipo,
  }) =>
      Completer<LeituraPlanta>().future;

  @override
  Future<ImagemGerada> gerarImagem({
    required String obraId,
    required String vista,
    required Uint8List guia,
    Uint8List? referencia,
    String? referenciaTipo,
    String? nomeComodo,
    String? medidas,
    String? piso,
    String? detalhes,
  }) =>
      Completer<ImagemGerada>().future;
}

/// Abre [tela] por cima da tela da planta, como o app faz.
Future<void> Function(WidgetTester) _abrir(Widget Function() tela) =>
    (tester) async {
      final contexto = tester.element(find.byType(Scaffold).first);
      unawaited(Navigator.of(contexto).push(MaterialPageRoute<void>(
        builder: (_) => TemaPrancheta(child: tela()),
      )));
    };

final _arquivo = ArquivoPlanta(Uint8List(0), 'planta-casa-7x20.pdf');

void main() {
  if (serieDeCaptura == 'antes') {
    test('capturas do antes', () {}, skip: 'a IA da planta não existia antes');
    return;
  }
  setUpAll(prepararCapturas);

  for (final (sufixo, brilho) in [
    ('', Brightness.light),
    ('_escuro', Brightness.dark),
  ]) {
    capturarCena(Cena(
      '16_planta_lendo$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      ia: _IaLendo.new,
      acao: _abrir(() =>
          LeituraPlantaScreen(obraId: IdsExemplo.obra, arquivo: _arquivo)),
    ));
    capturarCena(Cena(
      '16b_planta_nao_publicada$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      ia: () => PlantaIaFalsa(
          falha: PlantaIaFirebase.traduzirFalha('not-found', null)),
      acao: _abrir(() =>
          LeituraPlantaScreen(obraId: IdsExemplo.obra, arquivo: _arquivo)),
    ));
    capturarCena(Cena(
      '16c_planta_revisao$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      acao: _abrir(() => RevisaoPlantaScreen(
            obraId: IdsExemplo.obra,
            leitura: LeituraPlanta(
              planta: DadosExemplo.plantaExemplo(),
              avisos: const [
                'A cota da largura da garagem estava apagada; usei a escala.',
                'O pé-direito não aparece na planta; usei 2,50 m do corte.',
              ],
            ),
            arquivo: _arquivo,
          )),
    ));
    capturarCena(Cena(
      '17_gerar_fachada$sufixo',
      usuario: UsuariosExemplo.dono,
      rota: '$_obra/planta',
      brilho: brilho,
      dados: () => DadosExemplo.padrao().comPlanta(),
      acao: _abrir(() => GerarImagemScreen(
            obraId: IdsExemplo.obra,
            pedido: const PedidoImagem.fachada(),
            maquete: LayoutBuilder(
              builder: (context, caixa) => MaqueteObra(
                progresso: ProgressoMaquete.fases(
                    List<double>.filled(ProgressoMaquete.totalFases, 1)),
                fonte: FontePlanta(DadosExemplo.plantaExemplo()),
                altura: caixa.maxHeight,
                legenda: false,
              ),
            ),
          )),
    ));
  }
}
