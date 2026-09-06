"""LiveState: letzter Wert je Schlüssel → EnergySnapshot mit Bilanz und Alterung."""

from __future__ import annotations

from datetime import UTC, datetime

from hems_core.balance import balance
from hems_core.domain import BufferTemperatures, EnergySnapshot, HemsConfig, Measurement, Quality
from hems_core.protocol import RawReading

POWER_KEYS = (
    "pv_power_kw",
    "grid_power_kw",
    "battery_power_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
)


class LiveState:
    def __init__(self, cfg: HemsConfig) -> None:
        self.cfg = cfg
        self.readings: dict[str, RawReading] = {}
        self.updated_at: datetime | None = None

    def apply(self, items: list[RawReading]) -> None:
        for r in items:
            cur = self.readings.get(r.key)
            # Eine leere Meldung (unavailable/unknown) einer anderen Quelle verdrängt keinen gültigen Wert:
            # liefert myenergi PV direkt, darf der ausgefallene HA-Sensor ihn nicht auf „–“ setzen.
            if (
                r.value is None
                and cur is not None
                and cur.value is not None
                and (cur.source or "") != (r.source or "")
            ):
                continue
            if cur is None or r.observed_at >= cur.observed_at:
                self.readings[r.key] = r
        self.updated_at = datetime.now(UTC)

    def _m(self, key: str, now: datetime, stale_after_s: float) -> Measurement:
        r = self.readings.get(key)
        if r is None:
            return Measurement.missing(Quality.UNAVAILABLE, now, key)
        m = Measurement(
            value=r.value, observed_at=r.observed_at, quality=r.quality, source=r.source or key
        )
        return m.aged(now, stale_after_s)

    def snapshot(self, now: datetime | None = None) -> EnergySnapshot:
        now = now or datetime.now(UTC)
        t = self.cfg.timeouts
        pv = self._m("pv_power_kw", now, t.power_s)
        grid = self._m("grid_power_kw", now, t.power_s)
        bat = self._m("battery_power_kw", now, t.battery_s)
        hp = self._m("heat_pump_power_kw", now, t.power_s)
        ev = self._m("ev_power_kw", now, t.power_s)
        house_measured = (
            self._m("house_power_kw", now, t.power_s) if "house_power_kw" in self.readings else None
        )
        b = balance(
            now=now,
            pv=pv,
            grid=grid,
            battery=bat,
            heat_pump=hp,
            ev=ev,
            house_measured=house_measured,
            cfg=self.cfg.balance,
        )
        actuators = {
            k.removeprefix("actuator:"): self._m(k, now, 3600.0)
            for k in self.readings
            if k.startswith("actuator:")
        }
        return EnergySnapshot(
            timestamp=now,
            pv_power_kw=pv,
            grid_power_kw=grid,
            battery_power_kw=bat,
            battery_soc=self._m("battery_soc", now, t.battery_s),
            house_power_kw=b.house_power_kw,
            base_load_kw=b.base_load_kw,
            heat_pump_power_kw=hp,
            ev_power_kw=ev,
            electricity_price_ct_kwh=self._m("electricity_price_ct_kwh", now, t.price_s),
            outdoor_temp_c=self._m("outdoor_temp_c", now, 3 * 3600.0),
            buffer_temps_c=BufferTemperatures(
                top=self._m("buffer_temp_top_c", now, t.temperature_s),
                mid_top=self._m("buffer_temp_mid_top_c", now, t.temperature_s),
                mid_bottom=self._m("buffer_temp_mid_bottom_c", now, t.temperature_s),
                bottom=self._m("buffer_temp_bottom_c", now, t.temperature_s),
            ),
            hp_release_contact=self._m("actuator:hp_release_contact", now, 3600.0),
            hp_block_contact=self._m("actuator:hp_block_contact", now, 3600.0),
            actuators=actuators,
            balance_residual_kw=b.residual_kw,
        )
