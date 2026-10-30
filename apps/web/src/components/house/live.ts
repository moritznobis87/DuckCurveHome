/**
 * Was das Modell aus dem Augenblick braucht, in einer Form, die die Szene direkt setzen kann.
 *
 * Drei Quellen, ein Bild: die Raumwerte (`/rooms`, ueber `room_id`), der Hausplan mit seinen
 * Kontakten (`/haus`, ueber `key`) und der Live-Zustand (Alarm, Puffer, Waermepumpe, Wallbox,
 * Ofen). Hier wird nichts geholt, nur zusammengelegt.
 */
import type { House, HouseContact, LiveState, RoomLive } from "@/lib/api/models";

export type AlarmStufe = "unscharf" | "zuhause" | "unterwegs" | "schaltet" | "ausgeloest" | "unbekannt";

export interface HausLive {
  /** Raumwerte nach Kennung der Einzelraumregelung. */
  raeume: Map<number, RoomLive>;
  /** Kontakte nach Schluessel. */
  kontakte: Map<string, HouseContact>;
  alarm: AlarmStufe;
  alarmSatz: string;
  /** Puffer: Ladestand 0..1 und die vier Fuehler von oben nach unten. */
  pufferSoc: number | null;
  pufferTemps: (number | null)[];
  /** Leistungen in kW. */
  waermepumpeKw: number | null;
  wallboxKw: number | null;
  /** Der Pelletofen brennt. `null`, wenn es keinen gibt oder er nichts sagt. */
  ofenLaeuft: boolean | null;
  /** Wie viele Heizkreise offen stehen, als Anteil der Raeume mit offenen Kreisen. */
  kreiseOffen: number;
}

export function alarmStufe(state: number | null | undefined): AlarmStufe {
  if (state == null) return "unbekannt";
  if (state >= 4) return "ausgeloest";
  if (state >= 3) return "schaltet";
  if (state >= 2) return "unterwegs";
  if (state >= 1) return "zuhause";
  return "unscharf";
}

export const ALARM_WORT: Record<AlarmStufe, string> = {
  unscharf: "UNSCHARF",
  zuhause: "ZU HAUSE",
  unterwegs: "UNTERWEGS",
  schaltet: "SCHALTET",
  ausgeloest: "AUSGELÖST",
  unbekannt: "KEINE MELDUNG",
};

export function hausLive(rooms: RoomLive[] | null, house: House | null, state: LiveState | null): HausLive {
  const raeume = new Map<number, RoomLive>();
  for (const r of rooms ?? []) raeume.set(r.id, r);
  const kontakte = new Map<string, HouseContact>();
  for (const k of house?.contacts ?? []) kontakte.set(k.key, k);
  const s = state?.snapshot;
  const temps = s ? [s.buffer_temps_c.top, s.buffer_temps_c.mid_top, s.buffer_temps_c.mid_bottom, s.buffer_temps_c.bottom] : [];
  const alarm = state?.alarm.present ? alarmStufe(state.alarm.state) : "unbekannt";
  return {
    raeume,
    kontakte,
    alarm,
    alarmSatz: state?.alarm.present ? state.alarm.state_de : "nicht eingerichtet",
    pufferSoc: state?.buffer.soc ?? null,
    pufferTemps: temps.map((m) => m.value ?? null),
    waermepumpeKw: s?.heat_pump_power_kw.value ?? null,
    wallboxKw: s?.ev_power_kw.value ?? null,
    ofenLaeuft: state?.stove.present ? (state.stove.running ?? null) : null,
    kreiseOffen: (rooms ?? []).filter((r) => (r.valve ?? 0) > 0).length,
  };
}

/** Die offenen Kontakte, Tueren zuerst, fuer die Liste neben dem Modell. */
export function offeneKontakte(kontakte: Iterable<HouseContact>): HouseContact[] {
  return [...kontakte].filter((k) => k.open === true).sort((a, b) => Number(b.door) - Number(a.door) || a.name.localeCompare(b.name, "de"));
}

/** Satz unter der Zahl der offenen Kontakte. */
export function offenSatz(offen: HouseContact[], gesamt: number): string {
  if (gesamt === 0) return "keine Kontakte im Plan";
  if (offen.length === 0) return "alles zu";
  if (offen.length === 1) return offen[0]!.name;
  return `${offen[0]!.name} und ${offen.length - 1} weitere`;
}
