/**
 * Die Technikseite der Wärmepumpe: was die Zeichnung an Rechnung und Maßen braucht.
 *
 * **Zwei Lagen, eine Zeichnung.** Auf der Wandanzeige stehen Außengerät, Innengerät und Speicher
 * nebeneinander, am Telefon untereinander. Die drei Blöcke sind dieselben; hier steht nur, wo
 * sie liegen und wie die Leitungen zwischen ihnen laufen. Jede Leitung endet an einer Stelle,
 * die es am Gerät gibt: Heißgas und Flüssigkeitsleitung zwischen Außen- und Innengerät,
 * Vorlauf und Rücklauf zwischen Innengerät und Speicher, der Vorlauf oben in den Speicher,
 * der Rücklauf unten heraus.
 */
import type { Measurement, Waermepumpe } from "@/lib/api/models";

export type Lage = "breit" | "hoch";
export type Punkt = [number, number];

export const BLOCK = {
  aussen: { w: 330, h: 250 },
  innen: { w: 300, h: 250 },
  speicher: { w: 250, h: 250 },
} as const;

/** Das Glas im Block „Speicher" (`puffer/Glas`): links daneben stehen die vier Temperaturen. */
export const TANK = { x: 133, y: 40, w: 64, h: 190 } as const;
/** Die Mitte des Glases im Block: dort kommt der Vorlauf an. */
const MITTE = TANK.x + TANK.w / 2;

type Plan = {
  viewBox: string;
  aussen: Punkt;
  innen: Punkt;
  speicher: Punkt;
  /** Leitungen als Punktfolgen in Flussrichtung. */
  heissgas: Punkt[];
  fluessig: Punkt[];
  vorlauf: Punkt[];
  /** Der Vorlauf im Heizbetrieb: die Maschine speist dann nicht oben, sondern tiefer in den
   *  Speicher ein (Auskunft des Hausherrn, 14.11.2026). Er endet seitlich auf halber Höhe. */
  vorlaufTiefer: Punkt[];
  ruecklauf: Punkt[];
  /** Linke obere Ecke der Schilder an den Leitungen. */
  schild: { heissgas: Punkt; fluessig: Punkt; vorlauf: Punkt; ruecklauf: Punkt };
};

export const SCHILD = { w: 124, h: 38 } as const;

export const PLAN: Record<Lage, Plan> = {
  breit: {
    viewBox: "0 0 1120 450",
    aussen: [10, 100],
    innen: [410, 100],
    speicher: [850, 100],
    heissgas: [[260, 100], [260, 50], [450, 50], [450, 100]],
    fluessig: [[450, 350], [450, 400], [260, 400], [260, 350]],
    vorlauf: [[660, 100], [660, 50], [1015, 50], [1015, 100 + TANK.y]],
    vorlaufTiefer: [[660, 100], [660, 50], [1100, 50], [1100, 100 + TANK.y + TANK.h / 2], [850 + TANK.x + TANK.w, 100 + TANK.y + TANK.h / 2]],
    ruecklauf: [[1015, 100 + TANK.y + TANK.h], [1015, 400], [660, 400], [660, 350]],
    schild: { heissgas: [293, 31], fluessig: [293, 381], vorlauf: [776, 31], ruecklauf: [776, 381] },
  },
  hoch: {
    viewBox: "0 0 380 1000",
    aussen: [25, 10],
    innen: [40, 370],
    speicher: [20, 740],
    heissgas: [[150, 260], [150, 370]],
    fluessig: [[300, 370], [300, 260]],
    // Der Vorlauf verlässt das Innengerät links und kommt mittig auf dem Glas an: ein Versatz
    // unter den beiden Schildern.
    vorlauf: [[150, 620], [150, 712], [20 + MITTE, 712], [20 + MITTE, 740 + TANK.y]],
    vorlaufTiefer: [[150, 620], [150, 712], [272, 712], [272, 740 + TANK.y + TANK.h / 2], [20 + TANK.x + TANK.w, 740 + TANK.y + TANK.h / 2]],
    ruecklauf: [[20 + TANK.x + TANK.w, 740 + TANK.y + TANK.h - 24], [300, 740 + TANK.y + TANK.h - 24], [300, 620]],
    schild: { heissgas: [14, 296], fluessig: [164, 296], vorlauf: [14, 660], ruecklauf: [164, 660] },
  },
};

export const pfad = (punkte: Punkt[]): string => punkte.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x} ${y}`).join(" ");

/** Ist der Wert da und nicht veraltet? */
export function brauchbar(m: Measurement | null | undefined): boolean {
  return !!m && m.value !== null && (m.quality === "ok" || m.quality === "derived");
}

/** Eine Zahl deutsch geschrieben, oder ein Fragezeichen: ein fehlender Wert ist keine Null. */
export function zahl(wert: number | null | undefined, stellen = 1): string {
  return wert == null || Number.isNaN(wert) ? "?" : wert.toFixed(stellen).replace(".", ",");
}

export const messwert = (m: Measurement | null | undefined, stellen = 1): string => zahl(m?.value, stellen);

/** Die Leistungsaufnahme, die gilt: der Zähler, wo er einen Wert hat, sonst die Auskunft der Maschine. */
export function aufnahme(d: Pick<Waermepumpe, "leistung_zaehler_kw" | "leistung_bus_kw">): { kw: number | null; quelle: "Zähler" | "laut Maschine" | "" } {
  if (brauchbar(d.leistung_zaehler_kw)) return { kw: d.leistung_zaehler_kw.value ?? null, quelle: "Zähler" };
  if (brauchbar(d.leistung_bus_kw)) return { kw: d.leistung_bus_kw.value ?? null, quelle: "laut Maschine" };
  return { kw: null, quelle: "" };
}

/** Der Satz über der Zeichnung: was die Maschine gerade tut, in einem Atemzug. */
export function satz(d: Waermepumpe): string {
  const strom = aufnahme(d).kw;
  if (!d.laeuft) return `Die Wärmepumpe ${d.zustand_de}.`;
  if (d.waermeleistung_kw != null && strom != null) {
    return `Die Wärmepumpe ${d.zustand_de}: rund ${zahl(d.waermeleistung_kw)} kW Wärme aus ${zahl(strom)} kW Strom.`;
  }
  if (strom != null) return `Die Wärmepumpe ${d.zustand_de} und nimmt ${zahl(strom)} kW auf.`;
  return `Die Wärmepumpe ${d.zustand_de}.`;
}
