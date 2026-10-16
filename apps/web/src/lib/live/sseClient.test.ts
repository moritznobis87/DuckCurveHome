import { beforeEach, describe, expect, it, vi } from "vitest";
import type { History, LiveState, Plan } from "@/lib/api/models";

const liveState = vi.fn();
const history = vi.fn();
const plan = vi.fn();

vi.mock("@/lib/api/client", () => ({ api: { liveState: () => liveState(), history: () => history(), plan: () => plan() } }));

import { startLiveClient } from "./sseClient";
import { useLiveStore } from "./store";

/** Die Zeit steht fest: sonst haengt der erwartete Tag davon ab, wann der Lauf stattfindet. */
const JETZT = new Date("2026-10-17T00:10:00+02:00").getTime();
const TAG = new Date(JETZT).toLocaleDateString("sv-SE");

function zustand(serverTime: string): LiveState {
  const wert = (value: number) => ({ value, age_s: 1, stale: false, source: "test" });
  return {
    system: { server_time: serverTime, version: "test" },
    snapshot: {
      timestamp: serverTime,
      pv_power_kw: wert(1),
      heat_pump_power_kw: wert(0),
      ev_power_kw: wert(0),
      grid_power_kw: wert(0),
      battery_power_kw: wert(0),
      electricity_price_ct_kwh: wert(30),
      hp_release_contact: wert(1),
    },
  } as unknown as LiveState;
}

class StummeQuelle {
  onopen: (() => void) | null = null;
  onerror: (() => void) | null = null;
  addEventListener(): void {}
  close(): void {}
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(JETZT);
  vi.stubGlobal("EventSource", StummeQuelle);
  useLiveStore.setState({ history: [], historyDay: "", state: null, plan: null, lastFrameAt: null, serverOffsetMs: 0 });
  liveState.mockResolvedValue(zustand(new Date(JETZT).toISOString()));
  history.mockResolvedValue({ rows: [] } as unknown as History);
  plan.mockResolvedValue({ intervals: [], windows: [] } as unknown as Plan);
});

describe("Erstladung des Live-Clients", () => {
  it("legt die Historie unter dem Kalendertag ab, nicht unter dem Wort „today“", async () => {
    const stop = startLiveClient();
    await vi.waitFor(() => expect(useLiveStore.getState().lastFrameAt).not.toBeNull());
    expect(useLiveStore.getState().historyDay).toBe(TAG);
    stop();
  });

  it("zieht niemanden von einem vergangenen Tag weg", async () => {
    useLiveStore.getState().setHistory([{ ts: 1, pv: 2, hp: null, ev: null, grid: null, battery: null, price: null, k1: null }], "2026-10-12");
    const stop = startLiveClient();
    await vi.waitFor(() => expect(useLiveStore.getState().lastFrameAt).not.toBeNull());
    expect(useLiveStore.getState().historyDay).toBe("2026-10-12");
    expect(useLiveStore.getState().history).toHaveLength(1);
    stop();
  });

  it("vergiftet den Zeitversatz nicht, wenn die Serverzeit unlesbar ist", async () => {
    liveState.mockResolvedValue(zustand("gleich"));
    const stop = startLiveClient();
    await vi.waitFor(() => expect(useLiveStore.getState().lastFrameAt).not.toBeNull());
    expect(Number.isFinite(useLiveStore.getState().nowMs())).toBe(true);
    expect(useLiveStore.getState().historyDay).toBe(TAG);
    stop();
  });
});
