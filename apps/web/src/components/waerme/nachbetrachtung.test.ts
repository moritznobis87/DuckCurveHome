import { describe, expect, it } from "vitest";
import type { Nachbetrachtung } from "@/lib/api/models";
import { achse, euro, euroMitVorzeichen, staerke, treppe, zeilen, type Abstand, type Linie } from "./nachbetrachtung";

function linie(key: string, eur: number | null, mehr: Partial<Linie> = {}): Linie {
  return { key, name_de: key, verfuegbar: eur !== null, grund_de: eur === null ? "fehlt" : "", geschaetzt: false, eur, ...mehr };
}

function abstand(key: string, von: string, nach: string, eur: number | null): Abstand {
  return { key, name_de: key, von, nach, eur, satz_de: eur === null ? "" : `Satz zu ${key}` };
}

function tag(linien: Linie[], abstaende: Abstand[]): Nachbetrachtung {
  return {
    day: "2026-11-07",
    von: "2026-11-06T23:00:00Z",
    bis: "2026-11-07T23:00:00Z",
    schritt_min: 15,
    n_verglichen: 96,
    laeuft_noch: false,
    wp_kw: 4.5,
    verguetung_ct: 8,
    hat_ofen: false,
    satz_de: "",
    verschieben_de: "",
    linien,
    abstaende,
  };
}

const VOLL = tag(
  [linie("versprochen", 1.35), linie("erster", 1.13), linie("letzter", 0.9), linie("wirklich", 4.59), linie("perfekt", 0.8)],
  [
    abstand("prognosefehler", "versprochen", "erster", -0.22),
    abstand("nachfuehren", "erster", "letzter", -0.23),
    abstand("eingriff", "letzter", "wirklich", 3.69),
    abstand("voraussicht", "perfekt", "letzter", 0.1),
  ],
);

describe("treppe", () => {
  it("führt vom Versprechen über drei Stufen zur Wirklichkeit", () => {
    const t = treppe(VOLL);
    expect(t.map((s) => s.key)).toEqual(["versprochen", "prognosefehler", "nachfuehren", "eingriff", "wirklich", "perfekt"]);
    expect(t.map((s) => s.art)).toEqual(["summe", "stufe", "stufe", "stufe", "summe", "bezug"]);
    expect(t[5]?.satz).toBe("Satz zu voraussicht");
    // Jede Stufe beginnt, wo die vorige endet, und die letzte endet auf der Wirklichkeit.
    expect(t[1]?.von).toBe(1.35);
    expect(t[2]?.von).toBeCloseTo(1.13);
    expect(t[3]?.von).toBeCloseTo(0.9);
    expect(t[3]?.bis).toBeCloseTo(4.59);
    expect(t[4]?.bis).toBe(4.59);
  });

  it("beginnt beim gehaltenen Fahrplan, wenn das Versprechen fehlt", () => {
    const ohne = tag(
      [linie("versprochen", null), linie("erster", 1.13), linie("letzter", 0.9), linie("wirklich", 4.59)],
      [abstand("prognosefehler", "versprochen", "erster", null), abstand("nachfuehren", "erster", "letzter", -0.23), abstand("eingriff", "letzter", "wirklich", 3.69)],
    );
    const t = treppe(ohne);
    expect(t.map((s) => s.key)).toEqual(["erster", "nachfuehren", "eingriff", "wirklich"]);
    expect(t[0]?.bis).toBe(1.13);
  });

  it("zeigt ohne jeden Fahrplan nur die Wirklichkeit und zeichnet keine Stufe der Höhe null", () => {
    const nur = tag(
      [linie("versprochen", null), linie("erster", null), linie("letzter", null), linie("wirklich", 4.59), linie("perfekt", 3.1)],
      [abstand("prognosefehler", "versprochen", "erster", null), abstand("nachfuehren", "erster", "letzter", null), abstand("eingriff", "letzter", "wirklich", null), abstand("voraussicht", "perfekt", "letzter", null)],
    );
    const t = treppe(nur);
    expect(t.map((s) => s.key)).toEqual(["wirklich", "perfekt"]);
    expect(t[1]?.art).toBe("bezug");
  });

  it("bleibt leer, wenn nichts gemessen ist", () => {
    expect(treppe(tag([linie("wirklich", null)], []))).toEqual([]);
  });
});

describe("achse", () => {
  it("beginnt bei null und endet rund über dem größten Stand", () => {
    const a = achse(treppe(VOLL));
    expect(a.min).toBe(0);
    expect(a.max).toBe(5);
    expect(a.marken).toEqual([0, 1, 2, 3, 4, 5]);
  });

  it("hat auch für Centbeträge eine Achse", () => {
    const a = achse([{ key: "wirklich", name: "", art: "summe", von: 0, bis: 0.12, eur: 0.12, geschaetzt: false, satz: "" }]);
    expect(a.max).toBe(0.5);
    expect(a.marken.length).toBeGreaterThanOrEqual(3);
  });

  it("reicht unter null, wenn eine Linie negativ ist", () => {
    // Bei vollem Überschuss und negativem Preis kann Wärme Geld bringen.
    const a = achse([{ key: "wirklich", name: "", art: "summe", von: 0, bis: -0.4, eur: -0.4, geschaetzt: false, satz: "" }]);
    expect(a.min).toBeLessThanOrEqual(-0.4);
    expect(a.marken).toContain(0);
  });
});

describe("Beträge", () => {
  it("schreibt Euro mit Komma und lässt Fehlendes als Strich", () => {
    expect(euro(3.42)).toBe("3,42 €");
    expect(euro(-0.4)).toBe("−0,40 €");
    expect(euro(null)).toBe("-");
  });

  it("gibt einer Änderung immer ihr Vorzeichen", () => {
    expect(euroMitVorzeichen(0.31)).toBe("+0,31 €");
    expect(euroMitVorzeichen(-0.8)).toBe("−0,80 €");
    expect(euroMitVorzeichen(0)).toBe("±0,00 €");
    expect(euroMitVorzeichen(undefined)).toBe("-");
  });
});

describe("staerke", () => {
  it("teilt den Strom einer Viertelstunde in vier Stufen der Nennleistung", () => {
    expect(staerke(0, 1)).toBe(0);
    expect(staerke(0.25, 1)).toBe(1);
    expect(staerke(0.26, 1)).toBe(2);
    expect(staerke(0.76, 1)).toBe(4);
    expect(staerke(1.4, 1)).toBe(4);
  });

  it("unterscheidet nichts gezogen von keiner Aussage", () => {
    expect(staerke(null, 1)).toBeNull();
    expect(staerke(0.01, 1)).toBe(0);
  });
});

describe("zeilen", () => {
  it("nimmt nur verfügbare Linien und lässt das Versprechen weg", () => {
    const d = tag([linie("versprochen", 1.35), linie("erster", 1.13), linie("letzter", null), linie("wirklich", 4.59)], []);
    expect(zeilen(d).map((l) => l.key)).toEqual(["erster", "wirklich"]);
  });
});
