import type { RoomLogEntry } from "@/lib/api/models";

/**
 * Was das Protokollfenster rechnet, ohne React.
 *
 * Alles hier ist reine Funktion: Zahlen hinein, Zahlen oder Text heraus. Das ist der Teil, der
 * sich prüfen lässt, ohne einen Browser zu starten.
 */

/** Wer den Sollwert geändert hat, in der Sprache der Anzeige. */
export const QUELLE_WORT: Record<RoomLogEntry["quelle"], string> = {
  app: "hier gestellt",
  automatik: "Automatik",
  extern: "von außen",
};

/**
 * Die Farbe der Quelle. **Extern ist bernstein, nicht rot.** Eine Änderung von außen ist kein
 * Fehler - meistens war es ein Mensch, der genau das wollte. Sie soll auffallen, nicht warnen.
 */
export const QUELLE_FARBE: Record<RoomLogEntry["quelle"], string> = {
  app: "var(--pv)",
  automatik: "var(--petrol-hell, var(--text-2))",
  extern: "var(--amber)",
};

/** Was in einer Zeile steht, wenn kein Begründungstext dabei ist. */
export function artText(e: RoomLogEntry): string {
  switch (e.art) {
    case "befehl":
      return "Befehl geschickt, aber nie gemeldet";
    case "ruhe":
      return "Die Automatik lässt den Raum in Ruhe";
    case "einstellung":
      return "Die Automatik wurde geschaltet";
    default:
      return "Sollwert geändert";
  }
}

/** `21,0 → 22,5`, oder leer, wenn der Eintrag keine Werte trägt. */
export function sprungText(e: RoomLogEntry): string {
  if (e.to_c == null) return "";
  const z = (n: number) => n.toFixed(1).replace(".", ",");
  return e.from_c == null ? `auf ${z(e.to_c)}` : `${z(e.from_c)} → ${z(e.to_c)}`;
}

export type Spanne = { min: number; max: number };

/**
 * Die Temperaturspanne der Kurve: so eng wie möglich, aber nie enger als `mindestK`.
 *
 * **Warum eine Untergrenze.** Ein Raum, der zwei Tage lang auf 0,3 K genau steht, bekäme sonst
 * eine Kurve, die wie ein Gebirge aussieht. Zwei Kelvin Mindestspanne machen aus Rauschen wieder
 * eine waagerechte Linie - und genau das ist die richtige Auskunft.
 */
export function spanne(reihen: (number | null)[][], mindestK = 2): Spanne | null {
  const werte = reihen.flat().filter((v): v is number => v != null);
  if (werte.length === 0) return null;
  let min = Math.min(...werte);
  let max = Math.max(...werte);
  const fehlt = mindestK - (max - min);
  if (fehlt > 0) {
    min -= fehlt / 2;
    max += fehlt / 2;
  }
  // Auf halbe Grad nach außen, damit die Achse runde Zahlen trägt.
  return { min: Math.floor(min * 2) / 2, max: Math.ceil(max * 2) / 2 };
}

/**
 * Eine Reihe als SVG-Pfad. **Lücken bleiben Lücken.** Ein `null` trennt den Pfad, statt zwei
 * Messwerte über eine Stunde Stille hinweg zu verbinden - eine durchgezogene Linie wäre dort eine
 * Behauptung über Zeit, in der nichts gemessen wurde.
 */
export function pfad(werte: (number | null)[], s: Spanne, breite: number, hoehe: number): string {
  if (werte.length === 0 || s.max <= s.min) return "";
  const n = werte.length;
  const x = (i: number) => (n === 1 ? 0 : (i / (n - 1)) * breite);
  const y = (v: number) => hoehe - ((v - s.min) / (s.max - s.min)) * hoehe;
  let d = "";
  let offen = false;
  werte.forEach((v, i) => {
    if (v == null) {
      offen = false;
      return;
    }
    d += `${offen ? "L" : "M"}${x(i).toFixed(1)} ${y(v).toFixed(1)} `;
    offen = true;
  });
  return d.trim();
}

/** Wo auf der Breite ein Zeitpunkt liegt, oder `null`, wenn er außerhalb der Achse liegt. */
export function xFuerZeit(iso: string, ts: string[], breite: number): number | null {
  if (ts.length < 2) return null;
  const t = new Date(iso).getTime();
  const a = new Date(ts[0]!).getTime();
  const b = new Date(ts[ts.length - 1]!).getTime();
  if (!Number.isFinite(t) || b <= a) return null;
  if (t < a || t > b) return null;
  return ((t - a) / (b - a)) * breite;
}

/**
 * Die Beschriftungen der Zeitachse: jeweils der Beginn eines neuen Tages und sonst runde Stunden.
 *
 * Zurück kommen Anteile der Breite (0 bis 1) mit ihrem Text, höchstens `hoechstens` Stück.
 */
export function zeitMarken(ts: string[], hoechstens = 7): { anteil: number; text: string }[] {
  if (ts.length < 2) return [];
  const schritt = Math.max(1, Math.ceil(ts.length / hoechstens));
  const out: { anteil: number; text: string }[] = [];
  for (let i = 0; i < ts.length; i += schritt) {
    const d = new Date(ts[i]!);
    if (Number.isNaN(d.getTime())) continue;
    const stunde = d.getHours();
    out.push({
      anteil: i / (ts.length - 1),
      // Um Mitternacht das Datum, sonst die Uhrzeit: über zwei Tage hinweg ist sonst nicht zu
      // sehen, wo der eine aufhört.
      text:
        stunde === 0 && d.getMinutes() < 30
          ? d.toLocaleDateString("de-DE", { day: "2-digit", month: "2-digit" })
          : `${String(stunde).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`,
    });
  }
  return out;
}

/**
 * Eine Reihe auf gröbere Fenster mitteln, `je` Werte zu einem.
 *
 * **Warum die Streifen das brauchen.** Zwei Tage in Viertelstunden sind 193 Felder; auf der
 * Breite eines Fensters werden daraus Striche von drei Bildpunkten, und der Streifen sieht aus
 * wie ein Lattenzaun, in dem nichts mehr zu erkennen ist. Auf Stunden verdichtet sagen 48 Felder
 * dasselbe und sind zu lesen. Gemittelt wird auch hier die Ventilstellung: Über eine Stunde ist
 * der Mittelwert die Einschaltdauer, und genau die interessiert.
 *
 * Ein Fenster ganz ohne Messwert bleibt `null` - eine Lücke ist die Aussage „hier war nichts".
 */
export function verdichte(werte: (number | null)[], je: number): (number | null)[] {
  if (je <= 1) return werte;
  const out: (number | null)[] = [];
  for (let i = 0; i < werte.length; i += je) {
    const teil = werte.slice(i, i + je).filter((v): v is number => v != null);
    out.push(teil.length ? teil.reduce((a, b) => a + b, 0) / teil.length : null);
  }
  return out;
}

/** Wie viele Einträge es je Quelle gibt - die Zusammenfassung über dem Protokoll. */
export function zaehle(entries: RoomLogEntry[]): Record<RoomLogEntry["quelle"], number> {
  const out: Record<RoomLogEntry["quelle"], number> = { app: 0, automatik: 0, extern: 0 };
  for (const e of entries) out[e.quelle] += 1;
  return out;
}

/**
 * Der Satz über dem Protokoll. **Er sagt zuerst, ob überhaupt etwas passiert ist** - das ist die
 * häufigste und wichtigste Antwort: Wenn sich der Sollwert nicht geändert hat, liegt die Ursache
 * der Abweichung nicht an der Regelung, und man muss woanders suchen.
 */
export function ueberschrift(entries: RoomLogEntry[], stunden: number): string {
  const n = entries.filter((e) => e.art === "sollwert").length;
  if (n === 0) return `In ${stunden} Stunden hat niemand den Sollwert verändert.`;
  const z = zaehle(entries.filter((e) => e.art === "sollwert"));
  const teile: string[] = [];
  if (z.extern) teile.push(`${z.extern}× von außen`);
  if (z.app) teile.push(`${z.app}× hier`);
  if (z.automatik) teile.push(`${z.automatik}× durch die Automatik`);
  return `${n === 1 ? "Eine Änderung" : `${n} Änderungen`} in ${stunden} Stunden: ${teile.join(", ")}.`;
}
