"""Wärmeseite: Wärmebedarfsprognose aus Außentemperatur und gelieferte Wärme aus Strom × COP.

Modell v1 nach Projektplan Abschnitt 20.2: Heizgradstunden gegen eine Innentemperatur, Warmwasser als
Tagesprofil. Ohne Wärmemengenzähler ist das eine Schätzung und wird als solche ausgewiesen.
"""

from __future__ import annotations

from collections.abc import Iterable
from datetime import datetime
from itertools import pairwise

from pydantic import BaseModel, ConfigDict

from hems_core.domain.config import HeatDemandConfig


def cop_at(outdoor_c: float, cfg: HeatDemandConfig) -> float:
    """Linear interpolierte COP-Kennlinie über der Außentemperatur."""
    pts = sorted(cfg.cop_curve, key=lambda p: p[0])
    if not pts:
        return 3.0
    if outdoor_c <= pts[0][0]:
        return pts[0][1]
    if outdoor_c >= pts[-1][0]:
        return pts[-1][1]
    for (t0, c0), (t1, c1) in pairwise(pts):
        if t0 <= outdoor_c <= t1:
            f = (outdoor_c - t0) / (t1 - t0) if t1 > t0 else 0.0
            return round(c0 + (c1 - c0) * f, 3)
    return pts[-1][1]


def heat_demand_kw(outdoor_c: float, hour_local: int, cfg: HeatDemandConfig) -> tuple[float, float]:
    """(Heizleistung, Warmwasserleistung) in kW_th für eine Stunde."""
    heating = 0.0
    if outdoor_c < cfg.heating_limit_c:
        heating = cfg.heat_loss_kw_per_k * max(0.0, cfg.indoor_target_c - outdoor_c)
        heating = max(0.0, heating - cfg.internal_gains_kw)
    profile = cfg.dhw_profile
    weight = profile[hour_local % 24] if len(profile) == 24 else 1.0
    total_weight = sum(profile) if len(profile) == 24 else 24.0
    dhw = cfg.dhw_kwh_per_day * (weight / total_weight) if total_weight > 0 else 0.0
    return round(heating, 3), round(dhw, 3)


class HeatForecastPoint(BaseModel):
    model_config = ConfigDict(frozen=True)

    ts: datetime
    outdoor_c: float
    heating_kw: float
    dhw_kw: float
    cop: float
    electric_kw: float  # erwarteter Strombedarf der Wärmepumpe


def heat_forecast(
    temps: Iterable[tuple[datetime, float]], cfg: HeatDemandConfig, tz_offset_h: int = 0
) -> list[HeatForecastPoint]:
    out: list[HeatForecastPoint] = []
    for ts, t_out in temps:
        heating, dhw = heat_demand_kw(t_out, (ts.hour + tz_offset_h) % 24, cfg)
        cop = cop_at(t_out, cfg)
        out.append(
            HeatForecastPoint(
                ts=ts,
                outdoor_c=round(t_out, 1),
                heating_kw=heating,
                dhw_kw=dhw,
                cop=cop,
                electric_kw=round((heating + dhw) / cop, 3) if cop > 0 else 0.0,
            )
        )
    return out


def thermal_kwh_from_electric(
    electric_kwh: float, outdoor_c: float | None, cfg: HeatDemandConfig
) -> float:
    """Gelieferte Wärme aus Strom über die COP-Kennlinie (Schätzung ohne Wärmemengenzähler)."""
    cop = cop_at(outdoor_c if outdoor_c is not None else 7.0, cfg)
    return round(electric_kwh * cop, 3)
