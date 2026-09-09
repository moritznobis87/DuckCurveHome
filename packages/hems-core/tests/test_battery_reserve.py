from __future__ import annotations

from hems_core.control import decide_reserve

FLOOR = 0.06


def test_ohne_ladestand_wird_nicht_eingegriffen() -> None:
    """Ein Regler, der ohne Messwert schaltet, ist gefährlicher als gar keiner."""
    d = decide_reserve(soc=None, reserve_soc=FLOOR, surplus_kw=None, holding=False)
    assert d.command == "normal"


def test_untergrenze_aus_bedeutet_kein_eingriff() -> None:
    d = decide_reserve(soc=0.01, reserve_soc=0.0, surplus_kw=None, holding=False)
    assert d.command == "normal"


def test_an_der_grenze_wird_angehalten() -> None:
    d = decide_reserve(soc=0.06, reserve_soc=FLOOR, surplus_kw=0.0, holding=False)
    assert d.holding
    assert "6" in d.reason_de


def test_ueber_der_grenze_laeuft_er_weiter() -> None:
    d = decide_reserve(soc=0.35, reserve_soc=FLOOR, surplus_kw=0.0, holding=False)
    assert d.command == "normal"


def test_hysterese_haelt_knapp_ueber_der_grenze() -> None:
    """Ohne Hysterese pendelt der Regler an der Grenze, und jeder Wechsel geht in die Cloud."""
    assert decide_reserve(soc=0.07, reserve_soc=FLOOR, surplus_kw=0.0, holding=True).holding
    assert not decide_reserve(soc=0.09, reserve_soc=FLOOR, surplus_kw=0.0, holding=True).holding
    # Ohne vorheriges Halten greift die Hysterese nicht, sonst hielte sie ohne Anlass an.
    assert not decide_reserve(soc=0.07, reserve_soc=FLOOR, surplus_kw=0.0, holding=False).holding


def test_ueberschuss_gibt_den_speicher_frei() -> None:
    """`stopped` hält auch das Laden an: bei Sonne muss die Grenze zurücktreten."""
    d = decide_reserve(soc=0.03, reserve_soc=FLOOR, surplus_kw=1.5, holding=True)
    assert d.command == "normal"
    assert "Überschuss" in d.reason_de


def test_kleiner_ueberschuss_gibt_nicht_frei() -> None:
    """Ein Strohfeuer von 100 W traegt den Speicher nicht; er liefe sofort wieder unter die Grenze."""
    assert decide_reserve(soc=0.03, reserve_soc=FLOOR, surplus_kw=0.1, holding=True).holding
