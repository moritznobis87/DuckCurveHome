from __future__ import annotations

import pytest
from hc_helpers import T0, m

from hems_core.domain import BufferConfig, BufferStatus, BufferTemperatures, Quality
from hems_core.thermal import capacity_kwh, compute_buffer_state, nutzbarer_inhalt_kwh


def temps(*t: float) -> BufferTemperatures:
    return BufferTemperatures(top=m(t[0]), mid_top=m(t[1]), mid_bottom=m(t[2]), bottom=m(t[3]))


def test_capacity_1000l_between_35_and_62() -> None:
    cap = capacity_kwh(BufferConfig())
    assert cap == pytest.approx(1000 * 27 * 4.186 / 3600, rel=1e-6)


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


@pytest.mark.parametrize("methode", ["layered_energy_v1", "weighted_mean_v1"])
@pytest.mark.parametrize(
    "schichten", [(62.0, 55.0, 41.0, 30.0), (36.0, 36.0, 36.0, 36.0), (80.0, 80.0, 80.0, 80.0)]
)
def test_der_nutzbare_inhalt_aus_blossen_temperaturen_ist_der_des_pufferzustands(
    methode: str, schichten: tuple[float, float, float, float]
) -> None:
    """Der gemessene Pufferinhalt im Fahrplan und der Startwert des Optimierers sind eine Zahl.

    Der Optimierer beginnt mit `compute_buffer_state(...).usable_energy_kwh`. Der Fahrplan
    zeigt daneben den gemessenen Inhalt der vergangenen Stunden aus `nutzbarer_inhalt_kwh`;
    wichen die beiden ab, spränge die Kurve an der Jetzt-Linie.
    """
    cfg = BufferConfig(soc_method=methode)  # type: ignore[arg-type]
    zustand = compute_buffer_state(temps(*schichten), cfg)
    assert nutzbarer_inhalt_kwh(schichten, cfg) == pytest.approx(
        zustand.usable_energy_kwh, abs=1e-3
    )
