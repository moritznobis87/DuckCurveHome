import { describe, expect, it } from "vitest";
import { abweichungen, etagenText, gruppiere, mittel, ziel } from "./logic";
import { abweichungText, anteilText, farbe, kelvin, ventilText } from "./palette";
import type { RoomLive, RoomSeries } from "@/lib/api/models";

function raum(p: Partial<RoomLive> & { id: number }): RoomLive {
  return {
    id: p.id,
    name: p.name ?? `Raum ${p.id}`,
    floor: p.floor ?? "",
    circuits: p.circuits ?? 0,
    temp_c: p.temp_c ?? null,
    setpoint_c: p.setpoint_c ?? null,
    offset_k: p.offset_k ?? null,
    target_c: p.target_c ?? p.setpoint_c ?? null,
    humidity_pct: p.humidity_pct ?? null,
    valve: p.valve ?? null,
    deviation_k: p.deviation_k ?? null,
    observed_at: p.observed_at ?? null,
    quality: p.quality ?? "ok",
  };
}

describe("Gruppierung nach Etage", () => {
  it("behält die Reihenfolge der Schnittstelle und sortiert nicht alphabetisch", () => {
    const g = gruppiere([
      raum({ id: 1, floor: "Obergeschoss" }),
      raum({ id: 2, floor: "Erdgeschoss" }),
      raum({ id: 3, floor: "Obergeschoss" }),
    ]);
    expect(g.map((x) => x.floor)).toEqual(["Obergeschoss", "Erdgeschoss"]);
    expect(g[0]!.rooms.map((r) => r.id)).toEqual([1, 3]);
  });

  it("gibt Räumen ohne Etagenangabe eine eigene Überschrift statt sie einzusortieren", () => {
    const g = gruppiere([raum({ id: 1, floor: "" })]);
    expect(g[0]!.floor).toBe("ohne Etagenangabe");
  });
});

describe("Zusammenfassung einer Etage", () => {
  it("zählt kalte Räume und stumme Fühler getrennt", () => {
    const text = etagenText([
      raum({ id: 1, temp_c: 20, deviation_k: -1.2 }),
      raum({ id: 2, temp_c: null }),
      raum({ id: 3, temp_c: 21, deviation_k: 0.1 }),
    ]);
    expect(text).toBe("3 Räume · 1 unter dem Ziel · 1 ohne Messwert");
  });

  it("sagt es, wenn nichts zu melden ist", () => {
    expect(etagenText([raum({ id: 1, temp_c: 21, deviation_k: 0.2 })])).toBe("1 Raum · alle am Ziel");
  });

  it("zählt eine Abweichung innerhalb des Messrauschens nicht als zu kalt", () => {
    expect(etagenText([raum({ id: 1, temp_c: 21, deviation_k: -0.4 })])).toContain("alle am Ziel");
  });
});

describe("Abweichung je Fenster", () => {
  const serie = (temp: (number | null)[], soll: (number | null)[], off: (number | null)[] = []): RoomSeries => ({
    id: 1,
    name: "x",
    floor: "",
    circuits: 2,
    temp_c: temp,
    setpoint_c: soll,
    offset_k: off.length ? off : soll.map(() => null),
    valve: [],
  });

  it("bleibt leer, wo eine der beiden Zahlen fehlt", () => {
    expect(abweichungen(serie([20, null, 22], [21, 21, null]))).toEqual([-1, null, null]);
  });

  it("rechnet gegen Sollwert plus Offset, nicht gegen den Sollwert allein", () => {
    // Controme zeigt in seiner Oberfläche `21,00 - 0,32` und darunter `20,68` als Zielwert.
    expect(ziel(serie([20.36], [21], [-0.32]), 0)).toBeCloseTo(20.68, 5);
    expect(abweichungen(serie([20.36], [21], [-0.32]))[0]).toBeCloseTo(-0.32, 5);
  });

  it("nimmt einen fehlenden Offset als null, einen fehlenden Sollwert als kein Ziel", () => {
    expect(ziel(serie([20], [21], [null]), 0)).toBe(21);
    expect(ziel(serie([20], [null], [0.5]), 0)).toBeNull();
  });

  it("mittelt nur über vorhandene Werte", () => {
    expect(mittel([1, null, 3])).toBe(2);
    expect(mittel([null, null])).toBeNull();
  });
});

describe("Texte", () => {
  it("nennt eine Abweichung innerhalb des Bandes „am Ziel“", () => {
    expect(abweichungText(0.3)).toBe("am Ziel");
    expect(abweichungText(-0.5)).toBe("am Ziel");
  });

  it("unterscheidet kein Messwert von null Abweichung", () => {
    expect(abweichungText(null)).toBe("kein Messwert");
    expect(abweichungText(0)).toBe("am Ziel");
  });

  it("setzt das Minuszeichen und das deutsche Komma", () => {
    expect(kelvin(-1.25)).toBe("−1,3 K");
    expect(kelvin(0.7)).toBe("+0,7 K");
  });

  it("zählt im Augenblick die offenen Kreise, weil es dort nur ganze gibt", () => {
    expect(ventilText(0.5, 4)).toBe("2 von 4 offen");
    expect(ventilText(1, 1)).toBe("1 von 1 offen");
  });

  it("sagt „zu“ statt „0 von 3 Kreisen“", () => {
    expect(ventilText(0, 3)).toBe("zu");
    expect(anteilText(0)).toBe("zu");
  });

  it("fällt auf den Anteil zurück, wo kein ganzer Kreis herauskommt", () => {
    expect(ventilText(0.45, 4)).toBe("45 %");
    expect(ventilText(0.5, 0)).toBe("50 %");
    expect(ventilText(null, 4)).toBe("kein Messwert");
  });

  it("nennt über einen Zeitraum nur den Anteil - dort ist er kein Bruch mehr", () => {
    // 0,57 an einem Raum mit einem Kreis heißt „ein Teil der Zeit offen", nicht „0,57 Kreise".
    expect(anteilText(0.57)).toBe("57 %");
    expect(anteilText(null)).toBe("kein Messwert");
  });
});

describe("Farbskala", () => {
  it("ist zweiseitig: kalt und warm sind nicht dieselbe Farbe", () => {
    expect(farbe(-2)).not.toBe(farbe(2));
    expect(farbe(-1)).not.toBe(farbe(1));
  });

  it("gibt null eine eigene Stufe und nicht die Farbe der Nachbarn", () => {
    expect(farbe(0)).toBe("var(--dev-null)");
    expect(farbe(0.4)).toBe("var(--dev-null)");
    expect(farbe(0.6)).not.toBe("var(--dev-null)");
  });
});
