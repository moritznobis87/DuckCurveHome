from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path

import yaml
from fastapi.testclient import TestClient

from dch_api.infrastructure.live_state import LiveState
from hems_core.domain import HemsConfig, Quality
from hems_core.protocol import RawReading
from hems_core.watch import findings

NOW = datetime(2026, 9, 4, 12, 0, tzinfo=UTC)


def reading(key: str, value: float, at: datetime = NOW) -> RawReading:
    return RawReading(key=key, value=value, observed_at=at, quality=Quality.OK, source=f"ha:{key}")


def test_snapshot_derives_house_and_ages_values() -> None:
    ls = LiveState(HemsConfig())
    ls.apply(
        [
            reading("pv_power_kw", 6.0),
            reading("grid_power_kw", -3.0),
            reading("battery_power_kw", -1.0),
            reading("battery_soc", 0.9),
            reading("heat_pump_power_kw", 0.0),
            reading("ev_power_kw", 0.0),
        ]
    )
    snap = ls.snapshot(NOW)
    assert snap.house_power_kw.value == 2.0 and snap.house_power_kw.quality is Quality.DERIVED
    assert snap.buffer_temps_c.top.quality is Quality.UNAVAILABLE
    later = ls.snapshot(NOW + timedelta(minutes=4))  # power_s = 180 s
    assert later.pv_power_kw.quality is Quality.STALE
    assert later.house_power_kw.quality is Quality.UNAVAILABLE


def test_nachts_ist_eine_fehlende_erzeugung_null_und_das_haus_hat_eine_zahl() -> None:
    """Gesehen im Haus am 10.11.2026 um 20:46: Netz 0,6 kW, beim Haus ein Strich.

    Die Erzeugung meldete nachts nichts, und ohne sie ließ sich der Hausverbrauch nicht bilden.
    Steht die Sonne unter dem Horizont, ist die Erzeugung null, auch ungemeldet.
    """
    nacht = datetime(2026, 11, 10, 19, 46, tzinfo=UTC)
    ohne_pv = [
        RawReading(
            key="pv_power_kw",
            value=None,
            observed_at=nacht,
            quality=Quality.UNAVAILABLE,
            source="ha:pv",
        ),
        reading("grid_power_kw", 0.6, nacht),
        reading("battery_power_kw", 0.0, nacht),
        reading("heat_pump_power_kw", 0.1, nacht),
        reading("ev_power_kw", 0.0, nacht),
    ]

    ohne_sonnenstand = LiveState(HemsConfig())
    ohne_sonnenstand.apply(ohne_pv)
    alt = ohne_sonnenstand.snapshot(nacht)
    assert alt.pv_power_kw.value is None and alt.house_power_kw.value is None

    ls = LiveState(HemsConfig(), sonnenhoehe=lambda _t: -40.0)
    ls.apply(ohne_pv)
    snap = ls.snapshot(nacht)
    assert snap.pv_power_kw.value == 0.0 and snap.pv_power_kw.quality is Quality.DERIVED
    assert snap.pv_power_kw.source == "nacht:sonne-unter-horizont"
    assert snap.house_power_kw.value == 0.6 and snap.house_power_kw.quality is Quality.DERIVED
    assert snap.base_load_kw.value == 0.5

    # Am Tag bleibt eine fehlende Erzeugung eine Lücke: dort ist sie nicht bekannt.
    tag = LiveState(HemsConfig(), sonnenhoehe=lambda _t: 25.0)
    tag.apply(ohne_pv)
    assert tag.snapshot(nacht).house_power_kw.value is None

    # Auch ein veralteter Wert weicht nachts der Null, ein frischer bleibt stehen.
    alt_wert = LiveState(HemsConfig(), sonnenhoehe=lambda _t: -40.0)
    alt_wert.apply([reading("pv_power_kw", 2.1, nacht - timedelta(hours=3))])
    assert alt_wert.snapshot(nacht).pv_power_kw.value == 0.0
    frisch = LiveState(HemsConfig(), sonnenhoehe=lambda _t: -40.0)
    frisch.apply([reading("pv_power_kw", 0.02, nacht)])
    assert frisch.snapshot(nacht).pv_power_kw.value == 0.02


def test_newer_reading_wins_and_actuators_map() -> None:
    ls = LiveState(HemsConfig())
    ls.apply(
        [reading("pv_power_kw", 1.0, NOW), reading("pv_power_kw", 2.0, NOW - timedelta(seconds=5))]
    )
    assert ls.readings["pv_power_kw"].value == 1.0
    ls.apply([reading("actuator:coffee_machine", 1.0), reading("actuator:hp_release_contact", 0.0)])
    snap = ls.snapshot(NOW)
    assert snap.actuators["coffee_machine"].value == 1.0
    assert snap.hp_release_contact.value == 0.0


def test_die_alarmanlage_laesst_sich_schaerfen_aber_nicht_entschaerfen(client: TestClient) -> None:
    """Scharf ja, unscharf nein - die Anzeige hängt in der Küche.

    Ein Gerät mit Sitzungskeks ist genug, um eine Anlage scharf zu schalten; im schlimmsten Fall
    wird das lästig. Für das Gegenteil ist es zu wenig, und deshalb gibt es den Weg nicht.
    """
    vorher = client.get("/api/v1/live/state").json()["alarm"]
    assert vorher["state_de"] == "unscharf"
    assert vorher["can_arm"] is True

    r = client.post("/api/v1/control/alarm/arm", json={"mode": "away"})
    assert r.status_code == 200, r.text
    assert r.json()["ok"] is True
    assert r.json()["alarm"]["state_de"] == "unterwegs scharf"
    assert client.get("/api/v1/live/state").json()["alarm"]["state"] == 2.0

    # Es gibt keinen Modus, der entschärft.
    assert client.post("/api/v1/control/alarm/arm", json={"mode": "disarm"}).status_code == 422
    assert client.post("/api/v1/control/alarm/arm", json={"mode": "off"}).status_code == 422


def test_nachts_schweigt_die_erzeugung_nicht_sie_ist_null() -> None:
    """Der Wächter darf nachts keinen Alarm über die Leistungen stellen.

    Seit dem 22.11.2026 fällt eine Gruppenregel nach dem Schlüssel, der am **längsten** schweigt -
    vorher deckte der jüngste die anderen zu. Richtig so, nur gilt es auch für `power`: zwanzig
    Minuten nach Sonnenuntergang stand damit ein Alarm auf dem einen Platz des Ruhebilds, jede
    Nacht bis zum Sonnenaufgang, während der Dienst zwei Module weiter festhält, dass eine
    fehlende Erzeugung nachts bekannt ist (`pv_bei_nacht`). Die Ausnahme steht deshalb auch in
    `zuletzt_gesehen`, der Vorlage des Wächters.
    """
    nacht = datetime(2026, 11, 10, 19, 46, tzinfo=UTC)
    alt = nacht - timedelta(minutes=200)

    def bestand(ls: LiveState) -> None:
        ls.apply(
            [
                reading("pv_power_kw", 0.0, alt),
                reading("grid_power_kw", 0.6, nacht),
                reading("battery_power_kw", 0.0, nacht),
            ]
        )

    nachts = LiveState(HemsConfig(), sonnenhoehe=lambda _t: -40.0)
    bestand(nachts)
    assert nachts.zuletzt_gesehen(nacht)["pv_power_kw"] == nacht
    assert findings(nachts.zuletzt_gesehen(nacht), nacht) == []

    # Am Tag fehlt derselbe Wert wirklich, und dann soll er gemeldet werden.
    tags = LiveState(HemsConfig(), sonnenhoehe=lambda _t: 25.0)
    bestand(tags)
    assert tags.zuletzt_gesehen(nacht)["pv_power_kw"] == alt
    (befund,) = findings(tags.zuletzt_gesehen(nacht), nacht)
    assert befund.name == "power" and befund.severity == "alarm"
    assert "1 von 3 Messstellen" in befund.text_de

    # Ohne bekannten Sonnenstand bleibt alles, wie es gemeldet wurde.
    blind = LiveState(HemsConfig())
    bestand(blind)
    assert blind.zuletzt_gesehen(nacht)["pv_power_kw"] == alt


def test_die_pufferfuehler_haben_nur_eine_altersgrenze() -> None:
    """Eine Grenze, zwei Wege: über Home Assistant und über MQTT dieselbe Zahl.

    Bis zum 22.11.2026 stand in der Zuordnung 3600 und in `SensorTimeouts` 900. Wirksam war immer
    die kürzere, weil der Dienst jeden Wert beim Bauen der Aufnahme noch einmal altert - die 3600
    konnte nichts bewirken und sagte trotzdem etwas anderes. Dieser Test ist der Grund, warum das
    nicht wieder auseinanderlaufen kann.
    """
    wurzel = Path(__file__).resolve().parents[3]
    karte = yaml.safe_load((wurzel / "config" / "entities.home.yaml").read_text(encoding="utf-8"))
    frist = HemsConfig().timeouts.temperature_s
    puffer = [s for s in karte["sensors"] if str(s["key"]).startswith("buffer_temp_")]
    assert len(puffer) == 4
    for s in puffer:
        assert s["stale_after_s"] == frist, s["key"]


def test_die_stillstandsspur_zaehlt_gleiche_werte_und_bricht_bei_einer_luecke_ab() -> None:
    """Woran man einen stehenden Fühler erkennt - und woran nicht.

    Der letzte Wert allein sagt nichts darüber, ob er sich bewegt; dafür führt `LiveState` je
    Schlüssel mit, seit wann derselbe Wert kommt und wie oft. Eine leere Meldung dazwischen bricht
    die Spur ab: was nach einem Ausfall wieder kommt, ist ein neuer Wert und kein alter Stillstand.
    """
    ls = LiveState(HemsConfig())
    for i in range(5):
        ls.apply([reading("buffer_temp_top_c", 58.0, NOW + timedelta(minutes=i))])
    spur = ls.unchanged["buffer_temp_top_c"]
    assert (spur.meldungen, spur.unveraendert_min) == (5, 4.0)
    # Die Spanne ist die gemeldete, nicht „bis jetzt": die Zeit nach der letzten Meldung ist
    # Stille, und die hat ihre eigene Regel.
    ls.apply([reading("buffer_temp_top_c", 58.1, NOW + timedelta(minutes=6))])
    assert ls.unchanged["buffer_temp_top_c"].meldungen == 1
    ls.apply(
        [
            RawReading(
                key="buffer_temp_top_c",
                value=None,
                observed_at=NOW + timedelta(minutes=7),
                quality=Quality.UNAVAILABLE,
                source="ha:buffer_temp_top_c",
            )
        ]
    )
    assert "buffer_temp_top_c" not in ls.unchanged
