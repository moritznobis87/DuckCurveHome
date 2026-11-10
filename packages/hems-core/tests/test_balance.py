from __future__ import annotations

from hc_helpers import T0, m

from hems_core.balance import NACHT_UNTER_GRAD, balance, pv_bei_nacht, pv_surplus_kw
from hems_core.domain import BalanceConfig, Measurement, PvRuleConfig, Quality


def test_house_is_derived_from_supply() -> None:
    r = balance(
        now=T0,
        pv=m(6.0),
        grid=m(-3.0),
        battery=m(-1.0),
        heat_pump=m(0.0),
        ev=m(0.0),
        house_measured=None,
        cfg=BalanceConfig(),
    )
    assert r.house_power_kw.value == 2.0
    assert r.house_power_kw.quality is Quality.DERIVED
    assert r.base_load_kw.value == 2.0
    assert r.consistent


def test_measured_house_with_residual_is_flagged() -> None:
    r = balance(
        now=T0,
        pv=m(6.0),
        grid=m(-3.0),
        battery=m(0.0),
        heat_pump=m(0.0),
        ev=m(0.0),
        house_measured=m(2.0),
        cfg=BalanceConfig(tolerance_kw=0.3),
    )
    assert not r.consistent
    assert r.residual_kw == 1.0
    assert r.house_power_kw.quality is Quality.INCONSISTENT


def test_base_load_never_negative_but_flagged() -> None:
    r = balance(
        now=T0,
        pv=m(1.0),
        grid=m(1.0),
        battery=m(0.0),
        heat_pump=m(3.6),
        ev=m(0.0),
        house_measured=None,
        cfg=BalanceConfig(),
    )
    assert r.base_load_kw.value == 0.0
    assert r.base_load_kw.quality is Quality.INCONSISTENT


def test_missing_grid_makes_house_unavailable() -> None:
    r = balance(
        now=T0,
        pv=m(1.0),
        grid=m(None, T0, Quality.UNAVAILABLE),
        battery=m(0.0),
        heat_pump=m(0.0),
        ev=m(0.0),
        house_measured=None,
        cfg=BalanceConfig(),
    )
    assert not r.house_power_kw.usable


def test_surplus_counts_battery_only_when_nearly_full() -> None:
    cfg = PvRuleConfig(count_battery_charging_above_soc=0.8)
    low = pv_surplus_kw(
        grid=m(-1.0), battery=m(-3.0), battery_soc=m(0.5), ev=m(0.0), heat_pump=m(0.0), cfg=cfg
    )
    high = pv_surplus_kw(
        grid=m(-1.0), battery=m(-3.0), battery_soc=m(0.9), ev=m(0.0), heat_pump=m(0.0), cfg=cfg
    )
    assert low == 1.0
    assert high == 4.0


def test_surplus_adds_running_heat_pump_and_optionally_ev() -> None:
    cfg = PvRuleConfig(heat_pump_before_ev=True)
    s = pv_surplus_kw(
        grid=m(0.5), battery=m(0.0), battery_soc=m(1.0), ev=m(2.0), heat_pump=m(3.6), cfg=cfg
    )
    assert s == 5.6


def test_surplus_none_without_grid() -> None:
    assert (
        pv_surplus_kw(
            grid=m(None, T0, Quality.STALE),
            battery=m(0.0),
            battery_soc=m(1.0),
            ev=m(0.0),
            heat_pump=m(0.0),
            cfg=PvRuleConfig(),
        )
        is None
    )


def test_nachts_ist_fehlende_erzeugung_null() -> None:
    fehlt = Measurement.missing(Quality.UNAVAILABLE, T0, "pv")
    nachts = pv_bei_nacht(fehlt, T0, -20.0)
    assert nachts.value == 0.0 and nachts.quality is Quality.DERIVED
    assert nachts.source == "nacht:sonne-unter-horizont"
    assert pv_bei_nacht(fehlt, T0, NACHT_UNTER_GRAD).value == 0.0


def test_am_tag_und_in_der_daemmerung_bleibt_die_luecke() -> None:
    fehlt = Measurement.missing(Quality.UNAVAILABLE, T0, "pv")
    assert pv_bei_nacht(fehlt, T0, 30.0) is fehlt
    assert pv_bei_nacht(fehlt, T0, -1.0) is fehlt, "Dämmerung: noch Streulicht möglich"
    assert pv_bei_nacht(fehlt, T0, None) is fehlt, "ohne Sonnenstand ändert sich nichts"


def test_ein_brauchbarer_wert_bleibt_auch_nachts() -> None:
    gemessen = m(0.03)
    assert pv_bei_nacht(gemessen, T0, -40.0) is gemessen
