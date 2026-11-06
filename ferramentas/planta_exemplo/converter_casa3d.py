"""Converte a casa 7 x 20 do projeto casa-3d (MIT) para o formato de planta
do Obra na Mão (obra_facil/assets/plantas/casa_7x20.json).

Origem: https://github.com/jobasfernandes/casa-3d, src/data/planta.ts, que o
próprio projeto confere contra a planta desenhada (ref/*.svg). Licença MIT,
Copyright (c) 2026 Joseph Fernandes.

Uso:
    python3 ferramentas/planta_exemplo/converter_casa3d.py <pasta do casa-3d>

O formato de planta está descrito em obra_facil/lib/models/planta_obra.dart.
Coordenadas em metros, como no casa-3d: x de 0 (oeste) a 7 (leste), y de 0
(fundo do terreno) a 20 (rua). Paredes pela linha de centro, com espessura;
vãos pela distância ao longo da parede a partir do ponto "de".
"""

import json
import os
import re
import sys

ESP = 0.12
TOL = 0.011


def numeros(texto):
    return {k: float(v) for k, v in re.findall(r'(\w+):\s*(-?[\d.]+)', texto)}


def bloco(fonte, nome):
    i = fonte.index(f'export const {nome}')
    j = fonte.index(']\n', i)
    return fonte[i:j]


def retangulos(texto):
    return [numeros(m) for m in re.findall(r'\{[^{}]*\}', texto)]


def ler(pasta):
    fonte = open(os.path.join(pasta, 'src/data/planta.ts'), encoding='utf-8').read()
    paredes = retangulos(bloco(fonte, 'WALLS'))
    muros = retangulos(bloco(fonte, 'BOUNDARY_WALLS'))
    vidros = retangulos(bloco(fonte, 'GLASS_WALLS'))
    postes = retangulos(bloco(fonte, 'POSTS'))
    canto = numeros(re.search(r'GLASS_CORNER_POST: Rect = (\{[^}]*\})', fonte).group(1))
    comodos = []
    for m in re.finditer(r"id: '([^']+)',\s*name: '([^']+)',\s*rects: \[(.*?)\],\s*ceiling: (true|false),\s*floor: '(\w+)'", bloco(fonte, 'ROOMS'), re.S):
        comodos.append((m.group(1), m.group(2), retangulos(m.group(3)), m.group(4) == 'true', m.group(5)))
    aberturas = []
    for linha in bloco(fonte, 'OPENINGS').splitlines():
        if "kind:" not in linha:
            continue
        a = dict(re.findall(r"(\w+): '([^']*)'", linha))
        a.update(numeros(linha))
        a['vidro'] = 'glassEnclosure: true' in linha
        if 'HEIGHTS.door - 0.5' in linha:
            a['height'] = 2.1 - 0.5
        aberturas.append(a)
    return paredes, muros, vidros, postes, canto, comodos, aberturas


def segmentos(rects, tipo):
    """Retângulo de parede → (eixo, linha de centro, de, até, tipo)."""
    saida = []
    for r in rects:
        if r['d'] > r['w']:  # corre em y
            saida.append(('y', round(r['x'] + r['w'] / 2, 4), r['y'], r['y'] + r['d'], tipo))
        else:  # corre em x
            saida.append(('x', round(r['y'] + r['d'] / 2, 4), r['x'], r['x'] + r['w'], tipo))
    return saida


def juntar(segs, aberturas):
    """Junta trechos colineares separados por um vão (ou encostados)."""
    grupos = {}
    for s in segs:
        grupos.setdefault((s[0], s[1], s[4]), []).append(s)
    paredes = []
    for (eixo, linha, tipo), lista in grupos.items():
        lista.sort(key=lambda s: s[2])
        atual = None
        for s in lista:
            if atual is None:
                atual = [s[2], s[3], []]
                continue
            vao = s[2] - atual[1]
            casa = [a for a in aberturas
                    if a['along'] == eixo and abs(a['at'] + ESP / 2 - linha) < TOL
                    and abs(a['from'] - atual[1]) < TOL and abs(a['to'] - s[2]) < TOL]
            if vao <= TOL:
                atual[1] = s[3]
            elif casa:
                atual[2].append(casa[0])
                atual[1] = s[3]
            else:
                paredes.append((eixo, linha, tipo, *atual))
                atual = [s[2], s[3], []]
        paredes.append((eixo, linha, tipo, *atual))
    # Vão encostado na ponta de uma parede (a porta de correr do quarto vai
    # da ponta da parede até a parede central): a parede passa a ir até o
    # fim do vão, e o vão entra nela.
    for i, (eixo, linha, tipo, de, ate, vaos) in enumerate(paredes):
        for a in aberturas:
            if a['along'] != eixo or abs(a['at'] + ESP / 2 - linha) >= TOL or a in vaos:
                continue
            if abs(a['from'] - ate) < TOL:
                ate = a['to']
                vaos.append(a)
            elif abs(a['to'] - de) < TOL:
                de = a['from']
                vaos.append(a)
        paredes[i] = (eixo, linha, tipo, de, ate, vaos)
    return paredes


TIPO_ABERTURA = {
    'hinged-door': 'porta', 'sliding-door': 'porta_correr', 'passage': 'passagem',
    'window': 'janela', 'gate': 'portao',
}
PISO = {'porcelain': 'porcelanato', 'ceramic': 'ceramica', 'garage': 'garagem',
        'concrete': 'cimento', 'grass': 'grama'}
TIPO_COMODO = {
    'despensa': 'despensa', 'cozinha': 'cozinha', 'area-sol': 'jardim',
    'faixa-antessala': 'circulacao', 'antessala': 'sala', 'sala': 'sala',
    'quarto-2': 'quarto', 'banheiro': 'banheiro', 'corredor': 'circulacao',
    'quarto-1': 'quarto', 'garagem': 'garagem', 'area-coberta': 'varanda',
    'quintal': 'quintal', 'corredor-lateral': 'circulacao', 'frente': 'jardim',
}


def r2(v):
    return round(v + 0.0, 3)


def montar(pasta):
    paredes_r, muros_r, vidros_r, postes_r, canto, comodos_r, aberturas = ler(pasta)
    aberturas = [a for a in aberturas if a.get('enabled', 'true') != 'false' and 'enabled: false' not in json.dumps(a)]
    # Desligada no casa-3d (o desenho não tem janela no banheiro).
    aberturas = [a for a in aberturas if a['id'] != 'basculante-banheiro']
    # O muro leste é a parede da casa (a cozinha, a sala e a garagem
    # encostam nele): sobe até o pé-direito. Os outros muros ficam baixos.
    leste = [m for m in muros_r if m['x'] >= 7 - TOL]
    outros = [m for m in muros_r if m not in leste]
    segs = (segmentos(paredes_r, 'alvenaria') + segmentos(leste, 'alvenaria')
            + segmentos(outros, 'muro') + segmentos(vidros_r, 'mureta_vidro'))
    paredes = []
    for i, (eixo, linha, tipo, de, ate, vaos) in enumerate(sorted(juntar(segs, aberturas), key=lambda p: (p[0], p[1], p[3]))):
        a = [r2(linha), r2(de)] if eixo == 'y' else [r2(de), r2(linha)]
        b = [r2(linha), r2(ate)] if eixo == 'y' else [r2(ate), r2(linha)]
        p = {'id': f'p{i + 1:02d}', 'de': a, 'ate': b, 'espessura': ESP, 'tipo': tipo}
        if tipo == 'muro':
            p['altura'] = 2.2
        if tipo == 'mureta_vidro':
            p['altura'] = 2.1
        lista = []
        for v in vaos:
            item = {'id': v['id'], 'tipo': TIPO_ABERTURA[v['kind']],
                    'inicio': r2(v['from'] - de), 'largura': r2(v['to'] - v['from'])}
            if v['kind'] == 'window':
                item['peitoril'] = r2(v['sill'])
                item['altura'] = r2(v['height'])
            elif v['kind'] in ('hinged-door', 'sliding-door'):
                item['altura'] = 2.1
            elif v['kind'] == 'gate':
                item['altura'] = 2.2
            lista.append(item)
        # Vidro da área de sol: a janela ocupa o painel inteiro (não é vão
        # entre trechos de parede no casa-3d).
        for v in aberturas:
            if v['vidro'] and tipo == 'mureta_vidro' and v['along'] == eixo and abs(v['at'] + ESP / 2 - linha) < TOL:
                lista.append({'id': v['id'], 'tipo': 'janela', 'inicio': r2(max(0.0, v['from'] - de)),
                              'largura': r2(min(ate, v['to']) - max(de, v['from'])),
                              'peitoril': 0.5, 'altura': 1.6})
        if lista:
            p['aberturas'] = sorted(lista, key=lambda x: x['inicio'])
        paredes.append(p)
    pilares = [{'x': r2(r['x'] + r['w'] / 2), 'y': r2(r['y'] + r['d'] / 2)} for r in postes_r + [canto]]
    comodos = []
    for ident, nome, rects, coberto, piso in comodos_r:
        comodos.append({
            'id': ident, 'nome': nome, 'tipo': TIPO_COMODO[ident], 'coberto': coberto,
            'piso': PISO[piso],
            'retangulos': [{'x': r2(r['x']), 'y': r2(r['y']), 'largura': r2(r['w']), 'profundidade': r2(r['d'])} for r in rects],
        })
    return {
        'versao': 1,
        'nome': 'Casa térrea 7 x 20',
        'fonte': 'casa-3d (github.com/jobasfernandes/casa-3d), licença MIT',
        'terreno': {'largura': 7.0, 'profundidade': 20.0},
        'frente': 'y+',
        'alturas': {'peDireito': 2.5, 'porta': 2.1, 'muro': 2.2},
        'cobertura': {'tipo': 'laje_platibanda'},
        'paredes': paredes,
        'pilares': pilares,
        'comodos': comodos,
    }


if __name__ == '__main__':
    planta = montar(sys.argv[1])
    destino = os.path.join(os.path.dirname(__file__), '..', '..', 'obra_facil', 'assets', 'plantas', 'casa_7x20.json')
    with open(destino, 'w', encoding='utf-8') as f:
        json.dump(planta, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f"{len(planta['paredes'])} paredes, {sum(len(p.get('aberturas', [])) for p in planta['paredes'])} vãos, "
          f"{len(planta['comodos'])} cômodos, {len(planta['pilares'])} pilares soltos -> {os.path.normpath(destino)}")
