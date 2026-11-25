import { describe, expect, it } from "vitest";
import type { Zelle } from "./ausblick";
import { bandbreite, buehnenmass, sonnenanteil, sonnenort } from "./buehne";
import { STARTBILDER, STARTBILD_MERKER, startbildAus } from "./startbild";
import { preislaenge, ringmass, stunden24, stundenwinkel } from "./stundenring";

/**
 * Die Rechnung der neuen Startseite. Dieselben Werte prüft das Kit in `StartbildTests.swift`:
 * wer hier eine Zahl ändert, ändert sie dort.
 */
describe("Startbild", () => {
  it("kennt zwei Bilder, die Bühne zuerst", () => {
    expect(STARTBILDER.map((b) => b.id)).toEqual(["buehne", "uhr"]);
    expect(STARTBILDER.map((b) => b.name)).toEqual(["Die Bühne", "Die Uhr"]);
    expect(STARTBILD_MERKER).toBe("dch-startbild");
  });
  it("liest Unbekanntes als Bühne", () => {
    expect(startbildAus("uhr")).toBe("uhr");
    expect(startbildAus("buehne")).toBe("buehne");
    expect(startbildAus(null)).toBe("buehne");
    expect(startbildAus("kacheln")).toBe("buehne");
  });
});

describe("Bühne", () => {
  it("macht ein Band nach der Leistung breit und deckelt es", () => {
    expect(bandbreite(0)).toBe(5);
    expect(bandbreite(1.3)).toBeCloseTo(10.85, 6);
    expect(bandbreite(4.6)).toBeCloseTo(25.7, 6);
    expect(bandbreite(9)).toBe(30);
    expect(bandbreite(-2)).toBe(5);
  });
  it("stellt die Sonne nur zwischen Aufgang und Untergang auf den Bogen", () => {
    const lauf = { punkte: [], von: 1000, bis: 5000 };
    expect(sonnenanteil(lauf, 1000)).toBe(0);
    expect(sonnenanteil(lauf, 3000)).toBe(0.5);
    expect(sonnenanteil(lauf, 5000)).toBe(1);
    expect(sonnenanteil(lauf, 999)).toBeNull();
    expect(sonnenanteil(lauf, 5001)).toBeNull();
    expect(sonnenanteil(null, 3000)).toBeNull();
  });
  it("rechnet die Maße der Wand", () => {
    const m = buehnenmass(816, 400);
    expect(m.schmal).toBe(false);
    expect(m.boden).toBe(340);
    expect(m.mitte).toBe(408);
    expect(m.hausHalb).toBeCloseTo(85.68, 6);
    expect(m.rx).toBe(372);
    expect(m.ry).toBe(300);
    expect(m.netzX).toBeCloseTo(81.6, 6);
    expect(m.wallboxX).toBeCloseTo(232.56, 6);
    expect(m.speicherX).toBeCloseTo(583.44, 6);
    expect(m.pumpeX).toBeCloseTo(726.24, 6);
    expect(m.tief).toBe(370);
    expect(m.schildY).toBe(244);
  });
  it("rechnet die Maße des Telefons", () => {
    const m = buehnenmass(358, 322);
    expect(m.schmal).toBe(true);
    expect(m.boden).toBe(268);
    expect(m.hausHalb).toBe(60);
    expect(m.rx).toBe(157);
    expect(m.ry).toBe(204);
    expect(m.netzX).toBe(40);
    expect(m.speicherX).toBe(316);
    expect(m.tief).toBe(294);
  });
  it("setzt die Sonne auf den Bogen", () => {
    const m = buehnenmass(816, 400);
    expect(sonnenort(m, 0)).toEqual({ x: 36, y: 340 });
    const mittag = sonnenort(m, 0.5);
    expect(mittag.x).toBeCloseTo(408, 6);
    expect(mittag.y).toBeCloseTo(40, 6);
    const spaet = sonnenort(m, 0.75);
    expect(spaet.x).toBeCloseTo(671.0437, 3);
    expect(spaet.y).toBeCloseTo(127.868, 3);
  });
});

describe("Stundenring", () => {
  const um = (stunde: number, minute: number, tag = 25) => new Date(2026, 10, tag, stunde, minute).getTime();
  const zelle = (ts: number, preis: number | null, pv: number, wp = false): Zelle => ({ ts, preis, pv, wp, ofen: false });

  it("fasst Viertelstunden zu Stunden zusammen", () => {
    const zellen = [
      zelle(um(18, 30), 50, 0),
      zelle(um(18, 45), 54, 0),
      zelle(um(19, 0), 40, 0.2, true),
      zelle(um(19, 15), 44, 0.4),
      zelle(um(19, 30), null, 0.6),
      zelle(um(19, 45), null, 0.8),
      zelle(um(20, 0), null, 1),
    ];
    const st = stunden24(zellen, { start: um(19, 30), end: um(21, 30), mittel: 20 });
    expect(st.map((s) => s.stunde)).toEqual([18, 19, 20]);
    expect(st.map((s) => s.preis)).toEqual([52, 42, null]);
    expect(st[1]!.sonneKw).toBeCloseTo(0.5, 6);
    expect(st.map((s) => s.wp)).toEqual([false, true, false]);
    expect(st.map((s) => s.tief)).toEqual([false, true, true]);
  });
  it("hört nach 24 Stunden auf, auch wenn die laufende Stunde morgen wiederkommt", () => {
    const zellen: Zelle[] = [];
    for (let i = 0; i < 96; i++) zellen.push(zelle(um(18, 30) + i * 900_000, 30, 0));
    const st = stunden24(zellen, null);
    expect(st).toHaveLength(24);
    expect(st[0]!.stunde).toBe(18);
    expect(st[23]!.stunde).toBe(17);
  });
  it("stellt 00 Uhr nach oben und dreht im Uhrzeigersinn", () => {
    expect(stundenwinkel(0)).toBeCloseTo(-Math.PI / 2, 9);
    expect(stundenwinkel(6)).toBeCloseTo(0, 9);
    expect(stundenwinkel(12)).toBeCloseTo(Math.PI / 2, 9);
    expect(stundenwinkel(18)).toBeCloseTo(Math.PI, 9);
  });
  it("misst einen Preis am höchsten des Tages, mindestens an 40 ct", () => {
    expect(preislaenge(53, 53)).toBe(1);
    expect(preislaenge(26.5, 53)).toBe(0.5);
    expect(preislaenge(20, 30)).toBe(0.5);
    expect(preislaenge(20, null)).toBe(0.5);
    expect(preislaenge(-5, 53)).toBe(0);
  });
  it("rechnet die Maße des Rings", () => {
    expect(ringmass(816, 400)).toEqual({ mitteX: 408, mitteY: 189, radius: 152, preis: 118, sonne: 106, pumpe: 94, zahl: 78 });
    expect(ringmass(358, 380)).toEqual({ mitteX: 179, mitteY: 179, radius: 149, preis: 115, sonne: 103, pumpe: 91, zahl: 75 });
  });
});
