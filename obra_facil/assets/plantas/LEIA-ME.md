# Planta de exemplo

`casa_7x20.json` é uma casa térrea num terreno de 7 x 20 m, no formato de
planta do Obra na Mão (`lib/models/planta_obra.dart`).

Origem: o projeto aberto [casa-3d](https://github.com/jobasfernandes/casa-3d),
de Joseph Fernandes, licença MIT (Copyright (c) 2026 Joseph Fernandes). As
medidas vêm de `src/data/planta.ts` daquele projeto, que é conferido contra a
planta desenhada dele. A conversão é refeita com
`ferramentas/planta_exemplo/converter_casa3d.py`.

O que mudou na conversão: as paredes viraram linhas de centro com espessura,
os vãos passaram a ser medidos ao longo da parede, o muro leste (onde a casa
encosta) sobe até o pé-direito e a basculante desligada do banheiro ficou de
fora.
