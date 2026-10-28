"""Ein unveränderter Wert ist kein Schweigen.

Home Assistant setzt den Zeitstempel eines Sensors nur fort, wenn die Integration den Wert erneut
schreibt. Nachts steht die PV-Leistung stundenlang bei null; ihr Zeitstempel bleibt dann stehen,
und die Bilanz im Dienst verliert die Erzeugungsseite, obwohl nichts ausgefallen ist. Deshalb
zählt beim periodischen Nachlesen der Lesezeitpunkt.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

from dch_bridge.home_assistant.ws_client import EntityState
from dch_bridge.main import Bridge
from dch_bridge.mapping import EntityMap
from dch_bridge.settings import BridgeSettings
from hems_core.domain import Quality

MAP = {
    "sensors": [
        {"key": "pv_power_kw", "entity": "sensor.pv", "unit": "W", "stale_after_s": 120},
    ]
}


def bruecke(tmp_path: Path) -> Bridge:
    settings = BridgeSettings(
        api_token="t", outbox_path=tmp_path / "outbox.sqlite", source_mode="home_assistant"
    )
    return Bridge(settings, EntityMap.model_validate(MAP))


def stillstehend(alter_min: float) -> EntityState:
    """Die PV-Anlage meldet null, und zwar seit `alter_min` Minuten unverändert."""
    alt = datetime.now(UTC) - timedelta(minutes=alter_min)
    return EntityState(
        entity_id="sensor.pv",
        state="0",
        attributes={"unit_of_measurement": "W"},
        last_updated=alt,
        last_changed=alt,
        last_reported=alt,
    )


def test_ohne_bestaetigung_altert_der_wert(tmp_path: Path) -> None:
    b = bruecke(tmp_path)
    b._ingest(stillstehend(10))
    r = b._pending["pv_power_kw"]
    assert r.value == 0.0
    assert r.quality is Quality.STALE


def test_nachgelesen_ist_frisch(tmp_path: Path) -> None:
    """Dasselbe Alter, aber Home Assistant hat den Wert eben auf Nachfrage bestätigt."""
    b = bruecke(tmp_path)
    b._ingest(stillstehend(10), bestaetigt=True)
    r = b._pending["pv_power_kw"]
    assert r.value == 0.0
    assert r.quality is Quality.OK
    assert (datetime.now(UTC) - r.observed_at).total_seconds() < 5


def test_ausgefallen_bleibt_ausgefallen(tmp_path: Path) -> None:
    """Der Lesezeitpunkt macht aus `unavailable` keinen brauchbaren Wert."""
    b = bruecke(tmp_path)
    st = stillstehend(10)
    b._ingest(
        EntityState(
            entity_id=st.entity_id,
            state="unavailable",
            attributes=st.attributes,
            last_updated=st.last_updated,
            last_changed=st.last_changed,
            last_reported=st.last_reported,
        ),
        bestaetigt=True,
    )
    r = b._pending["pv_power_kw"]
    assert r.value is None
    assert r.quality is Quality.UNAVAILABLE
