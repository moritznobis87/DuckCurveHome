import { describe, expect, it } from "vitest";
import type { HouseDeck } from "@/lib/api/models";
import { bildschirm, istAussen, ohneLuecken, strahl, tempFarbe, vereinigt, versetzt, wandstuecke } from "./geometrie";

type Raum = HouseDeck["rooms"][number];
const raum = (name: string, x0: number, z0: number, x1: number, z1: number, extra: Partial<Raum> = {}): Raum => ({
  name,
  x0,
  z0,
  x1,
  z1,
  minor: false,
  silent: false,
  open: false,
  cold: false,
  tech: false,
  tiles: false,
  no_walls: "",
  railing: "",
  ...extra,
});

describe("Waende aus Raeumen", () => {
  it("vereinigt anstossende Intervalle und laesst Luecken aus", () => {
    expect(vereinigt([[0, 2], [2, 5], [7, 8]])).toEqual([[0, 5], [7, 8]]);
    expect(ohneLuecken([[0, 10]], [[2, 3], [6, 7]])).toEqual([[0, 2], [3, 6], [7, 10]]);
    // Eine Luecke am Rand frisst kein Stueck von weniger als zwei Zentimetern.
    expect(ohneLuecken([[0, 10]], [[0, 1]])).toEqual([[1, 10]]);
  });

  it("erkennt die Aussenhaut an der Raumkante", () => {
    const huelle = [[0, 0], [10, 0], [10, 8], [0, 8]];
    const r = raum("Wohnen", 0, 0, 6, 8);
    expect(istAussen(huelle, r, "n")).toBe(true);
    expect(istAussen(huelle, r, "w")).toBe(true);
    expect(istAussen(huelle, r, "o")).toBe(false);
  });

  it("zeichnet eine geteilte Wand nur einmal und schneidet die Tuer heraus", () => {
    const deck: HouseDeck = {
      key: "eg",
      name: "EG",
      shell: [[0, 0], [10, 0], [10, 8], [0, 8]],
      rooms: [raum("Wohnen", 0, 0, 6, 8), raum("Kochen", 6, 0, 10, 8)],
      gaps: [{ x: 6, a: 3, b: 4 }],
    } as HouseDeck;
    const innen = wandstuecke(deck).filter((w) => w.senkrecht && Math.abs(w.konst - 6) < 0.01);
    expect(innen).toHaveLength(2);
    expect(innen.map((w) => [w.a, w.b])).toEqual([[0, 3], [4, 8]]);
    expect(innen.every((w) => !w.aussen)).toBe(true);
    const aussen = wandstuecke(deck).filter((w) => w.aussen);
    expect(aussen.length).toBeGreaterThanOrEqual(4);
  });

  it("laesst Seiten ohne Wand weg", () => {
    const deck: HouseDeck = {
      key: "og",
      name: "OG",
      shell: [[0, 0], [10, 0], [10, 8], [0, 8]],
      rooms: [raum("Luftraum", 2, 2, 5, 5, { no_walls: "nwso", open: true })],
    } as HouseDeck;
    expect(wandstuecke(deck)).toHaveLength(0);
  });
});

describe("Projektion und Farben", () => {
  it("versetzt ein Rechteck nach aussen", () => {
    const aus = versetzt([[0, 0], [4, 0], [4, 3], [0, 3]], 1);
    expect(aus[0]![0]).toBeCloseTo(-1);
    expect(aus[0]![1]).toBeCloseTo(-1);
    expect(aus[2]![0]).toBeCloseTo(5);
    expect(aus[2]![1]).toBeCloseTo(4);
  });

  it("haelt den Grundriss massstaeblich und schiebt Hoehen nach rechts oben", () => {
    const boden = bildschirm(3, 0, 2, 0);
    const oben = bildschirm(3, 1, 2, 0);
    expect(boden).toEqual({ sx: 3, su: -2 });
    expect(oben.sx).toBeGreaterThan(boden.sx);
    expect(oben.su).toBeGreaterThan(boden.su);
    const r = strahl(0);
    expect(Math.hypot(...r)).toBeCloseTo(1);
  });

  it("faerbt kalt blau und warm orange, dazwischen stetig", () => {
    expect(tempFarbe(10)).toBe(0x25506a);
    expect(tempFarbe(30)).toBe(0xff7a45);
    const mitte = tempFarbe(20);
    expect(mitte).toBeGreaterThan(0x3d7a9c);
    expect(mitte).toBeLessThan(0x6ab6c8);
  });
});
