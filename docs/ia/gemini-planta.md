# IA da planta: ler a planta e gerar "como vai ficar"

Duas funções do Firebase (pasta `functions/`) fazem a parte de IA da planta:

| Função | O que faz | Modelo (padrão) |
|---|---|---|
| `lerPlanta` | Recebe a planta (foto, PDF, imagem ou DXF) e devolve as paredes, os vãos e os cômodos em metros, no formato do app (`PlantaObra`). | Gemini 3.1 Pro (`gemini-3.1-pro-preview`) |
| `gerarImagem` | Recebe um quadro da maquete 3D (fachada ou cômodo) e devolve uma foto realista da casa pronta, com as mesmas medidas. Salva no Storage e registra em `obras/{id}/imagens/{vista}`. | Nano Banana Pro (`gemini-3-pro-image`), 4K |

A chave do Gemini fica no Secret Manager do Google Cloud. Ela não entra no
app nem no repositório. O app chama as funções com o login do Firebase, e
só o dono da obra pode chamá-las.

## Como funciona no app

1. **Planta da obra → Enviar a planta.** O dono escolhe um arquivo ou tira
   uma foto. Foto com mais de 6 MB é reduzida no aparelho (lado maior de
   3.500 px) antes de subir.
2. **Lendo a planta.** A tela mostra a planta com a varredura enquanto a IA
   lê. Leva de um a dois minutos.
3. **Revisão.** Três vistas: a leitura (planta desenhada pelo app), o
   original e o 3D. Os avisos da IA (cota ilegível, escala estimada etc.)
   aparecem em laranja. Os problemas que impedem a maquete aparecem em
   vermelho e travam o botão. O dono corrige o nome, a cobertura e o piso de
   cada cômodo e o pé-direito. **Confirmar a planta** grava em
   `obras/{id}/planta/atual`. A partir daí, a maquete da central, a planta
   do cliente e a vista 360° usam essa casa.
4. **Como vai ficar.** Na planta, **Gerar a fachada** abre a maquete pronta:
   o dono gira até o ângulo que quer, escreve o acabamento (opcional), anexa
   a ilustração do projeto (opcional, usada só para cores e materiais) e
   gera. Na vista 360° de um cômodo, **Gerar foto deste ângulo** faz o
   mesmo com o quadro do cômodo. As imagens aparecem na planta, na vista
   360° do cômodo e na tela do cliente.

Sem as funções publicadas, o app avisa que "a IA da planta ainda não foi
publicada". O resto continua funcionando: a casa de exemplo, a maquete
padrão e o cronograma.

## Formatos aceitos

- Foto da planta impressa, PNG, JPG, WEBP, HEIC: vão direto para o Gemini.
- PDF (até 9 MB): vai direto. É o melhor formato, porque as cotas saem nítidas.
- DXF (o arquivo do CAD): a função lê as linhas, os textos e as camadas e
  manda um resumo em texto, em metros. Funciona bem quando o desenho tem
  camadas com nomes claros (PAREDE, PORTA, JANELA, COTA).
- DWG: não dá, porque o formato é fechado. No CAD, exporte em PDF ou DXF.

## Ligar a IA no projeto (passo a passo)

Precisa ser feito uma vez, por quem é dono do projeto `obrafacil-a755c` no
Firebase.

1. **Plano Blaze.** No console do Firebase, abra Configurações do projeto →
   Uso e faturamento e mude para o Blaze. Cloud Functions e Secret Manager
   só funcionam nele. Crie também um **alerta de orçamento** em
   console.cloud.google.com/billing → Orçamentos e alertas (sugestão:
   US$ 10/mês, com aviso em 50%, 90% e 100%).
2. **Chave do Gemini.** Em aistudio.google.com/apikey, crie a chave no
   projeto `obrafacil-a755c` e ative o faturamento nele. No nível pago, o
   Google não usa os dados enviados para treinar modelos. No gratuito, usa.
3. **Ferramenta do Firebase** (no seu computador):
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
4. **Guardar a chave** (na raiz do repositório):
   ```bash
   firebase functions:secrets:set GEMINI_API_KEY
   ```
   Cole a chave quando o terminal pedir. Ela vai direto para o Secret
   Manager. Não cole a chave em código, em `.env` ou em chat.
5. **Storage.** No console do Firebase, abra Storage e clique em Começar
   (pode ser na região `southamerica-east1`).
6. **Publicar** (na raiz do repositório):
   ```bash
   cd functions && npm ci && cd ..
   firebase deploy --only functions,firestore:rules,storage
   ```
   No primeiro deploy, o Firebase pergunta os parâmetros abaixo. Enter
   aceita o padrão, e as respostas ficam em
   `functions/.env.obrafacil-a755c`.
7. **Testar:** abra uma obra no app como dono → Planta da obra → Enviar a
   planta.

### Parâmetros

| Parâmetro | Padrão | Para que serve |
|---|---|---|
| `MODELO_PLANTA` | `gemini-3.1-pro-preview` | Modelo que lê a planta. Troque quando sair a versão estável. |
| `MODELO_IMAGEM` | `gemini-3-pro-image` | Modelo das imagens (Nano Banana Pro). |
| `LEITURAS_POR_MES` | 15 | Leituras de planta por obra, por mês. |
| `IMAGENS_POR_MES` | 30 | Imagens por obra, por mês. |
| `GERACOES_POR_VISTA` | 3 | Quantas vezes dá para gerar a mesma vista (fachada ou um cômodo). |

Para mudar um parâmetro depois, edite `functions/.env.obrafacil-a755c` e
publique de novo só as funções: `firebase deploy --only functions`.

## Custo

Preços da Gemini API no plano pago, em novembro de 2026. Confira em
ai.google.dev/gemini-api/docs/pricing antes de confiar, porque mudam.

| Item | Preço | Por obra (típico) |
|---|---|---|
| Ler a planta (Gemini 3.1 Pro: US$ 2 por milhão de tokens de entrada, US$ 12 por milhão de saída, raciocínio incluso) | US$ 0,05 a 0,25 por leitura | 1 a 2 leituras: até US$ 0,50 |
| Imagem 4K (Nano Banana Pro) | US$ 0,24 por imagem | fachada + 5 cômodos: US$ 1,44 |
| Cloud Functions, Firestore, Storage | dentro da cota gratuita do Blaze para este uso | US$ 0 |

**Uma obra completa sai por volta de US$ 2**, uma vez só. A leitura e as
imagens ficam gravadas: abrir a planta, a maquete ou as imagens depois não
gasta nada, e funciona sem internet depois da primeira vez (cache do
Firestore e das imagens).

Cada chamada grava o custo estimado em `obras/{id}/uso_ia/{aaaa-mm}`
(`leituras`, `imagens`, `custoUsd`). Só a função escreve ali. O limite por
mês é conferido numa transação antes de chamar o Gemini, e o pedido
recusado não gasta nada.

## Segurança

- A chave fica só no Secret Manager (`defineSecret('GEMINI_API_KEY')`). O
  app não tem a chave.
- `lerPlanta` e `gerarImagem` exigem login e conferem que quem chama é o
  dono da obra (`obras/{id}.donoId`).
- Regras do Firestore: a planta só o dono grava. `imagens` e `uso_ia`
  ninguém grava pelo app, só a função (Admin SDK). O cliente lê a planta e
  as imagens da obra dele.
- Regras do Storage (`storage.rules`): lê quem está logado. Ninguém grava
  pelo app.
- A função aceita arquivo de até 9 MB (planta) e 8 MB (quadros) e confere o
  tipo do arquivo.

## Testar os prompts à mão (sem publicar nada)

Dá para conferir a leitura no AI Studio (aistudio.google.com), com a sua
conta, antes de publicar as funções.

**Ler a planta**

1. Modelo: Gemini 3.1 Pro. Temperatura: 0.
2. Em "Structured output", cole o esquema `esquemaPlanta` de
   `functions/src/planta.ts` (o objeto JSON).
3. Cole o texto de `promptLerPlanta` (`functions/src/prompts.ts`), anexe a
   planta e envie.
4. Salve a resposta como `leitura.json` e compare com o gabarito:
   ```bash
   cd functions && npm run build
   node lib/src/avaliar.js leitura.json ../obra_facil/assets/plantas/casa_7x20.json
   ```
   O resultado traz quantos cômodos a IA achou, o erro médio das medidas
   (m), o erro da área (%), a sobreposição média dos cômodos (IoU) e as
   paredes e vãos lidos. Esses números servem para a seção de resultados do
   TCC.

**Imagem "como vai ficar"**

1. Modelo: Nano Banana Pro (Gemini 3 Pro Image). Tamanho: 4K. Proporção:
   3:2 (fachada) ou 4:3 (cômodo).
2. Anexe um print da maquete (no app: Planta → Gerar a fachada, ou a vista
   360°) e, se quiser, a ilustração do projeto como segunda imagem.
3. O texto é o de `promptComoVaiFicar` (`functions/src/prompts.ts`). Para a
   fachada sem ilustração, fica assim:

   > The FIRST image is a plain 3D massing model of a Brazilian house,
   > rendered from the construction app. It shows the exact geometry:
   > walls, openings, roof parapet, lot, street sidewalk.
   > Turn it into a photorealistic architectural visualization of the
   > FINISHED house: realistic plaster and paint, window frames and glass,
   > doors, a gate, the sidewalk, a little landscaping inside the lot, soft
   > late-afternoon daylight, a clear sky.
   > Keep EXACTLY the same camera position, lens, perspective and framing
   > as the first image.
   > Keep EXACTLY the same walls, proportions, number and position of
   > windows and doors. Do not add or remove floors, rooms, windows or
   > doors.
   > Use a contemporary Brazilian style: light neutral colors, wood
   > details, simple lines.
   > No people, no text, no labels, no watermark, no dimension lines, no
   > dashed lines.

## Limites conhecidos

- A IA erra medida, principalmente em foto torta ou planta sem cota. Por
  isso a revisão é obrigatória e o PDF é o formato recomendado.
- A revisão corrige cômodos e pé-direito, mas ainda não deixa mover uma
  parede. Parede errada: envie de novo com uma foto mais nítida ou o PDF.
- Casa de um pavimento. Sobrado entra numa próxima versão do formato
  (`PlantaObra.versao`).
- A imagem gerada é ilustrativa: o modelo segue a geometria do quadro, mas
  pode inventar acabamento. O app avisa isso na imagem em tela cheia.
