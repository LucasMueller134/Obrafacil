// A maquete gerada pela planta (lib/design/maquete/gerador/).
//
// Com GLB_SAIDA=<arquivo>, o teste da casa de exemplo grava o glb gerado
// (para conferir no validador e no Blender, ver ferramentas/planta_exemplo).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/gerador/gerador_maquete.dart';
import 'package:obra_facil/design/maquete/gerador/glb.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';
import 'package:obra_facil/models/planta_obra.dart';

PlantaObra _casaExemplo() => PlantaObra.fromMap(
    jsonDecode(File('assets/plantas/casa_7x20.json').readAsStringSync())
        as Map<String, dynamic>);

Map<String, dynamic> _jsonDoGlb(Uint8List glb) {
  final d = ByteData.sublistView(glb);
  expect(d.getUint32(0, Endian.little), 0x46546C67, reason: 'assinatura glTF');
  expect(d.getUint32(8, Endian.little), glb.length, reason: 'tamanho total');
  final tamanho = d.getUint32(12, Endian.little);
  return jsonDecode(utf8.decode(glb.sublist(20, 20 + tamanho)))
      as Map<String, dynamic>;
}

void main() {
  group('Planta da casa de exemplo', () {
    test('lê o JSON sem problemas e com as medidas do desenho', () {
      final p = _casaExemplo();
      expect(p.problemas(), isEmpty);
      expect(p.largura, 7);
      expect(p.profundidade, 20);
      expect(p.paredes, hasLength(18));
      expect(p.comodos, hasLength(15));
      final quarto2 = p.comodos.firstWhere((c) => c.id == 'quarto-2');
      // "3,23 × 4,10" na planta.
      expect(quarto2.principal.largura, closeTo(3.23, 0.001));
      expect(quarto2.principal.profundidade, closeTo(4.10, 0.001));
      expect(p.comodoEm(2.0, 9.0)?.nome, 'Quarto 2');
      expect(p.comodoEm(5.5, 13.0)?.nome, 'Sala');
    });

    test('ida e volta pelo mapa do Firestore não perde nada', () {
      final p = _casaExemplo();
      final volta = PlantaObra.fromMap(
          jsonDecode(jsonEncode(p.toMap())) as Map<String, dynamic>);
      expect(jsonEncode(volta.toMap()), jsonEncode(p.toMap()));
    });
  });

  group('Maquete gerada', () {
    late MaqueteGerada maquete;
    setUpAll(() => maquete = GeradorMaquete.gerar(_casaExemplo()));

    test('tem todos os nós que o PlanoMaquete mexe', () {
      for (final nome in PlanoMaquete.todosOsNos) {
        expect(maquete.modelo.raiz.procurar(nome), isNotNull, reason: nome);
      }
      expect(maquete.modelo.raiz.procurar('base'), isNotNull);
      expect(maquete.modelo.raiz.procurar('cotas'), isNotNull);
    });

    test('cada fase que a casa tem ganhou peças', () {
      for (final nome in [
        'fundacao_radier', 'estrutura_pilares', 'estrutura_vigas',
        'estrutura_laje', 'alvenaria_fiada_00', 'alvenaria_fiada_11',
        'alvenaria_fiada_12', 'cobertura_telhas', 'eletrica_poste',
        'hidraulica_caixa_dagua', 'reboco_paredes', 'revestimentos_calcada',
        'pintura_paredes', 'acabamento_esquadrias', 'acabamento_porta',
        'acabamento_arvores',
      ]) {
        expect(maquete.modelo.raiz.procurar(nome)!.malha.vazia, isFalse,
            reason: nome);
      }
    });

    test('cabe no aparelho intermediário (como a maquete-padrão)', () {
      // A maquete-padrão tem uns 44 mil triângulos.
      expect(maquete.modelo.triangulos, lessThan(120000));
      expect(maquete.modelo.triangulos, greaterThan(5000));
    });

    test('o glb é válido e tem os nós e materiais', () {
      final glb = escreverGlb(maquete.modelo);
      final json = _jsonDoGlb(glb);
      final nomes = {for (final n in json['nodes'] as List) (n as Map)['name']};
      expect(nomes, containsAll(PlanoMaquete.todosOsNos));
      final materiais = {
        for (final m in json['materials'] as List) (m as Map)['name'],
      };
      expect(materiais, containsAll(['fantasma', 'bloco_ceramico', 'base']));
      final saida = Platform.environment['GLB_SAIDA'];
      if (saida != null) File(saida).writeAsBytesSync(glb);
    });

    test('a laje cobre os cômodos cobertos e não os de fora', () {
      final laje = maquete.modelo.raiz.procurar('estrutura_laje')!;
      final (mn, mx) = laje.malha.lotes['concreto']!.limites();
      // A laje vai do fundo (despensa, y 0) até a garagem (y 20).
      expect(mx.$3 - mn.$3, greaterThan(19));
    });
  });

  test('planta com problema não gera maquete', () {
    const p = PlantaObra(largura: 7, profundidade: 20, paredes: [], comodos: []);
    expect(() => GeradorMaquete.gerar(p), throwsArgumentError);
  });
}
