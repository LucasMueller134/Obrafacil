// Grava o ModeloGerado como glb (glTF 2.0 binário): o mesmo tipo de arquivo
// do `maquete.glb`, que o flutter_scene carrega com `Node.fromGlbBytes`.

import 'dart:convert';
import 'dart:typed_data';

import 'geometria.dart';

Uint8List escreverGlb(ModeloGerado modelo) {
  final bin = BytesLE();
  final accessors = <Map<String, Object?>>[];
  final bufferViews = <Map<String, Object?>>[];
  final meshes = <Map<String, Object?>>[];
  final nodes = <Map<String, Object?>>[];
  final indiceDoMaterial = {
    for (final (i, m) in modelo.materiais.indexed) m.nome: i,
  };

  int vista(int inicio, int tamanho, {int? alvo}) {
    bufferViews.add({
      'buffer': 0,
      'byteOffset': inicio,
      'byteLength': tamanho,
      if (alvo != null) 'target': alvo,
    });
    return bufferViews.length - 1;
  }

  int? malha(MalhaGerada m) {
    final primitivas = <Map<String, Object?>>[];
    for (final MapEntry(key: material, value: lote) in m.lotes.entries) {
      if (lote.triangulos == 0) continue;
      final mat = indiceDoMaterial[material];
      if (mat == null) {
        throw StateError('material sem definição: $material');
      }
      final (mn, mx) = lote.limites();
      bin.alinhar();
      final pInicio = bin.length;
      bin.floats(lote.posicoes);
      final pVista = vista(pInicio, bin.length - pInicio, alvo: 34962);
      accessors.add({
        'bufferView': pVista,
        'componentType': 5126,
        'count': lote.vertices,
        'type': 'VEC3',
        'min': [mn.$1, mn.$2, mn.$3],
        'max': [mx.$1, mx.$2, mx.$3],
      });
      final pos = accessors.length - 1;
      bin.alinhar();
      final nInicio = bin.length;
      bin.floats(lote.normais);
      final nVista = vista(nInicio, bin.length - nInicio, alvo: 34962);
      accessors.add({
        'bufferView': nVista,
        'componentType': 5126,
        'count': lote.vertices,
        'type': 'VEC3',
      });
      final nor = accessors.length - 1;
      bin.alinhar();
      final iInicio = bin.length;
      final curto = lote.vertices < 65536;
      if (curto) {
        bin.uint16s(lote.indices);
      } else {
        bin.uint32s(lote.indices);
      }
      final iVista = vista(iInicio, bin.length - iInicio, alvo: 34963);
      accessors.add({
        'bufferView': iVista,
        'componentType': curto ? 5123 : 5125,
        'count': lote.indices.length,
        'type': 'SCALAR',
      });
      primitivas.add({
        'attributes': {'POSITION': pos, 'NORMAL': nor},
        'indices': accessors.length - 1,
        'material': mat,
        'mode': 4,
      });
    }
    if (primitivas.isEmpty) return null;
    meshes.add({'primitives': primitivas});
    return meshes.length - 1;
  }

  int no(NoGerado n) {
    final indice = nodes.length;
    nodes.add({}); // reserva o lugar (pai antes dos filhos)
    final m = malha(n.malha);
    final filhos = [for (final f in n.filhos) no(f)];
    final (tx, ty, tz) = n.translacao;
    nodes[indice] = {
      'name': n.nome,
      if (tx != 0 || ty != 0 || tz != 0) 'translation': [tx, ty, tz],
      if (m != null) 'mesh': m,
      if (filhos.isNotEmpty) 'children': filhos,
      if (n.extras != null) 'extras': n.extras,
    };
    return indice;
  }

  final raiz = no(modelo.raiz);
  bin.alinhar();
  final binario = bin.pegar();

  final usaSemLuz = modelo.materiais.any((m) => m.semLuz);
  final json = {
    'asset': {'version': '2.0', 'generator': 'ObraFácil (maquete da planta)'},
    if (usaSemLuz) 'extensionsUsed': ['KHR_materials_unlit'],
    'scene': 0,
    'scenes': [
      {
        'nodes': [raiz],
      },
    ],
    'nodes': nodes,
    'materials': [
      for (final m in modelo.materiais)
        {
          'name': m.nome,
          'pbrMetallicRoughness': {
            'baseColorFactor': m.cor,
            'metallicFactor': m.metalico,
            'roughnessFactor': m.rugosidade,
          },
          if (m.transparente) 'alphaMode': 'BLEND',
          if (m.duasFaces) 'doubleSided': true,
          if (m.semLuz)
            'extensions': {'KHR_materials_unlit': <String, Object?>{}},
        },
    ],
    'meshes': meshes,
    'accessors': accessors,
    'bufferViews': bufferViews,
    'buffers': [
      {'byteLength': binario.length},
    ],
  };

  final saida = BytesLE();
  final texto = utf8.encode(jsonEncode(json));
  final jsonPreenchido = BytesLE()
    ..bytes(texto)
    ..alinhar(4, 0x20);
  final jsonBytes = jsonPreenchido.pegar();
  final total = 12 + 8 + jsonBytes.length + 8 + binario.length;
  saida
    ..uint32s([0x46546C67, 2, total]) // "glTF", versão 2
    ..uint32s([jsonBytes.length, 0x4E4F534A]) // "JSON"
    ..bytes(jsonBytes)
    ..uint32s([binario.length, 0x004E4942]) // "BIN"
    ..bytes(binario);
  return saida.pegar();
}
