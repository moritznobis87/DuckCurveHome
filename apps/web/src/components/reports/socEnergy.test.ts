import { describe, expect, it } from "vitest";
import { socEnergy } from "./BatteryReport";
import type { HistoryRow } from "@/lib/api/models";

/** Minutenreihe mit einem Ladestandsverlauf in Prozentpunkten. */
function rows(socPercent: number[]): HistoryRow[] {
  return socPercent.map((p, i) => ({ ts: `2026-09-08T00:${String(i).padStart(2, "0")}:00Z`, battery_soc: p / 100 }));
}

describe("Gegenprobe aus dem Ladestand", () => {
  it("misst die Entladung des 08.09.: 33 % eines 5,1-kWh-Speichers", () => {
    // Genau der Fall, an dem die Bilanz aufgefallen ist: nachts von 33 auf 0 Prozent.
    const soc = Array.from({ length: 34 }, (_, i) => 33 - i);
    const e = socEnergy(rows(soc), 5.1);
    expect(e?.discharge).toBeCloseTo(5.1 * 0.33, 2);
    expect(e?.charge).toBeCloseTo(0, 3);
  });

  it("zählt Laden und Entladen getrennt", () => {
    const e = socEnergy(rows([...Array.from({ length: 20 }, (_, i) => 20 + i * 4), ...Array.from({ length: 20 }, (_, i) => 96 - i * 2)]), 5.0);
    expect(e?.charge).toBeCloseTo(5.0 * 0.76, 2);
    expect(e?.discharge).toBeCloseTo(5.0 * 0.38, 2);
  });

  it("schweigt ohne Ladestand und ohne Kapazität", () => {
    expect(socEnergy(rows([50, 49, 48]), 5.1)).toBeNull(); // zu wenige Punkte
    expect(socEnergy(rows(Array.from({ length: 20 }, () => 50)), 0)).toBeNull();
  });
});
