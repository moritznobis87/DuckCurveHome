"""Was `tools/version.py` an `docs/versionen.json` verlangt.

Jede Regel hat einen Test, der fällt, wenn man sie aus dem Werkzeug nimmt. Die Datei des
Repositorys wird nur gelesen; alles, was schreibt, arbeitet unter `tmp_path`.
"""

from __future__ import annotations

import copy
import datetime as dt
import importlib.util
import json
from pathlib import Path
from typing import Any

import pytest

WERKZEUG = Path(__file__).resolve().parents[1] / "version.py"


def _laden():
    spezifikation = importlib.util.spec_from_file_location("version_werkzeug", WERKZEUG)
    assert spezifikation is not None and spezifikation.loader is not None
    modul = importlib.util.module_from_spec(spezifikation)
    spezifikation.loader.exec_module(modul)
    return modul


v = _laden()

SATZ = "Die Seite zeigt jetzt den Verlauf der letzten Tage."


def _daten(**ueber: Any) -> dict[str, Any]:
    daten: dict[str, Any] = {
        "unveroeffentlicht": [],
        "versionen": [
            {
                "version": "2026.11.2",
                "datum": "2026-11-28",
                "neuerungen": [{"bereich": "Energie", "text": SATZ}],
            },
            {
                "version": "2026.11.1",
                "datum": "2026-11-26",
                "neuerungen": [{"bereich": "Hausgerät", "text": SATZ}],
            },
        ],
    }
    daten.update(ueber)
    return daten


def _mit_text(text: str, bereich: str = "Energie") -> dict[str, Any]:
    return _daten(unveroeffentlicht=[{"bereich": bereich, "text": text}])


def test_die_datei_des_repositorys_ist_in_ordnung() -> None:
    assert v.pruefen(v.laden()) == []


def test_eine_saubere_datei_hat_keine_befunde() -> None:
    assert v.pruefen(_daten()) == []


@pytest.mark.parametrize(
    "version",
    ["2026.11", "2026.011.1", "2026.13.1", "2026.11.0", "26.11.1", "v2026.11.1", "2026.11.1-beta"],
)
def test_nur_jahr_monat_nummer_ist_eine_version(version: str) -> None:
    daten = _daten()
    daten["versionen"][1]["version"] = version
    assert v.pruefen(daten)


def test_jahr_und_monat_passen_zum_datum() -> None:
    daten = _daten()
    daten["versionen"][1]["datum"] = "2026-12-01"
    assert any("passen nicht zum Datum" in f for f in v.pruefen(daten))


def test_neueste_zuerst() -> None:
    daten = _daten()
    daten["versionen"].reverse()
    assert any("neueste zuerst" in f for f in v.pruefen(daten))


def test_nummern_ohne_luecke() -> None:
    daten = _daten()
    daten["versionen"][0]["version"] = "2026.11.3"
    assert any("ohne Lücke" in f for f in v.pruefen(daten))


def test_keine_version_ohne_neuerungen() -> None:
    daten = _daten()
    daten["versionen"][0]["neuerungen"] = []
    assert any("ohne Neuerungen" in f for f in v.pruefen(daten))


def test_unbekannter_bereich() -> None:
    assert any("unbekannter Bereich" in f for f in v.pruefen(_mit_text(SATZ, bereich="Backend")))


def test_bereiche_des_seitenbaums_gelten() -> None:
    assert {"Jetzt", "Haus", "Energie", "Geld", "Anlage", "Einstellen"} <= v.bereiche()


@pytest.mark.parametrize(
    ("text", "grund"),
    [
        ("Behebt den Fehler aus 66fc27c in der Anzeige.", "Commit-Hash"),
        ("Die Anzeige aus Nummer #48 ist wieder richtig.", "Pull Request"),
        ("Die Funktion `hochfahren` startet jetzt sauber.", "Code-Auszeichnung"),
        ("Die Datei Verlauf.tsx zeichnet jetzt im Rahmen.", "Dateinamen"),
        ("Merge des Zweigs mit den neuen Diagrammen erledigt.", "Entwicklung"),
        ("Ein Refactoring macht die Seite jetzt schneller.", "Entwicklung"),
        ("Hausgerät - Speicher jetzt messbar und richtig.", "Gedankenstrich"),
    ],
)
def test_interna_werden_abgewiesen(text: str, grund: str) -> None:
    assert any(grund in f for f in v.pruefen(_mit_text(text)))


@pytest.mark.parametrize(
    "text",
    [
        "kurz.",
        "die Seite zeigt jetzt den Verlauf der Tage.",
        "Die Seite zeigt jetzt den Verlauf der Tage",
    ],
)
def test_ganze_saetze(text: str) -> None:
    assert v.pruefen(_mit_text(text))


def test_hoechstens_dreihundert_zeichen() -> None:
    assert any(
        "300" in f for f in v.pruefen(_mit_text("Die Seite zeigt " + "sehr " * 70 + "viel."))
    )


def test_nur_bereich_und_text() -> None:
    daten = _daten(unveroeffentlicht=[{"bereich": "Energie", "text": SATZ, "pr": 48}])
    assert any("genau die Felder" in f for f in v.pruefen(daten))


def test_naechste_nummer_im_selben_monat() -> None:
    assert v.naechste(_daten(), dt.date(2026, 11, 30)) == "2026.11.3"


def test_neuer_monat_beginnt_bei_eins() -> None:
    assert v.naechste(_daten(), dt.date(2027, 1, 5)) == "2027.1.1"


def test_veroeffentlichen_verschiebt_das_unveroeffentlichte(tmp_path: Path) -> None:
    datei = tmp_path / "versionen.json"
    datei.write_text(json.dumps(_mit_text(SATZ)), encoding="utf-8")
    assert v.main(["--datei", str(datei), "--veroeffentlichen", "--datum", "2026-12-02"]) == 0
    daten = json.loads(datei.read_text(encoding="utf-8"))
    assert daten["unveroeffentlicht"] == []
    assert daten["versionen"][0] == {
        "version": "2026.12.1",
        "datum": "2026-12-02",
        "neuerungen": [{"bereich": "Energie", "text": SATZ}],
    }
    assert v.pruefen(daten) == []


def test_ohne_unveroeffentlichtes_keine_version(tmp_path: Path) -> None:
    datei = tmp_path / "versionen.json"
    datei.write_text(json.dumps(_daten()), encoding="utf-8")
    vorher = datei.read_text(encoding="utf-8")
    assert v.main(["--datei", str(datei), "--veroeffentlichen"]) == 1
    assert datei.read_text(encoding="utf-8") == vorher


def test_notizen_als_markdown() -> None:
    text = v.notizen(_daten(), "2026.11.1")
    assert text.startswith("Version 2026.11.1 vom 26.11.2026\n")
    assert f"- **Hausgerät:** {SATZ}" in text


def test_pruefen_meldet_ueber_den_rueckgabewert(tmp_path: Path) -> None:
    datei = tmp_path / "versionen.json"
    kaputt = copy.deepcopy(_daten())
    kaputt["versionen"][0]["version"] = "2026.11"
    datei.write_text(json.dumps(kaputt), encoding="utf-8")
    assert v.main(["--datei", str(datei), "--pruefen"]) == 1
