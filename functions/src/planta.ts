// A planta como dados: o esquema que o Gemini preenche (o mesmo formato do
// app, obra_facil/lib/models/planta_obra.dart) e a normalização do que ele
// devolver. A IA erra medidas: aqui só se garante que o JSON é usável e se
// aponta o que o dono precisa conferir na tela de revisão.

export type Ponto = [number, number];

export interface Abertura {
  id: string;
  tipo: 'porta' | 'porta_correr' | 'passagem' | 'janela' | 'portao';
  inicio: number;
  largura: number;
  peitoril?: number;
  altura?: number;
}

export interface Parede {
  id: string;
  de: Ponto;
  ate: Ponto;
  espessura: number;
  tipo: 'alvenaria' | 'muro' | 'mureta_vidro';
  altura?: number;
  aberturas?: Abertura[];
}

export interface Retangulo {
  x: number;
  y: number;
  largura: number;
  profundidade: number;
}

export interface Comodo {
  id: string;
  nome: string;
  tipo: string;
  coberto: boolean;
  piso: 'porcelanato' | 'ceramica' | 'cimento' | 'garagem' | 'grama' | 'madeira';
  retangulos: Retangulo[];
}

export interface Planta {
  versao: 1;
  nome?: string;
  fonte?: string;
  terreno: {largura: number; profundidade: number};
  frente: 'y+';
  alturas: {peDireito: number; porta: number; muro: number};
  cobertura: {tipo: 'laje_platibanda'};
  paredes: Parede[];
  pilares: {x: number; y: number; lado: number}[];
  comodos: Comodo[];
}

const TIPOS_ABERTURA = ['porta', 'porta_correr', 'passagem', 'janela', 'portao'] as const;
const TIPOS_PAREDE = ['alvenaria', 'muro', 'mureta_vidro'] as const;
const PISOS = ['porcelanato', 'ceramica', 'cimento', 'garagem', 'grama', 'madeira'] as const;

/** O esquema da resposta (subconjunto de JSON Schema que o Gemini aceita). */
export const esquemaPlanta = {
  type: 'object',
  properties: {
    nome: {type: 'string', description: 'Nome do projeto, se houver no desenho.'},
    terreno: {
      type: 'object',
      properties: {
        largura: {type: 'number', description: 'Metros, no eixo x.'},
        profundidade: {type: 'number', description: 'Metros, no eixo y (do fundo para a rua).'},
      },
      required: ['largura', 'profundidade'],
    },
    alturas: {
      type: 'object',
      properties: {
        peDireito: {type: 'number'},
        porta: {type: 'number'},
        muro: {type: 'number'},
      },
    },
    paredes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: {type: 'string'},
          de: {type: 'array', items: {type: 'number'}, minItems: 2, maxItems: 2},
          ate: {type: 'array', items: {type: 'number'}, minItems: 2, maxItems: 2},
          espessura: {type: 'number'},
          tipo: {type: 'string', enum: [...TIPOS_PAREDE]},
          altura: {type: 'number'},
          aberturas: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                id: {type: 'string'},
                tipo: {type: 'string', enum: [...TIPOS_ABERTURA]},
                inicio: {type: 'number', description: 'Metros ao longo da parede, a partir do ponto "de".'},
                largura: {type: 'number'},
                peitoril: {type: 'number'},
                altura: {type: 'number'},
              },
              required: ['tipo', 'inicio', 'largura'],
            },
          },
        },
        required: ['de', 'ate', 'espessura', 'tipo'],
      },
    },
    pilares: {
      type: 'array',
      items: {
        type: 'object',
        properties: {x: {type: 'number'}, y: {type: 'number'}, lado: {type: 'number'}},
        required: ['x', 'y'],
      },
    },
    comodos: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: {type: 'string'},
          nome: {type: 'string'},
          tipo: {type: 'string'},
          coberto: {type: 'boolean'},
          piso: {type: 'string', enum: [...PISOS]},
          retangulos: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                x: {type: 'number'},
                y: {type: 'number'},
                largura: {type: 'number'},
                profundidade: {type: 'number'},
              },
              required: ['x', 'y', 'largura', 'profundidade'],
            },
          },
        },
        required: ['nome', 'coberto', 'retangulos'],
      },
    },
    avisos: {
      type: 'array',
      items: {type: 'string'},
      description: 'O que ficou incerto e precisa ser conferido pelo dono (em português).',
    },
  },
  required: ['terreno', 'paredes', 'comodos'],
} as const;

const num = (v: unknown, padrao = 0): number => {
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : padrao;
};
const r3 = (v: number) => Math.round(v * 1000) / 1000;
const entre = (v: number, a: number, b: number) => Math.min(b, Math.max(a, v));
const umDe = <T extends string>(v: unknown, lista: readonly T[], padrao: T): T =>
  (lista as readonly string[]).includes(String(v)) ? (v as T) : padrao;

/**
 * Deixa a resposta da IA no formato do app: números válidos, ids únicos,
 * espessuras e alturas no plausível, tudo dentro de x, y >= 0 (desloca se
 * a IA usou outra origem), vãos dentro das paredes. Devolve a planta e os
 * avisos (os da IA mais os da normalização).
 */
export function normalizarPlanta(bruta: unknown, fonte?: string): {planta: Planta; avisos: string[]} {
  const b = (bruta ?? {}) as Record<string, any>;
  const avisos: string[] = Array.isArray(b.avisos)
    ? b.avisos.filter((a: unknown) => typeof a === 'string' && a.trim()).map((a: string) => a.trim())
    : [];

  const alt = b.alturas ?? {};
  let peDireito = num(alt.peDireito, 2.6);
  if (peDireito < 2.2 || peDireito > 4.5) {
    avisos.push(`Pé-direito de ${peDireito} m fora do comum: usei 2,60 m. Confira.`);
    peDireito = 2.6;
  }
  const alturas = {
    peDireito,
    porta: entre(num(alt.porta, 2.1), 1.8, 3),
    muro: entre(num(alt.muro, 2.0), 1.0, 3.5),
  };

  const ids = new Set<string>();
  const unico = (base: string) => {
    let id = base.replace(/[^\w-]/g, '-').slice(0, 40) || 'item';
    let k = 2;
    const raiz = id;
    while (ids.has(id)) id = `${raiz}-${k++}`;
    ids.add(id);
    return id;
  };

  const paredes: Parede[] = [];
  for (const [i, w] of (Array.isArray(b.paredes) ? b.paredes : []).entries()) {
    const de: Ponto = [num(w?.de?.[0]), num(w?.de?.[1])];
    const ate: Ponto = [num(w?.ate?.[0]), num(w?.ate?.[1])];
    const comprimento = Math.hypot(ate[0] - de[0], ate[1] - de[1]);
    if (comprimento < 0.05) continue;
    let espessura = num(w?.espessura, 0.14);
    if (espessura < 0.05 || espessura > 0.6) espessura = 0.14;
    const tipo = umDe(w?.tipo, TIPOS_PAREDE, 'alvenaria');
    const aberturas: Abertura[] = [];
    for (const [j, a] of (Array.isArray(w?.aberturas) ? w.aberturas : []).entries()) {
      let inicio = num(a?.inicio);
      let largura = num(a?.largura);
      if (largura <= 0.1) continue;
      inicio = entre(inicio, 0, comprimento);
      largura = Math.min(largura, comprimento - inicio);
      if (largura <= 0.1) continue;
      const tipoA = umDe(a?.tipo, TIPOS_ABERTURA, 'porta');
      const item: Abertura = {id: unico(String(a?.id ?? `v${i + 1}-${j + 1}`)), tipo: tipoA, inicio: r3(inicio), largura: r3(largura)};
      if (a?.peitoril != null) item.peitoril = r3(entre(num(a.peitoril), 0, 2.5));
      if (a?.altura != null) item.altura = r3(entre(num(a.altura), 0.2, 3));
      aberturas.push(item);
    }
    aberturas.sort((x, y) => x.inicio - y.inicio);
    // Vãos sobrepostos: o segundo encolhe até o fim do primeiro.
    for (let k = 1; k < aberturas.length; k++) {
      const ant = aberturas[k - 1];
      const fim = ant.inicio + ant.largura;
      if (aberturas[k].inicio < fim) {
        const novoFim = aberturas[k].inicio + aberturas[k].largura;
        aberturas[k].inicio = r3(fim);
        aberturas[k].largura = r3(Math.max(0, novoFim - fim));
      }
    }
    const p: Parede = {
      id: unico(String(w?.id ?? `p${i + 1}`)),
      de,
      ate,
      espessura: r3(espessura),
      tipo,
      aberturas: aberturas.filter((a) => a.largura > 0.1),
    };
    if (w?.altura != null) p.altura = r3(entre(num(w.altura), 0.3, 5));
    paredes.push(p);
  }

  const comodos: Comodo[] = [];
  for (const [i, c] of (Array.isArray(b.comodos) ? b.comodos : []).entries()) {
    const rets: Retangulo[] = [];
    for (const r of Array.isArray(c?.retangulos) ? c.retangulos : []) {
      const x = num(r?.x), y = num(r?.y);
      let largura = num(r?.largura), profundidade = num(r?.profundidade);
      // Retângulo dado de trás para a frente.
      const rx = largura < 0 ? x + largura : x;
      const ry = profundidade < 0 ? y + profundidade : y;
      largura = Math.abs(largura);
      profundidade = Math.abs(profundidade);
      if (largura < 0.2 || profundidade < 0.2) continue;
      rets.push({x: rx, y: ry, largura: r3(largura), profundidade: r3(profundidade)});
    }
    if (!rets.length) {
      avisos.push(`O cômodo "${c?.nome ?? i + 1}" veio sem medidas e ficou de fora.`);
      continue;
    }
    comodos.push({
      id: unico(String(c?.id ?? c?.nome ?? `c${i + 1}`).toLowerCase()),
      nome: String(c?.nome ?? `Cômodo ${i + 1}`).trim().slice(0, 40) || `Cômodo ${i + 1}`,
      tipo: String(c?.tipo ?? 'comodo').trim().toLowerCase().slice(0, 20) || 'comodo',
      coberto: c?.coberto !== false,
      piso: umDe(c?.piso, PISOS, c?.coberto === false ? 'cimento' : 'porcelanato'),
      retangulos: rets,
    });
  }

  const pilares = (Array.isArray(b.pilares) ? b.pilares : [])
    .map((p: any) => ({x: num(p?.x), y: num(p?.y), lado: r3(entre(num(p?.lado, 0.15), 0.1, 0.6))}));

  // Origem: tudo em x, y >= 0.
  const xs: number[] = [], ys: number[] = [];
  for (const w of paredes) xs.push(w.de[0], w.ate[0]), ys.push(w.de[1], w.ate[1]);
  for (const c of comodos) for (const r of c.retangulos) xs.push(r.x, r.x + r.largura), ys.push(r.y, r.y + r.profundidade);
  // Um muro de divisa pode passar uns centímetros para fora do lote (o
  // muro fica fora dele); só uma origem bem diferente é corrigida.
  const minX = xs.length ? Math.min(...xs) : 0;
  const minY = ys.length ? Math.min(...ys) : 0;
  const dx = minX < -0.25 ? minX : 0;
  const dy = minY < -0.25 ? minY : 0;
  if (dx || dy) {
    avisos.push('A leitura usou outra origem; a planta foi deslocada para o canto do terreno.');
  }
  const mover = (p: Ponto): Ponto => [r3(p[0] - dx), r3(p[1] - dy)];
  for (const w of paredes) {
    w.de = mover(w.de);
    w.ate = mover(w.ate);
  }
  for (const c of comodos) for (const r of c.retangulos) {
    r.x = r3(r.x - dx);
    r.y = r3(r.y - dy);
  }
  for (const p of pilares) {
    p.x = r3(p.x - dx);
    p.y = r3(p.y - dy);
  }

  const maxX = xs.length ? Math.max(...xs) - dx : 0;
  const maxY = ys.length ? Math.max(...ys) - dy : 0;
  let largura = num(b?.terreno?.largura);
  let profundidade = num(b?.terreno?.profundidade);
  if (!(largura >= maxX - 0.25)) largura = maxX;
  if (!(profundidade >= maxY - 0.25)) profundidade = maxY;

  if (!paredes.length) avisos.push('Nenhuma parede foi lida.');
  if (!comodos.length) avisos.push('Nenhum cômodo foi lido.');

  const planta: Planta = {
    versao: 1,
    ...(typeof b.nome === 'string' && b.nome.trim() ? {nome: b.nome.trim().slice(0, 60)} : {}),
    ...(fonte ? {fonte} : {}),
    terreno: {largura: r3(largura), profundidade: r3(profundidade)},
    frente: 'y+',
    alturas,
    cobertura: {tipo: 'laje_platibanda'},
    paredes,
    pilares,
    comodos,
  };
  return {planta, avisos};
}
