# Capturas de tela do redesenho

As capturas do "antes" e do "depois" saem do mesmo harness de teste, com os
mesmos dados de exemplo, para a comparação lado a lado valer. Não precisa de
Firebase, aparelho nem rede.

## Como gerar

```sh
cd obra_facil
CAPTURAR=antes flutter test test/visual/capturas_test.dart
```

(Neste ambiente o Flutter do projeto é `/opt/flutter-3.47/flutter/bin/flutter`,
3.47.7. Na primeira vez o hook do flutter_scene compila os shaders, uns 5
minutos; depois fica em cache e a série inteira roda em uns 20 s.)

- `CAPTURAR` é o nome da série e da pasta: `CAPTURAR=antes` grava em
  `docs/redesign/antes/`, `CAPTURAR=depois` em `docs/redesign/depois/`. Só
  letras, números, `-` e `_`.
- Sem `CAPTURAR`, os testes de captura são pulados: o `flutter test` de
  sempre não escreve nada.
- Cada cena sai em dois tamanhos, com pixel ratio 3:
  - `<cena>.png`: celular de 390x844 pontos (PNG de 1170x2532);
  - `<cena>_longa.png`: tela comprida de 390x2400 pontos (1170x7200), para
    ver a página inteira sem rolar.
- A tela tem 24 pontos de barra de status no topo e 16 de barra de gestos
  embaixo (Android edge-to-edge). A barra de status não é desenhada, só o
  espaço dela.
- Para uma cena só: `--plain-name 02_obra_dono`.

Uma captura só é gravada se a tela não deu erro: overflow, exceção no
build (tela vermelha) ou texto fora das fontes carregadas reprovam o teste
antes do PNG. A exceção é o `defeitoConhecido` de uma cena (ver abaixo).

## Cenas (série "antes", tema escuro atual)

| Arquivo | O que mostra |
|---|---|
| `01_obras_dono` | Lista de obras da Marina (dono): as três obras com status, datas e orçamento. |
| `02_obra_dono` | Central da obra (`/obras/sobrado-vila-izabel`) como dono: cabeçalho laranja com códigos, financeiro, previsão, gráficos e módulos. |
| `03_obra_mestre` | A mesma central como o Joaquim (mestre): sem menu, sem códigos e sem o botão de revisar. |
| `04_lancamentos_dono` | Lançamentos como dono, "Todos": é a fila de aprovação de hoje (os 3 pendentes no topo). |
| `05_lancamentos_pendentes_dono` | A mesma tela com o filtro "Pendente": os 3 pendentes somando R$ 4.912,40. |
| `06_lancamento_pendente_dono` | Folha de detalhe do "Bloco cerâmico 9 furos", com Rejeitar e Aprovar (o jeito de aprovar hoje). |
| `07_novo_lancamento_mestre` | Novo lançamento como mestre, vazio. |
| `08_novo_lancamento_voz_mestre` | Painel de voz aberto e ouvindo, com a interpretação ao vivo de "comprei seis metros de areia média por mil duzentos e noventa reais". |
| `09_novo_lancamento_voz_preenchido_mestre` | O formulário depois do "Concluir": aviso da IA, material para o estoque, descrição, valor e categoria preenchidos pela fala. |
| `10_cliente_obra` | Acompanhamento do cliente (Paulo): avanço físico, prazo, etapas e diário. |

### Defeito real nas cenas 08 e 09 (painel de voz)

Em 390 pontos a linha de botões do painel de voz (Cancelar, Regravar,
Concluir) mede 350,4 pontos e só há 342: o app de hoje estoura 8,4 pontos à
direita. A captura 08 mostra o que o modo debug desenha nesse caso, a faixa
amarela e preta e o rótulo vermelho vertical (este na fonte padrão do
framework). No release não há faixa: o "Concluir" sai cortado 8,4 pontos
na borda direita (o `SingleChildScrollView` do painel recorta).
Cabe a partir de uns 399 pontos de largura, então em boa parte dos Android
de 360 a 393 pontos o defeito aparece. Na 09 o painel já fechou, mas o
erro aconteceu enquanto ele estava aberto. As duas cenas declaram o erro exato em
`defeitoConhecido`; se ele mudar ou sumir (no redesenho, por exemplo), o
teste falha e é só tirar a declaração.

## Como funciona (`obra_facil/test/visual/`)

| Arquivo | Papel |
|---|---|
| `capturas_test.dart` | As cenas: perfil, rota e o que tocar antes da foto. |
| `fontes_test.dart` | Roda sempre (sem `CAPTURAR`): confere que o texto sai na Poppins e nas fontes do pubspec, que o ícone Material é desenhado e que a seta cai na fonte de símbolos. |
| `suporte/captura.dart` | Harness: `Cena`, `capturarCena`, tamanhos, `AppDeCaptura` (o MaterialApp do `main.dart`) e gravação do PNG. |
| `suporte/fakes.dart` | `FirestoreFalso` e `AuthServiceFalso`, por `implements` (o `FirestoreService` real cria `FirebaseFirestore.instance` num campo). O que não está implementado cai no `noSuchMethod` com uma mensagem dizendo o que acrescentar. |
| `suporte/dados_exemplo.dart` | Dados fictícios e fixos (ver abaixo). |
| `suporte/fontes.dart` | `carregarFontes()`: o helper único das fontes. |
| `suporte/plataforma.dart` | Plugins de mentira: voz (speech_to_text, com `falaDoAparelho`) e ML Kit. |
| `fontes/` | Poppins e a fonte de símbolos dos testes, com as licenças OFL. |

O app é montado como no `lib/main.dart`: `AuthProvider` de verdade
alimentado pelo `AuthServiceFalso`, `ChangeNotifierProvider<AuthProvider>`,
`Provider<FirestoreService>.value` com o falso, o router de verdade
(`criarRouter`, com o redirect por perfil), tema `AppTheme.dark` e
localização pt_BR (`flutter_localizations` e `initializeDateFormatting`). A
cena entra por `router.go(rota)`, então a pilha tem as telas de cima e a
seta de voltar aparece como no app. O teste confere que o router não
redirecionou para outro lugar.

### Fontes

`carregarFontes()` carrega tudo de uma vez:

1. **Poppins** (tema atual) pelo próprio google_fonts, com
   `GoogleFonts.config.allowRuntimeFetching = false`. Os TTF de
   `test/visual/fontes/` são os mesmos arquivos, byte a byte (SHA-256 da
   tabela do google_fonts 6.3.3), que o app baixa de `fonts.gstatic.com` no
   aparelho. O canal `flutter/assets` é interceptado para servi-los como se
   fossem assets do app.
2. **Fontes do pubspec** (`FontManifest.json`, via `rootBundle`): Archivo
   600/700/800, Atkinson 400/500/700 e PlexMono 400/500, para o "depois".
   Uma família nova no pubspec entra sem mudar o harness.
3. **MaterialIcons**, de `bin/cache/artifacts/material_fonts/` do SDK.
4. **Símbolos**: subconjunto da Noto Sans Math + Noto Sans Symbols 2 (OFL),
   registrado com o nome `Poppins`. A Poppins não tem `→` nem `✕`; no
   aparelho o Android completa com a fonte do sistema, e o google_fonts põe
   `Poppins` no `fontFamilyFallback` de todo estilo. Emoji não está coberto
   (nenhuma tela capturada usa).

## Dados de exemplo

Fixos em outubro de 2026, e iguais para o antes e o depois:

- Obra "Sobrado Vila Izabel", Rua das Araucárias, 210, Vila Izabel,
  Curitiba/PR, cliente Família Andrade, orçamento R$ 260.000, de 04/05/2026
  a 26/03/2027.
- 16 lançamentos aprovados somando R$ 112.380,00, 1 rejeitado e 3 pendentes
  somando R$ 4.912,40: "Bloco cerâmico 9 furos" (2.000 un, Casa do
  Construtor, R$ 2.380,00, OCR, com itens), "Areia média" (6 m³, Areial São
  Jorge, R$ 1.290,00, voz) e "Diária de servente (3 dias)" (R$ 1.242,40,
  manual).
- Cronograma com as 10 fases de `AppConstants.fasesPadrao`: Fundação 100%,
  Estrutura 100%, Alvenaria 60%, o resto 0%.
- 5 dias de diário, 7 itens de estoque, 6 fornecedores e mais duas obras na
  lista (uma pausada, uma concluída).
- Pessoas: Marina Souza (dono), Joaquim Pereira (mestre), Paulo Andrade
  (cliente).

## Limitações

- **Data do dia.** Algumas telas usam `DateTime.now()` direto e o teste não
  tem como fixá-lo sem mexer no app: o gráfico "Gastos por semana" (as
  últimas semanas até hoje), a previsão de orçamento, o "Prazo decorrido"
  e as fases em andamento ou atrasadas do cliente, e a data já preenchida
  no novo lançamento. A série "antes" foi gerada em 19/10/2026. Rodada em
  outro dia, essas partes mudam; para comparar, gere o antes e o depois no
  mesmo dia.
- **Sombras.** O flutter_test troca toda sombra por um contorno preto; o
  harness desliga isso (`debugDisableShadows = false`) durante a captura.
- **Fallback de símbolos** é uma aproximação da fonte do sistema Android:
  os poucos símbolos que a Poppins não tem saem na Noto, não na Roboto.
- **Modo debug.** O teste roda em debug: um overflow aparece com a faixa do
  debug (ver o defeito das cenas 08 e 09), coisa que o release não desenha.
- **Câmera e OCR** não estão capturados: a foto da nota passa pelo
  image_picker, que não tem como ser simulado de um jeito fiel.

## Para o "depois"

- Quando o `lib/main.dart` mudar (tema claro e escuro do Prancheta), mude o
  `AppDeCaptura` em `suporte/captura.dart` igual: a captura tem de ser o app
  como ele é.
- `Cena(brilho: Brightness.light)` simula o tema do sistema; para o claro e
  o escuro, registre a cena duas vezes com nomes diferentes.
- Nomes de arquivo iguais aos do antes onde a tela for a mesma, para o lado
  a lado casar.
- Se o tema novo usar `fontFamilyFallback` com outra família, ponha o nome
  em `familiasComFallbackDeSimbolos` (`suporte/fontes.dart`).
- A maquete 3D tem de usar a imagem de reserva nos testes (ver
  `design-system.md`, seção 7).
