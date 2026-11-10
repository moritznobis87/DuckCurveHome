import { describe, expect, it } from "vitest";
import { achsenText, betrieb, deckung, ergebnisText, geordnet, gruppe, hausStunde, hausTag, prozentZahl, wiedergabeZiel, type Ereignis } from "./wirkung";

function ereignis(teil: Partial<Ereignis>): Ereignis {
  return { at: "2026-11-07T11:00:00Z", lief_schon: false, auswertbar: true, gefolgt: true, verzoegerung_min: 4, kontakt_min: 60, kw: [], ...teil };
}

describe("gruppe", () => {
  it("stellt die laufende Maschine vor jede andere Frage", () => {
    expect(gruppe(ereignis({ lief_schon: true, auswertbar: false, gefolgt: null }))).toBe("lief_schon");
  });

  it("unterscheidet nicht angelaufen von nicht auswertbar", () => {
    expect(gruppe(ereignis({ gefolgt: false, verzoegerung_min: null }))).toBe("nicht_gefolgt");
    expect(gruppe(ereignis({ auswertbar: false, gefolgt: null }))).toBe("unklar");
  });
});

describe("geordnet", () => {
  it("ordnet nach Gruppe und darin nach Verzögerung", () => {
    const g = geordnet([
      ereignis({ at: "2026-11-01T11:00:00Z", verzoegerung_min: 9 }),
      ereignis({ at: "2026-11-02T11:00:00Z", gefolgt: false, verzoegerung_min: null }),
      ereignis({ at: "2026-11-03T11:00:00Z", verzoegerung_min: 2 }),
      ereignis({ at: "2026-11-04T11:00:00Z", lief_schon: true, auswertbar: false, gefolgt: null, verzoegerung_min: null }),
    ]);
    expect(g.map((x) => x.key)).toEqual(["gefolgt", "nicht_gefolgt", "lief_schon"]);
    expect(g[0]?.ereignisse.map((e) => e.verzoegerung_min)).toEqual([2, 9]);
  });

  it("stellt einen späten Anlauf vor gar keinen und bei Gleichstand den jüngsten zuerst", () => {
    const g = geordnet([
      ereignis({ at: "2026-11-01T11:00:00Z", gefolgt: false, verzoegerung_min: null }),
      ereignis({ at: "2026-11-05T11:00:00Z", gefolgt: false, verzoegerung_min: null }),
      ereignis({ at: "2026-11-03T11:00:00Z", gefolgt: false, verzoegerung_min: 48 }),
    ]);
    expect(g[0]?.ereignisse.map((e) => e.at.slice(8, 10))).toEqual(["03", "05", "01"]);
  });

  it("lässt leere Gruppen weg", () => {
    expect(geordnet([])).toEqual([]);
  });
});

describe("betrieb", () => {
  it("trennt laufen, stehen und nicht gemessen", () => {
    const b = betrieb([0, 0, 4, 4, null, null, 0.3, 0.5], 0.5);
    expect(b.laeuft).toEqual([
      [2, 4],
      [7, 8],
    ]);
    expect(b.steht).toEqual([
      [0, 2],
      [6, 7],
    ]);
  });
});

describe("ergebnisText", () => {
  it("nennt die Verzögerung und sagt, wenn sie zu spät kam", () => {
    expect(ergebnisText(ereignis({ verzoegerung_min: 4 }), 30)).toBe("nach 4 min");
    expect(ergebnisText(ereignis({ verzoegerung_min: 0 }), 30)).toBe("sofort");
    expect(ergebnisText(ereignis({ gefolgt: false, verzoegerung_min: 45 }), 30)).toBe("erst nach 45 min");
    expect(ergebnisText(ereignis({ gefolgt: false, verzoegerung_min: null }), 30)).toBe("kein Anlauf");
  });

  it("gibt für nicht auswertbare Ereignisse den Grund und keine Zahl", () => {
    expect(ergebnisText(ereignis({ lief_schon: true, auswertbar: false, gefolgt: null }), 30)).toBe("lief schon");
    expect(ergebnisText(ereignis({ auswertbar: false, gefolgt: null }), 30)).toBe("Messung fehlt");
  });
});

describe("Achse und Zahlen", () => {
  it("beschriftet den Nullpunkt mit dem, was dort geschieht", () => {
    expect(achsenText(0)).toBe("Anforderung");
    expect(achsenText(30)).toBe("+30 min");
    expect(achsenText(-30)).toBe("−30 min");
  });

  it("lässt eine fehlende Quote als Strich stehen und rundet keine Null daraus", () => {
    expect(prozentZahl(null)).toBe("-");
    expect(prozentZahl(0)).toBe("0");
    expect(prozentZahl(0.666)).toBe("67");
  });

  it("hält wenige Kurven lesbar und viele durchsichtig", () => {
    expect(deckung(1)).toBe(0.55);
    expect(deckung(100)).toBeCloseTo(0.11, 2);
    expect(deckung(10_000)).toBe(0.1);
  });
});

describe("Zeit des Hauses", () => {
  it("rechnet Tag und Stunde in Berlin und nicht in UTC", () => {
    // 23:30 UTC am 7. ist in Berlin 00:30 am 8. (Winterzeit).
    expect(hausTag("2026-11-07T23:30:00Z")).toBe("2026-11-08");
    expect(hausStunde("2026-11-07T23:30:00Z")).toBe(0);
    expect(wiedergabeZiel("2026-11-07T23:30:00Z")).toBe("/waerme/wiedergabe?day=2026-11-08&t=0");
  });

  it("kennt die Sommerzeit", () => {
    expect(hausStunde("2026-07-01T10:00:00Z")).toBe(12);
  });
});
