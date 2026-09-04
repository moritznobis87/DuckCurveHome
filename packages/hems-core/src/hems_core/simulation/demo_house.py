"""Simuliertes Haus für den Demo-Modus.

Erzeugt realistische Tagesverläufe ohne echte Geräte: PV aus Sonnenstand und Bewölkung, Grundlast
mit Tagesprofil, Außentemperatur, eine Wärmepumpe mit eigener Regelung, die auf K1 (Freigabe) und K2
(Sperre) reagiert, ein vierschichtiger Pufferspeicher, Batterie (Libbi-Verhalten), Wallbox (Zappi
Eco+) und Tibber-ähnliche Preise. Deterministisch über einen Seed; die Zeit läuft in Schritten
beliebiger Länge (Zeitraffer).
"""

from __future__ import annotations

import hashlib
import math
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

from pydantic import BaseModel, ConfigDict

from hems_core.domain.config import BufferConfig
from hems_core.domain.measurement import Measurement
from hems_core.domain.quality import Quality
from hems_core.domain.snapshot import BufferTemperatures, EnergySnapshot
from hems_core.planning.price_windows import PricePoint

BERLIN = ZoneInfo("Europe/Berlin")
KWH_PER_L_K = 4.186 / 3600.0


class DemoConfig(BaseModel):
    model_config = ConfigDict(frozen=True)

    seed: int = 7
    latitude: float = 50.97
    longitude: float = 6.12
    pv_kwp: float = 9.9
    inverter_ac_kw: float = 8.25
    battery_kwh: float = 10.0
    battery_max_kw: float = 3.7
    battery_min_soc: float = 0.08
    ev_max_kw: float = 7.2
    ev_min_kw: float = 1.4
    ev_need_kwh: float = 12.0
    hp_min_runtime_s: int = 15 * 60
    hp_min_offtime_s: int = 10 * 60
    house_heat_loss_kw_per_k: float = 0.22
    indoor_target_c: float = 21.0
    heating_limit_c: float = 15.0
    cold_water_c: float = 12.0
    heating_return_c: float = 32.0
    ambient_c: float = 20.0
    negative_price_days: bool = True  # sonnige Wochenenden mit negativen Mittagspreisen
    buffer: BufferConfig = BufferConfig()


@dataclass
class Fault:
    key: str
    quality: Quality
    until: datetime


@dataclass
class DemoHouse:
    cfg: DemoConfig
    now: datetime
    temps: list[float] = field(default_factory=lambda: [52.0, 49.0, 43.0, 36.0])
    battery_soc: float = 0.55
    hp_running: bool = False
    hp_since: datetime | None = None
    hp_stopped_at: datetime | None = None
    hp_power_kw: float = 0.0
    k1: bool = False
    k2: bool = False
    k1_until: datetime | None = None
    k2_until: datetime | None = None
    ev_delivered_kwh: float = 0.0
    ev_power_kw: float = 0.0
    ev_day: date | None = None
    actuators: dict[str, bool] = field(
        default_factory=lambda: {
            "coffee_machine": False,
            "terrace_light": False,
            "garden_fence_light": False,
        }
    )
    actuator_until: dict[str, datetime] = field(default_factory=dict)
    faults: list[Fault] = field(default_factory=list)
    _pv_kw: float = 0.0
    _base_kw: float = 0.0
    _grid_kw: float = 0.0
    _battery_kw: float = 0.0
    _pellet_kw_th: float = 0.0

    # ------------------------------------------------------------------ Zufall (deterministisch)
    def _hash(self, *parts: object) -> float:
        raw = ":".join(str(p) for p in (self.cfg.seed, *parts)).encode()
        return int.from_bytes(hashlib.sha256(raw).digest()[:8], "big") / 2**64

    # ------------------------------------------------------------------ Umwelt
    def local(self, t: datetime | None = None) -> datetime:
        return (t or self.now).astimezone(BERLIN)

    def solar_elevation(self, t: datetime) -> float:
        lt = self.local(t)
        n = lt.timetuple().tm_yday
        decl = math.radians(23.44) * math.sin(2 * math.pi * (284 + n) / 365)
        # Sonnenzeit: UTC-Stunde + Längengrad/15 (grob, ohne Zeitgleichung)
        ut = t.astimezone(UTC)
        solar_hour = ut.hour + ut.minute / 60 + ut.second / 3600 + self.cfg.longitude / 15
        hour_angle = math.radians(15 * (solar_hour - 12))
        lat = math.radians(self.cfg.latitude)
        s = math.sin(lat) * math.sin(decl) + math.cos(lat) * math.cos(decl) * math.cos(hour_angle)
        return math.degrees(math.asin(max(-1.0, min(1.0, s))))

    def day_cloudiness(self, d: date) -> float:
        return 0.08 + 0.75 * self._hash("cloud", d.isoformat())

    def pv_clear_sky_kw(self, t: datetime) -> float:
        el = self.solar_elevation(t)
        if el <= 0:
            return 0.0
        s = math.sin(math.radians(el))
        air = 1.0 - 0.18 * (1.0 - s)  # Luftmasse grob
        return min(self.cfg.inverter_ac_kw, self.cfg.pv_kwp * 0.88 * s * air)

    def pv_expected_kw(self, t: datetime) -> float:
        """Erwartete PV (Prognose): Klarhimmel × mittlerer Bewölkungsfaktor des Tages."""
        c = self.day_cloudiness(self.local(t).date())
        return self.pv_clear_sky_kw(t) * (1.0 - 0.85 * c)

    def pv_actual_kw(self, t: datetime) -> float:
        d = self.local(t).date()
        c = self.day_cloudiness(d)
        h = self.local(t).hour + self.local(t).minute / 60 + self.local(t).second / 3600
        p1, p2 = self._hash("p1", d) * 6.28, self._hash("p2", d) * 6.28
        wobble = 0.5 + 0.5 * math.sin(2 * math.pi * h / 1.7 + p1) * math.sin(
            2 * math.pi * h / 0.45 + p2
        )
        factor = 1.0 - c * (0.55 + 0.6 * wobble)
        return max(0.0, self.pv_clear_sky_kw(t) * max(0.12, min(1.0, factor)))

    def outdoor_temp_c(self, t: datetime) -> float:
        lt = self.local(t)
        n = lt.timetuple().tm_yday
        mean = 10.0 + 9.0 * math.cos(2 * math.pi * (n - 200) / 365)
        day_offset = (self._hash("tday", lt.date()) - 0.5) * 6
        h = lt.hour + lt.minute / 60
        diurnal = 4.5 * math.cos(2 * math.pi * (h - 15) / 24)
        return round(mean + day_offset + diurnal, 1)

    def base_load_kw(self, t: datetime) -> float:
        lt = self.local(t)
        profile = [
            0.35,
            0.30,
            0.30,
            0.30,
            0.30,
            0.40,
            0.90,
            1.20,
            0.80,
            0.60,
            0.60,
            0.70,
            1.00,
            0.70,
            0.50,
            0.50,
            0.70,
            1.10,
            1.60,
            1.40,
            1.10,
            0.90,
            0.60,
            0.40,
        ]
        h = lt.hour
        frac = lt.minute / 60
        base = profile[h] * (1 - frac) + profile[(h + 1) % 24] * frac
        noise = 0.85 + 0.3 * self._hash("load", lt.date(), lt.hour, lt.minute // 5)
        spike = 0.0
        if 18 <= h < 20 and self._hash("spike", lt.date(), lt.hour, lt.minute // 10) > 0.7:
            spike = 1.8
        extra = 1.2 if self.actuators.get("coffee_machine") else 0.0
        extra += 0.03 if self.actuators.get("terrace_light") else 0.0
        extra += 0.02 if self.actuators.get("garden_fence_light") else 0.0
        return round(base * noise + spike + extra, 3)

    # ------------------------------------------------------------------ Preise
    def prices_for_day(self, d: date) -> list[PricePoint]:
        shape = [
            18.5,
            18.3,
            18.1,
            18.5,
            19.2,
            22.0,
            27.5,
            31.2,
            38.3,
            34.1,
            29.4,
            25.0,
            22.0,
            19.6,
            17.2,
            18.9,
            21.4,
            30.0,
            42.0,
            40.5,
            38.0,
            33.2,
            29.9,
            26.4,
        ]
        day_factor = 0.85 + 0.35 * self._hash("pday", d)
        sunny_weekend = d.weekday() >= 5 and self.day_cloudiness(d) < 0.3
        points: list[PricePoint] = []
        start_local = datetime(d.year, d.month, d.day, tzinfo=BERLIN)
        for h, v in enumerate(shape):
            noise = 0.92 + 0.16 * self._hash("ph", d, h)
            price = v * day_factor * noise
            if self.cfg.negative_price_days and sunny_weekend and 11 <= h <= 14:
                price = -1.5 - 3.0 * self._hash("neg", d, h)
            s = start_local + timedelta(hours=h)
            points.append(
                PricePoint(
                    s.astimezone(UTC), (s + timedelta(hours=1)).astimezone(UTC), round(price, 2)
                )
            )
        return points

    def prices_available(self, t: datetime) -> list[PricePoint]:
        """Heute immer; morgen ab 13:00 Ortszeit (wie Tibber)."""
        lt = self.local(t)
        pts = self.prices_for_day(lt.date())
        if lt.hour >= 13:
            pts += self.prices_for_day(lt.date() + timedelta(days=1))
        return pts

    def current_price(self, t: datetime) -> float:
        for p in self.prices_for_day(self.local(t).date()):
            if p.start <= t < p.end:
                return p.ct_kwh
        return 25.0

    # ------------------------------------------------------------------ Aktoren
    def set_actuator(self, key: str, on: bool, ttl_s: int | None = None) -> bool:
        if key == "hp_release_contact":
            self.k1 = on
            self.k1_until = self.now + timedelta(seconds=ttl_s) if (on and ttl_s) else None
            return True
        if key == "hp_block_contact":
            self.k2 = on
            self.k2_until = self.now + timedelta(seconds=ttl_s) if (on and ttl_s) else None
            return True
        if key in self.actuators:
            self.actuators[key] = on
            if on and ttl_s:
                self.actuator_until[key] = self.now + timedelta(seconds=ttl_s)
            else:
                self.actuator_until.pop(key, None)
            return True
        return False

    def inject_fault(self, key: str, quality: Quality, duration_s: int) -> None:
        self.faults = [f for f in self.faults if f.key != key]
        self.faults.append(Fault(key, quality, self.now + timedelta(seconds=duration_s)))

    def _fault_for(self, key: str) -> Quality | None:
        for f in self.faults:
            if f.key == key and self.now < f.until:
                return f.quality
        return None

    # ------------------------------------------------------------------ Physik
    def _hp_cop(self, t_out: float) -> float:
        return max(2.2, min(4.5, 2.4 + 0.09 * (t_out + 7)))

    def _hp_el(self, t_out: float) -> float:
        return max(3.0, min(4.5, 3.2 + 0.05 * (15 - t_out)))

    def _hp_control(self, dt_s: float) -> None:
        """Eigene Regelung der Wärmepumpe + Reaktion auf K1/K2 (Näherung ELCO-Verhalten)."""
        top, _, mid_bottom, _ = self.temps
        since_start = (self.now - self.hp_since).total_seconds() if self.hp_since else None
        since_stop = (self.now - self.hp_stopped_at).total_seconds() if self.hp_stopped_at else 1e9
        want = self.hp_running
        if self.k2 and top > 30.0:
            want = False  # EVU-Sperre: nur Frostschutz
        elif self.hp_running:
            if self.k1:
                want = not (top >= self.cfg.buffer.max_temperature_c or mid_bottom >= 56.0)
            else:
                # eigene Regelung: lädt bis Kopf 56 °C und dritte Schicht 44 °C (Kombispeicher)
                want = top < 56.0 or mid_bottom < 44.0
        else:
            if self.k1:
                want = top < self.cfg.buffer.max_temperature_c - 2 and mid_bottom < 54.0
            else:
                want = top < 48.0 or mid_bottom < 36.0
        if want and not self.hp_running and since_stop >= self.cfg.hp_min_offtime_s:
            self.hp_running = True
            self.hp_since = self.now
        elif not want and self.hp_running and (since_start or 0) >= self.cfg.hp_min_runtime_s:
            self.hp_running = False
            self.hp_stopped_at = self.now
            self.hp_since = None

    def _buffer_step(self, dt_s: float, q_hp_th_kw: float, t_out: float) -> None:
        cfg = self.cfg.buffer
        layer_l = cfg.volume_liters / 4
        c_layer = layer_l * KWH_PER_L_K  # kWh/K
        dt_h = dt_s / 3600.0
        # Beladung von oben, Überschuss kaskadiert nach unten
        if q_hp_th_kw > 0:
            self.temps[0] += q_hp_th_kw * dt_h / c_layer
            cap = cfg.max_temperature_c + 1.0
            for i in range(3):
                if self.temps[i] > cap:
                    excess = (self.temps[i] - cap) * c_layer
                    self.temps[i] = cap
                    self.temps[i + 1] += excess / c_layer
            self.temps[3] = min(self.temps[3], cap)
        # Pelletofen (Fremdwärme) in die mittleren Schichten
        if self._pellet_kw_th > 0:
            self.temps[1] += 0.6 * self._pellet_kw_th * dt_h / c_layer
            self.temps[2] += 0.4 * self._pellet_kw_th * dt_h / c_layer
        # Entnahme als Kolbenströmung: Warmwasser (kaltes Nachfließen) und Heizkreis (Rücklauf)
        lt = self.local()
        h = lt.hour + lt.minute / 60
        dhw_kw = 0.12
        if 6.5 <= h < 7.5 or 18.5 <= h < 19.5:
            dhw_kw += 2.4
        elif 21.5 <= h < 22.0:
            dhw_kw += 1.6
        heat_kw = 0.0
        if t_out < self.cfg.heating_limit_c:
            heat_kw = self.cfg.house_heat_loss_kw_per_k * (self.cfg.indoor_target_c - t_out) * 0.6
        for e_kwh, t_in in (
            (dhw_kw * dt_h, self.cfg.cold_water_c),
            (heat_kw * dt_h, self.cfg.heating_return_c),
        ):
            if e_kwh <= 0:
                continue
            delta = max(3.0, self.temps[0] - t_in)
            frac = min(0.9, e_kwh / (c_layer * delta))
            old = list(self.temps)
            self.temps[0] = (1 - frac) * old[0] + frac * old[1]
            self.temps[1] = (1 - frac) * old[1] + frac * old[2]
            self.temps[2] = (1 - frac) * old[2] + frac * old[3]
            self.temps[3] = (1 - frac) * old[3] + frac * t_in
        # Verluste und leichte Wärmeleitung zwischen Schichten
        for i in range(4):
            self.temps[i] -= (
                (cfg.loss_kw_per_k / 4) * (self.temps[i] - self.cfg.ambient_c) * dt_h / c_layer
            )
        k = 0.03 * dt_h
        for i in range(3):
            d = (self.temps[i] - self.temps[i + 1]) * k
            self.temps[i] -= d
            self.temps[i + 1] += d
        # Inversionen mischen
        for i in range(3):
            if self.temps[i] < self.temps[i + 1]:
                m = (self.temps[i] + self.temps[i + 1]) / 2
                self.temps[i] = self.temps[i + 1] = m
        self.temps = [round(max(self.cfg.cold_water_c, t), 3) for t in self.temps]

    def _ev_step(self, dt_s: float, surplus_kw: float) -> None:
        lt = self.local()
        if self.ev_day != lt.date():
            self.ev_day = lt.date()
            self.ev_delivered_kwh = 0.0
        plugged = self._hash("evday", lt.date()) > 0.35 and 9.5 <= lt.hour + lt.minute / 60 < 15.0
        if not plugged or self.ev_delivered_kwh >= self.cfg.ev_need_kwh:
            self.ev_power_kw = 0.0
            return
        target = surplus_kw + self.ev_power_kw  # eigener Verbrauch zählt wieder als verfügbar
        if target >= self.cfg.ev_min_kw:
            self.ev_power_kw = round(min(self.cfg.ev_max_kw, target), 3)
        elif self.ev_power_kw > 0 and target >= self.cfg.ev_min_kw * 0.6:
            self.ev_power_kw = self.cfg.ev_min_kw
        else:
            self.ev_power_kw = 0.0
        self.ev_delivered_kwh += self.ev_power_kw * dt_s / 3600

    def step(self, dt_s: float) -> None:
        self.now = self.now + timedelta(seconds=dt_s)
        # TTLs
        if self.k1 and self.k1_until and self.now >= self.k1_until:
            self.k1 = False
        if self.k2 and self.k2_until and self.now >= self.k2_until:
            self.k2 = False
        for key, until in list(self.actuator_until.items()):
            if self.now >= until:
                self.actuators[key] = False
                del self.actuator_until[key]
        lt = self.local()
        # kleine Automatik im Haus: Terrassenlicht abends an
        h = lt.hour + lt.minute / 60
        if (
            20.0 <= h < 23.5
            and not self.actuators["terrace_light"]
            and "terrace_light" not in self.actuator_until
        ):
            self.actuators["terrace_light"] = self._hash("terr", lt.date()) > 0.3
        if h >= 23.5 or h < 6:
            self.actuators["terrace_light"] = False

        t_out = self.outdoor_temp_c(self.now)
        self._pellet_kw_th = (
            6.0
            if (t_out < 6.0 and 17 <= lt.hour < 21 and self._hash("pellet", lt.date()) > 0.5)
            else 0.0
        )

        self._hp_control(dt_s)
        cop = self._hp_cop(t_out)
        if self.hp_running:
            since = (self.now - self.hp_since).total_seconds() if self.hp_since else 60
            ramp = min(1.0, since / 90.0)
            self.hp_power_kw = round(
                self._hp_el(t_out) * ramp * (0.97 + 0.06 * self._hash("hpn", lt.minute)), 3
            )
        else:
            self.hp_power_kw = 0.0
        self._buffer_step(dt_s, self.hp_power_kw * cop, t_out)

        self._pv_kw = round(self.pv_actual_kw(self.now), 3)
        self._base_kw = self.base_load_kw(self.now)
        net = self._pv_kw - self._base_kw - self.hp_power_kw  # >0 Überschuss vor Batterie/EV
        # Batterie (Libbi): lädt Überschuss zuerst, entlädt bei Defizit
        cap = self.cfg.battery_kwh
        batt = 0.0
        if net > 0.05:
            room_kwh = max(0.0, (1.0 - self.battery_soc) * cap)
            charge = min(net, self.cfg.battery_max_kw, room_kwh / (dt_s / 3600) if dt_s else net)
            charge = max(0.0, charge)
            self.battery_soc = min(1.0, self.battery_soc + charge * 0.95 * dt_s / 3600 / cap)
            batt = -charge
            net -= charge
        elif net < -0.05 and self.battery_soc > self.cfg.battery_min_soc:
            avail_kwh = (self.battery_soc - self.cfg.battery_min_soc) * cap
            discharge = min(
                -net, self.cfg.battery_max_kw, avail_kwh / (dt_s / 3600) if dt_s else -net
            )
            discharge = max(0.0, discharge)
            self.battery_soc = max(0.0, self.battery_soc - discharge * dt_s / 3600 / cap)
            batt = discharge
            net += discharge
        self._battery_kw = round(batt, 3)
        # Wallbox nimmt, was nach der Batterie übrig ist
        self._ev_step(dt_s, max(0.0, net - self.ev_power_kw))
        net -= self.ev_power_kw
        self._grid_kw = round(-net, 3)  # positiv = Bezug

    # ------------------------------------------------------------------ Snapshot
    def _m(self, key: str, value: float, source: str, lag_s: float = 0.0) -> Measurement:
        at = self.now - timedelta(seconds=lag_s)
        fault = self._fault_for(key)
        if fault is not None:
            if fault is Quality.STALE:
                return Measurement(
                    value=value,
                    observed_at=at - timedelta(minutes=12),
                    quality=Quality.STALE,
                    source=source,
                )
            return Measurement.missing(fault, at, source)
        return Measurement.ok(round(value, 3), at, source)

    def snapshot(self) -> EnergySnapshot:
        now = self.now
        house = self._pv_kw + self._grid_kw + self._battery_kw
        return EnergySnapshot(
            timestamp=now,
            pv_power_kw=self._m("pv_power_kw", self._pv_kw, "demo:solaredge/modbus"),
            grid_power_kw=self._m("grid_power_kw", self._grid_kw, "demo:myenergi/harvi", lag_s=6),
            battery_power_kw=self._m(
                "battery_power_kw", self._battery_kw, "demo:myenergi/libbi", lag_s=6
            ),
            battery_soc=self._m("battery_soc", self.battery_soc, "demo:myenergi/libbi", lag_s=6),
            house_power_kw=Measurement.derived(round(house, 3), now),
            base_load_kw=Measurement.derived(
                round(max(0.0, house - self.hp_power_kw - self.ev_power_kw), 3), now
            ),
            heat_pump_power_kw=self._m("heat_pump_power_kw", self.hp_power_kw, "demo:shelly/3em"),
            ev_power_kw=self._m("ev_power_kw", self.ev_power_kw, "demo:myenergi/zappi", lag_s=6),
            electricity_price_ct_kwh=self._m(
                "electricity_price_ct_kwh", self.current_price(now), "demo:tibber"
            ),
            outdoor_temp_c=self._m("outdoor_temp_c", self.outdoor_temp_c(now), "demo:open-meteo"),
            buffer_temps_c=BufferTemperatures(
                top=self._m("buffer_temp_top_c", self.temps[0], "demo:shelly/temp:100"),
                mid_top=self._m("buffer_temp_mid_top_c", self.temps[1], "demo:shelly/temp:101"),
                mid_bottom=self._m(
                    "buffer_temp_mid_bottom_c", self.temps[2], "demo:shelly/temp:102"
                ),
                bottom=self._m("buffer_temp_bottom_c", self.temps[3], "demo:shelly/temp:103"),
            ),
            hp_release_contact=Measurement.ok(1.0 if self.k1 else 0.0, now, "demo:shelly/k1"),
            hp_block_contact=Measurement.ok(1.0 if self.k2 else 0.0, now, "demo:shelly/k2"),
            actuators={
                k: Measurement.ok(1.0 if v else 0.0, now, f"demo:shelly/{k}")
                for k, v in self.actuators.items()
            },
            balance_residual_kw=0.0,
        )


def new_demo_house(start: datetime | None = None, cfg: DemoConfig | None = None) -> DemoHouse:
    cfg = cfg or DemoConfig()
    start = start or datetime.now(UTC)
    return DemoHouse(cfg=cfg, now=start)
