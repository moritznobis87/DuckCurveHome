import { describe, expect, it } from "vitest";
import type { Plan } from "@/lib/api/models";
import { aussicht, bild, bogen, sonnenlauf } from "./ambiente";

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

describe("sonnenlauf", () => {
  it("findet Beginn und Ende der Erzeugung", () => {
    const l = sonnenlauf(planMitSonne(), uhr(12))!;
    expect(new Date(l.von).getHours()).toBe(9);
    // Die letzte Viertelstunde mit Erzeugung endet um 17 Uhr.
    expect(new Date(l.bis).getHours()).toBe(17);
  });
  it("gibt null an einem Tag ohne Erzeugung", () => {
    expect(sonnenlauf(nachts(), uhr(12))).toBeNull();
    expect(sonnenlauf(null, uhr(12))).toBeNull();
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
    const l = sonnenlauf(p, uhr(12));
    const ganz = aussicht(p, uhr(12), l);
    const spaet = aussicht(p, uhr(16), l);
    expect(ganz.erwartetKwh).toBeGreaterThan(19);
    expect(spaet.erwartetKwh).toBeCloseTo(ganz.erwartetKwh!, 6);
    expect(spaet.restKwh!).toBeLessThan(ganz.restKwh!);
    expect(new Date(ganz.bis!).getHours()).toBe(17);
  });
});

describe("bogen", () => {
  const lauf = sonnenlauf(planMitSonne(), uhr(12));
  it("zeichnet die Linie über die ganze Breite", () => {
    const b = bogen(lauf, uhr(12), 300, 60)!;
    expect(b.linie.startsWith("M0.0 ")).toBe(true);
    expect(b.linie).toContain("300.0 ");
  });
  it("füllt bis zur Marke jetzt", () => {
    const b = bogen(lauf, uhr(12), 300, 60)!;
    expect(b.jetztX).toBeGreaterThan(0);
    expect(b.jetztX).toBeLessThan(300);
    // Die Fläche endet an der Marke und läuft auf der Grundlinie zurück.
    expect(b.flaeche).toContain(" 60 L");
    expect(b.flaeche.endsWith("Z")).toBe(true);
    // Die Linie bis jetzt ist ein eigener Pfad, ohne Grundlinie.
    expect(b.bisJetzt.startsWith("M")).toBe(true);
    expect(b.bisJetzt).not.toContain("Z");
  });
  it("hat vor Sonnenaufgang keine Marke und keine Fläche", () => {
    const b = bogen(lauf, uhr(5), 300, 60)!;
    expect(b.jetztX).toBeNull();
    expect(b.flaeche).toBe("");
    expect(b.bisJetzt).toBe("");
  });
  it("bleibt aus, solange kein Sonnenlauf da ist", () => {
    expect(bogen(null, uhr(12))).toBeNull();
  });
});
