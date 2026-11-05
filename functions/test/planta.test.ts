import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {test} from 'node:test';

import {avaliar} from '../src/avaliar.js';
import {resumirDxf} from '../src/dxf.js';
import {normalizarPlanta} from '../src/planta.js';
import {promptComoVaiFicar, promptLerPlanta} from '../src/prompts.js';
import {custoDaImagem, mesAtual, tipoDoArquivo} from '../src/uso.js';

// Os testes rodam de lib/test/: a planta do app fica três pastas acima.
const exemplo = JSON.parse(
  readFileSync(join(__dirname, '..', '..', '..', 'obra_facil', 'assets', 'plantas', 'casa_7x20.json'), 'utf8'),
);

test('a planta do app passa pela normalização sem mudar', () => {
  const {planta, avisos} = normalizarPlanta(exemplo);
  assert.equal(planta.paredes.length, exemplo.paredes.length);
  assert.equal(planta.comodos.length, exemplo.comodos.length);
  assert.deepEqual(planta.terreno, exemplo.terreno);
  assert.deepEqual(avisos, []);
  const r = avaliar(planta, normalizarPlanta(exemplo).planta);
  assert.equal(r.comodosAchados, r.comodosGabarito);
  assert.equal(r.erroMedioMedidaM, 0);
  assert.equal(r.iouMedio, 1);
});

test('origem negativa é deslocada e vira aviso', () => {
  const {planta, avisos} = normalizarPlanta({
    terreno: {largura: 5, profundidade: 5},
    paredes: [{de: [-1, -1], ate: [4, -1], espessura: 0.15, tipo: 'alvenaria'}],
    comodos: [{nome: 'Sala', coberto: true, retangulos: [{x: -1, y: -1, largura: 5, profundidade: 4}]}],
  });
  assert.deepEqual(planta.paredes[0].de, [0, 0]);
  assert.equal(planta.comodos[0].retangulos[0].x, 0);
  assert.ok(avisos.some((a) => a.includes('origem')));
});

test('lixo da IA não derruba: parede sem comprimento sai, vão fora da parede é cortado', () => {
  const {planta, avisos} = normalizarPlanta({
    alturas: {peDireito: 12},
    paredes: [
      {de: [0, 0], ate: [0, 0], espessura: 0.15, tipo: 'alvenaria'},
      {de: [0, 0], ate: [3, 0], espessura: 9, tipo: 'qualquer', aberturas: [
        {tipo: 'janela', inicio: 2.5, largura: 1.2, peitoril: 1.1, altura: 1},
        {tipo: 'xyz', inicio: -1, largura: 0.05},
      ]},
    ],
    comodos: [{nome: 'Quarto', retangulos: [{x: 0, y: 0, largura: 3, profundidade: -3}]}, {nome: 'Fantasma', retangulos: []}],
  });
  assert.equal(planta.paredes.length, 1);
  const w = planta.paredes[0];
  assert.equal(w.espessura, 0.14);
  assert.equal(w.tipo, 'alvenaria');
  assert.equal(w.aberturas!.length, 1);
  assert.equal(w.aberturas![0].inicio + w.aberturas![0].largura, 3);
  assert.equal(planta.alturas.peDireito, 2.6);
  assert.equal(planta.comodos.length, 1);
  assert.ok(avisos.some((a) => a.includes('Pé-direito')));
  assert.ok(avisos.some((a) => a.includes('Fantasma')));
});

test('ids repetidos ficam únicos', () => {
  const {planta} = normalizarPlanta({
    paredes: [
      {id: 'p1', de: [0, 0], ate: [3, 0], espessura: 0.15, tipo: 'alvenaria'},
      {id: 'p1', de: [0, 0], ate: [0, 3], espessura: 0.15, tipo: 'alvenaria'},
    ],
    comodos: [],
  });
  assert.notEqual(planta.paredes[0].id, planta.paredes[1].id);
});

test('DXF vira texto em metros, com as camadas', () => {
  const dxf = [
    '0', 'SECTION', '2', 'HEADER', '9', '$INSUNITS', '70', '4', '0', 'ENDSEC',
    '0', 'SECTION', '2', 'ENTITIES',
    '0', 'LINE', '8', 'PAREDE', '10', '0', '20', '0', '30', '0', '11', '3500', '21', '0', '31', '0',
    '0', 'TEXT', '8', 'TEXTO', '10', '1000', '20', '1500', '30', '0', '40', '200', '1', 'SALA',
    '0', 'ENDSEC', '0', 'EOF',
  ].join('\n');
  const r = resumirDxf(dxf);
  assert.ok(r.texto.includes('milímetro'));
  assert.ok(r.texto.includes('L 0,0 3.5,0 [PAREDE]'));
  assert.ok(r.texto.includes('T 1,1.5 "SALA"'));
});

test('tipo do arquivo: qualquer formato comum, DWG reconhecido para orientar', () => {
  assert.equal(tipoDoArquivo('planta.PDF'), 'application/pdf');
  assert.equal(tipoDoArquivo('foto.jpeg'), 'image/jpeg');
  assert.equal(tipoDoArquivo('IMG_1.HEIC'), 'image/heic');
  assert.equal(tipoDoArquivo('casa.dxf'), 'dxf');
  assert.equal(tipoDoArquivo('casa.dwg'), 'dwg');
  assert.equal(tipoDoArquivo('sem-extensao', 'image/png'), 'image/png');
  assert.equal(tipoDoArquivo('planilha.xlsx'), 'desconhecido');
});

test('prompts e custos', () => {
  assert.ok(promptLerPlanta.includes('LINHA DE CENTRO'));
  assert.ok(promptLerPlanta.includes('1,20 x 1,00 / 1,10'));
  const fachada = promptComoVaiFicar({tipo: 'fachada', temReferencia: true});
  assert.ok(fachada.includes('SECOND image'));
  assert.ok(fachada.includes('same camera'));
  const quarto = promptComoVaiFicar({tipo: 'comodo', nomeComodo: 'Quarto 2', medidas: '3,23 x 4,10 m', temReferencia: false});
  assert.ok(quarto.includes('Quarto 2'));
  assert.ok(!quarto.includes('SECOND image'));
  assert.equal(custoDaImagem('4K'), 0.24);
  assert.equal(mesAtual(new Date('2026-11-05T12:00:00Z')), '2026-11');
});
