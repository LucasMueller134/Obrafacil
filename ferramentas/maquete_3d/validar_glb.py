#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Valida o maquete.glb sem dependências (só a biblioteca padrão).

Confere: glTF 2.0, nós obrigatórios, triângulos e chamadas de desenho por
fase, extensões usadas (nada de Draco/meshopt), material "fantasma" único,
tamanho do arquivo e caixa envolvente (Y para cima, origem no chão).

Uso:  python3 validar_glb.py ../../obra_facil/assets/3d/maquete.glb
Sai com código 1 se alguma regra falhar.
"""

import json
import os
import struct
import sys

LIMITE_TRI = 80_000
LIMITE_DC_FASE = 40
LIMITE_MB = 4.0
OBRIGATORIOS = (['base', 'cotas'] +
                ['fase_%02d_%s' % (i, n) for i, n in enumerate(
                    ['fundacao', 'estrutura', 'alvenaria', 'cobertura', 'eletrica', 'hidraulica',
                     'reboco', 'revestimentos', 'pintura', 'acabamento'])] +
                ['fantasma_fase_%02d' % i for i in range(10)] +
                ['estrutura_pilares', 'estrutura_vigas', 'estrutura_laje',
                 'cobertura_tercas', 'cobertura_telhas', 'alvenaria_fiada_00'])
TAM_COMP = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
N_COMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def ler_glb(caminho):
    with open(caminho, 'rb') as f:
        dados = f.read()
    magic, versao, total = struct.unpack_from('<III', dados, 0)
    assert magic == 0x46546C67, 'não é GLB'
    assert versao == 2, 'GLB versão %d' % versao
    assert total == len(dados), 'tamanho declarado difere do arquivo'
    off, js, binario = 12, None, b''
    while off < total:
        n, tipo = struct.unpack_from('<II', dados, off)
        bloco = dados[off + 8: off + 8 + n]
        if tipo == 0x4E4F534A:
            js = json.loads(bloco.decode('utf-8'))
        elif tipo == 0x004E4942:
            binario = bloco
        off += 8 + n
    return js, binario


def acessor_floats(g, binario, idx):
    a = g['accessors'][idx]
    bv = g['bufferViews'][a['bufferView']]
    n, comp = a['count'], N_COMP[a['type']]
    tam = TAM_COMP[a['componentType']]
    passo = bv.get('byteStride', tam * comp)
    base = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    fmt = '<' + {5126: 'f', 5125: 'I', 5123: 'H', 5121: 'B'}[a['componentType']] * comp
    return [struct.unpack_from(fmt, binario, base + i * passo) for i in range(n)]


def main():
    caminho = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), '..', '..', 'obra_facil', 'assets', '3d', 'maquete.glb')
    g, binario = ler_glb(caminho)
    erros = []
    mb = os.path.getsize(caminho) / 1e6
    print('arquivo: %s (%.2f MB)' % (os.path.normpath(caminho), mb))
    print('asset: %s' % g.get('asset'))
    ext = g.get('extensionsUsed', [])
    print('extensões usadas: %s' % (ext or 'nenhuma'))
    for e in ext:
        if 'draco' in e.lower() or 'meshopt' in e.lower() or 'quantization' in e.lower():
            erros.append('extensão proibida: %s' % e)

    nos = g['nodes']
    nomes = [n.get('name', '') for n in nos]
    for o in OBRIGATORIOS:
        if o not in nomes:
            erros.append('nó obrigatório ausente: %s' % o)
    if len(set(nomes)) != len(nomes):
        erros.append('nomes de nó repetidos')
    for n in nos:
        nm = n.get('name', '')
        if nm.startswith('fantasma_fase_') and n.get('extras', {}).get('fase') != int(nm[-2:]):
            erros.append('%s sem extras.fase = %d' % (nm, int(nm[-2:])))

    def tri_prim(p):
        if 'indices' in p:
            return g['accessors'][p['indices']]['count'] // 3
        return g['accessors'][p['attributes']['POSITION']]['count'] // 3

    def sub(i):
        lst = [i]
        for c in nos[i].get('children', []):
            lst += sub(c)
        return lst

    total_tri = sum(tri_prim(p) for n in nos if 'mesh' in n for p in g['meshes'][n['mesh']]['primitives'])
    total_dc = sum(len(g['meshes'][n['mesh']]['primitives']) for n in nos if 'mesh' in n)
    print('nós: %d   malhas: %d   materiais: %d   triângulos: %d   chamadas de desenho: %d' % (
        len(nos), len(g.get('meshes', [])), len(g.get('materials', [])), total_tri, total_dc))
    if total_tri > LIMITE_TRI:
        erros.append('triângulos acima de %d' % LIMITE_TRI)
    if mb > LIMITE_MB:
        erros.append('arquivo acima de %.1f MB' % LIMITE_MB)

    # hierarquia
    raizes = g['scenes'][g.get('scene', 0)]['nodes']

    def imprimir(i, nivel):
        n = nos[i]
        info = ''
        if 'mesh' in n:
            prims = g['meshes'][n['mesh']]['primitives']
            mats = [g['materials'][p['material']]['name'] for p in prims if 'material' in p]
            cor = any('COLOR_0' in p['attributes'] for p in prims)
            info = '  [%d tri, %d prim: %s%s]' % (sum(tri_prim(p) for p in prims), len(prims),
                                                 ', '.join(mats), ', COLOR_0' if cor else '')
        filhos = n.get('children', [])
        fiadas = [c for c in filhos if nomes[c].startswith('alvenaria_fiada_')]
        print('  ' * nivel + nomes[i] + info)
        if len(fiadas) > 3:
            for c in fiadas[:2]:
                imprimir(c, nivel + 1)
            print('  ' * (nivel + 1) + '... (%d fiadas: %s a %s)' % (len(fiadas), nomes[fiadas[0]], nomes[fiadas[-1]]))
            imprimir(fiadas[-1], nivel + 1)
            for c in filhos:
                if c not in fiadas:
                    imprimir(c, nivel + 1)
        else:
            for c in filhos:
                imprimir(c, nivel + 1)
    print('hierarquia:')
    for r in raizes:
        imprimir(r, 1)

    print('por fase (malha + fantasma):')
    for i, n in enumerate(nos):
        nm = n.get('name', '')
        if nm.startswith('fase_'):
            ids = sub(i)
            t = sum(tri_prim(p) for j in ids if 'mesh' in nos[j] for p in g['meshes'][nos[j]['mesh']]['primitives'])
            dc = sum(len(g['meshes'][nos[j]['mesh']]['primitives']) for j in ids if 'mesh' in nos[j])
            fj = nomes.index('fantasma_fase_' + nm[5:7]) if ('fantasma_fase_' + nm[5:7]) in nomes else None
            # um fantasma pode ser um nó vazio (fase sem desenho, como reboco e pintura)
            ft = (sum(tri_prim(p) for p in g['meshes'][nos[fj]['mesh']]['primitives'])
                  if fj is not None and 'mesh' in nos[fj] else 0)
            print('  %-24s %6d tri  %2d chamadas   %-18s %5d tri' % (nm, t, dc, nomes[fj] if fj is not None else '-', ft))
            if dc + 1 > LIMITE_DC_FASE:
                erros.append('%s: %d chamadas de desenho' % (nm, dc + 1))

    # materiais
    mats = g.get('materials', [])
    fant = [m for m in mats if m.get('name') == 'fantasma']
    if len(fant) != 1:
        erros.append('material "fantasma" deve existir uma única vez')
    for m in mats:
        pbr = m.get('pbrMetallicRoughness', {})
        print('  material %-18s cor=%s rug=%s met=%s %s%s' % (
            m.get('name'), [round(x, 3) for x in pbr.get('baseColorFactor', [1, 1, 1, 1])],
            pbr.get('roughnessFactor', 1), pbr.get('metallicFactor', 1), m.get('alphaMode', 'OPAQUE'),
            ' unlit' if 'KHR_materials_unlit' in m.get('extensions', {}) else ''))
    usados_fantasma = set()
    for n in nos:
        if n.get('name', '').startswith('fantasma_fase_') and 'mesh' in n:
            for p in g['meshes'][n['mesh']]['primitives']:
                usados_fantasma.add(mats[p['material']]['name'])
    if usados_fantasma != {'fantasma'}:
        erros.append('fantasmas usam materiais %s' % usados_fantasma)

    # caixa envolvente em coordenadas de mundo (só translações na hierarquia)
    lo, hi = [1e9] * 3, [-1e9] * 3

    def percorrer(i, t):
        n = nos[i]
        tt = [t[k] + n.get('translation', [0, 0, 0])[k] for k in range(3)]
        if 'rotation' in n or 'scale' in n or 'matrix' in n:
            erros.append('nó %s com rotação/escala (esperado só translação)' % n.get('name'))
        if 'mesh' in n:
            for p in g['meshes'][n['mesh']]['primitives']:
                a = g['accessors'][p['attributes']['POSITION']]
                for k in range(3):
                    lo[k] = min(lo[k], a['min'][k] + tt[k])
                    hi[k] = max(hi[k], a['max'][k] + tt[k])
        for c in n.get('children', []):
            percorrer(c, tt)
    for r in raizes:
        percorrer(r, [0, 0, 0])
    print('caixa envolvente: min %s  max %s' % ([round(x, 3) for x in lo], [round(x, 3) for x in hi]))
    if not (abs(lo[1] + 0.30) < 0.01 and 4.0 < hi[1] < 5.0):
        erros.append('eixo Y inesperado (tabuleiro deveria ir a y=-0,30 e a caixa d\'água passar de 4 m)')
    if abs(lo[0] + hi[0]) > 0.05 or abs(lo[2] + hi[2]) > 0.05:
        erros.append('modelo não está centrado na origem')

    # normais
    for n in nos:
        if 'mesh' not in n:
            continue
        for p in g['meshes'][n['mesh']]['primitives']:
            if 'NORMAL' not in p['attributes']:
                erros.append('%s sem NORMAL' % n.get('name'))

    if erros:
        print('FALHOU:')
        for e in erros:
            print('  - ' + e)
        sys.exit(1)
    print('OK: todas as regras passaram')


if __name__ == '__main__':
    main()
