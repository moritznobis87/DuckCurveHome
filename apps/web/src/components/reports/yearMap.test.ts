import { describe, expect, it } from "vitest";
import { yearMap, RAMP_NET, RAMP_OWN } from "./charts";

const days = ["2026-01-01", "2026-01-02", "2026-02-01"];

function grid(fill: (d: number, h: number) => number | null): Array<Array<number | null>> {
  return days.map((_, d) => Array.from({ length: 24 }, (_, h) => fill(d, h)));
}

/** Die Option ist ein verschachteltes Objekt; für die Prüfung reicht ein loser Zugriff. */
type Opt = { series: Array<{ data: Array<[number, number, number]> }>; visualMap: { min: number; max: number } };

describe("yearMap", () => {
  it("lässt fehlende Stunden weg statt sie als Null zu färben", () => {
    const o = yearMap(days, grid((d, h) => (d === 0 && h < 12 ? 1 : null)), { unit: "kWh", ramp: RAMP_OWN }) as unknown as Opt;
    expect(o.series[0]!.data).toHaveLength(12);
    expect(o.series[0]!.data.every(([, , v]) => v === 1)).toBe(true);
  });

  it("kappt die Skala am 98. Perzentil, damit ein Ausreißer nicht das Jahr einfärbt", () => {
    // 71 Stunden mit 1 kWh, eine mit 100 kWh
    const o = yearMap(days, grid((d, h) => (d === 0 && h === 0 ? 100 : 1)), { unit: "kWh", ramp: RAMP_OWN }) as unknown as Opt;
    expect(o.visualMap.max).toBe(1);
  });

  it("macht die divergierende Skala symmetrisch um null", () => {
    const o = yearMap(days, grid((d) => (d === 0 ? -3 : 1)), { unit: "kWh", ramp: RAMP_NET, diverging: true }) as unknown as Opt;
    expect(o.visualMap.min).toBe(-o.visualMap.max);
    expect(o.visualMap.max).toBeGreaterThan(0);
  });

  it("kommt mit einem leeren Jahr zurecht", () => {
    const o = yearMap(days, grid(() => null), { unit: "kWh", ramp: RAMP_OWN }) as unknown as Opt;
    expect(o.series[0]!.data).toHaveLength(0);
    expect(Number.isFinite(o.visualMap.max)).toBe(true);
  });
});
