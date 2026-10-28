"""Wärme in Räume mit offenem Fenster: verteilt nach offenen Heizkreisen."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from hems_core.thermal.ventilation import RoomMinute, ventilation_split

T0 = datetime(2026, 1, 15, 8, 0, tzinfo=UTC)
KREISE = {1: 4, 2: 2, 3: 2}


def minuten(n: int) -> list[datetime]:
    return [T0 + timedelta(minutes=i) for i in range(n)]


def reihe(n: int, raum: int, valve: float | None, window: float | None) -> list[RoomMinute]:
    return [RoomMinute(at=t, room_id=raum, valve=valve, window=window) for t in minuten(n)]


def entnahme(n: int, kw: float) -> dict[datetime, float]:
    return dict.fromkeys(minuten(n), kw)


def test_offenes_fenster_bekommt_seinen_anteil() -> None:
    # 60 Minuten, 6 kW Entnahme. Raum 1 hat alle vier Kreise offen, Raum 2 beide: 4 zu 2.
    rows = [*reihe(60, 1, 1.0, 1.0), *reihe(60, 2, 1.0, 0.0)]
    r = ventilation_split(entnahme(60, 6.0), rows, KREISE)
    # Raum 1 bekommt zwei Drittel von 6 kWh.
    assert r.kwh == 4.0
    assert r.share == 0.6667
    assert r.open_minutes == 60
    assert [x.room_id for x in r.rooms] == [1]
    assert r.rooms[0].heating_minutes == 60


def test_ohne_offene_kreise_wird_nichts_zugerechnet() -> None:
    """Steht kein Ventil offen, ist die Entnahme Warmwasser - und kein Fenster bekommt sie."""
    rows = [*reihe(30, 1, 0.0, 1.0), *reihe(30, 2, 0.0, 0.0)]
    r = ventilation_split(entnahme(30, 5.0), rows, KREISE)
    assert r.kwh == 0.0
    # Das offene Fenster wird trotzdem gezählt: Es war offen, nur ohne Heizung.
    assert r.open_minutes == 30
    assert r.rooms[0].heating_minutes == 0


def test_mehrere_raeume_mit_offenem_fenster() -> None:
    rows = [*reihe(60, 1, 0.5, 1.0), *reihe(60, 2, 1.0, 1.0), *reihe(60, 3, 1.0, 0.0)]
    # Gewichte: Raum 1 = 0,5*4 = 2, Raum 2 = 1*2 = 2, Raum 3 = 1*2 = 2. Zwei von drei offen.
    r = ventilation_split(entnahme(60, 3.0), rows, KREISE)
    assert r.kwh == 2.0
    assert len(r.rooms) == 2


def test_ohne_fensterkontakt_wird_nichts_behauptet() -> None:
    rows = [*reihe(60, 1, 1.0, None), *reihe(60, 2, 1.0, None)]
    r = ventilation_split(entnahme(60, 6.0), rows, KREISE)
    assert r.kwh == 0.0
    assert r.minutes_known == 0
    assert "Keine Fenster" in r.note_de


def test_der_satz_nennt_methode_und_grenze() -> None:
    rows = [*reihe(60, 1, 1.0, 1.0), *reihe(60, 2, 1.0, 0.0)]
    note = ventilation_split(entnahme(60, 6.0), rows, KREISE).note_de
    assert "Heizkreisen" in note
    assert "Warmwasser" in note  # die Grenze steht dabei
    assert "4,0 kWh" in note


def test_ein_ruhiger_tag_sagt_das_auch() -> None:
    rows = [*reihe(60, 1, 1.0, 0.0), *reihe(60, 2, 1.0, 0.0)]
    r = ventilation_split(entnahme(60, 6.0), rows, KREISE)
    assert r.kwh == 0.0
    assert r.minutes_known == 60
    assert "Kein Fenster" in r.note_de


def test_ohne_entnahme_kein_anteil() -> None:
    rows = reihe(10, 1, 1.0, 1.0)
    r = ventilation_split(entnahme(10, 0.0), rows, KREISE)
    assert r.kwh == 0.0
    assert r.share is None


def test_null_prozent_steht_nicht_da() -> None:
    """Eine gerundete Null ist keine Auskunft; unter einem Prozent sagt der Satz das in Worten."""
    # Zehn Stunden Heizen, aber nur eine Minute mit offenem Fenster.
    zeiten = minuten(600)
    rows: list[RoomMinute] = []
    for i, t in enumerate(zeiten):
        rows.append(RoomMinute(at=t, room_id=1, valve=1.0, window=1.0 if i == 0 else 0.0))
        rows.append(RoomMinute(at=t, room_id=2, valve=1.0, window=0.0))
    r = ventilation_split(dict.fromkeys(zeiten, 6.0), rows, KREISE)
    assert r.share is not None and r.share < 0.01
    assert "0 Prozent" not in r.note_de
    assert "weniger als ein Prozent" in r.note_de
