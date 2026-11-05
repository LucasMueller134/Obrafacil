// Os pedidos ao Gemini. Ficam num arquivo só para ser fácil conferir e
// citar no TCC (e para rodar à mão no AI Studio, ver docs/ia/gemini-planta.md).

/** Ler a planta baixa e devolver o JSON do esquema (planta.ts). */
export const promptLerPlanta = `Você é um arquiteto lendo a planta baixa de uma casa brasileira para montar uma maquete 3D da obra.
Devolva SÓ o JSON do esquema pedido, em metros.

Sistema de coordenadas:
- x cresce para a direita do desenho; y cresce do FUNDO do terreno para a RUA (a frente da casa fica em y máximo).
- Ache a frente pelo desenho ("RUA", "CALÇADA", "PASSEIO", "ACESSO", garagem, portão). Se não houver indício, a parte de baixo do desenho é a frente.
- Origem (0, 0) no canto do terreno do fundo à esquerda. terreno = largura x profundidade do lote; sem lote desenhado, a caixa que envolve a casa.

Paredes:
- Cada parede pela LINHA DE CENTRO, de "de" até "ate", com a espessura (em geral 0,15 externa e 0,10 a 0,15 interna; 0,12 quando o desenho não diz).
- tipo: "alvenaria" (parede da casa), "muro" (divisa do lote, sem laje em cima) ou "mureta_vidro" (mureta com vidro em cima).
- Uma parede reta e contínua vira UMA parede, com os vãos dentro dela. Não quebre a parede em cada porta.

Vãos (aberturas) de cada parede:
- inicio = distância, ao longo da parede, do ponto "de" até o começo do vão; largura = largura do vão.
- tipo: "porta", "porta_correr", "passagem" (vão sem porta), "janela" ou "portao".
- Notação brasileira: janela "1,20 x 1,00 / 1,10" é largura x altura / peitoril; porta "0,80 x 2,10" é largura x altura. Use esses números quando houver.

Cômodos:
- Cada cômodo como um ou mais retângulos (x, y, largura, profundidade) da área INTERNA; o primeiro é o principal.
- nome como está escrito ("Quarto 1", "Sala de estar"...); tipo: quarto, sala, cozinha, banheiro, lavanderia, garagem, varanda, circulacao, despensa, quintal, jardim ou comodo.
- coberto: true se tem laje/telhado em cima (dentro da casa, garagem e varanda cobertas); false para quintal, jardim, corredor lateral descoberto.
- piso quando o desenho indicar (porcelanato, ceramica, cimento, garagem, grama, madeira).

Medidas:
- As COTAS escritas no desenho mandam. Use a escala só onde faltar cota, e diga em "avisos".
- alturas.peDireito: do corte ou da nota ("PD = 2,80"); sem informação, 2,60.
- Confira: os cômodos devem caber entre as paredes, e as medidas dos cômodos devem bater com as áreas escritas (ex.: "A = 12,50 m²").

avisos: em português, curto, uma frase por item, tudo o que ficou incerto (cota ilegível, parede que não fecha, cômodo sem nome, escala estimada).`;

/** Transformar o render da maquete em imagem fotorrealista "como vai ficar". */
export function promptComoVaiFicar(alvo: {
  tipo: 'fachada' | 'comodo';
  nomeComodo?: string;
  medidas?: string;
  piso?: string;
  detalhes?: string;
  temReferencia: boolean;
}): string {
  const base = alvo.tipo === 'fachada'
    ? 'The FIRST image is a plain 3D massing model of a Brazilian house, rendered from the construction app. It shows the exact geometry: walls, openings, roof parapet, lot, street sidewalk.'
    : `The FIRST image is a plain 3D view from INSIDE the room "${alvo.nomeComodo}" (${alvo.medidas ?? ''}) of a Brazilian house, rendered from the construction app with no furniture.`;
  const tarefa = alvo.tipo === 'fachada'
    ? 'Turn it into a photorealistic architectural visualization of the FINISHED house: realistic plaster and paint, window frames and glass, doors, a gate, the sidewalk, a little landscaping inside the lot, soft late-afternoon daylight, a clear sky.'
    : `Turn it into a photorealistic interior photograph of the FINISHED room: ${alvo.piso ? `${alvo.piso} floor, ` : ''}painted walls, ceiling with lights, furnished and decorated as a typical Brazilian ${alvo.nomeComodo?.toLowerCase() ?? 'room'}, natural light through the windows shown in the model.`;
  return [
    base,
    tarefa,
    'Keep EXACTLY the same camera position, lens, perspective and framing as the first image.',
    'Keep EXACTLY the same walls, proportions, number and position of windows and doors. Do not add or remove floors, rooms, windows or doors.',
    alvo.temReferencia
      ? 'The SECOND image is the owner\'s reference illustration: use it ONLY for style, materials and colors, never for the geometry.'
      : 'Use a contemporary Brazilian style: light neutral colors, wood details, simple lines.',
    alvo.detalhes ? `Owner notes: ${alvo.detalhes}` : '',
    'No people, no text, no labels, no watermark, no dimension lines, no dashed lines.',
  ].filter(Boolean).join('\n');
}
