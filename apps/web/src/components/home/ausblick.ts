import type { Plan } from "@/lib/api/models";

/**
 * Der Ausblick der Startseite: was in den nächsten 24 Stunden kommt.
 *
 * **Warum es ihn gibt.** Die Startseite sagte, was gerade ist, in Kilowatt. Was ein Mensch im Haus
 * daraus machen soll, sagte sie nicht: „Strom gerade 38,3 ct" ist eine Zahl ohne Maß, und der
 * Fahrplan stand als drei Textzeilen in einer Kachel. Der Ausblick beantwortet drei Fragen, die
 * man sich mit dem Handy in der Hand stellt:
 *
 * - Ist Strom gerade teuer oder günstig? Gemessen an den nächsten 24 Stunden, nicht an einer
 *   festen Grenze: 30 ct sind im Januar günstig und im Mai teuer.
 * - Wann ist er am günstigsten, und wann scheint die Sonne? Das ist die Auskunft für alles, was
 *   sich verschieben lässt: Waschmaschine, Spülmaschine, Trockner.
 * - Wann läuft die Wärmepumpe das nächste Mal?
 *
 * Reine Rechnung auf dem Fahrplan, den die Seite ohnehin hat. Keine Annahme über den
 * Hausverbrauch: das Sonnenfenster ist die Zeit der höchsten erwarteten Erzeugung, nicht eine
 * Zusage, dass Überschuss da ist.
 */
export const SCHRITT_MS = 15 * 60_000;
/** Der Ausblick reicht 24 Stunden. */
export const ZELLEN = 96;
/** Ein Fenster für verschiebbare Verbraucher: zwei Stunden, so lange läuft eine Waschmaschine. */
export const FENSTER_ZELLEN = 8;
/** Unter dieser Spanne zwischen billigstem und teuerstem Preis lohnt kein Verschieben. */
export const MIN_SPANNE_CT = 4;
/** Ab dieser erwarteten Leistung gilt die Sonne als da; darunter ist es Dämmerung oder Nacht. */
export const SONNE_AB_KW = 0.05;
/** Ein Sonnenfenster wird nur genannt, wenn die Erwartung darin im Mittel so hoch ist. */
export const SONNENFENSTER_AB_KW = 1.0;

export interface Zelle {
  ts: number;
  preis: number | null;
  pv: number;
  wp: boolean;
  ofen: boolean;
}

export interface Fenster {
  start: number;
  end: number;
  /** Mittlerer Preis in ct/kWh beim Preisfenster, mittlere erwartete Leistung in kW beim Sonnenfenster. */
  mittel: number;
}

export type Preislage = "günstig" | "mittel" | "teuer" | "gleichmäßig";

export interface Ausblick {
  zellen: Zelle[];
  preisJetzt: number | null;
  preisMin: number | null;
  preisMax: number | null;
  /** Wo der jetzige Preis unter den bekannten Preisen der nächsten 24 Stunden liegt. */
  lage: Preislage | null;
  /** Die günstigsten zwei Stunden am Stück. Fehlt, wenn die Preise kaum auseinanderliegen. */
  guenstig: Fenster | null;
  /** Die zwei Stunden mit der meisten erwarteten Sonne. Fehlt an einem trüben Tag. */
  sonne: Fenster | null;
  /** Die höchste erwartete Erzeugung im Ausblick, in kW. */
  pvMax: number;
  /** Es ist dunkel: keine Erzeugung erwartet. */
  nacht: boolean;
  /** Wann die Sonne wiederkommt, wenn es dunkel ist; wann sie geht, wenn sie scheint. */
  sonneWechsel: number | null;
  /** Bis wohin Preise bekannt sind, wenn nicht für den ganzen Ausblick. */
  preiseBis: number | null;
}

/** Anteil der Preise, die unter `p` liegen. 0 ist der billigste Moment, 1 der teuerste. */
function rang(p: number, alle: number[]): number {
  if (alle.length < 2) return 0.5;
  const darunter = alle.filter((x) => x < p).length;
  return darunter / (alle.length - 1);
}

/** Das Fenster aus `n` Zellen am Stück mit dem kleinsten oder größten Mittel von `wert`. */
function bestesFenster(zellen: Zelle[], n: number, wert: (z: Zelle) => number | null, kleinstes: boolean): Fenster | null {
  let bestes: Fenster | null = null;
  for (let i = 0; i + n <= zellen.length; i++) {
    let summe = 0;
    let vollstaendig = true;
    for (let j = i; j < i + n; j++) {
      const w = wert(zellen[j]!);
      // Zellen müssen lückenlos aufeinander folgen: ein Fenster über eine Lücke im Fahrplan
      // wäre länger als zwei Stunden.
      if (w == null || (j > i && zellen[j]!.ts - zellen[j - 1]!.ts !== SCHRITT_MS)) {
        vollstaendig = false;
        break;
      }
      summe += w;
    }
    if (!vollstaendig) continue;
    const mittel = summe / n;
    if (!bestes || (kleinstes ? mittel < bestes.mittel - 1e-9 : mittel > bestes.mittel + 1e-9)) {
      bestes = { start: zellen[i]!.ts, end: zellen[i + n - 1]!.ts + SCHRITT_MS, mittel };
    }
  }
  return bestes;
}

export function ausblick(plan: Plan | null, nowMs: number): Ausblick {
  const ende = nowMs + ZELLEN * SCHRITT_MS;
  const zellen: Zelle[] = (plan?.intervals ?? [])
    .map((iv) => ({ iv, t: new Date(iv.ts).getTime() }))
    // Die laufende Viertelstunde gehört dazu: in ihr steht der Preis von jetzt.
    .filter(({ t }) => t + SCHRITT_MS > nowMs && t < ende)
    .sort((a, b) => a.t - b.t)
    // Genau 24 Stunden ab der laufenden Viertelstunde, auch wenn sie schon zur Hälfte vorbei ist.
    .slice(0, ZELLEN)
    .map(({ iv, t }) => ({
      ts: t,
      preis: iv.price_ct_kwh ?? null,
      pv: Math.max(0, iv.expected_pv_kw ?? 0),
      // Nur was der Optimierer geplant hat. Wo die Preisregel einspringt, steht kein Fahrplan.
      wp: iv.reason_code === "planned_optimizer" && iv.planned_hp_state === "release",
      ofen: iv.planned_stove_on === true,
    }));

  const preise = zellen.map((z) => z.preis).filter((p): p is number => p != null);
  const preisJetzt = zellen[0]?.preis ?? null;
  const preisMin = preise.length ? Math.min(...preise) : null;
  const preisMax = preise.length ? Math.max(...preise) : null;
  const spanne = preisMin != null && preisMax != null ? preisMax - preisMin : 0;

  let lage: Preislage | null = null;
  if (preisJetzt != null && preise.length >= FENSTER_ZELLEN) {
    if (spanne < MIN_SPANNE_CT) lage = "gleichmäßig";
    else {
      const r = rang(preisJetzt, preise);
      lage = r < 1 / 3 ? "günstig" : r > 2 / 3 ? "teuer" : "mittel";
    }
  }

  const guenstig = spanne >= MIN_SPANNE_CT ? bestesFenster(zellen, FENSTER_ZELLEN, (z) => z.preis, true) : null;
  const sonnigstes = bestesFenster(zellen, FENSTER_ZELLEN, (z) => z.pv, false);
  const sonne = sonnigstes && sonnigstes.mittel >= SONNENFENSTER_AB_KW ? sonnigstes : null;

  const nacht = zellen.length > 0 && zellen[0]!.pv < SONNE_AB_KW;
  const wechsel = zellen.find((z, i) => i > 0 && (nacht ? z.pv >= SONNE_AB_KW : z.pv < SONNE_AB_KW));

  const letzterPreis = [...zellen].reverse().find((z) => z.preis != null);
  const preiseBis = letzterPreis && letzterPreis.ts + SCHRITT_MS < ende - SCHRITT_MS ? letzterPreis.ts + SCHRITT_MS : null;

  return {
    zellen,
    preisJetzt,
    preisMin,
    preisMax,
    lage,
    guenstig,
    sonne,
    pvMax: zellen.reduce((m, z) => Math.max(m, z.pv), 0),
    nacht,
    sonneWechsel: wechsel ? wechsel.ts : null,
    preiseBis,
  };
}

/** Zusammenhängende Abschnitte, in denen `an` gilt, als Zellennummern [von, bis). */
export function abschnitte(zellen: Zelle[], an: (z: Zelle) => boolean): Array<[number, number]> {
  const out: Array<[number, number]> = [];
  let start = -1;
  zellen.forEach((z, i) => {
    const ja = an(z);
    if (ja && start < 0) start = i;
    if (!ja && start >= 0) {
      out.push([start, i]);
      start = -1;
    }
  });
  if (start >= 0) out.push([start, zellen.length]);
  return out;
}
