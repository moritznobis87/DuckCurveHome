"""Der Satz der Startseite spricht Alltagssprache, in jedem Zustand und mit jedem Grund."""

from __future__ import annotations

from datetime import UTC, datetime
from itertools import product

import pytest

from hems_core.control.explain import explain
from hems_core.domain.decision import ControllerState, DecisionInputs, ReasonCode

#: Wörter des Reglers. Sie standen bis zum 11.11.2026 groß auf der Startseite.
REGLERWOERTER = (
    "Freigabe",
    "Überschuss",
    "Preisfenster",
    "Übersteuerung",
    "Mindestlaufzeit",
    "Mindeststillstand",
    "Regelung",
    "Eingriff",
    "K1",
)


def eingang(*, laeuft: bool = False) -> DecisionInputs:
    return DecisionInputs(
        surplus_ewma_kw=0.0,
        import_ewma_kw=0.4,
        hp_running=laeuft,
        hp_power_kw=3.2 if laeuft else 0.0,
        buffer_soc=0.93,
        buffer_top_c=55.0,
        price_ct_kwh=27.4,
        price_rank=0.5,
        outdoor_temp_c=4.0,
        starts_today=3,
        seconds_since_stop=600.0,
        seconds_since_start=300.0,
    )


def satz(
    zustand: ControllerState,
    grund: ReasonCode | None = None,
    sperre: ReasonCode | None = None,
    *,
    laeuft: bool = False,
) -> str:
    return explain(
        zustand,
        [grund] if grund else [],
        [sperre] if sperre else [],
        eingang(laeuft=laeuft),
        min_offtime_s=1800.0,
        min_runtime_s=1800.0,
        override_ends=datetime(2026, 11, 11, 20, 0, tzinfo=UTC),
    )


@pytest.mark.parametrize(
    ("zustand", "grund", "sperre", "laeuft"),
    list(product(ControllerState, [None, *ReasonCode], [None, *ReasonCode], [False, True])),
)
def test_kein_satz_spricht_die_sprache_des_reglers(
    zustand: ControllerState, grund: ReasonCode | None, sperre: ReasonCode | None, laeuft: bool
) -> None:
    text = satz(zustand, grund, sperre, laeuft=laeuft)
    assert text.endswith("."), "ein ganzer Satz"
    assert " - " not in text, "kein Gedankenstrich als Satzbau"
    for wort in REGLERWOERTER:
        assert wort not in text, f"{wort!r} in {text!r}"


def test_die_wichtigsten_saetze_sagen_was_gemeint_ist() -> None:
    aus = satz(ControllerState.IDLE)
    assert aus == "Die Wärmepumpe ist aus: gerade gibt es weder genug Sonne noch günstigen Strom."
    assert "eigenen Dach" in satz(ControllerState.RUNNING_RELEASED, ReasonCode.PV_SURPLUS)
    assert "am günstigsten" in satz(ControllerState.RUNNING_RELEASED, ReasonCode.PRICE_CHEAP_WINDOW)
    assert "fast voll" in satz(ControllerState.IDLE, None, ReasonCode.BUFFER_NO_HEADROOM)
    assert "93 %" in satz(ControllerState.IDLE, None, ReasonCode.BUFFER_NO_HEADROOM)
    assert "von sich aus" in satz(ControllerState.IDLE, laeuft=True)


def test_die_pause_nennt_die_restzeit_mit_einzahl_und_mehrzahl() -> None:
    assert "noch 20 Minuten Pause" in satz(ControllerState.COOLDOWN)
    kurz = explain(
        ControllerState.COOLDOWN,
        [],
        [],
        eingang().model_copy(update={"seconds_since_stop": 1790.0}),
        min_offtime_s=1800.0,
        min_runtime_s=1800.0,
    )
    assert "noch 1 Minute Pause" in kurz
