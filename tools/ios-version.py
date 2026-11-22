#!/usr/bin/env python3
"""Fassung und Baunummer der App - an einer Stelle stellen, in zwei Dateien schreiben.

**Warum ein Werkzeug fuer zwei Zahlen.** Sie stehen doppelt: in `apps/ios/project.yml` (die
Quelle) und in `apps/ios/DuckCurveHome/Info.plist` (das Erzeugnis, das mit im Repository liegt,
damit Xcode ohne XcodeGen aufgeht). `tools/xcodeproj-pruefen.py` haelt beide gegeneinander und
wird rot, sobald sie auseinanderlaufen - jede Aenderung muss also beide anfassen. Von Hand ist
das zweimal dieselbe Zahl und einmal Vergessen.

**Warum nicht xcodegen.** Weil es dafuer nicht gebraucht wird: an der Struktur des Projekts
aendert eine Baunummer nichts, nur ein Wert in der Plist. Dieses Werkzeug laeuft darum ohne
Swift und ohne Mac - in der CI und auf jedem Rechner, auf dem gerade kein Xcode steht.

**Die Baunummer muss steigen, jedes Mal.** App Store Connect nimmt eine Baunummer je Fassung
genau einmal an; der zweite Upload mit derselben Nummer wird abgewiesen, nachdem er
hochgeladen ist. Darum ist `--hochzaehlen` der normale Weg vor jedem Archivieren, und die Zahl
im Repository ist die Auskunft darueber, was zuletzt hochging. Sie laeuft dabei durch, auch
ueber eine neue Fassung hinweg: eindeutig muss sie nur je Fassung sein, und eine Zahl, die nie
zurueckspringt, kann nie kollidieren.

    tools/ios-version.py                 # zeigen, was eingestellt ist
    tools/ios-version.py --hochzaehlen   # Baunummer + 1 (vor jedem Archivieren)
    tools/ios-version.py --bau 42        # Baunummer setzen
    tools/ios-version.py --fassung 1.1   # Fassung setzen (CFBundleShortVersionString)
    tools/ios-version.py --pruefen       # laufen die beiden Dateien auseinander?
"""

from __future__ import annotations

import argparse
import os
import plistlib
import re
import sys

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPEZIFIKATION = os.path.join(WURZEL, "apps", "ios", "project.yml")
PLIST = os.path.join(WURZEL, "apps", "ios", "DuckCurveHome", "Info.plist")

FASSUNG = "CFBundleShortVersionString"
BAU = "CFBundleVersion"


def spezifikation_lesen(schluessel: str) -> str:
    """Den Wert aus project.yml holen - ohne YAML zu laden.

    `yaml.safe_load` wuerde reichen, um zu lesen; zum Schreiben waere es falsch. Ein
    `yaml.dump` wirft die sechzig Zeilen Begruendung aus dieser Datei weg, und die sind
    mehr wert als die Bequemlichkeit. Also Zeilenarbeit, lesend wie schreibend dieselbe.
    """
    text = open(SPEZIFIKATION, encoding="utf-8").read()
    treffer = re.findall(rf'^\s*{schluessel}:\s*"([^"]*)"\s*$', text, re.M)
    if len(treffer) != 1:
        raise SystemExit(
            f"{os.path.relpath(SPEZIFIKATION, WURZEL)}: {schluessel} steht "
            f"{len(treffer)}-mal drin, erwartet war einmal."
        )
    return treffer[0]


def spezifikation_schreiben(schluessel: str, wert: str) -> None:
    text = open(SPEZIFIKATION, encoding="utf-8").read()
    neu, anzahl = re.subn(
        rf'^(\s*{schluessel}:\s*)"[^"]*"\s*$', rf'\g<1>"{wert}"', text, flags=re.M
    )
    if anzahl != 1:
        raise SystemExit(f"{schluessel}: {anzahl} Stellen ersetzt, erwartet war eine.")
    open(SPEZIFIKATION, "w", encoding="utf-8").write(neu)


def plist_lesen() -> dict:
    with open(PLIST, "rb") as datei:
        return plistlib.load(datei)


def plist_schreiben(inhalt: dict) -> None:
    """Die Plist zurueckschreiben, Byte fuer Byte so, wie XcodeGen sie schreibt.

    Nachgemessen: `plistlib.dumps(..., sort_keys=True)` auf die eingecheckte Datei ergibt
    genau dieselben Bytes. Das ist der Grund, warum hier geschrieben werden darf, ohne dass
    der naechste `xcodegen generate` einen Diff erzeugt.
    """
    with open(PLIST, "wb") as datei:
        plistlib.dump(inhalt, datei, sort_keys=True)


def zustand() -> tuple[str, str, str, str]:
    plist = plist_lesen()
    return (
        spezifikation_lesen(FASSUNG),
        spezifikation_lesen(BAU),
        str(plist.get(FASSUNG, "")),
        str(plist.get(BAU, "")),
    )


def setzen(schluessel: str, wert: str) -> None:
    spezifikation_schreiben(schluessel, wert)
    plist = plist_lesen()
    plist[schluessel] = wert
    plist_schreiben(plist)


def main() -> int:
    zerleger = argparse.ArgumentParser(
        description="Fassung und Baunummer der iOS-App stellen.",
        epilog="Ohne Argument wird nur gezeigt, was eingestellt ist.",
    )
    zerleger.add_argument("--hochzaehlen", action="store_true",
                         help="Baunummer um eins erhoehen")
    zerleger.add_argument("--bau", metavar="N", help="Baunummer auf N setzen")
    zerleger.add_argument("--fassung", metavar="X.Y", help="Fassung auf X.Y setzen")
    zerleger.add_argument("--pruefen", action="store_true",
                         help="nur melden, ob project.yml und Info.plist auseinanderlaufen")
    argumente = zerleger.parse_args()

    fassung_yml, bau_yml, fassung_plist, bau_plist = zustand()

    # Zuerst die Wache: auf einem Stand, der schon auseinanderlaeuft, wird nichts gestellt -
    # sonst schreibt dieses Werkzeug die Abweichung fest, statt sie zu zeigen.
    abweichungen = []
    if fassung_yml != fassung_plist:
        abweichungen.append(f"{FASSUNG}: project.yml {fassung_yml!r}, Info.plist {fassung_plist!r}")
    if bau_yml != bau_plist:
        abweichungen.append(f"{BAU}: project.yml {bau_yml!r}, Info.plist {bau_plist!r}")
    if abweichungen:
        print("project.yml und Info.plist laufen auseinander:", file=sys.stderr)
        for abweichung in abweichungen:
            print(f"  - {abweichung}", file=sys.stderr)
        print("\nBeheben mit:  cd apps/ios && xcodegen generate", file=sys.stderr)
        return 1

    if argumente.pruefen:
        print(f"Fassung {fassung_yml}, Bau {bau_yml} - in beiden Dateien gleich.")
        return 0

    if argumente.fassung:
        setzen(FASSUNG, argumente.fassung)
    if argumente.bau:
        setzen(BAU, argumente.bau)
    elif argumente.hochzaehlen:
        if not bau_yml.isdigit():
            print(f"Baunummer {bau_yml!r} ist keine Zahl - mit --bau N setzen.", file=sys.stderr)
            return 1
        setzen(BAU, str(int(bau_yml) + 1))

    fassung_neu, bau_neu, _, _ = zustand()
    if (fassung_neu, bau_neu) != (fassung_yml, bau_yml):
        print(f"Fassung {fassung_yml} ({bau_yml})  ->  {fassung_neu} ({bau_neu})")
        print("Beide Dateien geschrieben. Mit einchecken, damit das Repository sagt, "
              "was hochgeladen wurde.")
    else:
        print(f"Fassung {fassung_neu}, Bau {bau_neu}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
