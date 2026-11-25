import { describe, expect, it } from "vitest";
import { KEIN_GERAET, MITTEILUNGEN } from "./Mitteilungen";
import { briefsatz } from "./Morgenbrief";

/** Die Sätze der Seite „Mitteilungen“ wie in der App (`MitteilungsstandTests.swift`). */
describe("Mitteilungen", () => {
  it("sagt dasselbe wie die App", () => {
    expect(MITTEILUNGEN.satz).toBe("Störungen und das Morning Briefing auf die angemeldeten Geräte.");
    expect(KEIN_GERAET).toBe("Kein Gerät angemeldet. Störungen und das Morning Briefing gehen an niemanden.");
    expect(briefsatz("07:00")).toBe("Jeden Morgen um 07:00 Uhr: Sonne, Strompreis und Wärme des Tages.");
    expect(briefsatz(null)).toBe("Jeden Morgen um 07:00 Uhr: Sonne, Strompreis und Wärme des Tages.");
  });
});
