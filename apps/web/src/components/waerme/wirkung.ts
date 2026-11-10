/**
 * Die Seite „Wirkung": was sich rechnen lässt, ohne zu zeichnen.
 *
 * Das Urteil und alle Quoten kommen fertig vom Server. Hier steht nur, was die Darstellung
 * braucht: die Reihenfolge der Zeilen im Raster, die Läufe einer Leistungskurve, die Texte neben
 * einer Zeile, und Tag und Stunde eines Ereignisses in der Zeit des Hauses.
 */

import type { Kontaktwirkung } from "@/lib/api/models";
import { laeufe } from "./tagesuhr";

export type Ereignis = NonNullable<Kontaktwirkung["ereignisse"]>[number];
export type Gruppe = "gefolgt" | "nicht_gefolgt" | "lief_schon" | "unklar";

const MINUTE = 60_000;
const HAUS = "Europe/Berlin";

/** In welche der vier Gruppen ein Schließvorgang gehört. */
export function gruppe(e: Ereignis): Gruppe {
  if (e.lief_schon) return "lief_schon";
  if (!e.auswertbar) return "unklar";
  return e.gefolgt ? "gefolgt" : "nicht_gefolgt";
}

export const GRUPPEN: { key: Gruppe; titel: string }[] = [
  { key: "gefolgt", titel: "angelaufen" },
  { key: "nicht_gefolgt", titel: "nicht angelaufen" },
  { key: "lief_schon", titel: "lief schon" },
  { key: "unklar", titel: "Messung fehlt" },
];

/**
 * Die Ereignisse für das Raster: nach Gruppe, darin nach Verzögerung.
 *
 * Nach Verzögerung und nicht nach Datum, weil das Raster so seine Form zeigt: stehen die Anläufe
 * als Treppe dicht hinter dem Nullpunkt, reagiert die Maschine; streuen sie über das ganze
 * Fenster, tut sie, was sie ohnehin tut. Nach Datum sortiert sähe beides gleich unruhig aus.
 * Ohne Verzögerung entscheidet der Zeitpunkt, der jüngste zuerst.
 */
export function geordnet(ereignisse: readonly Ereignis[]): { key: Gruppe; titel: string; ereignisse: Ereignis[] }[] {
  const zeit = (e: Ereignis) => new Date(e.at).getTime();
  return GRUPPEN.map(({ key, titel }) => ({
    key,
    titel,
    ereignisse: ereignisse
      .filter((e) => gruppe(e) === key)
      .sort((a, b) => {
        const va = a.verzoegerung_min ?? Infinity;
        const vb = b.verzoegerung_min ?? Infinity;
        return va !== vb ? va - vb : zeit(b) - zeit(a);
      }),
  })).filter((g) => g.ereignisse.length > 0);
}

/**
 * Eine Leistungskurve als Läufe, in Minuten ab dem Beginn des Ausschnitts.
 *
 * `laeuft` sind die Abschnitte an oder über der Schwelle, `steht` die gemessenen darunter. Was in
 * keinem von beiden liegt, wurde nicht gemessen - und bleibt im Raster leer, statt als Stillstand
 * zu erscheinen.
 */
export function betrieb(kw: readonly (number | null)[], schwelleKw: number): { laeuft: [number, number][]; steht: [number, number][] } {
  const zeiten = kw.map((_, i) => i * MINUTE);
  const alle = laeufe(
    kw.map((w) => (w === null ? null : w >= schwelleKw)),
    zeiten,
    MINUTE,
  );
  const minuten = (an: boolean) => alle.filter((l) => l.wert === an).map((l): [number, number] => [l.von / MINUTE, l.bis / MINUTE]);
  return { laeuft: minuten(true), steht: minuten(false) };
}

/** Was neben einer Zeile des Rasters steht. */
export function ergebnisText(e: Ereignis, folgeMin: number): string {
  const g = gruppe(e);
  if (g === "lief_schon") return "lief schon";
  if (g === "unklar") return "Messung fehlt";
  if (e.verzoegerung_min === null) return "kein Anlauf";
  if (e.verzoegerung_min === 0) return "sofort";
  return e.verzoegerung_min < folgeMin ? `nach ${e.verzoegerung_min} min` : `erst nach ${e.verzoegerung_min} min`;
}

/** Die Beschriftung einer Minute relativ zum Schließen. */
export function achsenText(m: number): string {
  if (m === 0) return "Anforderung";
  return `${m > 0 ? "+" : "−"}${Math.abs(m)} min`;
}

/** Ein Anteil als ganze Prozentzahl ohne Einheit. `null` bleibt ein Strich. */
export function prozentZahl(x: number | null | undefined): string {
  return x === null || x === undefined ? "-" : String(Math.round(x * 100));
}

const tagFmt = new Intl.DateTimeFormat("sv-SE", { timeZone: HAUS, year: "numeric", month: "2-digit", day: "2-digit" });
const stundeFmt = new Intl.DateTimeFormat("en-GB", { timeZone: HAUS, hour: "2-digit", hourCycle: "h23" });
const kurzFmt = new Intl.DateTimeFormat("de-DE", { timeZone: HAUS, weekday: "short", day: "2-digit", month: "2-digit" });
const spanneFmt = new Intl.DateTimeFormat("de-DE", { timeZone: HAUS, day: "numeric", month: "long" });

/** Der Kalendertag eines Zeitpunkts in der Zeit des Hauses, als `YYYY-MM-DD`. */
export function hausTag(iso: string): string {
  return tagFmt.format(new Date(iso));
}

/** Die Stunde eines Zeitpunkts in der Zeit des Hauses, 0 bis 23. */
export function hausStunde(iso: string): number {
  return Number(stundeFmt.format(new Date(iso)));
}

/** „Sa., 07.11." in der Zeit des Hauses. */
export function kurzDatum(iso: string): string {
  return kurzFmt.format(new Date(iso));
}

/** „10. Oktober bis 9. November" in der Zeit des Hauses. */
export function spanne(von: string, bis: string): string {
  return `${spanneFmt.format(new Date(von))} bis ${spanneFmt.format(new Date(bis))}`;
}

/** Wohin eine Zeile führt: in die Wiedergabe dieses Tages, zur Stunde des Ereignisses. */
export function wiedergabeZiel(iso: string): string {
  return `/waerme/wiedergabe?day=${hausTag(iso)}&t=${hausStunde(iso)}`;
}

/**
 * Die Deckung einer einzelnen Kurve im Fächer.
 *
 * Viele Kurven übereinander sollen eine Wolke ergeben, wenige einzeln lesbar bleiben. Mit fester
 * Deckung wäre eines von beiden falsch: drei Kurven verschwänden, oder hundert würden zur Fläche.
 */
export function deckung(n: number): number {
  if (n <= 0) return 0.55;
  return Math.min(0.55, Math.max(0.1, 1.1 / Math.sqrt(n)));
}
