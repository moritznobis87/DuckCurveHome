import { describe, expect, it } from "vitest";
import { PRUEFSAETZE } from "./pruefsaetze";

/** Dieselben Sätze wie in der App (`Pruefworte`, `DatenpruefungTests.swift`). */
describe("Daten prüfen", () => {
  it("sagt in den Karten dasselbe wie die App", () => {
    expect(PRUEFSAETZE.leistungen).toBe("Bezug und Entladen zählen positiv, Einspeisung und Laden negativ; der Ladestand steht rechts in Prozent.");
    expect(PRUEFSAETZE.quellen).toBe("Was gerade liefert und was ausbleibt.");
    expect(PRUEFSAETZE.abdeckung(28)).toBe("Minuten je Stunde über 28 Tage, von 0 bis 60.");
    expect(PRUEFSAETZE.lesehilfe).toBe("Ohne Farbe stand der Dienst still. Rot heißt, das Gerät hat in dieser Stunde nichts geliefert.");
  });
});
