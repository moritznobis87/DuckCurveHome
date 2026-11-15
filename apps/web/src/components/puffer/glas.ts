import { farbe } from "@/components/anlage/schema";

/**
 * Der Pufferspeicher als Glas: die Rechnung hinter der einen Zeichnung, die es davon gibt.
 *
 * **Eine Darstellung statt dreier** (Nutzerwunsch 14.11.2026). Bis dahin stand der Speicher als
 * eckiger Tank mit Trennlinien auf der Startseite, als liegender Balken am Telefon, als Glas im
 * Anlagenschema und als vier harte Farbbänder auf der Seite der Wärmepumpe, mit zwei
 * verschiedenen Farbskalen: 60 Grad waren hier gelb und dort orange. Geblieben ist das Glas aus
 * dem Anlagenschema, weil es zeigt, was im Speicher ist: eine Schichtung ohne Stufen, oben warm,
 * unten kalt, und jede Zahl auf der Höhe ihres Fühlers.
 *
 * Die Farbe ist die des Wassers im Anlagenschema (`farbe`), dieselbe wie in den Rohren.
 *
 * **Eine Ausnahme in der Lage, nicht in der Art:** auf der Startseite am Telefon liegt das Glas
 * (`home/Rail`), damit die Kachel flach bleibt. Farbskala, Verlauf und die Stelle der Zahlen
 * kommen auch dort von hier.
 */

/** Wo die vier Fühler sitzen: in der Mitte ihrer Schicht, als Anteil von oben. */
export const FUEHLER = [0.125, 0.375, 0.625, 0.875] as const;

export type Temperaturen = ReadonlyArray<number | null | undefined>;

/** Sind alle vier Fühler da? Sonst gibt es keinen Verlauf, nur ein leeres Glas. */
export const vollstaendig = (t: Temperaturen): boolean => t.length === FUEHLER.length && t.every((v) => v != null && !Number.isNaN(v));

/** Die Stützstellen des Farbverlaufs: jede Farbe auf der Höhe ihres Fühlers. Darüber und
 *  darunter bleibt die Farbe des nächsten Fühlers stehen; mehr weiß niemand. */
export function stufen(t: Temperaturen): Array<{ bei: number; farbe: string }> {
  if (!vollstaendig(t)) return [];
  return FUEHLER.map((bei, i) => ({ bei, farbe: farbe(t[i]) }));
}

/** Die Zahl an einem Fühler: ganze Grad. Das Gradzeichen setzt die Zeichnung eng dahinter; in
 *  der Ziffernschrift wäre ein Leerzeichen davor so breit wie eine Ziffer. `null`: kein Wert. */
export const gradzahl = (v: number | null | undefined): string | null => (v == null || Number.isNaN(v) ? null : String(Math.round(v)));

/** Platz neben dem Glas für Strich und Zahl, abhängig von der Schriftgröße. */
export const randBreite = (schrift: number): number => Math.round(20 + schrift * 2.6);
