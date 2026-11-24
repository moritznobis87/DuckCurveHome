import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { BESCHRIFTUNG, EBENEN, KARTE, PLATZ, SICHT, WEGE, notplatz } from "./layout";

/**
 * Das Blockschaltbild des Regelkreises steht im Dashboard und in der App (Vorgabe des Hausherrn
 * vom 24.11.2026: überall das Schaltbild, keine Liste). Wo ein Kästchen liegt und wie eine
 * Leitung läuft, steht einmal in `docs/regelkreis-schaltbild.json`.
 *
 * Dieser Test hält `layout.ts` dagegen. Die App bekommt ihre Daten aus derselben Datei erzeugt
 * (`tools/gen-schaltbild.py`), und `tools/ios-pruefen.sh` prüft, dass sie auf dem Stand sind.
 * Wer ein Kästchen nur hier verschiebt, bekommt einen roten Lauf, der die Stelle nennt.
 */

type Rechteck = { x: number; y: number; w: number; h: number };
type Schaltbild = {
  karte: { breite: number; hoehe: number };
  sicht: { schluessel: string; name: string; box: [number, number, number, number] }[];
  platz: { block: string; rect: Rechteck; wdh: Rechteck[] }[];
  wege: { kante: string; punkte: [number, number][]; bogen: [number, number] | null }[];
  beschriftung: { x: number; y: number; text: string; anker: "start" | "middle" | "end" }[];
  ebenen: { x: number; y: number; text: string }[];
};

const bild = JSON.parse(readFileSync(resolve(__dirname, "../../../../../docs/regelkreis-schaltbild.json"), "utf8")) as Schaltbild;

describe("Schaltbild des Regelkreises", () => {
  it("hat im Dashboard dieselbe Karte und dieselben Sichten wie in der gemeinsamen Datei", () => {
    expect(KARTE).toEqual(bild.karte);
    expect(Object.entries(SICHT).map(([schluessel, s]) => ({ schluessel, name: s.label, box: s.box }))).toEqual(bild.sicht);
  });

  it("stellt jeden Block an denselben Platz, Wiederholungen eingeschlossen", () => {
    expect(Object.entries(PLATZ).map(([block, p]) => ({ block, rect: p.rect, wdh: p.wdh ?? [] }))).toEqual(bild.platz);
  });

  it("führt jede Leitung über dieselben Punkte", () => {
    expect(Object.entries(WEGE).map(([kante, w]) => ({ kante, punkte: w.p, bogen: w.bogen ?? null }))).toEqual(bild.wege);
  });

  it("trägt dieselben Aufschriften an den Leitungen und über den Ebenen", () => {
    expect(BESCHRIFTUNG.map((b) => ({ x: b.x, y: b.y, text: b.text, anker: b.anker ?? "start" }))).toEqual(bild.beschriftung);
    expect(EBENEN).toEqual(bild.ebenen);
  });

  it("verbindet nur Blöcke, die einen Platz haben", () => {
    const bloecke = new Set(Object.keys(PLATZ));
    for (const kante of Object.keys(WEGE)) {
      const [von, nach] = kante.split("→");
      expect(bloecke.has(von!), `${kante}: ${von} hat keinen Platz`).toBe(true);
      expect(bloecke.has(nach!), `${kante}: ${nach} hat keinen Platz`).toBe(true);
    }
  });

  it("legt Blöcke ohne Platz in eine Reihe unter die Karte, sieben nebeneinander", () => {
    // Dieselbe Rechnung steht in der App (`Schaltbild.notplatz`).
    expect(notplatz(0)).toEqual({ x: 28, y: 1272, w: 180, h: 44 });
    expect(notplatz(6)).toEqual({ x: 1204, y: 1272, w: 180, h: 44 });
    expect(notplatz(7)).toEqual({ x: 28, y: 1328, w: 180, h: 44 });
  });
});
