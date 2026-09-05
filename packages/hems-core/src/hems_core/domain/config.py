"""Konfiguration der Regelung und der thermischen Modelle.

Alle Werte sind Defaults und werden aus YAML/Env überschrieben (CONFIGURATION.md).
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class HeatPumpConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    minimum_electric_power_kw: float = 3.5
    nominal_electric_power_kw: float = 4.5
    nominal_thermal_power_kw: float = 12.0
    running_threshold_kw: float = 0.5
    running_debounce_s: int = 60
    min_runtime_min: int = 30
    min_offtime_min: int = 20
    start_timeout_min: int = 10
    max_starts_per_day: int = 8
    release_ttl_min: int = 20
    hw_auto_off_release_s: int = 1800
    hw_auto_off_block_s: int = 1200


class PvRuleConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    on_surplus_kw: float = 4.0
    off_import_kw: float = 1.5
    on_delay_min: float = 5.0
    off_delay_min: float = 10.0
    count_battery_charging_above_soc: float = 0.8
    heat_pump_before_ev: bool = False
    min_buffer_headroom_soc: float = 0.10


class PriceRuleConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    negative_price_release: bool = True
    cheap_quantile: float = 0.10
    min_window_min: int = 30
    price_max_age_h: float = 30.0
    expensive_quantile: float = 0.85


class BlockRuleConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    enabled: bool = False
    max_duration_min: int = 120
    max_per_day: int = 2
    min_soc: float = 0.6
    min_outdoor_temp_c: float = 3.0
    block_ttl_min: int = 15


class ControlConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    tick_s: int = 10
    ewma_seconds: float = 180.0
    sensor_grace_min: float = 5.0
    max_toggles_per_hour: int = 4
    failsafe_hold_min: int = 60
    pv: PvRuleConfig = PvRuleConfig()
    price: PriceRuleConfig = PriceRuleConfig()
    block: BlockRuleConfig = BlockRuleConfig()


class BufferConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    # Kombipuffer: Wärmepumpe und Pelletofen speisen ein, Heizung und Warmwasser entnehmen
    volume_liters: float = 1000.0
    layers: list[float] = Field(default_factory=lambda: [0.25, 0.25, 0.25, 0.25])
    min_useful_temperature_c: float = 35.0
    target_temperature_c: float = 50.0
    max_temperature_c: float = 62.0
    comfort_min_top_c: float = 42.0
    loss_kw_per_k: float = 0.004
    soc_method: Literal["layered_energy_v1", "weighted_mean_v1"] = "layered_energy_v1"
    weights: list[float] = Field(default_factory=lambda: [0.25, 0.25, 0.25, 0.25])
    status_thresholds: tuple[float, float, float] = (0.2, 0.6, 0.9)  # cold|partial|warm|full
    soc_full: float = 0.95  # ab hier gilt „voll“ für den Regler


class BalanceConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    tolerance_kw: float = 0.3
    min_flow_kw: float = 0.05  # darunter gilt „kein Fluss“


class SensorTimeouts(BaseModel):
    model_config = ConfigDict(frozen=True)

    power_s: float = 60.0
    battery_s: float = 60.0
    temperature_s: float = 900.0
    price_s: float = 3600.0 * 2


class HemsConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    heat_pump: HeatPumpConfig = HeatPumpConfig()
    control: ControlConfig = ControlConfig()
    buffer: BufferConfig = BufferConfig()
    balance: BalanceConfig = BalanceConfig()
    timeouts: SensorTimeouts = SensorTimeouts()
