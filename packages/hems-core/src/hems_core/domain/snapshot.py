"""EnergySnapshot – der vollständige Zustand des Hauses zu einem Zeitpunkt.

Vorzeichenkonvention (verbindlich, siehe docs/PROJECT_PLAN.md Abschnitt 7):
  Aus Sicht des Hauses. Erzeuger positiv, Verbraucher positiv.
  grid_power_kw     > 0 Netzbezug, < 0 Einspeisung
  battery_power_kw  > 0 Entladen (Batterie -> Haus), < 0 Laden
  house_power_kw    Gesamtverbrauch inkl. Wärmepumpe und Wallbox
  base_load_kw      Verbrauch ohne Wärmepumpe und Wallbox (abgeleitet)
Bilanz: pv + grid + battery = house = base + heat_pump + ev
"""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from hems_core.domain.measurement import Measurement


class BufferTemperatures(BaseModel):
    model_config = ConfigDict(frozen=True)

    top: Measurement
    mid_top: Measurement
    mid_bottom: Measurement
    bottom: Measurement

    def as_list(self) -> list[Measurement]:
        return [self.top, self.mid_top, self.mid_bottom, self.bottom]

    @property
    def all_usable(self) -> bool:
        return all(m.usable for m in self.as_list())


class EnergySnapshot(BaseModel):
    model_config = ConfigDict(frozen=True)

    timestamp: datetime
    pv_power_kw: Measurement
    grid_power_kw: Measurement
    battery_power_kw: Measurement
    battery_soc: Measurement
    house_power_kw: Measurement
    base_load_kw: Measurement
    heat_pump_power_kw: Measurement
    ev_power_kw: Measurement
    electricity_price_ct_kwh: Measurement
    outdoor_temp_c: Measurement
    buffer_temps_c: BufferTemperatures
    hp_release_contact: Measurement  # K1 „PV-Überschuss“ (0/1)
    hp_block_contact: Measurement  # K2 „Netzbetreiber-Shutdown“ (0/1)
    actuators: dict[str, Measurement] = Field(default_factory=dict)
    balance_residual_kw: float = 0.0

    @property
    def export_kw(self) -> float:
        """Einspeisung als positive Zahl (0, wenn Bezug)."""
        return max(0.0, -self.grid_power_kw.value_or(0.0))

    @property
    def import_kw(self) -> float:
        return max(0.0, self.grid_power_kw.value_or(0.0))
