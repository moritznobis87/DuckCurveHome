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
});
