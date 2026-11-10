import { describe, expect, it } from "vitest";
import type { Plan } from "@/lib/api/models";
import { abschnitte, ausblick, FENSTER_ZELLEN, SCHRITT_MS, ZELLEN } from "./ausblick";

const T0 = Date.UTC(2026, 10, 10, 19, 0); // 20:00 im Haus

type Halb = { preis?: number | null; pv?: number; wp?: boolean; ofen?: boolean; regel?: boolean };

/** Ein Fahrplan ab T0 in Viertelstunden. `f` sagt je Zelle, was dort gilt. */
function plan(n: number, f: (i: number) => Halb, ab = T0): Plan {
  return {
    intervals: Array.from({ length: n }, (_, i) => {
      const z = f(i);
      return {
        ts: new Date(ab + i * SCHRITT_MS).toISOString(),
        expected_pv_kw: z.pv ?? 0,
        price_ct_kwh: z.preis === undefined ? 30 : z.preis,
        planned_hp_state: z.wp ? "release" : "off",
        planned_stove_on: z.ofen ?? null,
        reason_code: z.regel ? "price_rule" : "planned_optimizer",
      };
    }),
  } as unknown as Plan;
}

describe("ausblick", () => {
  it("reicht 24 Stunden und beginnt mit der laufenden Viertelstunde", () => {
    const a = ausblick(plan(200, () => ({})), T0 + 7 * 60_000);
    expect(a.zellen).toHaveLength(ZELLEN);
    expect(a.zellen[0]!.ts).toBe(T0);
    const spaeter = ausblick(plan(200, () => ({}), T0 - 4 * SCHRITT_MS), T0 + 7 * 60_000);
    expect(spaeter.zellen[0]!.ts).toBe(T0);
  });

  it("nennt den jetzigen Preis teuer, günstig oder mittel, gemessen an den nächsten 24 Stunden", () => {
    const teuer = ausblick(plan(96, (i) => ({ preis: i === 0 ? 45 : 20 + (i % 10) })), T0);
    expect(teuer.preisJetzt).toBe(45);
    expect(teuer.lage).toBe("teuer");
    expect(teuer.preisMin).toBe(20);
    expect(teuer.preisMax).toBe(45);
    const guenstig = ausblick(plan(96, (i) => ({ preis: i === 0 ? 12 : 20 + (i % 10) })), T0);
    expect(guenstig.lage).toBe("günstig");
    const mittel = ausblick(plan(96, (i) => ({ preis: i === 0 ? 25 : 20 + (i % 10) })), T0);
    expect(mittel.lage).toBe("mittel");
  });

  it("sagt gleichmäßig und nennt kein Preisfenster, wenn die Preise kaum auseinanderliegen", () => {
    const a = ausblick(plan(96, (i) => ({ preis: 30 + (i % 3) })), T0);
    expect(a.lage).toBe("gleichmäßig");
    expect(a.guenstig).toBeNull();
  });

  it("findet die günstigsten zwei Stunden am Stück", () => {
    // Zellen 16 bis 23 kosten 18 ct, alles andere 35: das Fenster ist genau dort.
    const a = ausblick(plan(96, (i) => ({ preis: i >= 16 && i < 24 ? 18 : 35 })), T0);
    expect(a.guenstig).toEqual({ start: T0 + 16 * SCHRITT_MS, end: T0 + 24 * SCHRITT_MS, mittel: 18 });
    expect((a.guenstig!.end - a.guenstig!.start) / SCHRITT_MS).toBe(FENSTER_ZELLEN);
  });

  it("legt kein Preisfenster über Stunden ohne Preis", () => {
    // Ab Zelle 20 fehlt der Preis; das billige Stück davor ist nur vier Zellen lang.
    const a = ausblick(plan(96, (i) => ({ preis: i >= 20 ? null : i >= 16 ? 5 : 35 })), T0);
    expect(a.guenstig!.start).toBe(T0 + 12 * SCHRITT_MS);
    expect(a.preiseBis).toBe(T0 + 20 * SCHRITT_MS);
    const voll = ausblick(plan(96, () => ({})), T0);
    expect(voll.preiseBis).toBeNull();
  });

  it("nennt das Sonnenfenster nur, wenn die Sonne dafür reicht", () => {
    const berg = (i: number) => Math.max(0, 3 - Math.abs(i - 64) * 0.2);
    const sonnig = ausblick(plan(96, (i) => ({ pv: berg(i) })), T0);
    expect(sonnig.sonne!.start).toBe(T0 + 60 * SCHRITT_MS);
    expect(sonnig.pvMax).toBe(3);
    const trueb = ausblick(plan(96, (i) => ({ pv: berg(i) * 0.2 })), T0);
    expect(trueb.sonne).toBeNull();
  });

  it("weiß, ob es dunkel ist, und wann die Sonne wiederkommt oder geht", () => {
    const nachts = ausblick(plan(96, (i) => ({ pv: i >= 44 && i < 80 ? 1.5 : 0 })), T0);
    expect(nachts.nacht).toBe(true);
    expect(nachts.sonneWechsel).toBe(T0 + 44 * SCHRITT_MS);
    const tags = ausblick(plan(96, (i) => ({ pv: i < 12 ? 1.5 : 0 })), T0);
    expect(tags.nacht).toBe(false);
    expect(tags.sonneWechsel).toBe(T0 + 12 * SCHRITT_MS);
    const dunkel = ausblick(plan(96, () => ({ pv: 0 })), T0);
    expect(dunkel.nacht).toBe(true);
    expect(dunkel.sonneWechsel).toBeNull();
  });

  it("zählt als geplanten Lauf nur, was der Optimierer geplant hat", () => {
    const a = ausblick(plan(96, (i) => ({ wp: i >= 8 && i < 12, regel: i >= 10 })), T0);
    expect(abschnitte(a.zellen, (z) => z.wp)).toEqual([[8, 10]]);
  });

  it("bleibt ohne Fahrplan leer, ohne zu raten", () => {
    const a = ausblick(null, T0);
    expect(a.zellen).toEqual([]);
    expect(a.lage).toBeNull();
    expect(a.guenstig).toBeNull();
    expect(a.sonne).toBeNull();
    expect(a.nacht).toBe(false);
  });
});

describe("abschnitte", () => {
  it("fasst aufeinanderfolgende Zellen zusammen, auch bis zum Ende", () => {
    const a = ausblick(plan(12, (i) => ({ ofen: i < 2 || i >= 9 })), T0);
    expect(abschnitte(a.zellen, (z) => z.ofen)).toEqual([
      [0, 2],
      [9, 12],
    ]);
  });
});
