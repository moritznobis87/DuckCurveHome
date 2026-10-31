import { describe, expect, it } from "vitest";
import type { RoomLogEntry } from "@/lib/api/models";
import { artText, fahnenPosition, fensterText, indexFuerAnteil, pfad, spanne, sprungText, ueberschrift, verdichte, wertText, xFuerZeit, yFuerWert, zaehle, zeitMarken } from "./protokoll";

function eintrag(p: Partial<RoomLogEntry>): RoomLogEntry {
  return {
    at: "2026-10-31T06:00:00Z",
    quelle: "extern",
    art: "sollwert",
    from_c: null,
    to_c: null,
    text: "",
    ...p,
  } as RoomLogEntry;
}

describe("spanne", () => {
  it("nimmt die Spanne der Werte, wenn sie weit genug ist", () => {
    expect(spanne([[18, 24]])).toEqual({ min: 18, max: 24 });
  });

  it("dehnt eine zu enge Spanne auf das Mindestmaß", () => {
    // Ein Raum, der auf 0,2 K genau steht, bekommt keine Gebirgskurve.
    const s = spanne([[21.0, 21.2]]);
    expect(s!.max - s!.min).toBeGreaterThanOrEqual(2);
  });

  it("rundet nach außen auf halbe Grad", () => {
    expect(spanne([[18.3, 24.1]])).toEqual({ min: 18, max: 24.5 });
  });

  it("übergeht Lücken und liefert ohne Werte nichts", () => {
    expect(spanne([[null, 20, null], [null]])).not.toBeNull();
    expect(spanne([[null, null]])).toBeNull();
  });
});

describe("pfad", () => {
  const s = { min: 20, max: 22 };

  it("zeichnet eine Linie über die volle Breite", () => {
    const d = pfad([20, 22], s, 100, 50);
    expect(d).toBe("M0.0 50.0 L100.0 0.0");
  });

  it("trennt den Pfad an einer Lücke statt sie zu überbrücken", () => {
    const d = pfad([20, null, 22], s, 100, 50);
    // Zwei Anfänge heißt: zwei getrennte Stücke, dazwischen wurde nichts gemessen.
    expect(d.match(/M/g)).toHaveLength(2);
    expect(d).not.toContain("L100.0 0.0 L");
  });

  it("gibt bei leerer Reihe nichts zurück", () => {
    expect(pfad([], s, 100, 50)).toBe("");
    expect(pfad([21], { min: 21, max: 21 }, 100, 50)).toBe("");
  });
});

describe("xFuerZeit", () => {
  const ts = ["2026-10-31T06:00:00Z", "2026-10-31T07:00:00Z", "2026-10-31T08:00:00Z"];

  it("legt einen Zeitpunkt anteilig auf die Breite", () => {
    expect(xFuerZeit("2026-10-31T07:00:00Z", ts, 200)).toBe(100);
  });

  it("gibt nichts zurück, wenn der Zeitpunkt außerhalb liegt", () => {
    expect(xFuerZeit("2026-10-31T05:00:00Z", ts, 200)).toBeNull();
    expect(xFuerZeit("2026-10-31T09:00:00Z", ts, 200)).toBeNull();
    expect(xFuerZeit("unsinn", ts, 200)).toBeNull();
  });
});

describe("Texte", () => {
  it("benennt die Arten verständlich", () => {
    expect(artText(eintrag({ art: "befehl" }))).toContain("nie gemeldet");
    expect(artText(eintrag({ art: "ruhe" }))).toContain("in Ruhe");
    expect(artText(eintrag({ art: "einstellung" }))).toContain("geschaltet");
  });

  it("schreibt den Sprung mit Komma", () => {
    expect(sprungText(eintrag({ from_c: 21, to_c: 22.5 }))).toBe("21,0 → 22,5");
    expect(sprungText(eintrag({ from_c: null, to_c: 22 }))).toBe("auf 22,0");
    expect(sprungText(eintrag({ to_c: null }))).toBe("");
  });
});

describe("ueberschrift", () => {
  it("sagt zuerst, wenn nichts passiert ist", () => {
    expect(ueberschrift([], 48)).toContain("niemand");
    // Ein Rückzug der Automatik ist keine Sollwertänderung.
    expect(ueberschrift([eintrag({ art: "ruhe", quelle: "automatik" })], 48)).toContain("niemand");
  });

  it("zählt die Änderungen nach Herkunft", () => {
    const text = ueberschrift(
      [
        eintrag({ quelle: "extern", to_c: 22 }),
        eintrag({ quelle: "extern", to_c: 23 }),
        eintrag({ quelle: "automatik", to_c: 21 }),
      ],
      48,
    );
    expect(text).toContain("3 Änderungen");
    expect(text).toContain("2× von außen");
    expect(text).toContain("1× durch die Automatik");
  });

  it("schreibt den Einzelfall im Singular", () => {
    expect(ueberschrift([eintrag({ quelle: "app", to_c: 22 })], 24)).toContain("Eine Änderung");
  });
});

describe("zaehle", () => {
  it("zählt je Quelle und lässt leere Quellen bei null", () => {
    expect(zaehle([eintrag({ quelle: "app" }), eintrag({ quelle: "app" })])).toEqual({
      app: 2,
      automatik: 0,
      extern: 0,
    });
  });
});

describe("zeitMarken", () => {
  it("liefert höchstens so viele Marken wie erlaubt", () => {
    const ts = Array.from({ length: 96 }, (_, i) => new Date(Date.UTC(2026, 9, 31, 0, i * 15)).toISOString());
    expect(zeitMarken(ts, 7).length).toBeLessThanOrEqual(7);
  });

  it("gibt bei zu kurzer Achse nichts zurück", () => {
    expect(zeitMarken(["2026-10-31T06:00:00Z"])).toEqual([]);
  });
});

describe("verdichte", () => {
  it("mittelt je Fenster", () => {
    // Zwei Viertelstunden offen, zwei zu: die Stunde war zur Hälfte offen.
    expect(verdichte([1, 1, 0, 0], 4)).toEqual([0.5]);
  });

  it("lässt ein Fenster ohne Messwert leer, statt es zu erfinden", () => {
    expect(verdichte([null, null], 2)).toEqual([null]);
    expect(verdichte([1, null], 2)).toEqual([1]);
  });

  it("gibt die Reihe unverändert zurück, wenn nichts zu verdichten ist", () => {
    const r = [1, 0, null];
    expect(verdichte(r, 1)).toBe(r);
  });

  it("nimmt auch ein angeschnittenes letztes Fenster mit", () => {
    expect(verdichte([1, 1, 1, 1, 0], 4)).toEqual([1, 0]);
  });
});

describe("indexFuerAnteil", () => {
  it("trifft Anfang, Mitte und Ende", () => {
    expect(indexFuerAnteil(0, 5)).toBe(0);
    expect(indexFuerAnteil(0.5, 5)).toBe(2);
    expect(indexFuerAnteil(1, 5)).toBe(4);
  });

  it("rundet zum naechsten Punkt statt abzuschneiden", () => {
    // 0,74 liegt naeher an Punkt 3 als an Punkt 2; mit floor waere es 2.
    expect(indexFuerAnteil(0.74, 5)).toBe(3);
  });

  it("bleibt in den Grenzen, auch wenn der Finger daneben liegt", () => {
    expect(indexFuerAnteil(-0.3, 5)).toBe(0);
    expect(indexFuerAnteil(1.4, 5)).toBe(4);
  });

  it("gibt ohne Punkte nichts zurueck", () => {
    expect(indexFuerAnteil(0.5, 0)).toBeNull();
  });
});

describe("wertText", () => {
  it("schreibt mit Komma und Einheit", () => {
    expect(wertText(21.34)).toBe("21,3 °C");
    expect(wertText(0.5, "", 0)).toBe("1 ");
  });

  it("sagt bei einer Luecke, dass nichts gemessen wurde", () => {
    expect(wertText(null)).toBe("kein Messwert");
    expect(wertText(undefined)).toBe("kein Messwert");
  });
});

describe("fensterText", () => {
  const ts = ["2026-10-31T06:00:00Z", "2026-10-31T06:15:00Z"];

  it("nennt den Zeitraum, nicht einen Augenblick", () => {
    const t = fensterText(ts, 0, 15);
    expect(t).toMatch(/\d{2}:\d{2} bis \d{2}:\d{2}/);
  });

  it("gibt bei kaputter Zeit nichts zurueck", () => {
    expect(fensterText(["unsinn"], 0, 15)).toBe("");
    expect(fensterText(ts, 9, 15)).toBe("");
  });
});

describe("fahnenPosition", () => {
  it("folgt dem Finger in der Mitte", () => {
    expect(fahnenPosition(0.5)).toBe(50);
  });

  it("bleibt an den Raendern stehen, damit sie nicht hinauslaeuft", () => {
    expect(fahnenPosition(0)).toBe(16);
    expect(fahnenPosition(1)).toBe(84);
  });
});

describe("yFuerWert", () => {
  const s = { min: 20, max: 22 };

  it("legt den kleinsten Wert nach unten und den groessten nach oben", () => {
    // In SVG waechst y nach unten: der Hoechstwert liegt bei 0.
    expect(yFuerWert(20, s, 50)).toBe(50);
    expect(yFuerWert(22, s, 50)).toBe(0);
    expect(yFuerWert(21, s, 50)).toBe(25);
  });

  it("gibt ohne Wert oder bei entarteter Spanne nichts zurueck", () => {
    expect(yFuerWert(null, s, 50)).toBeNull();
    expect(yFuerWert(21, { min: 21, max: 21 }, 50)).toBeNull();
  });
});
