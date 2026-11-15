"""
Nachschlagen in den eigenen Methodenpapieren (docs/ALFRED.md).

Sucht zu einem Stichwort die passenden Abschnitte der freigegebenen Papiere, damit Alfred die
Methodik zitieren und ihre Quelle nennen kann, statt sie zu schaetzen.

`PAPIERE` ist eine Positivliste und damit die Sicherheitsgrenze. Im Repository stehen auch
Betriebspapiere - DEPLOYMENT.md und CONFIGURATION.md mit Umgebungsvariablen und dem Umgang mit
Schluesseln, OPEN_QUESTIONS.md mit Entscheidungen des Hausherrn, TUEROEFFNUNG.md mit dem Zutritt -,
die weder in eine Antwort noch in eine Anfrage an einen fremden Anbieter gehoeren. Ein neu
angelegtes Papier ist deshalb zunaechst nicht erreichbar.

Kein RAG: Bewertet wird, wie viele der gesuchten Woerter in Ueberschrift (doppelt) und Text eines
Abschnitts vorkommen. Das ist erklaerbar und reicht fuer eine Handvoll Papiere.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

#: Hoechstlaenge eines zurueckgegebenen Abschnitts in Zeichen.
ABSCHNITT_MAX = 2500

#: Hoechstzahl der Abschnitte je Suche.
TREFFER_MAX = 3

_FUELLWOERTER = frozenset(
    {
        "der",
        "die",
        "das",
        "und",
        "oder",
        "ist",
        "sind",
        "ein",
        "eine",
        "von",
        "fuer",
        "für",
        "mit",
        "auf",
        "bei",
        "dem",
        "den",
        "des",
        "was",
        "wie",
        "wo",
        "wer",
        "warum",
        "ich",
        "wir",
        "man",
        "sich",
        "nicht",
        "auch",
        "nur",
        "im",
        "in",
        "zu",
        "an",
        "es",
        "als",
        "wird",
        "werden",
        "wieso",
        "weshalb",
    }
)


@dataclass(frozen=True)
class Papier:
    titel: str
    #: Pfad relativ zur Wurzel des Repositories.
    pfad: str


#: Freigegebene Papiere. Nicht darin und damit nicht lesbar: alles, was Betrieb, Zugang,
#: Schluessel, Personen oder offene Entscheidungen beschreibt (siehe oben).
PAPIERE: tuple[Papier, ...] = (
    Papier("Regelung der Waermepumpe", "HEMS_CONTROL.md"),
    Papier("Wirkung der Anforderung", "docs/K1_WIRKUNG.md"),
    Papier("Nachbetrachtung", "docs/NACHBETRACHTUNG.md"),
    Papier("Ofen-Optimierung", "docs/OFEN_OPTIMIERUNG.md"),
    Papier("PV-Abrechnung", "docs/PV_ABRECHNUNG.md"),
    Papier("Prognose und Waermemodell", "docs/design/prognose-und-waermemodell.md"),
)


@dataclass(frozen=True)
class Fundstelle:
    papier: str
    ueberschrift: str
    text: str


def _woerter(text: str) -> set[str]:
    return {
        w for w in re.findall(r"[\wäöüß]+", text.lower()) if len(w) > 2 and w not in _FUELLWOERTER
    }


def _abschnitte(inhalt: str) -> list[tuple[str, str]]:
    """Paare (Ueberschrift, Text), getrennt an jeder Ueberschriftenebene; leere verworfen.

    Codebloecke werden uebersprungen, damit ein `#` in einem Kommentar keine Ueberschrift wird.
    """
    teile: list[tuple[str, str]] = []
    ueberschrift = "Anfang"
    zeilen: list[str] = []
    im_code = False
    for zeile in inhalt.splitlines():
        if zeile.lstrip().startswith("```"):
            im_code = not im_code
            zeilen.append(zeile)
            continue
        if not im_code and zeile.startswith("#"):
            if zeilen:
                teile.append((ueberschrift, "\n".join(zeilen).strip()))
            ueberschrift = zeile.lstrip("#").strip()
            zeilen = []
        else:
            zeilen.append(zeile)
    if zeilen:
        teile.append((ueberschrift, "\n".join(zeilen).strip()))
    return [(u, t) for u, t in teile if t]


def wurzel() -> Path:
    """Die Wurzel des Repositories (lokal) bzw. /app (im Abbild): das erste Verzeichnis aufwaerts,
    in dem `docs/` liegt."""
    hier = Path(__file__).resolve()
    for kandidat in hier.parents:
        if (kandidat / "docs").is_dir():
            return kandidat
    return hier.parents[-1]


def nachschlagen(stichwort: str, basis: Path | None = None) -> list[Fundstelle]:
    gesucht = _woerter(stichwort)
    if not gesucht:
        return []
    basis = basis or wurzel()
    bewertet: list[tuple[int, Fundstelle]] = []
    for papier in PAPIERE:
        datei = basis / papier.pfad
        if not datei.is_file():
            continue
        for ueberschrift, text in _abschnitte(datei.read_text(encoding="utf-8")):
            punkte = 2 * len(gesucht & _woerter(ueberschrift)) + len(gesucht & _woerter(text))
            if punkte:
                bewertet.append(
                    (punkte, Fundstelle(papier.titel, ueberschrift, text[:ABSCHNITT_MAX]))
                )
    bewertet.sort(key=lambda p: p[0], reverse=True)
    return [f for _, f in bewertet[:TREFFER_MAX]]
