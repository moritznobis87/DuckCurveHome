import { describe, expect, it } from "vitest";
import type { Measurement } from "@/lib/api/models";
import { pufferZustand } from "./puffer";

const JETZT = new Date("2026-10-25T12:22:00Z").getTime();

const fuehler = (wert: number | null, quality: Measurement["quality"] = "ok", minutenAlt = 0): Measurement =>
  ({
    value: wert,
    quality,
    observed_at: new Date(JETZT - minutenAlt * 60_000).toISOString(),
    source: "mqtt",
  }) as Measurement;

const vier = (quality: Measurement["quality"] = "ok", minutenAlt = 0) => [
  fuehler(61, quality, minutenAlt),
  fuehler(61, quality, minutenAlt),
  fuehler(60, quality, minutenAlt),
  fuehler(38, quality, minutenAlt),
];

describe("pufferZustand", () => {
  it("nennt den Zustand, solange die Fühler frisch sind", () => {
    expect(pufferZustand(vier(), JETZT, false, "partial").wort).toBe("hält");
    expect(pufferZustand(vier(), JETZT, true, "partial").wort).toBe("lädt");
    expect(pufferZustand(vier(), JETZT, false, "full").wort).toBe("voll");
    expect(pufferZustand(vier(), JETZT, false, "cold").wort).toBe("kalt");
  });

  it("sagt das Alter, wenn ein Fühler veraltet ist", () => {
    // Der Fall vom 25.10.2026: Temperaturen standen da, der Füllstand blieb leer, und niemand
    // konnte sehen warum. Das Wort nennt jetzt den Grund.
    const z = pufferZustand(vier("stale", 190), JETZT, false, "unknown");
    expect(z.veraltet).toBe(true);
    expect(z.wort).toBe("Werte vor 3 h");
  });

  it("nimmt den ältesten der vier, denn er ist der Grund", () => {
    const gemischt = [fuehler(61), fuehler(61, "stale", 200), fuehler(60), fuehler(38, "stale", 40)];
    expect(pufferZustand(gemischt, JETZT, false, "unknown").wort).toBe("Werte vor 3 h");
  });

  it("unterscheidet veraltet von gar nicht da", () => {
    const leer = [fuehler(null, "unavailable"), fuehler(null, "unavailable"), fuehler(null, "unavailable"), fuehler(null, "unavailable")];
    const z = pufferZustand(leer, JETZT, false, "unknown");
    expect(z.vollstaendig).toBe(false);
    expect(z.veraltet).toBe(false);
    expect(z.wort).toBe("keine Werte");
  });

  it("lässt ein frisches Laden nicht von einem alten Nachbarn verdecken", () => {
    // Ein einziger veralteter Fühler genügt, damit der Dienst keinen Füllstand rechnet - dann
    // darf die Kachel auch nicht „lädt" behaupten.
    const einer = [fuehler(61), fuehler(61), fuehler(60), fuehler(38, "stale", 95)];
    expect(pufferZustand(einer, JETZT, true, "partial").wort).toBe("Werte vor 2 h");
  });
});
