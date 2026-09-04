import { describe, expect, it } from "vitest";
import { dayBounds } from "./DayChart";

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
