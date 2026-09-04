/* Zahlen- und Zeitformate für das Dashboard (de-DE, schmales Leerzeichen vor Einheiten). */

const NNBSP = " ";
const nf1 = new Intl.NumberFormat("de-DE", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const nf0 = new Intl.NumberFormat("de-DE", { maximumFractionDigits: 0 });

export function kw(value: number | null | undefined, digits: 1 | 0 = 1): string {
  if (value === null || value === undefined || Number.isNaN(value)) return "–";
  const abs = Math.abs(value) < 0.05 ? 0 : value;
  return (digits === 1 ? nf1 : nf0).format(abs).replace("-", "−");
}

export function kwWithUnit(value: number | null | undefined): string {
  const v = kw(value);
  return v === "–" ? v : `${v}${NNBSP}kW`;
}

export function kwh(value: number | null | undefined): string {
  if (value === null || value === undefined) return "–";
  return `${nf1.format(value)}${NNBSP}kWh`;
}

export function percent(fraction: number | null | undefined): string {
  if (fraction === null || fraction === undefined) return "–";
  return `${nf0.format(Math.round(fraction * 100))}${NNBSP}%`;
}

export function celsius(value: number | null | undefined, digits: 0 | 1 = 0): string {
  if (value === null || value === undefined) return "–";
  return `${(digits ? nf1 : nf0).format(value)}${NNBSP}°C`;
}

export function ct(value: number | null | undefined): string {
  if (value === null || value === undefined) return "–";
  return `${nf1.format(value).replace("-", "−")}${NNBSP}ct/kWh`;
}

const TZ = "Europe/Berlin";
const timeFmt = new Intl.DateTimeFormat("de-DE", { hour: "2-digit", minute: "2-digit", timeZone: TZ });
const dateFmt = new Intl.DateTimeFormat("de-DE", { weekday: "long", day: "numeric", month: "long", timeZone: TZ });

export function hhmm(iso: string | Date | null | undefined): string {
  if (!iso) return "–";
  return timeFmt.format(typeof iso === "string" ? new Date(iso) : iso);
}

export function longDate(d: Date): string {
  return dateFmt.format(d);
}

export function ageLabel(observedAtIso: string, nowMs: number): string | null {
  const age = Math.max(0, (nowMs - new Date(observedAtIso).getTime()) / 1000);
  if (age < 30) return null;
  if (age < 90) return `vor ${Math.round(age)} s`;
  if (age < 3600) return `vor ${Math.round(age / 60)} min`;
  return `vor ${Math.round(age / 3600)} h`;
}

export function minutesUntil(iso: string | null | undefined, nowMs: number): number | null {
  if (!iso) return null;
  return Math.max(0, Math.round((new Date(iso).getTime() - nowMs) / 60000));
}
