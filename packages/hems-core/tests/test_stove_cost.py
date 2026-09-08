"""Wärmepreis des Pelletofens und der Vergleich mit der Wärmepumpe.

Die Zahlen sind von Hand nachgerechnet, damit ein Fehler in der Formel auffällt und nicht nur eine
Abweichung vom letzten Lauf. Gerät: 12 kW gesamt, davon 9 kW ins Wasser, 92 % Verbrennung,
450 €/t, 4,9 kWh/kg.
"""

from __future__ import annotations

import pytest

from hems_core.accounting.stove_cost import (
    break_even_cop,
    cheaper_source,
    heat_pump_ct_per_kwh,
    stove_economics,
)
from hems_core.domain import StoveConfig

CFG = StoveConfig()


def test_die_kette_vom_pellet_zur_waerme() -> None:
    """12 / 0,92 = 13,04 kW Feuerung; / 4,9 = 2,661 kg/h; × 0,45 €/kg = 1,197 €/h."""
    e = stove_economics(CFG)
    assert e.fuel_kw == pytest.approx(13.04, abs=0.01)
    assert e.chimney_loss_kw == pytest.approx(1.04, abs=0.01)
    assert e.water_heat_kw == 9.0
    assert e.room_heat_kw == 3.0
    assert e.kg_per_hour == pytest.approx(2.661, abs=0.002)
    assert e.eur_per_hour == pytest.approx(1.197, abs=0.002)


def test_die_raumwaerme_entscheidet_ueber_den_waermepreis() -> None:
    """Derselbe Ofen kostet 13,3 oder 10,0 ct/kWh, je nachdem was man als Nutzen zählt.

    Das ist keine Rechenungenauigkeit, sondern eine Bewertungsfrage. Deshalb gibt die Rechnung
    beide Zahlen aus, statt sich stillschweigend für eine zu entscheiden.
    """
    e = stove_economics(CFG)
    assert e.ct_per_kwh_water == pytest.approx(13.3, abs=0.1)  # 1,197 / 9
    assert e.ct_per_kwh_useful == pytest.approx(9.98, abs=0.1)  # 1,197 / 12


def test_ohne_anrechnung_der_raumwaerme_zaehlt_nur_der_puffer() -> None:
    e = stove_economics(CFG.model_copy(update={"room_heat_credit": 0.0}))
    assert e.ct_per_kwh_useful == e.ct_per_kwh_water


def test_teurere_pellets_schlagen_linear_durch() -> None:
    teuer = stove_economics(CFG.model_copy(update={"pellet_price_eur_per_t": 900.0}))
    assert teuer.ct_per_kwh_water == pytest.approx(
        2 * stove_economics(CFG).ct_per_kwh_water, abs=0.1
    )


def test_besserer_heizwert_senkt_den_preis() -> None:
    """Die Zahl, die der Hausherr auf 5,4 geschätzt hatte. Sie wirkt, deshalb steht sie einstellbar."""
    gut = stove_economics(CFG.model_copy(update={"pellet_kwh_per_kg": 5.4}))
    assert gut.ct_per_kwh_water < stove_economics(CFG).ct_per_kwh_water


def test_waermepumpe_ist_strompreis_durch_arbeitszahl() -> None:
    assert heat_pump_ct_per_kwh(30.0, 3.0) == pytest.approx(10.0)
    assert heat_pump_ct_per_kwh(30.0, 2.4) == pytest.approx(12.5)
    assert heat_pump_ct_per_kwh(30.0, 0.0) == float("inf")


def test_bei_kaelte_und_teurem_strom_gewinnt_der_ofen() -> None:
    """Minus sieben Grad, COP 2,4, 45 ct/kWh: 18,75 ct Wärmepumpe gegen 9,98 ct Ofen."""
    c = cheaper_source(CFG, price_ct_kwh=45.0, cop=2.4)
    assert c.cheaper == "stove"
    assert c.heat_pump_ct == pytest.approx(18.75, abs=0.05)
    assert c.saving_ct_per_kwh > 8
    assert "Ofen günstiger" in c.note_de


def test_bei_mildem_wetter_und_billigem_strom_gewinnt_die_waermepumpe() -> None:
    """Sieben Grad, COP 3,5, 20 ct/kWh: 5,71 ct gegen 9,98 ct."""
    c = cheaper_source(CFG, price_ct_kwh=20.0, cop=3.5)
    assert c.cheaper == "heat_pump"
    assert c.heat_pump_ct == pytest.approx(5.71, abs=0.05)
    assert "Wärmepumpe günstiger" in c.note_de


def test_die_lesart_kann_die_entscheidung_kippen() -> None:
    """Bei 30 ct und COP 2,4 liegt die Wärmepumpe bei 12,5 ct, also zwischen den beiden Ofenpreisen."""
    mit = cheaper_source(CFG, price_ct_kwh=30.0, cop=2.4, credit_room_heat=True)
    ohne = cheaper_source(CFG, price_ct_kwh=30.0, cop=2.4, credit_room_heat=False)
    assert mit.cheaper == "stove"
    assert ohne.cheaper == "heat_pump"
    assert "mit angerechneter Raumwärme" in mit.note_de
    assert "nur auf die Pufferwärme" in ohne.note_de


def test_break_even_cop_ist_die_zahl_fuer_die_kennlinie() -> None:
    """Ab welcher Arbeitszahl schlägt die Wärmepumpe den Ofen? Bei 30 ct: 30 / 9,98 = 3,01."""
    assert break_even_cop(CFG, 30.0) == pytest.approx(3.01, abs=0.02)
    assert break_even_cop(CFG, 45.0) == pytest.approx(4.51, abs=0.02)
    # Ohne Anrechnung der Raumwärme ist der Ofen teurer, die Schwelle sinkt entsprechend.
    assert break_even_cop(CFG, 30.0, credit_room_heat=False) == pytest.approx(2.26, abs=0.02)


def test_die_naechtliche_frage_des_hausherrn() -> None:
    """Kalte Winternacht, Ofen an statt Wärmepumpe: die bisherige Handregel wird nachgerechnet.

    Minus fünf Grad heißt nach der Kennlinie etwa COP 2,5. Bei 32 ct Nachtstrom kostet die
    Wärmepumpe 12,8 ct/kWh, der Ofen 10,0. Die Handregel war also richtig, und zwar aus Gründen,
    nicht aus Gefühl.
    """
    c = cheaper_source(CFG, price_ct_kwh=32.0, cop=2.5)
    assert c.cheaper == "stove"
    assert c.heat_pump_ct == pytest.approx(12.8, abs=0.05)
