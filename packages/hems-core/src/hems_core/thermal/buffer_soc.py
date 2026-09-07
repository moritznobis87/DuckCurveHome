"""Thermischer Ladezustand des Pufferspeichers.

Zwei konfigurierbare Methoden:
  layered_energy_v1  - nutzbare Energie je Schicht oberhalb T_min, bezogen auf die Kapazität
                       zwischen T_min und T_max. Schichten unter T_min zählen 0 (Schichtung wird
                       berücksichtigt). Standard.
  weighted_mean_v1   - gewichtete Mitteltemperatur, linear zwischen T_min und T_max.
Beide sind Schätzwerte; die Methode wird im Ergebnis mitgeführt.
"""

from __future__ import annotations

from collections.abc import Sequence

from hems_core.domain.buffer import BufferState, BufferStatus
from hems_core.domain.config import BufferConfig
from hems_core.domain.snapshot import BufferTemperatures

KWH_PER_LITER_KELVIN = 4.186 / 3600.0  # Wasser: 4,186 kJ/(kg·K) → kWh/(l·K)


def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))


def status_for(soc: float, cfg: BufferConfig) -> BufferStatus:
    cold, partial, warm = cfg.status_thresholds
    if soc < cold:
        return BufferStatus.COLD
    if soc < partial:
        return BufferStatus.PARTIAL
    if soc < warm:
        return BufferStatus.WARM
    return BufferStatus.FULL


def capacity_kwh(cfg: BufferConfig) -> float:
    span = cfg.max_temperature_c - cfg.min_useful_temperature_c
    return cfg.volume_liters * KWH_PER_LITER_KELVIN * span


def usable_energy_kwh(temps: Sequence[float], cfg: BufferConfig) -> float:
    """Nutzbare Energie im Puffer oberhalb T_min, aus vier Schichttemperaturen.

    Herausgezogen aus `compute_buffer_state`, damit dieselbe Rechnung auch auf eine Zeitreihe
    angewandt werden kann: die Änderung dieses Werts über die Zeit ist die Netto-Wärmeleistung des
    Speichers - Zufuhr minus Entnahme minus Verluste. Damit lässt sich Fremdwärme beziffern, statt
    sie nur zu vermuten, ganz ohne Wärmemengenzähler.
    """
    if len(temps) != len(cfg.layers):
        raise ValueError("temps und buffer.layers müssen gleich lang sein")
    usable = 0.0
    for share, ti in zip(cfg.layers, temps, strict=True):
        liters = cfg.volume_liters * share
        usable += liters * KWH_PER_LITER_KELVIN * max(0.0, ti - cfg.min_useful_temperature_c)
    return min(usable, capacity_kwh(cfg))


def compute_buffer_state(temps: BufferTemperatures, cfg: BufferConfig) -> BufferState:
    cap = capacity_kwh(cfg)
    values = [m.value if m.usable else None for m in temps.as_list()]
    if any(v is None for v in values):
        return BufferState(
            soc=None,
            usable_energy_kwh=None,
            capacity_kwh=cap,
            volume_liters=cfg.volume_liters,
            mean_temp_c=None,
            status=BufferStatus.UNKNOWN,
            method=cfg.soc_method,
            headroom_soc=None,
        )
    t = [float(v) for v in values if v is not None]
    if len(cfg.layers) != 4 or abs(sum(cfg.layers) - 1.0) > 1e-6:
        raise ValueError("buffer.layers muss vier Anteile mit Summe 1 enthalten")

    if cfg.soc_method == "weighted_mean_v1":
        if len(cfg.weights) != 4:
            raise ValueError("buffer.weights muss vier Gewichte enthalten")
        wsum = sum(cfg.weights)
        mean = sum(w * ti for w, ti in zip(cfg.weights, t, strict=True)) / wsum
        span = cfg.max_temperature_c - cfg.min_useful_temperature_c
        soc = _clamp01((mean - cfg.min_useful_temperature_c) / span)
        usable = soc * cap
    else:
        usable = usable_energy_kwh(t, cfg)
        soc = _clamp01(usable / cap) if cap > 0 else 0.0
        mean = sum(s * ti for s, ti in zip(cfg.layers, t, strict=True))

    return BufferState(
        soc=round(soc, 4),
        usable_energy_kwh=round(usable, 3),
        capacity_kwh=round(cap, 3),
        volume_liters=cfg.volume_liters,
        mean_temp_c=round(mean, 2),
        status=status_for(soc, cfg),
        method=cfg.soc_method,
        headroom_soc=round(1.0 - soc, 4),
    )
