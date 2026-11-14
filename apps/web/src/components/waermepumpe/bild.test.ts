import { describe, expect, it } from "vitest";
import type { Measurement, Waermepumpe } from "@/lib/api/models";
import { BLOCK, PLAN, SCHILD, TANK, aufnahme, brauchbar, pfad, satz, zahl } from "./bild";

const m = (value: number | null, quality: Measurement["quality"] = "ok"): Measurement => ({ value, quality, observed_at: "2026-11-13T22:30:54Z", source: "test" });

function daten(teil: Partial<Waermepumpe> = {}): Waermepumpe {
  return {
    now: "2026-11-13T22:30:54Z",
    laeuft: true,
    zustand_code: 3,
    zustand_de: "heizt",
    pumpe_laeuft: true,
    aussen_c: m(4.6),
    verdampfer_c: m(2.3),
    sauggas_c: m(3.3),
    heissgas_c: m(46.4),
    fluessig_c: m(36.6),
    verdichter_hz: m(58),
    leistung_bus_kw: m(1.448),
    leistung_zaehler_kw: m(1.5),
    vorlauf_c: m(39.9),
    ruecklauf_c: m(36.5),
    durchfluss_l_min: m(29.8),
    vorlauf_soll_c: m(45),
    speicherfuehler_c: m(47.6),
    puffer_c: [m(48), m(44), m(39), m(35)],
    spreizung_k: 3.4,
    waermeleistung_kw: 7.07,
    arbeitszahl: 4.7,
    hinweise_de: [],
    ...teil,
  };
}

describe("die Zahlen der Wärmepumpe", () => {
  it("ein fehlender Wert ist ein Fragezeichen und keine Null", () => {
    expect(zahl(null)).toBe("?");
    expect(zahl(39.94)).toBe("39,9");
    expect(zahl(58, 0)).toBe("58");
    expect(brauchbar(m(1, "stale"))).toBe(false);
    expect(brauchbar(m(null))).toBe(false);
  });

  it("die Leistungsaufnahme kommt vom Zähler, und ohne ihn von der Maschine", () => {
    expect(aufnahme(daten())).toEqual({ kw: 1.5, quelle: "Zähler" });
    expect(aufnahme(daten({ leistung_zaehler_kw: m(null, "unavailable") }))).toEqual({ kw: 1.448, quelle: "laut Maschine" });
    expect(aufnahme(daten({ leistung_zaehler_kw: m(null, "unavailable"), leistung_bus_kw: m(null, "unavailable") })).kw).toBeNull();
  });

  it("der Satz sagt, was sie tut, und rechnet nur, wenn es etwas zu rechnen gibt", () => {
    expect(satz(daten())).toBe("Die Wärmepumpe heizt: rund 7,1 kW Wärme aus 1,5 kW Strom.");
    expect(satz(daten({ waermeleistung_kw: null }))).toBe("Die Wärmepumpe heizt und nimmt 1,5 kW auf.");
    expect(satz(daten({ laeuft: false, zustand_de: "steht", waermeleistung_kw: null }))).toBe("Die Wärmepumpe steht.");
    expect(satz(daten({ zustand_code: 9, zustand_de: "taut ab", waermeleistung_kw: null }))).toBe("Die Wärmepumpe taut ab und nimmt 1,5 kW auf.");
  });
});

describe("die Zeichnung", () => {
  const innerhalb = (lage: "breit" | "hoch", x: number, y: number) => {
    const [, , w, h] = PLAN[lage].viewBox.split(" ").map(Number) as [number, number, number, number];
    return x >= 0 && y >= 0 && x <= w && y <= h;
  };

  it("jede Leitung, jeder Block und jedes Schild liegt in beiden Lagen im Bild", () => {
    for (const lage of ["breit", "hoch"] as const) {
      const p = PLAN[lage];
      for (const leitung of [p.heissgas, p.fluessig, p.vorlauf, p.vorlaufTiefer, p.ruecklauf]) {
        expect(leitung.length).toBeGreaterThan(1);
        for (const [x, y] of leitung) expect(innerhalb(lage, x, y)).toBe(true);
      }
      for (const [name, [x, y]] of [["aussen", p.aussen], ["innen", p.innen], ["speicher", p.speicher]] as const) {
        expect(innerhalb(lage, x + BLOCK[name].w, y + BLOCK[name].h)).toBe(true);
      }
      for (const [x, y] of Object.values(p.schild)) expect(innerhalb(lage, x + SCHILD.w, y + SCHILD.h)).toBe(true);
    }
  });

  it("der Vorlauf endet oben im Speicher, der Rücklauf beginnt unten", () => {
    for (const lage of ["breit", "hoch"] as const) {
      const p = PLAN[lage];
      const [sx, sy] = p.speicher;
      const ende = p.vorlauf[p.vorlauf.length - 1]!;
      const anfang = p.ruecklauf[0]!;
      expect(ende[1]).toBe(sy + TANK.y);
      expect(ende[0]).toBeGreaterThanOrEqual(sx + TANK.x);
      expect(ende[0]).toBeLessThanOrEqual(sx + TANK.x + TANK.w);
      expect(anfang[1]).toBeGreaterThan(sy + TANK.y + TANK.h / 2);
      // Im Heizbetrieb endet der Vorlauf seitlich am Glas, auf halber Höhe, und beginnt dort,
      // wo auch der andere beginnt: am Innengerät.
      const tief = p.vorlaufTiefer[p.vorlaufTiefer.length - 1]!;
      expect(tief).toEqual([sx + TANK.x + TANK.w, sy + TANK.y + TANK.h / 2]);
      expect(p.vorlaufTiefer[0]).toEqual(p.vorlauf[0]);
    }
  });

  it("ein Pfad ist eine Folge von Strecken", () => {
    expect(pfad([[1, 2], [3, 4], [3, 9]])).toBe("M1 2 L3 4 L3 9");
  });
});
