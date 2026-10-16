import { create } from "zustand";
import type { Decision, LiveState, Plan } from "@/lib/api/models";

export type Connection = "connecting" | "live" | "reconnecting" | "offline";

export interface HistoryPoint {
  ts: number; // ms UTC, Minutenanfang
  pv: number | null;
  hp: number | null;
  ev: number | null;
  grid: number | null;
  battery: number | null;
  price: number | null;
  k1: number | null;
}

interface LiveStore {
  state: LiveState | null;
  plan: Plan | null;
  decisions: Decision[];
  connection: Connection;
  lastFrameAt: number | null;
  serverOffsetMs: number; // serverTime - clientTime
  history: HistoryPoint[];
  // Der angezeigte Kalendertag als ISO-Datum. Vorher waren es drei feste Stufen; die Ansicht
  // soll aber jedem Tag folgen können, auf den man blättert.
  historyDay: string;
  setState: (s: LiveState) => void;
  setPlan: (p: Plan) => void;
  pushDecision: (d: Decision) => void;
  setConnection: (c: Connection) => void;
  setHistory: (rows: HistoryPoint[], day: string) => void;
  nowMs: () => number;
}

export function rowToPoint(row: Record<string, number | string | null>): HistoryPoint {
  const num = (k: string): number | null => {
    const v = row[k];
    return typeof v === "number" ? v : null;
  };
  return {
    ts: new Date(String(row.ts)).getTime(),
    pv: num("pv_power_kw"),
    hp: num("heat_pump_power_kw"),
    ev: num("ev_power_kw"),
    grid: num("grid_power_kw"),
    battery: num("battery_power_kw"),
    price: num("electricity_price_ct_kwh"),
    k1: num("hp_release_contact"),
  };
}

/** Schreibt einen Live-Snapshot in das Minutenraster fort (Mittelwert je Minute). */
export function appendLiveSample(points: HistoryPoint[], s: LiveState, counts: Map<number, number>): HistoryPoint[] {
  const ts = new Date(s.snapshot.timestamp).getTime();
  const minute = ts - (ts % 60000);
  const sample: HistoryPoint = {
    ts: minute,
    pv: s.snapshot.pv_power_kw.value ?? null,
    hp: s.snapshot.heat_pump_power_kw.value ?? null,
    ev: s.snapshot.ev_power_kw.value ?? null,
    grid: s.snapshot.grid_power_kw.value ?? null,
    battery: s.snapshot.battery_power_kw.value ?? null,
    price: s.snapshot.electricity_price_ct_kwh.value ?? null,
    k1: s.snapshot.hp_release_contact.value ?? null,
  };
  const last = points[points.length - 1];
  if (last && last.ts === minute) {
    const n = counts.get(minute) ?? 1;
    const avg = (a: number | null, b: number | null): number | null =>
      a === null ? b : b === null ? a : (a * n + b) / (n + 1);
    counts.set(minute, n + 1);
    const merged: HistoryPoint = {
      ts: minute,
      pv: avg(last.pv, sample.pv),
      hp: avg(last.hp, sample.hp),
      ev: avg(last.ev, sample.ev),
      grid: avg(last.grid, sample.grid),
      battery: avg(last.battery, sample.battery),
      price: sample.price,
      k1: sample.k1,
    };
    return [...points.slice(0, -1), merged];
  }
  if (last && minute < last.ts) return points; // verspäteter Frame
  counts.set(minute, 1);
  const next = [...points, sample];
  return next.length > 1500 ? next.slice(next.length - 1500) : next;
}

const liveCounts = new Map<number, number>();

export const useLiveStore = create<LiveStore>((set, get) => ({
  state: null,
  plan: null,
  decisions: [],
  connection: "connecting",
  lastFrameAt: null,
  serverOffsetMs: 0,
  history: [],
  historyDay: "",
  setState: (s) =>
    set((prev) => {
      const clientNow = Date.now();
      const serverNow = new Date(s.system.server_time).getTime();
      // Eine unlesbare Serverzeit darf den Zeitversatz nicht vergiften. Aus NaN wird sonst überall
      // „Invalid Date": in der Überschrift des Tagesdiagramms, im geladenen Tag, in den Verweisen
      // der Navigation - und es bleibt so, denn der nächste gute Rahmen macht den einmal
      // weggeschriebenen Tag nicht wieder gut.
      const serverOffsetMs = Number.isFinite(serverNow) ? serverNow - clientNow : prev.serverOffsetMs;
      // Live-Werte nur an den laufenden Tag anhängen. Ein vergangener Tag ist abgeschlossen;
      // ein frischer Messwert gehört dort nicht hinein. Maßgeblich ist der Tag des Servers: im
      // Demo-Betrieb läuft dessen Uhr im Zeitraffer, und die des Geräts zeigt dann etwas anderes.
      const today = new Date(clientNow + serverOffsetMs).toLocaleDateString("sv-SE");
      const history = prev.historyDay === today ? appendLiveSample(prev.history, s, liveCounts) : prev.history;
      return { state: s, lastFrameAt: clientNow, serverOffsetMs, connection: "live", history };
    }),
  setPlan: (p) => set({ plan: p }),
  pushDecision: (d) =>
    set((prev) => {
      if (prev.decisions[0]?.id === d.id) return {};
      return { decisions: [d, ...prev.decisions].slice(0, 50) };
    }),
  setConnection: (c) => set({ connection: c }),
  setHistory: (rows, day) => {
    liveCounts.clear();
    set({ history: rows, historyDay: day });
  },
  nowMs: () => Date.now() + get().serverOffsetMs,
}));
