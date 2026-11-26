import type { Plan } from "@/lib/api/models";
import type { Ausblick } from "./ausblick";
import { grenzen, pvSumme } from "./tage";

/**
 * Das Ambiente: was die Wand zeigt, wenn niemand sie berührt.
 *
 * **Die Idee.** Die Startseite ist eine Bedienung: Schalter, Reiter, Kacheln, ein Dock. Das ist
 * richtig, solange jemand davorsteht. Den ganzen Tag über steht niemand davor, und dann ist eine
 * Bedienung nur Unruhe in der Küche. Nach ein paar Minuten ohne Berührung bleibt deshalb das
 * übrig, was man aus drei Metern lesen kann: die Uhr, das Bild der Startseite und die Zahlen des
 * Tages. Eine Berührung holt die Bedienung zurück.
 *
 * **Tag oder Nacht, und die Sonne entscheidet.** Am Tag steht die Sonne auf ihrem Bogen, nachts
 * der Mond; die Startseite und das Ambiente fragen beide hier. Umgeschaltet wird nach Aufgang und
 * Untergang der Sonne am Standort des Hauses, die der Fahrplan mitbringt (`plan.sun`). Das
 * wechselt zweimal am Tag und nicht alle fünf Minuten, wie es eine Schwelle auf die gemessene
 * Leistung täte - eine Wolke um 13 Uhr ist kein Abend.
 *
 * **Nicht mehr aus der Ertragsprognose.** Bis zum 26.11.2026 galten als Aufgang und Untergang die
 * erste und die letzte Viertelstunde, in der die Prognose mehr als 50 Watt kannte. An jenem Tag
 * standen damit 08:45 und 16:45 an den Enden des Bogens, die Sonne ging aber um 08:09 auf und um
 * 16:36 unter; um 09:17 saß sie im Bild noch am Horizont (Hausherr: „Es passt doch nicht“). Die
 * Erzeugung beginnt später, als die Sonne aufgeht, und das ist eine andere Auskunft.
 *
 * Alles hier ist reine Rechnung, damit es Tests gibt; die Zeichnung steht in `Ambiente.tsx`.
 */
export type Bild = "tag" | "abend";

/** Ab dieser Leistung zählt eine Viertelstunde als Erzeugung. Nur für den Ersatz unten. */
const SONNE_KW = 0.05;
/** Erzeugt die Anlage so viel, ist es Tag, auch wenn der Fahrplan nichts vom Sonnenlauf weiß. */
const TROTZDEM_TAG_KW = 0.3;
const SCHRITT_MS = 15 * 60_000;

export interface Sonnenlauf {
  /** Aufgang und Untergang der Sonne. */
  von: number;
  bis: number;
}

/** Aufgang und Untergang je Tag, wie der Fahrplan sie mitbringt, nach der Zeit geordnet. */
function sonnentage(plan: Plan | null): Sonnenlauf[] {
  return (plan?.sun ?? [])
    .map((s) => ({ von: new Date(s.sunrise).getTime(), bis: new Date(s.sunset).getTime() }))
    .filter((s) => Number.isFinite(s.von) && Number.isFinite(s.bis) && s.bis > s.von)
    .sort((a, b) => a.von - b.von);
}

/**
 * Der Sonnenlauf des heutigen Tages: Aufgang und Untergang am Standort des Hauses. Null, wenn der
 * Plan nichts dazu sagt.
 *
 * **Der Ersatz.** Ein Dienst vor dem 26.11.2026 schickt `sun` nicht mit. Dann gilt wie vorher das
 * Fenster der erwarteten Erzeugung: ein ungefährer Himmel ist besser als keiner, und Dienst und
 * Oberfläche werden nicht im selben Augenblick erneuert.
 */
export function sonnenlauf(plan: Plan | null, nowMs: number): Sonnenlauf | null {
  const tag = grenzen("heute", nowMs);
  const heute = sonnentage(plan).find((s) => s.von >= tag.start && s.von < tag.end);
  if (heute) return heute;
  const hell = (plan?.intervals ?? [])
    .map((i) => ({ ts: new Date(i.ts).getTime(), kw: i.expected_pv_kw }))
    .filter((p) => p.ts >= tag.start && p.ts < tag.end && p.kw > SONNE_KW)
    .sort((a, b) => a.ts - b.ts);
  if (!hell.length) return null;
  return { von: hell[0]!.ts, bis: hell[hell.length - 1]!.ts + SCHRITT_MS };
}

/**
 * Wann die Sonne das nächste Mal aufgeht: heute, wenn es noch vor dem Aufgang ist, sonst morgen.
 * Weiß der Fahrplan nichts vom Sonnenlauf, gilt der Beginn der Erzeugung aus dem Ausblick.
 */
export function naechsterAufgang(plan: Plan | null, nowMs: number, blick: Ausblick): number | null {
  const tage = sonnentage(plan);
  if (tage.length) return tage.find((s) => s.von > nowMs)?.von ?? null;
  return blick.nacht ? blick.sonneWechsel : null;
}

/** Tag zwischen Aufgang und Untergang; sonst nur, wenn die Anlage trotzdem liefert. */
export function bild(lauf: Sonnenlauf | null, nowMs: number, pvKw: number | null | undefined): Bild {
  if (lauf && nowMs >= lauf.von && nowMs <= lauf.bis) return "tag";
  return pvKw != null && pvKw >= TROTZDEM_TAG_KW ? "tag" : "abend";
}

export interface Aussicht {
  /** Was der ganze Tag bringen soll. */
  erwartetKwh: number | null;
  /** Was ab jetzt noch kommt. */
  restKwh: number | null;
}

export function aussicht(plan: Plan | null, nowMs: number): Aussicht {
  const tag = grenzen("heute", nowMs);
  return {
    erwartetKwh: pvSumme(plan?.intervals, tag.start, tag.end),
    restKwh: pvSumme(plan?.intervals, Math.max(nowMs, tag.start), tag.end),
  };
}
