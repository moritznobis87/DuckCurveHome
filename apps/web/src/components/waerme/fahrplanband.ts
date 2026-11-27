// Der Streifen „Wärmepumpe geplant“ des Fahrplans: was für eine Viertelstunde als Absicht gilt.
//
// **Warum es das gibt.** Der Optimierer rechnet ab jetzt. Für die Viertelstunden davor griff im
// Dienst die Preisregel, und sie antwortet mit den Fenstern von heute. Der Streifen zeigte links
// der Jetzt-Linie also nicht, was man vorhatte, als man in die Stunde hineinging, sondern was
// die Regel heute über sie sagen würde. Seit dem 27.11.2026 liefert der Dienst die Absicht des
// Fahrplans von damals aus dem Archiv (`past_plan_hp_release`), und die vergangenen
// Viertelstunden werden daraus gezeichnet.
//
// Dieselbe Regel steht in der App in `Fahrplanbild.absicht`.

import type { Plan } from "@/lib/api/models";

type Intervall = Plan["intervals"][number];

const VIERTELSTUNDE_MS = 15 * 60_000;

/**
 * Der Beginn der Viertelstunde, in der der Fahrplan gerechnet wurde. Davor liegt seine
 * Vergangenheit: Der Dienst fragt das Archiv genau für diese Viertelstunden.
 */
export function laufendeViertelstunde(plan: Pick<Plan, "created_at">): number {
  return Math.floor(new Date(plan.created_at).getTime() / VIERTELSTUNDE_MS) * VIERTELSTUNDE_MS;
}

/**
 * Was der Streifen für eine Viertelstunde zeigt.
 *
 * `jetzt`: der laufende Fahrplan mit seinen vier Zuständen. `damals`: der Fahrplan von damals,
 * der nur Ja oder Nein kennt, weil das Archiv „gemieden“ und „aus“ als dasselbe Nein ablegt.
 * `ohne`: Der Fahrplan von damals gab nichts vor, oder es ist keiner aufbewahrt. Beides sieht im
 * Archiv gleich aus, und im Streifen bleibt die Stelle leer.
 */
export type Absicht =
  | { art: "jetzt"; zustand: string }
  | { art: "damals"; freigabe: boolean }
  | { art: "ohne" };

export function absicht(i: Intervall, laufendeMs: number): Absicht {
  if (new Date(i.ts).getTime() >= laufendeMs) return { art: "jetzt", zustand: i.planned_hp_state };
  if (i.past_plan_hp_release == null) return { art: "ohne" };
  return { art: "damals", freigabe: i.past_plan_hp_release };
}

/** Das Wort zur Absicht von damals, für die Auskunft zur Viertelstunde. */
export function damalsWort(a: Absicht): string | null {
  if (a.art === "jetzt") return null;
  if (a.art === "ohne") return "ohne Vorgabe";
  return a.freigabe ? "angefordert" : "nicht angefordert";
}

/**
 * Wie viele der gemessenen Viertelstunden der Fahrplan von damals freigegeben hatte.
 *
 * `null`, wenn das Archiv für keine von ihnen etwas weiß: Dann gibt es keinen Vergleich, und
 * null Stunden wären eine Behauptung.
 */
export function damalsFreigegeben(gemessen: Intervall[]): number | null {
  const bekannt = gemessen.filter((i) => i.past_plan_hp_release != null);
  if (bekannt.length === 0) return null;
  return bekannt.filter((i) => i.past_plan_hp_release === true).length;
}
