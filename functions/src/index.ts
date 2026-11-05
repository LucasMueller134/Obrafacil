// Cloud Functions do ObraFácil (plano Blaze).
//
// - lerPlanta: a planta da obra (foto, PDF ou DXF) vira o JSON da planta,
//   lido pelo Gemini. Não grava nada: o app mostra a leitura para o dono
//   conferir e só ele confirma (regras do Firestore: só o dono grava a
//   planta).
// - gerarImagem: o render da maquete (fachada ou de dentro de um cômodo)
//   vira a imagem fotorrealista "como vai ficar", com o Nano Banana Pro. A
//   imagem vai para o Storage e os dados dela para obras/{id}/imagens.
//
// A chave do Gemini fica no Secret Manager (GEMINI_API_KEY), nunca no app.
// Só o dono da obra chama; cada obra tem limite de uso (parâmetros abaixo)
// e o custo estimado fica anotado em obras/{id}/uso_ia/{mês}.

import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getDownloadURL, getStorage} from 'firebase-admin/storage';
import {defineInt, defineSecret, defineString} from 'firebase-functions/params';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {GoogleGenAI} from '@google/genai';

import {resumirDxf} from './dxf.js';
import {esquemaPlanta, normalizarPlanta} from './planta.js';
import {promptComoVaiFicar, promptLerPlanta} from './prompts.js';
import {custoDaImagem, custoDaLeitura, mesAtual, tipoDoArquivo} from './uso.js';

initializeApp();

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
/** Lê a planta (multimodal, com raciocínio espacial). */
const MODELO_PLANTA = defineString('MODELO_PLANTA', {default: 'gemini-3.1-pro-preview'});
/** Gera as imagens (Nano Banana Pro). */
const MODELO_IMAGEM = defineString('MODELO_IMAGEM', {default: 'gemini-3-pro-image'});
const LEITURAS_POR_MES = defineInt('LEITURAS_POR_MES', {default: 15});
const IMAGENS_POR_MES = defineInt('IMAGENS_POR_MES', {default: 30});
/** Quantas vezes a mesma vista (fachada ou cômodo) pode ser gerada. */
const GERACOES_POR_VISTA = defineInt('GERACOES_POR_VISTA', {default: 3});

const opcoes = {
  region: 'southamerica-east1',
  secrets: [GEMINI_API_KEY],
  timeoutSeconds: 300,
  memory: '1GiB' as const,
  maxInstances: 5,
};

/** O dono da obra (e só ele) pode gastar com IA nela. */
async function exigirDono(uid: string | undefined, obraId: unknown) {
  if (!uid) throw new HttpsError('unauthenticated', 'Entre na sua conta.');
  if (typeof obraId !== 'string' || !obraId) {
    throw new HttpsError('invalid-argument', 'Obra não informada.');
  }
  const obra = await getFirestore().doc(`obras/${obraId}`).get();
  if (!obra.exists) throw new HttpsError('not-found', 'Obra não encontrada.');
  if (obra.get('donoId') !== uid) {
    throw new HttpsError('permission-denied', 'Só o dono da obra pode fazer isso.');
  }
  return obra;
}

/** Conta um uso no mês, ou recusa se passou do limite. */
async function reservarUso(obraId: string, campo: 'leituras' | 'imagens', limite: number) {
  const ref = getFirestore().doc(`obras/${obraId}/uso_ia/${mesAtual()}`);
  await getFirestore().runTransaction(async (t) => {
    const atual = (await t.get(ref)).get(campo) ?? 0;
    if (atual >= limite) {
      throw new HttpsError('resource-exhausted',
        campo === 'leituras'
          ? `Esta obra já usou as ${limite} leituras de planta do mês.`
          : `Esta obra já gerou as ${limite} imagens do mês.`);
    }
    t.set(ref, {[campo]: FieldValue.increment(1), atualizadoEm: FieldValue.serverTimestamp()}, {merge: true});
  });
  return ref;
}

function bytesDe(base64: unknown, maxMb: number): Buffer {
  if (typeof base64 !== 'string' || !base64) {
    throw new HttpsError('invalid-argument', 'Arquivo não enviado.');
  }
  const b = Buffer.from(base64, 'base64');
  if (b.length > maxMb * 1024 * 1024) {
    throw new HttpsError('invalid-argument', `Arquivo maior que ${maxMb} MB.`);
  }
  return b;
}

export const lerPlanta = onCall(opcoes, async (req) => {
  const {obraId, arquivo} = (req.data ?? {}) as {obraId?: string; arquivo?: {nome?: string; base64?: string; tipo?: string}};
  await exigirDono(req.auth?.uid, obraId);
  const nome = String(arquivo?.nome ?? 'planta');
  const tipo = tipoDoArquivo(nome, arquivo?.tipo);
  if (tipo === 'dwg') {
    throw new HttpsError('invalid-argument',
      'DWG é um formato fechado do AutoCAD. Exporte a planta em PDF ou DXF (Arquivo > Exportar) e envie de novo.');
  }
  if (tipo === 'desconhecido') {
    throw new HttpsError('invalid-argument', 'Envie a planta como foto, PDF ou DXF.');
  }
  const bytes = bytesDe(arquivo?.base64, 9);
  const usoRef = await reservarUso(obraId!, 'leituras', LEITURAS_POR_MES.value());

  const partes: any[] = [{text: promptLerPlanta}];
  if (tipo === 'dxf') {
    const resumo = resumirDxf(bytes.toString('utf8'));
    partes.push({text: `Conteúdo do DXF (${resumo.entidades} entidades):\n${resumo.texto}`});
  } else {
    partes.push({inlineData: {mimeType: tipo, data: bytes.toString('base64')}});
  }

  const ai = new GoogleGenAI({apiKey: GEMINI_API_KEY.value()});
  let resposta;
  try {
    resposta = await ai.models.generateContent({
      model: MODELO_PLANTA.value(),
      contents: [{role: 'user', parts: partes}],
      config: {
        temperature: 0,
        responseMimeType: 'application/json',
        responseJsonSchema: esquemaPlanta,
      },
    });
  } catch (erro) {
    console.error('lerPlanta: Gemini falhou', erro);
    throw new HttpsError('unavailable', 'A leitura da planta falhou. Tente de novo em alguns minutos.');
  }
  let bruta: unknown;
  try {
    bruta = JSON.parse(resposta.text ?? '');
  } catch {
    throw new HttpsError('internal', 'A IA não devolveu uma planta legível. Tente uma foto mais nítida ou o PDF.');
  }
  const {planta, avisos} = normalizarPlanta(bruta, `lida pela IA (${MODELO_PLANTA.value()}) de "${nome}"`);
  const u = resposta.usageMetadata;
  const custo = custoDaLeitura(u?.promptTokenCount ?? 0, (u?.candidatesTokenCount ?? 0) + (u?.thoughtsTokenCount ?? 0));
  await usoRef.set({custoUsd: FieldValue.increment(custo), tokens: FieldValue.increment(u?.totalTokenCount ?? 0)}, {merge: true});
  return {planta, avisos, modelo: MODELO_PLANTA.value(), custoUsd: custo};
});

export const gerarImagem = onCall(opcoes, async (req) => {
  const d = (req.data ?? {}) as {
    obraId?: string;
    vista?: string; // 'fachada' ou o id do cômodo
    guia?: string; // PNG da maquete (base64), do ângulo escolhido
    referencia?: string; // ilustração do dono (base64), opcional
    referenciaTipo?: string;
    nomeComodo?: string;
    medidas?: string;
    piso?: string;
    detalhes?: string;
  };
  await exigirDono(req.auth?.uid, d.obraId);
  const vista = String(d.vista ?? 'fachada').replace(/[^\w-]/g, '-').slice(0, 40) || 'fachada';
  const guia = bytesDe(d.guia, 8);
  const referencia = d.referencia ? bytesDe(d.referencia, 8) : null;

  const db = getFirestore();
  const imagemRef = db.doc(`obras/${d.obraId}/imagens/${vista}`);
  const anterior = await imagemRef.get();
  const geracoes = (anterior.get('geracoes') ?? 0) as number;
  if (geracoes >= GERACOES_POR_VISTA.value()) {
    throw new HttpsError('resource-exhausted',
      `Esta vista já foi gerada ${geracoes} vezes, o limite. Escolha outro ângulo ou outro cômodo.`);
  }
  const usoRef = await reservarUso(d.obraId!, 'imagens', IMAGENS_POR_MES.value());

  const ehFachada = vista === 'fachada';
  // A melhor qualidade em tudo (pedido do dono): 4K, ~US$ 0,24 a imagem.
  const tamanho = '4K';
  const partes: any[] = [
    {text: promptComoVaiFicar({
      tipo: ehFachada ? 'fachada' : 'comodo',
      nomeComodo: d.nomeComodo,
      medidas: d.medidas,
      piso: d.piso,
      detalhes: typeof d.detalhes === 'string' ? d.detalhes.slice(0, 300) : undefined,
      temReferencia: referencia != null,
    })},
    {inlineData: {mimeType: 'image/png', data: guia.toString('base64')}},
  ];
  if (referencia) {
    partes.push({inlineData: {mimeType: d.referenciaTipo || 'image/jpeg', data: referencia.toString('base64')}});
  }

  const ai = new GoogleGenAI({apiKey: GEMINI_API_KEY.value()});
  let resposta;
  try {
    resposta = await ai.models.generateContent({
      model: MODELO_IMAGEM.value(),
      contents: [{role: 'user', parts: partes}],
      config: {
        responseModalities: ['IMAGE'],
        imageConfig: {aspectRatio: ehFachada ? '3:2' : '4:3', imageSize: tamanho},
      },
    });
  } catch (erro) {
    console.error('gerarImagem: Gemini falhou', erro);
    throw new HttpsError('unavailable', 'A imagem não foi gerada. Tente de novo em alguns minutos.');
  }
  const parte = resposta.candidates?.[0]?.content?.parts?.find((p) => p.inlineData?.data);
  if (!parte?.inlineData?.data) {
    throw new HttpsError('internal', 'O modelo não devolveu imagem (pode ter recusado o pedido). Tente outro ângulo.');
  }
  const mime = parte.inlineData.mimeType ?? 'image/png';
  const extensao = mime.includes('jpeg') ? 'jpg' : 'png';
  const caminho = `obras/${d.obraId}/imagens/${vista}-${Date.now()}.${extensao}`;
  const arquivo = getStorage().bucket().file(caminho);
  await arquivo.save(Buffer.from(parte.inlineData.data, 'base64'), {contentType: mime, resumable: false});
  const url = await getDownloadURL(arquivo);

  const custo = custoDaImagem(tamanho);
  await imagemRef.set({
    vista,
    nome: ehFachada ? 'Fachada' : (d.nomeComodo ?? vista),
    url,
    caminho,
    modelo: MODELO_IMAGEM.value(),
    tamanho,
    geracoes: geracoes + 1,
    custoUsd: FieldValue.increment(custo),
    criadaEm: FieldValue.serverTimestamp(),
  }, {merge: true});
  await usoRef.set({custoUsd: FieldValue.increment(custo)}, {merge: true});
  return {url, vista, geracoes: geracoes + 1, restantes: GERACOES_POR_VISTA.value() - geracoes - 1, custoUsd: custo};
});
