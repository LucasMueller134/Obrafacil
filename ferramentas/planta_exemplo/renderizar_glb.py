"""Renderiza no Blender (Cycles) um glb gerado pelo app a partir da planta,
em alguns estágios da obra, com a luz e a câmera das imagens de reserva.

Serve para conferir a maquete gerada fora do aparelho e para fazer as
imagens de reserva da obra de exemplo.

    .venv-maquete/bin/python ferramentas/planta_exemplo/renderizar_glb.py \
        casa.glb saida/ --estados 0,3,6,10 --amostras 48 [--rapido] [--escuro]

Estado N = as N primeiras fases prontas e o resto tracejado (como as
imagens estado_NN da maquete-padrão).
"""

import argparse
import math
import os

import bpy
from mathutils import Vector

FASES = [
    'fase_00_fundacao', 'fase_01_estrutura', 'fase_02_alvenaria',
    'fase_03_cobertura', 'fase_04_eletrica', 'fase_05_hidraulica',
    'fase_06_reboco', 'fase_07_revestimentos', 'fase_08_pintura',
    'fase_09_acabamento',
]


def args():
    a = argparse.ArgumentParser()
    a.add_argument('glb')
    a.add_argument('saida')
    a.add_argument('--estados', default='0,3,6,10')
    a.add_argument('--amostras', type=int, default=48)
    a.add_argument('--rapido', action='store_true')
    a.add_argument('--escuro', action='store_true')
    a.add_argument('--azimute', type=float, default=0.62)
    a.add_argument('--elevacao', type=float, default=0.62)
    return a.parse_args()


def cena(a):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.glb)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = a.amostras
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    w, h = (720, 480) if a.rapido else (1080, 720)
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.view_settings.view_transform = 'Khronos PBR Neutral'
    luz = bpy.data.lights.new('janela', 'SUN')
    luz.energy = 3.2
    luz.angle = math.radians(14)
    luz.color = (1.0, 0.975, 0.945)
    sol = bpy.data.objects.new('janela', luz)
    sc.collection.objects.link(sol)
    dirl = Vector((-10, 10, 8)).normalized()  # Blender: Z para cima
    sol.rotation_euler = (-dirl).to_track_quat('-Z', 'Y').to_euler()
    mundo = bpy.data.worlds.new('ambiente')
    mundo.use_nodes = True
    mundo.node_tree.nodes['Background'].inputs['Color'].default_value = (0.8, 0.81, 0.82, 1)
    mundo.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.9
    sc.world = mundo
    # Fantasma: só a câmera vê.
    for o in bpy.data.objects:
        if o.name.startswith('fantasma_fase_'):
            o.visible_shadow = False
            o.visible_diffuse = False
            o.visible_glossy = False
    return sc


def enquadrar(sc, a):
    pontos = []
    for o in bpy.data.objects:
        if o.type == 'MESH':
            pontos += [o.matrix_world @ Vector(v) for v in o.bound_box]
    mn = Vector([min(p[i] for p in pontos) for i in range(3)])
    mx = Vector([max(p[i] for p in pontos) for i in range(3)])
    alvo = (mn + mx) / 2
    raio = (mx - mn).length / 2
    cam = bpy.data.cameras.new('camera')
    cam.lens = 50
    obj = bpy.data.objects.new('camera', cam)
    sc.collection.objects.link(obj)
    fov = cam.angle_y if cam.sensor_fit != 'VERTICAL' else cam.angle
    dist = raio / math.sin(min(cam.angle_x, cam.angle_y) / 2) * 0.82
    # glTF +Z (frente) vira -Y no Blender.
    d = Vector((math.sin(a.azimute) * math.cos(a.elevacao),
                -math.cos(a.azimute) * math.cos(a.elevacao),
                math.sin(a.elevacao)))
    obj.location = alvo + d * dist
    obj.rotation_euler = (alvo - obj.location).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = obj


def mostrar(estado):
    for i, nome in enumerate(FASES):
        o = bpy.data.objects.get(nome)
        pronta = i < estado
        for filho in ([o] + list(o.children_recursive)) if o else []:
            filho.hide_render = not pronta
        g = bpy.data.objects.get(f'fantasma_fase_{i:02d}')
        if g:
            g.hide_render = pronta


def main():
    a = args()
    sc = cena(a)
    enquadrar(sc, a)
    os.makedirs(a.saida, exist_ok=True)
    for e in [int(x) for x in a.estados.split(',')]:
        mostrar(e)
        sc.render.filepath = os.path.join(a.saida, f'estado_{e:02d}.png')
        bpy.ops.render.render(write_still=True)
        print('[render] estado', e, '->', sc.render.filepath)


main()
