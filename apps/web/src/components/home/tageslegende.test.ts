import { describe, expect, it } from "vitest";
import { tageslegende, type Kurveninhalt } from "./tageslegende";

/** Dieselben Fälle wie in `KurvenlegendeTests.swift`. */
const leer: Kurveninhalt = { schattenwort: null, waermepumpeGemessen: false, waermepumpeErwartet: false, preisGemessen: false, preisErwartet: false, baender: false };
const kurz = (tag: Parameters<typeof tageslegende>[0], inhalt: Kurveninhalt) => tageslegende(tag, inhalt).map((e) => `${e.reihe}:${e.form}:${e.wort}`);

describe("tageslegende", () => {
  it("nennt für morgen vor 13 Uhr nur, was im Bild steht, und zeichnet es gestrichelt", () => {
    // Das Bild des Hausherrn vom 27.11.2026: Sonne erwartet, heute im Hintergrund, die
    // Wärmepumpe von morgen, aber noch kein Preis und kein Preistief.
    const inhalt = { ...leer, schattenwort: "heute 10,8 kWh", waermepumpeErwartet: true };
    expect(kurz("morgen", inhalt)).toEqual(["sonneErwartet:gestrichelt:Sonne erwartet", "schatten:linie:heute 10,8 kWh", "waermepumpeErwartet:gestrichelt:Wärmepumpe"]);
  });
  it("nimmt Strompreis und Preistief für morgen dazu, sobald sie im Bild stehen", () => {
    const inhalt = { ...leer, schattenwort: "heute 10,8 kWh", waermepumpeErwartet: true, preisErwartet: true, baender: true };
    expect(kurz("morgen", inhalt)).toEqual([
      "sonneErwartet:gestrichelt:Sonne erwartet",
      "schatten:linie:heute 10,8 kWh",
      "waermepumpeErwartet:gestrichelt:Wärmepumpe",
      "strompreis:gestrichelt:Strompreis",
      "preistief:flaeche:Preistief",
    ]);
  });
  it("zeigt heute Sonne, Prognose, den Vortag, das Haus und den Preis als durchgezogene Linie", () => {
    const inhalt = { ...leer, schattenwort: "gestern 6,9 kWh", preisGemessen: true, preisErwartet: true, baender: true };
    expect(kurz("heute", inhalt)).toEqual([
      "sonne:flaeche:Sonne",
      "sonneErwartet:gestrichelt:Prognose",
      "schatten:linie:gestern 6,9 kWh",
      "haus:linie:Haus",
      "strompreis:linie:Strompreis",
      "preistief:flaeche:Preistief",
    ]);
  });
  it("nennt die gemessene Wärmepumpe nur, wo sie gezeichnet ist, und nie für morgen", () => {
    expect(kurz("heute", { ...leer, waermepumpeGemessen: true })).toContain("waermepumpe:linie:Wärmepumpe");
    expect(kurz("morgen", { ...leer, waermepumpeGemessen: true })).toEqual(["sonneErwartet:gestrichelt:Sonne erwartet"]);
  });
  it("lässt das Preistief weg, wenn kein Band im Bild liegt", () => {
    expect(kurz("heute", { ...leer, preisGemessen: true })).toEqual(["sonne:flaeche:Sonne", "sonneErwartet:gestrichelt:Prognose", "haus:linie:Haus", "strompreis:linie:Strompreis"]);
  });
  it("zeichnet den Preis gestrichelt, solange noch keiner gegolten hat", () => {
    expect(kurz("heute", { ...leer, preisErwartet: true })).toContain("strompreis:gestrichelt:Strompreis");
  });
  it("zeigt gestern keine Prognose", () => {
    expect(kurz("gestern", { ...leer, preisGemessen: true })).toEqual(["sonne:flaeche:Sonne", "haus:linie:Haus", "strompreis:linie:Strompreis"]);
  });
});
