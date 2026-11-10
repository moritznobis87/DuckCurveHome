import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { describe, expect, it } from "vitest";

/**
 * „K1" steht in keinem Text, den Nutzer sehen.
 *
 * K1 ist die Bezeichnung des Schaltkontakts im Schaltplan, über den die Regelung bei der
 * Wärmepumpe Wärme anfordert. Im Quelltext und in den Kommentaren ist das der richtige Name. In
 * der Oberfläche stand er in rund vierzig Texten („Was löst K1 aus?", „K1 wird gestellt"), und
 * der Nutzer sagte dazu am 10.11.2026: „Kein Mensch versteht, was mit K1 gemeint ist."
 *
 * Gemeint ist die **Anforderung** an die Wärmepumpe, und so heißt sie in der Oberfläche. Dasselbe
 * gilt für „Freigabekontakt" und „Schließvorgang": das sind Wörter über den Kontakt, nicht über
 * das, was er bewirkt.
 *
 * Geprüft wird der Quelltext ohne Kommentare. Die erzeugte Typdatei ist ausgenommen: sie trägt
 * die Beschreibungen der Schnittstelle, die kein Nutzer liest.
 */
const WURZEL = join(__dirname);
const AUSGENOMMEN = new Set(["lib/api/types.ts", "texte-ohne-k1.test.ts"]);
const VERBOTEN = /\bK1\b|Freigabekontakt|Schließvorg/;

function dateien(ordner: string): string[] {
  return readdirSync(ordner).flatMap((name) => {
    const pfad = join(ordner, name);
    if (statSync(pfad).isDirectory()) return dateien(pfad);
    return /\.(ts|tsx)$/.test(name) && !/\.test\.tsx?$/.test(name) ? [pfad] : [];
  });
}

/** Kommentare entfernen: Blockkommentare, JSX-Kommentare und Zeilenkommentare. */
function ohneKommentare(quelle: string): string {
  return quelle
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .split("\n")
    .map((zeile) => zeile.replace(/(^|[^:"'`])\/\/.*$/, "$1"))
    .join("\n");
}

describe("Texte der Oberfläche", () => {
  it("nennen den Schaltkontakt nicht beim Namen aus dem Schaltplan", () => {
    const funde: string[] = [];
    for (const pfad of dateien(WURZEL)) {
      const rel = relative(WURZEL, pfad);
      if (AUSGENOMMEN.has(rel)) continue;
      ohneKommentare(readFileSync(pfad, "utf8"))
        .split("\n")
        .forEach((zeile, i) => {
          if (VERBOTEN.test(zeile)) funde.push(`${rel}:${i + 1}: ${zeile.trim().slice(0, 120)}`);
        });
    }
    expect(funde).toEqual([]);
  });
});
