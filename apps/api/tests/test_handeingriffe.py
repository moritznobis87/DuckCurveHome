"""Was gerade von Hand gestellt ist, und „Alles zurück auf Automatik“ (Seite „Einstellen“)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from dch_api.application import handeingriffe
from dch_api.schemas import (
    BatteryLiveOut,
    LiveStateOut,
    RoomShiftOut,
    RoomShiftRoomOut,
    StoveLiveOut,
)
from hems_core.domain import OperatingMode, Override, OverrideKind, SystemMode

# 14:00 in Berlin.
JETZT = datetime(2026, 11, 24, 13, 0, tzinfo=UTC)


def _zustand(modus: OperatingMode | None = None, ofen: StoveLiveOut | None = None) -> LiveStateOut:
    return LiveStateOut.model_construct(
        operating_mode=modus or OperatingMode(), stove=ofen or StoveLiveOut()
    )


def _speicher(mode: str = "off", ends_at: datetime | None = None) -> BatteryLiveOut:
    return BatteryLiveOut(mode=mode, ends_at=ends_at)  # type: ignore[arg-type]


def test_ohne_eingriff_ist_die_liste_leer() -> None:
    assert handeingriffe.liste(_zustand(), _speicher(), None, JETZT).eingriffe == []


def test_die_waermepumpe_von_hand_steht_mit_ihrem_ende_da() -> None:
    modus = OperatingMode(
        system_mode=SystemMode.MANUAL,
        override=Override(
            kind=OverrideKind.FORCE_OFF, started_at=JETZT, ends_at=JETZT + timedelta(hours=2)
        ),
    )
    [e] = handeingriffe.liste(_zustand(modus), _speicher(), None, JETZT).eingriffe
    assert (e.art, e.weg, e.zuruecksetzbar) == ("waermepumpe", "/", True)
    assert e.satz_de == "Wärmepumpe von Hand gesperrt, bis 16:00 Uhr."


def test_ein_abgelaufener_eingriff_steht_nicht_mehr_da() -> None:
    modus = OperatingMode(
        system_mode=SystemMode.MANUAL,
        override=Override(
            kind=OverrideKind.FORCE_RELEASE,
            started_at=JETZT - timedelta(hours=3),
            ends_at=JETZT - timedelta(hours=1),
        ),
    )
    assert handeingriffe.liste(_zustand(modus), _speicher(), None, JETZT).eingriffe == []


def test_ofen_und_speicher_mit_frist() -> None:
    ofen = StoveLiveOut(present=True, mode="on", ends_at=JETZT + timedelta(hours=3))
    speicher = _speicher("hold", JETZT + timedelta(hours=12))
    eingriffe = handeingriffe.liste(_zustand(ofen=ofen), speicher, None, JETZT).eingriffe
    assert [e.satz_de for e in eingriffe] == [
        "Ofen von Hand an, bis 17:00 Uhr.",
        # Über Mitternacht hinaus mit Datum.
        "Speicher von Hand angehalten, bis 25.11. um 02:00 Uhr.",
    ]
    assert all(e.zuruecksetzbar for e in eingriffe)


def test_ein_speicher_ohne_frist_ist_kein_eingriff() -> None:
    """`auto` und `off` gelten unbefristet; sie sind eine Vorgabe und kein Eingriff."""
    assert handeingriffe.liste(_zustand(), _speicher("auto"), None, JETZT).eingriffe == []


def test_ein_raum_von_hand_steht_da_und_bleibt_beim_zurueckstellen() -> None:
    raeume = RoomShiftOut.model_construct(
        active=[
            RoomShiftRoomOut.model_construct(
                room_id=3, name="Bad", paused_until=JETZT + timedelta(hours=6)
            ),
            RoomShiftRoomOut.model_construct(room_id=4, name="Flur", paused_until=None),
        ]
    )
    [e] = handeingriffe.liste(_zustand(), _speicher(), raeume, JETZT).eingriffe
    assert (e.art, e.weg, e.zuruecksetzbar) == ("raum", "/haus", False)
    assert e.satz_de == "Bad von Hand gestellt; die Raum-Automatik ruht bis 20:00 Uhr."


# ---------------------------------------------------------------------------
# Über HTTP, gegen den Demo-Dienst
# ---------------------------------------------------------------------------


def test_alles_zurueck_beendet_die_waermepumpe_von_hand(client: TestClient) -> None:
    gestellt = client.post(
        "/api/v1/control/heat-pump/mode",
        json={"system_mode": "manual", "manual_state": "on", "duration_min": 60},
    )
    assert gestellt.status_code == 200, gestellt.text
    vorher = client.get("/api/v1/control/handeingriffe").json()["eingriffe"]
    assert [e["art"] for e in vorher] == ["waermepumpe"]

    zurueck = client.post("/api/v1/control/automatik")
    assert zurueck.status_code == 200, zurueck.text
    daten = zurueck.json()
    assert daten["ok"] is True
    assert daten["meldung_de"] == "Der Eingriff ist zurückgestellt; die Automatik regelt wieder."
    assert daten["handeingriffe"]["eingriffe"] == []
    modus = client.get("/api/v1/live/state").json()["operating_mode"]
    assert modus["system_mode"] == "auto"


def test_ohne_eingriff_gibt_es_nichts_zurueckzustellen(client: TestClient) -> None:
    daten = client.post("/api/v1/control/automatik").json()
    assert (daten["ok"], daten["meldung_de"]) == (True, handeingriffe.NICHTS_ZURUECK)
