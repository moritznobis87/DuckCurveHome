#!/usr/bin/env python3
"""Versionen und Neuerungen von Duck Curve Home - eine Datei, ein Werkzeug.

**Was hier steht, lesen Außenstehende.** Die Neuerungen aus `docs/versionen.json` erscheinen
auf der Seite Hausgerät im Dashboard und in der App, wenn ein Update bereitsteht, und als
Beschreibung der Veröffentlichung auf GitHub. Sie sagen in ganzen Sätzen, was sich in welchem
Bereich geändert hat. Commit-Titel, Dateinamen, Hashes und interne Begriffe gehören nicht
hinein; `--pruefen` weist sie ab (Festlegung des Hausherrn vom 26.11.2026).

**Das Schema der Versionen ist Jahr.Monat.laufende Nummer**, etwa `2026.11.1` für die erste
Version im November 2026. Der Monat steht ohne führende Null (`2027.1.1`), die Nummer beginnt in
jedem Monat bei 1 und zählt ohne Lücke hoch.

**Versionen entstehen gebündelt.** Jeder Pull Request mit einer Wirkung, die Nutzer bemerken,
trägt seine Sätze unter `unveroeffentlicht` ein. Eine Version entsteht erst mit
`--veroeffentlichen`: Das verschiebt die gesammelten Sätze in einen neuen Eintrag mit dem
heutigen Datum. Ist dieser Stand auf `main`, baut die CI die Images, versieht sie mit der
Version und dem Kanal `stabil`, setzt das Git-Tag `v<version>` und legt die Veröffentlichung auf
GitHub an (`.github/workflows/docker.yml`).

    tools/version.py                      # aktuelle Version und was noch unveröffentlicht ist
    tools/version.py --pruefen            # ist die Datei in Ordnung? (CI)
    tools/version.py --aktuell            # nur die neueste Version (CI)
    tools/version.py --notizen 2026.11.1  # Neuerungen einer Version als Markdown (CI)
    tools/version.py --veroeffentlichen   # aus dem Unveröffentlichten eine Version machen
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
from typing import Any

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATEI = os.path.join(WURZEL, "docs", "versionen.json")
SEITENBAUM = os.path.join(WURZEL, "docs", "seitenbaum.json")

VERSION = re.compile(r"^(?P<jahr>\d{4})\.(?P<monat>1[0-2]|[1-9])\.(?P<nummer>[1-9]\d*)$")

#: Bereiche neben denen des Seitenbaums: Teile, die keine eigene Seite sind oder quer liegen.
WEITERE_BEREICHE = (
    "Hausgerät",
    "Updates",
    "Anmeldung",
    "Alfred",
    "Mitteilungen",
    "App",
    "Allgemein",
)

#: Was in einem Satz für Außenstehende nichts verloren hat, und warum.
VERBOTEN: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"\b[0-9a-f]{7,40}\b"), "sieht aus wie ein Commit-Hash"),
    (re.compile(r"#\d+"), "verweist auf einen Pull Request oder ein Issue"),
    (re.compile(r"`"), "enthält Code-Auszeichnung"),
    (
        re.compile(r"\b[\w.-]+\.(py|ts|tsx|swift|sh|json|ya?ml|md|toml|sql)\b", re.IGNORECASE),
        "nennt einen Dateinamen",
    ),
    (
        re.compile(
            r"\b(commit|merge|pull request|codex|claude|refactor\w*|fix(es|ed)?)\b", re.IGNORECASE
        ),
        "benutzt einen Begriff aus der Entwicklung",
    ),
    (re.compile(r"\s[-–—]\s"), "hängt Wörter an einen Gedankenstrich statt einen Satz zu bilden"),
)


class Fehler(Exception):  # noqa: N818 - eine Meldung an den Menschen, kein Programmfehler
    pass


def schluessel(version: str) -> tuple[int, int, int]:
    treffer = VERSION.fullmatch(version)
    if not treffer:
        raise Fehler(f"„{version}“ ist keine Version nach Jahr.Monat.Nummer (etwa 2026.11.1)")
    return int(treffer["jahr"]), int(treffer["monat"]), int(treffer["nummer"])


def bereiche() -> set[str]:
    try:
        with open(SEITENBAUM, encoding="utf-8") as f:
            baum = json.load(f)
        aus_baum = {
            b["name"] for b in baum.get("bereiche", []) if isinstance(b, dict) and b.get("name")
        }
    except (OSError, ValueError, KeyError):
        aus_baum = set()
    return aus_baum | set(WEITERE_BEREICHE)


def laden(pfad: str = DATEI) -> dict[str, Any]:
    with open(pfad, encoding="utf-8") as f:
        return json.load(f)


def speichern(daten: dict[str, Any], pfad: str = DATEI) -> None:
    with open(pfad, "w", encoding="utf-8") as f:
        json.dump(daten, f, ensure_ascii=False, indent=2)
        f.write("\n")


def _neuerungen_pruefen(liste: Any, wo: str, erlaubt: set[str]) -> list[str]:
    fehler: list[str] = []
    if not isinstance(liste, list):
        return [f"{wo}: die Neuerungen müssen eine Liste sein"]
    for i, n in enumerate(liste, 1):
        stelle = f"{wo}, Neuerung {i}"
        if not isinstance(n, dict) or set(n) != {"bereich", "text"}:
            fehler.append(f"{stelle}: genau die Felder „bereich“ und „text“ erwartet")
            continue
        bereich, text = n["bereich"], n["text"]
        if bereich not in erlaubt:
            fehler.append(
                f"{stelle}: unbekannter Bereich „{bereich}“ (erlaubt: {', '.join(sorted(erlaubt))})"
            )
        if not isinstance(text, str) or len(text.strip()) < 20:
            fehler.append(f"{stelle}: der Text muss ein ganzer Satz sein")
            continue
        if text != text.strip() or not text[0].isupper() or text[-1] not in ".!":
            fehler.append(f"{stelle}: ein Satz beginnt groß und endet mit einem Punkt")
        if len(text) > 300:
            fehler.append(
                f"{stelle}: höchstens 300 Zeichen; was mehr braucht, gehört in zwei Neuerungen"
            )
        for muster, grund in VERBOTEN:
            if muster.search(text):
                fehler.append(f"{stelle}: „{text}“ {grund}")
    return fehler


def pruefen(daten: dict[str, Any]) -> list[str]:
    """Alles, was an der Datei nicht stimmt; leer, wenn sie in Ordnung ist."""
    fehler: list[str] = []
    erlaubt = bereiche()
    if set(daten) != {"unveroeffentlicht", "versionen"}:
        return ["die Datei hat genau die Schlüssel „unveroeffentlicht“ und „versionen“"]
    fehler += _neuerungen_pruefen(daten["unveroeffentlicht"], "Unveröffentlicht", erlaubt)
    versionen = daten["versionen"]
    if not isinstance(versionen, list) or not versionen:
        return [*fehler, "es muss mindestens eine Version geben"]
    gesehen: list[tuple[int, int, int]] = []
    for v in versionen:
        if not isinstance(v, dict) or set(v) != {"version", "datum", "neuerungen"}:
            fehler.append(f"{v!r}: genau die Felder „version“, „datum“ und „neuerungen“ erwartet")
            continue
        wo = f"Version {v['version']}"
        try:
            k = schluessel(v["version"])
        except Fehler as e:
            fehler.append(str(e))
            continue
        try:
            datum = dt.date.fromisoformat(v["datum"])
        except (TypeError, ValueError):
            fehler.append(f"{wo}: das Datum muss JJJJ-MM-TT sein")
        else:
            if (datum.year, datum.month) != k[:2]:
                fehler.append(f"{wo}: Jahr und Monat passen nicht zum Datum {v['datum']}")
        if not v["neuerungen"]:
            fehler.append(f"{wo}: eine Version ohne Neuerungen gibt es nicht")
        fehler += _neuerungen_pruefen(v["neuerungen"], wo, erlaubt)
        gesehen.append(k)
    if gesehen != sorted(gesehen, reverse=True) or len(set(gesehen)) != len(gesehen):
        fehler.append("die Versionen stehen neueste zuerst, und jede nur einmal")
    je_monat: dict[tuple[int, int], list[int]] = {}
    for jahr, monat, nummer in gesehen:
        je_monat.setdefault((jahr, monat), []).append(nummer)
    for (jahr, monat), nummern in je_monat.items():
        if sorted(nummern) != list(range(1, len(nummern) + 1)):
            fehler.append(
                f"{jahr}.{monat}: die Nummern zählen von 1 ohne Lücke hoch, gefunden {sorted(nummern)}"
            )
    return fehler


def aktuell(daten: dict[str, Any]) -> str:
    return str(daten["versionen"][0]["version"])


def naechste(daten: dict[str, Any], heute: dt.date) -> str:
    gleicher_monat = [
        schluessel(v["version"])[2]
        for v in daten["versionen"]
        if schluessel(v["version"])[:2] == (heute.year, heute.month)
    ]
    return f"{heute.year}.{heute.month}.{max(gleicher_monat, default=0) + 1}"


def veroeffentlichen(daten: dict[str, Any], heute: dt.date) -> str:
    if not daten["unveroeffentlicht"]:
        raise Fehler(
            "Unter „unveroeffentlicht“ steht nichts; eine Version ohne Neuerungen gibt es nicht."
        )
    version = naechste(daten, heute)
    daten["versionen"].insert(
        0,
        {"version": version, "datum": heute.isoformat(), "neuerungen": daten["unveroeffentlicht"]},
    )
    daten["unveroeffentlicht"] = []
    return version


def notizen(daten: dict[str, Any], version: str) -> str:
    for v in daten["versionen"]:
        if v["version"] == version:
            datum = dt.date.fromisoformat(v["datum"]).strftime("%d.%m.%Y")
            zeilen = [f"Version {version} vom {datum}", ""]
            zeilen += [f"- **{n['bereich']}:** {n['text']}" for n in v["neuerungen"]]
            return "\n".join(zeilen) + "\n"
    raise Fehler(f"Version {version} steht nicht in {os.path.relpath(DATEI, WURZEL)}")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    gruppe = p.add_mutually_exclusive_group()
    gruppe.add_argument("--pruefen", action="store_true")
    gruppe.add_argument("--aktuell", action="store_true")
    gruppe.add_argument("--notizen", metavar="VERSION")
    gruppe.add_argument("--veroeffentlichen", action="store_true")
    p.add_argument("--datei", default=DATEI, help=argparse.SUPPRESS)
    p.add_argument("--datum", help="Datum der neuen Version (JJJJ-MM-TT), Vorgabe heute")
    a = p.parse_args(argv)
    try:
        daten = laden(a.datei)
        befund = pruefen(daten)
        if a.pruefen:
            for f in befund:
                print(f"versionen.json: {f}", file=sys.stderr)
            return 1 if befund else 0
        if befund:
            raise Fehler(f"die Datei ist nicht in Ordnung ({len(befund)} Befunde); erst --pruefen")
        if a.aktuell:
            print(aktuell(daten))
        elif a.notizen:
            print(notizen(daten, a.notizen), end="")
        elif a.veroeffentlichen:
            heute = dt.date.fromisoformat(a.datum) if a.datum else dt.date.today()
            version = veroeffentlichen(daten, heute)
            speichern(daten, a.datei)
            print(
                f"Version {version} angelegt. Nach dem Merge auf main baut die CI sie und legt die Veröffentlichung an."
            )
        else:
            offen = len(daten["unveroeffentlicht"])
            print(
                f"Aktuell: {aktuell(daten)}. Unveröffentlicht: {offen} {'Neuerung' if offen == 1 else 'Neuerungen'}."
            )
    except Fehler as e:
        print(f"version: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
