# Relatório das IAs do ObraFácil

Auditoria e revisão das IAs de **imagem** e **voz** do app, com medição de
acerto antes e depois. Decisão do projeto: **IA 100% no aparelho**, sem
nuvem, sem custo e sem chave de API.

## 1. Resumo

| | Antes | Depois |
|---|---|---|
| Valor do gasto entendido pela voz | 57% | **91%** |
| Total da nota fiscal | 39% | **78%** |
| CNPJ da nota | 72% | **94%** |
| Material reconhecido pela câmera | 57% | **100%** |
| Fase da obra pelo relato falado | 66% | **79%** |
| Equipe (nº de pessoas) pelo relato falado | 65% | **87%** |
| Fase da obra pela foto | 50% | **71%** (50% → 50% na metade reservada) |

Medido em 133 casos (seção 5). Custo mensal: **R$ 0**.

## 2. O que estava errado

**Imagem**

1. **O classificador não conhece obra.** O ML Kit tem ~400 rótulos de uso
   geral em inglês ("Roof", "Wood", "Metal"). Termos que o código esperava,
   como `rebar`, `formwork` e `excavation`, não fazem parte desse
   vocabulário. Foi a causa do caso real em que uma foto de baldrame virou
   "Cobertura" com telha.
2. **As regras de cor geravam erros novos.** A madeira da forma contava
   como terra e puxava a foto para Fundação; a telha cerâmica contava como
   tijolo e puxava para Alvenaria.
3. **OCR sem a estrutura da nota.** O app usava só o texto corrido. Em nota
   de duas colunas, o rótulo "TOTAL" e o valor ficavam longe, e o total saía
   de um número qualquer. O QR code da NFC-e, que traz CNPJ e data exatos e
   validáveis, era ignorado.
4. **Material sem leitura da embalagem.** O saco de cimento não era
   reconhecido, e a lata de tinta virava vergalhão porque o modelo dizia
   "Metal".
5. **O "progresso por foto" media diferença de pixels.** Luz e ângulo
   dominavam o resultado, e o README prometia "avanço real".

**Voz**

6. **O reconhecedor era usado no modo mais pobre.** O app usava só a
   primeira hipótese e descartava as outras 9 que o Android devolve. O modo
   offline não estava ligado, embora o README prometesse "on-device". Num
   erro, o painel ficava "ouvindo" para sempre. Com barulho de obra, o fim
   da fala podia nunca ser detectado.
7. **O parser tinha furos em falas comuns.**
   - "paguei 200 pro pedreiro" ficava sem valor.
   - "gastei 2 mil reais" virava R$ 1.000.
   - "10 sacos a 35 cada" ficava sem valor.
   - "metros cúbicos" ia para o estoque como "m".
   - No diário, "pintamos a parede" virava Alvenaria e "rebocamos" não era
     reconhecido.
8. **Ruído de canteiro não era tratado.** Palavras partidas pelo
   reconhecedor ("verga lhão", "contra piso", "chap isco") viravam material
   desconhecido.

**Geral**

9. **Não havia como medir.** Os testes usavam frases ideais e não existia
   conjunto com resposta esperada, então nenhuma melhoria podia ser provada.

## 3. Decisões técnicas e justificativa

**Por que no aparelho.**
- O canteiro tem sinal ruim.
- O TCC tem a IA embarcada como proposta.
- Custo por uso seria um risco para o pequeno construtor.
- Foto e voz de funcionário são dados pessoais (LGPD): processá-los no
  celular evita enviá-los a terceiros.

**Alternativas avaliadas e descartadas (outubro de 2026)**

| Opção | Por que não agora |
|---|---|
| Gemini via Firebase AI Logic (nuvem) | Melhor acerto, custo de centavos, mas depende de internet e envia foto e voz para fora do aparelho |
| Claude Haiku via Cloud Function (nuvem) | Mesmo motivo, e ainda exige o plano Blaze e um servidor |
| Gemma 3n no aparelho | ~3 GB por modelo, 10 a 60 s por foto, só roda em celular topo de linha |
| Gemini Nano (ML Kit GenAI) | Só em Pixel 9, Galaxy S25 e similares; sem plugin Flutter oficial |
| Whisper no aparelho | Bom em pt-BR, mas soma 57 a 180 MB ao app; fica como próximo passo |

**Arquitetura adotada, em camadas:**

```
captura (câmera / microfone)
  → pré-processamento: orientação, realce, binarização, rotação, QR code
  → modelos on-device: ML Kit (texto, código de barras, rótulos),
    reconhecedor de voz do Android em modo offline
  → interpretação com conhecimento de obra (Dart puro, testável)
  → validação: dígitos do CNPJ e da chave, data ≤ hoje, data no mês da
    chave, valor plausível, fase só com evidência suficiente
  → rascunho na tela, com o "porquê" visível → o usuário confirma
```

**Princípio de projeto: melhor vazio que errado.** Um campo vazio, o
usuário preenche. Um campo errado, ele pode nem perceber. Por isso a
avaliação conta separadamente "errado" e "omitido".

## 4. O que mudou

**Nota fiscal (OCR)**
- As linhas visuais são remontadas pela posição do texto, com a foto
  inclinada ou deitada endireitada.
- Hierarquia de total: "valor a pagar" > "valor total" > subtotal. Tributo,
  troco e desconto nunca são o total.
- Chave de acesso lida do QR, do código de barras ou do texto, com DV
  validado. O CNPJ da chave vence o lido pelo OCR, e a data tem de bater
  com o mês da chave.
- Arquivos: `linhas_ocr.dart`, `chave_acesso.dart` e
  `ocr_nota_service.dart`; pacote novo `google_mlkit_barcode_scanning`
  0.13.0.

**Voz (lançamento e diário)**
- Valor reconhecido sem "reais", "2 mil", preço unitário e valor negociado.
- Unidades por extenso ("metros cúbicos" → m³).
- Fornecedor sem engolir o resto da frase.
- Normalizador do vocabulário de obra para o ruído do reconhecedor.
- Escolha entre as hipóteses do Android.
- Diário: clima com negação, contagem de equipe e fase pela atividade.
- Microfone: offline por padrão, com instrução para baixar o pacote de
  português e opção online por gravação; erros tratados; encerra 4 s depois
  da última palavra nova; aviso de confiança baixa.

**Foto do canteiro e material**
- Cor de madeira separada de solo.
- Telha só com duas evidências de telhado.
- Bloco de concreto separado de tijolo; reboco e contrapiso separados de
  estrutura.
- Monte de areia sem obra não sugere fase.
- Material: o texto da embalagem entra como evidência forte.
- Suporte a modelo próprio treinado com as fotos da obra (seção 9).

**Mudança visual entre fotos.** A luz é equalizada e as bordas são
comparadas; os textos não prometem mais "avanço real".

**Erros.** Mensagens que dizem o que fazer, sem texto técnico.

## 5. Como foi medido

- **Conjunto:** 133 casos em `obra_facil/test/avaliacao/casos/`
  - 46 lançamentos por voz
  - 31 relatos de diário
  - 18 notas fiscais (8 com posição de cada linha, 10 com QR ou código de
    barras)
  - 24 fotos do canteiro
  - 14 fotos de material
- **Origem dos casos.** Imitam a saída real do reconhecedor do Android, do
  OCR e do classificador do ML Kit: ruído, minúsculas, colunas separadas,
  rótulos genéricos.
- **Revisão independente.** Cada arquivo foi escrito por um gerador e
  conferido por um revisor: contas, datas e dígitos verificadores
  recalculados.
- **Esperado sem olhar o código.** A resposta esperada é o que um
  encarregado preencheria, não o que o código faz.
- **Partição dev/teste.** Cada caso tem uma partição fixa, sorteada pelo
  hash do id. Só os erros da metade dev foram estudados para corrigir. A
  metade teste ficou reservada, e quem implementou não viu nenhum caso.
- **Métricas por campo:**
  - acurácia = acertos / avaliados;
  - **errado** = valor errado preenchido;
  - **omitido** = deixou vazio havendo resposta;
  - **inventado** = preencheu quando devia deixar vazio.
- **Como rodar:** `flutter test test/avaliacao/avaliacao_ia_test.dart`.
  Com `AVALIACAO_SALVAR=<rótulo>`, o resultado é gravado em
  `resultados/<rótulo>.json`.

## 6. Resultados antes × depois

<!-- tabela gerada a partir de resultados/antes.json e resultados/depois.json -->
| Módulo | Campo | Antes | Depois | Antes (teste) | Depois (teste) | Errado antes → depois |
|---|---|---|---|---|---|---|
| Voz → lançamento | valor | 57% | **91%** | 59% | 91% | 4 → 4 |
| Voz → lançamento | categoria | 96% | **98%** | 95% | 95% | 2 → 1 |
| Voz → lançamento | fornecedor | 87% | **91%** | 82% | 82% | 1 → 0 |
| Voz → lançamento | data | 98% | **98%** | 95% | 95% | 1 → 1 |
| Voz → lançamento | itens | 84% | **100%** | 84% | 100% | 5 → 0 |
| Voz → diário | clima | 83% | **90%** | 81% | 81% | 5 → 2 |
| Voz → diário | pessoas | 65% | **87%** | 75% | 88% | 4 → 3 |
| Voz → diário | fase | 66% | **79%** | 50% | 86% | 8 → 2 |
| Voz → diário | data | 85% | **90%** | 80% | 80% | 1 → 1 |
| Nota fiscal (OCR) | fornecedor | 71% | **82%** | 73% | 73% | 4 → 1 |
| Nota fiscal (OCR) | cnpj | 72% | **94%** | 67% | 92% | 3 → 0 |
| Nota fiscal (OCR) | total | 39% | **78%** | 42% | 83% | 11 → 4 |
| Nota fiscal (OCR) | data | 89% | **94%** | 92% | 92% | 1 → 1 |
| Foto do canteiro | fase | 50% | **71%** | 50% | 50% | 9 → 3 |
| Foto do canteiro | materiais | 75% | **90%** | 73% | 82% | 5 → 2 |
| Foto do canteiro | clima | 100% | **100%** | 100% | 100% | 0 → 0 |
| Material pela câmera | material | 57% | **100%** | 70% | 100% | 2 → 0 |

| Módulo | Casos | Sem nenhum erro — antes | depois |
|---|---|---|---|
| Voz → lançamento | 46 | 16 (35%) | **37 (80%)** |
| Voz → diário | 31 | 13 (42%) | **19 (61%)** |
| Nota fiscal (OCR) | 18 | 3 (17%) | **11 (61%)** |
| Foto do canteiro | 24 | 11 (46%) | **17 (71%)** |
| Material pela câmera | 14 | 8 (57%) | **14 (100%)** |

**Leitura honesta**
- **Voz, OCR e material** melhoraram também na metade reservada: a
  correção generalizou.
- **Fase pela foto** subiu de 50% para 71% no geral, mas ficou em 50% na
  metade reservada. Lá, a mudança foi de segurança: fase errada preenchida
  caiu de 5 para 3, e fase deixada em branco subiu de 2 para 4.
- **Conclusão:** regras em cima de um classificador genérico não
  generalizam para a fase da obra. O caminho é o modelo próprio (seção 9).

## 7. Limitações e ameaças à validade

- **Casos sintéticos.** Imitam a saída real, mas não substituem fotos e
  áudios do canteiro. Cada erro real deve virar um caso `"origem": "real"`
  (ver `test/avaliacao/LEIA-ME.md`).
- **Rótulos e paletas da foto também são sintéticos.** A distribuição real
  de rótulos do ML Kit numa obra precisa ser conferida no aparelho, pelo
  "Ver o que a IA viu".
- **Partes nativas sem teste em aparelho.** O microfone, o leitor de
  código de barras e o carregamento do modelo próprio foram testados contra
  o plugin simulado e com testes unitários, mas não num Android real. O
  build do APK roda no CI, só em push na `main`.
- **Voz offline.** Exige o pacote de reconhecimento de português baixado no
  celular. Sem ele, o app explica como baixar e oferece o modo online
  naquela gravação.
- **Treino do modelo próprio não executado aqui.** O script foi validado
  até o download do modelo base, que é bloqueado na rede deste ambiente.

## 8. Custos e configuração

- **Custo mensal: R$ 0.** Nenhuma chamada a serviço pago; tudo roda no
  celular.
- **Chaves e variáveis de ambiente: nenhuma.**
  - O app não usa chave de API de IA.
  - `lib/firebase_options.dart` (gerado pelo `flutterfire configure`)
    identifica o projeto Firebase e não é segredo. A proteção dos dados
    está em `obra_facil/firestore.rules`, que precisa estar publicada no
    console.
  - A avaliação aceita `AVALIACAO_SALVAR`, que não é segredo.
- **No celular de teste:** baixar o pacote de voz offline de português.
  Em geral fica em Configurações → Google → Voz/Reconhecimento offline; o
  caminho varia por fabricante.
- **Se um dia entrar IA na nuvem:**
  - usar o Firebase AI Logic, em que a chave fica no Firebase e não no app;
  - ligar o App Check com Play Integrity, que exige distribuição pela Play
    Store, mesmo no teste interno;
  - guardar o nome do modelo e os limites no Remote Config;
  - nada de chave no código.

## 9. Próximos passos recomendados

1. **Treinar o modelo próprio de fases** com 100 a 200 fotos por fase, de
   pelo menos 3 obras (`docs/ia/treinar-modelo.md`). É o único caminho que
   resolve a fase pela foto no aparelho. Medir com o mesmo conjunto, com as
   fotos reais como casos `"real"`.
2. **Coletar casos reais.** Cada erro no canteiro, entre transcrição, texto
   lido e "o que a IA viu", vira um caso no conjunto.
3. **Testar num Android real** o microfone offline, o leitor de QR e o
   modelo próprio, antes da banca.
4. **Whisper no aparelho** (`whisper_cpp_flutter_plus`), se o reconhecedor
   do Android errar demais com barulho. Aceita lista de vocabulário e
   funciona offline, mas soma 57 a 180 MB.
5. **Atualizar o Firebase** (core 3 → 4, auth 5 → 6, firestore 5 → 6) num
   PR separado e testado no aparelho. Não era necessário para a IA
   on-device e mexe no app inteiro.

## 10. Trechos para o texto do TCC

> **Justificativa da IA embarcada.** Optou-se por executar toda a
> inferência no próprio dispositivo (Google ML Kit e o reconhecedor de voz
> do Android em modo offline), sem serviços de nuvem. A escolha atende a
> três requisitos do contexto de obra: funcionamento sem conectividade no
> canteiro, custo operacional nulo para o pequeno construtor e minimização
> do tráfego de dados pessoais (imagens e voz de trabalhadores), em linha
> com a LGPD. Modelos multimodais em nuvem obteriam acurácia maior, mas
> foram descartados por dependerem de internet e por enviarem esses dados
> a terceiros.

> **Conhecimento de domínio sobre modelos genéricos.** Os modelos
> embarcados são de uso geral: o classificador de imagens não possui
> classes de construção civil e o reconhecedor de voz não conhece o
> vocabulário do canteiro. A solução adotada combina esses modelos com uma
> camada de interpretação com conhecimento de domínio. Essa camada reúne a
> reconstrução do layout da nota pela geometria do texto, a validação pelos
> dígitos verificadores do CNPJ e da chave de acesso da NF-e/NFC-e, a
> normalização de termos técnicos partidos pelo reconhecedor e a
> combinação de evidências (rótulos, cores e texto) com limiar de
> confiança. O princípio de projeto é preferir um campo vazio a um campo
> errado.

> **Metodologia de avaliação.** Construiu-se um conjunto de 133 casos que
> reproduzem a saída real dos componentes de reconhecimento (transcrições
> com ruído, texto de OCR com colunas separadas, rótulos genéricos). Cada
> caso traz a resposta esperada, definida sem consulta à implementação e
> revisada de forma independente. Os casos foram divididos de forma fixa
> em uma metade de desenvolvimento e uma metade reservada, esta usada
> apenas para medir a generalização. A acurácia foi medida por campo,
> distinguindo valores errados preenchidos de campos omitidos.

> **Resultados.** A revisão elevou a acurácia do valor interpretado da fala
> de 57% para 91%, do total da nota fiscal de 39% para 78% e do material
> reconhecido pela câmera de 57% para 100%. Na fase da obra pela foto, a
> acurácia na metade reservada não se alterou (50%), embora os
> preenchimentos errados tenham caído. Esse resultado indica o limite das
> regras sobre um classificador genérico e motiva o treinamento de um
> modelo próprio com fotos de obra.
