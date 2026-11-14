import { describe, expect, it } from "vitest";
import type { KennlinienBilanz } from "@/lib/api/models";
import { dauer, fehlend, halbeFenster, teile } from "./bilanz";

const bilanz = (teil: Partial<KennlinienBilanz> = {}): KennlinienBilanz => ({ minuten: 1440, heizen: 240, anlauf: 40, zusatz: 20, ohne_wert: 60, ohne_waerme: 0, gueltig: 120, fenster: 15, punkte: 11, unglaubwuerdig: 1, fehlt: { Vorlauf: 10, Rücklauf: 55 }, verhaeltnis: 1.04, satz_de: "", ...teil });

describe("die Bilanz der Kennlinie", () => {
  it("teilt die Heizminuten in feste Reihenfolge auf und lässt leere Teile weg", () => {
    const t = teile(bilanz());
    expect(t.map((x) => x.art)).toEqual(["gueltig", "anlauf", "zusatz", "ohne_wert"]);
    expect(t.map((x) => x.minuten)).toEqual([120, 40, 20, 60]);
    expect(t.reduce((s, x) => s + x.anteil, 0)).toBeCloseTo(1, 9);
    expect(t[0]?.anteil).toBeCloseTo(0.5, 9);
  });

  it("zeigt nichts, wenn die Maschine nicht heizte", () => {
    expect(teile(bilanz({ heizen: 0, anlauf: 0, zusatz: 0, ohne_wert: 0, gueltig: 0 }))).toEqual([]);
  });

  it("zeigt den Fall aus dem Haus: Stunden Lauf, kein brauchbarer Wert, und woran es lag", () => {
    const b = bilanz({ heizen: 300, anlauf: 30, zusatz: 0, ohne_wert: 270, gueltig: 0, fenster: 0, punkte: 0, unglaubwuerdig: 0, fehlt: { Rücklauf: 270 } });
    expect(teile(b).map((x) => [x.name, x.minuten])).toEqual([["Anlauf", 30], ["Wert fehlte", 270]]);
    expect(fehlend(b)).toEqual([{ name: "Rücklauf", minuten: 270 }]);
  });

  it("nennt den häufigsten fehlenden Wert zuerst", () => {
    expect(fehlend(bilanz()).map((f) => f.name)).toEqual(["Rücklauf", "Vorlauf"]);
    expect(fehlend(bilanz({ fehlt: {} }))).toEqual([]);
  });

  it("sagt Dauern, wie man sie sagt", () => {
    expect(dauer(45)).toBe("45 min");
    expect(dauer(60)).toBe("1 h");
    expect(dauer(200)).toBe("3 h 20 min");
    expect(dauer(0)).toBe("0 min");
  });

  it("zählt die Fenster, die nicht voll genug wurden", () => {
    expect(halbeFenster(bilanz())).toBe(3);
    expect(halbeFenster(bilanz({ fenster: 2, punkte: 2, unglaubwuerdig: 0 }))).toBe(0);
  });
});
