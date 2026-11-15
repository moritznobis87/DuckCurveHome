"use client";

// Alfred, der Helfer unten rechts (docs/ALFRED.md).
//
// Ohne Sprachmodell erklärt er die Seite und sagt, wo was steht - vorbereitete Texte, nichts
// verlässt das Haus. Mit Modell beantwortet er getippte oder gesprochene Fragen zu den Daten des
// Hauses, schlägt Schaltungen vor (ausgeführt erst auf Knopfdruck), liest Rechnungen anderer
// Anbieter und schlägt bei der Einrichtung die Sensorzuordnung vor.
//
// Der Anbieter des Modells bleibt der Oberfläche unbekannt: Sie schickt eine Frage an die eigene
// API und bekommt Nachrichten zurück. Nur seinen Namen zeigt sie, weil die KI-Verordnung es
// verlangt (Art. 50).
//
// Gäste sehen nur die vorbereiteten Texte: Das BFF lässt für sie kein POST durch, und ein Feld,
// das nichts beantwortet, ist schlimmer als keines.

import { useCallback, useEffect, useId, useRef, useState } from "react";
import { usePathname } from "next/navigation";

import { useRole } from "@/lib/live/useRole";
import { TEXTE, ortBestimmen, wissen } from "./hilfetexte";
import { schrittText, stromLesen, verlaufFuerServer, vorschlagAufruf, vorschlagText, type Vorschlag } from "./strom";

export interface Nachricht {
  kennung: string;
  wer: "alfred" | "nutzer";
  inhalt: string;
  /** "modell" trägt die KI-Marke. Vorbereitete Texte haben keine. */
  quelle?: "modell";
}

type Zustand = { bereit: boolean; anbieter: string | null };

type Rechnungsergebnis = {
  gelesen: { anbieter: string | null; von: string | null; bis: string | null; kwh: number | null; brutto_eur: number | null; arbeitspreis_ct_kwh: number | null };
  mittlerer_preis_ct_kwh: number | null;
  gemessen_kwh: number | null;
  abdeckung: number | null;
  befunde: { stufe: string; titel: string; text: string }[];
};

type Zuordnungsergebnis = { zeilen: { schluessel: string; entitaet: string; grund: string }[]; verworfen: string[]; offen: string[]; yaml: string };

/** Pfade ohne Alfred: dort gibt es keine Anwendung, in der man sich orientieren müsste. */
const OHNE_ALFRED = [/^\/locked/, /^\/pair/];

let laufendeNummer = 0;
const naechsteKennung = () => `alfred-${++laufendeNummer}`;

/** Kurzer Text aus `**fett**` - mehr Auszeichnung schreibt Alfred nicht. */
function mitFettdruck(text: string): React.ReactNode[] {
  return text.split(/(\*\*[^*]+\*\*)/g).map((teil, i) =>
    teil.startsWith("**") && teil.endsWith("**") ? <strong key={i}>{teil.slice(2, -2)}</strong> : <span key={i}>{teil}</span>,
  );
}

function ersetze(text: string, werte: Record<string, string>): string {
  return text.replace(/\{(\w+)\}/g, (_, k: string) => werte[k] ?? `{${k}}`);
}

/** Die Spracherkennung des Browsers, falls vorhanden (Safari und Chrome mit Präfix). */
type Erkennung = {
  lang: string;
  interimResults: boolean;
  maxAlternatives: number;
  onresult: ((e: { results: ArrayLike<ArrayLike<{ transcript: string }>> }) => void) | null;
  onend: (() => void) | null;
  onerror: (() => void) | null;
  start: () => void;
  stop: () => void;
};
function erkennungBauen(): Erkennung | null {
  if (typeof window === "undefined") return null;
  const w = window as unknown as { SpeechRecognition?: new () => Erkennung; webkitSpeechRecognition?: new () => Erkennung };
  const Klasse = w.SpeechRecognition ?? w.webkitSpeechRecognition;
  return Klasse ? new Klasse() : null;
}

export function Alfred() {
  const pfad = usePathname() ?? "/";
  const rolle = useRole();
  const [offen, setOffen] = useState(false);
  const [nachrichten, setNachrichten] = useState<Nachricht[]>([]);
  const [zustand, setZustand] = useState<Zustand | null>(null);
  const [frage, setFrage] = useState("");
  const [laeuft, setLaeuft] = useState(false);
  const [schritt, setSchritt] = useState<string | null>(null);
  const [vorschlaege, setVorschlaege] = useState<Vorschlag[]>([]);
  const [fuehrtAus, setFuehrtAus] = useState<string | null>(null);
  const [hoert, setHoert] = useState(false);
  const [werkzeug, setWerkzeug] = useState<"rechnung" | "zuordnung" | null>(null);
  const [liste, setListe] = useState("");
  const [zuordnung, setZuordnung] = useState<Zuordnungsergebnis | null>(null);
  const [kopiert, setKopiert] = useState(false);
  const huelle = useRef<HTMLDivElement>(null);
  const knopf = useRef<HTMLButtonElement>(null);
  const datei = useRef<HTMLInputElement>(null);
  const erkennung = useRef<Erkennung | null>(null);
  const ende = useRef<HTMLDivElement>(null);
  const feldKennung = useId();
  const [kannSprechen, setKannSprechen] = useState(false);

  const darfFragen = Boolean(zustand?.bereit) && rolle === "owner";
  const anbieter = zustand?.anbieter ?? "dem Anbieter";

  useEffect(() => setKannSprechen(erkennungBauen() !== null), []);

  // Die jüngste Nachricht ins Bild rollen; jsdom kennt scrollIntoView nicht, daher optional.
  useEffect(() => {
    if (offen) ende.current?.scrollIntoView?.({ block: "nearest" });
  }, [nachrichten, offen]);

  const zumachen = useCallback(() => {
    setOffen(false);
    erkennung.current?.stop();
    knopf.current?.focus();
  }, []);

  // Escape und Klick daneben schließen; nur bei offenem Panel registriert.
  useEffect(() => {
    if (!offen) return;
    const taste = (e: KeyboardEvent) => e.key === "Escape" && zumachen();
    const daneben = (e: PointerEvent) => {
      if (!huelle.current?.contains(e.target as Node)) setOffen(false);
    };
    document.addEventListener("keydown", taste);
    document.addEventListener("pointerdown", daneben);
    return () => {
      document.removeEventListener("keydown", taste);
      document.removeEventListener("pointerdown", daneben);
    };
  }, [offen, zumachen]);

  // Einmal beim ersten Öffnen: Ist ein Modell eingerichtet? Liest nur eine Einstellung.
  useEffect(() => {
    if (!offen || zustand !== null) return;
    let lebt = true;
    fetch("/api/dch/alfred/status", { cache: "no-store" })
      .then((a) => (a.ok ? a.json() : { bereit: false }))
      .then((d: { bereit?: boolean; anbieter?: string | null }) => lebt && setZustand({ bereit: Boolean(d.bereit), anbieter: d.anbieter ?? null }))
      .catch(() => lebt && setZustand({ bereit: false, anbieter: null }));
    return () => {
      lebt = false;
    };
  }, [offen, zustand]);

  const sagen = (inhalt: string, quelle?: "modell") =>
    setNachrichten((bisher) => [...bisher, { kennung: naechsteKennung(), wer: "alfred", inhalt, ...(quelle ? { quelle } : {}) }]);

  const aufmachen = () => {
    if (offen) return zumachen();
    if (nachrichten.length === 0) setNachrichten([{ kennung: naechsteKennung(), wer: "alfred", inhalt: TEXTE.begruessung }]);
    setOffen(true);
  };

  const seiteErklaeren = () => sagen(ortBestimmen(pfad).text ?? TEXTE.keineSeitenhilfe);

  const fragen = async (text: string) => {
    const gefragt = text.trim();
    if (!gefragt || laeuft) return;
    setFrage("");
    setLaeuft(true);
    setVorschlaege([]);
    const verlauf = verlaufFuerServer(nachrichten);
    setNachrichten((bisher) => [...bisher, { kennung: naechsteKennung(), wer: "nutzer", inhalt: gefragt }]);
    try {
      const antwort = await fetch("/api/dch/alfred/ask/stream", {
        method: "POST",
        headers: { "content-type": "application/json", accept: "text/event-stream" },
        body: JSON.stringify({ frage: gefragt, wissen: wissen(pfad), verlauf }),
      });
      if (!antwort.ok) {
        // Die Tagesgrenze ist ein vorgesehener Zustand und kommt vor dem ersten Byte als 429.
        const rumpf = (await antwort.json().catch(() => null)) as { error?: { code?: string } } | null;
        sagen(rumpf?.error?.code === "zu_viele_fragen" ? TEXTE.frageTagesgrenze : TEXTE.frageFehler);
        return;
      }
      await stromLesen(antwort, {
        schritt: (s) => setSchritt(schrittText(s, TEXTE)),
        antwort: (d) => {
          if (d.bereit) sagen(d.antwort, "modell");
          else sagen(TEXTE.frageOhneModell);
          setVorschlaege(d.vorschlaege ?? []);
        },
        fehler: () => sagen(TEXTE.frageFehler),
      });
    } catch {
      sagen(TEXTE.frageFehler);
    } finally {
      setLaeuft(false);
      setSchritt(null);
    }
  };

  /** Führt einen Vorschlag aus; der einzige schaltende Vorgang dieses Panels. Er geht an dieselben
   *  Endpunkte wie die Schalter der Seiten, mit deren Prüfungen und dem Urheber im Protokoll. */
  const ausfuehren = async (v: Vorschlag) => {
    const schluessel = `${v.art}-${v.ziel}`;
    if (fuehrtAus) return;
    setFuehrtAus(schluessel);
    try {
      const { pfad: ziel, rumpf } = vorschlagAufruf(v);
      const antwort = await fetch(ziel, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(rumpf) });
      const daten = (await antwort.json().catch(() => null)) as { ok?: boolean; message_de?: string } | null;
      if (!antwort.ok || daten?.ok === false) throw new Error(daten?.message_de ?? String(antwort.status));
      setVorschlaege((bisher) => bisher.filter((x) => `${x.art}-${x.ziel}` !== schluessel));
      sagen(daten?.message_de ?? `${vorschlagText(v)}: erledigt.`);
    } catch (e) {
      const text = e instanceof Error && e.message && !/^\d+$/.test(e.message) ? e.message : TEXTE.vorschlagFehler;
      sagen(text);
    } finally {
      setFuehrtAus(null);
    }
  };

  const sprechen = () => {
    if (hoert) return erkennung.current?.stop();
    const e = erkennungBauen();
    if (!e) return;
    e.lang = "de-DE";
    e.interimResults = false;
    e.maxAlternatives = 1;
    e.onresult = (ereignis) => {
      const text = ereignis.results[0]?.[0]?.transcript ?? "";
      if (text) void fragen(text);
    };
    e.onend = () => setHoert(false);
    e.onerror = () => setHoert(false);
    erkennung.current = e;
    setHoert(true);
    e.start();
  };

  const rechnungPruefen = async (f: File) => {
    setLaeuft(true);
    setSchritt(TEXTE.rechnungLaeuft);
    setNachrichten((bisher) => [...bisher, { kennung: naechsteKennung(), wer: "nutzer", inhalt: f.name }]);
    try {
      const antwort = await fetch("/api/dch/alfred/rechnung", { method: "POST", headers: { "content-type": "application/pdf" }, body: f });
      const daten = (await antwort.json().catch(() => null)) as (Rechnungsergebnis & { error?: { message?: string } }) | null;
      if (!antwort.ok || !daten) return sagen(daten?.error?.message ?? TEXTE.frageFehler);
      sagen(rechnungZusammenfassung(daten), "modell");
    } catch {
      sagen(TEXTE.frageFehler);
    } finally {
      setLaeuft(false);
      setSchritt(null);
      setWerkzeug(null);
      if (datei.current) datei.current.value = "";
    }
  };

  const zuordnen = async () => {
    if (!liste.trim()) return;
    setLaeuft(true);
    setSchritt(TEXTE.zuordnungLaeuft);
    setZuordnung(null);
    try {
      const antwort = await fetch("/api/dch/alfred/zuordnung", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ liste }) });
      const daten = (await antwort.json().catch(() => null)) as (Zuordnungsergebnis & { error?: { message?: string } }) | null;
      if (!antwort.ok || !daten) return sagen(daten?.error?.message ?? TEXTE.frageFehler);
      setZuordnung(daten);
    } catch {
      sagen(TEXTE.frageFehler);
    } finally {
      setLaeuft(false);
      setSchritt(null);
    }
  };

  if (OHNE_ALFRED.some((re) => re.test(pfad))) return null;
  const hatGefragt = nachrichten.some((n) => n.wer === "nutzer");

  return (
    <div className="alfred" ref={huelle}>
      {offen ? (
        <div className="alfred-feld" id={feldKennung} role="dialog" aria-label={TEXTE.name}>
          <div className="alfred-kopf">
            <span className="alfred-name">{TEXTE.name}</span>
            <button type="button" className="alfred-zu" onClick={zumachen} aria-label={TEXTE.schliessen}>
              ×
            </button>
          </div>

          <div className="alfred-verlauf">
            {nachrichten.map((n) => (
              <p key={n.kennung} className={`alfred-sprechblase ${n.wer === "alfred" ? "von-alfred" : "von-nutzer"}${n.quelle === "modell" ? " ki" : ""}`}>
                {n.quelle === "modell" ? <span className="alfred-ki">{TEXTE.kiMarke}</span> : null}
                {mitFettdruck(n.inhalt)}
              </p>
            ))}
            <div ref={ende} />
          </div>

          {vorschlaege.length > 0 ? (
            <div className="alfred-vorschlaege-liste">
              <p className="titel">{TEXTE.vorschlagTitel}</p>
              <ul>
                {vorschlaege.map((v) => (
                  <li key={`${v.art}-${v.ziel}`}>
                    <span className="was">{vorschlagText(v)}</span>
                    <button type="button" disabled={fuehrtAus !== null} onClick={() => void ausfuehren(v)}>
                      {fuehrtAus === `${v.art}-${v.ziel}` ? TEXTE.vorschlagLaeuft : TEXTE.vorschlagAusfuehren}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {hatGefragt ? null : (
            <div className="alfred-vorschlaege">
              <button type="button" onClick={seiteErklaeren}>
                {TEXTE.seiteErklaeren}
              </button>
              <button type="button" onClick={() => sagen(zustand?.bereit ? TEXTE.antwortWasKannAlfred : TEXTE.antwortWasKannAlfredOhneModell)}>
                {TEXTE.wasKannAlfred}
              </button>
              {darfFragen
                ? TEXTE.beispiele.map((b) => (
                    <button key={b} type="button" disabled={laeuft} onClick={() => void fragen(b)}>
                      {b}
                    </button>
                  ))
                : null}
            </div>
          )}

          {darfFragen ? (
            <div className="alfred-werkzeuge">
              <button type="button" disabled={laeuft} aria-pressed={werkzeug === "rechnung"} onClick={() => { setWerkzeug("rechnung"); datei.current?.click(); }}>
                {TEXTE.rechnungKnopf}
              </button>
              <button type="button" disabled={laeuft} aria-pressed={werkzeug === "zuordnung"} onClick={() => setWerkzeug(werkzeug === "zuordnung" ? null : "zuordnung")}>
                {TEXTE.zuordnungKnopf}
              </button>
              <input
                ref={datei}
                type="file"
                accept="application/pdf"
                hidden
                data-testid="alfred-rechnung"
                onChange={(e) => {
                  const f = e.target.files?.[0];
                  if (f) void rechnungPruefen(f);
                }}
              />
            </div>
          ) : null}
          {darfFragen && werkzeug === "rechnung" ? <p className="alfred-stufe">{ersetze(TEXTE.rechnungHinweis, { anbieter })}</p> : null}

          {darfFragen && werkzeug === "zuordnung" ? (
            <div className="alfred-zuordnung">
              <textarea value={liste} rows={5} placeholder={TEXTE.zuordnungFeld} aria-label={TEXTE.zuordnungFeld} onChange={(e) => setListe(e.target.value)} />
              <button type="button" disabled={laeuft || !liste.trim()} onClick={() => void zuordnen()}>
                {TEXTE.zuordnungSenden}
              </button>
              {zuordnung ? (
                <div className="alfred-zuordnung-ergebnis">
                  {zuordnung.yaml ? (
                    <>
                      <pre>{zuordnung.yaml}</pre>
                      <button
                        type="button"
                        onClick={() => {
                          void navigator.clipboard?.writeText(zuordnung.yaml).then(() => setKopiert(true));
                        }}
                      >
                        {kopiert ? TEXTE.zuordnungKopiert : TEXTE.zuordnungKopieren}
                      </button>
                    </>
                  ) : null}
                  {zuordnung.offen.length ? <p>Offen: {zuordnung.offen.join(", ")}</p> : null}
                  {zuordnung.verworfen.length ? <p>Verworfen: {zuordnung.verworfen.join("; ")}</p> : null}
                </div>
              ) : null}
            </div>
          ) : null}

          {darfFragen ? (
            <form
              className="alfred-frage"
              onSubmit={(e) => {
                e.preventDefault();
                void fragen(frage);
              }}
            >
              <input type="text" value={frage} placeholder={TEXTE.frageFeld} aria-label={TEXTE.frageFeld} maxLength={1000} disabled={laeuft} onChange={(e) => setFrage(e.target.value)} />
              {kannSprechen ? (
                <button type="button" className={`alfred-mikro${hoert ? " an" : ""}`} onClick={sprechen} disabled={laeuft} aria-label={hoert ? TEXTE.mikrofonLaeuft : TEXTE.mikrofon} title={TEXTE.mikrofonHinweis}>
                  <svg viewBox="0 0 24 24" aria-hidden="true" width="16" height="16">
                    <path d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Zm-7 9a7 7 0 0 0 14 0M12 19v3" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
                  </svg>
                </button>
              ) : null}
              <button type="submit" disabled={laeuft || !frage.trim()}>
                {laeuft ? TEXTE.frageLaeuft : TEXTE.frageSenden}
              </button>
            </form>
          ) : null}

          {laeuft || hoert ? (
            <p className="alfred-schritt" aria-live="polite">
              {hoert ? TEXTE.mikrofonLaeuft : (schritt ?? TEXTE.frageLaeuft)}
            </p>
          ) : null}

          {zustand === null ? null : <p className="alfred-stufe">{zustand.bereit ? ersetze(TEXTE.hinweisModell, { anbieter }) : TEXTE.hinweisOhneModell}</p>}
        </div>
      ) : null}

      <button type="button" ref={knopf} className="alfred-button" onClick={aufmachen} title={TEXTE.ansprechen} aria-label={TEXTE.ansprechen} aria-expanded={offen} aria-controls={offen ? feldKennung : undefined}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/brand/ente-maskottchen.svg" alt="" aria-hidden="true" />
      </button>
    </div>
  );
}

/** Das Ergebnis der Rechnungsprüfung als Text. Die gelesenen Werte stammen vom Modell (daher die
 *  KI-Marke), Vergleich und Befunde rechnet der Dienst. */
export function rechnungZusammenfassung(r: Rechnungsergebnis): string {
  const zahl = (x: number | null | undefined, stellen = 0) => (x == null ? "?" : x.toLocaleString("de-DE", { maximumFractionDigits: stellen }));
  const datum = (d: string | null) => (d ? new Date(`${d}T12:00:00`).toLocaleDateString("de-DE") : "?");
  const g = r.gelesen;
  const zeilen = [
    `**${g.anbieter ?? "Rechnung"}**, ${datum(g.von)} bis ${datum(g.bis)}: ${zahl(g.kwh)} kWh, ${zahl(g.brutto_eur, 2)} € brutto` +
      (r.mittlerer_preis_ct_kwh != null ? `, im Mittel ${zahl(r.mittlerer_preis_ct_kwh, 2)} ct/kWh.` : "."),
  ];
  if (r.gemessen_kwh != null) zeilen.push(`Eigene Messung: ${zahl(r.gemessen_kwh)} kWh (Abdeckung ${zahl((r.abdeckung ?? 0) * 100)} %).`);
  for (const b of r.befunde) zeilen.push(`${b.stufe === "warning" ? "⚠ " : ""}${b.titel}: ${b.text}`);
  return zeilen.join("\n");
}
