from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from hems_core.accounting import (
    BatteryOrigin,
    MinuteSample,
    cop_at,
    fill_gaps,
    heat_demand_kw,
    heat_forecast,
    hourly_energy,
    pv_tax,
    samples_from_rows,
    summarize,
)
from hems_core.domain import HeatDemandConfig, TariffConfig

H0 = datetime(2026, 9, 6, 12, 0, tzinfo=UTC)
TARIFF = TariffConfig(feed_in_ct_kwh=8.0, fallback_import_ct_kwh=30.0)


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


def test_sunny_hour_pv_direct_battery_charge_and_export() -> None:
    # PV 6 kW, Haus 2 kW (davon WP 1 kW), Batterie lädt 2 kW, Export 2 kW
    hour = hourly_energy(
        H0, _minutes(60, pv_kw=6.0, grid_kw=-2.0, battery_kw=-2.0, heat_pump_kw=1.0), TARIFF
    )
    assert hour.minutes == 60
    assert hour.pv_kwh == pytest.approx(6.0)
    assert hour.house_kwh == pytest.approx(2.0)
    assert hour.pv_direct_kwh == pytest.approx(2.0)
    assert hour.pv_to_battery_kwh == pytest.approx(2.0)
    assert hour.export_kwh == pytest.approx(2.0)
    assert hour.grid_to_house_kwh == pytest.approx(0.0)
    assert hour.heat_pump_kwh == pytest.approx(1.0)
    assert hour.heat_pump_pv_kwh == pytest.approx(1.0)
    assert hour.heat_pump_cost_eur == pytest.approx(0.0)
    assert hour.heat_pump_opportunity_eur == pytest.approx(0.08)  # 1 kWh × 8 ct
    assert hour.export_revenue_eur == pytest.approx(0.16)
    assert hour.pv_direct_savings_eur == pytest.approx(2.0 * 0.22)
    assert hour.self_consumption_share == pytest.approx(4.0 / 6.0, abs=1e-3)
    assert hour.autarky == pytest.approx(1.0)


def test_night_hour_battery_then_grid_with_ev() -> None:
    # Nacht: Haus 4 kW (Wallbox 3 kW), Batterie entlädt 1 kW, Netz 3 kW à 40 ct
    hour = hourly_energy(
        H0,
        _minutes(60, pv_kw=0.0, grid_kw=3.0, battery_kw=1.0, ev_kw=3.0, price_ct_kwh=40.0),
        TARIFF,
    )
    assert hour.house_kwh == pytest.approx(4.0)
    assert hour.battery_to_house_kwh == pytest.approx(1.0)
    assert hour.grid_to_house_kwh == pytest.approx(3.0)
    assert hour.ev_kwh == pytest.approx(3.0)
    assert hour.ev_battery_kwh == pytest.approx(0.75)
    assert hour.ev_grid_kwh == pytest.approx(2.25)
    assert hour.ev_cost_eur == pytest.approx(2.25 * 0.40)
    assert hour.import_cost_eur == pytest.approx(1.20)
    assert hour.battery_savings_eur == pytest.approx(1.0 * 0.32)
    assert hour.avg_import_price_ct == pytest.approx(40.0)
    assert hour.autarky == pytest.approx(0.25)


def test_missing_inputs_and_fallback_price() -> None:
    rows = _minutes(30, pv_kw=1.0, grid_kw=0.5, price_ct_kwh=None) + _minutes(
        30, pv_kw=None, grid_kw=0.5
    )
    hour = hourly_energy(H0, rows, TARIFF)
    assert hour.minutes == 30 and hour.price_missing_minutes == 30
    assert hour.import_cost_eur == pytest.approx(0.25 * 0.30)  # Ersatzpreis 30 ct


def test_summarize_and_samples_from_rows() -> None:
    rows = [
        {
            "ts": "2026-09-06T12:00:00Z",
            "pv_power_kw": 2.0,
            "grid_power_kw": -1.0,
            "battery_power_kw": 0.0,
            "heat_pump_power_kw": 0.5,
            "ev_power_kw": None,
            "electricity_price_ct_kwh": 25.0,
        },
        {"ts": "2026-09-06T12:01:00Z", "pv_power_kw": 2.0, "grid_power_kw": -1.0},
    ]
    smp = samples_from_rows(rows)
    assert len(smp) == 2 and smp[1].battery_kw is None and smp[0].heat_pump_kw == 0.5
    h = hourly_energy(H0, smp, TARIFF)
    total = summarize([h, h])
    assert total.minutes == 4 and total.pv_kwh == pytest.approx(2 * h.pv_kwh)
    assert total.price_missing_minutes == 2


def test_heat_model() -> None:
    cfg = HeatDemandConfig()
    assert cop_at(-10, cfg) == 2.4 and cop_at(20, cfg) == 4.2
    assert cop_at(4.5, cfg) == pytest.approx(3.25, abs=1e-3)
    heating, dhw = heat_demand_kw(0.0, 7, cfg)
    assert heating == pytest.approx(0.22 * 21 - 0.4)
    assert dhw > heat_demand_kw(0.0, 3, cfg)[1]  # morgens mehr Warmwasser als nachts
    assert heat_demand_kw(18.0, 12, cfg)[0] == 0.0  # über Heizgrenze
    pts = heat_forecast([(H0, 5.0), (H0 + timedelta(hours=1), 16.0)], cfg)
    assert pts[0].electric_kw > 0 and pts[1].heating_kw == 0.0


# ------------------------------------------------------------------ Eigenverbrauch und Steuer

TAX_TARIFF = TariffConfig(feed_in_ct_kwh=7.41, fallback_import_ct_kwh=30.0)


def test_self_consumption_is_valued_net_not_gross() -> None:
    # PV 3 kW, Haus 3 kW, kein Netz, kein Speicher: 3 kWh Eigenverbrauch zu 35,7 ct brutto.
    hour = hourly_energy(H0, _minutes(60, pv_kw=3.0, grid_kw=0.0, price_ct_kwh=35.7), TAX_TARIFF)
    assert hour.self_consumption_kwh == pytest.approx(3.0)
    # 35,7 ct brutto sind 30 ct netto; 3 kWh × 30 ct = 0,90 €
    assert hour.self_consumption_value_eur == pytest.approx(0.90, abs=1e-3)
    assert hour.self_consumption_ct_kwh == pytest.approx(30.0, abs=0.02)


def test_battery_origin_separates_grid_charge_from_pv_charge() -> None:
    """Nachts aus dem Netz geladen, tags entladen: der Netzanteil ist kein Eigenverbrauch."""
    origin = BatteryOrigin()
    # Stunde 1: Netzbezug 4 kW, davon 4 kW in den Speicher (kein PV, kein Hausverbrauch).
    h1 = hourly_energy(
        H0, _minutes(60, pv_kw=0.0, grid_kw=4.0, battery_kw=-4.0), TAX_TARIFF, origin, 10.0
    )
    assert h1.grid_to_battery_kwh == pytest.approx(4.0)
    assert h1.battery_pv_to_house_kwh == pytest.approx(0.0)
    assert origin.grid_kwh == pytest.approx(4.0)
    # Stunde 2: PV 2 kW lädt weiter, Haus 0.
    h2 = hourly_energy(
        H0 + timedelta(hours=1),
        _minutes(60, pv_kw=2.0, grid_kw=0.0, battery_kw=-2.0),
        TAX_TARIFF,
        origin,
        10.0,
    )
    assert h2.pv_to_battery_kwh == pytest.approx(2.0)
    assert origin.pv_kwh == pytest.approx(2.0)
    # Stunde 3: Speicher entlädt 3 kW ins Haus. Konto steht 2 PV zu 4 Netz → ein Drittel ist PV.
    h3 = hourly_energy(
        H0 + timedelta(hours=2),
        _minutes(60, pv_kw=0.0, grid_kw=0.0, battery_kw=3.0),
        TAX_TARIFF,
        origin,
        10.0,
    )
    assert h3.battery_to_house_kwh == pytest.approx(3.0)
    assert h3.battery_pv_to_house_kwh == pytest.approx(1.0)
    assert h3.battery_origin_estimated_kwh == pytest.approx(0.0)
    assert h3.battery_pv_stored_kwh == pytest.approx(1.0)
    assert h3.battery_grid_stored_kwh == pytest.approx(2.0)


def test_unknown_battery_content_counts_as_pv_but_is_flagged() -> None:
    hour = hourly_energy(H0, _minutes(60, pv_kw=0.0, grid_kw=0.0, battery_kw=2.0), TAX_TARIFF)
    assert hour.battery_pv_to_house_kwh == pytest.approx(2.0)
    assert hour.battery_origin_estimated_kwh == pytest.approx(2.0)


def test_battery_ledger_is_capped_at_capacity() -> None:
    """Ladeverluste lassen das Konto sonst über die Kapazität hinaus wachsen."""
    origin = BatteryOrigin()
    for i in range(4):
        hourly_energy(
            H0 + timedelta(hours=i),
            _minutes(60, pv_kw=3.0, grid_kw=0.0, battery_kw=-3.0),
            TAX_TARIFF,
            origin,
            10.0,
        )
    assert origin.content_kwh == pytest.approx(10.0)


def test_pv_tax_splits_vat_on_feed_in_and_self_consumption() -> None:
    hour = hourly_energy(H0, _minutes(60, pv_kw=5.0, grid_kw=-3.0, price_ct_kwh=35.7), TAX_TARIFF)
    rep = pv_tax(hour, TAX_TARIFF)
    assert rep.export_kwh == pytest.approx(3.0)
    # Geldbeträge werden auf den Cent gerundet, die Prüfung darum auf den halben Cent genau.
    assert rep.export_net_eur == pytest.approx(3.0 * 0.0741, abs=5e-3)
    assert rep.export_vat_eur == pytest.approx(3.0 * 0.0741 * 0.19, abs=5e-3)
    assert rep.export_gross_eur == pytest.approx(rep.export_net_eur + rep.export_vat_eur, abs=5e-3)
    assert rep.self_consumption_kwh == pytest.approx(2.0)
    assert rep.self_value_net_eur == pytest.approx(0.60, abs=1e-2)  # 2 kWh × 30 ct netto
    assert rep.self_vat_eur == pytest.approx(0.60 * 0.19, abs=1e-2)
    assert rep.vat_payable_eur == pytest.approx(rep.export_vat_eur + rep.self_vat_eur, abs=1e-2)
    assert rep.self_consumption_share == pytest.approx(0.4)


def test_small_business_owes_no_vat() -> None:
    tariff = TariffConfig(feed_in_ct_kwh=7.41, small_business=True)
    hour = hourly_energy(H0, _minutes(60, pv_kw=5.0, grid_kw=-3.0, price_ct_kwh=35.7), tariff)
    rep = pv_tax(hour, tariff)
    assert rep.export_vat_eur == 0.0
    assert rep.self_vat_eur == 0.0
    assert rep.vat_payable_eur == 0.0
    # Ohne Umsatzsteuer ist der Bruttopreis auch der Beschaffungspreis.
    assert rep.self_ct_kwh == pytest.approx(35.7, abs=0.02)


def test_summarize_adds_self_consumption_but_not_the_ledger() -> None:
    a = hourly_energy(H0, _minutes(60, pv_kw=3.0, grid_kw=0.0, price_ct_kwh=35.7), TAX_TARIFF)
    b = hourly_energy(
        H0 + timedelta(hours=1), _minutes(60, pv_kw=3.0, grid_kw=0.0, price_ct_kwh=35.7), TAX_TARIFF
    )
    total = summarize([a, b])
    assert total.self_consumption_kwh == pytest.approx(6.0)
    assert total.self_consumption_value_eur == pytest.approx(1.80, abs=1e-2)
    assert not hasattr(total, "battery_pv_stored_kwh")


def test_grid_charging_is_split_by_daylight() -> None:
    """Nachts aus dem Netz zu laden ist eine Entscheidung, tagsüber meist ein Messartefakt."""
    # Nacht: kein PV, Netzbezug 4 kW, Speicher lädt 4 kW
    night = hourly_energy(H0, _minutes(60, pv_kw=0.0, grid_kw=4.0, battery_kw=-4.0), TARIFF)
    assert night.grid_to_battery_kwh == pytest.approx(4.0)
    assert night.grid_to_battery_dark_kwh == pytest.approx(4.0)

    # Tag: PV 1 kW, Haus 0, Speicher lädt 4 kW, davon 3 aus dem Netz - aber die Sonne scheint
    day = hourly_energy(H0, _minutes(60, pv_kw=1.0, grid_kw=3.0, battery_kw=-4.0), TARIFF)
    assert day.grid_to_battery_kwh == pytest.approx(3.0)
    assert day.grid_to_battery_dark_kwh == pytest.approx(0.0)


# ------------------------------------------------------------------ Lücken im Minutenraster
# Der Fall, an dem die Bilanz still gescheitert ist: der Speicher trägt nachts das Haus mit
# gleichmäßiger Leistung, aber die Quelle meldet nur jede dritte Minute. Gezählt wurde vorher nur,
# was einen Messwert hatte - die Entladung schrumpfte auf ein Drittel, ohne dass irgendwo eine
# Warnung erschien. Am 08.09. waren das 0,6 statt 1,7 kWh, und daraus ein Wirkungsgrad von 11 %.


def _sparse(n: int, every: int, **kw: float | None) -> list[MinuteSample]:
    return [s for i, s in enumerate(_minutes(n, **kw)) if i % every == 0]


def test_lueckige_minuten_verlieren_keine_energie_mehr() -> None:
    voll = hourly_energy(H0, _minutes(60, battery_kw=0.36, grid_kw=-0.36), TARIFF)
    lueckig = hourly_energy(H0, fill_gaps(_sparse(60, 3, battery_kw=0.36, grid_kw=-0.36)), TARIFF)
    assert voll.battery_discharge_kwh == pytest.approx(0.36)
    assert lueckig.battery_discharge_kwh == pytest.approx(voll.battery_discharge_kwh, abs=0.02)
    assert lueckig.minutes >= 58


def test_ohne_fuellung_fehlten_zwei_drittel() -> None:
    """Der Beleg für den Befund: ungefüllt zählt die Stunde nur ihre 20 gemeldeten Minuten."""
    roh = hourly_energy(H0, _sparse(60, 3, battery_kw=0.36, grid_kw=-0.36), TARIFF)
    assert roh.minutes == 20
    assert roh.battery_discharge_kwh == pytest.approx(0.12, abs=0.005)


def test_ein_echter_ausfall_wird_nicht_zugeschuettet() -> None:
    """Fünf Minuten Lücke sind ein Takt, eine halbe Stunde ist ein Ausfall - und bleibt einer."""
    erste = _minutes(5, battery_kw=1.0)
    spaete = [
        MinuteSample(
            ts=H0 + timedelta(minutes=40 + i),
            pv_kw=0.0,
            grid_kw=0.0,
            battery_kw=1.0,
            heat_pump_kw=0.0,
            ev_kw=0.0,
            price_ct_kwh=30.0,
        )
        for i in range(5)
    ]
    h = hourly_energy(H0, fill_gaps(erste + spaete), TARIFF)
    assert h.minutes == 15, "5 gemessene + 5 gehaltene + 5 gemessene Minuten"
    assert h.battery_discharge_kwh == pytest.approx(15 / 60, abs=1e-3)


def test_ueber_den_letzten_messwert_hinaus_wird_nichts_erfunden() -> None:
    """Die laufende Stunde darf nicht vorgreifen: sonst stünde Energie da, die es noch nicht gibt."""
    h = hourly_energy(H0, fill_gaps(_minutes(10, battery_kw=1.0)), TARIFF)
    assert h.minutes == 10
    assert h.battery_discharge_kwh == pytest.approx(10 / 60, abs=1e-3)


def test_jedes_feld_haelt_fuer_sich() -> None:
    """Fehlt nur die Batterie, gelten PV und Netz weiter - und umgekehrt."""
    a = MinuteSample(
        ts=H0,
        pv_kw=3.0,
        grid_kw=-1.0,
        battery_kw=-2.0,
        heat_pump_kw=0.0,
        ev_kw=0.0,
        price_ct_kwh=30.0,
    )
    b = MinuteSample(
        ts=H0 + timedelta(minutes=1),
        pv_kw=None,
        grid_kw=-1.0,
        battery_kw=None,
        heat_pump_kw=0.0,
        ev_kw=0.0,
        price_ct_kwh=30.0,
    )
    filled = fill_gaps([a, b])
    assert filled[1].pv_kw == 3.0 and filled[1].battery_kw == -2.0


def test_eine_gemessene_null_altert_nicht() -> None:
    """Nachts meldet die PV-Seite nichts mehr, weil sich an ihrer Null nichts ändert.

    Der erste Anlauf hielt Werte fünf Minuten - das reicht für einen Takt, nicht für eine Nacht.
    Und weil die Bilanz eine Minute ohne PV-Wert verwirft, nahm die fehlende Null die Entladung des
    Speichers gleich mit. Genau das war der Grund, warum die erste Korrektur nichts bewirkt hat.
    """
    nacht = [
        MinuteSample(
            ts=H0 + timedelta(minutes=i),
            pv_kw=0.0 if i == 0 else None,  # danach schweigt die PV-Seite
            grid_kw=-0.36,
            battery_kw=0.36,
            heat_pump_kw=0.0,
            ev_kw=0.0,
            price_ct_kwh=30.0,
        )
        for i in range(60)
    ]
    h = hourly_energy(H0, fill_gaps(nacht), TARIFF)
    assert h.minutes == 60, "die Null gilt weiter, die Minute bleibt bewertbar"
    assert h.battery_discharge_kwh == pytest.approx(0.36, abs=0.01)
    assert h.pv_kwh == pytest.approx(0.0)


def test_ein_veralteter_wert_ungleich_null_gilt_nicht_weiter() -> None:
    """Eine Leistung, die zuletzt 3 kW war, ist nach einer Stunde Schweigen keine Auskunft mehr."""
    reihe = [
        MinuteSample(
            ts=H0 + timedelta(minutes=i),
            pv_kw=3.0 if i == 0 else None,
            grid_kw=1.0,
            battery_kw=0.0,
            heat_pump_kw=0.0,
            ev_kw=0.0,
            price_ct_kwh=30.0,
        )
        for i in range(30)
    ]
    filled = fill_gaps(reihe)
    assert filled[3].pv_kw == 3.0, "innerhalb der Haltezeit gilt er"
    assert filled[20].pv_kw is None, "danach nicht mehr"


def test_ohne_jede_meldung_entsteht_keine_minute() -> None:
    """Ein Ausfall zählt nicht als abgedeckt, nur weil irgendwann eine Null gemessen wurde."""
    erste = _minutes(3, pv_kw=0.0, grid_kw=0.0, battery_kw=0.0)
    spaet = [
        MinuteSample(
            ts=H0 + timedelta(minutes=50),
            pv_kw=0.0,
            grid_kw=0.0,
            battery_kw=0.0,
            heat_pump_kw=0.0,
            ev_kw=0.0,
            price_ct_kwh=30.0,
        )
    ]
    filled = fill_gaps(erste + spaet)
    assert len(filled) == 3 + 5 + 1, "drei gemessene, fünf gehaltene, dann Stille bis zur letzten"
