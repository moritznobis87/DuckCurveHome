#!/usr/bin/env python3
"""Die Geometrie des Regelkreis-Schaltbilds nach Swift uebernehmen.

Das Blockschaltbild des Regelkreises steht im Dashboard und in der App (Vorgabe des Hausherrn vom
24.11.2026: ueberall das Schaltbild, keine Liste). Wo ein Kaestchen liegt und wie eine Leitung
laeuft, ist fuer beide dasselbe und steht einmal in `docs/regelkreis-schaltbild.json`:

* Das Dashboard haelt `apps/web/src/components/regelkreis/layout.ts` mit einem Test dagegen
  (`layout.test.ts`).
* Die App bekommt ihre Daten von hier: `Schaltbilddaten.swift` im Kern, erzeugt und nicht von
  Hand gepflegt. Die Typen dazu stehen in `Schaltbild.swift`.

    tools/gen-schaltbild.py
    tools/gen-schaltbild.py --pruefen
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

WURZEL = Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "docs" / "regelkreis-schaltbild.json"
ZIEL = (
    WURZEL / "apps" / "ios" / "DuckCurveKit" / "Sources" / "DuckCurveKit"
    / "Zustand" / "Schaltbilddaten.swift"
)


def zahl(wert: float) -> str:
    """Eine Zahl, wie Swift sie als Double liest: ganze ohne Nachkommastellen."""
    return str(int(wert)) if float(wert).is_integer() else repr(float(wert))


def text(wert: str) -> str:
    """Eine Zeichenkette als Swift-Literal."""
    return '"' + wert.replace("\\", "\\\\").replace('"', '\\"') + '"'


def rechteck(r: dict[str, float]) -> str:
    return f"Schaltbild.Rechteck(x: {zahl(r['x'])}, y: {zahl(r['y'])}, w: {zahl(r['w'])}, h: {zahl(r['h'])})"


def punkt(p: list[float]) -> str:
    return f"Schaltbild.Punkt(x: {zahl(p[0])}, y: {zahl(p[1])})"


def erzeuge(d: dict) -> str:
    z: list[str] = [
        "// Erzeugt von tools/gen-schaltbild.py aus docs/regelkreis-schaltbild.json.",
        "// Nicht von Hand aendern - neu erzeugen mit `tools/gen-schaltbild.py`.",
        "//",
        "// Die Geometrie des Regelkreis-Schaltbilds: wo jedes Kaestchen liegt, wie jede Leitung",
        "// laeuft und was an ihr steht. Dieselben Zahlen wie im Dashboard",
        "// (`apps/web/src/components/regelkreis/layout.ts`).",
        "",
        "public enum Schaltbilddaten {",
        f"    public static let breite: Double = {zahl(d['karte']['breite'])}",
        f"    public static let hoehe: Double = {zahl(d['karte']['hoehe'])}",
        "",
        "    /// Die Ebenen zum Hineinzoomen, in der Reihenfolge ihrer Knoepfe.",
        "    public static let sichten: [Schaltbild.Sicht] = [",
    ]
    for s in d["sicht"]:
        b = s["box"]
        z.append(
            f"        Schaltbild.Sicht(schluessel: {text(s['schluessel'])}, name: {text(s['name'])}, "
            f"ausschnitt: Schaltbild.Rechteck(x: {zahl(b[0])}, y: {zahl(b[1])}, w: {zahl(b[2])}, h: {zahl(b[3])})),"
        )
    z += ["    ]", "", "    /// Hauptrechteck je Block, dazu die Wiederholungen.",
          "    public static let plaetze: [String: Schaltbild.Platz] = ["]
    for p in d["platz"]:
        wdh = ", ".join(rechteck(r) for r in p["wdh"])
        z.append(f"        {text(p['block'])}: Schaltbild.Platz(rect: {rechteck(p['rect'])}, wdh: [{wdh}]),")
    z += ["    ]", "", "    /// Die Leitungen, nach „von→nach“ der Topologie.",
          "    public static let wege: [String: Schaltbild.Weg] = ["]
    for w in d["wege"]:
        punkte = ", ".join(punkt(p) for p in w["punkte"])
        bogen = punkt(w["bogen"]) if w["bogen"] else "nil"
        z.append(f"        {text(w['kante'])}: Schaltbild.Weg(punkte: [{punkte}], bogen: {bogen}),")
    z += ["    ]", "", "    /// Beschriftungen, die nicht am Kaestchen, sondern an der Leitung stehen.",
          "    public static let beschriftungen: [Schaltbild.Beschriftung] = ["]
    for b in d["beschriftung"]:
        z.append(
            f"        Schaltbild.Beschriftung(x: {zahl(b['x'])}, y: {zahl(b['y'])}, "
            f"text: {text(b['text'])}, anker: .{b['anker']}),"
        )
    z += ["    ]", "", "    /// Die Ebenenaufschriften.",
          "    public static let ebenen: [Schaltbild.Beschriftung] = ["]
    for e in d["ebenen"]:
        z.append(
            f"        Schaltbild.Beschriftung(x: {zahl(e['x'])}, y: {zahl(e['y'])}, "
            f"text: {text(e['text'])}, anker: .start),"
        )
    z += ["    ]", "}", ""]
    return "\n".join(z)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pruefen", action="store_true")
    args = ap.parse_args()

    neu = erzeuge(json.loads(QUELLE.read_text(encoding="utf-8")))
    if args.pruefen:
        alt = ZIEL.read_text(encoding="utf-8") if ZIEL.exists() else ""
        if alt != neu:
            print(
                f"{ZIEL.relative_to(WURZEL)} ist nicht auf dem Stand von "
                f"{QUELLE.relative_to(WURZEL)}. Neu erzeugen mit tools/gen-schaltbild.py.",
                file=sys.stderr,
            )
            return 1
        return 0
    ZIEL.write_text(neu, encoding="utf-8")
    print(f"{ZIEL.relative_to(WURZEL)} geschrieben.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
