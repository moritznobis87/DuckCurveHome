import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { zahlUndEinheit } from "@/components/layout/Bereichsuebersicht";
import { AREAS, EINSTELLUNGEN, EINZELSEITEN, STUFEN, sucheEinstellungen } from "./areas";

/**
 * Dashboard und App zeigen dieselben Seiten unter denselben Adressen. Das ist seit dem
 * 23.11.2026 eine feste Regel des Hausherrn, und bis dahin hat sie nur Sorgfalt gehalten:
 * `areas.ts` hier und `Bereiche.swift` in der App wurden von Hand nebeneinander gepflegt.
 *
 * `docs/seitenbaum.json` beschreibt den Seitenbaum einmal. Dieser Test hält das Dashboard
 * dagegen, `SeitenbaumTests.swift` die App. Wer eine Seite nur auf einer Seite einträgt, bekommt
 * in der anderen CI einen roten Lauf, der die Abweichung beim Namen nennt.
 */

type Unteransicht = { weg: string; name: string };
type Reiter = {
  weg: string;
  name: string;
  zeichen: string;
  farbe: string;
  zeitraum: boolean;
  nurHausherr: boolean;
  gruppe: string | null;
  beschreibung: string | null;
  unter: Unteransicht[];
};
type Gruppe = { name: string; wort: string };
type Bereich = {
  schluessel: string;
  weg: string;
  name: string;
  nurHausherr: boolean;
  inLeiste: boolean;
  gruppen: Gruppe[];
  reiter: Reiter[];
};

/** Der Seitenbaum des Dashboards in der Schreibweise der gemeinsamen Datei. */
function seitenbaumDesDashboards(): Bereich[] {
  return AREAS.map((bereich) => ({
    schluessel: bereich.key,
    weg: bereich.href,
    name: bereich.label,
    nurHausherr: bereich.ownerOnly === true,
    inLeiste: bereich.leiste !== false,
    gruppen: (bereich.gruppen ?? []).map((gruppe) => ({ name: gruppe.name, wort: gruppe.wort })),
    reiter: bereich.tabs.map((reiter) => ({
      weg: reiter.href,
      name: reiter.label,
      zeichen: reiter.icon,
      farbe: reiter.farbe,
      zeitraum: reiter.dated === true,
      nurHausherr: reiter.ownerOnly === true,
      gruppe: reiter.gruppe ?? null,
      beschreibung: reiter.beschreibung ?? null,
      unter: (reiter.unter ?? []).map((ansicht) => ({ weg: ansicht.href, name: ansicht.label })),
    })),
  }));
}

describe("Seitenbaum", () => {
  it("stimmt mit docs/seitenbaum.json überein, gegen das auch die App geprüft wird", () => {
    const datei = resolve(__dirname, "../../../../docs/seitenbaum.json");
    const gemeinsam = JSON.parse(readFileSync(datei, "utf-8")) as { bereiche: Bereich[] };
    expect(seitenbaumDesDashboards()).toEqual(gemeinsam.bereiche);
  });

  it("zerlegt die Leitzahl einer Kachel am letzten Leerzeichen, wie die App", () => {
    expect(zahlUndEinheit("19,1 kWh")).toEqual({ zahl: "19,1", einheit: "kWh" });
    expect(zahlUndEinheit("−80 %")).toEqual({ zahl: "−80", einheit: "%" });
    expect(zahlUndEinheit("0")).toEqual({ zahl: "0", einheit: "" });
    expect(zahlUndEinheit("1 234,5 kWh")).toEqual({ zahl: "1 234,5", einheit: "kWh" });
  });

  it("kennt dieselben Stufen und Einstellungen wie docs/seitenbaum.json", () => {
    const datei = resolve(__dirname, "../../../../docs/seitenbaum.json");
    const gemeinsam = JSON.parse(readFileSync(datei, "utf-8")) as { stufen: unknown; einstellungen: unknown };
    expect(STUFEN).toEqual(gemeinsam.stufen);
    expect(EINSTELLUNGEN).toEqual(gemeinsam.einstellungen);
  });

  it("findet eine Einstellung unter einem Stichwort und zeigt einem Bewohner keine Akte", () => {
    expect(sucheEinstellungen("heizkurve", true).map((e) => e.name)).toEqual(["Regler der Wärmepumpe"]);
    expect(sucheEinstellungen("  ", true)).toEqual([]);
    // Die Mitteilungen liegen im System; das sieht nur der Hausherr.
    expect(sucheEinstellungen("morgenbrief", true)).toHaveLength(1);
    expect(sucheEinstellungen("morgenbrief", false)).toEqual([]);
    expect(sucheEinstellungen("speicher", false).map((e) => e.weg)).toEqual(["/strom/speicher", "/strom/speicher"]);
  });

  it("kennt dieselben Seiten außerhalb der Bereiche wie docs/seitenbaum.json", () => {
    const datei = resolve(__dirname, "../../../../docs/seitenbaum.json");
    const gemeinsam = JSON.parse(readFileSync(datei, "utf-8")) as {
      einzelseiten: { weg: string; name: string; beschreibung: string }[];
    };
    expect(EINZELSEITEN.map((s) => ({ weg: s.href, name: s.label, beschreibung: s.beschreibung }))).toEqual(
      gemeinsam.einzelseiten,
    );
  });
});
