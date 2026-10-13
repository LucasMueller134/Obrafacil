# Conjunto de avaliação das IAs

Mede o acerto das IAs de voz, nota fiscal e foto **campo a campo**, para
comparar versões ("antes" e "depois") com números, e não com impressão.

```bash
# roda a avaliação e imprime a tabela
flutter test test/avaliacao/avaliacao_ia_test.dart

# roda e grava o resultado com um rótulo (ex.: antes, depois, v2)
AVALIACAO_SALVAR=depois flutter test test/avaliacao/avaliacao_ia_test.dart
```

O resultado gravado vai para `resultados/<rótulo>.json`, com o acerto por
campo e a lista de cada caso que falhou (esperado × obtido).

## Como ler as métricas

Para cada campo:

| Métrica | O que conta |
|---|---|
| **acerto** | a IA preencheu o valor certo (ou deixou vazio quando devia) |
| **errado** | a IA preencheu um valor **errado** — o pior caso, o usuário pode não perceber |
| **omitido** | a IA deixou vazio quando havia resposta — o usuário preenche à mão |
| **inventado** | a IA preencheu algo quando o certo era deixar vazio |

`acurácia = acerto / avaliados`. Um campo só é avaliado nos casos em que o
`esperado` traz aquele campo.

## Formato dos casos

Cada arquivo em `casos/` é uma lista JSON. Campos comuns:

- `id`: identificador único e legível (`voz-valor-sem-reais-01`).
- `origem`: `"sintetico"` (escrito à mão imitando a saída real do
  reconhecedor/OCR) ou `"real"` (copiado de um uso de verdade no canteiro).
- `nota`: por que o caso existe / o que ele testa.
- `entrada`: o que a IA recebe.
- `esperado`: o que um encarregado de obra preencheria. **Só os campos
  presentes são avaliados.** `null` significa "o certo é deixar vazio".

### `voz_lancamento.json`
`entrada`: `{"transcricao": "...", "alternativas": [["...", 0.81], ...]}`
(`alternativas` é opcional: hipóteses extras do reconhecedor com a confiança).
`esperado`: `valor` (número), `categoria` (`material` | `maoDeObra` |
`equipamento` | `outros`), `fornecedor` (texto ou null), `data`
(`AAAA-MM-DD` ou null), `itens` (`[{"material","quantidade","unidade"}]`).
"Hoje" nos casos é **2026-07-06 (segunda-feira)**.

### `voz_diario.json`
`entrada`: igual à de voz. `esperado`: `clima` (`Ensolarado` | `Nublado` |
`Chuvoso` | `Chuva forte` | null), `pessoas` (inteiro ou null), `fase` (uma
das fases padrão ou null), `data`.

### `ocr_notas.json`
`entrada`: `{"texto": "..."}` **ou** `{"blocos": [{"linhas": [{"t": "...",
"l": 0, "tp": 0, "r": 0, "b": 0}]}]}` (texto com a posição de cada linha, em
pixels: esquerda, topo, direita, base — como o ML Kit devolve). Com `blocos`,
o texto corrido é montado na ordem dos blocos, igual ao `RecognizedText.text`.
Opcional: `"codigos": [{"formato": "qr" | "code128", "valor": "..."}]` — o que
o leitor de código de barras leria na mesma foto.
`esperado`: `fornecedor`, `cnpj` (`00.000.000/0000-00`), `total`, `data`.

### `foto_diario.json`
`entrada`: `{"rotulos": [["Brick", 0.91], ...], "paleta": {"terra": 0.1,
"tijolo": 0.3, "concreto": 0.2, "claro": 0.05, "vegetacao": 0.0,
"ceuAzul": 0.4, "ceuCinza": 0.0}}` — rótulos do classificador do ML Kit (em
inglês, como ele devolve) e a proporção de cores da foto.
`esperado`: `fase` (a fase que a tela deve **preencher**; null = a foto não
permite afirmar), `clima`, `materiais_contem`, `materiais_nao_contem`.

### `material.json`
`entrada`: `{"rotulos": [["Bag", 0.8], ...], "texto": "CIMENTO CP II..."}`
(`texto` é o que o OCR leria na embalagem; opcional).
`esperado`: `material` (nome do material no app, ou null).

## Casos reais

Os casos `sintetico` imitam a saída do reconhecedor do Android, do ML Kit e
do OCR, mas **não substituem uso real**. Sempre que a IA errar no canteiro,
copie a entrada (transcrição, texto lido ou "o que a IA viu") para um caso
`"origem": "real"` com o esperado correto — é assim que o conjunto passa a
medir o seu canteiro, e não o que eu imaginei dele.
