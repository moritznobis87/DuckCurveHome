"""Die Sicherheitslogik der Raumautomatik: vor allem, wann sie nichts tut."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from dch_api.application.room_automatik import (
    RaumZustand,
    Stellen,
    Zurueckziehen,
    entscheide,
)

JETZT = datetime(2026, 1, 15, 15, 0, tzinfo=UTC)


def zustand(**over: object) -> RaumZustand:
    werte: dict[str, object] = {
        "base_setpoint_c": 22.2,
        "offset_k": 0.5,
        "written_setpoint_c": 22.7,
        "written_at": JETZT - timedelta(minutes=30),
        "paused_until": None,
    }
    werte.update(over)
    return RaumZustand(**werte)  # type: ignore[arg-type]


def test_anheben_merkt_sich_die_rueckfahrkarte() -> None:
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.5,
        grund="Vorladen",
        gemessen_c=22.2,
        gemessen_at=JETZT,
        fenster_offen=False,
        zustand=None,
    )
    assert isinstance(a, Stellen)
    assert a.setpoint_c == 22.7
    assert a.base_c == 22.2  # darauf wird zurückgestellt
    assert a.offset_k == 0.5


def test_zurueck_auf_den_grundwert() -> None:
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.0,
        grund="Preishoch vorbei",
        gemessen_c=22.7,
        gemessen_at=JETZT,
        fenster_offen=False,
        zustand=zustand(),
    )
    assert isinstance(a, Stellen)
    assert a.setpoint_c == 22.2
    assert a.offset_k == 0.0


def test_wer_von_hand_stellt_hat_recht() -> None:
    """Der gemeldete Sollwert passt nicht zu dem, was die Automatik geschrieben hat."""
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.5,
        grund="Vorladen",
        gemessen_c=21.0,  # jemand hat heruntergedreht
        gemessen_at=JETZT,
        fenster_offen=False,
        zustand=zustand(),
    )
    assert isinstance(a, Zurueckziehen)
    assert a.ruhe_bis == JETZT + timedelta(hours=12)
    assert "von Hand" in a.grund and "21,0" in a.grund


def test_der_eigene_befehl_gilt_nicht_als_fremde_aenderung() -> None:
    """Direkt nach dem Stellen meldet die Anlage noch den alten Wert. Das ist kein Eingriff."""
    gerade = zustand(written_at=JETZT - timedelta(minutes=1))
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.5,
        grund="Vorladen",
        gemessen_c=22.2,  # noch der alte Wert
        gemessen_at=JETZT,
        fenster_offen=False,
        zustand=gerade,
    )
    assert a is None  # Schonfrist, kein Rückzug


def test_offenes_fenster_haelt_die_automatik_an() -> None:
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.5,
        grund="Vorladen",
        gemessen_c=22.7,
        gemessen_at=JETZT,
        fenster_offen=True,
        zustand=zustand(),
    )
    assert isinstance(a, Stellen)
    assert a.setpoint_c == 22.2  # zurück auf den Grundwert, nicht weiter laden


def test_was_schon_richtig_steht_wird_nicht_noch_einmal_gestellt() -> None:
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.5,
        grund="Vorladen",
        gemessen_c=22.7,
        gemessen_at=JETZT,
        fenster_offen=False,
        zustand=zustand(),
    )
    assert a is None


def test_ohne_anhebung_wird_die_rueckfahrkarte_weggelegt() -> None:
    fertig = zustand(offset_k=0.0, written_setpoint_c=22.2)
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.0,
        grund="aus",
        gemessen_c=22.2,
        gemessen_at=JETZT,
        fenster_offen=False,
        zustand=fertig,
    )
    assert isinstance(a, Zurueckziehen)
    assert a.ruhe_bis is None


def test_waehrend_der_ruhe_passiert_nichts() -> None:
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.5,
        grund="Vorladen",
        gemessen_c=22.2,
        gemessen_at=JETZT,
        fenster_offen=False,
        zustand=zustand(offset_k=0.0, paused_until=JETZT + timedelta(hours=2)),
    )
    assert a is None


def test_zwei_befehle_brauchen_abstand() -> None:
    a = entscheide(
        now=JETZT,
        ziel_offset_k=0.0,
        grund="zurueck",
        gemessen_c=22.7,
        gemessen_at=JETZT,
        fenster_offen=False,
        zustand=zustand(written_at=JETZT - timedelta(minutes=2)),
    )
    assert a is None


def test_ohne_gemeldeten_sollwert_kein_eingriff() -> None:
    assert (
        entscheide(
            now=JETZT,
            ziel_offset_k=0.5,
            grund="Vorladen",
            gemessen_c=None,
            gemessen_at=None,
            fenster_offen=False,
            zustand=None,
        )
        is None
    )


def test_die_grenzen_der_einstellungen_stehen_im_dienst() -> None:
    """Was eine Heizung verstellen darf, ist keine Frage der Anzeige."""
    from dch_api.application.room_automatik import AutomatikConfig

    c = AutomatikConfig.from_payload(
        {"enabled": True, "rooms": [1, 2], "delta_k": 9.0, "draw_k": 5.0, "lead_h": 99.0}
    )
    assert c.delta_k == 1.5
    assert c.draw_k == 1.0
    assert c.lead_h == 8.0
    assert c.rooms == (1, 2)
    # Unsinn im Rumpf wirft nicht, sondern fällt auf die Voreinstellung zurück.
    leer = AutomatikConfig.from_payload({"rooms": "alle", "delta_k": "viel"})
    assert leer.enabled is False and leer.rooms == () and leer.delta_k == 0.5
    # Und die Voreinstellung ist aus.
    assert AutomatikConfig().enabled is False
    assert AutomatikConfig().policy().delta_k == 0.5
