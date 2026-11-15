import { describe, expect, it } from "vitest";
import { farbe } from "@/components/anlage/schema";
import { FUEHLER, gradzahl, randBreite, stufen, vollstaendig } from "./glas";

describe("der Pufferspeicher als Glas", () => {
  it("setzt jede Farbe auf die Höhe ihres Fühlers, mit der Skala des Wassers", () => {
    const t = [61, 54, 39, 31];
    const s = stufen(t);
    expect(s.map((x) => x.bei)).toEqual([...FUEHLER]);
    expect(s.map((x) => x.farbe)).toEqual(t.map((v) => farbe(v)));
    // Die Fühler sitzen in der Mitte ihrer Schicht: vier gleich hohe Schichten.
    expect(FUEHLER.map((f, i) => f - i * 0.25)).toEqual([0.125, 0.125, 0.125, 0.125]);
  });

  it("zeichnet keinen Verlauf, wenn ein Fühler fehlt", () => {
    expect(vollstaendig([61, 54, 39, 31])).toBe(true);
    for (const t of [[61, null, 39, 31], [61, 54, 39], [61, 54, Number.NaN, 31], []]) {
      expect(vollstaendig(t)).toBe(false);
      expect(stufen(t)).toEqual([]);
    }
  });

  it("beschriftet in ganzen Grad und lässt der Zahl Platz", () => {
    expect(gradzahl(60.6)).toBe("61");
    expect(gradzahl(null)).toBeNull();
    expect(gradzahl(Number.NaN)).toBeNull();
    expect(randBreite(13)).toBeGreaterThan(40);
    expect(randBreite(20)).toBeGreaterThan(randBreite(13));
  });
});
