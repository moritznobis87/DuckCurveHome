// Lesen des Ereignisstroms von POST /alfred/ask/stream und Übersetzung eines Schritts in einen
// Anzeigetext.
//
// Kein `EventSource`: Der kann nur GET ohne Rumpf, die Frage trägt aber die Hilfetexte. Die Anfrage
// läuft deshalb als POST, die Antwort als SSE-Strom im Rumpf, gelesen mit `fetch`.
//
// Der Dienst meldet den Namen des Werkzeugs und keinen Satz; den Satz hat die Oberfläche.

export interface Schritt {
  werkzeug: string;
}

/** Ein Vorschlag, noch nicht ausgeführt. `art` bestimmt den Endpunkt, der ihn ausführt. */
export interface Vorschlag {
  art: "schalten" | "sollwert";
  ziel: string | number;
  name: string;
  an?: boolean | null;
  /** Zustand vor dem Schalten, aus dem Live-Zustand; null, wenn keiner gemeldet ist. */
  war_an?: boolean | null;
  alt?: number | null;
  neu?: number | null;
}

export interface Antwortdaten {
  bereit: boolean;
  antwort: string;
  vorschlaege?: Vorschlag[];
}

export interface Zuhoerer {
  schritt: (s: Schritt) => void;
  antwort: (d: Antwortdaten) => void;
  fehler: (d: unknown) => void;
}

/** Liest einen SSE-Rumpf und ruft je Ereignis den Zuhörer. Ein Paket kann mitten in einer Zeile
 *  enden; der Rest bleibt im Puffer. Zeilenenden dürfen `\r\n` sein (sse-starlette). */
export async function stromLesen(antwort: Response, zuhoerer: Zuhoerer): Promise<void> {
  const leser = antwort.body?.getReader();
  if (!leser) return;
  const decoder = new TextDecoder();
  let puffer = "";
  let art = "";

  const verarbeiten = (roh: string) => {
    const zeile = roh.replace(/\r$/, "");
    if (zeile.startsWith("event:")) {
      art = zeile.slice(6).trim();
      return;
    }
    if (!zeile.startsWith("data:")) return;
    let daten: unknown;
    try {
      daten = JSON.parse(zeile.slice(5).trim());
    } catch {
      return;
    }
    if (art === "schritt") zuhoerer.schritt(daten as Schritt);
    else if (art === "antwort") zuhoerer.antwort(daten as Antwortdaten);
    else if (art === "fehler") zuhoerer.fehler(daten);
  };

  for (;;) {
    const { done, value } = await leser.read();
    if (done) break;
    puffer += decoder.decode(value, { stream: true });
    const zeilen = puffer.split("\n");
    puffer = zeilen.pop() ?? "";
    zeilen.forEach(verarbeiten);
  }
  if (puffer) verarbeiten(puffer);
}

/** Der Satz zu einem Schritt; bei einem unbekannten Werkzeug (Dienst neuer als Oberfläche) der
 *  allgemeine statt eines rohen Bezeichners. */
export function schrittText(schritt: Schritt, texte: { schritte: Record<string, string>; schrittAllgemein: string }): string {
  return texte.schritte[schritt.werkzeug] ?? texte.schrittAllgemein;
}

/** Höchstzahl der mitgesendeten Wechsel. Der Dienst kürzt auf seinen eigenen Wert; diese Schranke
 *  begrenzt nur die Übertragung. */
export const VERLAUF_MAX = 10;

/** Der Gesprächsverlauf für den Dienst. Er lebt nur im Browser und endet mit dem Panel. */
export function verlaufFuerServer(nachrichten: { wer: string; inhalt: string }[]): { wer: string; inhalt: string }[] {
  return nachrichten.slice(-VERLAUF_MAX).map(({ wer, inhalt }) => ({ wer, inhalt }));
}

/** Beschriftung eines Vorschlags, ohne Zahlen zu erfinden: was steht, steht im Vorschlag. */
export function vorschlagText(v: Vorschlag): string {
  if (v.art === "schalten") return `${v.name} ${v.an ? "einschalten" : "ausschalten"}`;
  const zahl = (x: number | null | undefined) => (x == null ? "?" : x.toLocaleString("de-DE", { maximumFractionDigits: 1 }));
  return `${v.name}: Soll ${zahl(v.alt)} → ${zahl(v.neu)} °C`;
}

/** Was genau sich ändert, für die Bestätigung: vorher und nachher, aus den Feldern des Vorschlags.
 *  Unbekanntes steht als „?" und wird nicht erraten. */
export function vorschlagAenderung(v: Vorschlag): string {
  const zahl = (x: number | null | undefined) => (x == null ? "?" : `${x.toLocaleString("de-DE", { maximumFractionDigits: 1 })} °C`);
  if (v.art === "schalten") {
    const vorher = v.war_an == null ? "?" : v.war_an ? "ein" : "aus";
    return `${v.name}: ${vorher} → ${v.an ? "ein" : "aus"}`;
  }
  return `${v.name}: Solltemperatur ${zahl(v.alt)} → ${zahl(v.neu)}`;
}

/** Wohin ein Vorschlag beim Drücken geht - dieselben Endpunkte wie die Schalter der Oberfläche,
 *  mit deren Prüfungen. */
export function vorschlagAufruf(v: Vorschlag): { pfad: string; rumpf: Record<string, unknown> } {
  if (v.art === "schalten") {
    return { pfad: `/api/dch/control/actuators/${encodeURIComponent(String(v.ziel))}`, rumpf: { state: Boolean(v.an) } };
  }
  return { pfad: `/api/dch/rooms/${encodeURIComponent(String(v.ziel))}/setpoint`, rumpf: { setpoint_c: v.neu } };
}
