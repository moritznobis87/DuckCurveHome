import { describe, expect, it } from "vitest";
import type { DoorEntry } from "@/lib/api/models";
import { TUERSATZ, zaehlung } from "./DoorLog";

const eintrag = (outcome: string): DoorEntry => ({ at: "2026-11-25T06:00:00Z", door: "Haustür", actor: "Anna", method: "FACE", outcome, reason: "" }) as DoorEntry;

/** Dieselben Zahlen und derselbe Satz wie in der App (`Tuerprotokoll.kacheln`, `kartensatz`). */
describe("Haustür", () => {
  it("zählt Öffnungen, Abweisungen und Fehlschläge wie die App", () => {
    const z = zaehlung([eintrag("geöffnet"), eintrag("geöffnet"), eintrag("abgelehnt"), eintrag("fehlgeschlagen")]);
    expect(z.map((k) => [k.wort, k.wert, k.ton])).toEqual([
      ["Öffnungen", 2, ""],
      ["abgewiesen", 1, "achtung"],
      ["fehlgeschlagen", 1, "alarm"],
    ]);
    expect(zaehlung([]).map((k) => k.ton)).toEqual(["", "", ""]);
    expect(TUERSATZ).toBe("Zutritte und abgewiesene Versuche am Reader.");
  });
});
