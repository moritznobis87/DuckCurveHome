"""„K1" steht in keinem Text, den der Dienst ausgibt.

K1 ist die Bezeichnung des Schaltkontakts im Schaltplan, über den die Regelung bei der Wärmepumpe
Wärme anfordert. Im Quelltext, in Kommentaren und Docstrings ist das der richtige Name. In Sätzen,
die bis in die Oberfläche reichen, versteht ihn niemand (Nutzer am 10.11.2026: „Kein Mensch
versteht, was mit K1 gemeint ist"). Dort heißt es „Anforderung".

Geprüft werden alle Zeichenketten im Quelltext, die keine Docstrings sind. Das ist strenger als
nötig, denn auch Protokollzeilen fallen darunter; dafür braucht der Test keine Liste der Felder,
die Nutzer sehen, und die wäre beim nächsten neuen Feld veraltet.
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

WURZEL = Path(__file__).resolve().parents[3]
ORDNER = ("apps/api/src", "packages/hems-core/src", "apps/bridge/src")
VERBOTEN = re.compile(r"\bK1\b|Freigabekontakt|Schließvorg")


def _texte(pfad: Path) -> list[tuple[int, str]]:
    baum = ast.parse(pfad.read_text(encoding="utf-8"))
    # Eine Zeichenkette als eigene Anweisung ist ein Docstring, am Modul, an einer Klasse, an
    # einer Funktion oder unter einem Attribut.
    docstrings = {
        id(k.value)
        for k in ast.walk(baum)
        if isinstance(k, ast.Expr)
        and isinstance(k.value, ast.Constant)
        and isinstance(k.value.value, str)
    }
    return [
        (k.lineno, k.value)
        for k in ast.walk(baum)
        if isinstance(k, ast.Constant) and isinstance(k.value, str) and id(k) not in docstrings
    ]


def test_kein_text_nennt_den_kontakt_beim_namen_aus_dem_schaltplan() -> None:
    funde = [
        f"{pfad.relative_to(WURZEL)}:{zeile}: {text[:100]!r}"
        for ordner in ORDNER
        for pfad in sorted((WURZEL / ordner).rglob("*.py"))
        for zeile, text in _texte(pfad)
        if VERBOTEN.search(text)
    ]
    assert funde == []


def test_der_waechter_findet_was_er_finden_soll() -> None:
    assert VERBOTEN.search("Die Maschine folgt K1.")
    assert VERBOTEN.search("3 Schließvorgänge")
    assert VERBOTEN.search("der Freigabekontakt")
    assert not VERBOTEN.search("Die Maschine folgt der Anforderung.")
    assert not VERBOTEN.search("PK1234"), "nur das Wort, nicht jede Zeichenfolge"
