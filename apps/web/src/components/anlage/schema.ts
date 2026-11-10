import type { Anlage, AnlageSpeicher, AnlageStrom } from "@/lib/api/models";

/**
 * Die reinen Rechnungen hinter dem Anlagenschema: Farben, Mischung, Tempo, Worte.
 *
 * Alles hier ist ohne Browser prüfbar. Die Zeichnung in `Schema.tsx` setzt nur zusammen, was
 * diese Funktionen liefern.
 */

/** Die Farben des Schemas. Dieselbe Semantik wie in tokens.css, hier als Leuchten auf tiefem
 *  Petrol, deshalb als Werte und nicht als Variablen: SVG-Verläufe nehmen keine `var()`. */
export const FARBE = {
  pv: "#f2a900",
  pvSoft: "#ffd778",
  netz: "#7fa3b3",
  speicher: "#9fd0df",
  ev: "#5c8fa3",
  hp: "#e0966b",
  ofen: "#c9742c",
  kalt: "#2a6f8f",
} as const;

/** Temperaturskala des Wassers: dieselbe für Glas und Rohre. Stützstellen in °C. */
type Rgb = readonly [number, number, number];
const STOPS: readonly { t: number; c: Rgb }[] = [
  { t: 10, c: [0x1a, 0x3a, 0x52] },
  { t: 25, c: [0x1f, 0x4c, 0x66] },
  { t: 35, c: [0x7f, 0xa3, 0xb3] },
  { t: 45, c: [0xff, 0xd7, 0x78] },
  { t: 55, c: [0xf2, 0xa9, 0x00] },
  { t: 65, c: [0xe0, 0x53, 0x3d] },
];
const ERSTE = STOPS[0] as { t: number; c: Rgb };
const LETZTE = STOPS[STOPS.length - 1] as { t: number; c: Rgb };

const rgb = (c: Rgb) => `rgb(${c[0]},${c[1]},${c[2]})`;

/** Die Farbe einer Wassertemperatur. Ohne Wert: das neutrale Blaugrau der Skala. */
export function farbe(t: number | null | undefined): string {
  if (t == null) return FARBE.netz;
  if (t <= ERSTE.t) return rgb(ERSTE.c);
  let vor = ERSTE;
  for (const s of STOPS) {
    if (t <= s.t) {
      const f = (t - vor.t) / (s.t - vor.t);
      const m = (k: 0 | 1 | 2) => Math.round(vor.c[k] + (s.c[k] - vor.c[k]) * f);
      return rgb([m(0), m(1), m(2)]);
    }
    vor = s;
  }
  return rgb(LETZTE.c);
}

/** Eine Zahl, deutsch, ohne Vorzeichen; die Richtung steht als Wort daneben. */
export const de = (n: number | null | undefined, stellen = 1): string =>
  n == null || Number.isNaN(n) ? "-" : Math.abs(n).toFixed(stellen).replace(".", ",");

/** Eine ganze Gradzahl, oder ein Strich. */
export const grad = (t: number | null | undefined): string => (t == null ? "-" : `${Math.round(t)} °`);

/** Unter dieser Leistung steht ein Rohr still. */
export const AN_KW = 0.05;
export const istAn = (kw: number | null | undefined): kw is number => kw != null && Math.abs(kw) >= AN_KW;

/** Umlaufzeit eines Lichtpunkts in Sekunden: schneller bei mehr Leistung, in Grenzen, und auf
 *  halbe Sekunden gerundet, damit ein neuer Messwert die Animation nicht bei jedem Abruf neu
 *  startet. Rückläufe laufen langsamer, damit der Vorlauf das Wort führt. */
export function rohrDauer(kw: number, leise = false): number {
  const roh = Math.max(2.4, Math.min(9, 16 / Math.max(Math.abs(kw), AN_KW))) * (leise ? 1.3 : 1);
  return Math.round(roh * 2) / 2;
}

/** Wie viele Lichtpunkte auf einem Rohr laufen: zwei bis sieben, mit der Leistung. */
export function partikelZahl(kw: number, leise = false): number {
  return Math.max(2, Math.min(7, Math.round(Math.abs(kw) * 0.8) + 2)) - (leise ? 1 : 0);
}

/** Strichstärke der Grundschicht eines Rohrs. */
export function rohrStaerke(kw: number | null | undefined, leise = false): number {
  return (istAn(kw) ? Math.min(14, 6 + Math.abs(kw) * 0.9) : 4) * (leise ? 0.6 : 1);
}

export type Mischung = { farben: string[] | null; text: string; haupt: string };

/** Woher der Strom im Knoten gerade kommt, als Folge von Punktfarben im Verhältnis der Anteile
 *  und als Satz. Die Anteile kommen fertig von der Schnittstelle.
 *
 *  Die sechs Punkte werden nach dem größten Rückstand vergeben: Platz für Platz bekommt die
 *  Quelle den Punkt, die gemessen an ihrem Anteil am weitesten hinterherhinkt. So liegen die
 *  Farben verschränkt statt blockweise, und zwei Punkte derselben kleinen Quelle stehen nicht
 *  nebeneinander. */
export function mischung(s: Pick<AnlageStrom, "share_pv" | "share_grid" | "share_battery">): Mischung {
  const q: { col: string; name: string; anteil: number }[] = [
    { col: FARBE.pv, name: "PV", anteil: s.share_pv },
    { col: FARBE.netz, name: "Netz", anteil: s.share_grid },
    { col: FARBE.speicher, name: "Speicher", anteil: s.share_battery },
  ];
  const summe = q.reduce((a, x) => a + x.anteil, 0);
  if (summe < 0.01) return { farben: null, text: "", haupt: FARBE.netz };
  const vergeben = q.map(() => 0);
  const farben: string[] = [];
  for (let i = 0; i < 6; i++) {
    let best = 0;
    let bestScore = -Infinity;
    q.forEach((x, k) => {
      const score = (x.anteil / summe) * (i + 1) - (vergeben[k] ?? 0);
      if (score > bestScore) {
        bestScore = score;
        best = k;
      }
    });
    vergeben[best] = (vergeben[best] ?? 0) + 1;
    farben.push(q[best]?.col ?? FARBE.netz);
  }
  const haupt = q.reduce((a, x) => (x.anteil > a.anteil ? x : a)).col;
  const text = q
    .filter((x) => x.anteil / summe >= 0.05)
    .map((x) => `${x.name} ${Math.round((x.anteil / summe) * 100)}\u00a0%`)
    .join(", ");
  return { farben, text, haupt };
}

/** „1 h 12 min", „38 min", oder leer, wenn es keinen Beginn gibt. */
export function dauerText(seitIso: string | null | undefined, nowMs: number): string {
  if (!seitIso) return "";
  const min = Math.max(0, Math.round((nowMs - new Date(seitIso).getTime()) / 60000));
  if (min < 60) return `${min} min`;
  const h = Math.floor(min / 60);
  const rest = min % 60;
  return rest ? `${h} h ${rest} min` : `${h} h`;
}

export const netzWort = (kw: number | null | undefined): string =>
  !istAn(kw) ? "ruht" : kw < 0 ? "Einspeisung" : "Bezug";

/** Batterie positiv heißt entladen, wie überall in Duck Curve Home. */
export const batterieWort = (kw: number | null | undefined): string =>
  !istAn(kw) ? "ruht" : kw > 0 ? "entlädt" : "lädt";

/** „lädt 1,2 kW", „entlädt 0,8 kW", „hält" oder leer: das Wort kommt von der Schnittstelle, die
 *  Schwelle steht dort an einer Stelle. */
export function nettoText(sp: Pick<AnlageSpeicher, "net_kw" | "net_word">): string {
  if (!sp.net_word) return "";
  return sp.net_word === "hält" ? "hält" : `${sp.net_word} ${de(sp.net_kw)} kW`;
}

export function nettoFarbe(sp: Pick<AnlageSpeicher, "net_kw" | "net_word">): string {
  if (sp.net_word !== "lädt" && sp.net_word !== "entlädt") return "rgba(255,255,255,.62)";
  return sp.net_word === "lädt" ? FARBE.pvSoft : FARBE.speicher;
}

/** Der Satz über dem Bild: wer gerade Wärme macht. */
export function erzeugerSatz(a: Pick<Anlage, "waermepumpe" | "ofen">, nowMs: number): string {
  if (a.waermepumpe.running) {
    const seit = dauerText(a.waermepumpe.running_since, nowMs);
    return seit ? `Wärmepumpe läuft seit ${seit}` : "Wärmepumpe läuft";
  }
  if (a.ofen.running) {
    return a.ofen.power_level != null ? `Ofen auf Stufe ${Math.round(a.ofen.power_level)}` : "Ofen brennt";
  }
  return "alle Erzeuger stehen";
}

export function kopfzeile(a: Anlage, nowMs: number): string {
  const teile: string[] = [];
  if (a.outdoor_c != null) teile.push(`${de(a.outdoor_c, 0)} °C draußen`.replace(/^(\d)/, a.outdoor_c < -0.5 ? "-$1" : "$1"));
  teile.push(erzeugerSatz(a, nowMs));
  const mix = mischung(a.strom);
  if (mix.text) teile.push(`Strom aus ${mix.text}`);
  return teile.join(" · ");
}

/** Was in der Ofenkachel unter dem Namen steht. */
export function ofenStatus(o: Anlage["ofen"]): string {
  if (!o.present) return "nicht angebunden";
  if (o.running == null) return "keine Verbindung";
  if (!o.running) return "aus";
  const stufe = o.power_level != null ? `Stufe ${Math.round(o.power_level)}` : "brennt";
  return o.pump_pct != null ? `${stufe} · Pumpe ${Math.round(o.pump_pct)} %` : stufe;
}

/** Was in der Warmwasserkachel unter dem Namen steht. */
export function warmwasserStatus(w: Anlage["warmwasser"], nowMs: number): string {
  if (!w.present) return "kein Fühler am Auslass";
  if (w.tapping) {
    const seit = dauerText(w.tapping_since, nowMs);
    return seit ? `Zapfung seit ${seit} · Auslass` : "Zapfung · Auslass";
  }
  return "ruht · Auslass kühlt ab";
}

export function heizungStatus(h: Anlage["heizkreis"]): string {
  if (h.rooms_total === 0) return "keine Räume gemeldet";
  return h.rooms_open > 0 ? "Räume nehmen Wärme" : "kein Raum nimmt Wärme";
}

/** Wohin ein Symbol führt. Dieselben Ziele wie die Knoten der Startseite (`FlowHero`): wer dort
 *  auf die Sonne tippt, landet auf der Photovoltaik, und hier auch. Die Wärme-Ziele bekommen eine
 *  Sprungmarke auf die Karte der Erzeugerseite, die das Gerät zeigt. */
export const ZIELE = {
  pv: { href: "/strom/pv", label: "Photovoltaik" },
  netz: { href: "/strom", label: "Strombilanz" },
  bat: { href: "/strom/speicher", label: "Stromspeicher" },
  haus: { href: "/strom", label: "Haushalt in der Strombilanz" },
  wp: { href: "/waerme#puffer", label: "Wärmepumpe und Puffer im Verlauf" },
  ofen: { href: "/waerme#ofen", label: "Pelletofen im Verlauf" },
  puffer: { href: "/waerme#puffer", label: "Pufferspeicher im Verlauf" },
  heizung: { href: "/haus?ansicht=liste", label: "Räume" },
  warmwasser: { href: "/waerme", label: "Wärmeübersicht mit Warmwasser" },
} as const;
export type Ziel = keyof typeof ZIELE;
