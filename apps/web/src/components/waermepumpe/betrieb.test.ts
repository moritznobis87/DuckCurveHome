import { describe, expect, it } from "vitest";
import type { Betrieb, BetriebTag } from "@/lib/api/models";
import { abtauAnteil, copAchse, klassenName, kurzAnteil, optionArbeitszahl, optionHeizkurve, optionLauflaengen, optionStunden, startsJeTag, stundenTeile, tagName, tagZeilen } from "./betrieb";

const tag = (teil: Partial<BetriebTag> = {}): BetriebTag => ({ tag: "2026-11-14", starts: 6, lauf_min: 300, abtau_min: 20, abtauungen: 4, zusatz_min: 10, strom_kwh: 14.2, waerme_kwh: 52.1, strom_lauf_kwh: 13.5, cop_tag: 3.86, cop_heizen: 4.3, lauf_median_min: 42, aussen_c: 4.5, waerme_min: 290, ...teil });

const antwort = (teil: Partial<Betrieb> = {}): Betrieb => ({
  now: "2026-11-14T20:00:00Z",
  von: "2026-10-31T20:00:00Z",
  bis: "2026-11-14T20:00:00Z",
  zeitraum_tage: 14,
  tage: [tag({ tag: "2026-11-12", starts: 0, lauf_min: 0, abtau_min: 0, abtauungen: 0, zusatz_min: 0, cop_tag: null, cop_heizen: null }), tag({ tag: "2026-11-13", starts: 10 }), tag()],
  laeufe: [],
  stunden: [
    { at: "2026-11-14T05:00:00Z", minuten: 60, aussen_c: 0, soll_c: 44, vorlauf_c: 41.5, ventil: 1 },
    { at: "2026-11-14T15:00:00Z", minuten: 30, aussen_c: 10, soll_c: 37, vorlauf_c: null, ventil: null },
  ],
  heizkurve: { a: 44, b: -0.7, n: 24, r2: 0.98, aussen_von_c: 0, aussen_bis_c: 10, formel_de: "Sollwert = 44,0 - 0,70 × Außentemperatur" },
  klassen: [
    { von_min: 0, bis_min: 10, laeufe: 4 },
    { von_min: 10, bis_min: 20, laeufe: 2 },
    { von_min: 20, bis_min: 40, laeufe: 3 },
    { von_min: 40, bis_min: 90, laeufe: 6 },
    { von_min: 90, bis_min: null, laeufe: 1 },
  ],
  starts: 16,
  lauf_min: 600,
  abtau_min: 40,
  abtauungen: 8,
  zusatz_min: 20,
  cop_gesamt: 3.86,
  cop_heizen: 4.3,
  lauf_median_min: 42,
  saetze_de: [],
  hinweise_de: [],
  ...teil,
});

type Reihe = { name: string; data: unknown[] };
const reihen = (o: unknown): Reihe[] => (o as { series: Reihe[] }).series;

describe("der Betrieb der Wärmepumpe über Tage", () => {
  it("nennt den Tag, wie der Dienst ihn als Ortstag liefert", () => {
    expect(tagName("2026-11-04")).toBe("4.11.");
    expect(tagName("2026-01-31")).toBe("31.1.");
  });

  it("teilt die Laufzeit eines Tages in Heizen, Abtauen und Heizstab, und die Teile ergeben sie", () => {
    const t = stundenTeile(tag());
    expect(t).toEqual({ heizen: 4.5, abtauen: 20 / 60, heizstab: 10 / 60 });
    expect((t.heizen + t.abtauen + t.heizstab) * 60).toBeCloseTo(300, 9);
    const o = optionStunden(antwort());
    expect(reihen(o).map((r) => r.name)).toEqual(["Heizen", "Abtauen", "Heizstab"]);
    expect(reihen(o)[0]?.data).toEqual([0, 4.5, 4.5]);
    expect((o as { xAxis: { data: string[] } }).xAxis.data).toEqual(["12.11.", "13.11.", "14.11."]);
  });

  it("rechnet Starts je Tag über die Tage mit Betrieb, nicht über alle", () => {
    expect(startsJeTag(antwort())).toBe(8);
    expect(startsJeTag(antwort({ tage: [], starts: 0 }))).toBeNull();
    expect(abtauAnteil(antwort())).toBeCloseTo(40 / 600, 9);
    expect(abtauAnteil(antwort({ lauf_min: 0 }))).toBeNull();
    expect(kurzAnteil(antwort())).toBe(0.25);
    expect(kurzAnteil(antwort({ klassen: [] }))).toBeNull();
  });

  it("benennt die Klassen der Lauflängen und zeigt je Klasse einen Balken", () => {
    expect(antwort().klassen.map(klassenName)).toEqual(["unter 10 min", "10 bis 20", "20 bis 40", "40 bis 90", "ab 90 min"]);
    expect(reihen(optionLauflaengen(antwort()))[0]?.data).toEqual([4, 2, 3, 6, 1]);
  });

  it("zeigt die Arbeitszahl je Tag in zwei Reihen und lässt Tage ohne Lauf leer", () => {
    const r = reihen(optionArbeitszahl(antwort()));
    expect(r.map((x) => x.name)).toEqual(["im Heizbetrieb", "über alles"]);
    expect(r[0]?.data).toEqual([null, 4.3, 4.3]);
    expect(r[1]?.data).toEqual([null, 3.86, 3.86]);
    expect(copAchse(antwort())).toEqual([2, 5]);
    expect(copAchse(antwort({ tage: [tag({ cop_tag: 1.4, cop_heizen: 5.6 })] }))).toEqual([1, 6]);
    expect(copAchse(antwort({ tage: [] }))).toEqual([2, 5]);
  });

  it("zeichnet die Heizkurve: Sollwerte, erreichten Vorlauf und die Gerade nur, wenn es sie gibt", () => {
    const mit = reihen(optionHeizkurve(antwort()));
    expect(mit.map((x) => x.name)).toEqual(["Gerade", "erreicht", "Sollwert"]);
    expect(mit[0]?.data).toEqual([[0, 44], [10, 37]]);
    expect(mit[1]?.data).toHaveLength(1);
    const ohne = reihen(optionHeizkurve(antwort({ heizkurve: null })));
    expect(ohne.map((x) => x.name)).toEqual(["erreicht", "Sollwert"]);
  });

  it("schreibt in den Hinweis am Balken nur, was es an dem Tag gab", () => {
    expect(tagZeilen(tag())).toContain("Abtauen");
    expect(tagZeilen(tag({ abtau_min: 0, abtauungen: 0, zusatz_min: 0 }))).not.toMatch(/Abtauen|Heizstab/);
  });
});
