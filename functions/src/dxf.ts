// DXF (o arquivo de texto do CAD) em texto curto para o Gemini: as linhas,
// polilinhas e textos com coordenadas, já na unidade do desenho. O DWG é
// binário e fechado (Autodesk): não dá para ler aqui; o app pede para
// exportar em DXF ou PDF.

// O pacote publica o construtor como o próprio módulo CommonJS (os tipos
// dizem export nomeado, que não existe em tempo de execução).
// eslint-disable-next-line @typescript-eslint/no-require-imports
const DxfParser: new () => {parseSync(texto: string): unknown} = require('dxf-parser');

/** $INSUNITS do DXF para metros por unidade. */
const UNIDADES: Record<number, [string, number]> = {
  1: ['polegada', 0.0254],
  2: ['pé', 0.3048],
  4: ['milímetro', 0.001],
  5: ['centímetro', 0.01],
  6: ['metro', 1],
};

export interface ResumoDxf {
  texto: string;
  entidades: number;
  cortado: boolean;
}

/** Resume o DXF em até [maxLinhas] linhas de texto. */
export function resumirDxf(conteudo: string, maxLinhas = 6000): ResumoDxf {
  const dxf: any = new DxfParser().parseSync(conteudo);
  if (!dxf) throw new Error('DXF vazio');
  const codigo = Number(dxf.header?.$INSUNITS ?? 0);
  const [unidade, metros] = UNIDADES[codigo] ?? ['desconhecida (provável milímetro)', 0.001];
  const f = (v: number) => (Math.round(v * metros * 1000) / 1000).toString();
  const linhas: string[] = [];
  let entidades = 0;
  for (const e of dxf.entities ?? []) {
    entidades++;
    const camada = e.layer ? ` [${e.layer}]` : '';
    switch (e.type) {
      case 'LINE':
        if (e.vertices?.length === 2) {
          const [a, b] = e.vertices;
          linhas.push(`L ${f(a.x)},${f(a.y)} ${f(b.x)},${f(b.y)}${camada}`);
        }
        break;
      case 'LWPOLYLINE':
      case 'POLYLINE':
        if (e.vertices?.length) {
          const pts = e.vertices.map((v: any) => `${f(v.x)},${f(v.y)}`).join(' ');
          linhas.push(`P${e.shape || e.closed ? ' fechada' : ''} ${pts}${camada}`);
        }
        break;
      case 'ARC':
        if (e.center) linhas.push(`A centro ${f(e.center.x)},${f(e.center.y)} raio ${f(e.radius ?? 0)}${camada}`);
        break;
      case 'TEXT':
      case 'MTEXT': {
        const p = e.startPoint ?? e.position;
        const t = String(e.text ?? '').replace(/\\P/g, ' ').replace(/[{}]/g, '').trim();
        if (p && t) linhas.push(`T ${f(p.x)},${f(p.y)} "${t.slice(0, 60)}"${camada}`);
        break;
      }
      case 'DIMENSION':
        if (e.actualMeasurement != null) {
          linhas.push(`C ${f(e.actualMeasurement)} m${e.text ? ` "${e.text}"` : ''}${camada}`);
        }
        break;
      default:
        break;
    }
    if (linhas.length >= maxLinhas) break;
  }
  const cortado = linhas.length >= maxLinhas;
  const cabecalho = [
    `Unidade do desenho: ${unidade}. As coordenadas abaixo já estão em metros.`,
    'L = linha (x1,y1 x2,y2); P = polilinha; A = arco; T = texto; C = cota. Entre colchetes, a camada.',
    cortado ? `(Arquivo grande: só as primeiras ${maxLinhas} entidades.)` : '',
  ].filter(Boolean);
  return {texto: [...cabecalho, ...linhas].join('\n'), entidades, cortado};
}
