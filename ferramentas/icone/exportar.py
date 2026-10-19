"""Exporta o ícone do ObraFácil (planta baixa) para obra_facil/assets/icone/.

Fontes: planta.svg (quadro de 108 dp) e notificacao.svg (grade de 24 dp),
nesta pasta. O Chromium do Playwright rasteriza cada PNG já no tamanho final
(renderizar.js); aqui só se trocam as cores, se tira o alfa do icon.png e se
"sangra" a cor nos pixels transparentes (ver sangrar()). No fim, confere
tamanhos, modos, círculo de segurança e cores, e para com erro se algo falhar.

    python3 ferramentas/icone/exportar.py [--saida PASTA] [--tmp PASTA]

Precisa de Node, Playwright com Chromium (ver LEIA-ME.md), Pillow e numpy.
"""
import argparse
import json
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parents[1]
SAIDA_PADRAO = RAIZ / "obra_facil" / "assets" / "icone"
SVG_NS = "http://www.w3.org/2000/svg"

# Tokens do design system (docs/redesign/design-system.md, seção 2).
PAPEL = "#F4F5F3"
PAPEL_ESCURO = "#121315"
GRAFITE = "#1A1C1F"
GRAFITE_ESCURO = "#ECEDE9"
MARCA = "#F97316"  # o laranja da marca fica igual no claro e no escuro
BRANCO = "#FFFFFF"

CLARO = {"construido": MARCA, "falta": GRAFITE, "porta": GRAFITE}
# "Mesa de luz": o mesmo desenho para a splash escura (traço claro, laranja igual).
ESCURO = {"construido": MARCA, "falta": GRAFITE_ESCURO, "porta": GRAFITE_ESCURO}
MONO = {"construido": BRANCO, "falta": BRANCO, "porta": BRANCO}

# Camada da frente e monocromática: 1296 = 12 px/dp. O flutter_launcher_icons
# reduz para 108/162/216/324/432 px com média em janelas inteiras; com 1296
# o fator é inteiro em todas as densidades (12/8/6/4/3) e as arestas da grade
# de 3 dp caem em pixel inteiro (só a hdpi, 1,5x, tem meio pixel). Com 1024 o
# fator é quebrado e as arestas borram (medido no pacote: 9 a 10 vezes mais
# pixels de meio-tom em xhdpi, xxhdpi e xxxhdpi).
LADO_FRENTE = 1296
LADO_ICONE = 1024  # icon.png: ícone legado (Android 7) e arte da loja (512 = 1/2)
LADO_SPLASH = 1152  # splash: 288 dp em xxxhdpi, o tamanho do ícone da splash do Android 12+
DENSIDADES_NOTIFICACAO = {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}
NOME_NOTIFICACAO = "ic_stat_obrafacil.png"

RAIO_SEGURO_DP = 33.0  # círculo de 66 dp no quadro de 108
RAIO_SPLASH_PX = 384.0  # círculo de 768 px na imagem de 1152 (Android 12+)


def variante(fonte, destino, cores, lado, viewbox=None, fundo=None):
    """Copia o SVG trocando o fill de cada id, o viewBox e o tamanho."""
    ET.register_namespace("", SVG_NS)
    arvore = ET.parse(fonte)
    raiz = arvore.getroot()
    for el in raiz.iter():
        if el.get("id") in cores:
            el.set("fill", cores[el.get("id")])
    if viewbox:
        raiz.set("viewBox", viewbox)
    raiz.set("width", str(lado))
    raiz.set("height", str(lado))
    if fundo:
        x, y, w, h = raiz.get("viewBox").split()
        rect = ET.Element(f"{{{SVG_NS}}}rect", x=x, y=y, width=w, height=h, fill=fundo)
        raiz.insert(1, rect)  # logo depois do <title>, embaixo de tudo
    arvore.write(destino, encoding="utf-8", xml_declaration=False)
    return destino


def renderizar(tarefas, tmp):
    arquivo = tmp / "tarefas.json"
    arquivo.write_text(json.dumps(tarefas))
    subprocess.run(["node", str(AQUI / "renderizar.js"), str(arquivo)], check=True)


def sangrar(rgba, passos=16):
    """Pinta os pixels 100% transparentes com a cor do vizinho mais próximo.

    O flutter_launcher_icons e o flutter_native_splash reduzem a imagem com
    média simples, sem pré-multiplicar o alfa. Um pixel transparente sai do
    Chromium com RGB preto, e a média com ele escurece a borda do laranja
    (franja marrom). Com a cor espalhada até 16 px (mais que a maior janela
    da redução, 12 px), a média dá a cor certa com o alfa certo.
    """
    out = rgba.copy()
    conhecido = rgba[..., 3] > 0
    vizinhos = [(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx]
    for _ in range(passos):
        if conhecido.all():
            break
        for dy, dx in vizinhos:
            viz = np.roll(out, (dy, dx), (0, 1))
            novo = ~conhecido & np.roll(conhecido, (dy, dx), (0, 1))
            out[novo, :3] = viz[novo, :3]
            conhecido |= novo
    return out


def cor_rgb(hexa):
    return [int(hexa[i:i + 2], 16) for i in (1, 3, 5)]


def salvar(rgba, caminho, modo="RGBA"):
    caminho.parent.mkdir(parents=True, exist_ok=True)
    im = Image.fromarray(rgba, "RGBA")
    if modo == "RGB":
        im = im.convert("RGB")
    im.save(caminho, optimize=True)


def raio_max(alfa, centro):
    ys, xs = np.nonzero(alfa > 0)
    return float(np.sqrt((xs + 0.5 - centro) ** 2 + (ys + 0.5 - centro) ** 2).max())


def contraste(a, b):
    def lum(h):
        c = [v / 255 for v in cor_rgb(h)]
        c = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c]
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--saida", type=Path, default=SAIDA_PADRAO)
    ap.add_argument("--tmp", type=Path, default=None, help="pasta dos SVGs e PNGs intermediários")
    args = ap.parse_args()
    tmp = args.tmp or Path(tempfile.mkdtemp(prefix="icone_"))
    tmp.mkdir(parents=True, exist_ok=True)
    saida = args.saida
    planta = AQUI / "planta.svg"
    notif = AQUI / "notificacao.svg"

    svgs = {
        "icon": variante(planta, tmp / "icon.svg", CLARO, LADO_ICONE, viewbox="18 18 72 72", fundo=PAPEL),
        "icon_foreground": variante(planta, tmp / "icon_foreground.svg", CLARO, LADO_FRENTE),
        "icon_monochrome": variante(planta, tmp / "icon_monochrome.svg", MONO, LADO_FRENTE),
        "splash": variante(planta, tmp / "splash.svg", CLARO, LADO_SPLASH),
        "splash_escuro": variante(planta, tmp / "splash_escuro.svg", ESCURO, LADO_SPLASH),
    }
    lados = {"icon": LADO_ICONE, "icon_foreground": LADO_FRENTE, "icon_monochrome": LADO_FRENTE,
             "splash": LADO_SPLASH, "splash_escuro": LADO_SPLASH}
    tarefas = [dict(svg=str(svgs[k]), png=str(tmp / f"{k}.png"), lado=lados[k]) for k in svgs]
    for dens, lado in DENSIDADES_NOTIFICACAO.items():
        tarefas.append(dict(svg=str(notif), png=str(tmp / f"notif_{dens}.png"), lado=lado))
    renderizar(tarefas, tmp)

    def ler(nome):
        return np.asarray(Image.open(tmp / nome).convert("RGBA")).copy()

    erros = []

    # icon.png: opaco, sem canal alfa (pedido do iOS e da Play Store)
    icone = ler("icon.png")
    if icone[..., 3].min() != 255:
        erros.append("icon.png tem pixel transparente")
    salvar(icone, saida / "icon.png", "RGB")

    frente = sangrar(ler("icon_foreground.png"))
    salvar(frente, saida / "icon_foreground.png")

    mono = ler("icon_monochrome.png")
    mono[..., :3] = cor_rgb(BRANCO)  # o sistema usa só o alfa; RGB constante
    salvar(mono, saida / "icon_monochrome.png")

    for nome in ("splash", "splash_escuro"):
        salvar(sangrar(ler(f"{nome}.png")), saida / f"{nome}.png")

    for dens in DENSIDADES_NOTIFICACAO:
        n = ler(f"notif_{dens}.png")
        n[..., :3] = cor_rgb(BRANCO)
        salvar(n, saida / "notificacao" / f"drawable-{dens}" / NOME_NOTIFICACAO)

    # ---- conferência
    px_dp = LADO_FRENTE / 108
    r_frente = raio_max(frente[..., 3], LADO_FRENTE / 2) / px_dp
    r_mono = raio_max(mono[..., 3], LADO_FRENTE / 2) / px_dp
    print(f"camada da frente: raio máximo {r_frente:.2f} dp (limite {RAIO_SEGURO_DP})")
    print(f"monocromática:    raio máximo {r_mono:.2f} dp")
    if max(r_frente, r_mono) > RAIO_SEGURO_DP:
        erros.append("desenho fora do círculo de segurança de 66 dp")
    dif = np.abs(frente[..., 3].astype(int) - mono[..., 3].astype(int)).max()
    print(f"alfa monocromática x frente: diferença máxima {dif}/255")
    if dif > 2:
        erros.append("a monocromática não tem a mesma geometria da camada da frente")
    for nome in ("splash", "splash_escuro"):
        s = np.asarray(Image.open(saida / f"{nome}.png").convert("RGBA"))
        r = raio_max(s[..., 3], LADO_SPLASH / 2)
        print(f"{nome}: raio máximo {r:.0f} px (limite {RAIO_SPLASH_PX:.0f})")
        if r > RAIO_SPLASH_PX:
            erros.append(f"{nome} sai do círculo de 768 px do Android 12+")
    for dens, lado in DENSIDADES_NOTIFICACAO.items():
        im = Image.open(saida / "notificacao" / f"drawable-{dens}" / NOME_NOTIFICACAO)
        if im.size != (lado, lado) or im.mode != "RGBA":
            erros.append(f"notificação {dens}: {im.size} {im.mode}")
    for nome, lado, modo in (("icon.png", LADO_ICONE, "RGB"), ("icon_foreground.png", LADO_FRENTE, "RGBA"),
                             ("icon_monochrome.png", LADO_FRENTE, "RGBA"), ("splash.png", LADO_SPLASH, "RGBA"),
                             ("splash_escuro.png", LADO_SPLASH, "RGBA")):
        im = Image.open(saida / nome)
        print(f"{nome}: {im.size[0]}x{im.size[1]} {im.mode}")
        if im.size != (lado, lado) or im.mode != modo:
            erros.append(f"{nome}: esperado {lado}x{lado} {modo}")
    for a, b, uso in ((GRAFITE, PAPEL, "traço sobre papel"), (MARCA, PAPEL, "laranja sobre papel"),
                      (GRAFITE_ESCURO, PAPEL_ESCURO, "traço claro na splash escura"),
                      (MARCA, PAPEL_ESCURO, "laranja na splash escura")):
        print(f"contraste {uso}: {contraste(a, b):.2f}:1")

    if erros:
        print("\nERROS:\n- " + "\n- ".join(erros), file=sys.stderr)
        sys.exit(1)
    print(f"\nok: PNGs em {saida} (intermediários em {tmp})")


if __name__ == "__main__":
    main()
