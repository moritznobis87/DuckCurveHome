"""Was die Fassungspruefung verlangt - und was sie absichtlich durchlaesst.

Jede Regel aus `tools/addon-fassung-pruefen.py` hat hier einen Test, und zwar einen, der faellt,
wenn man die Regel aus dem Werkzeug herausnimmt. Eine Regel ohne fallenden Test ist keine Regel,
sondern eine Absichtserklaerung.

Die Pruefung liest aus zwei Baeumen (Basis und Kopf). Im Betrieb sind das Git-Revisionen; hier
sind es zwei Ordner unter `tmp_path`. Deshalb braucht kein Test ein Repository, und keiner fasst
das echte Repository an - bis auf die drei, die den Vergleichspunkt bestimmen, und die lesen nur.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import pytest

WERKZEUG = Path(__file__).resolve().parents[1] / "addon-fassung-pruefen.py"


def _werkzeug_laden():
    """Das Werkzeug heisst mit Bindestrich und ist darum nicht importierbar - also von Hand.

    Der Name mit Bindestrich ist Absicht: so heissen die Werkzeuge in `tools/` alle, weil sie
    von der Kommandozeile aufgerufen werden und nicht als Modul.
    """
    spezifikation = importlib.util.spec_from_file_location("addon_fassung_pruefen", WERKZEUG)
    assert spezifikation is not None and spezifikation.loader is not None
    modul = importlib.util.module_from_spec(spezifikation)
    spezifikation.loader.exec_module(modul)
    return modul


pruefer = _werkzeug_laden()


# Ein Grundstand mit zwei Add-ons, so wie das Repository ihn hat.
GRUNDSTAND = {
    "addons/duckcurve_bridge/config.yaml": 'name: Bridge\nversion: "0.15.1"\nslug: duckcurve_bridge\n',
    "addons/duckcurve_bridge/run.sh": "#!/usr/bin/with-contenv bashio\n",
    "addons/duckcurve_ebusd/config.yaml": 'name: eBUS\nversion: "0.5.0"\nslug: duckcurve_ebusd\n',
    "addons/duckcurve_ebusd/run.sh": "#!/usr/bin/with-contenv bashio\n",
    "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.1'\n",
    "packages/hems-core/src/hems_core/regelung.py": "SCHWELLE = 4.0\n",
}


def _baum_anlegen(wurzel: Path, dateien: dict[str, str]):
    for pfad, inhalt in dateien.items():
        ziel = wurzel / pfad
        ziel.parent.mkdir(parents=True, exist_ok=True)
        ziel.write_text(inhalt, encoding="utf-8")
    return pruefer.OrdnerBaum(str(wurzel))


def _vergleich(tmp_path: Path, aenderungen: dict[str, str | None], *, basis_zusatz=None):
    """Basis aus dem Grundstand, Kopf mit den angegebenen Aenderungen - dann pruefen.

    Ein Wert `None` heisst: die Datei ist im Kopf geloescht. Die Liste der geaenderten Pfade
    ergibt sich aus den Schluesseln; so steht in jedem Test ausdruecklich da, was `git diff`
    gemeldet haette.
    """
    basis_dateien = dict(GRUNDSTAND)
    basis_dateien.update(basis_zusatz or {})
    basis = _baum_anlegen(tmp_path / "basis", basis_dateien)

    kopf_dateien = dict(basis_dateien)
    for pfad, inhalt in aenderungen.items():
        if inhalt is None:
            kopf_dateien.pop(pfad, None)
        else:
            kopf_dateien[pfad] = inhalt
    kopf = _baum_anlegen(tmp_path / "kopf", kopf_dateien)

    return pruefer.pruefen(basis, kopf, list(aenderungen))


def _fassung(nummer: str) -> str:
    return f'name: Bridge\nversion: "{nummer}"\nslug: duckcurve_bridge\n'


# -------------------------------------------------- was fallen muss: die Pflicht


def test_bridge_code_ohne_anhebung_faellt(tmp_path: Path) -> None:
    """Der eigentliche Anlass: `apps/bridge/src` geaendert, Nummer stehen gelassen.

    Zweimal in 60 Tagen passiert (gemessen im git log am 23.11.2026). Verloren ging dabei
    nichts - das Abbild wird aus `main` gebaut, nicht aus dem anhebenden Commit, also faehrt
    solcher Code mit der naechsten Anhebung mit. Genau das ist der Grund fuer diese Pflicht:
    ungebuendelt und von niemandem entschieden ausgeliefert, und im Changelog jener Fassung
    steht davon nichts. Die Herleitung steht im Modul-Docstring des Werkzeugs.
    """
    befunde = _vergleich(
        tmp_path, {"apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.1'\n# neu\n"}
    )
    assert len(befunde) == 1
    assert "duckcurve_bridge" in befunde[0]


def test_addon_ordner_ohne_anhebung_faellt(tmp_path: Path) -> None:
    """`run.sh` wird vom Dockerfile kopiert - sie aendert das Abbild."""
    befunde = _vergleich(tmp_path, {"addons/duckcurve_bridge/run.sh": "#!/bin/sh\necho neu\n"})
    assert len(befunde) == 1


def test_bridge_pyproject_ohne_anhebung_faellt(tmp_path: Path) -> None:
    """Die Abhaengigkeiten der Bridge stehen darin; `pip install` liest sie beim Bau."""
    befunde = _vergleich(tmp_path, {"apps/bridge/pyproject.toml": "[project]\nname='dch-bridge'\n"})
    assert len(befunde) == 1


def test_ebusd_ordner_ohne_anhebung_faellt(tmp_path: Path) -> None:
    """Das zweite Add-on hat seine eigene Nummer und seine eigene Pflicht."""
    befunde = _vergleich(tmp_path, {"addons/duckcurve_ebusd/aerotop_split.csv": "neu\n"})
    assert len(befunde) == 1
    assert "duckcurve_ebusd" in befunde[0]


def test_dockerfile_ohne_anhebung_faellt(tmp_path: Path) -> None:
    befunde = _vergleich(tmp_path, {"addons/duckcurve_bridge/Dockerfile": "FROM scratch\n"})
    assert len(befunde) == 1


def test_herabsetzen_faellt(tmp_path: Path) -> None:
    """Die Fassung muss steigen, nicht nur abweichen.

    Ein Herabsetzen ist fuer Home Assistant kein Update: der Supervisor bietet nur eine
    *hoehere* Nummer an. Eine Pruefung auf `!=` haette das durchgelassen.
    """
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.0"),
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.0'\n",
        },
    )
    assert len(befunde) == 1
    assert "nicht hoeher" in befunde[0]


def test_gleiche_fassung_mit_anderer_schreibweise_faellt(tmp_path: Path) -> None:
    """`0.15.1.0` ist dieselbe Fassung wie `0.15.1` - auffuellen mit Nullen, nicht laenger."""
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.1.0"),
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.1'\n# neu\n",
        },
    )
    assert len(befunde) == 1


# ------------------------------------------- was nicht fallen darf: die Ausnahmen


def test_anhebung_genuegt(tmp_path: Path) -> None:
    befunde = _vergleich(
        tmp_path,
        {
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.2'\n",
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.2"),
        },
    )
    assert befunde == []


def test_zahlenvergleich_statt_zeichenkette(tmp_path: Path) -> None:
    """0.9.0 -> 0.10.0 ist eine Anhebung.

    Als Zeichenketten verglichen waere `"0.10.0" > "0.9.0"` falsch, weil `1` vor `9` kommt. Die
    Bridge stand im September bei 0.9.x; dieser Fall ist also schon einmal eingetreten.
    """
    befunde = _vergleich(
        tmp_path,
        {
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.10.0'\n",
            "addons/duckcurve_bridge/config.yaml": _fassung("0.10.0"),
        },
        basis_zusatz={"addons/duckcurve_bridge/config.yaml": _fassung("0.9.0")},
    )
    assert befunde == []


def test_changelog_allein_loest_keine_pflicht_aus(tmp_path: Path) -> None:
    """Der Zirkel, den diese Ausnahme bricht.

    Waere die CHANGELOG.md beobachtet, verlangte der Eintrag fuer 0.15.2 eine Anhebung auf
    0.15.3, deren Eintrag eine auf 0.15.4 - die Pflicht liesse sich nie erfuellen.
    """
    befunde = _vergleich(
        tmp_path,
        {"addons/duckcurve_bridge/CHANGELOG.md": "# Changelog\n\n## 0.15.1\n\n- irgendwas\n"},
    )
    assert befunde == []


@pytest.mark.parametrize(
    "datei",
    ["DOCS.md", "icon.png", "logo.png", "entities.example.yaml"],
)
def test_darstellung_loest_keine_pflicht_aus(tmp_path: Path, datei: str) -> None:
    """Kein `COPY` im Dockerfile fasst diese Dateien an; der Store zeigt sie aus dem Zweig."""
    befunde = _vergleich(tmp_path, {f"addons/duckcurve_bridge/{datei}": "geaendert\n"})
    assert befunde == []


def test_hems_core_wird_nicht_beobachtet(tmp_path: Path) -> None:
    """Die bewusste Luecke, festgehalten als Test, damit sie nicht aus Versehen zugeht.

    Der Dockerfile installiert hems-core mit; nach der Messung vom 23.11.2026 haetten aber 28
    Commits in 60 Tagen angeschlagen, ohne die Fassung anzuheben (gezaehlt als Commits, nicht
    als CI-Laeufe, und nicht jeder davon zu Unrecht). Der Preis steht im Modul-Docstring des
    Werkzeugs: eine Aenderung allein in hems-core erreicht das Haus erst mit der naechsten
    Bridge-Anhebung. Wer diese Entscheidung umdreht, muss diesen Test anfassen und liest dabei,
    was sie kostet.
    """
    befunde = _vergleich(
        tmp_path, {"packages/hems-core/src/hems_core/regelung.py": "SCHWELLE = 5.0\n"}
    )
    assert befunde == []


def test_bridge_tests_loesen_keine_pflicht_aus(tmp_path: Path) -> None:
    """Die Grenze innerhalb `apps/bridge/`: beobachtet ist `src/` und `pyproject.toml`, nicht alles.

    Dieser Test bewacht die teure Richtung. `apps/bridge/tests/**` geht in kein Abbild - das
    Dockerfile installiert `"dch-bridge @ git+..."`, und Tests liegen nicht im installierten
    Paket. Wer die Liste in ZUSATZPFADE auf `apps/bridge/` verbreitert, verlangt fuer jede
    Testaenderung eine Fassungsanhebung. Die Verwechslung liegt nahe, weil der Pfadfilter des
    Ablaufs `apps/bridge/**` schreibt - er entscheidet nur, ob der Ablauf startet, nicht was
    beobachtet ist.
    """
    befunde = _vergleich(
        tmp_path, {"apps/bridge/tests/test_irgendwas.py": "def test_neu() -> None:\n    pass\n"}
    )
    assert befunde == []


def test_unterordner_im_addon_wird_beobachtet(tmp_path: Path) -> None:
    """Die Ausnahmen gelten fuer Dateien, nicht fuer Namen irgendwo im Baum.

    Heute hat kein Add-on Unterordner, darum faellt das sonst niemandem auf. Add-ons fuer Home
    Assistant legen ueblicherweise `rootfs/` an, und alles darin geht per `COPY` ins Abbild. Der
    Test haelt zweierlei fest: ein Unterordner ist beobachtet, und ein ausgenommener Name tief
    im Baum (`rootfs/DOCS.md`) ist es ebenfalls - ausgenommen ist nur `DOCS.md` direkt im
    Add-on-Ordner, denn nur die zeigt der Supervisor an.
    """
    befunde = _vergleich(tmp_path, {"addons/duckcurve_bridge/rootfs/etc/dienst.conf": "an = 1\n"})
    assert len(befunde) == 1
    assert "duckcurve_bridge" in befunde[0]

    tief = _vergleich(tmp_path, {"addons/duckcurve_bridge/rootfs/DOCS.md": "# im Abbild\n"})
    assert len(tief) == 1


def test_anhebung_und_eingebaute_nummer_in_einer_aenderung_genuegt(tmp_path: Path) -> None:
    """Das Etikett in `config.yaml` und `VERSION` im Code gehoeren in dieselbe Aenderung.

    `apps/bridge/tests/test_addon_optionen.py::test_die_eingebaute_nummer_folgt_dem_etikett`
    verlangt, dass beide gleich sind. Wer getrennt anhebt und nachzieht, faellt hier zu Recht -
    so entstand der einzige echte Fehlalarm der letzten 60 Tage (`d97bbe4`). Zusammen faellt
    nichts, und dieser Test haelt das fest, damit niemand die Pflicht dafuer aufweicht.
    """
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.2"),
            "addons/duckcurve_bridge/CHANGELOG.md": "# Aenderungen\n\n## 0.15.2\n\n- neu\n",
            "apps/bridge/src/dch_bridge/main.py": 'VERSION = "0.15.2"\n',
        },
    )
    assert befunde == []


def test_uebersprungenes_addon_wird_gemeldet(tmp_path: Path) -> None:
    """Ein Loch, das man liest, ist ein anderes als eines, das keiner sieht.

    Wer `config.yaml` im Kopf loescht (oder den Ordner umbenennt), faellt nicht - das Add-on
    steht dann in `kopf.addons()` nicht mehr. Das bricht das Add-on und ist kein realistischer
    Ausweg, aber stumm bleiben darf es nicht.
    """
    basis = _baum_anlegen(tmp_path / "basis", dict(GRUNDSTAND))
    kopf_dateien = dict(GRUNDSTAND)
    kopf_dateien.pop("addons/duckcurve_bridge/config.yaml")
    kopf = _baum_anlegen(tmp_path / "kopf", kopf_dateien)

    notizen: list[str] = []
    befunde = pruefer.pruefen(
        basis,
        kopf,
        ["addons/duckcurve_bridge/config.yaml", "apps/bridge/src/dch_bridge/main.py"],
        notizen,
    )
    assert befunde == []
    assert len(notizen) == 1
    assert "duckcurve_bridge" in notizen[0]
    assert "nicht geprueft" in notizen[0]


def test_ohne_beobachtete_aenderung_keine_notiz(tmp_path: Path) -> None:
    """Die Notiz ist ein Hinweis, kein Rauschen: ohne beobachtete Aenderung bleibt sie weg."""
    basis = _baum_anlegen(tmp_path / "basis", dict(GRUNDSTAND))
    kopf_dateien = dict(GRUNDSTAND)
    kopf_dateien.pop("addons/duckcurve_bridge/config.yaml")
    kopf = _baum_anlegen(tmp_path / "kopf", kopf_dateien)

    notizen: list[str] = []
    pruefer.pruefen(basis, kopf, ["docs/IRGENDWAS.md"], notizen)
    assert notizen == []


def test_nur_die_fassung_angehoben_faellt_nicht(tmp_path: Path) -> None:
    """Eine Anhebung ohne weitere Aenderung ist in Ordnung - ein Neubau auf Wunsch."""
    befunde = _vergleich(tmp_path, {"addons/duckcurve_bridge/config.yaml": _fassung("0.15.2")})
    assert befunde == []


def test_neues_addon_faellt_nicht(tmp_path: Path) -> None:
    """Es gibt keine Vorgaengerfassung, gegen die etwas steigen koennte."""
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_neu/config.yaml": 'name: Neu\nversion: "0.1.0"\nslug: duckcurve_neu\n',
            "addons/duckcurve_neu/run.sh": "#!/bin/sh\n",
        },
    )
    assert befunde == []


def test_geloeschtes_addon_faellt_nicht(tmp_path: Path) -> None:
    """Ein Abbild, das nicht mehr gebaut wird, braucht keine neue Nummer."""
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_ebusd/config.yaml": None,
            "addons/duckcurve_ebusd/run.sh": None,
        },
    )
    assert befunde == []


def test_fremdes_addon_bleibt_unberuehrt(tmp_path: Path) -> None:
    """Eine Aenderung am Bridge-Code verlangt nichts von der Nummer des eBUS-Add-ons."""
    befunde = _vergleich(
        tmp_path,
        {
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.2'\n",
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.2"),
        },
    )
    assert all("duckcurve_ebusd" not in befund for befund in befunde)
    assert befunde == []


# ----------------------------------------------------------- die Changelog-Pflicht


CHANGELOG_BASIS = "# Changelog Bridge\n\n## 0.15.1 - 2026-11-23\n\n- der Anfang\n"


def test_anhebung_ohne_changelog_abschnitt_faellt(tmp_path: Path) -> None:
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.2"),
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.2'\n",
        },
        basis_zusatz={"addons/duckcurve_bridge/CHANGELOG.md": CHANGELOG_BASIS},
    )
    assert len(befunde) == 1
    assert "CHANGELOG.md" in befunde[0]


def test_anhebung_mit_changelog_abschnitt_genuegt(tmp_path: Path) -> None:
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.2"),
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.2'\n",
            "addons/duckcurve_bridge/CHANGELOG.md": "# Changelog\n\n## 0.15.2 - heute\n\n- neu\n"
            + CHANGELOG_BASIS,
        },
        basis_zusatz={"addons/duckcurve_bridge/CHANGELOG.md": CHANGELOG_BASIS},
    )
    assert befunde == []


def test_geloeschte_changelog_entzieht_sich_nicht(tmp_path: Path) -> None:
    """Wer die Datei loescht, um der Pflicht zu entgehen, bekommt sie trotzdem.

    Deshalb zaehlt fuer die Frage, ob das Add-on eine CHANGELOG.md fuehrt, auch die Basis.
    """
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.2"),
            "addons/duckcurve_bridge/CHANGELOG.md": None,
        },
        basis_zusatz={"addons/duckcurve_bridge/CHANGELOG.md": CHANGELOG_BASIS},
    )
    assert len(befunde) == 1
    assert "CHANGELOG.md" in befunde[0]


def test_ohne_anhebung_wird_kein_changelog_abschnitt_verlangt(tmp_path: Path) -> None:
    """Die Changelog-Pflicht gilt der *neuen* Fassung, nicht jeder Fassung bei jedem Lauf.

    Ohne diese Einschraenkung verlangte die Pruefung in jedem Vergleich einen Abschnitt fuer die
    gerade geltende Fassung - auch dort, wo am Add-on gar nichts geaendert wurde. Das ist die
    teure Richtung: ein PR, der das Add-on nicht beruehrt, wuerde rot. Hier steht die Fassung
    still (0.15.1 in Basis und Kopf), und die `CHANGELOG.md` kennt sie nicht; trotzdem faellt
    nichts.
    """
    befunde = _vergleich(
        tmp_path,
        {"packages/hems-core/src/hems_core/regelung.py": "SCHWELLE = 5.0\n"},
        basis_zusatz={
            "addons/duckcurve_bridge/CHANGELOG.md": "# Aenderungen\n\n## 0.14.0\n\n- alt\n"
        },
    )
    assert befunde == []


def test_ohne_changelog_schlaeft_die_pflicht(tmp_path: Path) -> None:
    """Solange das Add-on keine CHANGELOG.md fuehrt, verlangt die Pruefung keinen Abschnitt.

    Am 23.11.2026 gab es die Datei noch nicht. Eine unbedingte Pflicht waere auf jedem Commit
    der Vorgeschichte rot gewesen und damit beim ersten Lauf nicht von einem echten Befund zu
    unterscheiden.
    """
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": _fassung("0.15.2"),
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.2'\n",
        },
    )
    assert befunde == []


@pytest.mark.parametrize(
    ("ueberschrift", "erwartet"),
    [
        ("## 0.15.2", True),
        ("## 0.15.2 - 2026-11-23", True),
        ("### [0.15.2]", True),
        ("# Bridge 0.15.2", True),
        ("## 0.15.20 - spaeter", False),
        ("## 10.15.2", False),
        ("- 0.15.2 in einer Liste, nicht als Ueberschrift", False),
    ],
)
def test_abschnitt_erkennen(ueberschrift: str, erwartet: bool) -> None:
    """`0.15.2` darf nicht aus der Ueberschrift fuer `0.15.20` herausgelesen werden."""
    text = f"# Changelog\n\n{ueberschrift}\n\n- etwas\n"
    assert pruefer.abschnitt_vorhanden(text, "0.15.2") is erwartet


# ---------------------------------------------------------------- die Meldung


def test_meldung_sagt_was_und_warum(tmp_path: Path) -> None:
    """Eine Meldung, die nur „rot" sagt, wird umgangen statt verstanden."""
    befunde = _vergleich(
        tmp_path,
        {
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.1'\n# neu\n",
            "addons/duckcurve_bridge/run.sh": "#!/bin/sh\n",
        },
    )
    assert len(befunde) == 1
    meldung = befunde[0]
    assert "duckcurve_bridge" in meldung  # welches Add-on
    assert "apps/bridge/src/dch_bridge/main.py" in meldung  # was es ausgeloest hat
    assert "addons/duckcurve_bridge/run.sh" in meldung
    assert "0.15.1" in meldung  # welche Fassung dasteht
    assert "nie neu" in meldung  # und warum das zaehlt
    assert "Zu tun" in meldung


def test_viele_ausloeser_werden_gekuerzt(tmp_path: Path) -> None:
    """Dreissig Pfade in einer Fehlermeldung liest niemand."""
    aenderungen = {f"apps/bridge/src/dch_bridge/datei{nummer}.py": "x\n" for nummer in range(30)}
    befunde = _vergleich(tmp_path, aenderungen)
    assert len(befunde) == 1
    assert "und 20 weitere" in befunde[0]


# ------------------------------------------------- der Vergleichspunkt in der CI


def test_leere_revision_wird_uebersprungen() -> None:
    """Bei `push` auf einen neuen Zweig liefert GitHub vierzig Nullen als Vorgaenger.

    Das ist kein Commit. Ein Abbruch waere hier falsch: nicht die Aenderung ist schuld,
    sondern der fehlende Vergleichspunkt.
    """
    basis, auskunft = pruefer.basis_bestimmen(pruefer.LEERE_REVISION, None, None)
    assert basis is None
    assert "neuer Zweig" in auskunft


def test_unbekannte_revision_wird_uebersprungen() -> None:
    basis, auskunft = pruefer.basis_bestimmen("gibtesnicht0000", None, None)
    assert basis is None
    assert "kennt" in auskunft


def test_ersatzbasis_springt_ein() -> None:
    """Statt zu ueberspringen kann die Pruefung den Merge-Base nehmen.

    Hier liest der Test das echte Repository - aber nur lesend, und nur `HEAD` gegen `HEAD`,
    damit er von der Vorgeschichte nicht abhaengt.
    """
    basis, auskunft = pruefer.basis_bestimmen(pruefer.LEERE_REVISION, "HEAD", "HEAD")
    assert basis is not None
    assert "Merge-Base" in auskunft


def test_brauchbare_basis_bleibt_unangetastet() -> None:
    basis, _ = pruefer.basis_bestimmen("HEAD", "origin/main", None)
    assert basis == "HEAD"


# ------------------------------------------------------------- Randfaelle lesen


def test_fassung_ohne_zahlen_faellt(tmp_path: Path) -> None:
    """Eine Fassung, die sich nicht in Zahlen lesen laesst, gilt als nicht gestiegen."""
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": _fassung("dev"),
            "apps/bridge/src/dch_bridge/main.py": "VERSION = 'dev'\n",
        },
    )
    assert len(befunde) == 1


def test_unlesbare_config_faellt(tmp_path: Path) -> None:
    """Ohne `version` weiss der Supervisor nicht, dass es ein Update gibt."""
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": "name: Bridge\nslug: duckcurve_bridge\n",
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.15.1'\n# neu\n",
        },
    )
    assert len(befunde) == 1
    assert "keine lesbare" in befunde[0]


def test_unquotierte_fassung_wird_als_zahl_gelesen(tmp_path: Path) -> None:
    """`version: 0.16` ohne Anfuehrungszeichen laedt YAML als Gleitkommazahl.

    Die Pruefung muss trotzdem vergleichen koennen, statt die Datei fuer unlesbar zu erklaeren.
    """
    befunde = _vergleich(
        tmp_path,
        {
            "addons/duckcurve_bridge/config.yaml": "name: Bridge\nversion: 0.16\n",
            "apps/bridge/src/dch_bridge/main.py": "VERSION = '0.16'\n",
        },
    )
    assert befunde == []
