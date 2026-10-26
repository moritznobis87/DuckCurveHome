import type { EnergySummary, HeatReport, Plan } from "@/lib/api/models";
import { isoDay } from "@/lib/day";

/**
 * Gestern, heute, morgen: die drei Tage der Startseite.
 *
 * **Warum drei und nicht mehr.** Wer vorbeigeht, fragt dreierlei: Was war gestern los, was ist
 * jetzt, und was kommt morgen. Alles darüber hinaus ist Analyse und steht in den Bereichen, mit
 * Blättern und allem. Die Wandanzeige kehrt deshalb von selbst zu „heute" zurück (siehe
 * `Home`), damit sie nicht tagelang auf einem Gestern stehen bleibt.
 *
 * **Jeder Tag hat andere Zahlen, nicht dieselben mit anderem Inhalt.** Gestern ist abgerechnet
 * („bezahlt"), heute läuft („bezahlt bis jetzt", dazu der Preis in diesem Moment), morgen ist
 * Vorschau: erwartete Sonne, erwartete Wärme, der Preis, den die Börse für morgen veröffentlicht
 * hat. Eine Zahl, die es für einen Tag nicht geben kann, steht als Strich da und sagt im Wort,
 * warum.
 */
export type Tag = "gestern" | "heute" | "morgen";

export const TAGE: Tag[] = ["gestern", "heute", "morgen"];
export const TAG_WORT: Record<Tag, string> = { gestern: "Gestern", heute: "Heute", morgen: "Morgen" };

/** Kalendertag des Geräts, um `versatz` Tage verschoben. Über `setDate`, damit Zeitumstellungen stimmen. */
export function grenzen(tag: Tag, nowMs: number): { start: number; end: number; iso: string } {
  const versatz = tag === "gestern" ? -1 : tag === "morgen" ? 1 : 0;
  const start = new Date(nowMs);
  start.setHours(0, 0, 0, 0);
  start.setDate(start.getDate() + versatz);
  const end = new Date(start);
  end.setDate(start.getDate() + 1);
  return { start: start.getTime(), end: end.getTime(), iso: isoDay(start.getTime()) };
}

export interface Kennzahl {
  wert: string;
  einheit: string;
  wort: string;
  /** Gelb für die Sonne und für einen negativen Preis: beides ist ein Gewinn. */
  gelb?: boolean;
}

type PlanInterval = Plan["intervals"][number];
type HeatPoint = HeatReport["forecast"][number];

const de = (n: number | null | undefined, stellen: number): string =>
  n == null || !Number.isFinite(n) ? "-" : n.toFixed(stellen).replace(".", ",");

const uhr = (ms: number): string => {
  const d = new Date(ms);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
};

/** Erwartete Erzeugung im Fenster, aus dem Raster der Planintervalle. */
export function pvSumme(intervals: PlanInterval[] | undefined, start: number, end: number): number | null {
  const pts = (intervals ?? []).map((i) => ({ ts: new Date(i.ts).getTime(), kw: i.expected_pv_kw }));
  if (pts.length < 2) return null;
  const schrittH = Math.max(1 / 60, (pts[1]!.ts - pts[0]!.ts) / 3600_000);
  const drin = pts.filter((p) => p.ts >= start && p.ts < end);
  if (!drin.length) return null;
  return drin.reduce((a, p) => a + p.kw * schrittH, 0);
}

/** Die Preise, die für das Fenster bekannt sind. Leer heißt: die Börse hat sie noch nicht. */
export function preise(intervals: PlanInterval[] | undefined, start: number, end: number): Array<{ ts: number; ct: number }> {
  return (intervals ?? [])
    .map((i) => ({ ts: new Date(i.ts).getTime(), ct: i.price_ct_kwh }))
    .filter((p): p is { ts: number; ct: number } => p.ct != null && p.ts >= start && p.ts < end);
}

/**
 * Wärmebedarf und Strom dafür, aus der stündlichen Wärmelastprognose.
 *
 * Die Punkte sind Stundenwerte in kW, eine Stunde lang - die Summe ist damit zugleich die
 * Energiemenge in kWh.
 */
export function waermeSumme(punkte: HeatPoint[] | undefined, start: number, end: number): { thermisch: number; elektrisch: number } | null {
  const drin = (punkte ?? []).filter((p) => {
    const t = new Date(p.ts).getTime();
    return t >= start && t < end;
  });
  if (!drin.length) return null;
  return {
    thermisch: drin.reduce((a, p) => a + p.heating_kw + p.dhw_kw, 0),
    elektrisch: drin.reduce((a, p) => a + p.electric_kw, 0),
  };
}

export interface MorgenDaten {
  pvKwh: number | null;
  waerme: { thermisch: number; elektrisch: number } | null;
  preise: Array<{ ts: number; ct: number }>;
}

/** Die vier Zahlen unter der Kurve. Immer vier, damit die Zeile beim Umschalten nicht springt. */
export function kennzahlen(tag: Tag, summary: EnergySummary | null, preisJetzt: number | null, morgen: MorgenDaten): Kennzahl[] {
  if (tag === "morgen") {
    const ct = morgen.preise.map((p) => p.ct);
    const mittel = ct.length ? ct.reduce((a, b) => a + b, 0) / ct.length : null;
    const guenstigste = morgen.preise.length
      ? morgen.preise.reduce((a, b) => (b.ct < a.ct ? b : a))
      : null;
    return [
      { wert: de(morgen.pvKwh, 1), einheit: "kWh", wort: "Sonne erwartet", gelb: true },
      {
        wert: de(morgen.waerme?.thermisch ?? null, 1),
        einheit: "kWh",
        wort: morgen.waerme ? `Wärme erwartet · ${de(morgen.waerme.elektrisch, 1)} kWh Strom` : "Wärme erwartet",
      },
      { wert: de(mittel, 1), einheit: "ct", wort: ct.length ? "Strom im Mittel" : "Preise kommen gegen 13 Uhr" },
      {
        wert: de(guenstigste?.ct ?? null, 1),
        einheit: "ct",
        wort: guenstigste ? `günstigste Stunde ab ${uhr(guenstigste.ts)}` : "günstigste Stunde",
        gelb: guenstigste != null && guenstigste.ct < 0,
      },
    ];
  }
  const t = summary?.totals ?? null;
  const letzte: Kennzahl =
    tag === "heute"
      ? { wert: de(preisJetzt, 1), einheit: "ct", wort: "Strom gerade", gelb: preisJetzt != null && preisJetzt < 0 }
      : { wert: de(t?.avg_import_price_ct ?? null, 1), einheit: "ct", wort: "Strom im Mittel" };
  return [
    { wert: de(t?.pv_kwh ?? null, 1), einheit: "kWh", wort: "Sonne geerntet", gelb: true },
    { wert: t?.autarky != null ? String(Math.round(t.autarky * 100)) : "-", einheit: "%", wort: "ohne Netz" },
    { wert: de(t?.import_cost_eur ?? null, 2), einheit: "€", wort: tag === "heute" ? "bezahlt bis jetzt" : "bezahlt" },
    letzte,
  ];
}

// -------------------------------------------------------------------- Die Schattenkurve

/** Ein Punkt einer Messreihe, so viel davon wie hier gebraucht wird. */
export interface Punkt {
  ts: number;
  pv: number | null;
}

/**
 * Der Tag davor, blass hinter dem Tag.
 *
 * **Warum.** Eine Kurve allein sagt nicht, ob der Tag gut war. 13,4 kWh sind viel oder wenig, je
 * nachdem, was gestern dastand - und genau diesen Vergleich macht sonst niemand, weil er zwei
 * Ansichten und ein Gedächtnis braucht. Hinter heute liegt deshalb gestern, hinter morgen heute.
 *
 * **Hinter gestern liegt nichts.** Vorgestern holt die Wandanzeige nicht; wer so weit zurück
 * will, ist unter Strom richtig, mit Blättern und allem.
 */
export interface Schatten {
  punkte: Punkt[];
  /** Tagesbeginn der Schattenreihe: Die Zeichnung legt sie darüber auf dieselbe Stundenachse. */
  start: number;
  end: number;
  /** Das Wort in der Legende: „gestern" hinter heute, „heute" hinter morgen. */
  wort: string;
  /** Die Sonne dieses Tages bis zur gleichen Uhrzeit, in kWh. Null, solange die Reihe fehlt. */
  kwh: number | null;
}

/**
 * Fläche unter der Sonnenleistung bis `bis`, in kWh: Trapeze zwischen den Messpunkten.
 *
 * Eine Lücke von mehr als einer Stunde wird übersprungen. Zwei Punkte mit einer Nacht dazwischen
 * sagen nichts über die Nacht, und als Trapez gerechnet ergäben sie eine Energie, die es nie gab.
 */
export function pvKwh(punkte: Punkt[], bis: number): number | null {
  let summe = 0;
  let paare = 0;
  for (let i = 1; i < punkte.length; i++) {
    const a = punkte[i - 1]!;
    const b = punkte[i]!;
    if (b.ts > bis) break;
    if (a.pv == null || b.pv == null) continue;
    const h = (b.ts - a.ts) / 3600_000;
    if (h <= 0 || h > 1) continue;
    summe += ((a.pv + b.pv) / 2) * h;
    paare++;
  }
  return paare ? summe : null;
}

/** Dieselbe Uhrzeit an einem anderen Tag. Über `setHours`, damit die Zeitumstellung stimmt. */
function gleicheUhrzeit(tagBeginn: number, nowMs: number): number {
  const jetzt = new Date(nowMs);
  const d = new Date(tagBeginn);
  d.setHours(jetzt.getHours(), jetzt.getMinutes(), 0, 0);
  return d.getTime();
}

export function schatten(tag: Tag, nowMs: number, gestern: Punkt[], heute: Punkt[]): Schatten | null {
  if (tag === "gestern") return null;
  const punkte = tag === "heute" ? gestern : heute;
  if (!punkte.length) return null;
  const vorher = grenzen(tag === "heute" ? "gestern" : "heute", nowMs);
  // Verglichen wird bis zur gleichen Uhrzeit, nicht bis zum Tagesende: „gestern um diese Zeit"
  // ist die Zahl, die etwas sagt. Hinter morgen liegt heute, und heute ist bis jetzt gelaufen.
  const bis = tag === "heute" ? gleicheUhrzeit(vorher.start, nowMs) : nowMs;
  return {
    punkte,
    start: vorher.start,
    end: vorher.end,
    wort: tag === "heute" ? "gestern" : "heute",
    kwh: pvKwh(punkte, bis),
  };
}
