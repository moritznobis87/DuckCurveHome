/**
 * Der Kalendertag als ISO-Datum, an einer Stelle.
 *
 * Die Funktion stand in ReportShell und wird jetzt auch von der Navigation im Dashboard gebraucht.
 * Dort die Berichtshuelle zu importieren, nur um ein Datum zu formatieren, zoege die halbe
 * Berichtsschicht in das Dashboard-Bundel. Also liegt sie hier, ohne React und ohne Abhaengigkeiten.
 */
function isoDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/** Heutiges Datum im Haus-Zeitraum (Europe/Berlin), unabhängig von der Zeitzone des Geräts. */
export function isoToday(): string {
  try {
    return new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Berlin", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
  } catch {
    return isoDate(new Date());
  }
}

/** Ein Kalendertag als ISO-Datum in der Ortszeit des Geraets. `sv-SE` liefert genau YYYY-MM-DD. */
export function isoDay(ms: number): string {
  return new Date(ms).toLocaleDateString("sv-SE");
}

/**
 * Ist das ein Kalendertag, mit dem die Oberflaeche rechnen kann?
 *
 * Die Form allein genuegt nicht. `2026-13-45` besteht jede Pruefung mit regulaerem Ausdruck und
 * ergibt doch ein `Invalid Date`; `new Date(NaN).toLocaleDateString()` liefert sogar genau diese
 * Zeichenkette zurueck. Darum wird zurueckgerechnet: was sich nicht wieder zu sich selbst
 * formatieren laesst, ist keiner.
 */
export function istTagIso(s: string | null | undefined): s is string {
  if (!s || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T12:00:00`);
  return Number.isFinite(d.getTime()) && isoDate(d) === s;
}

export { isoDate };
