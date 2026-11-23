import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { AREAS } from "./areas";

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
  zeitraum: boolean;
  nurHausherr: boolean;
  unter: Unteransicht[];
};
type Bereich = { schluessel: string; weg: string; name: string; reiter: Reiter[] };

/** Der Seitenbaum des Dashboards in der Schreibweise der gemeinsamen Datei. */
function seitenbaumDesDashboards(): Bereich[] {
  return AREAS.map((bereich) => ({
    schluessel: bereich.key,
    weg: bereich.href,
    name: bereich.label,
    reiter: bereich.tabs.map((reiter) => ({
      weg: reiter.href,
      name: reiter.label,
      zeitraum: reiter.dated === true,
      nurHausherr: reiter.ownerOnly === true,
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
});
