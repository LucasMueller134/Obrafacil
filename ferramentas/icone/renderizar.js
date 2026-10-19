// Rasteriza SVG em PNG com o Chromium do Playwright, no tamanho final e em
// escala 1:1 (como o aparelho faria), com fundo transparente.
// Chamado pelo exportar.py; não precisa rodar à mão.
//
//   node renderizar.js tarefas.json
//   tarefas.json: [{"svg": "/abs/a.svg", "png": "/abs/a.png", "lado": 96}, ...]
//
// O Playwright vem de PLAYWRIGHT_MODULE (caminho da pasta
// node_modules/playwright) ou do require normal do Node.
const fs = require('fs');

function carregarPlaywright() {
  const caminho = process.env.PLAYWRIGHT_MODULE;
  try {
    return require(caminho || 'playwright');
  } catch (erro) {
    console.error(
      'Playwright não encontrado. Instale com "npm i playwright" e ' +
      '"npx playwright install chromium", ou aponte PLAYWRIGHT_MODULE para ' +
      'a pasta node_modules/playwright.');
    throw erro;
  }
}

(async () => {
  const { chromium } = carregarPlaywright();
  const tarefas = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const navegador = await chromium.launch();
  const pagina = await (await navegador.newContext({ deviceScaleFactor: 1 })).newPage();
  for (const t of tarefas) {
    const svg = fs.readFileSync(t.svg).toString('base64');
    await pagina.setViewportSize({ width: t.lado, height: t.lado });
    await pagina.setContent(
      '<html><head><style>html,body{margin:0;padding:0;background:transparent}</style></head>' +
      `<body><img id="i" src="data:image/svg+xml;base64,${svg}" ` +
      `width="${t.lado}" height="${t.lado}" style="display:block"></body></html>`);
    await pagina.waitForFunction(() => {
      const i = document.getElementById('i');
      return i.complete && i.naturalWidth > 0;
    });
    await pagina.screenshot({
      path: t.png, omitBackground: true,
      clip: { x: 0, y: 0, width: t.lado, height: t.lado },
    });
  }
  await navegador.close();
})().catch((erro) => { console.error(erro); process.exit(1); });
