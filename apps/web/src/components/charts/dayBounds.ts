/**
 * Tagesgrenzen und Preisachse, ohne React.
 *
 * Standen im Tagesdiagramm der alten Startseite. Die Prognoseseite und die neue Tageskurve
 * brauchen beides weiter, das Diagramm selbst nicht mehr.
 */
function berlinOffsetMs(at: number): number {
  const parts = new Intl.DateTimeFormat("en-US", { timeZone: "Europe/Berlin", hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" }).formatToParts(new Date(at));
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value ?? 0);
  return Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second")) - at;
}

/** Mitternacht in Europe/Berlin als UTC-Zeitstempel - unabhängig von der Zeitzone des Browsers. */
/** Skalierung der Preisachse.
 *
 * Der Strompreis schwankt an einem Tag oft nur zwischen 18 und 45 ct. Eine Achse, die bei 0 beginnt,
 * drückt den Verlauf dann in das obere Drittel und macht ihn flach - deshalb spannt sie hier zwischen
 * dem tatsächlichen Minimum und Maximum auf, gerundet auf runde Schritte und mit etwas Luft, damit die
 * Kurve die Ränder nicht berührt. Negative Preise kommen vor und werden mit erfasst.
 */
export function priceBounds(rows: Array<Array<number | null>>): { min: number; max: number; step: number } {
  const values = rows.map((p) => p[1]).filter((v): v is number => typeof v === "number" && Number.isFinite(v));
  if (values.length === 0) return { min: 0, max: 45, step: 15 };
  const lo = Math.min(...values);
  const hi = Math.max(...values);
  const pad = Math.max(0.5, (hi - lo) * 0.06); // wenig Luft, damit die Kurve die Ränder nicht berührt
  // Der feinste runde Schritt, der mit höchstens sieben Abschnitten auskommt. Weil die Schrittweiten
  // ansteigen, ist der erste Treffer zugleich der mit der engsten Spanne - und je enger die Spanne,
  // desto mehr Höhe bleibt für den Verlauf. Ein gröberer Schritt reißt die Achse beim Runden wieder auf:
  // bei 22-46 ct ergibt Schritt 5 die Spanne 20-50, Schritt 10 dagegen 20-50 → 10-50, Schritt 20 sogar 0-60.
  for (const step of [0.5, 1, 2, 2.5, 5, 10, 20, 25, 50, 100]) {
    const min = Math.floor((lo - pad) / step) * step;
    const max = Math.ceil((hi + pad) / step) * step;
    if ((max - min) / step <= 7) return { min, max: Math.max(max, min + 2 * step), step };
  }
  return { min: Math.floor(lo - pad), max: Math.ceil(hi + pad), step: Math.max(1, Math.round((hi - lo) / 3)) };
}

export function dayBounds(nowMs: number): [number, number] {
  const off = berlinOffsetMs(nowMs);
  const local = new Date(nowMs + off);
  const midnightLocal = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  const start = midnightLocal - berlinOffsetMs(midnightLocal - off);
  return [start, start + 24 * 3600 * 1000];
}

