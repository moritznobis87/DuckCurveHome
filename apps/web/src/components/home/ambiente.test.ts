import { describe, expect, it } from "vitest";
import type { Plan } from "@/lib/api/models";
import { aussicht, bild, naechsterAufgang, sonnenlauf } from "./ambiente";
import { ausblick } from "./ausblick";
import { sonnenanteil } from "./buehne";

const tag = new Date("2026-10-23T00:00:00").getTime();
/** Ein Fahrplan mit einem Dreieck Sonne von 9 bis 17 Uhr, Viertelstundenraster. */
const planMitSonne = (): Plan => {
  const intervals = Array.from({ length: 96 }, (_, i) => {
    const h = i / 4;
    const kw = h >= 9 && h <= 17 ? Math.max(0, 4 - Math.abs(h - 13) * 0.8) : 0;
    return { ts: new Date(tag + i * 15 * 60_000).toISOString(), expected_pv_kw: kw, price_ct_kwh: 20 };
  });
  return { intervals } as unknown as Plan;
};
const nachts = (): Plan =>
  ({ intervals: Array.from({ length: 96 }, (_, i) => ({ ts: new Date(tag + i * 15 * 60_000).toISOString(), expected_pv_kw: 0, price_ct_kwh: 20 })) }) as unknown as Plan;

const uhr = (h: number, m = 0) => tag + h * 3600_000 + m * 60_000;
const iso = (ms: number) => new Date(ms).toISOString();
/** Derselbe Fahrplan, dazu Aufgang und Untergang für heute und morgen, wie der Dienst sie rechnet. */
const mitSonnenzeiten = (plan: Plan): Plan =>
  ({
    ...plan,
    sun: [
      { day: "2026-10-23", sunrise: iso(uhr(8, 9)), sunset: iso(uhr(16, 36)) },
      { day: "2026-10-24", sunrise: iso(uhr(24 + 8, 11)), sunset: iso(uhr(24 + 16, 35)) },
    ],
  }) as unknown as Plan;

describe("sonnenlauf", () => {
  it("nimmt Aufgang und Untergang, die der Fahrplan mitbringt", () => {
    const l = sonnenlauf(mitSonnenzeiten(planMitSonne()), uhr(12))!;
    expect(l.von).toBe(uhr(8, 9));
    expect(l.bis).toBe(uhr(16, 36));
  });
  it("hängt nicht an der Ertragsprognose: auch ein Tag ohne erwartete Erzeugung hat einen Sonnenlauf", () => {
    expect(sonnenlauf(mitSonnenzeiten(nachts()), uhr(12))).toEqual({ von: uhr(8, 9), bis: uhr(16, 36) });
  });
  it("stellt die Sonne dorthin, wo sie steht, und nicht an den Beginn der Erzeugung", () => {
    // Der Fall vom 26.11.2026: Aufgang um 08:09, Erzeugung laut Prognose erst ab 09 Uhr. Um
    // 09:17 ist ein gutes Achtel des Tages vorbei; aus der Prognose gelesen war es ein Dreißigstel.
    const l = sonnenlauf(mitSonnenzeiten(planMitSonne()), uhr(9, 17));
    expect(sonnenanteil(l, uhr(9, 17))).toBeCloseTo(68 / 507, 6);
    expect(sonnenanteil(sonnenlauf(planMitSonne(), uhr(9, 17)), uhr(9, 17))).toBeCloseTo(17 / 495, 6);
  });
  it("fällt ohne Sonnenzeiten auf Beginn und Ende der Erzeugung zurück", () => {
    const l = sonnenlauf(planMitSonne(), uhr(12))!;
    expect(new Date(l.von).getHours()).toBe(9);
    // Die letzte Viertelstunde mit Erzeugung endet um 17 Uhr.
    expect(new Date(l.bis).getHours()).toBe(17);
  });
  it("gibt null, wenn der Fahrplan weder Sonnenzeiten noch Erzeugung kennt", () => {
    expect(sonnenlauf(nachts(), uhr(12))).toBeNull();
    expect(sonnenlauf(null, uhr(12))).toBeNull();
  });
});

describe("naechsterAufgang", () => {
  const plan = mitSonnenzeiten(planMitSonne());
  it("nennt vor dem Aufgang den von heute und danach den von morgen", () => {
    expect(naechsterAufgang(plan, uhr(5), ausblick(plan, uhr(5)))).toBe(uhr(8, 9));
    expect(naechsterAufgang(plan, uhr(21), ausblick(plan, uhr(21)))).toBe(uhr(24 + 8, 11));
  });
  it("nimmt ohne Sonnenzeiten den Beginn der Erzeugung aus dem Ausblick", () => {
    const ohne = planMitSonne();
    expect(naechsterAufgang(ohne, uhr(5), ausblick(ohne, uhr(5)))).toBe(uhr(9));
  });
  it("gibt null, wenn nichts bekannt ist", () => {
    expect(naechsterAufgang(null, uhr(5), ausblick(null, uhr(5)))).toBeNull();
  });
});

describe("bild", () => {
  const lauf = sonnenlauf(planMitSonne(), uhr(12));
  it("zeigt am Tag die Sonne", () => {
    expect(bild(lauf, uhr(12), 2.4)).toBe("tag");
    // Eine Wolke um 13 Uhr ist kein Abend.
    expect(bild(lauf, uhr(13), 0)).toBe("tag");
  });
  it("zeigt abends den Preis und den Puffer", () => {
    expect(bild(lauf, uhr(21), 0)).toBe("abend");
    expect(bild(lauf, uhr(6), 0)).toBe("abend");
  });
  it("bleibt beim Tag, wenn die Anlage liefert und die Prognose nichts wusste", () => {
    expect(bild(null, uhr(12), 1.8)).toBe("tag");
    expect(bild(null, uhr(12), 0.1)).toBe("abend");
  });
});

describe("aussicht", () => {
  it("rechnet den ganzen Tag und den Rest ab jetzt", () => {
    const p = planMitSonne();
    const ganz = aussicht(p, uhr(12));
    const spaet = aussicht(p, uhr(16));
    expect(ganz.erwartetKwh).toBeGreaterThan(19);
    expect(spaet.erwartetKwh).toBeCloseTo(ganz.erwartetKwh!, 6);
    expect(spaet.restKwh!).toBeLessThan(ganz.restKwh!);
  });
});
