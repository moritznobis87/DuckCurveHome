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
import Link from "next/link";
import { usePathname } from "next/navigation";

import { useRole } from "@/lib/live/useRole";
import { TEXTE, ortBestimmen, wissen } from "./hilfetexte";
import { schrittText, stromLesen, verlaufFuerServer, vorschlagAenderung, vorschlagAufruf, vorschlagText, type Vorschlag } from "./strom";

export interface Nachricht {
  kennung: string;
  wer: "alfred" | "nutzer";
  inhalt: string;
  /** "modell" trägt die KI-Marke. Vorbereitete Texte haben keine. */
  quelle?: "modell";
  /** Ein Verweis unter dem Text, etwa auf die volle Auswertung einer Rechnung. */
  link?: { href: string; text: string };
  /** Klein unter dem Text: was die Spracherkennung getan hat, wenn sie keinen Text lieferte. */
  technik?: string;
}

type Zustand = { bereit: boolean; anbieter: string | null };

type Rechnungsergebnis = {
  gelesen: { anbieter: string | null; von: string | null; bis: string | null; kwh: number | null; brutto_eur: number | null; arbeitspreis_ct_kwh: number | null };
  mittlerer_preis_ct_kwh: number | null;
  gemessen_kwh: number | null;
  abdeckung: number | null;
  befunde: { stufe: string; titel: string; text: string }[];
};

type TibberZusammenfassung = {
  zeitraum: string;
  kwh: number;
  brutto_eur: number;
  ct_kwh_brutto: number;
  gemessen_kwh: number | null;
  abdeckung: number | null;
  urteil: string;
  befunde: { stufe: string; titel: string; text: string }[];
  schon_bekannt: boolean;
};

type RechnungsAntwort = { art: "tibber" | "andere"; tibber: TibberZusammenfassung | null; andere: Rechnungsergebnis | null; link: string | null };

type Zuordnungsergebnis = { zeilen: { schluessel: string; entitaet: string; grund: string }[]; verworfen: string[]; offen: string[]; yaml: string };

/** Pfade ohne Alfred: dort gibt es keine Anwendung, in der man sich orientieren müsste. */
const OHNE_ALFRED = [/^\/anmeldung/];

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
  onstart: (() => void) | null;
  onaudiostart: (() => void) | null;
  onspeechstart: (() => void) | null;
  onresult: ((e: { results: ArrayLike<ArrayLike<{ transcript: string }> & { isFinal?: boolean }> }) => void) | null;
  onend: (() => void) | null;
  onerror: ((e: { error?: string }) => void) | null;
  start: () => void;
  stop: () => void;
  abort: () => void;
};
function erkennungsKlasse(): (new () => Erkennung) | null {
  if (typeof window === "undefined") return null;
  const w = window as unknown as { SpeechRecognition?: new () => Erkennung; webkitSpeechRecognition?: new () => Erkennung };
  return w.SpeechRecognition ?? w.webkitSpeechRecognition ?? null;
}
function erkennungBauen(): Erkennung | null {
  const Klasse = erkennungsKlasse();
  return Klasse ? new Klasse() : null;
}

/** So lange muss die Ente gedrückt sein, bis Alfred zuhört. Kürzer ist ein Tippen und öffnet das
 *  Panel; länger als das Tippen, aber kürzer als das lange Drücken des Systems (iOS: 500 ms). */
export const HALTEN_MS = 350;
/** So lange wartet Alfred nach dem Loslassen auf den erkannten Text. Safari und Chrome erkennen
 *  auf einem Server; danach gilt die Erkennung als stumm. Ohne diese Wache bliebe „Ich höre zu"
 *  stehen, wo die Erkennung zwar angeboten wird, aber nie antwortet (iOS-Web-App vom Home-Bildschirm). */
export const WACHE_MS = 5000;
/** Liegt beim Loslassen schon ein Zwischentext vor, wartet Alfred nur so lange auf den endgültigen.
 *  Safari unter iOS liefert ihn nicht immer, dann gilt der letzte Zwischentext. */
export const NACHLAUF_MS = 1500;
/** Länger hört Alfred nie zu, auch wenn das Loslassen nicht ankommt. */
export const HOEREN_MAX_MS = 30_000;

/** Ein Zuhören, vom Start bis zum Text oder zur Meldung. Lebt in einem Ref, weil die Ereignisse
 *  der Erkennung nach dem Rendern eintreffen, in dem sie begonnen hat. */
type Zuhoeren = {
  erkennung: Erkennung;
  art: "halten" | "knopf";
  /** Die Erkennung hat gemeldet, dass sie hört. Vorher läuft womöglich die Frage nach dem Mikrofon. */
  gestartet: boolean;
  /** Das Mikrofon nimmt auf (`audiostart`), und es wurde Sprache erkannt (`speechstart`). */
  ton: boolean;
  sprache: boolean;
  /** Der bisher erkannte Text, auch ein Zwischenstand. Er wird gefragt, wenn kein endgültiger kommt. */
  text: string;
  fehler: string | null;
  fertig: boolean;
  /** Der Finger hat die Ente verlassen oder das Mikrofon wurde erneut gedrückt. */
  losgelassen: boolean;
  /** Das System hat die Berührung übernommen (`pointercancel`), der Finger lag womöglich noch auf. */
  abgebrochen: boolean;
  beginn: number;
  wache: ReturnType<typeof setTimeout> | null;
  hoechstens: ReturnType<typeof setTimeout> | null;
};

/** Läuft die Seite als Web-App vom Home-Bildschirm? Dort stellt Safari die Erkennung womöglich
 *  nicht bereit (WebKit-Fehler 225298). */
function alsWebApp(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia?.("(display-mode: standalone)").matches === true || (navigator as { standalone?: boolean }).standalone === true;
}

/** Eine Zeile dazu, was die Erkennung getan hat. Ohne Entwicklerwerkzeuge am Telefon ist das der
 *  einzige Weg zu sehen, woran es hängt: angelaufen, Ton, Sprache, Text, Fehler, Dauer. */
export function technikZeile(z: Pick<Zuhoeren, "art" | "gestartet" | "ton" | "sprache" | "text" | "fehler" | "losgelassen" | "abgebrochen" | "beginn">, jetzt: number, webApp: boolean): string {
  const ja = (b: boolean) => (b ? "✓" : "–");
  const teile = [`Start ${ja(z.gestartet)}`, `Ton ${ja(z.ton)}`, `Sprache ${ja(z.sprache)}`, `Text ${ja(z.text !== "")}`];
  if (z.fehler) teile.push(`Fehler ${z.fehler}`);
  teile.push(`${((jetzt - z.beginn) / 1000).toLocaleString("de-DE", { maximumFractionDigits: 1 })}\u00a0s`);
  if (z.art === "halten") teile.push(z.losgelassen ? "nach dem Loslassen" : "vor dem Loslassen");
  if (z.abgebrochen) teile.push("Berührung vom System übernommen");
  teile.push(webApp ? "Web-App" : "Browser");
  return teile.join(" · ");
}

/** Was Alfred sagt, wenn ein Zuhören ohne Text endet. `aborted` hat Alfred selbst ausgelöst. */
function sprachMeldung(fehler: string | null): string | null {
  if (fehler === "aborted") return null;
  if (fehler === null || fehler === "no-speech") return TEXTE.sprachNichtsGehoert;
  if (fehler === "not-allowed" || fehler === "service-not-allowed" || fehler === "audio-capture") return TEXTE.sprachNichtErlaubt;
  return TEXTE.sprachFehler;
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
  //: Der Vorschlag, dessen Bestätigung gerade offen steht, oder null.
  const [bestaetigen, setBestaetigen] = useState<Vorschlag | null>(null);
  //: Ob Alfred zuhört, und wie: mit gedrückter Ente, über den Mikrofonknopf, oder losgelassen und
  //: wartend auf den erkannten Text.
  const [ohr, setOhr] = useState<"halten" | "knopf" | "wartet" | null>(null);
  const hoert = ohr !== null;
  //: Was die Erkennung bisher verstanden hat, live im Panel: So sieht man, ob sie überhaupt hört.
  const [gehoert, setGehoert] = useState("");
  const [werkzeug, setWerkzeug] = useState<"rechnung" | "zuordnung" | null>(null);
  const [liste, setListe] = useState("");
  const [zuordnung, setZuordnung] = useState<Zuordnungsergebnis | null>(null);
  const [kopiert, setKopiert] = useState(false);
  const huelle = useRef<HTMLDivElement>(null);
  const knopf = useRef<HTMLButtonElement>(null);
  const datei = useRef<HTMLInputElement>(null);
  const zuhoeren = useRef<Zuhoeren | null>(null);
  //: Läuft, solange die Ente gedrückt ist und noch nicht als gehalten gilt.
  const haltenUhr = useRef<ReturnType<typeof setTimeout> | null>(null);
  //: Die Ente wurde gehalten: Der Klick, den der Browser beim Loslassen schickt, öffnet nichts.
  const gehalten = useRef(false);
  const statusAngefragt = useRef(false);
  const lebt = useRef(true);
  const ende = useRef<HTMLDivElement>(null);
  const feldKennung = useId();
  const [kannSprechen, setKannSprechen] = useState(false);

  const darfFragen = Boolean(zustand?.bereit) && rolle === "owner";
  //: Rechnungen ablegen geht auch ohne Sprachmodell (Tibber prüft der Dienst selbst), aber nur mit
  //: Vollzugriff: Rechnungen sind Gästen verschlossen, und das BFF lässt für sie kein POST durch.
  const darfAblegen = rolle === "owner";
  //: Ob gerade eine Datei über Alfred gezogen wird.
  const [ziehen, setZiehen] = useState(false);
  const anbieter = zustand?.anbieter ?? "dem Anbieter";

  useEffect(() => setKannSprechen(erkennungsKlasse() !== null), []);
  /** Beendet ein Zuhören genau einmal, egal ob Text, Fehler, Ende oder Wache zuerst kommt.
   *  `meldung` sagt Alfred, wenn es ohne Text endete. */
  const beenden = useCallback((z: Zuhoeren, meldung: string | null) => {
    if (z.fertig) return;
    z.fertig = true;
    if (z.wache) clearTimeout(z.wache);
    if (z.hoechstens) clearTimeout(z.hoechstens);
    if (zuhoeren.current === z) zuhoeren.current = null;
    if (!lebt.current) return;
    setOhr(null);
    setGehoert("");
    if (!meldung) return;
    const technik = technikZeile(z, Date.now(), alsWebApp());
    setNachrichten((bisher) => {
      const letzte = bisher.at(-1);
      // Derselbe Fehler noch einmal: einmal deutlicher werden, danach nichts mehr stapeln. Die
      // Technikzeile zeigt dann den jüngsten Versuch.
      if (letzte?.wer === "alfred" && letzte.inhalt === TEXTE.sprachWiederholt) return [...bisher.slice(0, -1), { ...letzte, technik }];
      const inhalt = letzte?.wer === "alfred" && letzte.inhalt === meldung ? TEXTE.sprachWiederholt : meldung;
      return [...bisher, { kennung: naechsteKennung(), wer: "alfred", inhalt, technik }];
    });
  }, []);

  /** Bricht ein laufendes Zuhören ab, ohne dass etwas gefragt wird: Panel zu, Komponente weg. */
  const zuhoerenAbbrechen = useCallback(() => {
    const z = zuhoeren.current;
    if (!z) return;
    beenden(z, null);
    z.erkennung.abort();
  }, [beenden]);

  useEffect(() => {
    lebt.current = true;
    return () => {
      lebt.current = false;
      if (haltenUhr.current) clearTimeout(haltenUhr.current);
      zuhoerenAbbrechen();
    };
  }, [zuhoerenAbbrechen]);

  // Die jüngste Nachricht ins Bild rollen; jsdom kennt scrollIntoView nicht, daher optional.
  useEffect(() => {
    if (offen) ende.current?.scrollIntoView?.({ block: "nearest" });
  }, [nachrichten, offen]);

  const zumachen = useCallback(() => {
    setOffen(false);
    zuhoerenAbbrechen();
    knopf.current?.focus();
  }, [zuhoerenAbbrechen]);

  // Escape und Klick daneben schließen; nur bei offenem Panel registriert.
  useEffect(() => {
    if (!offen) return;
    // Steht die Bestätigung offen, bricht Escape sie ab und schließt nicht das ganze Panel.
    const taste = (e: KeyboardEvent) => {
      if (e.key !== "Escape") return;
      if (bestaetigen) setBestaetigen(null);
      else zumachen();
    };
    const daneben = (e: PointerEvent) => {
      if (huelle.current?.contains(e.target as Node)) return;
      setOffen(false);
      zuhoerenAbbrechen();
    };
    document.addEventListener("keydown", taste);
    document.addEventListener("pointerdown", daneben);
    return () => {
      document.removeEventListener("keydown", taste);
      document.removeEventListener("pointerdown", daneben);
    };
  }, [offen, zumachen, bestaetigen, zuhoerenAbbrechen]);

  // Einmal je Seitenaufruf: Ist ein Modell eingerichtet? Liest nur eine Einstellung. Gefragt wird
  // beim ersten Öffnen oder schon beim Drücken der Ente, damit beim Halten die Antwort da ist.
  const statusHolen = useCallback(() => {
    if (statusAngefragt.current) return;
    statusAngefragt.current = true;
    fetch("/api/dch/alfred/status", { cache: "no-store" })
      .then((a) => (a.ok ? a.json() : { bereit: false }))
      .then((d: { bereit?: boolean; anbieter?: string | null }) => lebt.current && setZustand({ bereit: Boolean(d.bereit), anbieter: d.anbieter ?? null }))
      .catch(() => lebt.current && setZustand({ bereit: false, anbieter: null }));
  }, []);
  useEffect(() => {
    if (offen) statusHolen();
  }, [offen, statusHolen]);

  const sagen = (inhalt: string, quelle?: "modell", link?: Nachricht["link"]) =>
    setNachrichten((bisher) => [...bisher, { kennung: naechsteKennung(), wer: "alfred", inhalt, ...(quelle ? { quelle } : {}), ...(link ? { link } : {}) }]);

  const oeffnen = () => {
    if (offen) return;
    if (nachrichten.length === 0) setNachrichten([{ kennung: naechsteKennung(), wer: "alfred", inhalt: TEXTE.begruessung }]);
    setOffen(true);
  };
  const aufmachen = () => (offen ? zumachen() : oeffnen());

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
      // `x-dch-ueber: alfred` lässt das BFF als Urheberzusatz durch: Im Protokoll steht dann
      // „über Alfred" und nicht nur der Gerätename.
      const antwort = await fetch(ziel, {
        method: "POST",
        headers: { "content-type": "application/json", "x-dch-ueber": "alfred" },
        body: JSON.stringify(rumpf),
      });
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

  /** Beginnt zuzuhören. Den Text macht die Erkennung des Browsers; an den Dienst geht nur er. */
  const zuhoerenBeginnen = (art: "halten" | "knopf") => {
    if (zuhoeren.current || laeuft) return;
    const e = erkennungBauen();
    if (!e) return sagen(TEXTE.sprachOhneBrowser);
    e.lang = "de-DE";
    // Zwischenergebnisse an: Safari unter iOS meldet einen Text oft nur als Zwischenstand und nie
    // als endgültig. Ohne sie bliebe dort jede Frage leer.
    e.interimResults = true;
    e.maxAlternatives = 1;
    const z: Zuhoeren = {
      erkennung: e, art, gestartet: false, ton: false, sprache: false, text: "", fehler: null, fertig: false,
      losgelassen: false, abgebrochen: false, beginn: Date.now(), wache: null, hoechstens: null,
    };
    e.onstart = () => {
      z.gestartet = true;
      // Am Android-Telefon ein kurzes Zucken: Jetzt sprechen. iOS kennt das nicht.
      if (art === "halten" && "vibrate" in navigator) navigator.vibrate(20);
    };
    e.onaudiostart = () => {
      z.ton = true;
    };
    e.onspeechstart = () => {
      z.sprache = true;
    };
    e.onresult = (ereignis) => {
      if (z.fertig) return;
      const ergebnisse = Array.from(ereignis.results);
      const text = ergebnisse.map((r) => r[0]?.transcript ?? "").join(" ").replace(/\s+/g, " ").trim();
      if (text) {
        z.text = text;
        setGehoert(text);
      }
      if (z.text && ergebnisse.at(-1)?.isFinal) return textFragen(z);
      // Nach dem Loslassen kam noch ein Zwischentext: nicht mehr lange auf den endgültigen warten.
      if (z.losgelassen) wacheStellen(z);
    };
    e.onerror = (ereignis) => {
      z.fehler = ereignis?.error ?? "unbekannt";
    };
    // Endet die Erkennung mit einem Zwischentext, gilt er. Safari endet unter iOS auch so.
    e.onend = () => (z.text ? textFragen(z) : beenden(z, sprachMeldung(z.fehler)));
    zuhoeren.current = z;
    setOhr(art);
    setGehoert("");
    z.hoechstens = setTimeout(() => zuhoerenBeenden(), HOEREN_MAX_MS);
    try {
      e.start();
    } catch {
      beenden(z, TEXTE.sprachFehler);
    }
  };

  /** Fragt mit dem bisher erkannten Text, auch einem Zwischenstand, und gibt das Mikrofon frei. */
  const textFragen = (z: Zuhoeren) => {
    // Ein beendetes Zuhören fragt nie mehr: weder nach einem Abbruch (Panel zu), dessen Ende
    // noch nachkommt, noch ein zweites Mal, wenn auf das Endergebnis noch `onend` folgt.
    if (z.fertig) return;
    const text = z.text;
    beenden(z, null);
    z.erkennung.abort();
    void jetzt.current.fragen(text);
  };

  /** Die Wache nach dem Loslassen: Liegt schon ein Zwischentext vor, gilt er nach kurzer Zeit.
   *  Ohne Text gilt die Erkennung nach längerer Zeit als stumm. */
  const wacheStellen = (z: Zuhoeren) => {
    if (z.wache) clearTimeout(z.wache);
    z.wache = setTimeout(
      () => {
        if (z.text) return textFragen(z);
        beenden(z, TEXTE.sprachKeineAntwort);
        z.erkennung.abort();
      },
      z.text ? NACHLAUF_MS : WACHE_MS,
    );
  };

  /** Hört auf zuzuhören: Ente losgelassen oder Mikrofon erneut gedrückt. Der Text kommt danach. */
  const zuhoerenBeenden = () => {
    const z = zuhoeren.current;
    if (!z || z.fertig || z.losgelassen) return;
    z.losgelassen = true;
    if (!z.gestartet && !z.text) {
      // Nie angelaufen: Die Frage nach dem Mikrofon steht noch offen, oder die Erkennung wird nur
      // angeboten und antwortet nicht. Warten hilft in keinem der beiden Fälle.
      beenden(z, TEXTE.sprachNichtAngelaufen);
      z.erkennung.abort();
      return;
    }
    // Wache und Zustand vor stop(): Endet die Erkennung sofort, räumt `beenden` beides wieder ab.
    setOhr("wartet");
    wacheStellen(z);
    z.erkennung.stop();
  };

  const sprechen = () => (hoert ? zuhoerenBeenden() : zuhoerenBeginnen("knopf"));

  //: Halten zum Sprechen gibt es nur mit Vollzugriff, denn Gäste fragen nicht (siehe oben).
  const kannHalten = rolle === "owner";

  /** Die Ente ist lange genug gedrückt: Panel auf und zuhören, solange sie gedrückt bleibt. */
  const haltenBeginnt = () => {
    oeffnen();
    if (zustand?.bereit === false) return sagen(TEXTE.frageOhneModell);
    zuhoerenBeginnen("halten");
  };

  // Die Uhr fürs Halten und die Ereignisse der Erkennung kommen Renderdurchgänge nach ihrem Start.
  // Sie rufen deshalb die Fassung aus dem jüngsten Durchgang, mit dem jüngsten Zustand.
  const jetzt = useRef({ fragen, haltenBeginnt });
  useEffect(() => {
    jetzt.current = { fragen, haltenBeginnt };
  });

  const enteDruecken = (e: React.PointerEvent<HTMLButtonElement>) => {
    gehalten.current = false;
    if (!kannHalten || (e.pointerType === "mouse" && e.button !== 0)) return;
    statusHolen();
    // Das Loslassen kommt dann bei der Ente an, auch wenn der Finger etwas verrutscht.
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      // jsdom und ältere Browser kennen es nicht; dann endet das Halten am Ende des Satzes.
    }
    if (haltenUhr.current) clearTimeout(haltenUhr.current);
    haltenUhr.current = setTimeout(() => {
      haltenUhr.current = null;
      gehalten.current = true;
      jetzt.current.haltenBeginnt();
    }, HALTEN_MS);
  };

  const enteLoslassen = () => {
    if (haltenUhr.current) {
      clearTimeout(haltenUhr.current);
      haltenUhr.current = null;
    }
    if (zuhoeren.current?.art === "halten") zuhoerenBeenden();
  };

  /** Das System hat die Berührung übernommen (iOS tut das etwa, wenn der Finger verrutscht und es
   *  ein Scrollen vermutet). Der Finger liegt dann womöglich noch auf der Ente: Alfred hört weiter
   *  zu, bis er sich hebt. Die Touch-Ereignisse kommen auch nach `pointercancel` noch an. */
  const enteAbgebrochen = () => {
    if (haltenUhr.current) {
      clearTimeout(haltenUhr.current);
      haltenUhr.current = null;
    }
    const z = zuhoeren.current;
    if (z?.art !== "halten") return;
    z.abgebrochen = true;
    const heben = () => {
      window.removeEventListener("touchend", heben);
      window.removeEventListener("pointerup", heben);
      if (zuhoeren.current === z) zuhoerenBeenden();
    };
    window.addEventListener("touchend", heben);
    window.addEventListener("pointerup", heben);
  };

  const enteKlick = () => {
    // Nach dem Halten schickt der Browser beim Loslassen noch einen Klick. Der darf das eben
    // geöffnete Panel nicht wieder schließen.
    if (gehalten.current) {
      gehalten.current = false;
      return;
    }
    aufmachen();
  };

  const rechnungPruefen = async (f: File) => {
    setLaeuft(true);
    setSchritt(TEXTE.rechnungLaeuft);
    setNachrichten((bisher) => [...bisher, { kennung: naechsteKennung(), wer: "nutzer", inhalt: f.name }]);
    try {
      const antwort = await fetch(`/api/dch/alfred/rechnung?file_name=${encodeURIComponent(f.name)}`, {
        method: "POST",
        headers: { "content-type": "application/pdf" },
        body: f,
      });
      const daten = (await antwort.json().catch(() => null)) as (RechnungsAntwort & { error?: { message?: string } }) | null;
      if (!antwort.ok || !daten) return sagen(daten?.error?.message ?? TEXTE.frageFehler);
      if (daten.art === "tibber" && daten.tibber) {
        // Fest geprüft, ohne Sprachmodell: keine KI-Marke. Die volle Auswertung steht auf der Seite.
        sagen(tibberZusammenfassung(daten.tibber), undefined, daten.link ? { href: daten.link, text: TEXTE.rechnungZurAuswertung } : undefined);
      } else if (daten.andere) {
        sagen(rechnungZusammenfassung(daten.andere), "modell");
      }
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
    <div
      className={`alfred${ziehen ? " zieht" : ""}${hoert ? " hoert" : ""}${ohr === "wartet" ? " wartet" : ""}`}
      ref={huelle}
      onDragOver={(e) => {
        if (!darfAblegen || !hatDatei(e.dataTransfer)) return;
        e.preventDefault();
        e.dataTransfer.dropEffect = "copy";
        setZiehen(true);
      }}
      onDragLeave={(e) => {
        if (!huelle.current?.contains(e.relatedTarget as Node | null)) setZiehen(false);
      }}
      onDrop={(e) => {
        if (!darfAblegen) return;
        e.preventDefault();
        setZiehen(false);
        const f = Array.from(e.dataTransfer.files).find(istPdf);
        if (!offen) aufmachen();
        if (f) void rechnungPruefen(f);
        else sagen(TEXTE.rechnungKeinPdf);
      }}
    >
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
                {n.technik ? <span className="alfred-technik">{n.technik}</span> : null}
                {n.link ? (
                  // Das Panel geht zu, damit es die Auswertung nicht verdeckt; das Gespräch bleibt.
                  <Link className="alfred-link" href={n.link.href} onClick={() => setOffen(false)}>
                    {n.link.text}
                  </Link>
                ) : null}
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
                    <button type="button" disabled={fuehrtAus !== null || bestaetigen !== null} onClick={() => setBestaetigen(v)}>
                      {fuehrtAus === `${v.art}-${v.ziel}` ? TEXTE.vorschlagLaeuft : TEXTE.vorschlagPruefen}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          {/* Die letzte Schicht vor dem Schalten: ein Mensch liest, was genau passiert, und sagt ja.
              Gezeigt werden die geprüften Felder des Vorschlags aus dem Dienst - nicht der Text der
              Antwort, denn den hat das Modell formuliert und der darf etwas anderes behaupten.
              „Abbrechen" hat den Fokus: Wer nur Enter drückt, hat nichts geschaltet. */}
          {bestaetigen ? (
            <div className="alfred-bestaetigung" role="alertdialog" aria-modal="true" aria-labelledby={`${feldKennung}-frage`} aria-describedby={`${feldKennung}-was`}>
              <p className="frage" id={`${feldKennung}-frage`}>
                {TEXTE.bestaetigungTitel}
              </p>
              <p className="was" id={`${feldKennung}-was`}>
                {vorschlagAenderung(bestaetigen)}
              </p>
              <p className="hinweis">{TEXTE.bestaetigungHinweis}</p>
              <div className="knoepfe">
                <button type="button" autoFocus onClick={() => setBestaetigen(null)}>
                  {TEXTE.bestaetigungAbbrechen}
                </button>
                <button
                  type="button"
                  className="ok"
                  onClick={() => {
                    const v = bestaetigen;
                    setBestaetigen(null);
                    void ausfuehren(v);
                  }}
                >
                  {TEXTE.bestaetigungOk}
                </button>
              </div>
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

          {darfAblegen ? (
            <div className="alfred-werkzeuge">
              <button type="button" disabled={laeuft} aria-pressed={werkzeug === "rechnung"} onClick={() => { setWerkzeug("rechnung"); datei.current?.click(); }}>
                {TEXTE.rechnungKnopf}
              </button>
              {darfFragen ? (
                <button type="button" disabled={laeuft} aria-pressed={werkzeug === "zuordnung"} onClick={() => setWerkzeug(werkzeug === "zuordnung" ? null : "zuordnung")}>
                  {TEXTE.zuordnungKnopf}
                </button>
              ) : null}
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
          {darfAblegen && werkzeug === "rechnung" ? (
            <p className="alfred-stufe">{darfFragen ? ersetze(TEXTE.rechnungHinweis, { anbieter }) : TEXTE.rechnungHinweisOhneModell}</p>
          ) : null}

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
              {hoert && gehoert
                ? ersetze(TEXTE.sprachGehoert, { text: gehoert })
                : ohr === "halten"
                  ? TEXTE.haltenLaeuft
                  : ohr === "wartet"
                    ? TEXTE.sprachWartet
                    : hoert
                      ? TEXTE.mikrofonLaeuft
                      : (schritt ?? TEXTE.frageLaeuft)}
            </p>
          ) : null}

          {zustand === null ? null : <p className="alfred-stufe">{zustand.bereit ? ersetze(TEXTE.hinweisModell, { anbieter }) : TEXTE.hinweisOhneModell}</p>}
        </div>
      ) : null}

      {/* Tippen öffnet das Panel, Halten heißt sprechen (Push-to-Talk). Das Kontextmenü, das
          Android beim langen Drücken öffnen will, bleibt dabei zu. */}
      <button
        type="button"
        ref={knopf}
        className="alfred-button"
        onClick={enteKlick}
        onPointerDown={enteDruecken}
        onPointerUp={enteLoslassen}
        onPointerCancel={enteAbgebrochen}
        onContextMenu={(e) => {
          if (kannHalten) e.preventDefault();
        }}
        title={kannHalten && kannSprechen ? TEXTE.ansprechenHalten : TEXTE.ansprechen}
        aria-label={TEXTE.ansprechen}
        aria-expanded={offen}
        aria-controls={offen ? feldKennung : undefined}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/brand/ente-maskottchen.svg" alt="" aria-hidden="true" draggable={false} />
      </button>
    </div>
  );
}

/** Ob beim Ziehen Dateien dabei sind; welche, verrät der Browser erst beim Ablegen. */
function hatDatei(d: DataTransfer | null): boolean {
  return Boolean(d && Array.from(d.types ?? []).includes("Files"));
}

function istPdf(f: File): boolean {
  return f.type === "application/pdf" || f.name.toLowerCase().endsWith(".pdf");
}

/** Das Ergebnis der festen Tibber-Prüfung als Text. Gerechnet hat der Dienst, nicht das Modell. */
export function tibberZusammenfassung(t: TibberZusammenfassung): string {
  const zahl = (x: number | null | undefined, stellen = 0) => (x == null ? "?" : x.toLocaleString("de-DE", { maximumFractionDigits: stellen }));
  const urteil: Record<string, string> = { ok: "alles stimmig", info: "stimmig, mit Hinweisen", warning: "auffällig", error: "fehlerhaft" };
  const zeilen = [
    `**Tibber-Rechnung ${t.zeitraum}**: ${zahl(t.kwh)} kWh, ${zahl(t.brutto_eur, 2)} € brutto, im Mittel ${zahl(t.ct_kwh_brutto, 2)} ct/kWh. Ergebnis: ${urteil[t.urteil] ?? t.urteil}.`,
  ];
  // Ohne Abdeckung keine Zeile „0 kWh": Dass es keinen Vergleichswert gibt, sagt der Befund.
  if (t.gemessen_kwh != null && (t.abdeckung ?? 0) > 0) zeilen.push(`Eigene Messung: ${zahl(t.gemessen_kwh)} kWh (Abdeckung ${zahl((t.abdeckung ?? 0) * 100)} %).`);
  for (const b of t.befunde) zeilen.push(`${b.stufe === "warning" ? "⚠ " : ""}${b.titel}: ${b.text}`);
  if (t.schon_bekannt) zeilen.push("Diese Rechnung lag schon vor; ihr Stand ist ersetzt.");
  return zeilen.join("\n");
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
