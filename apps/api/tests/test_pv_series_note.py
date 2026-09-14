"""Die Gegenprobe auf die Erzeugungsreihe: eine ausgefallene Messung von einem grauen Tag trennen.

Die Frage, an der sich das entscheidet, kam aus dem Betrieb: der Speicher lädt, die Auswertung
weist die Ladung dem Netz zu, obwohl die Sonne schien. Zwei Ursachen sehen in den Stundenwerten
gleich aus - die Erzeugung lag unter der Ladeleistung, oder sie wurde nicht gemessen. Die zweite
hat eine Signatur, und dieser Test hält sie fest. Der zweite Test ist der wichtigere: die
Dunkelheit vor Sonnenaufgang darf den Verdacht **nicht** auslösen, sonst meldet das Werkzeug an
jedem Tag des Jahres einen Ausfall und taugt für die eine Frage nicht mehr, für die es da ist.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from dch_api.application.energy_accounting import _pv_series_note
from hems_core.accounting import MinuteSample
from hems_core.simulation import BERLIN

# 04:00 UTC, also 06:00 Ortszeit: der Tag beginnt hier im Dunkeln.
T0 = datetime(2026, 9, 13, 4, 0, tzinfo=UTC)


def _samples(pv: list[float | None], grid: list[float] | None = None) -> list[MinuteSample]:
    g = grid if grid is not None else [1.0 + 0.05 * i for i in range(len(pv))]
    return [
        MinuteSample(
            ts=T0 + timedelta(minutes=i),
            pv_kw=p,
            grid_kw=g[i],
            battery_kw=-2.0,
            heat_pump_kw=None,
            ev_kw=None,
            price_ct_kwh=20.0,
        )
        for i, p in enumerate(pv)
    ]


def test_a_dropout_inside_the_generating_stretch_is_flagged() -> None:
    """Erzeugung, dann 40 Minuten exakt null, dann wieder Erzeugung: das ist kein Wetter."""
    rows = _samples([1.5] * 10 + [0.0] * 40 + [1.5] * 10)
    note = _pv_series_note(rows, BERLIN)
    assert any("gemessen von 06:00 bis 06:59" in line for line in note)
    assert any("40 Minuten auf genau 0,00 kW" in line for line in note)
    assert any("06:10-06:49 (40 min)" in line for line in note)
    assert any("Ausfall der Erzeugungsmessung" in line for line in note)


def test_darkness_before_sunrise_and_after_sunset_never_triggers() -> None:
    """Die Nullen am Rand liegen außerhalb der Erzeugungsstrecke und werden nicht geprüft."""
    rows = _samples([0.0] * 60 + [1.5] * 30 + [0.0] * 60)
    note = _pv_series_note(rows, BERLIN)
    assert any("gemessen von 07:00 bis 07:29" in line for line in note)
    assert any("darin 0 Minuten auf genau 0,00 kW" in line for line in note)
    assert not any("Null-Strecke" in line for line in note)


def test_a_still_grid_leaves_the_verdict_open() -> None:
    """Steht auch der Netzwert still, ist der Beweis für einen laufenden Logger nicht geführt."""
    rows = _samples([1.5] * 10 + [0.0] * 40 + [1.5] * 10, [1.0] * 60)
    note = _pv_series_note(rows, BERLIN)
    assert any("Null-Strecke" in line for line in note)
    assert not any("Ausfall der Erzeugungsmessung" in line for line in note)


def test_short_cloud_gaps_stay_below_the_threshold() -> None:
    rows = _samples([1.5] * 10 + [0.0] * 10 + [1.5] * 10)
    note = _pv_series_note(rows, BERLIN)
    assert any("10 Minuten auf genau 0,00 kW" in line for line in note)
    assert not any("Null-Strecke" in line for line in note)


def test_a_day_without_any_generation_says_so() -> None:
    rows = _samples([0.0] * 120)
    note = _pv_series_note(rows, BERLIN)
    assert note == [
        "Erzeugungsreihe: an keiner der 120 Minuten dieses Tages wurde Erzeugung gemessen "
        "(0 Minuten ohne Wert)."
    ]


def test_missing_values_are_counted_separately() -> None:
    rows = _samples([1.5] * 10 + [None] * 5 + [1.5] * 10)
    note = _pv_series_note(rows, BERLIN)
    assert any("(5 Minuten des Tages ohne Wert)" in line for line in note)


def test_no_samples_at_all() -> None:
    assert _pv_series_note([], BERLIN) == []
