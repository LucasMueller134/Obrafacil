# Maquete 3D da obra (direção "Prancheta")

Gera, só com código no Blender (módulo Python `bpy`), a maquete da casa que o
app mostra na central da obra:

| Saída | O que é |
| --- | --- |
| `obra_facil/assets/3d/maquete.glb` | Modelo glTF 2.0 binário. Uma peça nomeada por fase, para o app (flutter_scene) mostrar e esconder em tempo real. |
| `obra_facil/assets/3d/maquete.json` | Manifesto: nós, fases, pivôs, triângulos, materiais de tema com as cores claro/escuro, cor opaca do fantasma (`fantasma_opaco`), câmera das imagens (`camera_reserva`), âncoras das cotas, lista das imagens (`reserva`). Opcional para o app. |
| `obra_facil/assets/3d/reserva/{claro,escuro}/estado_00.webp … estado_10.webp` | 22 imagens pré-renderizadas em Cycles (1080x720), para aparelhos sem suporte ao 3D. |

A casa é a do protótipo web aprovado (`maquete.js`, three.js): planta de
9,40 x 7,40 m, as mesmas aberturas e o mesmo mapeamento de peças por fase.

## Como regenerar

Precisa de Python 3.13 (exigência do `bpy` 5.2). Não precisa do Blender
instalado: o `bpy` traz o Blender inteiro, com Cycles, OpenImageDenoise e o
exportador glTF.

```sh
python3.13 -m venv .venv-maquete
.venv-maquete/bin/pip install -r ferramentas/maquete_3d/requirements.txt

# tudo: glb + manifesto + 22 imagens (~27 min em 4 núcleos de CPU)
.venv-maquete/bin/python ferramentas/maquete_3d/gerar_maquete.py

# só o glb e o manifesto (~2 s)
.venv-maquete/bin/python ferramentas/maquete_3d/gerar_maquete.py --sem-render

# teste rápido de luz/material (540x360, poucas amostras)
.venv-maquete/bin/python ferramentas/maquete_3d/gerar_maquete.py --sem-glb --rapido \
    --amostras 32 --estados 0,3,10 --temas claro --folha /tmp/folha.png

# validar o glb (só biblioteca padrão; sai com erro se alguma regra falhar)
python3 ferramentas/maquete_3d/validar_glb.py obra_facil/assets/3d/maquete.glb
```

Opções úteis: `--amostras` (padrão 96; a entrega usou 128), `--estados 0,5,10`,
`--temas claro`, `--sol`, `--ceu` e `--exposicao` (luz), `--tmp` (PNGs
intermediários), `--folha` (folha de contato), `--blend` (salva o .blend para
depuração). A exportação é determinística: rodar de novo gera o mesmo glb,
byte a byte.

## Coordenadas

* 1 unidade = 1 metro, Y para cima (glTF), frente da casa (rua) em +Z.
* Origem no centro do tabuleiro, no nível do terreno, que é o topo do
  tabuleiro. O tabuleiro (14 x 12 m) vai de y = -0,30 a 0. Piso pronto em
  y = 0,20, laje de 3,00 a 3,12, platibanda até 3,78, topo da caixa d'água em 4,65.
* Os nós só têm translação (sem rotação/escala). A translação de cada peça é
  o seu pivô, escolhido para o app poder "crescer" a peça com uma escala
  (pivôs no `maquete.json`). Exemplos: `estrutura_pilares` no piso (escala em Y
  sobe os pilares), `estrutura_laje` e `fundacao_radier` na borda dos fundos
  (escala em Z concreta de trás para a frente), cada `alvenaria_fiada_XX` na
  base da sua fiada.

## Nós

```
maquete
├── base                       tabuleiro + grade de 0,5 m e de 2 m (materiais base, grade, grade_forte)
├── cotas                      "9,40" e "7,40" com traço oblíquo (material cota)
├── fase_00_fundacao           └ fundacao_radier
├── fase_01_estrutura          └ estrutura_pilares, estrutura_vigas, estrutura_laje
├── fase_02_alvenaria          └ alvenaria_fiada_00 … alvenaria_fiada_11  (paredes, de baixo para cima)
│                                alvenaria_fiada_12 … alvenaria_fiada_14  (platibanda, 3 fiadas)
├── fase_03_cobertura          └ cobertura_tercas (terças e pontaletes), cobertura_telhas
├── fase_04_eletrica           └ eletrica_poste, eletrica_caixa_medicao, eletrica_eletroduto
├── fase_05_hidraulica         └ hidraulica_base, hidraulica_caixa_dagua, hidraulica_tubos
├── fase_06_reboco             └ reboco_paredes (inclui a faixa da platibanda), reboco_contrapiso
├── fase_07_revestimentos      └ revestimentos_calcada, revestimentos_ripado,
│                                revestimentos_pingadeira, revestimentos_peitoris (e soleira)
├── fase_08_pintura            └ pintura_paredes
├── fase_09_acabamento         └ acabamento_esquadrias, acabamento_porta, acabamento_arvores
└── fantasma_fase_00 … fantasma_fase_09   (06 e 08 são nós vazios: reboco e pintura não têm desenho)
```

* Cada `fase_XX_*` tem nos `extras` do glTF: `fase` (índice), `nome` (como no
  app) e `progresso_fim` (0,08 … 1,00, igual ao protótipo).
* Fiadas: cada `alvenaria_fiada_XX` é um nó com os blocos daquela fiada, a
  argamassa e, quando houver, a verga ou contraverga de concreto que fica nela.
  O app revela fiada a fiada mostrando os nós em ordem.
* Vãos em osso: na alvenaria os vãos são arredondados para a fiada (20 cm),
  com verga na fiada de cima e contraverga sob as janelas; o reboco fecha até
  o vão acabado do protótipo.
* Pintura: `pintura_paredes` é uma casca 4 mm maior que `reboco_paredes`, com
  a tinta clara. Mostrar a fase 08 cobre o reboco cinza; o reboco continua lá
  dentro. Não há troca de cor de material para animar.

### Fantasmas (o desenho do que falta)

* `fantasma_fase_XX` é o desenho tracejado da fase XX pronta, feito para ser
  lido com a maquete a ~340 px de largura (16,6 px/m): é o **contorno do
  volume** da fase, não as arestas de cada peça (linhas a menos de ~10 cm uma
  da outra viram ruído nesse tamanho). Traços de 28 cm com vão de 15 cm. Cada
  traço é um prisma fino de seção triangular com 5 cm de lado (3 faces,
  6 triângulos): de qualquer ângulo ele tem de 4,3 a 5 cm de largura (~0,8 px
  a 340 px: linha fina, não pontilhado).
* O que cada fantasma desenha:

  | Fase | Desenho |
  | --- | --- |
  | 00 fundação | o contorno de cima do radier (y = 0,20) |
  | 01 estrutura | a laje como placa: o contorno de baixo (y = 3,00). Pilares e vigas não têm desenho (ficam dentro da caixa das paredes) |
  | 02 alvenaria | a caixa da casa pronta: 4 quinas em ±4,52 x ±3,52 do piso à laje; a platibanda: 4 quinas em ±4,74 x ±3,74 de 3,00 a 3,78 e o contorno do topo |
  | 03 cobertura | um plano inclinado (contorno da telha) |
  | 04 elétrica | o eixo do poste e a face da caixa de medição virada para a rua |
  | 05 hidráulica | a base (topo + 4 quinas) e a caixa d'água como tronco de cone (2 círculos + 2 geratrizes da silhueta) |
  | 06 reboco | nada (nó vazio): não muda a silhueta |
  | 07 revestimentos | o contorno externo da calçada e a face do ripado |
  | 08 pintura | nada (nó vazio) |
  | 09 acabamento | o vão acabado de cada janela e porta, na face pronta da parede, e a silhueta de cada copa (1 círculo perpendicular à vista padrão) |

* As geratrizes da caixa d'água e os círculos das copas são a silhueta vista
  da câmera padrão (azimute 0,62 rad); com a câmera em órbita eles deixam de
  ser silhueta.
* Todos usam um único material, `fantasma`: sem luz (`KHR_materials_unlit`),
  OPAQUE, grafite `#1A1C1F`. No tema escuro o app troca a cor para `#ECEDE9`.
  As imagens de reserva usam opacidade 0,78 no claro e 0,62 no escuro. **No
  app, não usar alfa**: as 3 faces de cada prisma se sobrepõem (o traço mancha)
  e a ordenação das transparências falha. Usar a cor opaca equivalente, que o
  manifesto traz em `fantasma_opaco` (a cor do fantasma com essa opacidade
  sobre a base do tema, misturada em luz linear): claro `#7D7D7C`, escuro
  `#C0C1BE`. Fantasma não deve projetar nem receber sombra.
* **Regra de exibição:** mostrar o fantasma de toda fase ainda não concluída
  (como o protótipo). Linhas paralelas a menos de 8 cm uma da outra viram uma
  só, e fica no fantasma da fase posterior (com o desenho por volume isso quase
  não acontece). O desenho dos vãos é da fase 09 e por isso aparece até a
  obra pronta; mostrar só o fantasma da fase atual deixaria a casa sem os
  vãos desenhados.

### Materiais

Principled BSDF simples e foscos, exportados como glTF metal/rugosidade:
`concreto`, `bloco_ceramico` (o tom varia por bloco via `COLOR_0`, que o
flutter_scene multiplica pela cor base; sem `COLOR_0` fica o tom médio),
`argamassa`, `reboco`, `tinta`, `madeira_pinus`, `madeira_porta`,
`fibrocimento`, `plastico_azul`, `pvc_marrom`, `aluminio_escuro`,
`metal_galvanizado`, `policarbonato`, `vidro` (BLEND, alfa 0,35), `granito`,
`calcada`, `arvore`.

Materiais de tema, que o app troca de cor:

| Material | Claro | Escuro |
| --- | --- | --- |
| `base` | `#F2F2EF` | `#2A2D31` |
| `grade` | `#DCDDDA` | `#393D41` |
| `grade_forte` | `#C8C9C6` | `#4D5155` |
| `cota` | `#1A1C1F` | `#ECEDE9` |
| `fantasma` | `#1A1C1F` | `#ECEDE9` |
| `fantasma`, cor opaca para o app (`fantasma_opaco`) | `#7D7D7C` | `#C0C1BE` |
| fundo (não está no glb) | `#F4F5F3` | `#121315` |

Não há texturas: a grade da base é geometria (faixas finas), o que permite
trocar as cores pelo tema sem trocar imagem.

## Orçamento

Limites: cena inteira até ~80 mil triângulos, até ~40 chamadas de desenho
por fase visível, glb até ~4 MB, só glTF 2.0 padrão (sem Draco/meshopt).

| Nó | Triângulos | Chamadas | Fantasma (tri) |
| --- | ---: | ---: | ---: |
| base + cotas | 1.179 | 4 | – |
| fase_00_fundacao | 108 | 1 | 480 |
| fase_01_estrutura | 1.728 | 3 | 480 |
| fase_02_alvenaria | 13.038 | 34 | 696 |
| fase_03_cobertura | 2.794 | 2 | 456 |
| fase_04_eletrica | 568 | 5 | 78 |
| fase_05_hidraulica | 2.204 | 3 | 516 |
| fase_06_reboco | 1.204 | 2 | 0 (nó vazio) |
| fase_07_revestimentos | 7.024 | 4 | 708 |
| fase_08_pintura | 1.194 | 1 | 0 (nó vazio) |
| fase_09_acabamento | 9.592 | 6 | 1.416 |
| **total** | **45.463** | **73** | **4.830** (805 traços) |

glb: 1,71 MB, 47.019 vértices, 22 materiais, extensão usada só
`KHR_materials_unlit`. A fase mais cara em chamadas é a alvenaria: 15 fiadas
x (bloco + argamassa) + 4 com verga = 34, mais 1 do fantasma.

Acabamento: as peças retas têm chanfro de 3 a 30 mm (2 segmentos) com normais
ponderadas por área (modificador Weighted Normal): as faces grandes ficam
planas e a aresta pega luz. Os blocos (14x19x39, junta de 1 cm) são caixas
sem chanfro, de propósito: o chanfro ali é menor que um pixel e custaria 30
mil triângulos; o que dá leitura de alvenaria de verdade é a junta de
argamassa rebaixada 1 cm, o tom por bloco e um desalinhamento de 1 a 2 mm.
Para não dar z-fighting, as peças que se apoiam umas nas outras (radier e
tabuleiro, pilar e viga, viga e laje, reboco e laje, pingadeira e
platibanda, casca de pintura e reboco) entram de 2 a 10 mm uma na outra ou
ficam separadas por um chanfro, e as faixas planas do tabuleiro (grade,
cotas) ficam em alturas diferentes, de 1,2 a 4,5 mm acima dele. O que ainda
se encosta face com face são peças pequenas de esquadria (folha contra o
marco), sempre de costas uma para a outra, dentro da fresta.

## Imagens de reserva

* Estado N = fases 0 … N-1 prontas e fantasmas das fases N … 9. `estado_00`
  é só a base com a casa toda em desenho; `estado_10`, a obra pronta.
* Cycles em CPU, 1080x720, 128 amostras adaptativas, OpenImageDenoise
  (albedo + normal), transformação de vista Khronos PBR Neutral (preserva as
  cores de base e comprime só o alto, para o branco da base não estourar).
* Câmera 3/4 do alto do protótipo (azimute 0,62 rad, elevação 0,52 rad),
  lente 50 mm equivalente (FOV vertical 27°), afastada até o tabuleiro
  inteiro caber com 6 % de margem. A posição exata está em `camera_reserva`
  no manifesto, para o 3D do app poder coincidir com a imagem.
* Luz: "janela" vinda da esquerda e da frente (sol de 14° de diâmetro
  aparente, sombras macias) + céu neutro em degradê. O chão em volta do
  tabuleiro só recebe sombra (shadow catcher) e o fundo é composto depois
  com a cor exata do tema (`#F4F5F3` / `#121315`), em luz linear.
* Só nas imagens o vidro é vidro de verdade (transmissão); no glb ele é
  translúcido por alfa, que é o que o app desenha barato.
* Fantasma com opacidade 0,78 (claro) e 0,62 (escuro).
* WebP qualidade 85.
* Cotas: os números "9,40" e "7,40" ficam com ~3 px de altura a 340 px de
  largura (a fonte está deitada no tabuleiro e encurtada pela elevação da
  câmera); valem como ornamento de desenho técnico. Se o app quiser um rótulo
  legível, o manifesto traz em `cotas` o centro de cada número no modelo e em
  pixels da imagem de reserva (1080x720, origem no canto de cima à esquerda).

## Licença

Tudo é procedural e original deste script: nenhum modelo, textura ou imagem
de terceiros. A única peça de terceiros usada na geração é a fonte Archivo
SemiCondensed SemiBold (SIL Open Font License 1.1, em
`obra_facil/assets/fontes`): os contornos dos números "9,40" e "7,40" viram
malha dentro do glb; a OFL não se estende a obras feitas com a fonte. O glb,
as imagens e o manifesto podem ser usados livremente no projeto.

## Diferenças em relação ao protótipo

* A janela da frente foi deslocada 20 cm para a esquerda (-3,8 a -1,6): no
  protótipo ela invadia o pilar de x = -1,5 (o pilar ficava dentro do vão).
* A base da caixa d'água tem 0,60 m (protótipo: 0,50), para a caixa aparecer
  acima das ondas da telha.
* A telha passa por baixo da base da caixa d'água (a base atravessa o
  telhado), em vez de o telhado ser recortado: a base é da fase de
  hidráulica, e o recorte deixaria um buraco no telhado nas fases 03 e 04.
* Terças sobre pontaletes (no protótipo flutuavam), calçada em placas com
  junta, degrau na porta, pingadeira sobre a platibanda, peitoris de granito,
  janelas de correr com duas folhas, eletroduto no padrão de entrada, tubos
  de PVC na caixa d'água e árvores de esfera com haste.
* A caixa de medição fica do lado da rua (no protótipo, virada para a casa).
* O poste do padrão de entrada está em (6,0; 4,3) (protótipo: (5,6; 5,2)).
  Na posição do protótipo ele ficava na linha de visada da quina da frente
  (0,57 rad entre poste e quina contra 0,62 rad da câmera) e, nas imagens,
  parecia a quina da casa; agora aparece à direita dela (1,09 rad).
* O fantasma é mais simples que o do protótipo (contorno por volume) e o traço
  é mais grosso, para ler a 340 px.
