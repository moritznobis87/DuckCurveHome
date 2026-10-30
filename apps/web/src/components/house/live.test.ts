import { describe, expect, it } from "vitest";
import type { House, HouseContact, LiveState, RoomLive } from "@/lib/api/models";
import { alarmStufe, hausLive, offeneKontakte, offenSatz } from "./live";

const kontakt = (key: string, open: boolean | null, door = false): HouseContact => ({ key, name: key, room: null, door, open, observed_at: null, quality: open == null ? "unavailable" : "ok" });

describe("Alarmstufe", () => {
  it("uebersetzt die Zahl der Anlage", () => {
    expect(alarmStufe(0)).toBe("unscharf");
    expect(alarmStufe(1)).toBe("zuhause");
    expect(alarmStufe(2)).toBe("unterwegs");
    expect(alarmStufe(3)).toBe("schaltet");
    expect(alarmStufe(4)).toBe("ausgeloest");
    expect(alarmStufe(null)).toBe("unbekannt");
  });
});

describe("Das Bild des Augenblicks", () => {
  it("legt Raeume, Kontakte und Zustand zusammen", () => {
    const rooms = [{ id: 3, valve: 0.5 } as RoomLive, { id: 4, valve: 0 } as RoomLive];
    const house = { contacts: [kontakt("a", true), kontakt("b", null)] } as House;
    const state = {
      alarm: { present: true, state: 1, state_de: "zu Hause scharf", can_arm: true, observed_at: null },
      buffer: { soc: 0.54 },
      stove: { present: true, running: true },
      snapshot: {
        buffer_temps_c: { top: { value: 52 }, mid_top: { value: 48 }, mid_bottom: { value: 44 }, bottom: { value: null } },
        heat_pump_power_kw: { value: 1.6 },
        ev_power_kw: { value: 7.4 },
      },
    } as unknown as LiveState;
    const live = hausLive(rooms, house, state);
    expect(live.raeume.get(3)?.valve).toBe(0.5);
    expect(live.kontakte.get("a")?.open).toBe(true);
    expect(live.alarm).toBe("zuhause");
    expect(live.pufferSoc).toBe(0.54);
    expect(live.pufferTemps).toEqual([52, 48, 44, null]);
    expect(live.waermepumpeKw).toBe(1.6);
    expect(live.wallboxKw).toBe(7.4);
    expect(live.ofenLaeuft).toBe(true);
    expect(live.kreiseOffen).toBe(1);
  });

  it("haelt leere Quellen aus", () => {
    const live = hausLive(null, null, null);
    expect(live.raeume.size).toBe(0);
    expect(live.alarm).toBe("unbekannt");
    expect(live.alarmSatz).toBe("nicht eingerichtet");
    expect(live.pufferTemps).toEqual([]);
  });
});

describe("Offene Kontakte", () => {
  it("nennt Tueren zuerst und zaehlt den Rest", () => {
    const offen = offeneKontakte([kontakt("fenster", true), kontakt("tuer", true, true), kontakt("zu", false), kontakt("stumm", null)]);
    expect(offen.map((k) => k.key)).toEqual(["tuer", "fenster"]);
    expect(offenSatz(offen, 4)).toBe("tuer und 1 weitere");
    expect(offenSatz([], 4)).toBe("alles zu");
    expect(offenSatz([], 0)).toBe("keine Kontakte im Plan");
  });
});
