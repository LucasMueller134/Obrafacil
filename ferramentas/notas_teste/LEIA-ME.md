# Notas fiscais de teste

Duas notas para testar a leitura da nota no app (Lançar gasto → foto da nota →
**Escanear a nota**), sem precisar de uma compra de verdade. São **documentos
de teste, sem valor fiscal**: lojas fictícias, CNPJ de exemplo, chave de
acesso do ambiente de homologação e o aviso "EMITIDA EM AMBIENTE DE
HOMOLOGAÇÃO / SEM VALOR FISCAL" impresso, como a SEFAZ manda nas notas de teste.

| Arquivo | O que é |
| --- | --- |
| `saida/nfce_teste.png` / `.pdf` | Cupom NFC-e de 80 mm com QR Code, desconto e PIX |
| `saida/danfe_teste.png` / `.pdf` | DANFE da NF-e em A4, com código de barras e frete |
| `saida/nfce_teste_foto.jpg` | O cupom "fotografado": inclinado, com sombra e ruído |

## Como testar

1. Abra o PNG (ou o PDF) na tela do computador, em tela cheia, ou imprima.
2. No app: **Lançar gasto** → toque na foto da nota → **Escanear a nota**.
3. Aponte o celular: o scanner acha a nota, endireita e recorta sozinho.
   Confirme o recorte e espere a leitura.

O que o app deve preencher:

| | NFC-e (cupom) | DANFE (A4) |
| --- | --- | --- |
| Fornecedor | Deposito de Materiais Exemplo Ltda | Comercial de Ferragens Exemplo Ltda |
| CNPJ | 11.222.333/0001-81 | 12.345.678/0001-95 |
| Valor | R$ 1.800,00 (1.852,60 − 52,60 de desconto) | R$ 2.480,00 (2.380,00 + 100,00 de frete) |
| Data | 06/11/2026 | 05/11/2026 (a emissão, não a saída) |
| Itens | 6: cimento, areia, bloco cerâmico (tijolo), vergalhão, arame, cal | 7: tubo, joelho, registro, caixa d'água, fio, disjuntor, eletroduto |

Cada item aparece com a quantidade, o preço de cada um e o total da linha, e
embaixo a soma dos itens. Na aprovação do gasto, os itens entram no estoque
da obra.

O `nfce_teste_foto.jpg` serve para testar a foto ruim: mande pela opção
**Escolher da galeria**.

## Como gerar de novo

```sh
python3 -m venv .venv-notas
.venv-notas/bin/pip install -r ferramentas/notas_teste/requirements.txt
.venv-notas/bin/python ferramentas/notas_teste/gerar_notas.py ferramentas/notas_teste/saida
```

Além das imagens, o script grava `casos_ocr.json`: as duas notas como casos
da avaliação (`obra_facil/test/avaliacao/casos/ocr_notas.json`, os casos
`ocr-teste-*`), cada linha com a caixa onde o ML Kit a devolveria.
