import { hhmm } from "@/lib/format";
import type { Fenster, Zelle } from "./ausblick";

/**
 * Die nächsten 24 Stunden stundenweise, für den Ring der „Uhr“ und für das Bild „Nächste 24
 * Stunden“ der Bühne. Gerechnet wird hier und im Kit in `Stundenring.swift`, mit denselben
 * Prüfwerten in beiden Tests.
 */
const STUNDE_MS = 3_600_000;

export interface Stunde {
  /** Beginn der Stunde. */
  start: number;
  /** Die Stunde des Tages, 0 bis 23. */
  stunde: number;
  /** Der mittlere Preis der Stunde in ct; `null`, solange es noch keinen gibt. */
  preis: number | null;
  /** Die erwartete Sonne im Mittel der Stunde. */
  sonneKw: number;
  /** In dieser Stunde ist ein Lauf der Wärmepumpe geplant. */
  wp: boolean;
  /** In dieser Stunde soll der Pelletofen brennen. */
  ofen: boolean;
  /** Die Stunde liegt im Preistief. */
  tief: boolean;
}

/** Höchstens 24 Stunden ab der laufenden, aus den Viertelstunden des Ausblicks. */
export function stunden24(zellen: Zelle[], guenstig: Fenster | null): Stunde[] {
  const out: Stunde[] = [];
  const summen: Array<{ preis: number; preise: number; sonne: number; zellen: number }> = [];
  for (const z of zellen) {
    const d = new Date(z.ts);
    d.setMinutes(0, 0, 0);
    const start = d.getTime();
    if (!out.length || out[out.length - 1]!.start !== start) {
      if (out.length === 24) break;
      // Die Stunde in der Zeit des Hauses, so wie jede Uhrzeit der Oberfläche, nicht in der des Geräts.
      out.push({ start, stunde: Number(hhmm(d).slice(0, 2)), preis: null, sonneKw: 0, wp: false, ofen: false, tief: false });
      summen.push({ preis: 0, preise: 0, sonne: 0, zellen: 0 });
    }
    const s = summen[summen.length - 1]!;
    if (z.preis != null) {
      s.preis += z.preis;
      s.preise += 1;
    }
    s.sonne += z.pv;
    s.zellen += 1;
    if (z.wp) out[out.length - 1]!.wp = true;
    if (z.ofen) out[out.length - 1]!.ofen = true;
  }
  out.forEach((st, i) => {
    const s = summen[i]!;
    st.preis = s.preise ? s.preis / s.preise : null;
    st.sonneKw = s.zellen ? s.sonne / s.zellen : 0;
    st.tief = guenstig != null && st.start < guenstig.end && st.start + STUNDE_MS > guenstig.start;
  });
  return out;
}

/** Der Winkel einer Uhrzeit auf dem Ring im Bogenmaß: 00 Uhr steht oben, es geht im Uhrzeigersinn. */
export function stundenwinkel(stunde: number): number {
  return (stunde / 24) * 2 * Math.PI - Math.PI / 2;
}

/**
 * Wie lang die Speiche oder Säule eines Preises ist, von 0 bis 1. Gemessen wird am höchsten Preis
 * des Tages, mindestens an 40 ct, damit ein ruhiger Tag nicht wie ein teurer aussieht.
 */
export function preislaenge(preis: number, hoechster: number | null): number {
  return Math.max(0, Math.min(1, preis / Math.max(40, hoechster ?? 0)));
}

export interface Ringmass {
  mitteX: number;
  mitteY: number;
  /** Der äußere Radius; die Speichen beginnen bei `preis`, darunter liegen Sonne und Wärmepumpe. */
  radius: number;
  preis: number;
  sonne: number;
  pumpe: number;
  zahl: number;
}

/** Die Maße des Rings aus der Breite und Höhe seiner Bühne. Am Fuß bleiben 26 Pixel für die Legende. */
export function ringmass(breite: number, hoehe: number): Ringmass {
  const schmal = breite < 520;
  const radius = Math.max(40, Math.min(schmal ? breite / 2 - 30 : 152, (hoehe - 26) / 2 - 16));
  return { mitteX: breite / 2, mitteY: (hoehe - 26) / 2 + 2, radius, preis: radius - 34, sonne: radius - 46, pumpe: radius - 58, zahl: radius - 74 };
}
