import { describe, expect, it } from "vitest";
import { balkenhoehen, laeufe } from "./Kachelbild";

/** Das kleine Bild der Kachel rechnet wie in der App (`KachelbildTests.swift`). */
describe("Kachelbild", () => {
  it("gibt dem Tag immer 24 Plätze, was noch nicht war, bleibt leer", () => {
    const hoehen = balkenhoehen([1, 2, 4]);
    expect(hoehen).toHaveLength(24);
    expect(hoehen.slice(0, 3)).toEqual([0.25, 0.5, 1]);
    expect(hoehen[3]).toBeNull();
    expect(hoehen[23]).toBeNull();
  });

  it("lässt einen Tag ohne Wert flach und zeichnet nichts nach unten", () => {
    expect(balkenhoehen([0, 0]).slice(0, 2)).toEqual([0, 0]);
    expect(balkenhoehen([-1, 2]).slice(0, 2)).toEqual([0, 1]);
  });

  it("findet die Läufe eines Streifens", () => {
    expect(laeufe([0, 1, 1, 0, 1])).toEqual([
      { von: 0.2, bis: 0.6 },
      { von: 0.8, bis: 1 },
    ]);
    expect(laeufe([])).toEqual([]);
    expect(laeufe([0, 0])).toEqual([]);
    expect(laeufe([1, 1])).toEqual([{ von: 0, bis: 1 }]);
  });
});
