"""Gera as notas fiscais de TESTE do Obra na Mão (para testar a leitura da nota).

São documentos de teste, de lojas fictícias, com o aviso que a SEFAZ manda
imprimir nas notas de homologação ("EMITIDA EM AMBIENTE DE HOMOLOGAÇÃO - SEM
VALOR FISCAL"). O CNPJ é o de exemplo (11.222.333/0001-81), a chave de acesso
tem o DV certo e o ambiente 2 (homologação), e o QR aponta para a consulta de
homologação: nenhuma nota de verdade é imitada.

Saídas (na pasta dada):
  nfce_teste.png / .pdf      cupom NFC-e de 80 mm (QR Code, desconto, PIX)
  danfe_teste.png / .pdf     DANFE da NF-e em A4 (código de barras, frete,
                             emissão e saída em dias diferentes)
  nfce_teste_foto.jpg        o cupom "fotografado": inclinado, com sombra
  casos_ocr.json             as duas notas como casos da avaliação (cada linha
                             com a caixa, como o ML Kit devolve, e o esperado)

    python gerar_notas.py SAIDA
Precisa de: pillow, qrcode, python-barcode, numpy.
"""

import json
import math
import os
import random
import sys

import numpy as np
import qrcode
from barcode import Code128
from barcode.writer import ImageWriter
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONTES = '/usr/share/fonts/truetype'
MONO = f'{FONTES}/dejavu/DejaVuSansMono.ttf'
MONO_B = f'{FONTES}/dejavu/DejaVuSansMono-Bold.ttf'
SANS = f'{FONTES}/liberation/LiberationSans-Regular.ttf'
SANS_B = f'{FONTES}/liberation/LiberationSans-Bold.ttf'

HOMOLOGACAO = 'EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL'


def dv_chave(d43):
    """Módulo 11, pesos 2..9 da direita para a esquerda; resto 0/1 dá 0."""
    soma, peso = 0, 2
    for c in reversed(d43):
        soma += int(c) * peso
        peso = 2 if peso == 9 else peso + 1
    r = soma % 11
    return 0 if r < 2 else 11 - r


def chave(uf, aamm, cnpj, modelo, serie, numero, tp_emis, codigo):
    d = f'{uf:02d}{aamm}{cnpj}{modelo:02d}{serie:03d}{numero:09d}{tp_emis}{codigo:08d}'
    assert len(d) == 43, d
    return d + str(dv_chave(d))


def brl(v):
    s = f'{v:,.2f}'
    return s.replace(',', 'X').replace('.', ',').replace('X', '.')


def cnpj_fmt(d):
    return f'{d[:2]}.{d[2:5]}.{d[5:8]}/{d[8:12]}-{d[12:]}'


def em_grupos(c):
    return ' '.join(c[i:i + 4] for i in range(0, 44, 4))


class Folha:
    """Uma imagem em que cada texto escrito vira uma "linha" do OCR."""

    def __init__(self, largura, altura, fundo='white'):
        self.img = Image.new('RGB', (largura, altura), fundo)
        self.d = ImageDraw.Draw(self.img)
        self.linhas = []  # (texto, l, t, r, b)
        self._fontes = {}

    def fonte(self, caminho, tamanho):
        k = (caminho, tamanho)
        if k not in self._fontes:
            self._fontes[k] = ImageFont.truetype(caminho, tamanho)
        return self._fontes[k]

    def texto(self, x, y, s, fonte, cor='black', ancora='la', ocr=True):
        """Escreve [s]; colunas separadas por 3+ espaços viram linhas
        separadas do OCR (é como o ML Kit corta a linha impressa)."""
        self.d.text((x, y), s, font=fonte, fill=cor, anchor=ancora)
        if not ocr or not s.strip():
            return
        l, t, r, b = self.d.textbbox((x, y), s, font=fonte, anchor=ancora)
        pedacos = []
        i = 0
        for parte in _partes(s):
            ini = s.index(parte, i)
            pedacos.append((parte, ini, ini + len(parte)))
            i = ini + len(parte)
        larg_char = (r - l) / max(1, len(s))
        for parte, ini, fim in pedacos:
            pl = self.d.textbbox((x, y), s[:ini], font=fonte, anchor=ancora)[2] if ini else l
            pr = self.d.textbbox((x, y), s[:fim], font=fonte, anchor=ancora)[2]
            if ini and s[:ini].endswith(' '):
                pl += larg_char * 0  # o espaço já está no começo do corte
            self.linhas.append((parte.strip(), int(pl), int(t), int(pr), int(b)))


def _partes(s):
    """Separa nas colunas: 3 ou mais espaços seguidos."""
    import re
    return [p for p in re.split(r'\s{3,}', s) if p.strip()]


# --------------------------------------------------------------- NFC-e (cupom)

def nfce(saida):
    cnpj = '11222333000181'
    ch = chave(35, '2611', cnpj, 65, 1, 1234, 1, 81726354)
    itens = [
        ('7891000100103', 'CIMENTO CP II-E-32 50KG', 10, 'SC', 38.90),
        ('7890000201021', 'AREIA MEDIA LAVADA', 2, 'M3', 145.00),
        ('7896000300555', 'BLOCO CERAMICO 9X19X29', 500, 'UN', 1.25),
        ('7891000412106', 'VERGALHAO CA-50 10MM 12M', 8, 'BR', 52.90),
        ('7895000500018', 'ARAME RECOZIDO 18 1KG', 2, 'UN', 18.90),
        ('7892000600127', 'CAL HIDRATADA CH-III 20KG', 4, 'SC', 21.90),
    ]
    subtotal = round(sum(q * p for _, _, q, _, p in itens), 2)
    desconto = 52.60
    a_pagar = round(subtotal - desconto, 2)
    tributos = round(a_pagar * 0.3087, 2)
    hash_qr = '7C3A0F61D2B94E58A1C6F0B27D8E9A4B3C5D6E7F'
    url_qr = f'https://www.homologacao.nfce.fazenda.sp.gov.br/qrcode?p={ch}|2|2|1|{hash_qr}'

    col = 48
    f = Folha(945, 3000)
    fn = f.fonte(MONO, 30)
    fb = f.fonte(MONO_B, 30)
    cw = 945 / col * 0.93  # largura de um caractere (aprox.), só para centralizar
    y = 40
    lh = 40

    def linha(s, negrito=False, centro=False):
        nonlocal y
        fonte = fb if negrito else fn
        if centro:
            f.texto(945 // 2, y, s, fonte, ancora='ma')
        else:
            f.texto(32, y, s, fonte)
        y += lh

    def colunas(esq, dir_, negrito=False):
        nonlocal y
        fonte = fb if negrito else fn
        f.texto(32, y, esq, fonte)
        f.texto(945 - 32, y, dir_, fonte, ancora='ra')
        y += lh

    def tracos():
        nonlocal y
        f.d.line((32, y + 16, 945 - 32, y + 16), fill='black', width=2)
        y += lh

    linha('DEPOSITO DE MATERIAIS EXEMPLO LTDA', negrito=True, centro=True)
    linha(f'CNPJ: {cnpj_fmt(cnpj)} IE: 123.456.789.110', centro=True)
    linha('RUA DAS OBRAS, 100 - CENTRO', centro=True)
    linha('SAO PAULO - SP - CEP 01001-000', centro=True)
    tracos()
    linha('DOCUMENTO AUXILIAR DA NOTA FISCAL', centro=True)
    linha('DE CONSUMIDOR ELETRONICA', centro=True)
    tracos()
    linha('EMITIDA EM AMBIENTE DE HOMOLOGACAO', negrito=True, centro=True)
    linha('SEM VALOR FISCAL', negrito=True, centro=True)
    tracos()
    colunas('# CODIGO DESCRICAO', 'QTD UN VL UNIT   VL TOTAL')
    for i, (cod, desc, q, un, p) in enumerate(itens, 1):
        linha(f'{i:03d} {cod} {desc}')
        colunas(f'       {q} {un} X {brl(p)}', brl(q * p))
    tracos()
    colunas('QTD. TOTAL DE ITENS', str(len(itens)))
    colunas('VALOR TOTAL R$', brl(subtotal))
    colunas('DESCONTO R$', brl(desconto))
    colunas('VALOR A PAGAR R$', brl(a_pagar), negrito=True)
    colunas('FORMA DE PAGAMENTO', 'VALOR PAGO R$')
    colunas('PIX', brl(a_pagar))
    tracos()
    linha('Consulte pela Chave de Acesso em', centro=True)
    linha('homologacao.nfce.fazenda.sp.gov.br/consulta', centro=True)
    grupos = em_grupos(ch)
    linha(grupos[:29], centro=True)
    linha(grupos[30:], centro=True)
    tracos()
    linha('CONSUMIDOR NAO IDENTIFICADO', negrito=True, centro=True)
    linha('NFC-e n 000001234 Serie 001', centro=True)
    linha('Emissao: 06/11/2026 14:32:18', centro=True)
    linha('Protocolo de autorizacao: 135269000012345', centro=True)
    linha('Data de autorizacao: 06/11/2026 14:32:21', centro=True)
    # QR Code
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=8, border=2)
    qr.add_data(url_qr)
    qr.make(fit=True)
    qimg = qr.make_image(fill_color='black', back_color='white').convert('RGB')
    qimg = qimg.resize((380, 380), Image.NEAREST)
    y += 10
    f.img.paste(qimg, ((945 - 380) // 2, y))
    y += 380 + 20
    linha('Tributos totais incidentes', centro=True)
    linha(f'(Lei Federal 12.741/2012): R$ {brl(tributos)}', centro=True)
    tracos()
    linha('DOCUMENTO DE TESTE - OBRA NA MAO', negrito=True, centro=True)
    linha('SEM VALOR FISCAL', negrito=True, centro=True)
    y += 30
    f.img = f.img.crop((0, 0, 945, y))
    f.img.save(os.path.join(saida, 'nfce_teste.png'))
    # PDF de 80 mm de largura (300 dpi)
    f.img.save(os.path.join(saida, 'nfce_teste.pdf'), resolution=300)

    esperado = {
        'fornecedor': 'Deposito de Materiais Exemplo Ltda',
        'cnpj': cnpj_fmt(cnpj),
        'total': a_pagar,
        'data': '2026-11-06',
        'itens': [
            {'material': d, 'quantidade': q, 'unidade': u, 'valorUnitario': p,
             'valorTotal': round(q * p, 2)}
            for _, d, q, u, p in itens
        ],
    }
    return f, [{'formato': 'qr', 'valor': url_qr}], esperado, ch


# --------------------------------------------------------------- DANFE (A4)

def danfe(saida):
    W, H = 2480, 3508  # A4 a 300 dpi
    f = Folha(W, H)
    cnpj = '12345678000195'
    ch = chave(35, '2611', cnpj, 55, 1, 4567, 1, 30405060)
    m = 90
    fs = lambda t: f.fonte(SANS, t)  # noqa: E731
    fsb = lambda t: f.fonte(SANS_B, t)  # noqa: E731
    pr = (120, 120, 120)

    def caixa(x0, y0, x1, y1, rotulo=None, valor=None, valor_tam=34, negrito=False, alinhar='l'):
        f.d.rectangle((x0, y0, x1, y1), outline='black', width=3)
        if rotulo:
            f.texto(x0 + 12, y0 + 8, rotulo, fs(22))
        if valor is not None:
            fonte = fsb(valor_tam) if negrito else fs(valor_tam)
            if alinhar == 'r':
                f.texto(x1 - 12, y1 - 12, valor, fonte, ancora='rd')
            else:
                f.texto(x0 + 12, y1 - 12, valor, fonte, ancora='ld')

    # Canhoto
    y = m
    caixa(m, y, W - m - 520, y + 150,
          'RECEBEMOS DE COMERCIAL DE FERRAGENS EXEMPLO LTDA OS PRODUTOS CONSTANTES DA NOTA FISCAL INDICADA AO LADO')
    caixa(W - m - 520, y, W - m, y + 150, None)
    f.texto(W - m - 260, y + 30, 'NF-e', fsb(36), ancora='ma')
    f.texto(W - m - 260, y + 80, 'N. 000.004.567 SERIE 1', fs(28), ancora='ma')
    y += 150
    f.d.line((m, y + 25, W - m, y + 25), fill=pr, width=2)
    y += 50

    # Cabeçalho
    alto = 420
    x1, x2 = m + 900, m + 1350
    caixa(m, y, x1, y + alto)
    f.texto(m + 450, y + 40, 'COMERCIAL DE FERRAGENS', fsb(44), ancora='ma')
    f.texto(m + 450, y + 95, 'EXEMPLO LTDA', fsb(44), ancora='ma')
    f.texto(m + 450, y + 180, 'AV. DOS CONSTRUTORES, 2500 - DISTRITO INDUSTRIAL', fs(26), ancora='ma')
    f.texto(m + 450, y + 220, 'CAMPINAS - SP - CEP 13050-000', fs(26), ancora='ma')
    f.texto(m + 450, y + 260, 'FONE: (19) 3000-0000', fs(26), ancora='ma')
    caixa(x1, y, x2, y + alto)
    f.texto((x1 + x2) // 2, y + 30, 'DANFE', fsb(52), ancora='ma')
    f.texto((x1 + x2) // 2, y + 100, 'DOCUMENTO AUXILIAR DA', fs(24), ancora='ma')
    f.texto((x1 + x2) // 2, y + 132, 'NOTA FISCAL ELETRONICA', fs(24), ancora='ma')
    f.texto(x1 + 30, y + 190, '0 - ENTRADA', fs(24))
    f.texto(x1 + 30, y + 222, '1 - SAIDA', fs(24))
    f.d.rectangle((x2 - 90, y + 190, x2 - 40, y + 245), outline='black', width=3)
    f.texto(x2 - 65, y + 196, '1', fsb(36), ancora='ma')
    f.texto((x1 + x2) // 2, y + 290, 'N. 000.004.567', fsb(30), ancora='ma')
    f.texto((x1 + x2) // 2, y + 330, 'SERIE 1  FOLHA 1/1', fs(26), ancora='ma')
    caixa(x2, y, W - m, y + alto)
    # Código de barras da chave (CODE-128)
    cb = Code128(ch, writer=ImageWriter())
    bimg = cb.render({'module_width': 0.28, 'module_height': 14, 'write_text': False, 'quiet_zone': 2, 'dpi': 300})
    bimg = bimg.convert('RGB')
    bw = W - m - x2 - 60
    bimg = bimg.resize((bw, 150), Image.NEAREST)
    f.img.paste(bimg, (x2 + 30, y + 20))
    f.texto(x2 + 30, y + 190, 'CHAVE DE ACESSO', fs(22))
    f.texto(x2 + 30, y + 225, em_grupos(ch), fsb(30))
    f.texto(x2 + 30, y + 300, 'Consulta de autenticidade no portal nacional da NF-e', fs(24))
    f.texto(x2 + 30, y + 335, 'www.nfe.fazenda.gov.br/portal ou no site da Sefaz', fs(24))
    y += alto
    caixa(m, y, m + 1350, y + 100, 'NATUREZA DA OPERACAO', 'VENDA DE MERCADORIA')
    caixa(m + 1350, y, W - m, y + 100, 'PROTOCOLO DE AUTORIZACAO DE USO', '135269000045678 - 05/11/2026 10:15:42')
    y += 100
    caixa(m, y, m + 760, y + 100, 'INSCRICAO ESTADUAL', '244.555.666.777')
    caixa(m + 760, y, m + 1520, y + 100, 'INSC. ESTADUAL DO SUBST. TRIBUTARIO', '')
    caixa(m + 1520, y, W - m, y + 100, 'CNPJ', cnpj_fmt(cnpj))
    y += 130

    # Destinatário
    f.texto(m, y, 'DESTINATARIO / REMETENTE', fsb(26))
    y += 40
    caixa(m, y, m + 1400, y + 100, 'NOME / RAZAO SOCIAL', 'OBRA EXEMPLO - JOAO DA SILVA (TESTE)')
    caixa(m + 1400, y, m + 1900, y + 100, 'CNPJ / CPF', '123.456.789-09')
    caixa(m + 1900, y, W - m, y + 100, 'DATA DA EMISSAO', '05/11/2026')
    y += 100
    caixa(m, y, m + 1100, y + 100, 'ENDERECO', 'RUA DA OBRA NOVA, 42')
    caixa(m + 1100, y, m + 1500, y + 100, 'BAIRRO / DISTRITO', 'JARDIM EXEMPLO')
    caixa(m + 1500, y, m + 1900, y + 100, 'CEP', '13000-000')
    caixa(m + 1900, y, W - m, y + 100, 'DATA DA SAIDA/ENTRADA', '06/11/2026')
    y += 100
    caixa(m, y, m + 1100, y + 100, 'MUNICIPIO', 'CAMPINAS')
    caixa(m + 1100, y, m + 1500, y + 100, 'UF', 'SP')
    caixa(m + 1500, y, m + 1900, y + 100, 'FONE / FAX', '')
    caixa(m + 1900, y, W - m, y + 100, 'HORA DA SAIDA', '08:30:00')
    y += 130

    # Itens (antes dos totais, para o cálculo)
    itens = [
        ('1001', 'TUBO PVC SOLDAVEL 25MM BARRA 6M', '39172300', 'BR', 20, 18.50),
        ('1002', 'JOELHO 90 PVC SOLDAVEL 25MM', '39174000', 'UN', 40, 1.90),
        ('1003', 'REGISTRO DE GAVETA 3/4 BRUTO', '84818099', 'UN', 4, 64.50),
        ('1004', "CAIXA D'AGUA POLIETILENO 1000L", '39251000', 'UN', 1, 489.00),
        ('1005', 'FIO FLEXIVEL 2,5MM ROLO 100M', '85444900', 'RL', 3, 219.00),
        ('1006', 'DISJUNTOR MONOPOLAR 20A', '85362000', 'UN', 10, 15.00),
        ('1007', 'ELETRODUTO CORRUGADO 25MM 50M', '39173900', 'RL', 2, 190.00),
    ]
    produtos = round(sum(q * p for *_, q, p in itens), 2)
    frete = 100.00
    total_nota = round(produtos + frete, 2)

    f.texto(m, y, 'CALCULO DO IMPOSTO', fsb(26))
    y += 40
    larg = (W - 2 * m) / 6
    linha1 = [('BASE DE CALC. DO ICMS', brl(produtos)), ('VALOR DO ICMS', brl(produtos * 0.18)),
              ('BASE CALC. ICMS S.T.', '0,00'), ('VALOR DO ICMS SUBST.', '0,00'),
              ('V. TOTAL TRIBUTOS', brl(produtos * 0.31)), ('VALOR TOTAL DOS PRODUTOS', brl(produtos))]
    for i, (r, v) in enumerate(linha1):
        caixa(int(m + i * larg), y, int(m + (i + 1) * larg), y + 100, r, v, alinhar='r')
    y += 100
    linha2 = [('VALOR DO FRETE', brl(frete)), ('VALOR DO SEGURO', '0,00'), ('DESCONTO', '0,00'),
              ('OUTRAS DESPESAS', '0,00'), ('VALOR DO IPI', '0,00'), ('VALOR TOTAL DA NOTA', brl(total_nota))]
    for i, (r, v) in enumerate(linha2):
        caixa(int(m + i * larg), y, int(m + (i + 1) * larg), y + 100, r, v, alinhar='r',
              negrito=(i == 5))
    y += 130

    f.texto(m, y, 'TRANSPORTADOR / VOLUMES TRANSPORTADOS', fsb(26))
    y += 40
    caixa(m, y, m + 1300, y + 100, 'RAZAO SOCIAL', 'TRANSPORTES EXEMPLO LTDA')
    caixa(m + 1300, y, m + 1800, y + 100, 'FRETE POR CONTA', '0 - EMITENTE')
    caixa(m + 1800, y, W - m, y + 100, 'PLACA DO VEICULO', 'TST-0A00')
    y += 130

    f.texto(m, y, 'DADOS DOS PRODUTOS / SERVICOS', fsb(26))
    y += 40
    cols = [('COD. PROD.', 190), ('DESCRICAO DO PRODUTO / SERVICO', 860), ('NCM/SH', 200),
            ('CST', 110), ('CFOP', 120), ('UN', 100), ('QUANT.', 170), ('VALOR UNIT.', 250),
            ('VALOR TOTAL', 300)]
    xs = [m]
    for _, w in cols:
        xs.append(xs[-1] + w)
    xs[-1] = W - m
    f.d.rectangle((m, y, W - m, y + 70), outline='black', width=3)
    for i, (rot, _) in enumerate(cols):
        f.texto(xs[i] + 10, y + 22, rot, fs(22))
        if i:
            f.d.line((xs[i], y, xs[i], y + 70 + 75 * len(itens)), fill='black', width=2)
    y += 70
    for cod, desc, ncm, un, q, p in itens:
        vals = [cod, desc, ncm, '000', '5102', un, f'{q},0000', brl(p), brl(q * p)]
        for i, v in enumerate(vals):
            if i >= 6:
                f.texto(xs[i + 1] - 12, y + 22, v, fs(28), ancora='ra')
            else:
                f.texto(xs[i] + 10, y + 22, v, fs(28))
        y += 75
    f.d.rectangle((m, y - 75 * len(itens) - 70, W - m, y), outline='black', width=3)
    y += 40

    f.texto(m, y, 'DADOS ADICIONAIS', fsb(26))
    y += 40
    caixa(m, y, W - m, y + 240, 'INFORMACOES COMPLEMENTARES')
    f.texto(m + 12, y + 50, 'DOCUMENTO DE TESTE DO APP OBRA NA MAO - ' + HOMOLOGACAO, fs(28))
    f.texto(m + 12, y + 95, 'Pedido 7788 - Entrega na obra. Pagamento: boleto 28 dias.', fs(28))
    y += 270
    # Marca d'água de homologação (sem entrar no OCR, para não poluir o caso)
    marca = Image.new('L', (W, H), 0)
    dm = ImageDraw.Draw(marca)
    dm.text((W // 2, H // 2), 'SEM VALOR FISCAL', font=fsb(220), fill=40, anchor='mm')
    marca = marca.rotate(30, center=(W // 2, H // 2))
    cinza = Image.new('RGB', (W, H), (150, 150, 150))
    f.img = Image.composite(cinza, f.img, marca.point(lambda v: v))
    f.d = ImageDraw.Draw(f.img)
    f.img.save(os.path.join(saida, 'danfe_teste.png'))
    f.img.save(os.path.join(saida, 'danfe_teste.pdf'), resolution=300)

    esperado = {
        'fornecedor': 'Comercial de Ferragens Exemplo Ltda',
        'cnpj': cnpj_fmt(cnpj),
        'total': total_nota,
        'data': '2026-11-05',
        'itens': [
            {'material': d, 'quantidade': q, 'unidade': u, 'valorUnitario': p,
             'valorTotal': round(q * p, 2)}
            for _, d, _, u, q, p in itens
        ],
    }
    return f, [{'formato': 'code128', 'valor': ch}], esperado, ch


# --------------------------------------------------------------- "foto"

def fotografar(src, destino, semente=7):
    """O cupom fotografado em cima da mesa: inclinado, em perspectiva, com
    luz desigual, sombra e um pouco de desfoque e ruído."""
    random.seed(semente)
    np.random.seed(semente)
    papel = Image.open(src).convert('RGB')
    w, h = papel.size
    # papel levemente amarelado
    arr = np.asarray(papel).astype(np.float32)
    arr = arr * np.array([0.98, 0.97, 0.92]) + np.array([2, 2, 6])
    papel = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    W, H = int(w * 1.55), int(h * 1.18)
    fundo = np.zeros((H, W, 3), np.float32)
    # mesa de madeira escura
    yy, xx = np.mgrid[0:H, 0:W]
    veios = (np.sin(xx / 37.0 + np.sin(yy / 90.0) * 2.0) * 12 + np.random.normal(0, 4, (H, W)))
    for i, c in enumerate((92, 64, 40)):
        fundo[..., i] = c + veios
    fundo = Image.fromarray(np.clip(fundo, 0, 255).astype(np.uint8))
    # perspectiva: o topo mais estreito (celular inclinado)
    def coef(pa, pb):
        A = []
        for (x, y), (X, Y) in zip(pa, pb):
            A.append([x, y, 1, 0, 0, 0, -X * x, -X * y])
            A.append([0, 0, 0, x, y, 1, -Y * x, -Y * y])
        A = np.array(A, float)
        B = np.array(pb, float).reshape(8)
        return np.linalg.solve(A, B).tolist()
    ox, oy = (W - w) // 2, (H - h) // 2
    dst = [(ox + 70, oy + 40), (ox + w - 40, oy + 10), (ox + w + 30, oy + h - 20), (ox - 30, oy + h + 10)]
    src_pts = [(0, 0), (w, 0), (w, h), (0, h)]
    mascara = Image.new('L', (w, h), 255)
    t = coef(dst, src_pts)
    tp = papel.transform((W, H), Image.PERSPECTIVE, t, Image.BICUBIC)
    tm = mascara.transform((W, H), Image.PERSPECTIVE, t, Image.BICUBIC)
    # sombra do papel
    sombra = tm.filter(ImageFilter.GaussianBlur(25)).point(lambda v: int(v * 0.55))
    fundo.paste((20, 15, 10), (14, 22), sombra)
    fundo.paste(tp, (0, 0), tm)
    arr = np.asarray(fundo).astype(np.float32)
    # luz desigual: mais escuro embaixo à direita, uma sombra de mão
    luz = 0.78 + 0.32 * (1 - (xx / W * 0.6 + yy / H * 0.6))
    mao = np.exp(-(((xx - W * 0.82) / (W * 0.22)) ** 2 + ((yy - H * 0.78) / (H * 0.18)) ** 2)) * 0.28
    arr *= (luz - mao)[..., None]
    arr += np.random.normal(0, 6, arr.shape)
    foto = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1))
    foto = foto.resize((int(W * 0.8), int(H * 0.8)), Image.LANCZOS)
    foto.save(destino, quality=88)


def caso(id_, nota, folha, codigos, esperado):
    # Cada linha vira um bloco, como o ML Kit devolve uma coluna por vez.
    blocos = [{'linhas': [{'t': t, 'l': l, 'tp': tp, 'r': r, 'b': b}]} for t, l, tp, r, b in folha.linhas]
    return {
        'id': id_,
        'origem': 'sintetico',
        'particao': 'teste',
        'nota': nota,
        'entrada': {'blocos': blocos, 'codigos': codigos},
        'esperado': esperado,
    }


def main():
    saida = sys.argv[1]
    os.makedirs(saida, exist_ok=True)
    f1, c1, e1, ch1 = nfce(saida)
    f2, c2, e2, ch2 = danfe(saida)
    fotografar(os.path.join(saida, 'nfce_teste.png'), os.path.join(saida, 'nfce_teste_foto.jpg'))
    casos = [
        caso('ocr-teste-nfce-deposito-exemplo', 'A NFC-e de teste do app (docs/notas-de-teste): 6 itens com o nome numa linha e a quantidade na outra, desconto, PIX e QR de homologação. Total é o Valor a pagar.', f1, c1, e1),
        caso('ocr-teste-danfe-ferragens-exemplo', 'O DANFE de teste do app (docs/notas-de-teste): itens em tabela, frete no total, emissão (05/11) antes da saída (06/11), destinatário com CPF e unidade RL.', f2, c2, e2),
    ]
    with open(os.path.join(saida, 'casos_ocr.json'), 'w', encoding='utf-8') as fp:
        json.dump(casos, fp, ensure_ascii=False, indent=1)
    print('NFC-e', ch1, 'total', e1['total'])
    print('DANFE', ch2, 'total', e2['total'])


if __name__ == '__main__':
    main()
