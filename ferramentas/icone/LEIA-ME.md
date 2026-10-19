# Ícone do app (direção "Prancheta")

## A ideia

Uma planta baixa vista de cima, como no projeto da obra. O canto que já foi
levantado é um L de parede cheia em laranja (a cor da marca = construído).
As paredes que faltam são só o eixo tracejado em grafite (= ainda no
desenho), e a porta aparece com a folha aberta e o arco de abertura. É a
mesma regra da maquete 3D do app: o que existe aparece em material, o que
falta aparece tracejado. O fundo é o papel (`#F4F5F3`).

## Arquivos

| Arquivo | O que é |
| --- | --- |
| `planta.svg` | Fonte única do ícone, no quadro de 108 dp do ícone adaptativo. Três caminhos com id: `construido`, `falta`, `porta`. |
| `notificacao.svg` | Ícone de notificação, desenhado à parte na grade de 24 dp (branco). |
| `exportar.py` | Troca as cores pelos ids, manda rasterizar, confere tudo e grava em `obra_facil/assets/icone/`. |
| `renderizar.js` | Rasteriza SVG em PNG no Chromium do Playwright, no tamanho final. |

Saídas em `obra_facil/assets/icone/`:

| PNG | Tamanho | Uso |
| --- | --- | --- |
| `icon.png` | 1024, sem alfa | ícone legado (Android 7) e arte da loja; só a janela visível de 72 dp, com o papel |
| `icon_foreground.png` | 1296, transparente | camada da frente do ícone adaptativo (108 dp) |
| `icon_monochrome.png` | 1296, transparente | camada `monochrome` do ícone temático do Android 13+: a mesma geometria de 108 dp, numa cor só |
| `splash.png` | 1152, transparente | splash clara (Android 7 a 11 e 12+) |
| `splash_escuro.png` | 1152, transparente | splash escura, versão "mesa de luz" |
| `notificacao/drawable-*/ic_stat_obrafacil.png` | 24 a 96 | ícone pequeno da notificação, uma pasta por densidade |

## Como regenerar

```sh
pip install -r ferramentas/icone/requirements.txt
npm i playwright && npx playwright install chromium   # ou PLAYWRIGHT_MODULE=/caminho/node_modules/playwright
python3 ferramentas/icone/exportar.py
```

O script para com erro se algum PNG sair do tamanho ou do modo certo, se o
desenho sair do círculo de segurança (66 dp no quadro de 108; 768 px na
splash de 1152) ou se a monocromática não tiver a mesma geometria da camada
da frente. Rodar de novo gera os mesmos bytes.

## Decisões

- **Contraste do laranja.** Laranja `#F97316` sobre o papel dá 2,56:1,
  abaixo dos 3:1 que a WCAG 1.4.11 pede para elementos gráficos. Foi aceito
  de propósito: é a marca, e não um controle da interface; quem carrega a
  leitura do desenho é o grafite (15,61:1); as paredes laranja são formas
  grandes e cheias (12 dp); e no ícone temático e na notificação, que o
  sistema pinta numa cor só, o problema não existe. Trocar por `#C2410C`
  (4,73:1) deixaria o laranja marrom e fora do token `marca`. Na splash
  escura o mesmo laranja dá 6,63:1 sobre `#121315`.
- **Splash escura = mesa de luz.** Fundo `#121315` (papel escuro), traço
  `#ECEDE9` (grafite escuro, 15,81:1) e o mesmo laranja da marca, para a
  splash continuar o ícone do launcher. Um disco de papel claro no meio da
  tela escura ofuscaria à noite.
- **Camadas de 1296 px, não 1024.** O `flutter_launcher_icons` reduz a
  camada para 108, 162, 216, 324 e 432 px fazendo a média em janelas
  inteiras. Com 1296 (12 px/dp) o fator é inteiro em todas as densidades e
  as arestas da grade de 3 dp caem em pixel inteiro. Com 1024, o pacote
  gerou 9 a 10 vezes mais pixels de meio-tom em xhdpi, xxhdpi e xxxhdpi.
- **Cor "sangrada" nos pixels transparentes.** As duas ferramentas fazem a
  média sem pré-multiplicar o alfa, e o pixel transparente do Chromium é
  preto: sem isto, a borda do laranja ganha uma franja marrom.
- **No pubspec:** `adaptive_icon_foreground_inset: 0`. As camadas já vêm no
  quadro de 108 dp; o padrão do pacote (16%) encolheria o desenho.
- **O que não fazer** (testado pelo júri): aumentar o desenho (o próximo
  passo da grade leva o canto para fora do círculo de 66 dp), pôr grade no
  fundo (em 48 px disputa com o tracejado) e espelhar a porta (vira "L/\").
- **Notificação.** O primeiro traço de cima fica solto da parede: colado,
  a parede, o traço e a parede de baixo formam um "[". O arco continua
  antisserrilhado, porque no aparelho a notificação sai com 66 a 96 px.
