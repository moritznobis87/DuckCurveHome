from __future__ import annotations

import pytest
from hc_helpers import T0, m

from hems_core.domain import BufferConfig, BufferStatus, BufferTemperatures, Quality
from hems_core.thermal import capacity_kwh, compute_buffer_state


def temps(*t: float) -> BufferTemperatures:
    return BufferTemperatures(top=m(t[0]), mid_top=m(t[1]), mid_bottom=m(t[2]), bottom=m(t[3]))


def test_capacity_800l_between_35_and_62() -> None:
    cap = capacity_kwh(BufferConfig())
    assert cap == pytest.approx(800 * 27 * 4.186 / 3600, rel=1e-6)


def test_full_and_empty_bounds() -> None:
    cfg = BufferConfig()
    assert compute_buffer_state(temps(62, 62, 62, 62), cfg).soc == 1.0
    assert compute_buffer_state(temps(30, 30, 30, 30), cfg).soc == 0.0
    assert compute_buffer_state(temps(80, 80, 80, 80), cfg).soc == 1.0


def test_layered_energy_ignores_cold_layers() -> None:
    cfg = BufferConfig()
    st = compute_buffer_state(temps(62, 62, 20, 20), cfg)
    assert st.soc == pytest.approx(0.5, abs=1e-3)
    assert st.status is BufferStatus.PARTIAL


def test_weighted_mean_method() -> None:
    cfg = BufferConfig(soc_method="weighted_mean_v1")
    st = compute_buffer_state(temps(62, 62, 35, 35), cfg)
    assert st.soc == pytest.approx(0.5, abs=1e-3)
    assert st.method == "weighted_mean_v1"


def test_status_thresholds() -> None:
    cfg = BufferConfig()
    assert compute_buffer_state(temps(36, 36, 36, 36), cfg).status is BufferStatus.COLD
    assert compute_buffer_state(temps(60, 58, 49, 38), cfg).status is BufferStatus.WARM
    assert compute_buffer_state(temps(61, 61, 61, 60), cfg).status is BufferStatus.FULL


def test_missing_sensor_gives_unknown() -> None:
    cfg = BufferConfig()
    t = BufferTemperatures(
        top=m(60), mid_top=m(None, T0, Quality.UNAVAILABLE), mid_bottom=m(45), bottom=m(40)
    )
    st = compute_buffer_state(t, cfg)
    assert st.soc is None
    assert st.status is BufferStatus.UNKNOWN
