"""Das Raumprotokoll: Sprünge der Messreihe und Ereignisse zu einer Zeitleiste verschmelzen.

Die Raumnamen hier sind erfunden. Das Repository ist öffentlich.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from dch_api.application import room_log

T0 = datetime(2026, 10, 31, 6, 0, tzinfo=UTC)


def _zeilen(*werte: float | None) -> list[dict[str, float | str | None]]:
    """Minutenzeilen ab T0, eine je Minute. `None` heißt: in dieser Minute kein Wert."""
    return [
        {
            "ts": (T0 + timedelta(minutes=i)).isoformat().replace("+00:00", "Z"),
            "room_7_setpoint_c": w,
        }
        for i, w in enumerate(werte)
    ]


def _ev(min_: float, code: str, text: str, **context: object) -> room_log.RohEreignis:
    return room_log.RohEreignis(
        at=T0 + timedelta(minutes=min_), code=code, message=text, context=context
    )


# ------------------------------------------------------------------ Punkte und Sprünge


def test_punkte_ueberspringen_leere_minuten() -> None:
    p = room_log.punkte(_zeilen(21.0, None, 21.0), "room_7_setpoint_c")
    assert [w for _, w in p] == [21.0, 21.0]
    assert [t.minute for t, _ in p] == [0, 2]


def test_punkte_ignorieren_fremde_reihen_und_kaputte_zeiten() -> None:
    zeilen: list[dict[str, float | str | None]] = [
        {"ts": "keine-zeit", "room_7_setpoint_c": 21.0},
        {"ts": T0.isoformat(), "room_7_setpoint_c": None},
        {"ts": T0.isoformat(), "room_8_setpoint_c": 19.0},
    ]
    assert room_log.punkte(zeilen, "room_7_setpoint_c") == []


def test_ein_sprung_wird_auf_den_ersten_neuen_wert_datiert() -> None:
    s = room_log.spruenge(room_log.punkte(_zeilen(21.0, 21.0, 22.5, 22.5), "room_7_setpoint_c"))
    assert len(s) == 1
    assert (s[0].von, s[0].nach, s[0].at.minute) == (21.0, 22.5, 2)


def test_rundungsrauschen_ist_kein_sprung() -> None:
    # Controme führt Zehntel; 0,04 K sind keine Änderung, sondern eine andere Nachkommastelle.
    assert room_log.spruenge(room_log.punkte(_zeilen(21.0, 21.04), "room_7_setpoint_c")) == []


def test_eine_luecke_erzeugt_keinen_sprung() -> None:
    # Eine Stunde Stille, danach derselbe Wert: nichts ist passiert.
    p = room_log.punkte(_zeilen(21.0, *([None] * 60), 21.0), "room_7_setpoint_c")
    assert room_log.spruenge(p) == []


# ------------------------------------------------------------------ Zuordnung


def test_eigener_befehl_und_sprung_werden_ein_eintrag() -> None:
    spruenge = room_log.spruenge(
        room_log.punkte(_zeilen(21.0, 21.0, 21.0, 22.0), "room_7_setpoint_c")
    )
    eintraege = room_log.verschmelze(
        spruenge,
        [
            _ev(
                1,
                room_log.CODE_SETPOINT,
                "Nordzimmer: Sollwert auf 22.0 Grad gestellt",
                room=7,
                to=22.0,
            )
        ],
    )
    assert len(eintraege) == 1
    e = eintraege[0]
    assert (e.quelle, e.art, e.von, e.nach) == ("app", "sollwert", 21.0, 22.0)
    # Datiert wird auf den Messwert, nicht auf den Befehl: dann stand er wirklich so.
    assert e.at.minute == 3


def test_die_automatik_bringt_ihren_grund_mit() -> None:
    spruenge = room_log.spruenge(room_log.punkte(_zeilen(21.0, 21.5), "room_7_setpoint_c"))
    eintraege = room_log.verschmelze(
        spruenge,
        [
            _ev(
                0,
                room_log.CODE_AUTOMATIK,
                "Nordzimmer: Sollwert 21,0 auf 21,5 (Vorladen vor dem Preishoch)",
                room=7,
                to=21.5,
                base=21.0,
            )
        ],
    )
    assert eintraege[0].quelle == "automatik"
    assert "Preishoch" in eintraege[0].text


def test_ein_sprung_ohne_ereignis_heisst_von_aussen() -> None:
    spruenge = room_log.spruenge(room_log.punkte(_zeilen(21.0, 23.0), "room_7_setpoint_c"))
    eintraege = room_log.verschmelze(spruenge, [])
    assert (eintraege[0].quelle, eintraege[0].art) == ("extern", "sollwert")
    assert eintraege[0].text == ""


def test_ein_ereignis_ohne_sprung_heisst_befehl_ohne_wirkung() -> None:
    eintraege = room_log.verschmelze(
        [],
        [
            _ev(
                1,
                room_log.CODE_SETPOINT,
                "Nordzimmer: Sollwert auf 22.0 Grad gestellt",
                room=7,
                to=22.0,
                **{"from": 21.0},
            )
        ],
    )
    assert (eintraege[0].art, eintraege[0].von, eintraege[0].nach) == ("befehl", 21.0, 22.0)


def test_zu_spaeter_sprung_zaehlt_nicht_mehr_als_wirkung() -> None:
    # Eine halbe Stunde nach dem Befehl ist ein Sprung auf denselben Wert ein neues Ereignis.
    zeilen = _zeilen(21.0, *([21.0] * 29), 22.0)
    spruenge = room_log.spruenge(room_log.punkte(zeilen, "room_7_setpoint_c"))
    eintraege = room_log.verschmelze(
        spruenge, [_ev(0, room_log.CODE_SETPOINT, "gestellt", room=7, to=22.0)]
    )
    assert {e.art for e in eintraege} == {"befehl", "sollwert"}
    assert [e.quelle for e in eintraege if e.art == "sollwert"] == ["extern"]


def test_jeder_sprung_gehoert_hoechstens_einem_ereignis() -> None:
    # Zwei Befehle auf denselben Wert, aber nur ein Sprung: der zweite bleibt ohne Wirkung.
    spruenge = room_log.spruenge(room_log.punkte(_zeilen(21.0, 22.0, 22.0), "room_7_setpoint_c"))
    eintraege = room_log.verschmelze(
        spruenge,
        [
            _ev(0, room_log.CODE_AUTOMATIK, "erster", room=7, to=22.0),
            _ev(1, room_log.CODE_AUTOMATIK, "zweiter", room=7, to=22.0),
        ],
    )
    assert [e.art for e in eintraege] == ["sollwert", "befehl"]


def test_ein_sprung_kurz_vor_dem_ereignis_zaehlt_noch_dazu() -> None:
    # Die Brücke stößt die Abfrage sofort an; der Messwert kann vor dem Protokolleintrag liegen.
    spruenge = room_log.spruenge(room_log.punkte(_zeilen(21.0, 22.0), "room_7_setpoint_c"))
    eintraege = room_log.verschmelze(
        spruenge, [_ev(1.5, room_log.CODE_SETPOINT, "gestellt", room=7, to=22.0)]
    )
    assert eintraege[0].art == "sollwert"


# ------------------------------------------------------------------ Auswahl der Ereignisse


def test_rueckzug_der_automatik_kommt_ohne_werte_ins_protokoll() -> None:
    eintraege = room_log.verschmelze(
        [], [_ev(0, room_log.CODE_AUTOMATIK, "Nordzimmer: jemand hat von Hand gestellt.", room=7)]
    )
    assert (eintraege[0].art, eintraege[0].quelle) == ("ruhe", "automatik")
    assert eintraege[0].nach is None


def test_die_einstellung_der_automatik_gilt_fuer_jeden_raum() -> None:
    ev = _ev(
        0,
        room_log.CODE_AUTOMATIK,
        "Automatik eingeschaltet für 3 Räume",
        enabled=True,
        rooms=[1, 2, 3],
    )
    assert room_log.gehoert_zu_raum(ev, 7) is True
    assert room_log._art(ev) == "einstellung"


def test_ein_fremder_raum_gehoert_nicht_ins_protokoll() -> None:
    ev = _ev(0, room_log.CODE_SETPOINT, "Südzimmer gestellt", room=8, to=20.0)
    assert room_log.gehoert_zu_raum(ev, 7) is False
    assert room_log.gehoert_zu_raum(ev, 8) is True


def test_die_zeitleiste_ist_chronologisch() -> None:
    spruenge = room_log.spruenge(
        room_log.punkte(_zeilen(21.0, 22.0, 22.0, 23.0), "room_7_setpoint_c")
    )
    eintraege = room_log.verschmelze(
        spruenge, [_ev(3, room_log.CODE_SETPOINT, "gestellt", room=7, to=23.0)]
    )
    assert [e.at for e in eintraege] == sorted(e.at for e in eintraege)
    assert [e.quelle for e in eintraege] == ["extern", "app"]
