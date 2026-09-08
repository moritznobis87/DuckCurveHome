"""Der Bedienzustand des Ofens: Wunsch, Beobachtung, Freigabe und Ablauf.

Geprüft wird vor allem die Trennung, die dieser Teil aufmacht: `mode` ist gewollt, `running` ist
gemessen, und beide dürfen auseinanderlaufen. Ein Test, der beides gleichsetzt, würde genau den
Fehler festschreiben, den die Oberfläche vermeiden soll: beim Anheizen „Fehler" anzuzeigen.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from dch_api.application.stove_control import STALE_AFTER_S, MeasurementLookup, StoveController
from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.domain import Measurement, Quality
from hems_core.domain.config import StoveConfig
from hems_core.protocol import HelloFrame, RawReading, TelemetryFrame

NOW = datetime(2026, 1, 15, 18, 0, tzinfo=UTC)


def lookup(
    values: dict[str, float | None], at: datetime = NOW, quality: Quality = Quality.OK
) -> MeasurementLookup:
    def measure(key: str, stale_after_s: float) -> Measurement:
        assert stale_after_s == STALE_AFTER_S
        if key not in values:
            return Measurement.missing(Quality.UNAVAILABLE, at, key)
        v = values[key]
        if v is None:
            return Measurement.missing(Quality.UNKNOWN, at, key)
        return Measurement(value=v, observed_at=at, quality=quality, source="mcz")

    return measure


def controller(*, control: bool = True, present: bool = True) -> StoveController:
    return StoveController(StoveConfig(present=present, control_enabled=control))


# ------------------------------------------------------------------ Zustand


def test_ohne_ofen_gibt_es_nichts_zu_zeigen() -> None:
    s = controller(present=False).state(lookup({}), NOW)
    assert s.present is False and s.control_enabled is False
    assert s.note_de == "Kein Ofen konfiguriert."


def test_ohne_daten_heisst_keine_verbindung_und_nicht_aus() -> None:
    """„Wir wissen es nicht" ist eine andere Aussage als „er ist aus" - und die wichtigere."""
    s = controller().state(lookup({}), NOW)
    assert s.present is True
    assert s.running is None
    assert s.quality is Quality.UNAVAILABLE
    assert s.note_de == "Keine Verbindung zum Ofen."


def test_brennender_ofen_wird_mit_stufe_benannt() -> None:
    s = controller().state(
        lookup({"stove_running": 1.0, "stove_power_level": 5.0, "stove_fume_temp_c": 155.0}), NOW
    )
    assert s.running is True and s.power_level == 5.0
    assert s.fume_temp_c == 155.0
    assert "brennt auf Stufe 5" in s.note_de


def test_wunsch_und_wirklichkeit_stehen_nebeneinander() -> None:
    """Zwischen Befehl und Feuer liegen Minuten. In dieser Zeit stimmt beides zugleich."""
    c = controller()
    c.set("on", 180, NOW)
    s = c.state(lookup({"stove_running": 0.0}), NOW)
    assert s.mode == "on", "gewollt"
    assert s.running is False, "gemessen"
    assert "Der Ofen ist aus." in s.note_de and "Manuell an bis 18:00" not in s.note_de
    assert "Manuell an bis 21:00" in s.note_de


def test_ohne_freigabe_sagt_die_auskunft_warum_nichts_passiert() -> None:
    s = controller(control=False).state(lookup({"stove_running": 1.0}), NOW)
    assert s.control_enabled is False
    assert "nicht freigegeben" in s.note_de


def test_die_vorgabe_ist_aus_und_nicht_auto() -> None:
    """Die Automatik läuft nicht von selbst an, nur weil ein Dienst neu gestartet wurde."""
    s = controller().state(lookup({"stove_running": 0.0}), NOW)
    assert s.mode == "off"
    assert s.ends_at is None, "keine Frist: das ist ein Zustand, kein Eingriff"
    assert "in Ruhe" in s.note_de and "Auto" in s.note_de


def test_auto_ohne_fahrplan_verspricht_keine_automatik() -> None:
    c = controller()
    c.set("auto", 0, NOW)
    s = c.state(lookup({"stove_running": 0.0}), NOW)
    assert "kein Fahrplan" in s.note_de


def test_auto_mit_fahrplan_sagt_was_der_planer_vorhat() -> None:
    c = controller()
    c.set("auto", 0, NOW)
    s = c.state(
        lookup({"stove_running": 0.0}),
        NOW,
        planned_on=True,
        plan_until=NOW + timedelta(hours=3),
        plan_note_de="2,0 h Ofen in einer Zündung.",
    )
    assert s.planned_on is True
    assert "Planer sagt an bis 21:00" in s.note_de
    assert s.plan_note_de.startswith("2,0 h")


def test_veralteter_wert_wird_gezeigt_aber_gekennzeichnet() -> None:
    s = controller().state(lookup({"stove_running": 1.0}, quality=Quality.STALE), NOW)
    assert s.running is True
    assert s.quality is Quality.STALE, "die Oberfläche färbt das Alter ein, statt es zu verstecken"


# ------------------------------------------------------------------ Ablauf des Eingriffs


def test_ein_eingriff_laeuft_ab_und_faellt_auf_die_vorgabe() -> None:
    """Nach „an für zwei Stunden" übernimmt nicht der Planer, sondern wieder die Vorgabe."""
    c = controller()
    c.set("on", 120, NOW)
    assert c.effective_mode(NOW + timedelta(minutes=119)) == "on"
    assert c.effective_mode(NOW + timedelta(minutes=120)) == "off"
    assert c.ends_at is None


def test_auto_hebt_einen_laufenden_eingriff_auf() -> None:
    c = controller()
    c.set("off", 120, NOW)
    c.set("auto", 120, NOW)
    assert c.mode == "auto" and c.ends_at is None


def test_ohne_freigabe_ist_der_ofen_nicht_steuerbar() -> None:
    assert controller(control=False).controllable is False
    assert controller(present=False).controllable is False
    assert controller().controllable is True


# ------------------------------------------------------------------ Endpunkt


def client(tmp_path: Path, *, control: bool) -> TestClient:
    cfg = tmp_path / "hems.yaml"
    cfg.write_text(
        json.dumps({"hems": {"stove": {"present": True, "control_enabled": control}}}),
        encoding="utf-8",
    )
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'stove.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
        config_file=str(cfg),
    )
    return TestClient(create_app(settings))


AUTH = {"authorization": "Bearer api-geheim"}


@pytest.fixture
def open_client(tmp_path: Path) -> Iterator[TestClient]:
    with client(tmp_path, control=True) as c:
        yield c


def test_ohne_freigabe_wird_der_befehl_abgelehnt(tmp_path: Path) -> None:
    with client(tmp_path, control=False) as c:
        r = c.post("/api/v1/control/stove/mode", json={"mode": "on"}, headers=AUTH)
        assert r.status_code == 409
        assert "freigegeben" in r.json()["error"]["message"]


def test_ohne_bridge_kein_schaltbefehl(open_client: TestClient) -> None:
    """Erst wenn der Befehl beim Ofen ankommen kann, wird die Absicht übernommen."""
    r = open_client.post("/api/v1/control/stove/mode", json={"mode": "on"}, headers=AUTH)
    assert r.status_code == 503
    state = open_client.get("/api/v1/live/state", headers=AUTH).json()
    assert state["stove"]["mode"] == "off", "eine Absicht ohne Wirkung wird nicht gespeichert"


def test_auto_geht_immer_denn_es_schaltet_nichts(open_client: TestClient) -> None:
    r = open_client.post("/api/v1/control/stove/mode", json={"mode": "auto"}, headers=AUTH)
    assert r.status_code == 200 and r.json()["mode"] == "auto"


def test_der_ofen_steht_im_live_zustand(open_client: TestClient) -> None:
    now = datetime.now(UTC)
    with open_client.websocket_connect(
        "/bridge/ws", headers={"authorization": "Bearer geheim"}
    ) as ws:
        ws.send_text(
            HelloFrame(
                bridge_version="t",
                bridge_id="haus",
                clock=now,
                entity_map_hash="x",
                keys=["stove_running"],
            ).model_dump_json()
        )
        ws.receive_text()
        ws.send_text(
            TelemetryFrame(
                seq=1,
                sent_at=now,
                items=[
                    RawReading(key="stove_running", value=1.0, observed_at=now, source="mcz"),
                    RawReading(key="stove_power_level", value=5.0, observed_at=now, source="mcz"),
                    RawReading(
                        key="stove_boiler_temp_c", value=80.0, observed_at=now, source="mcz"
                    ),
                ],
            ).model_dump_json()
        )
        ws.receive_text()
        stove = open_client.get("/api/v1/live/state", headers=AUTH).json()["stove"]
    assert stove["present"] is True and stove["control_enabled"] is True
    assert stove["running"] is True and stove["power_level"] == 5.0
    assert stove["boiler_temp_c"] == 80.0
    assert stove["quality"] == "ok"


def test_im_demo_modus_gibt_es_keinen_ofen() -> None:
    settings = Settings(mode="demo", api_token="", demo_autostart=False, weather_refresh_min=0)
    with TestClient(create_app(settings)) as c:
        assert c.get("/api/v1/live/state").json()["stove"]["present"] is False
        r = c.post("/api/v1/control/stove/mode", json={"mode": "on"})
        assert r.status_code == 404
