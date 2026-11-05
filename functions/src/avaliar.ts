// Compara a leitura da IA com o gabarito (a planta de verdade): quantos
// cômodos ela achou, o erro das medidas e da área, e se as paredes e os
// vãos batem. É a métrica da leitura da planta para o TCC.
//
//   node lib/src/avaliar.js leitura.json ../obra_facil/assets/plantas/casa_7x20.json

import {readFileSync} from 'node:fs';

import {normalizarPlanta, type Planta} from './planta.js';

const sem = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();

export interface Avaliacao {
  comodosGabarito: number;
  comodosAchados: number;
  /** Cômodos do gabarito com par na leitura (mesmo nome). */
  pares: {nome: string; erroLargura: number; erroProfundidade: number; erroArea: number; iou: number}[];
  erroMedioMedidaM: number;
  erroMedioAreaPct: number;
  iouMedio: number;
  paredesGabarito: number;
  paredesLidas: number;
  vaosGabarito: number;
  vaosLidos: number;
}

function iou(a: {x: number; y: number; largura: number; profundidade: number}, b: typeof a): number {
  const x0 = Math.max(a.x, b.x), y0 = Math.max(a.y, b.y);
  const x1 = Math.min(a.x + a.largura, b.x + b.largura), y1 = Math.min(a.y + a.profundidade, b.y + b.profundidade);
  const inter = Math.max(0, x1 - x0) * Math.max(0, y1 - y0);
  const uniao = a.largura * a.profundidade + b.largura * b.profundidade - inter;
  return uniao > 0 ? inter / uniao : 0;
}

export function avaliar(leitura: Planta, gabarito: Planta): Avaliacao {
  const pares: Avaliacao['pares'] = [];
  for (const g of gabarito.comodos) {
    const l = leitura.comodos.find((c) => sem(c.nome) === sem(g.nome));
    if (!l) continue;
    const rg = g.retangulos[0], rl = l.retangulos[0];
    // Medidas sem orientação (a IA pode trocar largura e profundidade).
    const [ga, gb] = [rg.largura, rg.profundidade].sort((a, b) => a - b);
    const [la, lb] = [rl.largura, rl.profundidade].sort((a, b) => a - b);
    const areaG = g.retangulos.reduce((s, r) => s + r.largura * r.profundidade, 0);
    const areaL = l.retangulos.reduce((s, r) => s + r.largura * r.profundidade, 0);
    pares.push({
      nome: g.nome,
      erroLargura: Math.abs(ga - la),
      erroProfundidade: Math.abs(gb - lb),
      erroArea: areaG > 0 ? Math.abs(areaL - areaG) / areaG : 1,
      iou: iou(rg, rl),
    });
  }
  const media = (v: number[]) => (v.length ? v.reduce((s, x) => s + x, 0) / v.length : 0);
  const vaos = (p: Planta) => p.paredes.reduce((s, w) => s + (w.aberturas?.length ?? 0), 0);
  return {
    comodosGabarito: gabarito.comodos.length,
    comodosAchados: pares.length,
    pares,
    erroMedioMedidaM: media(pares.flatMap((p) => [p.erroLargura, p.erroProfundidade])),
    erroMedioAreaPct: media(pares.map((p) => p.erroArea)) * 100,
    iouMedio: media(pares.map((p) => p.iou)),
    paredesGabarito: gabarito.paredes.length,
    paredesLidas: leitura.paredes.length,
    vaosGabarito: vaos(gabarito),
    vaosLidos: vaos(leitura),
  };
}

if (process.argv[1]?.endsWith('avaliar.js') && process.argv.length >= 4) {
  const ler = (c: string) => normalizarPlanta(JSON.parse(readFileSync(c, 'utf8'))).planta;
  const r = avaliar(ler(process.argv[2]), ler(process.argv[3]));
  console.log(JSON.stringify(r, null, 2));
}
