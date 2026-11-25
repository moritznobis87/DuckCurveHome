#!/usr/bin/env node
/* Einen Entwurf aufnehmen: Wand und Handy, je Szene.
 *
 *   node docs/design/werkstatt/startseite/grundlage/aufnehmen.cjs <pfad/entwurf.html> [ausgabeordner]
 *
 * Schreibt wand-mittag.png, wand-abend.png, wand-stoerung.png (1280 × 800, ein Schirm),
 * ipad-abend.png (1180 × 820), handy-mittag.png und handy-abend.png (390 breit, die ganze Seite)
 * und handy-abend-oben.png (der erste Schirm, 390 × 844). Es meldet, wenn die Wand über ihren
 * Schirm hinausläuft oder das Handy seitwärts rollt: beides ist ein Fehler des Entwurfs.
 */
const path = require("path");
const { chromium } = require("playwright");

(async () => {
  const html = path.resolve(process.argv[2] || "entwurf.html");
  const aus = path.resolve(process.argv[3] || path.join(path.dirname(html), "bilder"));
  require("fs").mkdirSync(aus, { recursive: true });
  const adresse = (szene) => `file://${html}?szene=${szene}`;
  const browser = await chromium.launch();
  let fehler = 0;

  const aufnahme = async (name, szene, breite, hoehe, faktor, ganz) => {
    const seite = await (await browser.newContext({ viewport: { width: breite, height: hoehe }, deviceScaleFactor: faktor, isMobile: breite < 500, hasTouch: breite < 1300 })).newPage();
    seite.on("pageerror", (e) => { fehler++; console.log(`FEHLER im Skript (${name}): ${e.message}`); });
    await seite.goto(adresse(szene), { waitUntil: "load" });
    await seite.waitForTimeout(900);
    const mass = await seite.evaluate(() => ({ h: document.documentElement.scrollHeight, b: document.documentElement.scrollWidth, ih: innerHeight, ib: innerWidth }));
    if (mass.b > mass.ib + 1) { fehler++; console.log(`FEHLER ${name}: rollt seitwärts (${mass.b} > ${mass.ib}).`); }
    if (!ganz && mass.h > mass.ih + 1) { fehler++; console.log(`FEHLER ${name}: läuft über den Schirm hinaus (${mass.h} > ${mass.ih}). Die Wand rollt nicht.`); }
    await seite.screenshot({ path: path.join(aus, `${name}.png`), fullPage: ganz });
    console.log(`${name}.png  ${breite} × ${ganz ? mass.h : hoehe}`);
    await seite.close();
  };

  await aufnahme("wand-mittag", "mittag", 1280, 800, 1, false);
  await aufnahme("wand-abend", "abend", 1280, 800, 1, false);
  await aufnahme("wand-stoerung", "stoerung", 1280, 800, 1, false);
  await aufnahme("ipad-abend", "abend", 1180, 820, 1, false);
  await aufnahme("handy-mittag", "mittag", 390, 844, 2, true);
  await aufnahme("handy-abend", "abend", 390, 844, 2, true);
  // Der erste Schirm am Handy: was man sieht, bevor man rollt.
  const oben = await (await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true })).newPage();
  await oben.goto(adresse("abend"), { waitUntil: "load" });
  await oben.waitForTimeout(900);
  await oben.screenshot({ path: path.join(aus, "handy-abend-oben.png") });
  console.log("handy-abend-oben.png  390 × 844");
  await browser.close();
  console.log(fehler ? `${fehler} Fehler.` : "Keine Fehler.");
  process.exit(fehler ? 1 : 0);
})();
