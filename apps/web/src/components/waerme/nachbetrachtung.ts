/**
 * Die Seite „Nachbetrachtung": was sich rechnen lässt, ohne zu zeichnen.
 *
 * Alle Euro kommen fertig vom Server, die Sätze auch. Hier steht, wie daraus die Treppe wird:
 * welche Zeile wo beginnt und endet, welche fehlt, und auf welcher Achse sie liegen.
 */

import type { Nachbetrachtung } from "@/lib/api/models";

export type Linie = NonNullable<Nachbetrachtung["linien"]>[number];
export type Abstand = NonNullable<Nachbetrachtung["abstaende"]>[number];

/** Eine Zeile der Treppe. `von` und `bis` sind Euro auf der gemeinsamen Achse. */
export type Stufe = {
  key: string;
  name: string;
  /** `summe` steht auf dem Boden, `stufe` schwebt zwischen zwei Ständen, `bezug` steht daneben. */
  art: "summe" | "stufe" | "bezug";
  von: number;
  bis: number;
  /** Der Betrag der Zeile: bei einer Summe ihr Stand, bei einer Stufe ihre Änderung. */
  eur: number;
  geschaetzt: boolean;
  satz: string;
};

const KETTE = ["prognosefehler", "nachfuehren", "eingriff"] as const;

/**
 * Die Treppe vom Versprechen zur Wirklichkeit, und daneben der Vergleichslauf.
 *
 * Sie beginnt bei der ersten Linie, die es gibt. Fehlt das Versprechen, weil der Fahrplan vor der
 * Erweiterung der Ablage entstand, beginnt sie beim gehaltenen Fahrplan; fehlt jeder Fahrplan,
 * steht nur die Wirklichkeit da. Eine fehlende Stufe wird nicht als Null gezeichnet: eine Stufe
 * ohne Höhe hieße „kein Fehler", und das ist etwas anderes als „unbekannt".
 */
export function treppe(d: Nachbetrachtung): Stufe[] {
  const linie = new Map((d.linien ?? []).map((l) => [l.key, l]));
  const abstand = new Map((d.abstaende ?? []).map((a) => [a.key, a]));
  const out: Stufe[] = [];
  const kette = KETTE.map((k) => abstand.get(k)).filter((a): a is Abstand => a != null && a.eur != null);
  const beginn = kette[0] ? linie.get(kette[0].von) : undefined;
  let stand = 0;
  if (beginn?.eur != null) {
    stand = beginn.eur;
    out.push({ key: beginn.key, name: beginn.name_de, art: "summe", von: 0, bis: stand, eur: stand, geschaetzt: false, satz: "" });
    for (const a of kette) {
      const neu = stand + (a.eur ?? 0);
      out.push({ key: a.key, name: a.name_de, art: "stufe", von: stand, bis: neu, eur: a.eur ?? 0, geschaetzt: false, satz: a.satz_de });
      stand = neu;
    }
  }
  const ist = linie.get("wirklich");
  if (ist?.eur != null) {
    out.push({ key: "wirklich", name: ist.name_de, art: "summe", von: 0, bis: ist.eur, eur: ist.eur, geschaetzt: false, satz: "" });
  }
  // Daneben, nicht auf dem Weg: der Vergleichslauf. Was das Verschieben gegenüber einem Lauf ohne
  // Preisblick gebracht hat, steht nicht in der Treppe; das rechnet die Kostenseite, und die
  // Nachbetrachtung nennt nur ihr Ergebnis.
  const perfekt = linie.get("perfekt");
  if (perfekt?.eur != null) {
    out.push({ key: "perfekt", name: perfekt.name_de, art: "bezug", von: 0, bis: perfekt.eur, eur: perfekt.eur, geschaetzt: perfekt.geschaetzt, satz: abstand.get("voraussicht")?.satz_de ?? "" });
  }
  return out;
}

/**
 * Die Achse der Treppe: von null (oder darunter, falls eine Linie negativ ist) bis zu einem
 * runden Wert über dem größten Stand, mit drei bis fünf Marken.
 */
export function achse(stufen: readonly Stufe[]): { min: number; max: number; marken: number[] } {
  const werte = stufen.flatMap((s) => [s.von, s.bis]);
  const roh = Math.max(0.5, ...werte);
  const tief = Math.min(0, ...werte);
  const schritt = [0.1, 0.2, 0.25, 0.5, 1, 2, 2.5, 5, 10, 20, 25, 50].find((s) => (roh - tief) / s <= 5) ?? 100;
  const max = Math.ceil(roh / schritt) * schritt;
  const min = Math.floor(tief / schritt) * schritt;
  const marken: number[] = [];
  for (let m = min; m <= max + 1e-9; m += schritt) marken.push(Math.round(m * 100) / 100);
  return { min, max, marken };
}

/** „3,42 €". Ein fehlender Wert bleibt ein Strich. */
export function euro(x: number | null | undefined): string {
  if (x === null || x === undefined) return "-";
  return `${Math.abs(x).toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} €`.replace(/^/, x < 0 ? "−" : "");
}

/** „+0,31 €" oder „−0,80 €": eine Änderung trägt ihr Vorzeichen immer. Null bleibt „±0,00 €". */
export function euroMitVorzeichen(x: number | null | undefined): string {
  if (x === null || x === undefined) return "-";
  const betrag = `${Math.abs(x).toLocaleString("de-DE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} €`;
  if (Math.abs(x) < 0.005) return `±${betrag}`;
  return `${x > 0 ? "+" : "−"}${betrag}`;
}

/**
 * Die Helligkeitsstufe einer Viertelstunde im Tagesstreifen: 0 für nichts, 1 bis 4 für den Strom
 * im Verhältnis zu dem, was eine Viertelstunde bei Nennleistung zieht.
 *
 * Vier Stufen und kein stufenloser Verlauf: die Zeilen sollen sich vergleichen lassen, und vier
 * Helligkeiten unterscheidet das Auge sicher. `null` bleibt `null` - keine Aussage ist kein
 * Stillstand.
 */
export function staerke(kwh: number | null | undefined, vollKwh: number): number | null {
  if (kwh === null || kwh === undefined) return null;
  if (kwh <= 0.02 * vollKwh) return 0;
  return Math.min(4, Math.max(1, Math.ceil((kwh / vollKwh) * 4 - 1e-9)));
}

/** Die Linien, die im Tagesvergleich eine eigene Zeile bekommen, in dieser Reihenfolge. */
export const ZEILEN = ["erster", "letzter", "wirklich", "perfekt"] as const;

/** Die verfügbaren Linien für den Tagesvergleich. Das Versprechen fehlt: es ist derselbe Fahrplan wie „erster". */
export function zeilen(d: Nachbetrachtung): Linie[] {
  const je = new Map((d.linien ?? []).map((l) => [l.key, l]));
  return ZEILEN.map((k) => je.get(k)).filter((l): l is Linie => l != null && l.verfuegbar);
}
