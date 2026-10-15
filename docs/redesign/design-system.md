# Design system "Prancheta"

A interface do ObraFácil fala a língua do desenho técnico: papel, grafite,
cota, carimbo e traço. O laranja da marca aparece como marca-texto, sempre
com texto preto em cima. A maquete 3D mostra em material real o que já foi
construído e, tracejado, o que falta.

Este documento é a referência de implementação. O código fica em
`obra_facil/lib/design/`.

## 1. Regras de canteiro (valem para tudo)

| Regra | Valor |
|---|---|
| Tema | Claro por padrão; escuro para a noite. Segue o sistema. |
| Contraste mínimo | Texto principal 15:1 · texto secundário 7:1 · ícones e bordas 3:1 |
| Texto sobre laranja | Sempre preto `#15120F`. Nunca branco. |
| Alvo de toque | 48 dp no mínimo; 64 dp para ações do mestre; 72 dp para a ação principal da tela; 12 dp entre alvos |
| Ação principal | Fixa no rodapé (`BarraDeAcao`), ao alcance do polegar |
| Status | Nunca só por cor: ícone ou padrão + texto. Pendente usa hachura. |
| Gestos | Todo gesto tem botão equivalente. Desfazer em vez de diálogo de confirmação. |
| Dinheiro | Algarismos tabulares; valor principal da tela com 32 sp ou mais |
| Texto | Informação com 15 sp no mínimo. Só o rótulo em caixa alta pode ter 13 sp (negrito, 7:1). |
| Fontes | Embutidas no app (o canteiro fica sem sinal) |
| Movimento | Só o que informa uma mudança. Respeita "reduzir animações". Vibra ao confirmar, aprovar e errar. |
| 3D | Nunca carrega ação crítica; nada de texto sobre fundo animado |

## 2. Cores

Tokens em `CoresObra` (`ThemeExtension`), lidos com `context.cores`.

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `papel` | `#F4F5F3` | `#121315` | fundo das telas |
| `folha` | `#FFFFFF` | `#1A1C1F` | superfícies (cartões, campos, folhas) |
| `folhaRebaixada` | `#EBECE8` | `#23262A` | áreas recuadas, trilho de barras |
| `grafite` | `#1A1C1F` | `#ECEDE9` | texto principal, botão principal, traço forte |
| `grafite2` | `#4B5058` | `#A9ADB3` | texto secundário |
| `traco` | `#6E737B` | `#7A7F87` | bordas e ícones (≥ 3:1) |
| `grade` | `#DCDFDB` | `#2C2F34` | divisórias decorativas, nunca informação |
| `marca` | `#F97316` | `#FF8A3D` | laranja: preenchimento de destaque |
| `sobreMarca` | `#15120F` | `#15120F` | texto e ícone sobre a marca |
| `marcaTexto` | `#C2410C` | `#FF8A3D` | laranja como texto ou traço fino |
| `revisao` | `#B42318` | `#FF6B5B` | erro, recusa, alerta de orçamento |
| `ok` | `#0B6E4F` | `#3FBF8A` | aprovado, concluído |
| `aviso` | `#FFC400` | `#FFC400` | atenção, sempre com texto preto |
| `sobreGrafite` | `#F4F5F3` | `#121315` | texto sobre o botão grafite |

Contrastes medidos (WCAG 2.2): grafite no papel 15,6:1 (escuro 15,8:1);
grafite2 na folha 8,1:1 (escuro 7,6:1); traço na folha 4,8:1 (escuro 3,6:1);
preto na marca 6,7:1 (escuro 8,0:1); marcaTexto na folha 5,2:1; revisão na
folha 6,6:1; ok na folha 6,3:1; preto no aviso 11,7:1.

Gráficos: categorias separadas por luminância (grafite, traço, marca, grade
hachurada) e rotuladas direto no gráfico, sem legenda colorida.

## 3. Tipografia

| Papel | Fonte | Tamanho / peso | Uso |
|---|---|---|---|
| `valorHeroi` | Archivo SemiCondensed | 40 / 800, tabular | o número principal da tela (R$) |
| `tituloTela` | Archivo SemiCondensed | 30 / 800 | nome da obra, título da tela |
| `titulo` | Archivo SemiCondensed | 22 / 700 | títulos de seção |
| `subtitulo` | Archivo SemiCondensed | 18 / 700 | título de cartão, botão |
| `corpo` | Atkinson Hyperlegible Next | 17 / 400, altura 1,45 | texto |
| `corpoForte` | Atkinson Hyperlegible Next | 17 / 700 | destaque no texto, item de lista |
| `apoio` | Atkinson Hyperlegible Next | 15 / 400 | texto secundário (mínimo para informação) |
| `rotulo` | Archivo SemiCondensed | 13 / 700, caixa alta, espaçamento 1,0 | rótulos de campo e de carimbo |
| `codigo` | IBM Plex Mono | 15 / 500 | chave da NF-e, código de convite |

Todos os números de dinheiro, quantidade e porcentagem usam
`FontFeature.tabularFigures()`.

Por que estas fontes: a Archivo SemiCondensed lembra a letra técnica do
carimbo e tem algarismos tabulares; a Atkinson Hyperlegible Next foi feita
pelo Braille Institute para baixa visão, e 0/O e 1/l/I não se confundem sob
reflexo; a IBM Plex Mono deixa a chave de 44 dígitos legível. As três são
OFL, embutidas como arquivos estáticos (`assets/fontes/`).

## 4. Espaço, forma e traço

- Espaçamento (`Espaco`): 4 · 8 · 12 · 16 · 24 · 32 · 48. Margem lateral das
  telas: 16.
- Raios (`Raio`): `nenhum` 0 · `pequeno` 2 · `padrao` 4 · `folha` 8 (topo das
  folhas que sobem de baixo) · `pilula` só na nota de revisão e no microfone.
- Traço (`Traco`): `fino` 1,5 (bordas) · `forte` 2 (destaque, botão de
  contorno). Nada abaixo de 1,5 dp.
- Sombra: nenhuma nas superfícies. Hierarquia por papel/folha + borda.
  Só a folha que sobe de baixo tem uma sombra curta para separar do conteúdo.

## 5. Movimento (`Movimento`)

| Token | Valor | Uso |
|---|---|---|
| `rapido` | 120 ms | estado pressionado, troca de seleção |
| `medio` | 220 ms | entrar e sair de elementos |
| `lento` | 360 ms | traçado de cota, contagem de valor, maquete |
| `entrar` / `sair` | `easeOutCubic` / `easeInCubic` | curvas |
| `mola` | massa 1, rigidez 520, amortecimento 42 | folhas e cartões, sem quique |

Movimentos com significado:
- **Traçado:** a régua de cota se desenha da esquerda até o valor.
- **Contagem:** o valor-herói conta até o novo número (algarismos tabulares,
  então não treme).
- **Varredura:** uma linha grafite percorre a foto da nota enquanto o OCR lê.
- **Folha sobre folha:** a tela nova entra opaca por cima (transição atual).
- **Aprovar:** o cartão sai da fila e a vibração confirma; desfazer por 4 s.

Com "reduzir animações" ligado, todas as durações viram zero e a maquete não
gira sozinha. `Tato` centraliza a vibração: `leve()` na seleção,
`confirmar()` ao salvar e aprovar, `erro()` ao falhar.

## 6. Componentes (`lib/design/componentes/`)

| Componente | O que é |
|---|---|
| `Folha` | superfície com borda de 1,5 dp e raio 4; variante `destaque` com borda grafite de 2 dp |
| `Carimbo` | quadro de título da prancha: células com rótulo + valor, separadas por traço |
| `Rotulo` | texto do papel `rotulo` |
| `ValorHeroi` | valor em R$ grande, tabular, com contagem animada |
| `ReguaCota` | barra de avanço como linha de cota: preenchimento grafite, marcador laranja com legenda, traço oblíquo nas pontas |
| `LinhaCota` | divisória com traço oblíquo nas pontas e legenda no meio |
| `NotaRevisao` | anotação em pílula de contorno (vermelho de revisão ou laranja) |
| `Hachura` | padrão de linhas diagonais; marca o que está pendente |
| `SeloStatus` | status com forma: hachura/ícone + texto |
| `BotaoPrincipal` | 64 dp (72 na variante `grande`), fundo grafite, texto papel |
| `BotaoMarca` | igual, fundo laranja e texto preto |
| `BotaoContorno` | contorno grafite de 2 dp, fundo transparente |
| `BotaoIcone` | quadrado de 64 dp, contorno ou marca |
| `BarraDeAcao` | rodapé fixo com a ação principal, respeita a área segura e o teclado |
| `LinhaLista` | linha de lista com 72 dp ou mais: ícone, título, apoio, valor à direita |
| `MaqueteObra` | a maquete 3D da obra (flutter_scene) com imagem de reserva |

## 7. Maquete 3D

- Modelo: `assets/3d/maquete.glb`, gerado por
  `ferramentas/maquete_3d/` (Blender, tudo procedural). Um nó por fase
  (`fase_00_fundacao` … `fase_09_acabamento`), alvenaria por fiada, e um
  nó `fantasma_fase_XX` com o tracejado do que falta.
- Tempo real: flutter_scene (Flutter GPU sobre Impeller). Cada fase aparece
  conforme o percentual dela no cronograma; arrastar gira na horizontal.
- Reserva: `assets/3d/reserva/{claro,escuro}/estado_00..10.webp`, a mesma
  cena renderizada no Blender. Usada quando o Flutter GPU não inicia, quando
  o aparelho não aguenta (quadros lentos), com "reduzir animações" e nos
  testes.

## 8. Ícones

Ícones de traço (Material Symbols "outlined" ou desenhados no mesmo traço),
sempre na cor `grafite` ou `traco`. Sem quadradinho colorido atrás, sem
brilhos de "IA", sem emoji. A IA aparece como o campo já preenchido e uma
nota dizendo quanta certeza ela tem.
