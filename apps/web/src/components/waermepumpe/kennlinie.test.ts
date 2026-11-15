import { describe, expect, it } from "vitest";
import type { Kennlinie, KennlinienFit, KennlinienPunkt } from "@/lib/api/models";
import { belegung, copAchse, copNach, gesamt, mitte, optionAussen, optionFeld, optionVorlauf, raster, vergleich, vergleichsVorlauf, vorlaufStufen } from "./kennlinie";

const punkt = (aussen: number, vorlauf: number, cop: number, strom = 2): KennlinienPunkt => ({ at: "2026-11-14T09:10:00Z", minuten: 10, aussen_c: aussen, vorlauf_c: vorlauf, cop, waerme_kw: cop * strom, strom_kw: strom });

const fit = (teil: Partial<KennlinienFit> = {}): KennlinienFit => ({ art: "ebene", a: 6, b_aussen: 0.1, c_vorlauf: -0.06, n: 12, rmse: 0.2, r2: 0.9, aussen_von_c: -5, aussen_bis_c: 10, vorlauf_von_c: 32, vorlauf_bis_c: 48, formel_de: "", geltung_de: "", ...teil });

const antwort = (teil: Partial<Kennlinie> = {}): Kennlinie => ({
  now: "2026-11-14T10:00:00Z",
  von: "2026-10-15T10:00:00Z",
  bis: "2026-11-14T10:00:00Z",
  tage: 30,
  punkte: [punkt(-5, 32, 3.58), punkt(0, 40, 3.6), punkt(10, 48, 4.12)],
  fit: fit(),
  fehlt_de: null,
  annahme_vorlauf_c: 45,
  annahme: [{ aussen_c: -7, cop: 2.4 }, { aussen_c: 2, cop: 3.0 }, { aussen_c: 7, cop: 3.5 }, { aussen_c: 15, cop: 4.2 }],
  hinweise_de: [],
  ...teil,
});

describe("die gemessene Kennlinie", () => {
  it("rechnet die Arbeitszahl nach der Ausgleichsfläche und die aller Punkte aus den Summen", () => {
    expect(copNach(fit(), 7, 35)).toBeCloseTo(4.6, 5);
    // Ein Fenster mit 4 kW Strom zählt doppelt so viel wie eines mit 2 kW: (3*2 + 5*4) / 6.
    expect(gesamt([punkt(5, 35, 3, 2), punkt(5, 35, 5, 4)])).toBeCloseTo(26 / 6, 5);
    expect(gesamt([])).toBeNull();
    expect(mitte([3, 1, 2])).toBe(2);
    expect(mitte([4, 1, 2, 3])).toBe(2.5);
    expect(mitte([])).toBeNull();
  });

  it("zeichnet Geraden nur für Vorläufe, die gemessen wurden, und höchstens drei", () => {
    expect(vorlaufStufen(fit())).toEqual([35, 40, 45]);
    expect(vorlaufStufen(fit({ vorlauf_von_c: 31, vorlauf_bis_c: 58 }))).toEqual([35, 45, 55]);
    expect(vorlaufStufen(fit({ vorlauf_von_c: 36, vorlauf_bis_c: 39 }))).toEqual([]);
    // Kennt der Ausgleich den Vorlauf nicht, gibt es keine Schar.
    expect(vorlaufStufen(fit({ art: "aussen", c_vorlauf: 0 }))).toEqual([]);
  });

  it("stellt die Messung neben die Annahme des Fahrplans und sagt, wo sie nur verlängert ist", () => {
    const v = vergleich(antwort());
    expect(v.map((x) => x.aussen_c)).toEqual([-7, 2, 7, 15]);
    // 6 + 0,1 * 2 - 0,06 * 45 = 3,5 gegen die Annahme 3,0.
    expect(v[1]).toMatchObject({ annahme: 3.0, gemessen: true });
    expect(v[1]!.messung).toBeCloseTo(3.5, 5);
    // -7 und 15 Grad lagen außerhalb der Messung (-5 bis 10).
    expect(v.map((x) => x.gemessen)).toEqual([false, true, true, false]);
    // Liegt der Vorlauf der Annahme außerhalb der Messung, ist jede Zeile eine Verlängerung.
    expect(vergleich(antwort({ annahme_vorlauf_c: 55 })).every((x) => !x.gemessen)).toBe(true);
    // Ohne Term für den Vorlauf gilt der Vergleich beim mittleren Vorlauf der Messung.
    expect(vergleichsVorlauf(antwort({ fit: fit({ art: "aussen", c_vorlauf: 0 }) }))).toBe(40);
    expect(vergleich(antwort({ fit: null }))).toEqual([]);
  });

  it("baut das Kennfeld als Raster und zählt, wo gemessen wurde", () => {
    const r = raster(fit());
    expect(r.aussen[0]).toBe(-5);
    expect(r.aussen[r.aussen.length - 1]).toBe(10);
    expect(r.vorlauf).toEqual([32, 34, 36, 38, 40, 42, 44, 46, 48]);
    const b = belegung([punkt(-5, 32, 3.6), punkt(-4.6, 32.9, 3.6), punkt(10, 48, 4.1), punkt(40, 48, 4)], r);
    // Zwei Punkte im selben Feld, einer in einem anderen, einer außerhalb des Rasters.
    expect(b.sort()).toEqual([[0, 0, 2], [15, 8, 1]].sort());
  });

  it("liefert für jedes Diagramm eine Reihe mit allen Messpunkten", () => {
    const d = antwort();
    const reihen = (o: unknown) => (o as { series: Array<{ name: string; type: string; data: unknown[] }> }).series;
    const aussen = reihen(optionAussen(d));
    expect(aussen.filter((s) => s.type === "scatter")[0]!.data).toHaveLength(3);
    // Drei Geraden für 35, 40 und 45 Grad Vorlauf, dazu die Annahme des Fahrplans.
    expect(aussen.filter((s) => s.type === "line").map((s) => s.name)).toEqual(["Annahme des Fahrplans", "35 °C Vorlauf", "40 °C Vorlauf", "45 °C Vorlauf"]);
    expect(reihen(optionVorlauf(d)).map((s) => s.type)).toEqual(["line", "scatter"]);
    const feld = optionFeld(d);
    expect(feld).not.toBeNull();
    expect(reihen(feld).map((s) => s.type)).toEqual(["heatmap", "scatter"]);
    // Ohne Ausgleich bleiben die Punkte; das Kennfeld gibt es erst mit beiden Einflüssen.
    expect(reihen(optionAussen(antwort({ fit: null }))).map((s) => s.type)).toEqual(["line", "scatter"]);
    expect(optionFeld(antwort({ fit: null }))).toBeNull();
    expect(optionFeld(antwort({ fit: fit({ art: "vorlauf", b_aussen: 0 }) }))).toBeNull();
    // Die Achse der Arbeitszahl fasst Punkte und Annahme, auf ganze gerundet.
    expect(copAchse(d)).toEqual([2, 5]);
    expect(copAchse(antwort({ punkte: [], annahme: [] }))).toEqual([1, 6]);
  });
});
