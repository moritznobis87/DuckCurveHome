"""Der Eigenverbrauch des Speichergeräts: abziehen, zuordnen, bepreisen.

Was der Stromwandler des Speichers misst, ist nicht das, was in den Zellen ankommt. Ein Teil
versorgt den Wechselrichter selbst. Diese Prüfungen halten fest, dass die Bilanz beides trennt und
dass die Summen dabei stehen bleiben: Was abgezogen wird, verschwindet nicht, es wechselt die Zeile.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from hems_core.accounting import (
    MinuteSample,
    hourly_energy,
    samples_from_totals,
)
from hems_core.domain import TariffConfig

H0 = datetime(2026, 10, 15, 12, 0, tzinfo=UTC)
TARIFF = TariffConfig(feed_in_ct_kwh=8.0, fallback_import_ct_kwh=30.0)
IDLE = 0.12


def _minutes(n: int, **kw: float | None) -> list[MinuteSample]:
    base = {
        "pv_kw": 0.0,
        "grid_kw": 0.0,
        "battery_kw": 0.0,
        "heat_pump_kw": 0.0,
        "ev_kw": 0.0,
        "price_ct_kwh": 30.0,
    }
    base.update(kw)
    return [MinuteSample(ts=H0 + timedelta(minutes=i), **base) for i in range(n)]  # type: ignore[arg-type]


def test_ohne_einstellung_aendert_sich_nichts() -> None:
    """Der Abzug ist eine Annahme über ein Gerät. Wer sie nicht setzt, bekommt die alte Rechnung."""
    smp = _minutes(60, pv_kw=0.0, grid_kw=1.5, battery_kw=-1.5)
    h = hourly_energy(H0, smp, TARIFF)
    assert h.battery_device_kwh == 0.0
    assert h.battery_charge_kwh == pytest.approx(1.5, abs=1e-3)


def test_nachts_wird_der_eigenverbrauch_vom_netz_bezahlt() -> None:
    # Eine Stunde Netzladung mit 1,5 kW am Wandler. 0,12 kW davon bleiben im Gerät.
    smp = _minutes(60, pv_kw=0.0, grid_kw=1.5, battery_kw=-1.5)
    h = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)

    assert h.battery_device_kwh == pytest.approx(0.12, abs=1e-3)
    assert h.battery_charge_kwh == pytest.approx(1.38, abs=1e-3)
    # Ohne Sonne ist alles davon Netzstrom und wird zum Bezugspreis der Stunde bezahlt.
    assert h.battery_device_grid_kwh == pytest.approx(0.12, abs=1e-3)
    assert h.battery_device_pv_kwh == 0.0
    assert h.battery_device_cost_eur == pytest.approx(0.12 * 0.30, abs=1e-4)
    assert h.battery_device_opportunity_eur == 0.0
    # Und es ist keine Netzladung mehr, auch nicht die dunkle.
    assert h.grid_to_battery_kwh == pytest.approx(1.38, abs=1e-3)
    assert h.grid_to_battery_dark_kwh == pytest.approx(1.38, abs=1e-3)


def test_bei_sonne_kostet_er_die_verguetung() -> None:
    # PV 3 kW, Haus 1 kW, Speicher laedt mit 2 kW: die Ladung ist vollstaendig aus der Sonne.
    smp = _minutes(60, pv_kw=3.0, grid_kw=0.0, battery_kw=-2.0)
    h = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)

    assert h.battery_device_pv_kwh == pytest.approx(0.12, abs=1e-3)
    assert h.battery_device_grid_kwh == pytest.approx(0.0, abs=1e-6)
    # Entgangen ist die Einspeiseverguetung, nicht der Bezugspreis.
    assert h.battery_device_opportunity_eur == pytest.approx(0.12 * 0.08, abs=1e-4)
    assert h.battery_device_cost_eur == pytest.approx(0.0, abs=1e-6)
    # Nicht in der Eigenverbrauchsquote: ob der Betriebsstrom des Wechselrichters eine
    # unentgeltliche Wertabgabe ist, entscheidet keine Messung. Er steht daneben.
    assert h.self_consumption_kwh == pytest.approx(
        h.pv_direct_kwh + h.battery_pv_to_house_kwh, abs=1e-3
    )


def test_die_erzeugung_wird_nicht_doppelt_vergeben() -> None:
    """PV geht auf in: Zellen, Gerät, direkt ins Haus, Einspeisung."""
    smp = _minutes(60, pv_kw=5.0, grid_kw=-2.0, battery_kw=-2.0)
    h = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)
    summe = h.pv_to_battery_kwh + h.battery_device_pv_kwh + h.pv_direct_kwh + h.export_kwh
    assert summe == pytest.approx(h.pv_kwh, abs=1e-3)


def test_der_netzbezug_wird_nicht_doppelt_vergeben() -> None:
    smp = _minutes(60, pv_kw=0.5, grid_kw=3.0, battery_kw=-1.5)
    h = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)
    summe = h.grid_to_battery_kwh + h.battery_device_grid_kwh + h.grid_to_house_kwh
    assert summe == pytest.approx(h.import_kwh, abs=1e-3)


def test_eine_winzige_ladung_ist_ganz_eigenverbrauch() -> None:
    """Ein Rinnsal von 0,03 kW ist kein Laden, sondern das wache Geraet - und wird nicht negativ."""
    smp = _minutes(60, pv_kw=0.0, grid_kw=0.4, battery_kw=-0.03)
    h = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)
    assert h.battery_device_kwh == pytest.approx(0.03, abs=1e-3)
    assert h.battery_charge_kwh == pytest.approx(0.0, abs=1e-6)


def test_beim_entladen_wird_nichts_abgezogen() -> None:
    """Das Geraet zieht dann aus den Zellen; das Haus bekommt, was der Wandler misst."""
    smp = _minutes(60, pv_kw=0.0, grid_kw=0.5, battery_kw=1.5)
    h = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)
    assert h.battery_device_kwh == 0.0
    assert h.battery_discharge_kwh == pytest.approx(1.5, abs=1e-3)


def test_bei_grober_aufloesung_wird_nicht_abgezogen() -> None:
    """Ein Stundenmittel sagt nicht, wie lange das Geraet wach war; ein Abzug waere geraten."""
    smp = _minutes(60, pv_kw=0.0, grid_kw=1.5, battery_kw=-1.5)
    h = hourly_energy(H0, smp, TARIFF, resolution_min=60, inverter_idle_kw=IDLE)
    assert h.battery_device_kwh == 0.0
    assert h.battery_charge_kwh == pytest.approx(1.5, abs=1e-3)


def test_das_haus_bleibt_unberuehrt() -> None:
    """Der Eigenverbrauch des Speichers ist kein Verbraucher des Hauses und faelscht es nicht."""
    smp = _minutes(60, pv_kw=0.0, grid_kw=2.5, battery_kw=-1.5, heat_pump_kw=1.0)
    ohne = hourly_energy(H0, smp, TARIFF)
    mit = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)
    assert mit.house_kwh == pytest.approx(ohne.house_kwh, abs=1e-6)
    assert mit.base_kwh == pytest.approx(ohne.base_kwh, abs=1e-6)
    assert mit.import_kwh == pytest.approx(ohne.import_kwh, abs=1e-6)
    assert mit.autarky == ohne.autarky


def test_was_abgezogen_wird_verschwindet_nicht() -> None:
    """Die am Wandler gemessene Ladung ist die Summe aus Zellen und Geraet."""
    smp = _minutes(60, pv_kw=0.0, grid_kw=1.5, battery_kw=-1.5)
    ohne = hourly_energy(H0, smp, TARIFF)
    mit = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)
    assert mit.battery_charge_kwh + mit.battery_device_kwh == pytest.approx(
        ohne.battery_charge_kwh, abs=1e-3
    )


def test_die_reparatur_grober_stunden_rechnet_den_abzug_zurueck() -> None:
    """Sonst schrumpfte die Ladung bei jedem Reparaturlauf um denselben Betrag erneut."""
    smp = _minutes(60, pv_kw=0.0, grid_kw=1.5, battery_kw=-1.5)
    h = hourly_energy(H0, smp, TARIFF, inverter_idle_kw=IDLE)
    # Zurueck in Minuten und wieder zu einer Stunde: dieselbe gemessene Leistung wie am Anfang.
    zurueck = samples_from_totals(h)
    assert zurueck[0].battery_kw == pytest.approx(-1.5, abs=1e-3)
    nochmal = hourly_energy(H0, zurueck, TARIFF, inverter_idle_kw=IDLE)
    assert nochmal.battery_charge_kwh == pytest.approx(h.battery_charge_kwh, abs=1e-3)
    assert nochmal.battery_device_kwh == pytest.approx(h.battery_device_kwh, abs=1e-3)


# ------------------------------------------------------------------ Ersparnis netto


def test_ohne_verlust_ist_netto_gleich_der_alten_spanne() -> None:
    """Der Rueckfall auf den Normalfall: PV hinein, alles wieder heraus, nichts verloren."""
    laden = _minutes(60, pv_kw=3.0, grid_kw=0.0, battery_kw=-2.0)
    h1 = hourly_energy(H0, laden, TARIFF)
    # Dieselbe Menge in derselben Preislage wieder heraus.
    entladen = [
        MinuteSample(
            ts=H0 + timedelta(hours=1, minutes=i),
            pv_kw=0.0,
            grid_kw=0.0,
            battery_kw=2.0,
            heat_pump_kw=0.0,
            ev_kw=0.0,
            price_ct_kwh=30.0,
        )
        for i in range(60)
    ]
    h2 = hourly_energy(H0 + timedelta(hours=1), entladen, TARIFF, origin=None)
    netto = h1.battery_net_eur + h2.battery_net_eur
    # 2 kWh hinein zur Verguetung (8 ct), 2 kWh heraus zum Bezugspreis (30 ct): 0,44 EUR.
    assert netto == pytest.approx(2.0 * (0.30 - 0.08), abs=0.01)
    # Und das ist genau die alte Bruttozahl, solange nichts verlorengeht.
    assert netto == pytest.approx(h2.battery_savings_eur, abs=0.01)


def test_der_verlust_schlaegt_auf_die_nettozahl_durch() -> None:
    """Mehr hinein als heraus: brutto bleibt gleich, netto sinkt. Genau das war der Fehler."""
    laden = _minutes(60, pv_kw=4.0, grid_kw=0.0, battery_kw=-3.0)
    h1 = hourly_energy(H0, laden, TARIFF)
    entladen = [
        MinuteSample(
            ts=H0 + timedelta(hours=1, minutes=i),
            pv_kw=0.0,
            grid_kw=0.0,
            battery_kw=2.0,
            heat_pump_kw=0.0,
            ev_kw=0.0,
            price_ct_kwh=30.0,
        )
        for i in range(60)
    ]
    h2 = hourly_energy(H0 + timedelta(hours=1), entladen, TARIFF)
    # Brutto sieht den Verlust nicht: 2 kWh heraus mal 22 ct Spanne.
    assert h2.battery_savings_eur == pytest.approx(2.0 * 0.22, abs=0.01)
    # Netto schon: 3 kWh zur Verguetung hinein, 2 kWh zum Bezugspreis heraus.
    netto = h1.battery_net_eur + h2.battery_net_eur
    assert netto == pytest.approx(2.0 * 0.30 - 3.0 * 0.08, abs=0.01)
    assert netto < h2.battery_savings_eur


def test_netzladung_kostet_den_bezugspreis_nicht_die_verguetung() -> None:
    laden = _minutes(60, pv_kw=0.0, grid_kw=2.0, battery_kw=-2.0, price_ct_kwh=10.0)
    h = hourly_energy(H0, laden, TARIFF)
    # 2 kWh aus dem Netz zu 10 ct, abzueglich des Eigenverbrauchs, der nicht dazugehoert.
    assert h.battery_charge_cost_eur == pytest.approx(2.0 * 0.10, abs=0.01)
    assert h.battery_discharge_value_eur == 0.0
    assert h.battery_net_eur == pytest.approx(-0.20, abs=0.01)


def test_arbitrage_steckt_in_der_nettozahl() -> None:
    """Billig geladen, teuer entladen: das soll die Zahl belohnen."""
    billig = _minutes(60, pv_kw=0.0, grid_kw=2.0, battery_kw=-2.0, price_ct_kwh=5.0)
    teuer = [
        MinuteSample(
            ts=H0 + timedelta(hours=1, minutes=i),
            pv_kw=0.0,
            grid_kw=0.0,
            battery_kw=2.0,
            heat_pump_kw=0.0,
            ev_kw=0.0,
            price_ct_kwh=45.0,
        )
        for i in range(60)
    ]
    netto = (
        hourly_energy(H0, billig, TARIFF).battery_net_eur
        + hourly_energy(H0 + timedelta(hours=1), teuer, TARIFF).battery_net_eur
    )
    assert netto == pytest.approx(2.0 * 0.45 - 2.0 * 0.05, abs=0.01)


def test_der_eigenverbrauch_zaehlt_nicht_zu_den_ladekosten() -> None:
    """Er hat die Zellen nie erreicht und steht als eigener Verbraucher da - sonst doppelt."""
    laden = _minutes(60, pv_kw=0.0, grid_kw=2.0, battery_kw=-2.0)
    h = hourly_energy(H0, laden, TARIFF, inverter_idle_kw=IDLE)
    assert h.battery_charge_cost_eur == pytest.approx(1.88 * 0.30, abs=0.01)
    assert h.battery_device_cost_eur == pytest.approx(0.12 * 0.30, abs=0.01)
    # Zusammen wieder der ganze Bezug dieser Stunde.
    assert h.battery_charge_cost_eur + h.battery_device_cost_eur == pytest.approx(
        2.0 * 0.30, abs=0.01
    )
