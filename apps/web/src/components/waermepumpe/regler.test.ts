import { describe, expect, it } from "vitest";
import type { ReglerEinstellung } from "@/lib/api/models";
import { aenderungen, anteil, bedienbar, gelesen, gruppen, kurveAus, kurvenPunkte, raster, sichtbar, sperre, standText, steilheitDurch, verschiebungDurch, vorlauf, vorlaufFrei, wertBei, wertText, zahlText } from "./regler";

type Teil = Partial<ReglerEinstellung> & { v?: number | null; quality?: string };
const wert = (teil: Teil = {}): ReglerEinstellung => {
  const { v = 0.7, quality = "ok", ...rest } = teil;
  return {
    schluessel: "heat_pump_set_slope",
    name_de: "Steilheit",
    gruppe_de: "Heizkurve",
    kennung: "6a71",
    einheit: "",
    stellen: 2,
    lesart_de: null,
    art: "zahl",
    stellbar: true,
    von: 0.2,
    bis: 3.5,
    schritt: 0.1,
    wahl: {},
    bestaetigt: true,
    muster: false,
    hinweis_de: "",
    gesendet: null,
    wert: { value: v, observed_at: "2026-11-15T09:30:00Z", quality, source: "mqtt:ebusd" } as ReglerEinstellung["wert"],
    ...rest,
  };
};

const kurve = [
  wert(),
  wert({ schluessel: "heat_pump_set_offset_k", name_de: "Verschiebung", einheit: "K", stellen: 1, von: -7, bis: 7, schritt: 0.5, v: 0 }),
  wert({ schluessel: "heat_pump_set_room_day_c", name_de: "Raumtemperatur Tag", einheit: "°C", stellen: 1, von: 10, bis: 30, schritt: 0.5, v: 21 }),
  wert({ schluessel: "heat_pump_set_flow_min_c", name_de: "Vorlauf mindestens", einheit: "°C", stellen: 1, von: 20, bis: 45, schritt: 1, v: 20 }),
  wert({ schluessel: "heat_pump_set_flow_max_c", name_de: "Vorlauf höchstens", einheit: "°C", stellen: 1, von: 25, bis: 60, schritt: 1, v: 55 }),
];

describe("die Einstellungen des Reglers lesen", () => {
  it("ordnet nach Gruppen, in der Reihenfolge des Dienstes", () => {
    const g = gruppen([wert(), wert({ gruppe_de: "Warmwasser", name_de: "Komforttemperatur" }), wert({ name_de: "Verschiebung" })]);
    expect(g.map((x) => [x.name, x.werte.length])).toEqual([["Heizkurve", 2], ["Warmwasser", 1]]);
  });

  it("schreibt den Wert, wie er am Bediengerät steht", () => {
    expect(wertText(wert({ v: 1.2 }))).toBe("1,20");
    expect(wertText(wert({ v: 55, einheit: "°C", stellen: 1 }))).toBe("55,0 °C");
    expect(zahlText(wert({ einheit: "K", stellen: 1 }), -2)).toBe("−2,0 K");
    expect(zahlText(wert({ einheit: "K", stellen: 1 }), 1.5)).toBe("+1,5 K");
    expect(wertText(wert({ v: 2, stellen: 0 }))).toBe("2");
  });

  it("zeigt null als Einstellung und Fehlendes als Fragezeichen", () => {
    expect(wertText(wert({ v: 0, einheit: "K", stellen: 1 }))).toBe("0,0 K");
    expect(wertText(wert({ v: null, quality: "unavailable" }))).toBe("?");
    expect(wertText(wert({ quality: "stale" }))).toBe("?");
    expect(gelesen(wert({ quality: "stale" }))).toBe(false);
    expect(standText(wert({ quality: "stale" }))).toBe("nicht gelesen");
    expect(standText(wert())).toBe("10:30");
  });
});

describe("die Einstellungen des Reglers stellen", () => {
  it("lässt nur bewegen, was stellbar, gelesen und verglichen ist, und wenn der Dienst stellen kann", () => {
    expect(bedienbar(wert(), true)).toBe(true);
    expect(sperre(wert({ stellbar: false }), true)).toBe("nur lesen");
    expect(sperre(wert({ quality: "stale" }), true)).toBe("nicht gelesen");
    expect(sperre(wert({ bestaetigt: false }), true)).toBe("nicht verglichen");
    expect(sperre(wert(), false)).toBe("Stellen nicht möglich");
  });

  it("hält Werte auf dem Raster und in den Grenzen", () => {
    expect(raster(wert(), 0.84)).toBe(0.8);
    expect(raster(wert(), 9)).toBe(3.5);
    expect(raster(wert(), -1)).toBe(0.2);
    const versch = wert({ von: -7, bis: 7, schritt: 0.5 });
    expect(raster(versch, -2.3)).toBe(-2.5);
    expect(anteil(versch, 0)).toBe(0.5);
    expect(wertBei(versch, 0.75)).toBe(3.5);
    expect(wertBei(versch, 2)).toBe(7);
  });

  it("zählt als Änderung nur, was vom Gelesenen abweicht", () => {
    const werte = [wert(), wert({ schluessel: "x", v: 40 }), wert({ schluessel: "y", quality: "stale" })];
    expect(sichtbar(werte[0]!, {})).toBe(0.7);
    expect(sichtbar(werte[0]!, { heat_pump_set_slope: 0.9 })).toBe(0.9);
    expect(sichtbar(werte[2]!, {})).toBeNull();
    const a = aenderungen(werte, { heat_pump_set_slope: 0.9, x: 40, y: 3 });
    expect(a.map((x) => [x.w.schluessel, x.alt, x.neu])).toEqual([["heat_pump_set_slope", 0.7, 0.9]]);
  });
});

describe("die Heizkurve als Näherung", () => {
  const k = kurveAus(kurve)!;

  it("rechnet Vorlauf = Raum + Steilheit × (Raum − außen) + Verschiebung", () => {
    expect(k).toEqual({ steilheit: 0.7, verschiebung: 0, raum: 21, min: 20, max: 55 });
    expect(vorlaufFrei(k, 0)).toBeCloseTo(35.7, 9);
    expect(vorlaufFrei(k, -10)).toBeCloseTo(42.7, 9);
    // Bei Außentemperatur gleich Raumtemperatur bleibt die Raumtemperatur plus Verschiebung.
    expect(vorlaufFrei({ ...k, verschiebung: 2 }, 21)).toBe(23);
  });

  it("begrenzt auf den kleinsten und größten Vorlauf", () => {
    expect(vorlauf({ ...k, max: 40 }, -10)).toBe(40);
    expect(vorlauf({ ...k, min: 30 }, 20)).toBe(30);
    expect(kurvenPunkte(k, -1, 1)).toEqual([[-1, 36.4], [0, 35.7], [1, 35]].map(([t, v]) => [t, expect.closeTo(v as number, 9)]));
  });

  it("findet aus einem gezogenen Punkt die Steilheit oder die Verschiebung", () => {
    // Die Kurve soll bei −10 °C durch 46 °C gehen: Steilheit (46 − 21) / 31.
    expect(steilheitDurch(k, -10, 46)).toBeCloseTo(25 / 31, 9);
    expect(vorlaufFrei({ ...k, steilheit: steilheitDurch(k, -10, 46) }, -10)).toBeCloseTo(46, 9);
    // Bei 18 °C drei Grad höher ziehen ist eine Verschiebung von drei Grad.
    const ziel = vorlaufFrei(k, 18) + 3;
    expect(verschiebungDurch(k, 18, ziel)).toBeCloseTo(3, 9);
    // Am Drehpunkt selbst lässt sich keine Steilheit bestimmen: sie bleibt.
    expect(steilheitDurch(k, 21, 30)).toBe(0.7);
  });

  it("zeichnet mit dem Entwurf, und ohne eine der fünf Größen gar nicht", () => {
    expect(kurveAus(kurve, { heat_pump_set_slope: 1.0 })?.steilheit).toBe(1.0);
    expect(kurveAus(kurve.slice(1))).toBeNull();
    expect(kurveAus([wert({ quality: "stale" }), ...kurve.slice(1)])).toBeNull();
  });
});
