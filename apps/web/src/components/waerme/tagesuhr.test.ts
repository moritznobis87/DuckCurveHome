import { describe, expect, it } from "vitest";
import { anteil, anteilAus, indexBei, laeufe, punkt, ringstueck, stufe } from "./tagesuhr";

const STUNDE = 3_600_000;
const SCHRITT = 5 * 60_000;

describe("anteil", () => {
  it("läuft vom Tagesbeginn zum Tagesende von 0 bis 1", () => {
    expect(anteil(0, 0, 24 * STUNDE)).toBe(0);
    expect(anteil(6 * STUNDE, 0, 24 * STUNDE)).toBe(0.25);
    expect(anteil(24 * STUNDE, 0, 24 * STUNDE)).toBe(1);
  });

  it("nimmt den Tag der Zeitumstellung als ganzen Kreis", () => {
    // 25 Stunden: die Mitte des Tages liegt bei 12,5 Stunden, nicht bei 12.
    expect(anteil(12.5 * STUNDE, 0, 25 * STUNDE)).toBe(0.5);
  });

  it("bleibt bei Unsinn im Bereich", () => {
    expect(anteil(-5, 0, 10)).toBe(0);
    expect(anteil(50, 0, 10)).toBe(1);
    expect(anteil(5, 10, 10)).toBe(0);
  });
});

describe("punkt", () => {
  it("setzt den Tagesbeginn nach oben und geht im Uhrzeigersinn", () => {
    const [x0, y0] = punkt(100, 100, 50, 0);
    expect(x0).toBeCloseTo(100);
    expect(y0).toBeCloseTo(50);
    const [x1, y1] = punkt(100, 100, 50, 0.25);
    expect(x1).toBeCloseTo(150);
    expect(y1).toBeCloseTo(100);
    const [x2, y2] = punkt(100, 100, 50, 0.5);
    expect(x2).toBeCloseTo(100);
    expect(y2).toBeCloseTo(150);
  });
});

describe("anteilAus", () => {
  it("ist die Umkehrung von punkt", () => {
    for (const a of [0, 0.1, 0.25, 0.5, 0.75, 0.99]) {
      const [x, y] = punkt(0, 0, 80, a);
      expect(anteilAus(x, y)).toBeCloseTo(a, 6);
    }
  });
});

describe("ringstueck", () => {
  it("zeichnet nichts für eine leere Spanne", () => {
    expect(ringstueck(0, 0, 10, 20, 0.3, 0.3)).toBe("");
    expect(ringstueck(0, 0, 10, 20, 0.5, 0.2)).toBe("");
  });

  it("nimmt für mehr als den halben Kreis den großen Bogen", () => {
    expect(ringstueck(0, 0, 10, 20, 0, 0.3)).toContain(" 0 0 1 ");
    expect(ringstueck(0, 0, 10, 20, 0, 0.7)).toContain(" 0 1 1 ");
  });

  it("teilt den vollen Ring, statt ihn verschwinden zu lassen", () => {
    // Ein Bogen von einem Punkt zu demselben hat die Länge null. Zwei Hälften haben sie nicht.
    const d = ringstueck(0, 0, 10, 20, 0, 1);
    expect(d.match(/M/g)?.length).toBe(2);
  });
});

describe("laeufe", () => {
  const zeiten = [0, 1, 2, 3, 4, 5].map((i) => i * SCHRITT);

  it("fasst gleiche Nachbarn zusammen und trennt bei Wechsel", () => {
    const l = laeufe([true, true, false, false, true, true], zeiten, SCHRITT);
    expect(l).toEqual([
      { von: 0, bis: 2 * SCHRITT, wert: true },
      { von: 2 * SCHRITT, bis: 4 * SCHRITT, wert: false },
      { von: 4 * SCHRITT, bis: 6 * SCHRITT, wert: true },
    ]);
  });

  it("lässt eine Lücke in der Zeit offen, auch wenn der Wert gleich bleibt", () => {
    // Zwischen dem zweiten und dritten Bild fehlt eine Stunde. Ein Lauf darüber hinweg zeigte
    // eine Stunde Betrieb, von der niemand etwas weiß.
    const mitLuecke = [0, SCHRITT, STUNDE, STUNDE + SCHRITT];
    const l = laeufe([true, true, true, true], mitLuecke, SCHRITT);
    expect(l).toHaveLength(2);
    expect(l[0]).toEqual({ von: 0, bis: 2 * SCHRITT, wert: true });
    expect(l[1]?.von).toBe(STUNDE);
  });

  it("macht aus fehlenden Werten keinen Lauf und verbindet nicht über sie hinweg", () => {
    const l = laeufe([true, null, true, undefined, true], zeiten.slice(0, 5), SCHRITT);
    expect(l).toHaveLength(3);
    expect(l.every((x) => x.bis - x.von === SCHRITT)).toBe(true);
  });

  it("unterscheidet ein Nein von keinem Wert", () => {
    const l = laeufe([false, null], zeiten.slice(0, 2), SCHRITT);
    expect(l).toEqual([{ von: 0, bis: SCHRITT, wert: false }]);
  });
});

describe("stufe", () => {
  it("teilt die Spanne in gleich breite Stufen und bleibt an den Rändern drin", () => {
    expect(stufe(0, 0, 10, 5)).toBe(0);
    expect(stufe(4.9, 0, 10, 5)).toBe(2);
    expect(stufe(10, 0, 10, 5)).toBe(4);
    expect(stufe(99, 0, 10, 5)).toBe(4);
    expect(stufe(-3, 0, 10, 5)).toBe(0);
  });

  it("teilt nicht durch null, wenn alle Werte gleich sind", () => {
    expect(stufe(7, 7, 7, 5)).toBe(2);
  });
});

describe("indexBei", () => {
  it("findet das nächstgelegene Bild", () => {
    const zeiten = [0, 6, 12, 18].map((h) => h * STUNDE);
    expect(indexBei(0.26, zeiten, 0, 24 * STUNDE)).toBe(1);
    expect(indexBei(0.9, zeiten, 0, 24 * STUNDE)).toBe(3);
    expect(indexBei(0.5, [], 0, 24 * STUNDE)).toBe(-1);
  });
});
