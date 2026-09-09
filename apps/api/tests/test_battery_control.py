from __future__ import annotations

from datetime import UTC, datetime, timedelta

from dch_api.application.battery_control import BatteryController
from hems_core.domain.config import BatteryConfig

NOW = datetime(2026, 9, 9, 21, 0, tzinfo=UTC)
CFG = BatteryConfig(control_enabled=True, reserve_soc=0.06)


def _ctrl(**kw: object) -> BatteryController:
    return BatteryController(
        cfg=BatteryConfig(**{"control_enabled": True, "reserve_soc": 0.06, **kw})
    )  # type: ignore[arg-type]


def test_vorgabe_sendet_nichts() -> None:
    """Ein Dienstneustart darf den Speicher nicht anfassen."""
    c = BatteryController(cfg=CFG)
    assert c.mode == "off"
    assert c.wanted(NOW, soc=0.02, surplus_kw=0.0) is None


def test_ohne_freigabe_sendet_nichts() -> None:
    c = BatteryController(cfg=BatteryConfig(control_enabled=False, reserve_soc=0.06))
    c.set("auto", 0, NOW)
    assert c.wanted(NOW, soc=0.02, surplus_kw=0.0) is None


def test_auto_haelt_an_der_untergrenze() -> None:
    c = _ctrl()
    c.set("auto", 0, NOW)
    assert c.wanted(NOW, soc=0.05, surplus_kw=0.0) == "stopped"
    assert c.wanted(NOW, soc=0.40, surplus_kw=0.0) == "normal"


def test_auto_ohne_untergrenze_laesst_ihn_laufen() -> None:
    c = _ctrl(reserve_soc=0.0)
    c.set("auto", 0, NOW)
    assert c.wanted(NOW, soc=0.01, surplus_kw=0.0) == "normal"


def test_manuelles_halten_laeuft_ab_und_faellt_auf_die_vorgabe() -> None:
    """Ein dauerhaft angehaltener Speicher nimmt auch keine Sonne mehr auf."""
    c = _ctrl()
    c.set("hold", 30, NOW)
    assert c.wanted(NOW, soc=0.5, surplus_kw=0.0) == "stopped"
    later = NOW + timedelta(minutes=31)
    assert c.wanted(later, soc=0.5, surplus_kw=0.0) is None
    assert c.mode == "off"


def test_auto_gibt_bei_sonne_frei_auch_unter_der_grenze() -> None:
    c = _ctrl()
    c.set("auto", 0, NOW)
    c.sent = "stopped"
    assert c.wanted(NOW, soc=0.03, surplus_kw=2.0) == "normal"


def test_hysterese_nutzt_den_zuletzt_gesendeten_befehl() -> None:
    c = _ctrl()
    c.set("auto", 0, NOW)
    c.sent = "stopped"
    assert c.wanted(NOW, soc=0.07, surplus_kw=0.0) == "stopped"
    c.sent = "normal"
    assert c.wanted(NOW, soc=0.07, surplus_kw=0.0) == "normal"
