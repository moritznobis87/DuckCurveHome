import { describe, expect, it } from "vitest";
import { ABSCHNITTSZEICHEN } from "./abschnitte";

/** Dieselben Zeichen wie in der App (`Hausgeraet.abschnittszeichen`, `HausgeraetTests.swift`). */
describe("Hausgerät", () => {
  it("gibt jeder Karte dasselbe Zeichen wie die App", () => {
    expect(ABSCHNITTSZEICHEN).toEqual({
      Dienste: "dashboard",
      Rechenkern: "bolt",
      Gerät: "house",
      "SSD-Gesundheit": "shield",
      "Platz auf der SSD": "battery",
      Verlauf: "chart",
      Sicherung: "calendar",
      "Abläufe auf dem Gerät": "clock",
      Software: "loop",
      "Neu starten": "alert",
    });
  });
});
