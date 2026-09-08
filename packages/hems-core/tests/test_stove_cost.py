"""Wärmepreis des Pelletofens und der Vergleich mit der Wärmepumpe.

Die Zahlen sind von Hand nachgerechnet, damit ein Fehler in der Formel auffällt und nicht nur eine
Abweichung vom letzten Lauf. Gerät laut Datenblatt (MCZ Star Hydromatic): 11,9 kW gesamt, davon
10 kW ins Wasser, 91,1 % Wirkungsgrad bei Maximalbetrieb, 75 W Eigenverbrauch, 2,7 kg/h.
Teillast: 3,2 kW nutzbar, davon 1,8 ins Wasser, 96,1 % Wirkungsgrad, 0,7 kg/h.
Pellets 450 €/t bei 4,9 kWh/kg.
"""

from __future__ import annotations

import pytest

from hems_core.accounting.stove_cost import (
    break_even_cop,
    buffer_kwh_per_kg,
    cheaper_source,
    daily_budget,
    heat_pump_ct_per_kwh,
    hopper_runtime_h,
    stove_economics,
    stove_economics_min_load,
)
from hems_core.domain import StoveConfig

CFG = StoveConfig()


def test_die_kette_vom_pellet_zur_waerme() -> None:
    """11,9 / 0,911 = 13,06 kW Feuerung; / 4,9 = 2,666 kg/h; × 0,45 €/kg = 1,200 €/h."""
    e = stove_economics(CFG)
    assert e.fuel_kw == pytest.approx(13.06, abs=0.01)
    assert e.chimney_loss_kw == pytest.approx(1.16, abs=0.01)
    assert e.water_heat_kw == 10.0
    assert e.room_heat_kw == pytest.approx(1.9, abs=0.01)
    assert e.kg_per_hour == pytest.approx(2.666, abs=0.002)
    assert e.pellet_eur_per_hour == pytest.approx(1.200, abs=0.002)


def test_die_kette_prueft_sich_am_datenblatt() -> None:
    """Der gerechnete Durchsatz muss den angegebenen treffen, sonst stimmt eine Eingangsgröße nicht.

    Das ist die wertvollste Eigenschaft dieser Zahlen: Leistung, Wirkungsgrad und Verbrauch stammen
    aus derselben Quelle und sind über den Heizwert verknüpft. Wer den Heizwert falsch einträgt,
    fällt hier auf, statt still eine falsche Entscheidung zu erzeugen.
    """
    e = stove_economics(CFG)
    assert abs(e.datasheet_deviation) < 0.02, "2,666 gegen 2,7 kg/h"
    assert e.plausible

    # Der zweite, unabhängige Punkt: dieselbe Kette bei kleinster Flamme.
    m = stove_economics_min_load(CFG)
    assert m.kg_per_hour == pytest.approx(0.68, abs=0.01)
    assert abs(m.datasheet_deviation) < 0.04, "0,68 gegen 0,7 kg/h"
    assert m.plausible

    # Die ursprüngliche Schätzung von 5,4 kWh/kg widerspricht dem Datenblatt an beiden Punkten.
    zu_hoch = CFG.model_copy(update={"pellet_kwh_per_kg": 5.4})
    assert not stove_economics(zu_hoch).plausible
    assert not stove_economics_min_load(zu_hoch).plausible


def test_teillast_kostet_dasselbe() -> None:
    """Der überraschende Befund, und der Grund, warum keine Teillastkennlinie gebraucht wird.

    Auf kleiner Flamme ist der Wirkungsgrad besser (96,1 statt 91,1 %), aber es geht weniger ins
    Wasser (56 statt 84 %). Auf die gesamte Nutzwärme gerechnet hebt sich das fast genau auf. Die
    Modulation ist damit eine Zeitfrage, keine Kostenfrage.
    """
    voll = stove_economics(CFG, aux_price_ct_kwh=30.0)
    teil = stove_economics_min_load(CFG, aux_price_ct_kwh=30.0)
    assert abs(voll.ct_per_kwh_useful - teil.ct_per_kwh_useful) < 0.15
    # Auf die Pufferwärme allein sieht es anders aus: dort ist Teillast deutlich teurer.
    assert teil.ct_per_kwh_water > voll.ct_per_kwh_water * 1.3


def test_der_pelletbehaelter_begrenzt_die_laufzeit() -> None:
    """15 kg gewogen: 5,6 Stunden Volllast, 22 Stunden kleinste Flamme."""
    assert hopper_runtime_h(CFG) == pytest.approx(5.6, abs=0.2)
    assert hopper_runtime_h(CFG, min_load=True) == pytest.approx(22.1, abs=0.5)


def test_bei_knappem_brennstoff_ist_volllast_deutlich_besser() -> None:
    """Die Kehrseite von „Teillast kostet dasselbe", und die wichtigere Aussage.

    Je Kilowattstunde Nutzwärme sind beide Lastpunkte gleich teuer. Je **Kilogramm Pellets in den
    Puffer** ist Volllast um gut 40 % besser, weil dort ein viel größerer Anteil ins Wasser geht.
    Sobald der Brennstoff das knappe Gut ist, und das ist er bei einer Füllung am Tag, zählt die
    zweite Kennzahl.
    """
    voll = buffer_kwh_per_kg(CFG)
    teil = buffer_kwh_per_kg(CFG, min_load=True)
    assert voll == pytest.approx(3.75, abs=0.02)
    assert teil == pytest.approx(2.65, abs=0.02)
    assert voll / teil > 1.4


def test_das_tagesbudget_ist_die_haerteste_schranke() -> None:
    """Einmal am Tag nachfüllen heißt: höchstens 56 kWh in den Puffer, und das nur bei Volllast."""
    b = daily_budget(CFG)
    assert b.pellet_kg == 15.0
    assert b.fuel_kwh == pytest.approx(73.5, abs=0.5)
    assert b.buffer_kwh == pytest.approx(56.3, abs=0.5)
    assert b.runtime_full_h < 6, "eine kalte Nacht von 17 bis 6 Uhr geht bei Volllast nicht durch"
    assert b.runtime_min_h > 20, "mit Modulation dagegen schon"
    assert "15 kg je Tag" in b.note_de


def test_zwei_fuellungen_verdoppeln_das_budget() -> None:
    b = daily_budget(CFG.model_copy(update={"refills_per_day": 2.0}))
    assert b.pellet_kg == 30.0
    assert b.buffer_kwh == pytest.approx(2 * daily_budget(CFG).buffer_kwh, abs=0.5)


def test_der_eigenverbrauch_zaehlt_mit() -> None:
    """75 W zum Marktpreis: klein, aber Strom, und er verschiebt in dieselbe Richtung wie ein hoher
    Strompreis."""
    ohne = stove_economics(CFG)
    mit = stove_economics(CFG, aux_price_ct_kwh=30.0)
    assert ohne.electricity_eur_per_hour == 0.0
    assert mit.electricity_eur_per_hour == pytest.approx(0.0225, abs=0.0002)
    assert mit.ct_per_kwh_useful > ohne.ct_per_kwh_useful
    assert mit.ct_per_kwh_useful - ohne.ct_per_kwh_useful < 0.3, "Zehntel, keine Cents"


def test_die_raumwaerme_verschiebt_den_waermepreis_nur_wenig() -> None:
    """12,1 gegen 10,2 ct/kWh. Bei diesem Gerät geht fast alles ins Wasser, anders als zunächst
    angenommen: 10 der 11,9 kW, nicht 9 von 12."""
    e = stove_economics(CFG)
    assert e.ct_per_kwh_water == pytest.approx(12.00, abs=0.05)  # 1,200 / 10
    assert e.ct_per_kwh_useful == pytest.approx(10.08, abs=0.05)  # 1,200 / 11,9


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
    """Minus sieben Grad, COP 2,4, 45 ct/kWh: 18,75 ct Wärmepumpe gegen gut 10 ct Ofen."""
    c = cheaper_source(CFG, price_ct_kwh=45.0, cop=2.4)
    assert c.cheaper == "stove"
    assert c.heat_pump_ct == pytest.approx(18.75, abs=0.05)
    assert c.saving_ct_per_kwh > 7
    assert "Ofen günstiger" in c.note_de


def test_bei_mildem_wetter_und_billigem_strom_gewinnt_die_waermepumpe() -> None:
    """Sieben Grad, COP 3,5, 20 ct/kWh: 5,71 ct gegen gut 10 ct."""
    c = cheaper_source(CFG, price_ct_kwh=20.0, cop=3.5)
    assert c.cheaper == "heat_pump"
    assert c.heat_pump_ct == pytest.approx(5.71, abs=0.05)
    assert "Wärmepumpe günstiger" in c.note_de


def test_die_lesart_kann_die_entscheidung_kippen() -> None:
    """Bei 30 ct und COP 2,6 liegt die Wärmepumpe (11,5 ct) zwischen den Ofenpreisen 10,3 und 12,2.

    Das Fenster ist bei diesem Gerät schmal, weil fast die gesamte Wärme ins Wasser geht. Es
    existiert aber, und deshalb gibt die Rechnung weiter beide Zahlen aus.
    """
    mit = cheaper_source(CFG, price_ct_kwh=30.0, cop=2.6, credit_room_heat=True)
    ohne = cheaper_source(CFG, price_ct_kwh=30.0, cop=2.6, credit_room_heat=False)
    assert mit.cheaper == "stove"
    assert ohne.cheaper == "heat_pump"
    assert "mit angerechneter Raumwärme" in mit.note_de
    assert "nur auf die Pufferwärme" in ohne.note_de


def test_break_even_cop_ist_die_zahl_fuer_die_kennlinie() -> None:
    """Ab welcher Arbeitszahl schlägt die Wärmepumpe den Ofen? Bei 30 ct: 30 / 10,27 = 2,92."""
    assert break_even_cop(CFG, 30.0) == pytest.approx(2.92, abs=0.05)
    assert break_even_cop(CFG, 45.0) == pytest.approx(4.35, abs=0.05)
    # Ohne Anrechnung der Raumwärme ist der Ofen teurer, die Schwelle sinkt entsprechend.
    assert break_even_cop(CFG, 30.0, credit_room_heat=False) == pytest.approx(2.45, abs=0.05)


def test_die_naechtliche_frage_des_hausherrn() -> None:
    """Kalte Winternacht, Ofen an statt Wärmepumpe: die bisherige Handregel wird nachgerechnet.

    Minus fünf Grad heißt nach der Kennlinie etwa COP 2,5. Bei 32 ct Nachtstrom kostet die
    Wärmepumpe 12,8 ct/kWh, der Ofen 10,4. Die Handregel war also richtig, und zwar aus Gründen,
    nicht aus Gefühl.
    """
    c = cheaper_source(CFG, price_ct_kwh=32.0, cop=2.5)
    assert c.cheaper == "stove"
    assert c.heat_pump_ct == pytest.approx(12.8, abs=0.05)


def test_das_budgetfenster_laeuft_von_fuellung_zu_fuellung() -> None:
    """Nicht von Mitternacht zu Mitternacht: nachgefüllt wird morgens um sieben.

    Wer das verwechselt, plant um 23 Uhr mit einem vollen Behälter, obwohl der seit dem Morgen
    fast leer ist.
    """
    from datetime import datetime

    from hems_core.accounting import budget_window

    start, end = budget_window(CFG, datetime(2026, 9, 8, 23, 0))
    assert (start.day, start.hour) == (8, 7)
    assert (end.day, end.hour) == (9, 7)

    # Frühmorgens vor dem Nachfüllen gilt noch die Füllung des Vortages.
    start, _ = budget_window(CFG, datetime(2026, 9, 8, 5, 0))
    assert (start.day, start.hour) == (7, 7)


def test_verbrauch_aus_den_leistungsstufen() -> None:
    """Der Ofen meldet keinen Verbrauch, aber seine Stufe. Daraus wird der Rest im Behälter."""
    from hems_core.accounting import estimated_kg_burned, fuel_rate_kg_per_h, remaining_kg

    assert fuel_rate_kg_per_h(CFG, 1) == pytest.approx(0.68, abs=0.01)
    assert fuel_rate_kg_per_h(CFG, 5) == pytest.approx(2.666, abs=0.01)
    assert fuel_rate_kg_per_h(CFG, 3) == pytest.approx(1.673, abs=0.01), "linear dazwischen"

    burned = estimated_kg_burned(CFG, {"5": 120, "3": 60})
    assert burned == pytest.approx(7.0, abs=0.05)  # 2 h × 2,666 + 1 h × 1,673
    assert remaining_kg(CFG, burned) == pytest.approx(8.0, abs=0.05)


def test_der_rest_wird_nie_negativ() -> None:
    """Eine zu grobe Schätzung darf keinen negativen Vorrat ergeben."""
    from hems_core.accounting import remaining_kg

    assert remaining_kg(CFG, 99.0) == 0.0
