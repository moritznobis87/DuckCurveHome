"""Der Info-Rahmen des Maestro-Moduls: Feldlage, Maßstäbe, Sonderfälle.

Die Rahmen hier sind aus den dokumentierten Feldpositionen zusammengesetzt, nicht vom Gerät
abgeschrieben. Sie prüfen genau das, woran ein Protokollparser scheitert: die Halbierung der
Temperaturen, den Rohwert 255 als „kein Fühler", einen zu kurzen Rahmen und einen Rahmen, der gar
keine Information trägt.
"""

from __future__ import annotations

import asyncio
import importlib.util
from pathlib import Path
from types import ModuleType

import pytest

from dch_bridge.sources.mcz_maestro import (
    MAESTRO_FIELDS,
    MaestroStove,
    parse_info,
    stove_url,
)
from hems_core.domain.quality import Quality


def _probe_module() -> ModuleType:
    """`tools/mcz_probe.py` laden, ohne dass es ein Paket sein muss."""
    path = Path(__file__).resolve().parents[3] / "tools" / "mcz_probe.py"
    spec = importlib.util.spec_from_file_location("mcz_probe", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def frame(overrides: dict[int, int] | None = None) -> str:
    """Info-Rahmen bauen: Feld 0 ist der Typ, danach 60 Felder, alle hexadezimal."""
    values = dict.fromkeys(range(1, 61), 0)
    values.update(overrides or {})
    return "01|" + "|".join(format(values[i], "X") for i in range(1, 61))


def test_leitgroessen_werden_erkannt() -> None:
    got = parse_info(
        frame(
            {
                1: 15,  # Stove_State: Leistungsstufe 5
                5: 155,  # Rauchgas 155 °C, ganze Grad
                7: 118,  # Puffer 59,0 °C in halben Grad
                8: 160,  # Ofenvorlauf 80,0 °C
                14: 300,  # Förderschnecke
                16: 100,  # Pumpe 100 %
                29: 5,  # Leistungsstufe
                59: 90,  # Ofenrücklauf 45,0 °C
            }
        )
    )
    assert got["stove_state"] == 15
    assert got["stove_fume_temp_c"] == 155
    assert got["stove_buffer_temp_c"] == 59.0
    assert got["stove_boiler_temp_c"] == 80.0
    assert got["stove_auger_rpm"] == 300
    assert got["stove_pump_pct"] == 100
    assert got["stove_power_level"] == 5
    assert got["stove_return_temp_c"] == 45.0


def test_spreizung_des_ofenkreises_ist_rechenbar() -> None:
    """Der eigentliche Zweck: Vorlauf minus Rücklauf ohne zusätzliche Hardware."""
    got = parse_info(frame({8: 150, 59: 128}))
    assert got["stove_boiler_temp_c"] == 75.0
    assert got["stove_return_temp_c"] == 64.0


def test_fehlender_fuehler_ist_none_und_nicht_127_grad() -> None:
    got = parse_info(frame({7: 255, 9: 255}))
    assert got["stove_buffer_temp_c"] is None


def test_betriebsstunden_kommen_in_sekunden() -> None:
    got = parse_info(frame({37: 3600 * 307}))
    assert got["stove_operating_hours"] == pytest.approx(307.0)


def test_dreiwegeventil_unterscheidet_warmwasser_von_heizung() -> None:
    assert parse_info(frame({15: 1}))["stove_dhw_mode"] == 1.0
    assert parse_info(frame({15: 0}))["stove_dhw_mode"] == 0.0


@pytest.mark.parametrize(
    ("state", "running"),
    [(0, 0.0), (11, 1.0), (15, 1.0), (31, 1.0), (41, 1.0), (46, 0.0), (50, 0.0)],
)
def test_laeuft_er_wirklich(state: int, running: float) -> None:
    """Aus, Leistungsstufe 1, Leistungsstufe 5, An, Auskühlen, Standby, Zündfehler."""
    assert parse_info(frame({1: state}))["stove_running"] == running


def test_andere_nachrichtentypen_werden_nicht_gedeutet() -> None:
    assert parse_info("00|1|2|3") == {}
    assert parse_info("PING") == {}
    assert parse_info("") == {}


def test_zu_kurzer_rahmen_liefert_was_da_ist() -> None:
    """Ältere Firmware schickt weniger Felder. Fehlendes wird ausgelassen, nicht geraten."""
    got = parse_info("01|F|0|0|0|9B")
    assert got["stove_state"] == 15
    assert got["stove_fume_temp_c"] == 155
    assert "stove_return_temp_c" not in got


def test_unlesbare_felder_reissen_den_rahmen_nicht_ab() -> None:
    parts = frame({1: 11}).split("|")
    parts[5] = "??"
    got = parse_info("|".join(parts))
    assert got["stove_state"] == 11
    assert "stove_fume_temp_c" not in got


def test_feldtabelle_ist_widerspruchsfrei() -> None:
    indices = [f.index for f in MAESTRO_FIELDS]
    keys = [f.key for f in MAESTRO_FIELDS]
    assert len(set(indices)) == len(indices), "Feldposition doppelt vergeben"
    assert len(set(keys)) == len(keys), "Domänenschlüssel doppelt vergeben"
    assert all(f.kind in {"int", "half", "hours", "flag"} for f in MAESTRO_FIELDS)


def test_url_aus_host_und_port() -> None:
    assert stove_url("192.168.1.50", 81) == "ws://192.168.1.50:81/"
    assert stove_url(" ofen.local ", 81) == "ws://ofen.local:81/"
    assert stove_url("ws://192.168.120.1:81/", 81) == "ws://192.168.120.1:81/"


def test_ausfall_wird_einmal_gemeldet_und_nicht_eingefroren() -> None:
    """Nicht erreichbar heißt `unavailable`, nicht „der letzte Wert gilt weiter"."""
    seen: list[list] = []

    async def collect(items: list) -> None:
        seen.append(items)

    stove = MaestroStove(url="ws://test/", on_readings=collect)
    asyncio.run(stove._announce_offline())
    asyncio.run(stove._announce_offline())  # zweiter Ausfall in Folge: keine zweite Meldung

    assert len(seen) == 1
    assert {r.key for r in seen[0]} == set(stove.keys)
    assert all(r.value is None and r.quality is Quality.UNAVAILABLE for r in seen[0])


def test_werte_tragen_qualitaet() -> None:
    seen: list[list] = []

    async def collect(items: list) -> None:
        seen.append(items)

    stove = MaestroStove(url="ws://test/", on_readings=collect)
    asyncio.run(stove._emit({"stove_buffer_temp_c": 59.0, "stove_return_temp_c": None}))

    by_key = {r.key: r for r in seen[0]}
    assert by_key["stove_buffer_temp_c"].quality is Quality.OK
    assert by_key["stove_return_temp_c"].quality is Quality.UNKNOWN
    assert by_key["stove_buffer_temp_c"].source == "mcz"


def test_pruefskript_und_bridge_lesen_dieselben_felder() -> None:
    """`tools/mcz_probe.py` hält eine eigene Kopie der Feldtabelle, damit es ohne Repository und
    ohne Installation läuft. Diese Kopie darf nicht abdriften: sonst zeigt das Prüfskript etwas
    anderes an, als die Bridge später aufzeichnet."""
    probe = _probe_module()
    assert tuple((f.index, f.key, f.kind) for f in MAESTRO_FIELDS) == probe.FIELDS


def test_pruefskript_deutet_einen_rahmen_wie_die_bridge() -> None:
    probe = _probe_module()
    raw = frame({1: 15, 7: 118, 8: 160, 9: 255, 59: 128})
    mine = parse_info(raw)
    theirs = probe.parse_info(raw)
    assert theirs == {k: v for k, v in mine.items() if k != "stove_running"}


def test_lesbare_zeile_zeigt_fehlende_fuehler_als_strich() -> None:
    """`readable` ist die Form, in der der erste Rahmen im Protokoll landet."""
    from dch_bridge.sources.mcz_maestro import readable

    line = readable([("stove_buffer_temp_c", 59.0), ("stove_return_temp_c", None)])
    assert line == "stove_buffer_temp_c=59.0 stove_return_temp_c=-"
