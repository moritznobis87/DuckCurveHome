import { describe, expect, it } from "vitest";
import { appendLiveSample, rowToPoint, type HistoryPoint } from "./store";
import type { LiveState } from "@/lib/api/models";

function fakeState(ts: string, pv: number): LiveState {
  const m = (value: number) => ({ value, observed_at: ts, quality: "ok" as const, source: "t" });
  return {
    snapshot: {
      timestamp: ts, pv_power_kw: m(pv), grid_power_kw: m(-1), battery_power_kw: m(0), battery_soc: m(1),
      house_power_kw: m(1), base_load_kw: m(1), heat_pump_power_kw: m(0), ev_power_kw: m(0),
      electricity_price_ct_kwh: m(20), outdoor_temp_c: m(15),
      buffer_temps_c: { top: m(50), mid_top: m(48), mid_bottom: m(44), bottom: m(38) },
      hp_release_contact: m(0), hp_block_contact: m(0), actuators: {}, balance_residual_kw: 0,
    },
  } as unknown as LiveState;
}

describe("history bins", () => {
  it("mittelt Samples innerhalb einer Minute und legt neue Minuten an", () => {
    const counts = new Map<number, number>();
    let pts: HistoryPoint[] = [];
    pts = appendLiveSample(pts, fakeState("2026-09-04T10:00:05Z", 4), counts);
    pts = appendLiveSample(pts, fakeState("2026-09-04T10:00:35Z", 6), counts);
    expect(pts).toHaveLength(1);
    expect(pts[0]?.pv).toBe(5);
    pts = appendLiveSample(pts, fakeState("2026-09-04T10:01:05Z", 8), counts);
    expect(pts).toHaveLength(2);
    expect(pts[1]?.pv).toBe(8);
  });
  it("wandelt API-Zeilen um", () => {
    const p = rowToPoint({ ts: "2026-09-04T10:00:00Z", pv_power_kw: 3.2, heat_pump_power_kw: null });
    expect(p.pv).toBe(3.2);
    expect(p.hp).toBeNull();
  });
});
