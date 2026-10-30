"""Der Hausplan: Datei lesen, pruefen, einmal je Stand melden.

Das Haus hier ist erfunden. Das Repository ist oeffentlich.
"""

from __future__ import annotations

import os
from datetime import datetime
from pathlib import Path

import pytest

from dch_bridge.house_source import HousePlanSource, ereignis, lesen

PLAN = """
version: 1
name: Probe
decks:
  - key: eg
    name: Erdgeschoss
    shell: [[0, 0], [8, 0], [8, 6], [0, 6]]
    rooms:
      - {name: Wohnen, room_id: 3, x0: 0, z0: 0, x1: 5, z1: 6}
      - {name: Flur, x0: 5, z0: 0, x1: 8, z1: 6, minor: true}
    contacts:
      - {name: Terrasse, key: kontakt_terrasse, room: Wohnen, side: n, at: 0, a: 1, b: 2.2, door: true}
"""


class Sammler:
    def __init__(self) -> None:
        self.ereignisse: list[tuple[str, str, str, dict[str, str]]] = []

    async def __call__(
        self, at: datetime, severity: str, code: str, message: str, context: dict[str, str]
    ) -> None:
        self.ereignisse.append((severity, code, message, context))


def test_eine_gute_datei_ergibt_plan_und_hash(tmp_path: Path) -> None:
    datei = tmp_path / "haus.yaml"
    datei.write_text(PLAN, encoding="utf-8")
    g = lesen(datei)
    assert g.plan is not None and g.fehler == "" and len(g.hash) == 16
    schwere, satz, ctx = ereignis(g, datei)
    assert schwere == "info" and satz == "Hausplan mit 1 Decks und 2 Raeumen"
    assert ctx["hash"] == g.hash and ctx["file"] == str(datei)
    assert '"kontakt_terrasse"' in ctx["plan"]


def test_eine_fehlende_datei_ist_kein_fehler(tmp_path: Path) -> None:
    g = lesen(tmp_path / "fehlt.yaml")
    assert not g.vorhanden and g.plan is None and g.fehler == ""


def test_kaputtes_yaml_nennt_den_grund(tmp_path: Path) -> None:
    datei = tmp_path / "haus.yaml"
    datei.write_text("decks: [\n  - key: eg\n", encoding="utf-8")
    g = lesen(datei)
    assert g.plan is None and g.fehler.startswith("Kein gueltiges YAML")
    schwere, satz, ctx = ereignis(g, datei)
    assert schwere == "warning" and "nicht lesbar" in satz and ctx["error"] == g.fehler


def test_ein_schemafehler_nennt_den_pfad_im_dokument(tmp_path: Path) -> None:
    datei = tmp_path / "haus.yaml"
    datei.write_text(PLAN.replace("x1: 5, z1: 6}", "x1: 5, z1: -1}"), encoding="utf-8")
    g = lesen(datei)
    assert g.plan is None
    assert g.fehler.startswith("decks.0.rooms.0")
    assert "z1 > z0" in g.fehler


def test_eine_liste_statt_eines_dokuments_wird_abgewiesen(tmp_path: Path) -> None:
    datei = tmp_path / "haus.yaml"
    datei.write_text("- eg\n- og\n", encoding="utf-8")
    assert "decks" in lesen(datei).fehler


@pytest.mark.asyncio
async def test_gemeldet_wird_einmal_je_stand(tmp_path: Path) -> None:
    datei = tmp_path / "haus.yaml"
    datei.write_text(PLAN, encoding="utf-8")
    sammler = Sammler()
    quelle = HousePlanSource(datei, sammler, poll_s=0.01)
    assert await quelle.tick() is True
    assert await quelle.tick() is False, "dieselbe Datei, kein zweites Ereignis"
    # Neu gespeichert, aber inhaltlich gleich: der Hash entscheidet, nicht die Uhr.
    os.utime(datei, (datei.stat().st_atime + 100, datei.stat().st_mtime + 100))
    assert await quelle.tick() is False
    # Geaendert: ein neues Ereignis.
    datei.write_text(PLAN.replace("name: Probe", "name: Probe 2"), encoding="utf-8")
    os.utime(datei, (datei.stat().st_atime + 200, datei.stat().st_mtime + 200))
    assert await quelle.tick() is True
    # Kaputt gemacht: der Fehler geht raus. Repariert: der Plan wieder.
    datei.write_text("decks: [", encoding="utf-8")
    os.utime(datei, (datei.stat().st_atime + 300, datei.stat().st_mtime + 300))
    assert await quelle.tick() is True
    datei.write_text(PLAN, encoding="utf-8")
    os.utime(datei, (datei.stat().st_atime + 400, datei.stat().st_mtime + 400))
    assert await quelle.tick() is True
    schweren = [e[0] for e in sammler.ereignisse]
    assert schweren == ["info", "info", "warning", "info"]
    assert all(e[1] == "house.plan" for e in sammler.ereignisse)


@pytest.mark.asyncio
async def test_ohne_datei_passiert_nichts(tmp_path: Path) -> None:
    sammler = Sammler()
    quelle = HousePlanSource(tmp_path / "fehlt.yaml", sammler)
    assert await quelle.tick() is False
    assert sammler.ereignisse == []
