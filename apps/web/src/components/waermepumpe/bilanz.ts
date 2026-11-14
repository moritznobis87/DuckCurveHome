import type { KennlinienBilanz } from "@/lib/api/models";

/**
 * Wo die Minuten geblieben sind: die Bilanz der Kennlinie als Balken.
 *
 * Am 14.11.2026 lief die Wärmepumpe Stunden, und die Seite zeigte keinen einzigen Punkt, ohne
 * zu sagen, warum. Seitdem zählt die Rechnung mit, woran jede Minute im Heizbetrieb scheiterte.
 * Die Teile hier ergeben zusammen die Minuten, in denen die Maschine heizte; ein Teil ohne
 * Minuten steht nicht im Balken.
 */
export type TeilArt = "gueltig" | "anlauf" | "ohne_wert" | "zusatz" | "ohne_waerme";

export type Teil = { art: TeilArt; name: string; minuten: number; anteil: number; wozu: string };

const FOLGE: { art: TeilArt; name: string; wozu: string }[] = [
  { art: "gueltig", name: "brauchbar", wozu: "eingeschwungen, alle Werte da" },
  { art: "anlauf", name: "Anlauf", wozu: "die ersten zehn Minuten nach jedem Start" },
  { art: "zusatz", name: "Heizstab", wozu: "neben dem Verdichter nahm etwas anderes Strom auf" },
  { art: "ohne_waerme", name: "keine Wärme", wozu: "kaum Durchfluss oder keine Spreizung" },
  // Zuletzt, und nicht neben dem Heizstab: die beiden warmen Töne lägen sonst aneinander.
  { art: "ohne_wert", name: "Wert fehlte", wozu: "ein nötiger Wert kam länger nicht vom Bus" },
];

export function teile(b: KennlinienBilanz): Teil[] {
  const summe = FOLGE.reduce((s, f) => s + b[f.art], 0);
  if (summe <= 0) return [];
  return FOLGE.filter((f) => b[f.art] > 0).map((f) => ({ ...f, minuten: b[f.art], anteil: b[f.art] / summe }));
}

/** Eine Dauer in Minuten, wie man sie sagt: „45 min“, „3 h 20 min“, „2 h“. */
export function dauer(minuten: number): string {
  const m = Math.max(0, Math.round(minuten));
  if (m < 60) return `${m} min`;
  const rest = m % 60;
  return rest ? `${Math.floor(m / 60)} h ${rest} min` : `${m / 60} h`;
}

/** Welche Werte fehlten, der häufigste zuerst. */
export function fehlend(b: KennlinienBilanz): { name: string; minuten: number }[] {
  return Object.entries(b.fehlt ?? {})
    .map(([name, minuten]) => ({ name, minuten }))
    .filter((f) => f.minuten > 0)
    .sort((x, y) => y.minuten - x.minuten || x.name.localeCompare(y.name, "de"));
}

/** Fenster, die begonnen, aber nicht voll genug wurden. */
export function halbeFenster(b: KennlinienBilanz): number {
  return Math.max(0, b.fenster - b.punkte - b.unglaubwuerdig);
}
