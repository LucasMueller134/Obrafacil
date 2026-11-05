// Contas de uso: tipo do arquivo, mês do limite e custo estimado.
//
// Preços (Gemini API, plano pago, novembro de 2026; confira em
// ai.google.dev/gemini-api/docs/pricing antes de confiar):
// - leitura (Gemini 3.1 Pro): ~US$ 2 por milhão de tokens de entrada e
//   ~US$ 12 por milhão de saída (raciocínio incluso);
// - imagem (Nano Banana Pro): ~US$ 0,134 em 1K/2K e ~US$ 0,24 em 4K.

export const PRECO_ENTRADA_MILHAO = 2;
export const PRECO_SAIDA_MILHAO = 12;
export const PRECO_IMAGEM: Record<string, number> = {'1K': 0.134, '2K': 0.134, '4K': 0.24};

export function custoDaLeitura(entrada: number, saida: number): number {
  return Math.round((entrada * PRECO_ENTRADA_MILHAO + saida * PRECO_SAIDA_MILHAO) / 1e6 * 10000) / 10000;
}

export function custoDaImagem(tamanho: string): number {
  return PRECO_IMAGEM[tamanho] ?? PRECO_IMAGEM['2K'];
}

/** "2026-11": o limite é por mês. */
export function mesAtual(agora = new Date()): string {
  return agora.toISOString().slice(0, 7);
}

/** O tipo MIME que o Gemini recebe (ou dxf/dwg/desconhecido). */
export function tipoDoArquivo(nome: string, mime?: string): string {
  const ext = nome.toLowerCase().split('.').pop() ?? '';
  if (ext === 'dwg') return 'dwg';
  if (ext === 'dxf' || mime === 'image/vnd.dxf' || mime === 'application/dxf') return 'dxf';
  if (ext === 'pdf' || mime === 'application/pdf') return 'application/pdf';
  if (ext === 'png' || mime === 'image/png') return 'image/png';
  if (ext === 'webp' || mime === 'image/webp') return 'image/webp';
  if (ext === 'heic' || ext === 'heif' || mime === 'image/heic') return 'image/heic';
  if (['jpg', 'jpeg'].includes(ext) || mime === 'image/jpeg') return 'image/jpeg';
  if (mime?.startsWith('image/')) return mime;
  return 'desconhecido';
}
