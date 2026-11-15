import { describe, expect, it } from "vitest";
import type { ReglerEinstellung } from "@/lib/api/models";
import { gelesen, gruppen, standText, wertText } from "./regler";

const wert = (teil: Partial<ReglerEinstellung> & { v?: number | null; quality?: string } = {}): ReglerEinstellung => {
  const { v = 1.2, quality = "ok", ...rest } = teil;
  return { schluessel: "heat_pump_set_slope", name_de: "Steilheit", gruppe_de: "Heizkurve", kennung: "6a71", einheit: "", stellen: 2, lesart_de: null, wert: { value: v, observed_at: "2026-11-15T09:30:00Z", quality, source: "mqtt:ebusd" } as ReglerEinstellung["wert"], ...rest };
};

describe("die Einstellungen des Reglers", () => {
  it("ordnet nach Gruppen, in der Reihenfolge des Dienstes", () => {
    const g = gruppen([wert(), wert({ gruppe_de: "Warmwasser", name_de: "Komforttemperatur" }), wert({ name_de: "Verschiebung" })]);
    expect(g.map((x) => [x.name, x.werte.length])).toEqual([["Heizkurve", 2], ["Warmwasser", 1]]);
  });

  it("schreibt den Wert, wie er am Bediengerät steht", () => {
    expect(wertText(wert())).toBe("1,20");
    expect(wertText(wert({ v: 55, einheit: "°C", stellen: 1 }))).toBe("55,0 °C");
    expect(wertText(wert({ v: -2, einheit: "K", stellen: 1 }))).toBe("−2,0 K");
    expect(wertText(wert({ v: 1.5, einheit: "K", stellen: 1 }))).toBe("+1,5 K");
    expect(wertText(wert({ v: 2, stellen: 0 }))).toBe("2");
  });

  it("zeigt null als Einstellung und Fehlendes als Fragezeichen", () => {
    expect(wertText(wert({ v: 0, einheit: "K", stellen: 1 }))).toBe("0,0 K");
    expect(wertText(wert({ v: null, quality: "unavailable" }))).toBe("?");
    expect(wertText(wert({ quality: "stale" }))).toBe("?");
    expect(gelesen(wert({ quality: "stale" }))).toBe(false);
    expect(standText(wert({ quality: "stale" }))).toBe("nicht gelesen");
    expect(standText(wert())).toBe("10:30");
  });
});
