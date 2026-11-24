// Gemeinsames fuer die Boegen: ein Zeichen so setzen, wie Icon.tsx und Zeichen.swift es tun.
const GRUND = '#082431';      // --deep, der Grund der App
const FLAECHE = '#0f2e3d';    // --surface-1
const TEXT1 = 'rgba(255,255,255,0.92)';
const TEXT3 = 'rgba(255,255,255,0.48)';
const AMBER = '#f2a900';
const PETROL = '#0f2e3d';

/** art 'web': Strich in Rastereinheiten (skaliert mit, wie Icon.tsx). art 'app': Strich fest in Punkten (Zeichen.swift). */
function zeichen(fragment, groesse, { art = 'web', strich = 1.75, farbe = TEXT1 } = {}) {
  const sw = art === 'app' ? (strich * 24) / groesse : strich;
  let frag = fragment;
  // In der App gibt es kein non-scaling-stroke; dort ist jeder Strich fest.
  if (art === 'app') frag = frag.replace(/vector-effect="non-scaling-stroke"/g, '');
  return `<svg width="${groesse}" height="${groesse}" viewBox="0 0 24 24" fill="none" stroke="${farbe}" color="${farbe}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" style="display:block">${frag}</svg>`;
}

const KOPF = `<meta charset="utf-8"><style>
  @font-face { font-family: "Plex"; src: url("file:///home/user/DuckCurveHome/apps/web/public/brand/IBMPlexSans-Regular.otf"); }
  @font-face { font-family: "PlexMono"; src: url("file:///home/user/DuckCurveHome/apps/web/public/brand/IBMPlexMono-Regular.otf"); }
  html, body { margin: 0; background: ${GRUND}; color: ${TEXT1}; font-family: Plex, sans-serif; }
  body { padding: 24px; width: max-content; }
  h1 { font-size: 18px; margin: 0 0 4px; font-weight: 600; }
  p.unter { margin: 0 0 18px; font-size: 12px; color: rgba(255,255,255,.6); max-width: 1100px; line-height: 1.4; }
  table { border-collapse: collapse; }
  th { font: 11px PlexMono, monospace; color: rgba(255,255,255,.55); font-weight: 400; padding: 4px 10px; text-align: center; }
  td { padding: 7px 10px; text-align: center; vertical-align: middle; }
  td.name { text-align: left; font: 12px PlexMono, monospace; color: rgba(255,255,255,.75); white-space: nowrap; }
  td.sp { border-left: 1px solid rgba(255,255,255,.12); }
  tr + tr td { border-top: 1px solid rgba(255,255,255,.06); }
  .z { display: inline-flex; align-items: center; justify-content: center; }
</style>`;

async function bild(html, pfad, faktor) {
  const { chromium } = require('/opt/node-tools/node_modules/playwright');
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: faktor, viewport: { width: 1400, height: 900 } });
  const fs = require('fs');
  const tmp = pfad.replace(/\.png$/, '.html');
  fs.writeFileSync(tmp, '<!doctype html><html><head>' + html.replace('</style>', '</style></head><body>') + '</body></html>');
  await page.goto('file://' + require('path').resolve(tmp), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);
  const el = await page.$('body');
  await el.screenshot({ path: pfad });
  const kasten = await el.boundingBox();
  await browser.close();
  return kasten;
}

module.exports = { zeichen, KOPF, bild, GRUND, FLAECHE, TEXT1, TEXT3, AMBER, PETROL };
