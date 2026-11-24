import { describe, expect, it } from "vitest";
import { KARTEN, ROLLE, loeschfrage } from "./kontoworte";

/** „Mein Zugang“ sagt im Dashboard dasselbe wie in der App (`KontowortTests.swift`). */
describe("Mein Zugang", () => {
  it("nennt die Rollen wie die App", () => {
    expect(ROLLE.hausherr).toEqual({ name: "Hausherr", satz: "Sieht alles und darf alles einstellen." });
    expect(ROLLE.bewohner!.satz).toBe("Sieht das Haus und darf dort stellen.");
    expect(ROLLE.service!.name).toBe("Beratung");
    expect(ROLLE.gast!.satz).toBe("Sieht zu und stellt nichts.");
  });

  it("gibt den Karten dieselben Zeichen und Sätze wie die App", () => {
    expect([KARTEN.passkeys.zeichen, KARTEN.passwort.zeichen, KARTEN.sitzungen.zeichen]).toEqual(["key", "lock", "device"]);
    expect([KARTEN.passkeys.satz, KARTEN.passwort.satz, KARTEN.sitzungen.satz]).toEqual([
      "Anmelden mit Gesicht oder Finger, ohne Passwort.",
      "Der zweite Weg herein, an jedem Gerät.",
      "Wo du gerade angemeldet bist.",
    ]);
  });

  it("fragt vor dem Löschen eines Passkeys mit seinem Namen", () => {
    expect(loeschfrage("iPhone")).toBe("„iPhone“ löschen?");
  });
});
