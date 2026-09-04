import { describe, expect, it } from "vitest";
import { celsius, ct, hhmm, kw, kwWithUnit, percent } from "./index";

describe("format", () => {
  it("formatiert kW mit Komma und Minuszeichen", () => {
    expect(kw(6.84)).toBe("6,8");
    expect(kw(-2.4)).toBe("−2,4");
    expect(kw(0.02)).toBe("0,0");
    expect(kw(null)).toBe("–");
    expect(kwWithUnit(3.6)).toBe("3,6 kW");
  });
  it("formatiert Prozent, Temperatur und Preis", () => {
    expect(percent(0.62)).toBe("62 %");
    expect(celsius(59.6)).toBe("60 °C");
    expect(ct(-1.25)).toBe("−1,3 ct/kWh");
  });
  it("zeigt Uhrzeit in Europe/Berlin", () => {
    expect(hhmm("2026-09-04T11:42:00Z")).toBe("13:42");
  });
});
