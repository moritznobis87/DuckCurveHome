import { describe, expect, it } from "vitest";
import { lageAus, type Umstaende } from "./lage";

const basis: Umstaende = { unterstuetzt: true, ios: false, installiert: false, erlaubnis: "default", abo: false };

describe("lageAus", () => {
  it("unterscheidet das iPhone im Browser von einem Gerät, das es gar nicht kann", () => {
    // Safari auf dem iPhone kennt Web Push nur in der App vom Home-Bildschirm. Das ist kein
    // „geht nicht", sondern ein Schritt, den der Mensch tun kann, und so muss es dastehen.
    expect(lageAus({ ...basis, unterstuetzt: false, ios: true })).toBe("ios-browser");
    expect(lageAus({ ...basis, unterstuetzt: false, ios: true, installiert: true })).toBe("geht-nicht");
    expect(lageAus({ ...basis, unterstuetzt: false })).toBe("geht-nicht");
  });

  it("eine Ablehnung geht vor: ein altes Abonnement nützt dann nichts", () => {
    expect(lageAus({ ...basis, erlaubnis: "denied", abo: true })).toBe("verboten");
  });

  it("an ist nur, wer ein Abonnement hat", () => {
    expect(lageAus({ ...basis, erlaubnis: "granted" })).toBe("aus");
    expect(lageAus({ ...basis, erlaubnis: "granted", abo: true })).toBe("an");
    expect(lageAus(basis)).toBe("aus");
  });
});
