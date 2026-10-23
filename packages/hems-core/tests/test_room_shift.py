"""Das Modell hinter der Frage „was kostet ein halbes Grad mehr"."""

from __future__ import annotations

import math

import pytest

from hems_core.domain.config import HeatDemandConfig
from hems_core.thermal.room_shift import (
    TAU_RAUM_H,
    capacity_kwh_per_k,
    effect,
    hold_hours,
    share_of_house,
)

CFG = HeatDemandConfig()


def test_der_anteil_kommt_aus_den_heizkreisen() -> None:
    assert share_of_house(4, 20) == pytest.approx(0.2)
    assert share_of_house(20, 20) == pytest.approx(1.0)
    # Ein Raum ohne gemeldete Kreise bekommt einen Kreis, nicht null: sonst wäre seine Wirkung
    # null und die Anzeige behauptete, Heizen koste dort nichts.
    assert share_of_house(0, 20) == pytest.approx(0.05)
    assert share_of_house(4, 0) == 0.0


def test_die_kapazitaet_folgt_aus_zeitkonstante_mal_verlust() -> None:
    """tau = C / H, also C = tau * H. Für dieses Haus rund 5,5 kWh je Kelvin."""
    assert capacity_kwh_per_k(CFG) == pytest.approx(25.0 * 0.22)
    assert capacity_kwh_per_k(CFG, tau_h=13.0) == pytest.approx(13.0 * 0.22)


def test_dauerkosten_wachsen_linear_mit_anteil_und_kelvin() -> None:
    klein = effect(
        delta_k=0.5, circuits=2, total_circuits=20, cfg=CFG, outdoor_c=5.0, price_ct_kwh=30.0
    )
    doppelt_kreise = effect(
        delta_k=0.5, circuits=4, total_circuits=20, cfg=CFG, outdoor_c=5.0, price_ct_kwh=30.0
    )
    doppelt_kelvin = effect(
        delta_k=1.0, circuits=2, total_circuits=20, cfg=CFG, outdoor_c=5.0, price_ct_kwh=30.0
    )
    # Die Werte sind auf zwei Stellen gerundet, darum die Toleranz: verglichen wird die
    # Verdopplung, nicht die letzte Nachkommastelle.
    assert doppelt_kreise.daily_kwh_th == pytest.approx(2 * klein.daily_kwh_th, abs=0.011)
    assert doppelt_kelvin.daily_kwh_th == pytest.approx(2 * klein.daily_kwh_th, abs=0.011)
    # Strom ist Wärme durch Arbeitszahl, und die Arbeitszahl kommt aus der Kennlinie.
    assert klein.daily_kwh_el == pytest.approx(klein.daily_kwh_th / klein.cop, abs=0.01)


def test_kalte_luft_macht_das_anheben_teurer() -> None:
    """Nicht weil der Verlust steigt - der hängt an der Innentemperatur -, sondern weil die
    Wärmepumpe bei Frost eine schlechtere Arbeitszahl hat."""
    mild = effect(
        delta_k=0.5, circuits=4, total_circuits=20, cfg=CFG, outdoor_c=10.0, price_ct_kwh=30.0
    )
    frost = effect(
        delta_k=0.5, circuits=4, total_circuits=20, cfg=CFG, outdoor_c=-5.0, price_ct_kwh=30.0
    )
    assert frost.cop < mild.cop
    assert frost.daily_kwh_el > mild.daily_kwh_el
    assert frost.daily_eur > mild.daily_eur


def test_ohne_preis_steht_keine_zahl_in_euro() -> None:
    ohne = effect(
        delta_k=0.5, circuits=4, total_circuits=20, cfg=CFG, outdoor_c=5.0, price_ct_kwh=None
    )
    assert ohne.daily_eur == 0.0
    assert ohne.shift_saving_eur is None


def test_verschieben_lohnt_nur_bei_abstand_und_kostet_den_verlust() -> None:
    gemeinsam = dict(
        delta_k=0.5, circuits=4, total_circuits=20, cfg=CFG, outdoor_c=5.0, price_ct_kwh=30.0
    )
    weit = effect(**gemeinsam, cheap_ct_kwh=10.0, expensive_ct_kwh=50.0)
    eng = effect(**gemeinsam, cheap_ct_kwh=29.0, expensive_ct_kwh=31.0)
    assert weit.shift_saving_eur is not None and eng.shift_saving_eur is not None
    assert weit.shift_saving_eur > eng.shift_saving_eur
    # Bei gleichem Preis bleibt nur der Verlust übrig: Vorladen ist dann ein Verlustgeschäft.
    gleich = effect(**gemeinsam, cheap_ct_kwh=30.0, expensive_ct_kwh=30.0)
    assert gleich.shift_saving_eur is not None and gleich.shift_saving_eur < 0

    # Je länger zwischen Laden und Zehren liegt, desto weniger bleibt.
    frueh = effect(**gemeinsam, cheap_ct_kwh=10.0, expensive_ct_kwh=50.0, shift_hours=18.0)
    assert frueh.shift_saving_eur is not None
    assert frueh.shift_saving_eur < weit.shift_saving_eur


def test_die_haltezeit_folgt_dem_exponentiellen_abfall() -> None:
    assert hold_hours(0.5, toleranz_k=0.25) == pytest.approx(TAU_RAUM_H * math.log(2), abs=0.05)
    # Eine Anhebung, die schon unter der Toleranz liegt, hält keine Zeit.
    assert hold_hours(0.1, toleranz_k=0.25) == 0.0
    e = effect(
        delta_k=0.5, circuits=4, total_circuits=20, cfg=CFG, outdoor_c=5.0, price_ct_kwh=None
    )
    assert e.half_life_h == pytest.approx(17.3, abs=0.1)


def test_der_satz_erklaert_die_herkunft_der_zahlen() -> None:
    """Eine geschätzte Zahl ohne ihre Grundlage ist eine Behauptung."""
    e = effect(
        delta_k=0.5, circuits=4, total_circuits=20, cfg=CFG, outdoor_c=5.0, price_ct_kwh=30.0
    )
    assert e.note_de.startswith("Geschätzt")
    assert "0,22 kW je Kelvin" in e.note_de
    assert "4 von 20" in e.note_de
    assert "25 Stunden" in e.note_de
    # Deutsche Zahlen, keine englischen Punkte.
    assert "0.5" not in e.note_de
