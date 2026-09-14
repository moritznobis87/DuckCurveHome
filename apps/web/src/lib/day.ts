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

export { isoDate };
