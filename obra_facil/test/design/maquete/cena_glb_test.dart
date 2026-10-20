// Confere, sem GPU, o modelo que o app carrega de verdade: o `.fsceneb`
// que o hook do flutter_scene gera do assets/3d/maquete.glb no build (e no
// `flutter test`) e que o `loadScene('assets/3d/maquete.glb')` lê do
// flutter_scene_generated/. Os nós que a CenaMaquete procura com
// getChildByName têm de estar lá, com o pivô do manifesto (e o Z invertido
// pela conversão, que é o que a CameraMaquete assume), e os materiais de
// tema com os nomes que ela troca.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_scene/fscene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obra_facil/design/maquete/cena_maquete.dart';
import 'package:obra_facil/design/maquete/plano_maquete.dart';

/// Os ids de material de um componente `mesh` (uma primitiva ou várias).
List<LocalId> _materiais(ComponentSpec mesh) {
  LocalId? de(Map<String, PropertyValue> p) {
    final m = p['material'];
    return m is ResourceRefValue ? m.id : null;
  }

  final primitivas = mesh.properties['primitives'];
  if (primitivas is ListValue) {
    return [
      for (final p in primitivas.values)
        if (p is MapValue)
          if (de(p.values) case final id?) id,
    ];
  }
  return [if (de(mesh.properties) case final id?) id];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SceneDocument doc;
  late Map<String, NodeSpec> porNome;
  late Map<String, dynamic> manifesto;

  setUpAll(() async {
    final gerado = jsonDecode(
      await rootBundle.loadString('flutter_scene_generated/manifest.json'),
    ) as Map<String, dynamic>;
    final entrada = (gerado['entries'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((e) => e['source'] == CenaMaquete.caminhoGlb);
    final bytes = await rootBundle.load(
      'flutter_scene_generated/${entrada['file']}',
    );
    doc = readFsceneb(bytes.buffer.asUint8List());
    porNome = {};
    for (final n in doc.nodes.values) {
      expect(porNome.containsKey(n.name), isFalse,
          reason: 'nome repetido no modelo: ${n.name}');
      porNome[n.name] = n;
    }
    manifesto = jsonDecode(File('assets/3d/maquete.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('o modelo convertido tem a raiz e todo nó que o plano mexe', () {
    expect([for (final r in doc.rootNodes) r.name], [NosMaquete.raiz]);
    final ausentes = [
      for (final nome in PlanoMaquete.todosOsNos)
        if (!porNome.containsKey(nome)) nome,
    ];
    expect(ausentes, isEmpty);
    expect(porNome.keys, containsAll([NosMaquete.base, NosMaquete.cotas]));
  });

  test('pivô de cada peça = manifesto com o Z invertido, sem giro/escala', () {
    final pivos = (manifesto['pivos'] as Map).cast<String, List>();
    expect(pivos, isNotEmpty);
    for (final MapEntry(key: nome, value: p) in pivos.entries) {
      final no = porNome[nome];
      expect(no, isNotNull, reason: nome);
      final t = no!.transform as TrsTransform;
      final esperado = [p[0] as num, p[1] as num, -(p[2] as num)];
      for (var i = 0; i < 3; i++) {
        expect(t.translation[i], closeTo(esperado[i].toDouble(), 1e-4),
            reason: '$nome[$i]');
        expect(t.scale[i], 1, reason: '$nome escala');
      }
      expect(t.rotation.w.abs(), closeTo(1, 1e-6), reason: '$nome giro');
    }
    // A prova direta da troca de sinal: o radier tem o pivô na borda dos
    // fundos (-3,7 no glTF, onde a frente é +Z).
    expect(
        (porNome['fundacao_radier']!.transform as TrsTransform).translation.z,
        closeTo(3.7, 1e-4));
  });

  test('todos os nós começam visíveis (o plano esconde o que falta)', () {
    for (final nome in PlanoMaquete.todosOsNos) {
      expect(porNome[nome]!.visible, isTrue, reason: nome);
    }
  });

  test('fantasmas usam o material "fantasma", sem luz; 06 e 08 são vazios', () {
    for (var f = 0; f < 10; f++) {
      final no = porNome[NosMaquete.fantasma(f)]!;
      final malhas = no.components.where((c) => c.type == 'mesh').toList();
      if (f == 6 || f == 8) {
        expect(malhas, isEmpty, reason: 'fantasma_fase_0$f');
        continue;
      }
      expect(malhas, hasLength(1), reason: 'fantasma $f');
      for (final id in _materiais(malhas.single)) {
        final m = doc.resources[id]! as MaterialResource;
        expect(m.name, 'fantasma');
        expect(m.type, 'unlit');
      }
    }
  });

  test('materiais de tema existem com o nome que a CenaMaquete troca', () {
    final materiais = {
      for (final r in doc.resources.values)
        if (r is MaterialResource) r.name: r.type,
    };
    for (final nome in ['base', 'grade', 'grade_forte', 'cota']) {
      expect(TemaMaquete.claro.corDoMaterial(nome), isNotNull);
      expect(materiais[nome], 'physicallyBased', reason: nome);
    }
    expect(materiais['fantasma'], 'unlit');
    // Toda peça de fase tem malha (o plano esconde/escala o próprio nó).
    for (final etapas in PlanoMaquete.etapasPorFase) {
      for (final e in etapas) {
        expect(porNome[e.no]!.components.any((c) => c.type == 'mesh'), isTrue,
            reason: e.no);
      }
    }
  });
}
