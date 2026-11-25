import type { EnergySnapshot, Measurement } from "@/lib/api/models";
import { kw } from "@/lib/format";
import { FLUSS_AB_KW } from "./buehne";

/** Ein Messwert zählt, wenn er da ist und gemessen oder aus Gemessenem gerechnet. */
export function frisch(m: Measurement | null | undefined): boolean {
  return !!m && m.value !== null && (m.quality === "ok" || m.quality === "derived");
}

/**
 * Was vom Hausverbrauch bleibt, wenn Wärmepumpe und Wallbox abgezogen sind.
 *
 * Nur wenn die beiden überhaupt etwas nehmen: Steht alles still, ist die Grundlast der
 * Hausverbrauch, und die Zeile würde dieselbe Zahl ein zweites Mal sagen.
 */
export function grundlast(rest: number | null, andere: number): string | undefined {
  if (rest === null || andere < FLUSS_AB_KW) return undefined;
  return `davon ${kw(rest)} kW Grundlast`;
}

/**
 * Was unter der Wärmepumpe steht: „läuft“ nur, wenn sie nach der einen Festlegung des Hauses
 * läuft (`running_threshold_kw`, vom Dienst entschieden).
 *
 * Bis zum 10.11.2026 stand hier „läuft“, sobald 0,05 kW flossen. Die Maschine zieht im Stillstand
 * rund 0,1 kW für Steuerung und Pumpe, und so stand unter dem Satz „Wärmepumpe aus“ ein Knoten,
 * der „läuft“ sagte (gesehen im Haus am 10.11.2026). Was sie im Stillstand zieht, heißt
 * Bereitschaft.
 */
export function wpWort(kwJetzt: number, laeuft: boolean | undefined): string {
  if (laeuft) return "läuft";
  return kwJetzt >= FLUSS_AB_KW ? "Bereitschaft" : "steht";
}

export type Speicherwort = "lädt" | "entlädt" | "hält";

/** Der Energiefluss eines Augenblicks, so wie Bühne und Uhr ihn zeichnen. */
export interface Flusswerte {
  pv: number;
  haus: number;
  /** Was über den Netzanschluss geht, ohne Vorzeichen; `einspeisung` sagt die Richtung. */
  netz: number;
  einspeisung: boolean;
  /** Was in den Speicher geht oder aus ihm kommt, ohne Vorzeichen. */
  speicher: number;
  speicherWort: Speicherwort;
  /** Ladestand von 0 bis 1. */
  soc: number | null;
  hp: number;
  ev: number;
  /** Die Grundlast; `null`, wenn sie nicht gemessen ist. */
  rest: number | null;
}

/** Ein Messwert, der nicht zählt, fließt nicht: er steht mit 0 da und ist in der Anzeige grau. */
export function flusswerte(s: EnergySnapshot | null): Flusswerte {
  const num = (m?: Measurement | null) => (frisch(m) ? (m!.value as number) : 0);
  const grid = num(s?.grid_power_kw);
  const bat = num(s?.battery_power_kw);
  const lade = Math.max(0, -bat);
  const gibt = Math.max(0, bat);
  return {
    pv: num(s?.pv_power_kw),
    haus: num(s?.house_power_kw),
    netz: Math.abs(grid),
    einspeisung: grid < 0,
    speicher: Math.max(lade, gibt),
    speicherWort: lade >= FLUSS_AB_KW ? "lädt" : gibt >= FLUSS_AB_KW ? "entlädt" : "hält",
    soc: s?.battery_soc.value ?? null,
    hp: num(s?.heat_pump_power_kw),
    ev: num(s?.ev_power_kw),
    rest: frisch(s?.base_load_kw) ? (s!.base_load_kw.value as number) : null,
  };
}
