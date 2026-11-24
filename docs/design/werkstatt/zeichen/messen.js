// Misst je Zeichen: Tintenkasten (mit Strich), Raender, Mitte, Schwerpunkt, Deckung.
// Aufruf: node messen.js <eingabe.json> <ausgabe.json> [strich]
// eingabe.json: { name: { fragment } } oder { name: "fragment" }
const { chromium } = require('/opt/node-tools/node_modules/playwright');
const fs = require('fs');
(async () => {
  const [ein, ausDatei, strichArg] = process.argv.slice(2);
  const strich = parseFloat(strichArg || '1.75');
  const roh = JSON.parse(fs.readFileSync(ein, 'utf8'));
  const zeichen = {};
  for (const [k, v] of Object.entries(roh)) zeichen[k] = typeof v === 'string' ? v : v.fragment;
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.setContent('<html><body></body></html>');
  const erg = await page.evaluate(async ({ zeichen, strich }) => {
    const K = 20, N = 24 * K;
    const aus = {};
    for (const [name, fragRoh] of Object.entries(zeichen)) {
      const frag = fragRoh.replace(/vector-effect="non-scaling-stroke"/g, '');
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${N}" height="${N}" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="${strich}" stroke-linecap="round" stroke-linejoin="round" color="#fff">${frag}</svg>`;
      const img = new Image();
      await new Promise((ok, nein) => { img.onload = ok; img.onerror = nein; img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg); });
      const c = document.createElement('canvas'); c.width = N; c.height = N;
      const g = c.getContext('2d'); g.drawImage(img, 0, 0);
      const d = g.getImageData(0, 0, N, N).data;
      let x0 = N, y0 = N, x1 = -1, y1 = -1, sum = 0, sx = 0, sy = 0;
      for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
        const a = d[(y * N + x) * 4 + 3] / 255;
        if (a > 0.5) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
        sum += a; sx += a * (x + 0.5); sy += a * (y + 0.5);
      }
      const r = (v) => Math.round(v * 100) / 100;
      const links = x0 / K, oben = y0 / K, rechts = 24 - (x1 + 1) / K, unten = 24 - (y1 + 1) / K;
      aus[name] = {
        links: r(links), oben: r(oben), rechts: r(rechts), unten: r(unten),
        breite: r(24 - links - rechts), hoehe: r(24 - oben - unten),
        mitteX: r((links + 24 - rechts) / 2 - 12), mitteY: r((oben + 24 - unten) / 2 - 12),
        schwerX: r(sx / sum / K - 12), schwerY: r(sy / sum / K - 12),
        deckung: r(sum / (N * N) * 100),
      };
    }
    return aus;
  }, { zeichen, strich });
  fs.writeFileSync(ausDatei, JSON.stringify(erg, null, 1));
  const z = (v) => String(v).padStart(6);
  console.log('name        links  oben  rechts unten | breite hoehe | mitteX mitteY | schwX  schwY | Deckung %');
  for (const [n, m] of Object.entries(erg)) console.log(n.padEnd(11), z(m.links), z(m.oben), z(m.rechts), z(m.unten), '|', z(m.breite), z(m.hoehe), '|', z(m.mitteX), z(m.mitteY), '|', z(m.schwerX), z(m.schwerY), '|', z(m.deckung));
  await browser.close();
})();
