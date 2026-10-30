import { describe, expect, it } from "vitest";
import type { HousePlan, Measurement, RoomLive } from "@/lib/api/models";
import type { HistoryPoint } from "@/lib/live/store";
import type { HausLive } from "./live";
import { anDerGrenze, dauerText, kontaktOrt, kontaktZeilen, kreisZeilen, methodeText, raumOrt, schichtZeilen, seitText, sparkPfade, statusWort, tagesLauf, verdichte } from "./insights";

const plan = {
  version: 1,
  name: "Probe",
  decks: [
    {
      key: "eg",
      name: "Erdgeschoss",
      shell: [[0, 0], [10, 0], [10, 8], [0, 8]],
      rooms: [
        { name: "Wohnen", room_id: 3, x0: 0, z0: 0, x1: 6, z1: 8 },
        { name: "Wohnen", part_of: "Wohnen", x0: 6, z0: 0, x1: 7, z1: 2 },
      ],
      contacts: [
        { name: "Terrassentür", key: "k_terrasse", room: "Wohnen", side: "n", at: 0, a: 1, b: 2, door: true },
        { name: "Fenster", key: "k_fenster", room: "Wohnen", side: "n", at: 0, a: 3, b: 4, door: false },
        { name: "Kellertür", key: "k_keller", side: "s", at: 8, a: 1, b: 2, door: true },
      ],
    },
    { key: "og", name: "Obergeschoss", shell: [[0, 0], [10, 0], [10, 8], [0, 8]], rooms: [{ name: "Schlafen", room_id: 4, x0: 0, z0: 0, x1: 10, z1: 8 }] },
  ],
} as unknown as HousePlan;

const live = (eintraege: [string, boolean | null][]): HausLive =>
  ({
    raeume: new Map(),
    kontakte: new Map(eintraege.map(([key, open]) => [key, { key, name: key, room: null, door: false, open, observed_at: null, quality: "ok" }])),
  }) as unknown as HausLive;

describe("Orte im Plan", () => {
  it("findet einen Raum ueber seine Kennung, ohne auf Teilstuecke hereinzufallen", () => {
    expect(raumOrt(plan, 3)).toEqual({ deck: "eg", raum: "Wohnen" });
    expect(raumOrt(plan, 4)).toEqual({ deck: "og", raum: "Schlafen" });
    expect(raumOrt(plan, 99)).toBeNull();
    expect(raumOrt(null, 3)).toBeNull();
  });

  it("findet den Raum eines Kontakts, und keinen, wo keiner steht", () => {
    expect(kontaktOrt(plan, "k_terrasse")).toEqual({ deck: "eg", raum: "Wohnen" });
    expect(kontaktOrt(plan, "k_keller")).toBeNull();
    expect(kontaktOrt(plan, "gibt_es_nicht")).toBeNull();
  });
});

describe("Fenster und Tueren", () => {
  it("stellt offene nach vorn, Tueren vor Fenster, stumme nach hinten", () => {
    const zeilen = kontaktZeilen(plan, live([["k_fenster", true], ["k_terrasse", true], ["k_keller", false]]));
    expect(zeilen.map((z) => z.key)).toEqual(["k_terrasse", "k_fenster", "k_keller"]);
    const stumm = kontaktZeilen(plan, live([["k_fenster", false], ["k_terrasse", false]]));
    expect(stumm.map((z) => z.key)).toEqual(["k_terrasse", "k_fenster", "k_keller"]);
    expect(stumm[2]!.offen).toBeNull();
  });

  it("nennt je Kontakt seinen Raum, soweit er einen hat", () => {
    const zeilen = kontaktZeilen(plan, live([]));
    expect(zeilen.find((z) => z.key === "k_terrasse")?.ort).toEqual({ deck: "eg", raum: "Wohnen" });
    expect(zeilen.find((z) => z.key === "k_keller")?.ort).toBeNull();
  });

  it("haelt einen fehlenden Plan aus", () => {
    expect(kontaktZeilen(null, live([]))).toEqual([]);
  });
});

describe("Heizkreise", () => {
  const raum = (id: number, name: string, valve: number, dev: number): RoomLive =>
    ({ id, name, floor: "Erdgeschoss", circuits: 4, valve, temp_c: 20, setpoint_c: 21, target_c: 21, deviation_k: dev }) as RoomLive;

  it("zeigt nur offene Kreise, den weitesten zuerst", () => {
    const zeilen = kreisZeilen([raum(3, "Wohnen", 0.5, 0), raum(4, "Schlafen", 1, -1), raum(5, "Bad", 0, 0)], plan);
    expect(zeilen.map((z) => z.name)).toEqual(["Schlafen", "Wohnen"]);
    expect(zeilen[0]!.ort).toEqual({ deck: "og", raum: "Schlafen" });
  });

  it("nennt den Raum an der Grenze: Kreise ganz offen und trotzdem zu kalt", () => {
    const zeilen = kreisZeilen([raum(4, "Schlafen", 1, -1.2), raum(3, "Wohnen", 1, 0.2)], plan);
    expect(anDerGrenze(zeilen)?.name).toBe("Schlafen");
    expect(anDerGrenze(kreisZeilen([raum(3, "Wohnen", 0.5, -2)], plan))).toBeNull();
  });
});

describe("Puffer", () => {
  const m = (value: number | null, quality = "ok"): Measurement => ({ value, observed_at: "2026-10-30T08:00:00Z", quality, source: "t" }) as Measurement;

  it("benennt die vier Schichten von oben nach unten und merkt sich, was alt ist", () => {
    const zeilen = schichtZeilen([m(52), m(48), m(44), m(39, "stale")]);
    expect(zeilen.map((z) => z.name)).toEqual(["oben", "Mitte oben", "Mitte unten", "unten"]);
    expect(zeilen[0]!.frisch).toBe(true);
    expect(zeilen[3]!.frisch).toBe(false);
  });

  it("sagt den Zustand und die Rechnung in Worten", () => {
    expect(statusWort("full")).toBe("voll");
    expect(statusWort(undefined)).toBe("unbekannt");
    expect(methodeText("layered_energy_v1")).toContain("Schichtenmodell");
    expect(methodeText("")).toBe("");
    expect(methodeText("etwas_neues")).toBe("etwas_neues");
  });
});

describe("Waermepumpe", () => {
  const punkt = (hp: number | null): HistoryPoint => ({ ts: 0, pv: null, house: null, hp, ev: null, grid: null, battery: null, price: null, k1: null });

  it("rechnet Arbeit, Laufzeit und Spitze aus dem Minutenraster", () => {
    const lauf = tagesLauf([punkt(3), punkt(3), punkt(0), punkt(null), punkt(1.5)]);
    expect(lauf.kwh).toBeCloseTo((3 + 3 + 0 + 1.5) / 60);
    expect(lauf.minuten).toBe(3);
    expect(lauf.max).toBe(3);
    expect(tagesLauf([])).toEqual({ kwh: 0, minuten: 0, max: 0 });
  });

  it("sagt Dauern so, wie man sie sagt", () => {
    expect(dauerText(42)).toBe("42 min");
    expect(dauerText(60)).toBe("1 h");
    expect(dauerText(190)).toBe("3 h 10 min");
    expect(dauerText(-5)).toBe("0 min");
  });

  it("rechnet aus einem Zeitpunkt, wie lange es her ist", () => {
    const now = Date.parse("2026-10-30T10:00:00Z");
    expect(seitText("2026-10-30T09:18:00Z", now)).toBe("42 min");
    expect(seitText(null, now)).toBeNull();
    expect(seitText("2026-10-30T11:00:00Z", now)).toBeNull();
  });
});

describe("Kurve", () => {
  it("zeichnet je zusammenhaengendem Stueck einen Pfad", () => {
    const pfade = sparkPfade([1, 2, null, 2, 1], 100, 20, 2);
    expect(pfade).toHaveLength(2);
    expect(pfade[0]!.startsWith("M 0.0")).toBe(true);
    expect(sparkPfade([1], 100, 20, 2)).toEqual([]);
    expect(sparkPfade([1, 2], 100, 20, 0)).toEqual([]);
  });

  it("verdichtet lange Reihen und laesst leere Fenster leer", () => {
    const aus = verdichte([1, 3, null, null, 5, 5], 3);
    expect(aus).toEqual([2, null, 5]);
    expect(verdichte([1, 2], 5)).toEqual([1, 2]);
  });
});
