#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Maquete 3D da obra do ObraFácil (direção de arte "Prancheta").

Tudo é gerado por código no Blender (módulo Python ``bpy``), sem nenhum asset
de terceiros:

* ``obra_facil/assets/3d/maquete.glb``: a casa com uma peça nomeada por fase,
  para o app (flutter_scene) mostrar e esconder em tempo real;
* ``obra_facil/assets/3d/reserva/{claro,escuro}/estado_XX.webp``: 11 estados
  pré-renderizados em Cycles, para aparelhos sem suporte ao 3D;
* ``obra_facil/assets/3d/maquete.json``: manifesto com nós, fases, pivôs,
  materiais e cores por tema.

A casa é a mesma do protótipo web aprovado (maquete.js, three.js): planta de
9,40 x 7,40 m, estrutura de concreto, alvenaria de bloco cerâmico 14x19x39 em
fiadas amarradas, platibanda de 3 fiadas, telha de fibrocimento atrás da
platibanda, caixa d'água de 1000 L, padrão de entrada, reboco, calçada,
ripado, pintura, esquadrias e árvores de esfera.

Uso (ver LEIA-ME.md):
    python gerar_maquete.py                 # glb + manifesto + 22 imagens
    python gerar_maquete.py --sem-render    # só glb + manifesto
    python gerar_maquete.py --rapido --estados 0,5,10 --temas claro
"""

import argparse
import json
import math
import os
import random
import tempfile
import time
from collections import defaultdict

import bpy  # noqa: E402  (o bpy precisa vir antes do bmesh)
import bmesh  # noqa: E402
import numpy as np
from mathutils import Matrix, Vector

AQUI = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(AQUI, '..', '..'))
APP = os.path.join(REPO, 'obra_facil')
SAIDA_PADRAO = os.path.join(APP, 'assets', '3d')
FONTE_COTAS = os.path.join(APP, 'assets', 'fontes', 'Archivo-SemiCondensed-SemiBold.ttf')

# ---------------------------------------------------------------- fases
# (nó, nome no app, progresso em que a fase termina) — iguais ao protótipo.
FASES = [
    ('fase_00_fundacao', 'Fundação', 0.08),
    ('fase_01_estrutura', 'Estrutura', 0.22),
    ('fase_02_alvenaria', 'Alvenaria', 0.42),
    ('fase_03_cobertura', 'Cobertura', 0.52),
    ('fase_04_eletrica', 'Instalações elétricas', 0.56),
    ('fase_05_hidraulica', 'Instalações hidráulicas', 0.61),
    ('fase_06_reboco', 'Reboco e contrapiso', 0.72),
    ('fase_07_revestimentos', 'Revestimentos', 0.80),
    ('fase_08_pintura', 'Pintura', 0.90),
    ('fase_09_acabamento', 'Acabamento', 1.00),
]

# ---------------------------------------------------------------- planta
# Coordenadas do protótipo, em metros: x para a direita, y para cima, z para
# a frente (rua). É também o sistema do glTF (Y para cima). Piso pronto em
# y = 0,20; fundo da laje em y = 3,00; terreno (topo do tabuleiro) em y = 0.
PISO = 0.20
TOPO_VIGA = 3.00
ESP_LAJE = 0.12
Y_LAJE = TOPO_VIGA + ESP_LAJE          # 3,12: topo da laje
H_VIGA = 0.32
Y_VIGA = TOPO_VIGA - H_VIGA            # 2,68: fundo da viga
XM, ZM = 4.4, 3.4                      # eixos das paredes
PILARES_X = [-XM, -1.5, 1.5, XM]
FIADA, MODULO = 0.20, 0.40             # bloco 14x19x39 + junta de 1 cm
JUNTA = 0.005                          # meia junta
ALT_PAREDE = Y_VIGA - PISO             # 2,48
N_FIADAS = int(ALT_PAREDE / FIADA + 1e-6)   # 12 fiadas + encunhamento

# Aberturas [u0, u1, v0, v1] (v medido do piso), iguais ao protótipo. Única
# mudança: a janela da frente foi deslocada 20 cm para a esquerda, porque no
# protótipo ela invadia o pilar de x = -1,5 (o pilar ficava dentro do vão).
PAREDES = [
    dict(lado='frente', fixo=ZM, eixo='x', de=-XM, ate=XM, fora=+1,
         aberturas=[(-3.8, -1.6, 0.9, 2.1), (1.6, 2.5, 0.0, 2.1)]),
    dict(lado='fundos', fixo=-ZM, eixo='x', de=-XM, ate=XM, fora=-1,
         aberturas=[(-1.0, 0.2, 1.4, 2.1), (2.2, 3.4, 1.0, 2.1)]),
    dict(lado='esquerda', fixo=-XM, eixo='z', de=-ZM, ate=ZM, fora=-1,
         aberturas=[(0.4, 1.8, 1.0, 2.1)]),
    dict(lado='direita', fixo=XM, eixo='z', de=-ZM, ate=ZM, fora=+1,
         aberturas=[(-1.9, -0.6, 1.0, 2.1)]),
]
PILARES = [(x, z) for x in PILARES_X for z in (-ZM, ZM)] + [(-XM, 0.0), (XM, 0.0)]

# Caixa d'água e sua base sobre a laje.
CX_X, CX_Z = 2.9, -2.2
BASE_CX = (2.2, 3.6, Y_LAJE - 0.005, Y_LAJE + 0.60, -2.9, -1.5)
Y_CX = BASE_CX[3]
# Árvores [x, z, raio] (posições do protótipo, com ajuste fino para não
# encostar na calçada nem nas cotas).
ARVORES = [(-6.05, 5.0, 0.55), (-5.3, 5.5, 0.40), (6.2, -4.75, 0.60),
           (-6.15, -4.95, 0.45), (5.4, -5.4, 0.35), (-6.35, 1.2, 0.42)]
# Poste do padrão de entrada. No protótipo ficava em (5,6; 5,2), na linha de
# visada da quina da frente (o poste "virava" a quina da casa); em (6,0; 4,3)
# ele aparece à direita da quina, fora da calçada e depois do fim da cota.
POSTE_X, POSTE_Z = 6.0, 4.3
# Câmera das imagens de reserva (a mesma do protótipo: azimute 0,62 rad a
# partir de +z, elevação 0,52 rad, olhando para (0; 1,1; 0)).
CAM_AZIMUTE, CAM_ELEVACAO = 0.62, 0.52

# ---------------------------------------------------------------- cores
def lin(hexcor):
    """sRGB '#RRGGBB' -> RGB linear (Blender e glTF guardam linear)."""
    h = hexcor.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


TONS_BLOCO = (0.80, 1.00)   # multiplicador por bloco (COLOR_0)
MEDIA_TOM = sum(TONS_BLOCO) / 2

# nome: (cor sRGB, rugosidade, metálico, extras)
MATERIAIS = {
    'concreto': ('#989A96', 0.88, 0.0, {}),
    'bloco_ceramico': ('#B05D38', 0.86, 0.0, {'tom_por_bloco': True}),
    'argamassa': ('#BDB8AE', 0.95, 0.0, {}),
    'reboco': ('#B2AFA7', 0.93, 0.0, {}),
    'tinta': ('#E9E8E3', 0.82, 0.0, {}),
    'madeira_pinus': ('#C49A5E', 0.72, 0.0, {}),
    'madeira_porta': ('#8A5A33', 0.55, 0.0, {}),
    'fibrocimento': ('#A3A8A8', 0.78, 0.0, {}),
    'plastico_azul': ('#2F6DB3', 0.42, 0.0, {}),
    'pvc_marrom': ('#7A4A26', 0.45, 0.0, {}),
    'aluminio_escuro': ('#2B2E31', 0.38, 0.75, {}),
    'metal_galvanizado': ('#A4A9AD', 0.42, 0.85, {}),
    'policarbonato': ('#8A8F93', 0.50, 0.0, {}),
    'vidro': ('#9FBFD3', 0.05, 0.0, {'alpha': 0.35}),
    'granito': ('#55575A', 0.35, 0.0, {}),
    'calcada': ('#BEBEB9', 0.95, 0.0, {}),
    'arvore': ('#E6E4DE', 0.90, 0.0, {}),
    # Materiais que o app troca de cor conforme o tema (ver TEMAS).
    'base': ('#F2F2EF', 0.95, 0.0, {'tema': True}),
    'grade': ('#DCDDDA', 0.95, 0.0, {'tema': True}),
    'grade_forte': ('#C8C9C6', 0.95, 0.0, {'tema': True}),
    'cota': ('#1A1C1F', 0.80, 0.0, {'tema': True}),
    'fantasma': ('#1A1C1F', 1.0, 0.0, {'tema': True, 'unlit': True}),
}

# Cores dos materiais de tema e do fundo (o fundo não faz parte do glb).
TEMAS = {
    'claro': {'fundo': '#F4F5F3', 'base': '#F2F2EF', 'grade': '#DCDDDA',
              'grade_forte': '#C8C9C6', 'cota': '#1A1C1F', 'fantasma': '#1A1C1F'},
    'escuro': {'fundo': '#121315', 'base': '#2A2D31', 'grade': '#393D41',
               'grade_forte': '#4D5155', 'cota': '#ECEDE9', 'fantasma': '#ECEDE9'},
}
# Opacidade de lápis do fantasma nas imagens de reserva. No escuro é menor
# porque o traço claro de 5 cm sobre o fundo escuro pesa mais.
OPACIDADE_FANTASMA = {'claro': 0.78, 'escuro': 0.62}


def srgb_hex(rgb_lin):
    """RGB linear -> sRGB '#RRGGBB'."""
    out = []
    for x in rgb_lin:
        x = min(max(x, 0.0), 1.0)
        s = x * 12.92 if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055
        out.append(int(round(s * 255)))
    return '#%02X%02X%02X' % tuple(out)


def fantasma_opaco(tema):
    """Cor opaca equivalente ao fantasma com opacidade sobre a base do tema,
    misturada em luz linear (para o app desenhar o material OPAQUE do glb sem
    alfa: com alfa, as 3 faces de cada traço se sobrepõem e o traço mancha)."""
    a = OPACIDADE_FANTASMA[tema]
    f, b = lin(TEMAS[tema]['fantasma']), lin(TEMAS[tema]['base'])
    return srgb_hex([a * x + (1 - a) * y for x, y in zip(f, b)])


# ---------------------------------------------------------------- geometria
def P(x, y, z):
    """Protótipo/glTF (x, y para cima, z para a frente) -> Blender (Z para cima)."""
    return Vector((x, -z, y))


ARESTAS_CAIXA = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4),
                 (0, 4), (1, 5), (2, 6), (3, 7)]
FACES_CAIXA = {  # nomes no sistema do protótipo
    'baixo': (0, 3, 2, 1), 'cima': (4, 5, 6, 7), 'frente': (0, 1, 5, 4),
    'fundos': (2, 3, 7, 6), 'esquerda': (3, 0, 4, 7), 'direita': (1, 2, 6, 5),
}


def cantos(x0, x1, y0, y1, z0, z1):
    bx0, bx1, by0, by1, bz0, bz1 = x0, x1, -z1, -z0, y0, y1
    return [Vector((bx0, by0, bz0)), Vector((bx1, by0, bz0)), Vector((bx1, by1, bz0)),
            Vector((bx0, by1, bz0)), Vector((bx0, by0, bz1)), Vector((bx1, by0, bz1)),
            Vector((bx1, by1, bz1)), Vector((bx0, by1, bz1))]


class Malha:
    """Acumula geometria (coordenadas Blender) com materiais por face."""

    def __init__(self, nome):
        self.nome = nome
        self.materiais = []
        self.v, self.f, self.fmat, self.fsuave = [], [], [], []
        self.duras = set()
        self.cor = []
        self.tem_cor = False

    def _mat(self, nome):
        if nome not in self.materiais:
            self.materiais.append(nome)
        return self.materiais.index(nome)

    def add(self, verts, faces, mat, suave=True, duras=(), cor=None):
        b = len(self.v)
        self.v.extend(Vector(v) for v in verts)
        if cor is not None:
            self.tem_cor = True
        self.cor.extend([cor or (1.0, 1.0, 1.0, 1.0)] * len(verts))
        mi = self._mat(mat)
        for f in faces:
            self.f.append(tuple(b + i for i in f))
            self.fmat.append(mi)
            self.fsuave.append(suave)
        for a, c in duras:
            self.duras.add((min(a, c) + b, max(a, c) + b))

    def caixa(self, r, mat, chanfro=0.0, seg=2, omitir=(), cor=None):
        """Caixa alinhada aos eixos; r = (x0, x1, y0, y1, z0, z1) no protótipo."""
        x0, x1, y0, y1, z0, z1 = r
        if min(x1 - x0, y1 - y0, z1 - z0) <= 1e-5:
            return
        if chanfro > 0:
            vs, fs = caixa_chanfrada(r, chanfro, seg)
            self.add(vs, fs, mat, suave=True, cor=cor)
        else:
            vs = cantos(*r)
            fs = [f for k, f in FACES_CAIXA.items() if k not in omitir]
            self.add(vs, fs, mat, suave=True, duras=ARESTAS_CAIXA, cor=cor)

    def vazia(self):
        return not self.f


def caixa_chanfrada(r, w, seg):
    x0, x1, y0, y1, z0, z1 = r
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = (Matrix.Translation(P((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
         @ Matrix.Diagonal((x1 - x0, z1 - z0, y1 - y0, 1.0)))
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    w = min(w, 0.45 * min(x1 - x0, y1 - y0, z1 - z0))
    bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=w, offset_type='OFFSET',
                    segments=seg, profile=0.5, affect='EDGES', clamp_overlap=True)
    vs = [v.co.copy() for v in bm.verts]
    idx = {v: i for i, v in enumerate(bm.verts)}
    fs = [tuple(idx[v] for v in f.verts) for f in bm.faces]
    bm.free()
    return vs, fs


def cilindro(m, base, eixo, raio, comp, mat, segs=12, tampas=True, raio2=None):
    """Cilindro (ou tronco de cone) a partir do centro da base, eixo 'x','y','z'."""
    raio2 = raio if raio2 is None else raio2
    eixos = {'x': (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
             'y': (Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
             'z': (Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)))}
    a, e1, e2 = eixos[eixo]
    c0 = P(*base)
    vs, fs, duras = [], [], []
    for i in range(segs):
        t = 2 * math.pi * i / segs
        d = e1 * math.cos(t) + e2 * math.sin(t)
        vs.append(c0 + d * raio)
        vs.append(c0 + a * comp + d * raio2)
    for i in range(segs):
        j = (i + 1) % segs
        fs.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    if tampas:
        fs.append(tuple(2 * i for i in reversed(range(segs))))
        fs.append(tuple(2 * i + 1 for i in range(segs)))
        for i in range(segs):
            j = (i + 1) % segs
            duras += [(2 * i, 2 * j), (2 * i + 1, 2 * j + 1)]
    # garante normais para fora
    ctr = c0 + a * comp / 2
    f0 = fs[0]
    n = (vs[f0[1]] - vs[f0[0]]).cross(vs[f0[2]] - vs[f0[1]])
    if n.dot(vs[f0[0]] - ctr) < 0:
        fs = [tuple(reversed(f)) for f in fs]
    m.add(vs, fs, mat, suave=True, duras=duras)


def arredondar(pts, r=0.05, n=4):
    """Polilinha com cantos arredondados (para tubos)."""
    pts = [Vector(p) for p in pts]
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        d1, d2 = (a - b).normalized(), (c - b).normalized()
        p0, p1 = b + d1 * r, b + d2 * r
        for k in range(n + 1):
            t = k / n
            out.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * b + t ** 2 * p1)
    out.append(pts[-1])
    return out


def tubo(m, pts_proto, raio, mat, segs=10):
    pts = arredondar([P(*p) for p in pts_proto])
    tang = []
    for i in range(len(pts)):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        tang.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(tang[0].z) < 0.9 else Vector((1, 0, 0))
    n = (ref - tang[0] * ref.dot(tang[0])).normalized()
    vs, fs = [], []
    for i, p in enumerate(pts):
        if i:
            q = tang[i - 1].rotation_difference(tang[i])
            n = (q @ n)
            n = (n - tang[i] * n.dot(tang[i])).normalized()
        bnorm = tang[i].cross(n)
        for k in range(segs):
            t = 2 * math.pi * k / segs
            vs.append(p + (n * math.cos(t) + bnorm * math.sin(t)) * raio)
    for i in range(len(pts) - 1):
        for k in range(segs):
            j = (k + 1) % segs
            fs.append((i * segs + k, i * segs + j, (i + 1) * segs + j, (i + 1) * segs + k))
    fs.append(tuple(reversed(range(segs))))
    last = (len(pts) - 1) * segs
    fs.append(tuple(last + k for k in range(segs)))
    # normais para fora
    f0 = fs[0]
    nn = (vs[f0[1]] - vs[f0[0]]).cross(vs[f0[2]] - vs[f0[1]])
    if nn.dot(vs[f0[0]] - pts[0]) < 0:
        fs = [tuple(reversed(f)) for f in fs]
    m.add(vs, fs, mat, suave=True)


def torno(m, centro, perfil, mat, segs=48, ang_duro=35):
    """Sólido de revolução em torno do eixo vertical; perfil = [(raio, altura)]."""
    c = P(*centro)
    vs, fs, duras, aneis = [], [], [], []
    for r, h in perfil:
        if r < 1e-6:
            aneis.append([len(vs)])
            vs.append(c + Vector((0, 0, h)))
            continue
        anel = []
        for i in range(segs):
            t = 2 * math.pi * i / segs
            anel.append(len(vs))
            vs.append(c + Vector((r * math.cos(t), r * math.sin(t), h)))
        aneis.append(anel)
    for a, b in zip(aneis[:-1], aneis[1:]):
        if len(a) == 1:
            for i in range(segs):
                fs.append((a[0], b[(i + 1) % segs], b[i]))
        elif len(b) == 1:
            for i in range(segs):
                fs.append((a[i], a[(i + 1) % segs], b[0]))
        else:
            for i in range(segs):
                j = (i + 1) % segs
                fs.append((a[i], a[j], b[j], b[i]))
    # arestas duras onde o perfil dobra mais que ang_duro
    for k in range(1, len(perfil) - 1):
        (r0, h0), (r1, h1), (r2, h2) = perfil[k - 1], perfil[k], perfil[k + 1]
        d1 = Vector((r1 - r0, h1 - h0)).normalized()
        d2 = Vector((r2 - r1, h2 - h1)).normalized()
        if d1.dot(d2) < math.cos(math.radians(ang_duro)) and len(aneis[k]) > 1:
            an = aneis[k]
            duras += [(an[i], an[(i + 1) % segs]) for i in range(segs)]
    # normais para fora (o perfil sobe pelo lado de fora)
    f0 = fs[len(fs) // 2]
    nn = (vs[f0[1]] - vs[f0[0]]).cross(vs[f0[2]] - vs[f0[1]])
    mid = vs[f0[0]]
    if nn.dot(Vector((mid.x - c.x, mid.y - c.y, 0))) < 0:
        fs = [tuple(reversed(f)) for f in fs]
    m.add(vs, fs, mat, suave=True, duras=duras)


def esfera(m, centro, raio, mat, subdiv=3):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=raio)
    bmesh.ops.translate(bm, vec=P(*centro), verts=bm.verts)
    vs = [v.co.copy() for v in bm.verts]
    idx = {v: i for i, v in enumerate(bm.verts)}
    fs = [tuple(idx[v] for v in f.verts) for f in bm.faces]
    bm.free()
    m.add(vs, fs, mat, suave=True)


def quad_horizontal(m, x0, x1, z0, z1, y, mat):
    vs = [P(x0, y, z1), P(x1, y, z1), P(x1, y, z0), P(x0, y, z0)]
    m.add(vs, [(0, 1, 2, 3)], mat, suave=False)


def faixa_plana(m, a, b, larg, y, mat):
    """Traço plano no tabuleiro de a=(x,z) até b=(x,z)."""
    a, b = Vector((a[0], a[1])), Vector((b[0], b[1]))
    d = (b - a).normalized()
    n = Vector((-d.y, d.x)) * (larg / 2)
    q = [a - n, b - n, b + n, a + n]
    vs = [P(p.x, y, p.y) for p in q]
    nn = (vs[1] - vs[0]).cross(vs[2] - vs[1])
    f = (0, 1, 2, 3) if nn.z > 0 else (3, 2, 1, 0)
    m.add(vs, [f], mat, suave=False)


# ---------------------------------------------------------------- utilidades da planta
def faixa_parede(p, u0, u1, v0, v1, w0, w1):
    """Coordenadas da parede (u ao longo, v do piso, w espessura) -> caixa no protótipo."""
    y0, y1 = PISO + v0, PISO + v1
    w0, w1 = min(w0, w1), max(w0, w1)
    if p['eixo'] == 'x':
        return (u0, u1, y0, y1, p['fixo'] + w0, p['fixo'] + w1)
    return (p['fixo'] + w0, p['fixo'] + w1, y0, y1, u0, u1)


def pilares_na_parede(p):
    if p['eixo'] == 'x':
        return sorted(x for x, z in PILARES if abs(z - p['fixo']) < 1e-6)
    return sorted(z for x, z in PILARES if abs(x - p['fixo']) < 1e-6)


def segmentos(p):
    us = pilares_na_parede(p)
    return [(a + 0.1, b - 0.1) for a, b in zip(us[:-1], us[1:])]


def subtrair(base, cortes, minimo=1e-4):
    partes = list(base)
    for c0, c1 in cortes:
        novas = []
        for a, b in partes:
            if c1 <= a or c0 >= b:
                novas.append((a, b))
                continue
            if c0 > a:
                novas.append((a, c0))
            if c1 < b:
                novas.append((c1, b))
        partes = novas
    return [(a, b) for a, b in partes if b - a > minimo]


def q_baixo(v):
    return math.floor(v / FIADA + 1e-6) * FIADA


def q_cima(v):
    return math.ceil(v / FIADA - 1e-6) * FIADA


def assentar(intervalo, k):
    """Divide um trecho de fiada em blocos de 39 cm, com amarração (meio bloco
    nas fiadas ímpares) e sem sobras menores que 12 cm."""
    a, b = intervalo
    u = a - (MODULO / 2 if k % 2 else 0.0)
    pecas = []
    while u < b - 1e-6:
        s, e = max(u, a), min(u + MODULO, b)
        if e - s > 1e-4:
            pecas.append([s, e])
        u += MODULO
    while len(pecas) > 1:
        i = next((i for i, (s, e) in enumerate(pecas) if e - s < 0.12), None)
        if i is None:
            break
        if i == 0:
            j = 1
        elif i == len(pecas) - 1:
            j = i - 1
        else:
            la = pecas[i - 1][1] - pecas[i - 1][0]
            lb = pecas[i + 1][1] - pecas[i + 1][0]
            j = i - 1 if la < lb else i + 1
        lo, hi = min(i, j), max(i, j)
        s, e = pecas[lo][0], pecas[hi][1]
        pecas[lo:hi + 1] = [[s, e]] if e - s <= 0.5 else [[s, (s + e) / 2], [(s + e) / 2, e]]
    return pecas


# ---------------------------------------------------------------- cena Blender
class Cena:
    def __init__(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.scene = bpy.context.scene
        self.col = bpy.data.collections.new('maquete')
        self.scene.collection.children.link(self.col)
        self.mats = {}
        self.objs_fase = defaultdict(list)    # índice -> objetos de malha
        self.objs_fantasma = {}
        self.objs_fixos = []                   # base, cotas
        self.fantasmas = defaultdict(list)     # índice -> [(a, b)] em coords Blender
        self.curvas = defaultdict(list)        # índice -> [(pontos, fechada)]
        self.cotas_info = []                   # [(texto, centro no protótipo)]
        self.pivos = {}
        self.rng = random.Random(20261015)
        self.criar_materiais()
        self.raiz = self.vazio('maquete', None)

    # ---- materiais
    def criar_materiais(self):
        for nome, (cor, rough, metal, extra) in MATERIAIS.items():
            m = bpy.data.materials.new(nome)
            nt = m.node_tree
            nodes, links = nt.nodes, nt.links
            out = nodes['Material Output']
            bsdf = nodes['Principled BSDF']
            c = lin(cor)
            if extra.get('unlit'):
                nodes.remove(bsdf)
                rgb = nodes.new('ShaderNodeRGB')
                rgb.name = 'cor'
                rgb.outputs[0].default_value = (*c, 1.0)
                links.new(rgb.outputs[0], out.inputs['Surface'])
            else:
                if extra.get('tom_por_bloco'):
                    fator = tuple(min(1.0, x / MEDIA_TOM) for x in c)
                    mix = nodes.new('ShaderNodeMix')
                    mix.data_type = 'RGBA'
                    mix.blend_type = 'MULTIPLY'
                    sock = {x.identifier: x for x in mix.inputs}
                    sock['Factor_Float'].default_value = 1.0
                    sock['A_Color'].default_value = (*fator, 1.0)
                    attr = nodes.new('ShaderNodeVertexColor')
                    attr.layer_name = 'tom'
                    links.new(attr.outputs['Color'], sock['B_Color'])
                    saida = {x.identifier: x for x in mix.outputs}['Result_Color']
                    links.new(saida, bsdf.inputs['Base Color'])
                else:
                    bsdf.inputs['Base Color'].default_value = (*c, 1.0)
                bsdf.inputs['Roughness'].default_value = rough
                bsdf.inputs['Metallic'].default_value = metal
                if 'alpha' in extra:
                    bsdf.inputs['Alpha'].default_value = extra['alpha']
                    try:
                        m.surface_render_method = 'BLENDED'
                    except Exception:
                        pass
                    m.use_backface_culling = False
                else:
                    m.use_backface_culling = True
            m.diffuse_color = (*c, extra.get('alpha', 1.0))
            self.mats[nome] = m

    def cor_material(self, nome, hexcor):
        m = self.mats[nome]
        c = (*lin(hexcor), 1.0)
        m.diffuse_color = c
        nt = m.node_tree
        if 'cor' in nt.nodes:
            nt.nodes['cor'].outputs[0].default_value = c
        elif 'Principled BSDF' in nt.nodes:
            nt.nodes['Principled BSDF'].inputs['Base Color'].default_value = c

    # ---- objetos
    def vazio(self, nome, pai, props=None):
        o = bpy.data.objects.new(nome, None)
        o.empty_display_size = 0.3
        self.col.objects.link(o)
        o.parent = pai
        for k, v in (props or {}).items():
            o[k] = v
        return o

    def objeto(self, malha, pai, pivo=(0.0, 0.0, 0.0), fase=None, normais=True):
        if malha.vazia():
            return None
        me = bpy.data.meshes.new(malha.nome)
        me.from_pydata([tuple(v) for v in malha.v], [], malha.f)
        me.update()
        for nome in malha.materiais:
            me.materials.append(self.mats[nome])
        me.polygons.foreach_set('material_index', malha.fmat)
        me.polygons.foreach_set('use_smooth', malha.fsuave)
        if malha.duras:
            mapa = {tuple(sorted(e.vertices)): e.index for e in me.edges}
            vals = [False] * len(me.edges)
            for k in malha.duras:
                i = mapa.get(k)
                if i is not None:
                    vals[i] = True
            at = me.attributes.get('sharp_edge') or me.attributes.new('sharp_edge', 'BOOLEAN', 'EDGE')
            at.data.foreach_set('value', vals)
        if malha.tem_cor:
            ca = me.color_attributes.new('tom', 'FLOAT_COLOR', 'POINT')
            flat = [c for cor in malha.cor for c in cor]
            ca.data.foreach_set('color', flat)
            me.color_attributes.active_color = ca
        piv = P(*pivo)
        me.transform(Matrix.Translation(-piv))
        o = bpy.data.objects.new(malha.nome, me)
        self.col.objects.link(o)
        o.location = piv
        o.parent = pai
        if normais:
            wn = o.modifiers.new('normais_ponderadas', 'WEIGHTED_NORMAL')
            wn.mode = 'FACE_AREA'
            wn.weight = 50
            wn.keep_sharp = True
        if fase is not None:
            self.objs_fase[fase].append(o)
        self.pivos[malha.nome] = [round(x, 4) for x in pivo]
        return o

    def objeto_de_mesh(self, nome, me, mat, pai, fase, chanfro=0.012, seg=2):
        me.name = nome
        me.materials.clear()
        me.materials.append(self.mats[mat])
        for poly in me.polygons:
            poly.use_smooth = True
        o = bpy.data.objects.new(nome, me)
        self.col.objects.link(o)
        o.parent = pai
        if chanfro:
            bv = o.modifiers.new('chanfro', 'BEVEL')
            bv.width = chanfro
            bv.segments = seg
            bv.limit_method = 'ANGLE'
            bv.angle_limit = math.radians(30)
            bv.use_clamp_overlap = True
        wn = o.modifiers.new('normais_ponderadas', 'WEIGHTED_NORMAL')
        wn.mode = 'FACE_AREA'
        wn.weight = 50
        wn.keep_sharp = True
        self.objs_fase[fase].append(o)
        self.pivos[nome] = [0.0, 0.0, 0.0]
        return o

    def solido(self, positivas, negativas):
        """Malha booleana (caixas positivas menos negativas), em coords Blender."""
        m = Malha('tmp_solido')
        for r in positivas:
            m.caixa(r, 'concreto')
        me = bpy.data.meshes.new('tmp')
        me.from_pydata([tuple(v) for v in m.v], [], m.f)
        me.update()
        o = bpy.data.objects.new('tmp_solido', me)
        self.scene.collection.objects.link(o)
        cortadores = []
        if negativas:
            col = bpy.data.collections.new('tmp_cortes')
            self.scene.collection.children.link(col)
            for i, r in enumerate(negativas):
                mc = Malha('c')
                mc.caixa(r, 'concreto')
                mec = bpy.data.meshes.new('tmp_c%d' % i)
                mec.from_pydata([tuple(v) for v in mc.v], [], mc.f)
                mec.update()
                oc = bpy.data.objects.new('tmp_c%d' % i, mec)
                col.objects.link(oc)
                cortadores.append(oc)
            bo = o.modifiers.new('bool', 'BOOLEAN')
            bo.operation = 'DIFFERENCE'
            bo.operand_type = 'COLLECTION'
            bo.collection = col
            bo.solver = 'EXACT'
        dg = bpy.context.evaluated_depsgraph_get()
        res = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
        for oc in cortadores:
            mec = oc.data
            bpy.data.objects.remove(oc)
            bpy.data.meshes.remove(mec)
        if negativas:
            bpy.data.collections.remove(col)
        return res

    # ---- fantasmas (desenho tracejado do que falta)
    # O desenho é o contorno do VOLUME de cada fase (placa, caixa, plano,
    # cilindro), não as arestas de cada peça: a 340 px de largura, com traço
    # de 5 cm, linhas a menos de ~10 cm uma da outra viram ruído.
    def fantasma_retangulo(self, fase, pts):
        for i in range(len(pts)):
            self.fantasmas[fase].append((pts[i].copy(), pts[(i + 1) % len(pts)].copy()))

    def fantasma_ret_h(self, fase, x0, x1, z0, z1, y):
        """Retângulo horizontal na altura y (coordenadas do protótipo)."""
        self.fantasma_retangulo(fase, [P(x0, y, z1), P(x1, y, z1), P(x1, y, z0), P(x0, y, z0)])

    def fantasma_quinas(self, fase, x, z, y0, y1):
        """As 4 arestas verticais de uma caixa de ±x por ±z, de y0 a y1."""
        for sx in (-1, 1):
            for sz in (-1, 1):
                self.linha(fase, (sx * x, y0, sz * z), (sx * x, y1, sz * z))

    def linha(self, fase, a, b):
        """Linha do desenho entre dois pontos do protótipo."""
        self.fantasmas[fase].append((P(*a), P(*b)))

    def fantasma_curva(self, fase, pts, fechada=True):
        self.curvas[fase].append(([p.copy() for p in pts], fechada))


# ================================================================ construção
def construir(c):
    raiz = c.raiz
    t0 = time.time()
    fases = []
    for i, (no, nome, fim) in enumerate(FASES):
        fases.append(c.vazio(no, raiz, {'fase': i, 'nome': nome, 'progresso_fim': fim}))

    base(c, raiz)
    cotas(c, raiz)
    fundacao(c, fases[0])
    estrutura(c, fases[1])
    alvenaria(c, fases[2])
    cobertura(c, fases[3])
    eletrica(c, fases[4])
    hidraulica(c, fases[5])
    reboco_e_pintura(c, fases[6], fases[8])
    revestimentos(c, fases[7])
    acabamento(c, fases[9])
    fantasmas(c, raiz)
    print('[maquete] cena montada em %.1f s' % (time.time() - t0))


# ---- base (tabuleiro com grade de 0,5 m e de 2 m)
def base(c, raiz):
    m = Malha('base')
    m.caixa((-7.0, 7.0, -0.30, 0.0, -6.0, 6.0), 'base', chanfro=0.03, seg=3)
    for i in range(-13, 14):
        x = i * 0.5
        forte = i % 4 == 0
        quad_horizontal(m, x - (0.0125 if forte else 0.007), x + (0.0125 if forte else 0.007),
                        -5.95, 5.95, 0.0026 if forte else 0.0012, 'grade_forte' if forte else 'grade')
    for i in range(-11, 12):
        z = i * 0.5
        forte = i % 4 == 0
        quad_horizontal(m, -6.95, 6.95, z - (0.0125 if forte else 0.007), z + (0.0125 if forte else 0.007),
                        0.0033 if forte else 0.0019, 'grade_forte' if forte else 'grade')
    o = c.objeto(m, raiz)
    c.objs_fixos.append(o)


# ---- cotas "9,40" e "7,40" com traço oblíquo
def cotas(c, raiz):
    m = Malha('cotas')
    y = 0.0045

    def cota(a, b, normal, texto, rot):
        a, b = Vector(a), Vector(b)
        faixa_plana(m, a, b, 0.018, y, 'cota')
        n = Vector(normal)
        for p in (a, b):
            d = Vector((0.18, 0.18))
            faixa_plana(m, p - d, p + d, 0.034, y, 'cota')
            faixa_plana(m, p - n * 0.35, p + n * 0.14, 0.012, y, 'cota')
        centro = (a + b) / 2 + n * 0.42
        texto_malha(m, texto, centro, rot, y)
        c.cotas_info.append((texto, (centro.x, y, centro.y)))

    cota((-4.7, 5.3), (4.7, 5.3), (0, 1), '9,40', 0.0)
    cota((6.3, -3.7), (6.3, 3.7), (1, 0), '7,40', math.pi / 2)
    o = c.objeto(m, raiz, normais=False)
    c.objs_fixos.append(o)


def texto_malha(m, texto, centro, rot, y):
    cu = bpy.data.curves.new('txt', 'FONT')
    cu.body = texto
    if os.path.exists(FONTE_COTAS):
        cu.font = bpy.data.fonts.load(FONTE_COTAS, check_existing=True)
    cu.size = 0.44
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    cu.resolution_u = 6
    o = bpy.data.objects.new('txt', cu)
    bpy.context.scene.collection.objects.link(o)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    rotm = Matrix.Rotation(rot, 4, 'Z')
    loc = P(centro.x, y, centro.y)
    vs = [loc + rotm @ v.co for v in me.vertices]
    fs = [tuple(p.vertices) for p in me.polygons]
    fs2 = []
    for f in fs:
        nn = (vs[f[1]] - vs[f[0]]).cross(vs[f[2]] - vs[f[1]])
        fs2.append(f if nn.z >= 0 else tuple(reversed(f)))
    m.add(vs, fs2, 'cota', suave=False)
    bpy.data.objects.remove(o)
    bpy.data.curves.remove(cu)
    bpy.data.meshes.remove(me)


# ---- 00 fundação: radier
def fundacao(c, pai):
    m = Malha('fundacao_radier')
    m.caixa((-4.7, 4.7, -0.02, PISO, -3.7, 3.7), 'concreto', chanfro=0.012)
    c.objeto(m, pai, pivo=(0, 0, -3.7), fase=0)
    c.fantasma_ret_h(0, -4.7, 4.7, -3.7, 3.7, PISO)   # a placa: só o contorno de cima


# ---- 01 estrutura: pilares, vigas e laje
def estrutura(c, pai):
    m = Malha('estrutura_pilares')
    for x, z in PILARES:
        m.caixa((x - 0.1, x + 0.1, PISO - 0.01, Y_VIGA + 0.005, z - 0.1, z + 0.1), 'concreto', chanfro=0.01)
    c.objeto(m, pai, pivo=(0, PISO, 0), fase=1)

    m = Malha('estrutura_vigas')
    vigas = [(-4.5, 4.5, ZM - 0.1, ZM + 0.1), (-4.5, 4.5, -ZM - 0.1, -ZM + 0.1),
             (-4.31, 4.31, -0.1, 0.1),
             (-XM - 0.1, -XM + 0.1, -ZM + 0.09, ZM - 0.09), (XM - 0.1, XM + 0.1, -ZM + 0.09, ZM - 0.09)]
    for x0, x1, z0, z1 in vigas:
        m.caixa((x0, x1, Y_VIGA, TOPO_VIGA + 0.01, z0, z1), 'concreto', chanfro=0.01)
    c.objeto(m, pai, pivo=(0, Y_VIGA, 0), fase=1)

    m = Malha('estrutura_laje')
    m.caixa((-4.7, 4.7, TOPO_VIGA, Y_LAJE, -3.7, 3.7), 'concreto', chanfro=0.012)
    c.objeto(m, pai, pivo=(0, TOPO_VIGA, -3.7), fase=1)
    # Desenho da estrutura: só a laje, como uma placa (a aresta de baixo é a
    # que se lê). Pilares e vigas ficam dentro da caixa das paredes (fase 02).
    c.fantasma_ret_h(1, -4.7, 4.7, -3.7, 3.7, TOPO_VIGA)


# ---- 02 alvenaria: bloco cerâmico 14x19x39, fiada por fiada
def alvenaria(c, pai):
    rng = c.rng

    def tom():
        t = TONS_BLOCO[0] + (TONS_BLOCO[1] - TONS_BLOCO[0]) * rng.random()
        q = (rng.random() - 0.5) * 0.06
        return (min(1.0, t * (1 + q)), t, min(1.0, t * (1 - q * 0.8)), 1.0)

    def bloco(m, p, s, e, v0):
        du = (rng.random() - 0.5) * 0.002
        dw = (rng.random() - 0.5) * 0.003
        r = faixa_parede(p, s + JUNTA + du, e - JUNTA + du, v0 + JUNTA, v0 + FIADA - JUNTA,
                         -0.07 + dw, 0.07 + dw)
        m.caixa(r, 'bloco_ceramico', omitir=('baixo',), cor=tom())

    # paredes térreas: 12 fiadas + encunhamento sob a viga
    for k in range(N_FIADAS):
        m = Malha('alvenaria_fiada_%02d' % k)
        v0, v1 = k * FIADA, (k + 1) * FIADA
        for p in PAREDES:
            for a, b in segmentos(p):
                abs_ = [ab for ab in p['aberturas'] if ab[0] >= a - 1e-6 and ab[1] <= b + 1e-6]
                cortes, concreto = [], []
                for a0, a1, b0, b1 in abs_:
                    b0q, b1q = q_baixo(b0), q_cima(b1)
                    if b0q - 1e-6 <= v0 < b1q - 1e-6:
                        cortes.append((a0, a1))
                    if abs(v0 - b1q) < 1e-6:          # verga sobre o vão
                        concreto.append((max(a, a0 - 0.3), min(b, a1 + 0.3)))
                    if b0q > 1e-6 and abs(v1 - b0q) < 1e-6:   # contraverga sob a janela
                        concreto.append((max(a, a0 - 0.3), min(b, a1 + 0.3)))
                livres = subtrair([(a, b)], cortes)
                for itv in subtrair(livres, concreto):
                    for s, e in assentar(itv, k):
                        bloco(m, p, s, e, v0)
                for c0, c1 in concreto:
                    m.caixa(faixa_parede(p, c0 + JUNTA, c1 - JUNTA, v0 + JUNTA, v1 - JUNTA, -0.07, 0.07),
                            'concreto', chanfro=0.006)
                for s, e in livres:
                    s2 = s - 0.01 if abs(s - a) < 1e-6 else s + 0.008
                    e2 = e + 0.01 if abs(e - b) < 1e-6 else e - 0.008
                    m.caixa(faixa_parede(p, s2, e2, v0 - (0.01 if k == 0 else 0.0), v1 - 0.002, -0.06, 0.06),
                            'argamassa', omitir=('baixo',))
                if k == N_FIADAS - 1:   # encunhamento
                    m.caixa(faixa_parede(p, a - 0.01, b + 0.01, v1 - 0.002, ALT_PAREDE + 0.005, -0.065, 0.065),
                            'argamassa', omitir=('baixo',))
        c.objeto(m, pai, pivo=(0, PISO + v0, 0), fase=2)

    # platibanda: 3 fiadas sobre a laje, com amarração nos cantos
    corridas_x = lambda cheia: [dict(eixo='x', fixo=s * 3.63, de=-4.7 if cheia else -4.56,
                                     ate=4.7 if cheia else 4.56) for s in (1, -1)]
    corridas_z = lambda cheia: [dict(eixo='z', fixo=s * 4.63, de=-3.7 if cheia else -3.56,
                                     ate=3.7 if cheia else 3.56) for s in (1, -1)]
    for k in range(3):
        m = Malha('alvenaria_fiada_%02d' % (N_FIADAS + k))
        y0 = Y_LAJE + k * FIADA
        cheia_x = k % 2 == 0
        for r in corridas_x(cheia_x) + corridas_z(not cheia_x):
            p = dict(r, aberturas=[])
            cheia = (r['eixo'] == 'x') == cheia_x
            vv0 = y0 - PISO
            for s, e in assentar((r['de'], r['ate']), k):
                bloco(m, p, s, e, vv0)
            topo = vv0 + FIADA - (0.01 if k == 2 else 0.002)
            if cheia:
                s2, e2 = r['de'] + 0.01, r['ate'] - 0.01
            else:
                s2, e2 = r['de'] - 0.02, r['ate'] + 0.02
            m.caixa(faixa_parede(p, s2, e2, vv0 - (0.01 if k == 0 else 0.0), topo, -0.06, 0.06),
                    'argamassa', omitir=('baixo',))
        c.objeto(m, pai, pivo=(0, y0, 0), fase=2)

    # Desenho: a caixa da casa pronta (face do reboco/pintura, ±4,52 x ±3,52),
    # só as 4 quinas do piso à laje; a platibanda (face pronta ±4,74 x ±3,74)
    # com o contorno do topo e as 4 quinas. Os vãos ficam no desenho das
    # esquadrias (fase 09), que dura até a obra pronta.
    c.fantasma_quinas(2, 4.52, 3.52, PISO, TOPO_VIGA)
    c.fantasma_quinas(2, 4.74, 3.74, TOPO_VIGA, 3.78)
    c.fantasma_ret_h(2, -4.74, 4.74, -3.74, 3.74, 3.78)


# ---- 03 cobertura: terças de pinus e telha de fibrocimento ondulada (5 %)
def y_tercas(z):
    """Topo das terças (plano de apoio das telhas)."""
    return Y_LAJE + 0.13 + (3.2 - z) * 0.05


def cobertura(c, pai):
    # As telhas e terças não são recortadas em volta da base da caixa d'água:
    # a base é da fase de hidráulica e, quando aparece, atravessa o telhado
    # (sem isso o telhado ficaria com um buraco nas fases 03 e 04).
    m = Malha('cobertura_tercas')
    for i in range(5):
        z = -3.2 + i * 1.6
        yc = y_tercas(z) - 0.05
        trechos = [(-4.54, 4.54)]
        for x0, x1 in trechos:
            r = (x0, x1, yc - 0.05, yc + 0.05, z - 0.035, z + 0.035)
            m.caixa(r, 'madeira_pinus', chanfro=0.005)
        for xp in (-3.9, -1.95, 0.0, 1.95, 3.9):
            if not any(x0 + 0.05 < xp < x1 - 0.05 for x0, x1 in trechos):
                continue
            m.caixa((xp - 0.035, xp + 0.035, Y_LAJE - 0.005, yc - 0.045, z - 0.035, z + 0.035),
                    'madeira_pinus', omitir=('baixo',))
    c.objeto(m, pai, pivo=(0, Y_LAJE, 0), fase=3)

    m = Malha('cobertura_telhas')
    X0, X1, NC = -4.54, 4.54, 8
    larg = (X1 - X0) / NC
    passo = larg / 6
    filas = [(-3.54, 0.10, 0.008), (-0.10, 3.45, 0.0)]   # a de trás sobrepõe a da frente
    for z0, z1, dy in filas:
        for col in range(NC):
            xa, xb = X0 + col * larg, X0 + (col + 1) * larg
            ext = passo / 4 if col % 2 else 0.0
            lift = 0.004 if col % 2 else 0.0
            telha_ondulada(m, max(X0, xa - ext), min(X1, xb + ext), z0, z1, dy + lift, X0, passo)
    # Desenho: um só plano inclinado (as emendas e as terças, a 340 px, liam
    # como piso cerâmico sobre a laje).
    yy = lambda z: y_tercas(z) + 0.03
    z0, z1 = filas[0][0], filas[-1][1]
    c.fantasma_retangulo(3, [P(X0, yy(z1), z1), P(X1, yy(z1), z1), P(X1, yy(z0), z0), P(X0, yy(z0), z0)])
    c.objeto(m, pai, pivo=(0, Y_LAJE, 0), fase=3, normais=False)


def telha_ondulada(m, x0, x1, z0, z1, dy, xref, passo, h=0.051, div=10):
    xs = {x0, x1}
    n0 = math.ceil((x0 - xref) / (passo / div))
    n1 = math.floor((x1 - xref) / (passo / div))
    for n in range(n0, n1 + 1):
        x = xref + n * passo / div
        if x0 + 1e-4 < x < x1 - 1e-4:
            xs.add(x)
    xs = sorted(xs)
    onda = lambda x: h * (1 - math.cos(2 * math.pi * (x - xref) / passo)) / 2
    vs, fs = [], []
    for x in xs:
        vs.append(P(x, y_tercas(z1) + 0.002 + dy + onda(x), z1))
        vs.append(P(x, y_tercas(z0) + 0.002 + dy + onda(x), z0))
    for i in range(len(xs) - 1):
        fs.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
    f = fs[0]
    nn = (vs[f[1]] - vs[f[0]]).cross(vs[f[2]] - vs[f[1]])
    if nn.z < 0:
        fs = [tuple(reversed(f)) for f in fs]
    m.add(vs, fs, 'fibrocimento', suave=True)


# ---- 04 instalações elétricas: padrão de entrada
def eletrica(c, pai):
    px, pz = POSTE_X, POSTE_Z
    m = Malha('eletrica_poste')
    r = (px - 0.08, px + 0.08, -0.05, 2.8, pz - 0.08, pz + 0.08)
    m.caixa(r, 'concreto', chanfro=0.008)
    c.objeto(m, pai, pivo=(px, 0, pz), fase=4)
    c.linha(4, (px, 0.0, pz), (px, 2.8, pz))   # desenho: o eixo do poste

    m = Malha('eletrica_caixa_medicao')
    rc = (px - 0.18, px + 0.18, 1.25, 1.75, pz + 0.08, pz + 0.26)
    m.caixa(rc, 'policarbonato', chanfro=0.012)
    m.caixa((px - 0.07, px + 0.07, 1.52, 1.66, pz + 0.255, pz + 0.268), 'vidro', chanfro=0.003, seg=1)
    m.caixa((px - 0.15, px + 0.15, 1.30, 1.32, pz + 0.255, pz + 0.265), 'aluminio_escuro')
    c.objeto(m, pai, pivo=(px, 1.25, pz), fase=4)
    zf = rc[5]   # desenho: a face da caixa virada para a rua
    c.fantasma_retangulo(4, [P(rc[0], rc[2], zf), P(rc[1], rc[2], zf), P(rc[1], rc[3], zf), P(rc[0], rc[3], zf)])

    m = Malha('eletrica_eletroduto')
    zc = pz + 0.17
    tubo(m, [(px, 1.74, zc), (px, 2.92, zc), (px - 0.12, 2.92, zc), (px - 0.12, 2.84, zc)], 0.02,
         'metal_galvanizado')
    tubo(m, [(px, -0.03, zc), (px, 1.26, zc)], 0.02, 'metal_galvanizado')
    for yb in (0.6, 2.4):
        m.caixa((px - 0.03, px + 0.03, yb, yb + 0.03, pz + 0.075, zc + 0.025), 'metal_galvanizado')
    c.objeto(m, pai, pivo=(px, 0, pz), fase=4)


# ---- 05 instalações hidráulicas: caixa d'água de 1000 L sobre base
PERFIL_CAIXA = [(0.0, 0.0), (0.50, 0.0), (0.53, 0.025), (0.535, 0.06), (0.572, 0.235),
                (0.584, 0.245), (0.576, 0.258), (0.622, 0.47), (0.634, 0.48), (0.626, 0.493),
                (0.655, 0.70), (0.672, 0.715), (0.70, 0.735), (0.70, 0.77), (0.716, 0.775),
                (0.716, 0.80), (0.69, 0.828), (0.58, 0.865), (0.40, 0.898), (0.20, 0.918),
                (0.0, 0.925)]


def hidraulica(c, pai):
    m = Malha('hidraulica_base')
    m.caixa(BASE_CX, 'concreto', chanfro=0.012)
    c.objeto(m, pai, pivo=(CX_X, Y_LAJE, CX_Z), fase=5)
    # desenho da base: contorno do topo e as 4 quinas
    bx0, bx1, _, by1, bz0, bz1 = BASE_CX
    c.fantasma_ret_h(5, bx0, bx1, bz0, bz1, by1)
    for x in (bx0, bx1):
        for z in (bz0, bz1):
            c.linha(5, (x, Y_LAJE, z), (x, by1, z))

    m = Malha('hidraulica_caixa_dagua')
    torno(m, (CX_X, Y_CX, CX_Z), PERFIL_CAIXA, 'plastico_azul', segs=48)
    c.objeto(m, pai, pivo=(CX_X, Y_CX, CX_Z), fase=5)
    # desenho da caixa: um tronco de cone (fundo, borda da tampa e as duas
    # geratrizes da silhueta vista da câmera padrão)
    centro = P(CX_X, Y_CX, CX_Z)
    (r0, h0), (r1, h1) = (0.50, 0.0), (0.716, 0.80)
    for r, h in ((r0, h0), (r1, h1)):
        c.fantasma_curva(5, [centro + Vector((r * math.cos(t), r * math.sin(t), h))
                             for t in np.linspace(0, 2 * math.pi, 33)[:-1]])
    for s in (-1, 1):
        az = Vector((math.cos(CAM_AZIMUTE), math.sin(CAM_AZIMUTE))) * s   # (x, -z) Blender
        a = centro + Vector((az.x * r0, az.y * r0, h0))
        b = centro + Vector((az.x * r1, az.y * r1, h1))
        c.fantasmas[5].append((a, b))

    m = Malha('hidraulica_tubos')
    yb = Y_CX + 0.10
    tubo(m, [(CX_X + 0.52, yb, CX_Z), (BASE_CX[1] + 0.12, yb, CX_Z), (BASE_CX[1] + 0.12, Y_LAJE - 0.01, CX_Z)],
         0.025, 'pvc_marrom')
    tubo(m, [(CX_X - 0.55, Y_CX + 0.62, CX_Z), (BASE_CX[0] - 0.12, Y_CX + 0.62, CX_Z),
             (BASE_CX[0] - 0.12, Y_LAJE - 0.01, CX_Z)], 0.02, 'pvc_marrom')
    c.objeto(m, pai, pivo=(CX_X, Y_LAJE, CX_Z), fase=5, normais=False)


# ---- 06 reboco e contrapiso / 08 pintura (casca 4 mm maior por cima do reboco)
def casca(c, folga):
    """Sólidos do reboco (folga=0) ou da pintura (folga=0,004 m para fora)."""
    f = folga
    cortes = [(-4.28 + f, 4.28 - f, 0.0, 3.3, -3.28 + f, 3.28 - f)]
    for p in PAREDES:
        for a0, a1, b0, b1 in p['aberturas']:
            v0 = b0 + f if b0 > 1e-6 else -0.2
            cortes.append(faixa_parede(p, a0 + f, a1 - f, v0, b1 - f, -0.4, 0.4))
    paredes = c.solido([(-4.52 - f, 4.52 + f, PISO - 0.01 - f, TOPO_VIGA + 0.01 + f, -3.52 - f, 3.52 + f)], cortes)
    faixa = c.solido([(-4.74 - f, 4.74 + f, 2.98 - f, 3.74 + f, -3.74 - f, 3.74 + f)],
                     [(-4.54 + f, 4.54 - f, 2.8, 3.9, -3.54 + f, 3.54 - f)])
    return paredes, faixa


def juntar(*meshes):
    bm = bmesh.new()
    for me in meshes:
        bm.from_mesh(me)
    out = bpy.data.meshes.new('junto')
    bm.to_mesh(out)
    bm.free()
    for me in meshes:
        bpy.data.meshes.remove(me)
    return out


def reboco_e_pintura(c, pai_reboco, pai_pintura):
    # Reboco e pintura não mudam a silhueta da casa: não têm desenho (os nós
    # fantasma_fase_06 e _08 existem, vazios).
    paredes, faixa = casca(c, 0.0)
    c.objeto_de_mesh('reboco_paredes', juntar(paredes, faixa), 'reboco', pai_reboco, 6, chanfro=0.012)
    m = Malha('reboco_contrapiso')
    m.caixa((-4.29, 4.29, PISO - 0.01, PISO + 0.03, -3.29, 3.29), 'argamassa', omitir=('baixo',))
    c.objeto(m, pai_reboco, pivo=(0, PISO, 0), fase=6)

    paredes, faixa = casca(c, 0.004)
    c.objeto_de_mesh('pintura_paredes', juntar(paredes, faixa), 'tinta', pai_pintura, 8, chanfro=0.012)


# ---- 07 revestimentos: calçada, ripado, pingadeira, peitoris e soleira
def revestimentos(c, pai):
    m = Malha('revestimentos_calcada')
    faixas = [(-5.6, 5.6, 3.72, 4.7, 'x'), (-5.6, 5.6, -4.7, -3.72, 'x'),
              (-5.6, -4.72, -3.72 + 0.004, 3.72 - 0.004, 'z'), (4.72, 5.6, -3.72 + 0.004, 3.72 - 0.004, 'z')]
    for x0, x1, z0, z1, eixo in faixas:
        a, b = (x0, x1) if eixo == 'x' else (z0, z1)
        n = max(1, round((b - a) / 1.25))
        passo = (b - a) / n
        for i in range(n):
            s, e = a + i * passo + 0.004, a + (i + 1) * passo - 0.004
            r = (s, e, -0.01, 0.06, z0, z1) if eixo == 'x' else (x0, x1, -0.01, 0.06, s, e)
            m.caixa(r, 'calcada', chanfro=0.006)
    c.fantasma_ret_h(7, -5.6, 5.6, -4.7, 4.7, 0.06)   # desenho: só o contorno externo
    degrau = (1.5, 2.6, 0.055, 0.13, 3.71, 4.02)
    m.caixa(degrau, 'calcada', chanfro=0.006)
    c.objeto(m, pai, fase=7)

    m = Malha('revestimentos_ripado')
    for yb in (0.50, 2.62):
        m.caixa((-1.2, 0.265, yb, yb + 0.06, 3.522, 3.552), 'madeira_pinus', omitir=('fundos',))
    for i in range(14):
        x = -1.15 + i * 0.105
        m.caixa((x - 0.025, x + 0.025, 0.25, 2.95, 3.55, 3.61), 'madeira_pinus', chanfro=0.004)
    c.objeto(m, pai, pivo=(0, 0.25, 3.55), fase=7)
    c.fantasma_retangulo(7, [P(-1.175, 0.25, 3.61), P(0.24, 0.25, 3.61), P(0.24, 2.95, 3.61),
                             P(-1.175, 2.95, 3.61)])   # desenho: a face do ripado

    m = Malha('revestimentos_pingadeira')
    y0, y1 = 3.738, 3.78
    for z0, z1, de, ate, eixo in [(3.51, 3.77, -4.77, 4.77, 'x'), (-3.77, -3.51, -4.77, 4.77, 'x'),
                                  (-4.77, -4.51, -3.51 + 0.003, 3.51 - 0.003, 'z'),
                                  (4.51, 4.77, -3.51 + 0.003, 3.51 - 0.003, 'z')]:
        n = max(1, round((ate - de) / 1.0))
        passo = (ate - de) / n
        for i in range(n):
            s, e = de + i * passo + 0.0025, de + (i + 1) * passo - 0.0025
            r = (s, e, y0, y1, z0, z1) if eixo == 'x' else (z0, z1, y0, y1, s, e)
            m.caixa(r, 'calcada', chanfro=0.006, seg=1, omitir=())
    c.objeto(m, pai, pivo=(0, y0, 0), fase=7)

    m = Malha('revestimentos_peitoris')
    for p in PAREDES:
        f = p['fora']
        for a0, a1, b0, b1 in p['aberturas']:
            if b0 > 1e-6:
                r = faixa_parede(p, a0 - 0.03, a1 + 0.03, b0 - 0.015, b0 + 0.015, -0.02 * f, 0.154 * f)
            else:
                r = faixa_parede(p, a0 + 0.002, a1 - 0.002, -0.01, 0.015, -0.124 * f, 0.16 * f)
            m.caixa(r, 'granito', chanfro=0.004)
    c.objeto(m, pai, fase=7)


# ---- 09 acabamento: esquadrias, vidro, porta e árvores de esfera
def acabamento(c, pai):
    me_esq = Malha('acabamento_esquadrias')
    me_porta = Malha('acabamento_porta')
    for p in PAREDES:
        f = p['fora']
        wc = 0.02 * f
        for a0, a1, b0, b1 in p['aberturas']:
            porta = b0 < 1e-6
            vb = 0.013 if porta else b0 + 0.013
            ua, ub, vt = a0 - 0.002, a1 + 0.002, b1 + 0.002
            fr = lambda u0, u1, v0, v1, w0, w1: faixa_parede(p, u0, u1, v0, v1, wc + w0, wc + w1)
            e = 0.05
            # marco
            me_esq.caixa(fr(ua, ub, vt - e, vt, -0.05, 0.05), 'aluminio_escuro', chanfro=0.003, seg=1)
            me_esq.caixa(fr(ua, ua + e, vb, vt - e, -0.05, 0.05), 'aluminio_escuro', chanfro=0.003, seg=1)
            me_esq.caixa(fr(ub - e, ub, vb, vt - e, -0.05, 0.05), 'aluminio_escuro', chanfro=0.003, seg=1)
            if not porta:
                me_esq.caixa(fr(ua + e, ub - e, vb, vb + e, -0.05, 0.05), 'aluminio_escuro', chanfro=0.003, seg=1)
                # duas folhas de correr em trilhos diferentes
                iu0, iu1, iv0, iv1 = ua + e, ub - e, vb + e, vt - e
                meio = (iu0 + iu1) / 2
                s = 0.035
                for (u0, u1, w) in ((iu0, meio + 0.025, 0.018), (meio - 0.025, iu1, -0.018)):
                    me_esq.caixa(fr(u0, u1, iv1 - s, iv1, w - 0.012, w + 0.012), 'aluminio_escuro')
                    me_esq.caixa(fr(u0, u1, iv0, iv0 + s, w - 0.012, w + 0.012), 'aluminio_escuro')
                    me_esq.caixa(fr(u0, u0 + s, iv0 + s, iv1 - s, w - 0.012, w + 0.012), 'aluminio_escuro')
                    me_esq.caixa(fr(u1 - s, u1, iv0 + s, iv1 - s, w - 0.012, w + 0.012), 'aluminio_escuro')
                    me_esq.caixa(fr(u0 + s, u1 - s, iv0 + s, iv1 - s, w - 0.003, w + 0.003), 'vidro')
            else:
                me_porta.caixa(fr(ua + e, ub - e, 0.02, vt - e, -0.018, 0.018), 'madeira_porta', chanfro=0.004)
                um = ub - e - 0.09
                me_porta.caixa(fr(um - 0.02, um + 0.02, 0.98, 1.10, 0.018, 0.026), 'aluminio_escuro')
                me_porta.caixa(fr(um - 0.12, um + 0.01, 1.03, 1.05, 0.026, 0.07), 'aluminio_escuro')
            # Desenho do vão acabado, na face pronta da parede (reboco, 12 cm do
            # eixo): é o único desenho de abertura e some só com a obra pronta.
            y0, y1 = PISO + b0, PISO + b1
            w = p['fixo'] + f * 0.12
            if p['eixo'] == 'x':
                pts = [P(a0, y0, w), P(a1, y0, w), P(a1, y1, w), P(a0, y1, w)]
            else:
                pts = [P(w, y0, a0), P(w, y0, a1), P(w, y1, a1), P(w, y1, a0)]
            c.fantasma_retangulo(9, pts)
    c.objeto(me_esq, pai, fase=9)
    c.objeto(me_porta, pai, fase=9)

    m = Malha('acabamento_arvores')
    # desenho: a silhueta da copa, um círculo no plano perpendicular à vista
    dirc = P(math.sin(CAM_AZIMUTE) * math.cos(CAM_ELEVACAO), math.sin(CAM_ELEVACAO),
             math.cos(CAM_AZIMUTE) * math.cos(CAM_ELEVACAO)).normalized()
    e1 = Vector((math.cos(CAM_AZIMUTE), math.sin(CAM_AZIMUTE), 0))
    e2 = dirc.cross(e1).normalized()
    for x, z, r in ARVORES:
        yc = r * 1.42
        esfera(m, (x, yc, z), r, 'arvore', subdiv=4)
        cilindro(m, (x, -0.01, z), 'y', 0.028, yc - r * 0.6, 'madeira_pinus', segs=8)
        ctr = P(x, yc, z)
        ts = np.linspace(0, 2 * math.pi, 33)[:-1]
        c.fantasma_curva(9, [ctr + (e1 * math.cos(t) + e2 * math.sin(t)) * r for t in ts])
    c.objeto(m, pai, fase=9)


# ---- fantasmas: deduplicar, tracejar e montar um nó por fase
# Medido para a imagem de 340 px de largura (~16,6 px/m): traço de 28 cm vira
# ~4,6 px, vão de 15 cm ~2,5 px e o prisma de 5 cm ~0,8 px (linha fina, não
# pontilhado).
TRACO, VAO, LADO = 0.28, 0.15, 0.05   # traço, vão e lado do prisma (m)
TOL_DESENHO = 0.08                    # linhas paralelas mais perto que isso viram uma


def consolidar(segs_por_fase, tol=0.03, ang=3.0):
    """Remove arestas repetidas: uma aresta que coincide (até ``tol``) com outra
    de fase igual ou posterior só fica na posterior (os fantasmas de fases não
    concluídas aparecem juntos). Emenda trechos colineares da mesma fase."""
    lim = math.cos(math.radians(ang))
    O, D = [], []
    trechos = []     # por linha: dict fase -> [(t0, t1)]
    for fase in sorted(segs_por_fase, reverse=True):
        for a, b in segs_por_fase[fase]:
            a, b = np.array(a, float), np.array(b, float)
            for q in (a, b):
                if q[2] < 0.012:
                    q[2] = 0.012
            v = b - a
            L = float(np.linalg.norm(v))
            if L < 0.01:
                continue
            d = v / L
            livres = [(0.0, L)]
            alvo = None
            if O:
                Oa, Da = np.array(O), np.array(D)
                par = np.abs(Da @ d) > lim

                def dist(p):
                    w = p - Oa
                    t = (w * Da).sum(1)
                    perp = w - t[:, None] * Da
                    return np.linalg.norm(perp, axis=1), t

                da, ta = dist(a)
                db, tb = dist(b)
                cand = np.where(par & (da < tol) & (db < tol))[0]
                cobertos = []
                for k in cand:
                    for intervalos in trechos[k].values():
                        for t0, t1 in intervalos:
                            p0, p1 = Oa[k] + Da[k] * t0, Oa[k] + Da[k] * t1
                            s0, s1 = sorted((float((p0 - a) @ d), float((p1 - a) @ d)))
                            cobertos.append((s0, s1))
                livres = subtrair(livres, sorted(cobertos), minimo=0.02)
                if len(cand):
                    alvo = int(cand[np.argmin(da[cand] + db[cand])])
            if not livres:
                continue
            if alvo is None:
                O.append(a)
                D.append(d)
                trechos.append(defaultdict(list))
                alvo = len(O) - 1
            o, dd = np.array(O[alvo]), np.array(D[alvo])
            for s0, s1 in livres:
                t0, t1 = sorted((float((a + d * s0 - o) @ dd), float((a + d * s1 - o) @ dd)))
                trechos[alvo][fase].append((t0, t1))
    caminhos = defaultdict(list)
    for k, por_fase in enumerate(trechos):
        for fase, itvs in por_fase.items():
            itvs.sort()
            uniao = []
            for t0, t1 in itvs:
                if uniao and t0 <= uniao[-1][1] + 0.003:
                    uniao[-1][1] = max(uniao[-1][1], t1)
                else:
                    uniao.append([t0, t1])
            for t0, t1 in uniao:
                caminhos[fase].append(([O[k] + D[k] * t0, O[k] + D[k] * t1], False))
    return caminhos


def tracejar(pts, fechada):
    pts = [np.array(p, float) for p in pts]
    if fechada:
        pts = pts + [pts[0]]
    seg = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(pts) - 1)]
    acum = np.concatenate([[0.0], np.cumsum(seg)])
    L = float(acum[-1])
    if L < 0.03:
        return []
    if fechada:
        n = max(3, round(L / (TRACO + VAO)))
        t = L / n - VAO
        tracos = [(i * (t + VAO), i * (t + VAO) + t) for i in range(n)]
    else:
        n = max(1, round((L + VAO) / (TRACO + VAO)))
        t = (L - (n - 1) * VAO) / n
        while n > 1 and t < 0.05:
            n -= 1
            t = (L - (n - 1) * VAO) / n
        tracos = [(i * (t + VAO), i * (t + VAO) + t) for i in range(n)] if n > 1 else [(0.0, L)]

    def ponto(s):
        i = int(np.searchsorted(acum, s, side='right') - 1)
        i = min(max(i, 0), len(seg) - 1)
        u = (s - acum[i]) / seg[i] if seg[i] > 0 else 0.0
        return pts[i] + (pts[i + 1] - pts[i]) * u, i

    pedacos = []
    for s0, s1 in tracos:
        p0, i0 = ponto(s0)
        p1, i1 = ponto(s1)
        cadeia = [p0] + [pts[j] for j in range(i0 + 1, i1 + 1)] + [p1]
        for q0, q1 in zip(cadeia[:-1], cadeia[1:]):
            if np.linalg.norm(q1 - q0) > 1e-4:
                pedacos.append((q0, q1))
    return pedacos


def caixinha(m, a, b, lado=LADO):
    """Um traço: prisma fino de seção triangular (3 faces, 6 triângulos), sem
    tampas. Visto de qualquer lado tem de 0,87 a 1 x ``lado`` de largura."""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
    u = d.cross(ref).normalized()
    v = d.cross(u).normalized()
    raio = lado / math.sqrt(3)
    offs = [(u * math.cos(t) + v * math.sin(t)) * raio for t in (math.pi / 2, math.pi * 7 / 6, math.pi * 11 / 6)]
    vs = [a + o for o in offs] + [b + o for o in offs]
    fs = [(0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    nn = (vs[1] - vs[0]).cross(vs[4] - vs[1])
    if nn.dot((vs[0] + vs[1]) / 2 - a) < 0:
        fs = [tuple(reversed(f)) for f in fs]
    m.add(vs, fs, 'fantasma', suave=True)


def fantasmas(c, raiz):
    caminhos = consolidar(c.fantasmas, tol=TOL_DESENHO)
    for fase, lista in c.curvas.items():
        caminhos[fase].extend(lista)
    for i in range(len(FASES)):
        nome = 'fantasma_fase_%02d' % i
        m = Malha(nome)
        for pts, fechada in caminhos.get(i, []):
            for a, b in tracejar(pts, fechada):
                caixinha(m, a, b)
        o = c.objeto(m, raiz, normais=False)
        if o is None:
            # fase sem desenho (reboco, pintura): o nó existe, vazio, para o
            # app achar os 10 fantasmas pelo nome
            o = c.vazio(nome, raiz)
        o['fase'] = i
        c.objs_fantasma[i] = o


# ================================================================ exportação
def contar(c):
    dg = bpy.context.evaluated_depsgraph_get()
    tri = {}
    for o in c.col.objects:
        if o.type != 'MESH':
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        tri[o.name] = (len(me.loop_triangles), len(me.materials))
        ev.to_mesh_clear()
    return tri


def exportar(c, caminho):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in c.col.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = c.raiz
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=caminho, export_format='GLB', use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=False, export_normals=True, export_tangents=False,
        export_materials='EXPORT', export_vertex_color='MATERIAL',
        export_all_vertex_colors=False, export_active_vertex_color_when_no_material=False,
        export_extras=True, export_cameras=False, export_lights=False, export_animations=False,
        export_skins=False, export_morph=False, export_draco_mesh_compression_enable=False,
        export_meshopt_compression_enable=False, export_copyright='ObraFácil: modelo procedural, sem assets de terceiros')


def ancoras_cotas(c):
    """Centro de cada número de cota, no protótipo e em pixels da imagem de
    reserva (1080x720, origem no canto de cima à esquerda). Os números estão no
    glb e nas imagens; as âncoras servem para o app pôr um rótulo legível."""
    from bpy_extras.object_utils import world_to_camera_view
    sc = c.scene
    out = []
    for texto, (x, y, z) in c.cotas_info:
        q = world_to_camera_view(sc, sc.camera, P(x, y, z))
        out.append({'texto': texto, 'centro': [round(x, 3), round(y, 4), round(z, 3)],
                    'pixel_reserva': [round(q.x * 1080, 1), round((1 - q.y) * 720, 1)]})
    return out


def manifesto(c, tri, caminho, glb, camera, ancoras=None):
    def subarvore(o):
        lst = [o.name]
        for ch in o.children:
            lst += subarvore(ch)
        return lst
    fases = []
    for i, (no, nome, fim) in enumerate(FASES):
        obj = bpy.data.objects[no]
        filhos = [ch.name for ch in obj.children]
        t = sum(tri.get(n, (0, 0))[0] for n in subarvore(obj))
        dc = sum(tri.get(n, (0, 0))[1] for n in subarvore(obj))
        f = c.objs_fantasma.get(i)
        fases.append({'indice': i, 'no': no, 'nome': nome, 'progresso_fim': fim, 'filhos': filhos,
                      'fantasma': f.name if f else None, 'triangulos': t, 'chamadas_de_desenho': dc,
                      'triangulos_fantasma': tri.get(f.name, (0, 0))[0] if f else 0})
    dados = {
        'arquivo': os.path.basename(glb),
        'unidade': 'metro', 'eixo_vertical': '+Y',
        'origem': 'centro do tabuleiro, no nível do terreno (topo do tabuleiro); o tabuleiro vai de y=-0,30 a 0',
        'frente': '+Z (rua)',
        'raiz': 'maquete', 'fixos': ['base', 'cotas'],
        'fases': fases,
        'fiadas_alvenaria': ['alvenaria_fiada_%02d' % k for k in range(N_FIADAS + 3)],
        'fiadas_platibanda': ['alvenaria_fiada_%02d' % k for k in range(N_FIADAS, N_FIADAS + 3)],
        'pivos': c.pivos,
        'materiais_de_tema': {k: {t: TEMAS[t][k] for t in TEMAS} for k in
                              ('base', 'grade', 'grade_forte', 'cota', 'fantasma')},
        'fantasma_opacidade': dict(OPACIDADE_FANTASMA),
        'fantasma_opaco': {t: fantasma_opaco(t) for t in TEMAS},
        'fantasma_nota': ('material OPAQUE e doubleSided; para o app, usar a cor fantasma_opaco (a cor do '
                          'fantasma com a opacidade das imagens, já misturada à base do tema em luz linear) '
                          'em vez de alfa, que mancharia as 3 faces de cada traço'),
        'fundo': {t: TEMAS[t]['fundo'] for t in TEMAS},
        'camera_padrao': {'alvo': [0, 1.1, 0], 'azimute_rad': CAM_AZIMUTE, 'elevacao_rad': CAM_ELEVACAO,
                          'fov_vertical_graus': 27.0, 'nota': 'câmera do protótipo web'},
        'camera_reserva': camera,
        'cotas': ancoras or [],
        'reserva': {
            'pastas': {t: 'reserva/%s' % t for t in TEMAS},
            'estados': {'estado_%02d.webp' % s: (
                'só a base; tudo em fantasma' if s == 0 else
                'obra pronta (etapa "%s" concluída); sem fantasma' % FASES[s - 1][1] if s == len(FASES) else
                'etapa "%s" concluída; fases seguintes em fantasma' % FASES[s - 1][1])
                for s in range(len(FASES) + 1)},
            'regra': 'estado N = fases 0..N-1 visíveis, fantasmas N..9 visíveis',
        },
        'triangulos_total': sum(v[0] for v in tri.values()),
    }
    with open(caminho, 'w', encoding='utf-8') as fp:
        json.dump(dados, fp, ensure_ascii=False, indent=2)
    return dados


# ================================================================ render
def preparar_render(c, args):
    sc = c.scene
    sc.render.engine = 'CYCLES'
    cy = sc.cycles
    cy.device = 'CPU'
    cy.samples = args.amostras
    cy.use_adaptive_sampling = True
    cy.adaptive_threshold = 0.01
    cy.use_denoising = True
    try:
        cy.denoiser = 'OPENIMAGEDENOISE'
        cy.denoising_input_passes = 'RGB_ALBEDO_NORMAL'
        cy.denoising_prefilter = 'ACCURATE'
    except Exception as e:  # pragma: no cover
        print('[maquete] aviso: OIDN indisponível:', e)
    cy.max_bounces = 8
    cy.diffuse_bounces = 3
    cy.glossy_bounces = 3
    cy.transmission_bounces = 6
    cy.transparent_max_bounces = 16
    cy.caustics_reflective = False
    cy.caustics_refractive = False
    cy.sample_clamp_indirect = 4.0
    sc.render.threads_mode = 'AUTO'
    sc.render.film_transparent = True
    sc.render.filter_size = 1.2
    w, h = (540, 360) if args.rapido else (1080, 720)
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = 'Khronos PBR Neutral'
    sc.view_settings.look = 'None'
    sc.view_settings.exposure = args.exposicao
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    sc.render.dither_intensity = 1.0

    # Luz de janela vinda da esquerda (sol grande e macio) + céu neutro.
    luz = bpy.data.lights.new('janela', 'SUN')
    luz.energy = args.sol
    luz.angle = math.radians(14)
    luz.color = (1.0, 0.975, 0.945)
    sol = bpy.data.objects.new('janela', luz)
    sc.collection.objects.link(sol)
    dirl = P(-10, 10, 8).normalized()
    sol.rotation_euler = (-dirl).to_track_quat('-Z', 'Y').to_euler()

    mundo = bpy.data.worlds.new('ambiente')
    sc.world = mundo
    nt = mundo.node_tree
    nodes, links = nt.nodes, nt.links
    for n in list(nodes):
        nodes.remove(n)
    out = nodes.new('ShaderNodeOutputWorld')
    bg = nodes.new('ShaderNodeBackground')
    tc = nodes.new('ShaderNodeTexCoord')
    sep = nodes.new('ShaderNodeSeparateXYZ')
    mr = nodes.new('ShaderNodeMapRange')
    ramp = nodes.new('ShaderNodeValToRGB')
    links.new(tc.outputs['Generated'], sep.inputs[0])
    links.new(sep.outputs['Z'], mr.inputs['Value'])
    mr.inputs['From Min'].default_value = -1.0
    mr.inputs['From Max'].default_value = 1.0
    links.new(mr.outputs['Result'], ramp.inputs['Fac'])
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (0.20, 0.20, 0.20, 1)
    els[1].position, els[1].color = 1.0, (1.0, 1.0, 1.0, 1)
    e = els.new(0.5)
    e.color = (0.80, 0.81, 0.82, 1)
    links.new(ramp.outputs['Color'], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = args.ceu
    links.new(bg.outputs['Background'], out.inputs['Surface'])

    # Chão que só recebe sombra, logo abaixo do tabuleiro.
    mc = Malha('chao_sombra')
    quad_horizontal(mc, -40, 40, -40, 40, -0.3, 'base')
    me = bpy.data.meshes.new('chao_sombra')
    me.from_pydata([tuple(v) for v in mc.v], [], mc.f)
    chao = bpy.data.objects.new('chao_sombra', me)
    sc.collection.objects.link(chao)
    chao.is_shadow_catcher = True

    # Fantasma: só a câmera vê (não faz sombra nem reflexo).
    for o in c.objs_fantasma.values():
        if o.type != 'MESH':
            continue
        o.visible_shadow = False
        o.visible_diffuse = False
        o.visible_glossy = False
        o.visible_transmission = False
        o.visible_volume_scatter = False

    return sc.camera


def criar_camera(c):
    """Câmera 3/4 do alto, lente 50 mm em 36 mm (FOV vertical ~27°), como no
    protótipo, afastada até o tabuleiro inteiro caber em 1080x720 com margem."""
    sc = c.scene
    sc.render.resolution_x, sc.render.resolution_y = 1080, 720
    cam_d = bpy.data.cameras.new('camera')
    cam_d.lens = 50
    cam_d.sensor_fit = 'HORIZONTAL'
    cam_d.sensor_width = 36
    cam = bpy.data.objects.new('camera', cam_d)
    sc.collection.objects.link(cam)   # fora da coleção exportada
    sc.camera = cam
    alvo, dist = enquadrar(c, cam)
    pos = cam.location
    para_proto = lambda v: [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]
    return {'posicao': para_proto(pos), 'alvo': para_proto(alvo), 'distancia_m': round(dist, 3),
            'lente_mm_equivalente': 50, 'fov_vertical_graus': round(math.degrees(cam_d.angle_y), 2),
            'resolucao': [1080, 720]}


def enquadrar(c, cam):
    sc = c.scene
    from bpy_extras.object_utils import world_to_camera_view
    pts = []
    for x in (-7, 7):
        for z in (-6, 6):
            for y in (-0.3, 0.0):
                pts.append(P(x, y, z))
    pts += [P(CX_X, Y_CX + 0.93, CX_Z), P(-4.74, 3.78, -3.74), P(4.74, 3.78, -3.74),
            P(POSTE_X, 2.95, POSTE_Z)]
    alvo = P(0, 1.1, 0)
    dirc = P(math.sin(CAM_AZIMUTE) * math.cos(CAM_ELEVACAO), math.sin(CAM_ELEVACAO),
             math.cos(CAM_AZIMUTE) * math.cos(CAM_ELEVACAO)).normalized()
    margem = 0.06
    for _ in range(4):
        dist_lo, dist_hi = 10.0, 80.0
        for _ in range(40):
            dist = (dist_lo + dist_hi) / 2
            cam.location = alvo + dirc * dist
            cam.rotation_euler = (alvo - cam.location).to_track_quat('-Z', 'Y').to_euler()
            bpy.context.view_layer.update()
            cs = [world_to_camera_view(sc, cam, p) for p in pts]
            ok = all(margem <= q.x <= 1 - margem and margem <= q.y <= 1 - margem for q in cs)
            if ok:
                dist_hi = dist
            else:
                dist_lo = dist
        cam.location = alvo + dirc * dist_hi
        cam.rotation_euler = (alvo - cam.location).to_track_quat('-Z', 'Y').to_euler()
        bpy.context.view_layer.update()
        alvo_usado = alvo.copy()
        cs = [world_to_camera_view(sc, cam, p) for p in pts]
        # recentra verticalmente: desloca o alvo até as margens de cima e de baixo se igualarem
        ymin, ymax = min(q.y for q in cs), max(q.y for q in cs)
        xmin, xmax = min(q.x for q in cs), max(q.x for q in cs)
        desloc_y = ((ymin + ymax) / 2 - 0.5)
        desloc_x = ((xmin + xmax) / 2 - 0.5)
        cam_m = cam.matrix_world.to_3x3()
        altura = 2 * dist_hi * math.tan(cam.data.angle_y / 2)
        largura = 2 * dist_hi * math.tan(cam.data.angle_x / 2)
        alvo = alvo + cam_m @ Vector((desloc_x * largura, desloc_y * altura, 0))
    print('[maquete] câmera: distância %.2f m, alvo %s' % (dist_hi, tuple(round(v, 3) for v in alvo_usado)))
    return alvo_usado, dist_hi


def aplicar_tema(c, tema):
    for k in ('base', 'grade', 'grade_forte', 'cota', 'fantasma'):
        c.cor_material(k, TEMAS[tema][k])
    # fantasma com opacidade de lápis na imagem de reserva
    m = c.mats['fantasma']
    nt = m.node_tree
    if 'transp' not in nt.nodes:
        rgb = nt.nodes['cor']
        out = nt.nodes['Material Output']
        tr = nt.nodes.new('ShaderNodeBsdfTransparent')
        tr.name = 'transp'
        em = nt.nodes.new('ShaderNodeEmission')
        em.name = 'emissao'
        mix = nt.nodes.new('ShaderNodeMixShader')
        mix.name = 'mistura'
        nt.links.new(rgb.outputs[0], em.inputs['Color'])
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs['Surface'])
    nt.nodes['mistura'].inputs['Fac'].default_value = OPACIDADE_FANTASMA[tema]
    # Vidro de verdade na imagem de reserva (no glb ele é translúcido por alfa,
    # que é o que o app desenha barato).
    b = c.mats['vidro'].node_tree.nodes['Principled BSDF']
    b.inputs['Alpha'].default_value = 1.0
    b.inputs['Transmission Weight'].default_value = 1.0
    b.inputs['Base Color'].default_value = (0.86, 0.92, 0.95, 1.0)
    b.inputs['Roughness'].default_value = 0.02
    b.inputs['IOR'].default_value = 1.5


def mostrar_estado(c, estado):
    for i in range(len(FASES)):
        for o in c.objs_fase[i]:
            o.hide_render = not (i < estado)
        f = c.objs_fantasma.get(i)
        if f is not None:
            f.hide_render = not (i >= estado)


def compor(png, fundo_hex):
    from PIL import Image
    im = np.asarray(Image.open(png).convert('RGBA'), dtype=np.float64) / 255.0
    rgb, a = im[..., :3], im[..., 3:4]

    def para_lin(x):
        return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)

    def para_srgb(x):
        x = np.clip(x, 0, 1)
        return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055)

    fundo = np.array(lin(fundo_hex))[None, None, :]
    out = para_lin(rgb) * a + fundo * (1 - a)
    out = para_srgb(out)
    ruido = (np.random.default_rng(7).random(out.shape) - 0.5) / 255.0
    return Image.fromarray(np.clip((out + ruido) * 255 + 0.5, 0, 255).astype(np.uint8), 'RGB')


def renderizar(c, args, saida):
    preparar_render(c, args)
    sc = c.scene
    tmp = args.tmp
    os.makedirs(tmp, exist_ok=True)
    tempos = {}
    estados = [int(s) for s in args.estados.split(',')] if args.estados else list(range(len(FASES) + 1))
    temas = args.temas.split(',')
    for tema in temas:
        aplicar_tema(c, tema)
        pasta = os.path.join(saida, 'reserva', tema)
        os.makedirs(pasta, exist_ok=True)
        for s in estados:
            mostrar_estado(c, s)
            png = os.path.join(tmp, '%s_%02d.png' % (tema, s))
            sc.render.filepath = png
            t0 = time.time()
            bpy.ops.render.render(write_still=True)
            dt = time.time() - t0
            tempos['%s/%02d' % (tema, s)] = round(dt, 1)
            img = compor(png, TEMAS[tema]['fundo'])
            img.save(os.path.join(tmp, '%s_%02d_rgb.png' % (tema, s)))
            img.save(os.path.join(pasta, 'estado_%02d.webp' % s), 'WEBP', quality=args.qualidade, method=6)
            print('[maquete] %s estado %02d: %.1f s' % (tema, s, dt), flush=True)
    return tempos


def folha_contato(args, caminho):
    from PIL import Image, ImageDraw, ImageFont
    temas = args.temas.split(',')
    estados = [int(s) for s in args.estados.split(',')] if args.estados else list(range(len(FASES) + 1))
    w, h = 360, 240
    cols = (len(estados) + 1) // 2 if len(estados) > 6 else len(estados)
    rows_t = 2 if len(estados) > 6 else 1
    folha = Image.new('RGB', (cols * w, rows_t * len(temas) * (h + 18)), (128, 128, 128))
    try:
        fonte = ImageFont.truetype(FONTE_COTAS, 14)
    except Exception:
        fonte = ImageFont.load_default()
    d = ImageDraw.Draw(folha)
    for ti, tema in enumerate(temas):
        for k, s in enumerate(estados):
            p = os.path.join(args.tmp, '%s_%02d_rgb.png' % (tema, s))
            if not os.path.exists(p):
                continue
            im = Image.open(p).resize((w, h), Image.LANCZOS)
            col, row = k % cols, ti * rows_t + k // cols
            folha.paste(im, (col * w, row * (h + 18) + 18))
            rot = '%s %02d  %s' % (tema, s, 'só a base' if s == 0 else 'pronto até: ' + FASES[s - 1][1])
            d.text((col * w + 4, row * (h + 18) + 2), rot, fill=(255, 255, 255), font=fonte)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    folha.save(caminho)


# ================================================================ main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--saida', default=SAIDA_PADRAO, help='pasta de saída (assets/3d)')
    ap.add_argument('--tmp', default=os.path.join(tempfile.gettempdir(), 'maquete_render'),
                    help='pasta dos PNG intermediários')
    ap.add_argument('--sem-render', action='store_true', help='só gera o glb e o manifesto')
    ap.add_argument('--sem-glb', action='store_true', help='não reexporta o glb')
    ap.add_argument('--rapido', action='store_true', help='render de teste (540x360)')
    ap.add_argument('--amostras', type=int, default=96)
    ap.add_argument('--qualidade', type=int, default=85, help='qualidade WebP')
    ap.add_argument('--estados', default='', help='ex.: 0,5,10 (padrão: 0 a 10)')
    ap.add_argument('--temas', default='claro,escuro')
    ap.add_argument('--sol', type=float, default=4.6, help='irradiância da luz de janela (W/m²)')
    ap.add_argument('--ceu', type=float, default=0.75, help='intensidade do ambiente')
    ap.add_argument('--exposicao', type=float, default=0.0)
    ap.add_argument('--folha', default='', help='caminho da folha de contato (PNG)')
    ap.add_argument('--blend', default='', help='salva também o .blend (depuração)')
    args = ap.parse_args()

    t0 = time.time()
    c = Cena()
    construir(c)
    camera = criar_camera(c)
    tri = contar(c)
    glb = os.path.join(args.saida, 'maquete.glb')
    if not args.sem_glb:
        exportar(c, glb)
        dados = manifesto(c, tri, os.path.join(args.saida, 'maquete.json'), glb, camera, ancoras_cotas(c))
        print('[maquete] glb: %s (%.2f MB), %d triângulos' % (glb, os.path.getsize(glb) / 1e6,
                                                             dados['triangulos_total']))
        for f in dados['fases']:
            print('   %-24s %6d tri  %2d chamadas  fantasma %5d tri' % (
                f['no'], f['triangulos'], f['chamadas_de_desenho'], f['triangulos_fantasma']))
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if not args.sem_render:
        tempos = renderizar(c, args, args.saida)
        if args.folha:
            folha_contato(args, args.folha)
        with open(os.path.join(args.tmp, 'tempos.json'), 'w') as fp:
            json.dump(tempos, fp, indent=1)
        print('[maquete] tempos de render (s):', json.dumps(tempos))
    print('[maquete] total %.1f s' % (time.time() - t0))


if __name__ == '__main__':
    main()
