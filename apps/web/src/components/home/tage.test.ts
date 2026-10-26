import { describe, expect, it } from "vitest";
import type { EnergySummary, HeatReport, Plan } from "@/lib/api/models";
import { grenzen, kennzahlen, preise, pvKwh, pvSumme, schatten, waermeSumme, type MorgenDaten, type Punkt } from "./tage";

const LEER: MorgenDaten = { pvKwh: null, waerme: null, preise: [] };

/** Ein Planintervall; nur die Felder, die hier zählen. */
const iv = (ts: string, kw: number, ct: number | null): Plan["intervals"][number] =>
  ({ ts, expected_pv_kw: kw, price_ct_kwh: ct, planned_hp_state: "free", planned_stove_on: null, reason_code: "none", note_de: null }) as Plan["intervals"][number];

const punkt = (ts: string, heiz: number, ww: number, strom: number): HeatReport["forecast"][number] =>
  ({ ts, outdoor_c: 5, heating_kw: heiz, dhw_kw: ww, cop: 3, electric_kw: strom }) as HeatReport["forecast"][number];

const summary = (werte: Partial<EnergySummary["totals"]>): EnergySummary =>
  ({ totals: werte }) as EnergySummary;

describe("grenzen", () => {
  const mittag = new Date("2026-10-22T12:00:00").getTime();
  it("gibt den Kalendertag des Geräts", () => {
    expect(grenzen("heute", mittag).iso).toBe("2026-10-22");
    expect(grenzen("gestern", mittag).iso).toBe("2026-10-21");
    expect(grenzen("morgen", mittag).iso).toBe("2026-10-23");
  });
  it("beginnt um Mitternacht und endet am nächsten Mitternacht", () => {
    const g = grenzen("gestern", mittag);
    expect(new Date(g.start).getHours()).toBe(0);
    expect(new Date(g.end).getTime() - g.start).toBe(24 * 3600_000);
  });
  // Am Umstellungstag hat der Tag 23 oder 25 Stunden. Über setDate stimmt der Tageswechsel
  // trotzdem; eine Rechnung mit 86400000 ms läge eine Stunde daneben.
  it("trifft den Tageswechsel auch bei der Zeitumstellung", () => {
    const nach = new Date("2026-10-26T12:00:00").getTime();
    expect(grenzen("gestern", nach).iso).toBe("2026-10-25");
    expect(new Date(grenzen("gestern", nach).start).getHours()).toBe(0);
  });
});

describe("pvSumme", () => {
  const start = new Date("2026-10-23T00:00:00").getTime();
  const end = start + 24 * 3600_000;
  it("rechnet Viertelstundenleistung in Energie um", () => {
    const rows = [iv("2026-10-22T23:45:00", 9, 1), iv("2026-10-23T00:00:00", 2, 1), iv("2026-10-23T00:15:00", 4, 1)];
    expect(pvSumme(rows, start, end)).toBeCloseTo(1.5, 5);
  });
  it("ist leer, wenn der Plan den Tag nicht erreicht", () => {
    expect(pvSumme([iv("2026-10-22T10:00:00", 5, 1), iv("2026-10-22T10:15:00", 5, 1)], start, end)).toBeNull();
    expect(pvSumme([], start, end)).toBeNull();
  });
});

describe("preise", () => {
  const start = new Date("2026-10-23T00:00:00").getTime();
  const end = start + 24 * 3600_000;
  it("nimmt nur bekannte Preise des Tages", () => {
    const rows = [iv("2026-10-23T00:00:00", 0, 12.5), iv("2026-10-23T01:00:00", 0, null), iv("2026-10-24T01:00:00", 0, 9)];
    expect(preise(rows, start, end)).toEqual([{ ts: start, ct: 12.5 }]);
  });
});

describe("waermeSumme", () => {
  const start = new Date("2026-10-23T00:00:00").getTime();
  const end = start + 24 * 3600_000;
  it("summiert Stundenwerte zu Energiemengen", () => {
    const rows = [punkt("2026-10-23T00:00:00", 1.5, 0.5, 0.8), punkt("2026-10-23T01:00:00", 1.0, 0, 0.4), punkt("2026-10-24T01:00:00", 9, 9, 9)];
    expect(waermeSumme(rows, start, end)).toEqual({ thermisch: 3, elektrisch: 1.2000000000000002 });
  });
  it("sagt nichts statt null, wenn die Prognose nicht so weit reicht", () => {
    expect(waermeSumme([], start, end)).toBeNull();
  });
});

describe("kennzahlen", () => {
  it("zeigt heute den Preis dieses Augenblicks", () => {
    const k = kennzahlen("heute", summary({ pv_kwh: 12.5, autarky: 0.43, import_cost_eur: 6.45 }), 33.6, LEER);
    expect(k.map((x) => `${x.wert} ${x.einheit}`)).toEqual(["12,5 kWh", "43 %", "6,45 €", "33,6 ct"]);
    expect(k[3]!.wort).toBe("Strom gerade");
  });
  it("zeigt gestern den mittleren Bezugspreis und einen abgeschlossenen Betrag", () => {
    const k = kennzahlen("gestern", summary({ pv_kwh: 9, autarky: 0.5, import_cost_eur: 4, avg_import_price_ct: 28.4 }), 33.6, LEER);
    expect(k[2]!.wort).toBe("bezahlt");
    expect(k[3]).toMatchObject({ wert: "28,4", wort: "Strom im Mittel" });
  });
  it("zeigt morgen Erwartung statt Messung", () => {
    const start = new Date("2026-10-23T00:00:00").getTime();
    const k = kennzahlen("morgen", null, 33.6, {
      pvKwh: 18.25,
      waerme: { thermisch: 41.2, elektrisch: 12.8 },
      preise: [{ ts: start + 13 * 3600_000, ct: 9.2 }, { ts: start, ct: 30 }],
    });
    expect(k[0]).toMatchObject({ wert: "18,3", wort: "Sonne erwartet" });
    expect(k[1]!.wort).toBe("Wärme erwartet · 12,8 kWh Strom");
    expect(k[2]).toMatchObject({ wert: "19,6", wort: "Strom im Mittel" });
    expect(k[3]!.wort).toBe("günstigste Stunde ab 13:00");
  });
  it("sagt beim fehlenden Morgenpreis, wann er kommt", () => {
    const k = kennzahlen("morgen", null, null, LEER);
    expect(k.map((x) => x.wert)).toEqual(["-", "-", "-", "-"]);
    expect(k[2]!.wort).toBe("Preise kommen gegen 13 Uhr");
  });
  it("markiert einen negativen Preis als Gewinn", () => {
    expect(kennzahlen("heute", null, -1.4, LEER)[3]!.gelb).toBe(true);
    expect(kennzahlen("heute", null, 24, LEER)[3]!.gelb).toBe(false);
  });
  it("hat immer vier Zahlen, damit die Zeile nicht springt", () => {
    for (const tag of ["gestern", "heute", "morgen"] as const) {
      expect(kennzahlen(tag, null, null, LEER)).toHaveLength(4);
    }
  });
});

describe("pvKwh", () => {
  const start = new Date("2026-10-23T00:00:00").getTime();
  const reihe = (von: number, bis: number, kw: number): Punkt[] =>
    Array.from({ length: (bis - von) * 60 + 1 }, (_, i) => ({ ts: start + von * 3600_000 + i * 60_000, pv: kw }));

  it("rechnet die Fläche unter der Leistung", () => {
    // Zwei Stunden mit 3 kW sind 6 kWh.
    expect(pvKwh(reihe(10, 12, 3), start + 24 * 3600_000)).toBeCloseTo(6, 3);
  });
  it("hört bei der gefragten Uhrzeit auf", () => {
    expect(pvKwh(reihe(10, 12, 3), start + 11 * 3600_000)).toBeCloseTo(3, 3);
  });
  it("überspringt Lücken von mehr als einer Stunde", () => {
    // Zwei Punkte mit einer Nacht dazwischen: als Trapez wären das Kilowattstunden, die es nie gab.
    const nacht: Punkt[] = [
      { ts: start + 18 * 3600_000, pv: 2 },
      { ts: start + 30 * 3600_000, pv: 2 },
    ];
    expect(pvKwh(nacht, start + 48 * 3600_000)).toBeNull();
  });
  it("gibt null, solange keine Reihe da ist", () => {
    expect(pvKwh([], start)).toBeNull();
    expect(pvKwh([{ ts: start, pv: null }, { ts: start + 60_000, pv: null }], start + 3600_000)).toBeNull();
  });
});

describe("schatten", () => {
  const jetzt = new Date("2026-10-23T12:00:00").getTime();
  const gesternStart = new Date("2026-10-22T00:00:00").getTime();
  const heuteStart = new Date("2026-10-23T00:00:00").getTime();
  const gesternReihe: Punkt[] = Array.from({ length: 121 }, (_, i) => ({ ts: gesternStart + 10 * 3600_000 + i * 60_000, pv: 3 }));
  const heuteReihe: Punkt[] = Array.from({ length: 121 }, (_, i) => ({ ts: heuteStart + 9 * 3600_000 + i * 60_000, pv: 4 }));

  it("legt gestern hinter heute, bis zur gleichen Uhrzeit", () => {
    const s = schatten("heute", jetzt, gesternReihe, heuteReihe);
    expect(s?.wort).toBe("gestern");
    expect(s?.start).toBe(gesternStart);
    expect(s?.kwh).toBeCloseTo(6, 3);
  });
  it("legt heute hinter morgen", () => {
    const s = schatten("morgen", jetzt, gesternReihe, heuteReihe);
    expect(s?.wort).toBe("heute");
    expect(s?.start).toBe(heuteStart);
    expect(s?.kwh).toBeCloseTo(8, 3);
  });
  it("legt hinter gestern nichts", () => {
    expect(schatten("gestern", jetzt, gesternReihe, heuteReihe)).toBeNull();
  });
  it("bleibt aus, solange die Reihe fehlt", () => {
    expect(schatten("heute", jetzt, [], heuteReihe)).toBeNull();
  });
  // Am 26.10.2026 war gestern 25 Stunden lang. Die gleiche Uhrzeit ist dann nicht die gleiche
  // Zahl von Millisekunden seit Mitternacht.
  it("trifft die gleiche Uhrzeit auch nach der Zeitumstellung", () => {
    const nach = new Date("2026-10-26T12:00:00").getTime();
    const vortag = new Date("2026-10-25T00:00:00").getTime();
    const lang: Punkt[] = Array.from({ length: 181 }, (_, i) => ({ ts: vortag + 11 * 3600_000 + i * 60_000, pv: 2 }));
    const s = schatten("heute", nach, lang, heuteReihe);
    // Bis 12 Uhr Ortszeit ist eine Stunde der Reihe gelaufen, nicht zwei.
    expect(s?.kwh).toBeCloseTo(2, 3);
  });
});
