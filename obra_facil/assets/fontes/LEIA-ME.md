# Fontes embutidas

O app não baixa fonte em tempo de execução (o canteiro fica sem sinal).
Todas são OFL 1.1; as licenças estão em `licencas/`.

| Arquivo | Família no app | Origem |
|---|---|---|
| `Archivo-SemiCondensed-{SemiBold,Bold,ExtraBold}.ttf` | `Archivo` (600, 700, 800) | instâncias estáticas da Archivo variável (`wdth` 87,5) |
| `AtkinsonHyperlegibleNext-{Regular,Medium,Bold}.ttf` | `Atkinson` (400, 500, 700) | instâncias estáticas da Atkinson Hyperlegible Next variável |
| `IBMPlexMono-{Regular,Medium}.ttf` | `PlexMono` (400, 500) | IBM Plex Mono |

Fonte original: https://github.com/google/fonts (pastas `ofl/archivo`,
`ofl/atkinsonhyperlegiblenext`, `ofl/ibmplexmono`). As instâncias foram
geradas com fontTools (`varLib.instancer`) e reduzidas aos blocos Latim,
pontuação, moeda, setas, símbolos matemáticos e formas geométricas, mantendo
as variações tipográficas (algarismos tabulares inclusive).
