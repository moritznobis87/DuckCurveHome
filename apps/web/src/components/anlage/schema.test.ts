import { describe, expect, it } from "vitest";
import { AREAS } from "@/lib/areas";
import {
  batterieWort,
  dauerText,
  de,
  erzeugerSatz,
  farbe,
  FARBE,
  grad,
  heizungStatus,
  istAn,
  mischung,
  nettoFarbe,
  nettoText,
  netzWort,
  ofenStatus,
  partikelZahl,
  rohrDauer,
  warmwasserStatus,
  ZIELE,
} from "./schema";

const T = Date.UTC(2026, 10, 2, 18, 0);

describe("farbe", () => {
  it("klemmt an den Enden der Skala", () => {
    expect(farbe(0)).toBe(farbe(10));
    expect(farbe(90)).toBe(farbe(65));
  });
  it("liegt zwischen zwei Stützstellen dazwischen", () => {
    expect(farbe(40)).toBe("rgb(191,189,150)");
  });
  it("ist ohne Wert das neutrale Blaugrau", () => {
    expect(farbe(null)).toBe(FARBE.netz);
  });
});

describe("Zahlen und Worte", () => {
  it("schreibt deutsch und ohne Vorzeichen", () => {
    expect(de(-1.25)).toBe("1,3");
    expect(de(null)).toBe("-");
    expect(grad(46.6)).toBe("47 °");
  });
  it("kennt die Richtung von Netz und Batterie", () => {
    expect(netzWort(3.4)).toBe("Bezug");
    expect(netzWort(-1.1)).toBe("Einspeisung");
    expect(netzWort(0.01)).toBe("ruht");
    // Batterie positiv ist Entladung.
    expect(batterieWort(1.2)).toBe("entlädt");
    expect(batterieWort(-1.2)).toBe("lädt");
  });
  it("unterscheidet an und aus an einer Schwelle", () => {
    expect(istAn(0.04)).toBe(false);
    expect(istAn(-0.05)).toBe(true);
    expect(istAn(null)).toBe(false);
  });
});

describe("Tempo der Lichtpunkte", () => {
  it("wird mit der Leistung schneller, in Grenzen, auf halbe Sekunden", () => {
    expect(rohrDauer(0.5)).toBe(9);
    expect(rohrDauer(20)).toBe(2.5);
    expect(rohrDauer(4)).toBe(4);
    expect(rohrDauer(4, true)).toBe(5);
  });
  it("hat zwischen zwei und sieben Punkten", () => {
    expect(partikelZahl(0.1)).toBe(2);
    expect(partikelZahl(9)).toBe(7);
    expect(partikelZahl(9, true)).toBe(6);
  });
});

describe("mischung", () => {
  it("verteilt sechs Punkte nach Anteilen und verschränkt sie", () => {
    const m = mischung({ share_pv: 0, share_grid: 0.74, share_battery: 0.26 });
    expect(m.farben).toHaveLength(6);
    expect(m.farben!.filter((f) => f === FARBE.netz)).toHaveLength(4);
    expect(m.farben!.filter((f) => f === FARBE.speicher)).toHaveLength(2);
    // Nicht blockweise: die beiden Speicherpunkte stehen nicht nebeneinander.
    const idx = m.farben!.map((f, i) => (f === FARBE.speicher ? i : -1)).filter((i) => i >= 0);
    expect(Math.abs((idx[0] ?? 0) - (idx[1] ?? 0))).toBeGreaterThan(1);
    expect(m.haupt).toBe(FARBE.netz);
    expect(m.text).toBe("Netz 74\u00a0%, Speicher 26\u00a0%");
  });
  it("lässt kleine Anteile aus dem Satz", () => {
    expect(mischung({ share_pv: 0.97, share_grid: 0.03, share_battery: 0 }).text).toBe("PV 97\u00a0%");
  });
  it("ist ohne Quellen leer", () => {
    const m = mischung({ share_pv: 0, share_grid: 0, share_battery: 0 });
    expect(m.farben).toBeNull();
    expect(m.text).toBe("");
  });
});

describe("Dauer", () => {
  it("zählt Minuten und Stunden", () => {
    expect(dauerText(new Date(T - 38 * 60000).toISOString(), T)).toBe("38 min");
    expect(dauerText(new Date(T - 72 * 60000).toISOString(), T)).toBe("1 h 12 min");
    expect(dauerText(new Date(T - 120 * 60000).toISOString(), T)).toBe("2 h");
    expect(dauerText(null, T)).toBe("");
  });
});

describe("Sätze", () => {
  it("nennt den Erzeuger, der läuft", () => {
    const wp = { running: true, running_since: new Date(T - 72 * 60000).toISOString(), power_kw: 2.8, thermal_kw: null, flow_c: null, cop: null };
    const ofenAus = { present: true, running: false, power_level: null, flow_c: null, return_c: null, pump_pct: null, water_kw: 0 };
    expect(erzeugerSatz({ waermepumpe: wp, ofen: ofenAus }, T)).toBe("Wärmepumpe läuft seit 1 h 12 min");
    const wpAus = { ...wp, running: false, running_since: null };
    expect(erzeugerSatz({ waermepumpe: wpAus, ofen: { ...ofenAus, running: true, power_level: 4 } }, T)).toBe("Ofen auf Stufe 4");
    expect(erzeugerSatz({ waermepumpe: wpAus, ofen: ofenAus }, T)).toBe("alle Erzeuger stehen");
  });
  it("sagt beim Speicher, was er tut", () => {
    expect(nettoText({ net_kw: 1.2, net_word: "lädt" })).toBe("lädt 1,2 kW");
    expect(nettoText({ net_kw: -3.4, net_word: "entlädt" })).toBe("entlädt 3,4 kW");
    expect(nettoText({ net_kw: 0.05, net_word: "hält" })).toBe("hält");
    expect(nettoText({ net_kw: null, net_word: "" })).toBe("");
    expect(nettoFarbe({ net_kw: 1.2, net_word: "lädt" })).toBe(FARBE.pvSoft);
  });
  it("sagt ehrlich, was fehlt", () => {
    expect(ofenStatus({ present: false, running: null, power_level: null, flow_c: null, return_c: null, pump_pct: null, water_kw: null })).toBe("nicht angebunden");
    expect(ofenStatus({ present: true, running: null, power_level: null, flow_c: null, return_c: null, pump_pct: null, water_kw: null })).toBe("keine Verbindung");
    expect(ofenStatus({ present: true, running: true, power_level: 4, flow_c: 68, return_c: 52, pump_pct: 85, water_kw: 7.2 })).toBe("Stufe 4 · Pumpe 85 %");
    expect(warmwasserStatus({ present: false, outlet_c: null, inlet_c: null, tapping: null, tapping_since: null }, T)).toBe("kein Fühler am Auslass");
    expect(warmwasserStatus({ present: true, outlet_c: 47, inlet_c: null, tapping: true, tapping_since: new Date(T - 2 * 60000).toISOString() }, T)).toBe("Zapfung seit 2 min · Auslass");
    expect(warmwasserStatus({ present: true, outlet_c: 27, inlet_c: null, tapping: false, tapping_since: null }, T)).toBe("ruht · Auslass kühlt ab");
    expect(heizungStatus({ rooms_total: 0, rooms_open: 0, open_share: null, running: false })).toBe("keine Räume gemeldet");
    expect(heizungStatus({ rooms_total: 9, rooms_open: 7, open_share: 0.6, running: true })).toBe("Räume nehmen Wärme");
  });
});

describe("Ziele der Symbole", () => {
  const reiter = new Set(AREAS.flatMap((a) => a.tabs.map((t) => t.href)));
  it("führen alle auf einen Reiter, den es gibt", () => {
    for (const z of Object.values(ZIELE)) {
      expect(reiter.has(z.href.split("#")[0] ?? "")).toBe(true);
    }
  });
  it("sind dieselben wie auf der Startseite", () => {
    expect(ZIELE.pv.href).toBe("/strom/pv");
    expect(ZIELE.netz.href).toBe("/strom");
    expect(ZIELE.bat.href).toBe("/strom/speicher");
    expect(ZIELE.wp.href.startsWith("/waerme")).toBe(true);
  });
});
