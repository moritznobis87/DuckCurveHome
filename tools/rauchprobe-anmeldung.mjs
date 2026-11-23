// Rauchprobe der Anmeldung: der ganze Weg im echten Browser, mit virtuellem Authenticator.
//
// Aufruf: tools/rauchprobe-anmeldung.sh (faehrt Dienst und Oberflaeche hoch und raeumt wieder ab).
// Sie hat zwei Fehler gefunden, die keine Einheitenpruefung findet, weil beide erst aus dem
// Zusammenspiel mit Next entstehen - siehe docs/ZUGANG.md, "Geprueft im Browser".
//
// Chrome DevTools Protocol stellt einen Authenticator in Software bereit (WebAuthn-Domain), der
// sich wie ein Telefon verhaelt: auffindbare Schluessel, Nutzerpruefung automatisch bestaetigt.
// Damit laeuft die Zeremonie wirklich durch den Browser - nicht nachgebildet.
// Playwright ist keine Abhaengigkeit dieses Projekts - es wird dort gesucht, wo es liegt
// (global oder im Projekt). Ohne Playwright laeuft diese Probe nicht; alles, was sie prueft, ist
// zusaetzlich auch in apps/api/tests/test_auth.py abgedeckt - nur eben ohne Browser.
import { createRequire } from "node:module";
const verlangen = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = verlangen("playwright"));
} catch {
  console.error(
    "Playwright fehlt. Installieren (z. B. `npm i -g playwright`) oder die Probe ueberspringen.",
  );
  process.exit(2);
}

const BASIS = process.env.BASIS ?? "http://localhost:3000";
const EINLADUNG = process.env.EINLADUNG ?? "";
const BILD = process.env.BILD ?? "/tmp/anmeldung.png";

const schritte = [];
function sagt(text, ok = true) {
  schritte.push(`${ok ? "OK  " : "FEHL"} ${text}`);
  console.log(`${ok ? "OK  " : "FEHL"} ${text}`);
}


// Next im Entwicklungsmodus hydriert spaet; ein Klick davor landet im Nichts, ohne Fehler und
// ohne Spur. Darum: klicken, auf eine Reaktion warten, sonst noch einmal.
async function klickeBisReaktion(seite, knopf, reaktion, versuche = 5) {
  for (let i = 0; i < versuche; i++) {
    await seite.click(knopf);
    try {
      await seite.waitForSelector(reaktion, { timeout: 6000 });
      return true;
    } catch {
      /* noch nicht hydriert - gleich noch einmal */
    }
  }
  return false;
}

const browser = await chromium.launch({ args: ["--no-sandbox"] });
const kontext = await browser.newContext({ viewport: { width: 1280, height: 900 } });
const seite = await kontext.newPage();

// Virtueller Authenticator
const cdp = await kontext.newCDPSession(seite);
await cdp.send("WebAuthn.enable");
const { authenticatorId } = await cdp.send("WebAuthn.addVirtualAuthenticator", {
  options: {
    protocol: "ctap2",
    transport: "internal",
    hasResidentKey: true,
    hasUserVerification: true,
    isUserVerified: true,
    automaticPresenceSimulation: true,
  },
});

seite.on("console", (m) => {
  if (m.type() === "error") console.log("   [browser]", m.text().slice(0, 200));
});

try {
  // 1 - ohne Cookie fuehrt alles auf die Anmeldung
  await seite.goto(`${BASIS}/`, { waitUntil: "domcontentloaded" });
  sagt(`ohne Cookie auf ${new URL(seite.url()).pathname}`, new URL(seite.url()).pathname === "/anmeldung");

  // 2 - der erste Hausherr kommt ueber DCH_ERSTE_PERSON und seinen Link aus dem Protokoll.
  //     Einen Pairing-Link gibt es nicht mehr: er vergab Vollzugriff, stand im Klartext auf einer
  //     Seite und liess sich nicht einzeln widerrufen (ADR-0002, Nachtrag vom 23.11.2026).
  sagt("Einladung des ersten Hausherrn im Protokoll", EINLADUNG.includes("/anmeldung/einrichten?token="));
  if (!EINLADUNG) throw new Error("kein Einladungslink im Protokoll");
  const link = EINLADUNG;

  // 3 - Passkey hinter dem Link anlegen
  const pfad = new URL(link).pathname + new URL(link).search;
  await seite.goto(`${BASIS}${pfad}`, { waitUntil: "domcontentloaded" });
  sagt("Einrichtungsseite nennt die Adresse", (await seite.textContent("body")).includes("moritz@example.org"));
  await seite.fill('input[placeholder="iPhone"]', "Rauchprobe-Geraet");
  const angelegt = await klickeBisReaktion(
    seite,
    'button:has-text("Passkey anlegen")',
    "text=Wiederherstellungscodes",
  );
  sagt("Passkey angelegt", angelegt);
  if (!angelegt) throw new Error("Passkey wurde nicht angelegt");
  const codes = await seite.locator("li.mono").allTextContents();
  sagt(`zehn Wiederherstellungscodes gezeigt (${codes.length})`, codes.length === 10);
  await seite.screenshot({ path: BILD, scale: "css" });

  await seite.click('button:has-text("Habe ich notiert")');
  await seite.waitForURL(`${BASIS}/`, { timeout: 20000 });
  sagt("nach dem Einrichten angemeldet auf der Startseite");

  // 4 - der Dienst kennt jetzt eine Person
  const sitzung = await seite.evaluate(() => fetch("/api/session").then((r) => r.json()));
  sagt(`Sitzung ist eine Person mit Rolle ${sitzung.rolle}`, sitzung.art === "person" && sitzung.rolle === "hausherr");

  // 5 - abmelden und mit Passkey wieder herein
  await seite.goto(`${BASIS}/system/zugang`, { waitUntil: "domcontentloaded" });
  // Die Personenliste holt eine Client-Komponente nach der Hydrierung; darauf muss man warten,
  // sonst liest man den Rumpf, bevor er da ist.
  const gezeigt = await seite
    .waitForSelector("text=moritz@example.org", { timeout: 20000 })
    .then(() => true)
    .catch(() => false);
  sagt("die Verwaltung zeigt die Person", gezeigt);
  const liste = await seite.textContent("body");
  sagt("kein Link mehr, der Zugang vergibt", !liste.includes("/pair?token="));
  // `text-is` und nicht `has-text`: sonst trifft der Selektor auch „Überall abmelden".
  await seite.waitForSelector('button:text-is("Abmelden")', { timeout: 20000 });
  for (let i = 0; i < 6; i++) {
    if (/\/anmeldung/.test(seite.url())) break;
    await seite.click('button:text-is("Abmelden")').catch(() => {});
    try {
      await seite.waitForURL(/\/anmeldung/, { timeout: 5000 });
    } catch {
      /* noch nicht hydriert - gleich noch einmal */
    }
  }
  sagt("abgemeldet, zurueck auf der Anmeldeseite");

  for (let i = 0; i < 6; i++) {
    if (new URL(seite.url()).pathname === "/") break;
    await seite.click('button:has-text("Mit Passkey anmelden")').catch(() => {});
    try {
      await seite.waitForURL(`${BASIS}/`, { timeout: 8000 });
    } catch {
      /* noch nicht hydriert - gleich noch einmal */
    }
  }
  sagt("mit Passkey wieder angemeldet", new URL(seite.url()).pathname === "/");
  const zweite = await seite.evaluate(() => fetch("/api/session").then((r) => r.json()));
  sagt(`wieder als Person (${zweite.name})`, zweite.art === "person");
} catch (fehler) {
  sagt(`abgebrochen: ${String(fehler).split("\n")[0]}`, false);
  await seite.screenshot({ path: BILD, scale: "css" }).catch(() => {});
  process.exitCode = 1;
} finally {
  await cdp.send("WebAuthn.removeVirtualAuthenticator", { authenticatorId }).catch(() => {});
  await browser.close();
  console.log("\n--- Rauchprobe ---");
  for (const z of schritte) console.log(z);
  console.log("Bild:", BILD);
}
