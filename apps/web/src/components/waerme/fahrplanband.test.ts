import { describe, expect, it } from "vitest";
import type { Plan } from "@/lib/api/models";
import { absicht, damalsFreigegeben, damalsWort, laufendeViertelstunde } from "./fahrplanband";

type Intervall = Plan["intervals"][number];

function viertel(ts: string, mehr: Partial<Intervall> = {}): Intervall {
  return { ts, expected_pv_kw: 0, planned_hp_state: "free", reason_code: "none", ...mehr } as Intervall;
}

const LAUFENDE = laufendeViertelstunde({ created_at: "2026-11-27T06:07:30Z" });

describe("der Streifen „Wärmepumpe geplant“", () => {
  it("rechnet die laufende Viertelstunde aus dem Zeitpunkt des Fahrplans", () => {
    expect(new Date(LAUFENDE).toISOString()).toBe("2026-11-27T06:00:00.000Z");
    expect(laufendeViertelstunde({ created_at: "2026-11-27T06:15:00Z" })).toBe(LAUFENDE + 900_000);
  });

  it("zeigt ab der laufenden Viertelstunde den Fahrplan von jetzt", () => {
    const laufende = viertel("2026-11-27T06:00:00Z", { planned_hp_state: "release", past_plan_hp_release: false });
    expect(absicht(laufende, LAUFENDE)).toEqual({ art: "jetzt", zustand: "release" });
    expect(damalsWort(absicht(laufende, LAUFENDE))).toBeNull();
  });

  it("zeigt davor die Absicht von damals und nicht die Regel von heute", () => {
    const ja = viertel("2026-11-27T04:00:00Z", { planned_hp_state: "avoid", past_plan_hp_release: true });
    const nein = viertel("2026-11-27T05:00:00Z", { planned_hp_state: "release", past_plan_hp_release: false });
    expect(absicht(ja, LAUFENDE)).toEqual({ art: "damals", freigabe: true });
    expect(absicht(nein, LAUFENDE)).toEqual({ art: "damals", freigabe: false });
    expect(damalsWort(absicht(ja, LAUFENDE))).toBe("angefordert");
    expect(damalsWort(absicht(nein, LAUFENDE))).toBe("nicht angefordert");
  });

  it("lässt die Stelle leer, wo das Archiv nichts weiß", () => {
    const stumm = viertel("2026-11-27T03:00:00Z", { planned_hp_state: "release" });
    expect(absicht(stumm, LAUFENDE)).toEqual({ art: "ohne" });
    expect(damalsWort(absicht(stumm, LAUFENDE))).toBe("ohne Vorgabe");
  });

  it("zählt die Freigaben von damals nur, wo das Archiv etwas weiß", () => {
    const gemessen = [
      viertel("2026-11-27T03:00:00Z", { past_plan_hp_release: true }),
      viertel("2026-11-27T03:15:00Z", { past_plan_hp_release: true }),
      viertel("2026-11-27T03:30:00Z", { past_plan_hp_release: false }),
      viertel("2026-11-27T03:45:00Z"),
    ];
    expect(damalsFreigegeben(gemessen)).toBe(2);
    expect(damalsFreigegeben([viertel("2026-11-27T03:45:00Z")])).toBeNull();
    expect(damalsFreigegeben([])).toBeNull();
  });
});
