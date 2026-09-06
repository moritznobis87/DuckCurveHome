import { describe, expect, it } from "vitest";
import { dayBounds, priceBounds } from "./DayChart";

describe("dayBounds", () => {
  it("liefert Berliner Mitternacht in UTC (Sommerzeit)", () => {
    const [s, e] = dayBounds(Date.UTC(2026, 8, 4, 20, 1)); // 22:01 Berlin
    expect(new Date(s).toISOString()).toBe("2026-09-03T22:00:00.000Z");
    expect(e - s).toBe(86400000);
  });
  it("liefert Berliner Mitternacht in UTC (Winterzeit)", () => {
    const [s] = dayBounds(Date.UTC(2026, 0, 15, 3, 0));
    expect(new Date(s).toISOString()).toBe("2026-01-14T23:00:00.000Z");
  });
});

describe("priceBounds", () => {
  const rows = (...v: number[]): Array<Array<number | null>> => v.map((x, i) => [i, x]);

  it("spannt zwischen Minimum und Maximum statt bei null zu beginnen", () => {
    const b = priceBounds(rows(18.4, 22.1, 45.2, 41.0));
    expect(b.min).toBeLessThanOrEqual(18.4);
    expect(b.max).toBeGreaterThanOrEqual(45.2);
    expect(b.min).toBeGreaterThan(0); // der leere Bereich unter 18 ct fällt weg
    expect((b.max - b.min) / b.step).toBeLessThanOrEqual(5);
  });

  it("lässt Luft, damit die Kurve die Ränder nicht berührt", () => {
    const b = priceBounds(rows(30, 31));
    expect(b.min).toBeLessThan(30);
    expect(b.max).toBeGreaterThan(31);
  });

  it("bleibt auch bei weiter Spanne über null", () => {
    const b = priceBounds(rows(18, 20, 33, 45, 47));
    expect(b.min).toBeGreaterThan(0);
    expect(b.max).toBeGreaterThanOrEqual(47);
  });

  it("erfasst negative Preise", () => {
    const b = priceBounds(rows(-4.5, 12, 20));
    expect(b.min).toBeLessThanOrEqual(-4.5);
    expect(b.max).toBeGreaterThanOrEqual(20);
  });

  it("liefert auch ohne Daten eine brauchbare Achse", () => {
    expect(priceBounds([])).toEqual({ min: 0, max: 45, step: 15 });
    expect(priceBounds([[0, null]])).toEqual({ min: 0, max: 45, step: 15 });
  });

  it("rundet auf glatte Schritte", () => {
    const b = priceBounds(rows(19.7, 44.3));
    expect(Number.isInteger(b.max / b.step)).toBe(true);
    expect(Number.isInteger(b.min / b.step)).toBe(true);
  });
});
