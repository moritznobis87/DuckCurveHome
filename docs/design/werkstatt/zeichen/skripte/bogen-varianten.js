// Variantenbogen: Zeilen aus Namen (Bestand oder Variante), je Zeile die Groessen in beiden Stricharten und gross.
// Aufruf: node bogen-varianten.js <varianten.json> <ausgabe.png> <titel> zeile1 zeile2 ...   (zeile = name,name,name ; "alt:name" nimmt den Bestand)
const fs = require('fs');
const { zeichen, KOPF, bild } = require('./gemeinsam');
const [vDatei, ausgabe, titel, ...zeilen] = process.argv.slice(2);
const V = JSON.parse(fs.readFileSync(vDatei, 'utf8'));
const B = JSON.parse(fs.readFileSync(__dirname + '/../bestand.json', 'utf8'));
const hol = (n) => (n.startsWith('alt:') ? B[n.slice(4)].fragment : (typeof V[n] === 'string' ? V[n] : V[n].fragment));
const STUFEN = [[16, 1.5], [20, 1.5], [24, 1.75], [32, 2], [48, 2.5]];
function gross(frag) {
  let raster = '';
  for (let i = 0; i <= 24; i += 1) raster += `<path d="M${i} 0V24M0 ${i}H24" stroke="rgba(255,255,255,${i % 4 === 0 ? 0.2 : 0.07})" stroke-width="0.04"/>`;
  return `<svg width="144" height="144" viewBox="0 0 24 24" style="display:block;background:#0f2e3d">${raster}<rect x="2" y="2" width="20" height="20" fill="none" stroke="#f2a900" stroke-width="0.08" stroke-dasharray="0.4 0.3"/><g fill="none" stroke="rgba(255,255,255,.92)" color="rgba(255,255,255,.92)" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">${frag.replace(/vector-effect="non-scaling-stroke"/g, '')}</g></svg>`;
}
(async () => {
  let h = `${KOPF}<h1>${titel}</h1><p class="unter">Je Fassung: groß auf dem Raster (Strich 1,75), dann 16 · 20 · 24 · 32 · 48 mit dem Strich des Dashboards (wächst mit), darunter mit Strichstufen in Punkten (1,5 · 1,5 · 1,75 · 2 · 2,5).</p>`;
  for (const zeile of zeilen) {
    h += '<div style="display:flex; gap:26px; margin-bottom:22px">';
    for (const n of zeile.split(',')) {
      const f = hol(n);
      h += `<div><div style="font:12px PlexMono,monospace;color:rgba(255,255,255,.8);margin-bottom:4px">${n}</div>${gross(f)}`;
      h += '<div style="display:flex;gap:9px;align-items:center;margin-top:8px">' + STUFEN.map(([g]) => zeichen(f, g, { art: 'web' })).join('') + '</div>';
      h += '<div style="display:flex;gap:9px;align-items:center;margin-top:6px">' + STUFEN.map(([g, s]) => zeichen(f, g, { art: 'app', strich: s })).join('') + '</div></div>';
    }
    h += '</div>';
  }
  const k = await bild(h, ausgabe, 3);
  console.log(Math.round(k.width), 'x', Math.round(k.height));
})();
