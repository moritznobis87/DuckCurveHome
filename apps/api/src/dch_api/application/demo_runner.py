"""Demo-Runner: treibt Simulation, Tracker, Regler, Historie und Live-Stream.

Im Demo-Modus spielt der Runner drei Rollen zugleich, die im Live-Betrieb getrennt sind:
Geräteschicht (Simulation statt Shelly/MyEnergi), Worker (Regler-Ticks) und API-Ingest.
"""

from __future__ import annotations

import asyncio
import contextlib
from collections import deque
from datetime import UTC, date, datetime, time, timedelta
from typing import Any

import structlog

from dch_api.application.energy_accounting import EnergyAccounting
from dch_api.application.forecast_evaluation import ForecastEvaluator
from dch_api.application.ha_import import ImportResult
from dch_api.errors import DchError
from dch_api.infrastructure.history import HistoryStore
from dch_api.infrastructure.sse_broker import SseBroker
from dch_api.schemas import (
    EnergySummaryOut,
    EvReportOut,
    ForecastEvaluationOut,
    HeatReportOut,
    LiveStateOut,
    Period,
    PlanOut,
    SystemStatusOut,
)
from dch_api.settings import Settings
from hems_core.control import ControlInputs, HeatPumpController, HeatPumpTracker
from hems_core.domain import (
    AutoProfile,
    BufferState,
    Decision,
    EnergySnapshot,
    HeatPumpState,
    HemsConfig,
    OperatingMode,
    Override,
    OverrideKind,
    Quality,
    SystemMode,
)
from hems_core.planning import PricePoint, cheap_windows, next_window_after, price_rank
from hems_core.simulation import BERLIN, DemoConfig, DemoHouse, new_demo_house
from hems_core.thermal import compute_buffer_state

log = structlog.get_logger("demo")
VERSION = "0.1.0-phase1"


class DemoRunner:
    def __init__(self, settings: Settings, hems: HemsConfig | None = None) -> None:
        self.settings = settings
        self.hems = hems or HemsConfig()
        start = settings.demo_start or datetime.now(UTC)
        if start.tzinfo is None:
            start = start.replace(tzinfo=UTC)
        self.house: DemoHouse = new_demo_house(
            start - timedelta(hours=settings.demo_warmup_hours), DemoConfig(seed=settings.demo_seed)
        )
        self.tracker = HeatPumpTracker(self.hems.heat_pump)
        self.controller = HeatPumpController(self.hems)
        self.history = HistoryStore(timedelta(hours=settings.history_retention_hours))
        self.broker = SseBroker()
        self.mode = OperatingMode(system_mode=SystemMode.AUTO, auto_profile=AutoProfile.SMART)
        self.decisions: deque[Decision] = deque(maxlen=300)
        self.speed = settings.demo_speed
        self.snapshot: EnergySnapshot = self.house.snapshot()
        self.buffer: BufferState = compute_buffer_state(
            self.snapshot.buffer_temps_c, self.hems.buffer
        )
        self.hp: HeatPumpState = self.tracker.update(
            self.snapshot.heat_pump_power_kw, False, False, self.house.now
        )
        self.decision: Decision | None = None
        self.plan: PlanOut | None = None
        self._plan_at: datetime | None = None
        self._next_tick_at: datetime = self.house.now
        self._task: asyncio.Task[None] | None = None
        self._lock = asyncio.Lock()
        self._warming_up = False
        cfg = self.house.cfg
        self.evaluator = ForecastEvaluator(
            latitude=cfg.latitude,
            longitude=cfg.longitude,
            tz=BERLIN,
            source="demo_clear_sky_v1",
            source_label_de="Demo-Prognose (Klarhimmel × Tagesbewölkung)",
        )
        self._backfill_forecast_history(days=16)
        self.hems = self.hems.model_copy(
            update={
                "battery": self.hems.battery.model_copy(update={"capacity_kwh": cfg.battery_kwh})
            }
        )
        self.accounting = EnergyAccounting(
            self.hems, BERLIN, self._minute_rows, store=None, data_since=self._data_since
        )

    # ------------------------------------------------------------------ Zeit
    @property
    def now(self) -> datetime:
        return self.house.now

    # ------------------------------------------------------------------ Prognosebewertung
    def _backfill_forecast_history(self, days: int) -> None:
        """Vergangene Tage aus den (deterministischen) Simulationsfunktionen bewerten, damit die Detailseite
        im Demo sofort Lernhistorie zeigt. Day-ahead-Lauf um 05:30 Ortszeit, Ist als 15-min-Mittel."""
        first_local = self.house.now.astimezone(BERLIN).date()
        for offset in range(days, 0, -1):
            d: date = first_local - timedelta(days=offset)
            issued = datetime.combine(d, time(5, 30), tzinfo=BERLIN).astimezone(UTC)
            start, end = self.evaluator.day_bounds(d)
            slots = [
                start + timedelta(minutes=15 * i)
                for i in range(int((end - start) / timedelta(minutes=15)))
            ]
            self.evaluator.record_run(
                issued,
                [
                    (t, self.house.pv_expected_kw(t + timedelta(minutes=7, seconds=30)))
                    for t in slots
                ],
            )
            rows = [
                (t + timedelta(minutes=k), self.house.pv_actual_kw(t + timedelta(minutes=k)))
                for t in slots
                for k in (2, 7, 12)
            ]
            self.evaluator.close_day(d, rows)

    def _pv_rows(self, start: datetime, end: datetime) -> list[tuple[datetime, float | None]]:
        out: list[tuple[datetime, float | None]] = []
        for row in self.history.series(start, end):
            v = row.get("pv_power_kw")
            out.append(
                (datetime.fromisoformat(str(row["ts"])), v if isinstance(v, float) else None)
            )
        return out

    def _record_forecast_run(self, now: datetime) -> None:
        start = now - timedelta(hours=1)
        slots = [start + timedelta(minutes=15 * i) for i in range(37 * 4)]
        self.evaluator.record_run(
            now,
            [(t, self.house.pv_expected_kw(t + timedelta(minutes=7, seconds=30))) for t in slots],
        )
        for d in self.evaluator.days_to_close(now):
            s, e = self.evaluator.day_bounds(d)
            self.evaluator.close_day(d, self._pv_rows(s, e))

    async def _minute_rows(
        self, start: datetime, end: datetime
    ) -> list[dict[str, float | str | None]]:
        return self.history.series(start, end)

    async def _data_since(self) -> datetime | None:
        rows = self.history.series(self.now - timedelta(days=30), self.now)
        return datetime.fromisoformat(str(rows[0]["ts"])) if rows else None

    async def energy_summary(self, period: Period, anchor: date) -> EnergySummaryOut:
        return await self.accounting.summary(period, anchor, self.now)

    async def heat_report(self, period: Period, anchor: date) -> HeatReportOut:
        base = self.now.replace(minute=0, second=0, microsecond=0)
        temps = [
            (base + timedelta(hours=i), self.house.outdoor_temp_c(base + timedelta(hours=i)))
            for i in range(48)
        ]
        return await self.accounting.heat_report(period, anchor, self.now, temps)

    async def ev_report(self, period: Period, anchor: date) -> EvReportOut:
        return await self.accounting.ev_report(period, anchor, self.now)

    async def import_history(
        self, payload: bytes, kind: str, dry_run: bool, extra_map: dict[str, dict[str, Any]] | None
    ) -> ImportResult:
        raise DchError("not_supported", "Import nur im Live-Modus.", 400)

    async def forecast_evaluation(self) -> ForecastEvaluationOut:
        now = self.now
        today = now.astimezone(BERLIN).date()
        ts, te = self.evaluator.day_bounds(today)
        ys, ye = self.evaluator.day_bounds(today - timedelta(days=1))
        return self.evaluator.evaluation(now, self._pv_rows(ts, te), self._pv_rows(ys, ye))

    def warmup(self, hours: float) -> None:
        """Vorlauf im Zeitraffer, damit Historie und Regler-Zustand gefüllt sind."""
        total = int(hours * 3600)
        self._warming_up = True
        try:
            self.advance(total, step_s=30)
        finally:
            self._warming_up = False

    def advance(self, seconds: float, step_s: float = 10.0) -> None:
        remaining = float(seconds)
        while remaining > 1e-9:
            dt = min(step_s, remaining)
            self.house.step(dt)
            remaining -= dt
            self._after_step()

    def _after_step(self) -> None:
        snap = self.house.snapshot()
        self.snapshot = snap
        self.history.add(snap)
        self.hp = self.tracker.update(
            snap.heat_pump_power_kw, self.house.k1, self.house.k2, snap.timestamp
        )
        self.buffer = compute_buffer_state(snap.buffer_temps_c, self.hems.buffer)
        if snap.timestamp >= self._next_tick_at:
            self._next_tick_at = snap.timestamp + timedelta(seconds=self.settings.tick_s)
            self._control_tick(snap)
        self._refresh_plan_if_due(snap.timestamp)

    # ------------------------------------------------------------------ Regelung
    def _prices(self) -> list[PricePoint]:
        return self.house.prices_available(self.now)

    def _control_tick(self, snap: EnergySnapshot) -> None:
        prices = self._prices()
        rank = price_rank(prices, snap.timestamp)
        cheap = cheap_windows(
            prices, self.hems.control.price.cheap_quantile, self.hems.control.price.min_window_min
        )
        nxt = next_window_after(cheap, snap.timestamp)
        price_ok = snap.electricity_price_ct_kwh.usable
        inputs = ControlInputs(
            now=snap.timestamp,
            snapshot=snap,
            buffer=self.buffer,
            hp=self.hp,
            mode=self._effective_mode(snap.timestamp),
            price_rank=rank if price_ok else None,
            price_age_s=60.0 if price_ok else None,
            next_cheap_window_start=nxt.start if nxt else None,
            planned_release=False,
        )
        decision = self.controller.tick(inputs)
        self.decision = decision
        if decision.changed or not self.decisions:
            self.decisions.appendleft(decision)
            if not self._warming_up:
                log.info(
                    "decision",
                    state=decision.controller_state,
                    k1=decision.k1_release,
                    reasons=[r.value for r in decision.reasons],
                    text=decision.explanation_de,
                )
        # Aktor anwenden (Demo: direkt in der Simulation, mit Hardware-TTL wie im echten Betrieb)
        want_k1 = decision.k1_release and self.mode.system_mode is not SystemMode.OFF
        if want_k1 != self.house.k1 or want_k1:
            self.house.set_actuator(
                "hp_release_contact",
                want_k1,
                ttl_s=self.hems.heat_pump.hw_auto_off_release_s if want_k1 else None,
            )
        if self.house.k2 != decision.k2_block:
            self.house.set_actuator(
                "hp_block_contact", decision.k2_block, ttl_s=self.hems.heat_pump.hw_auto_off_block_s
            )
        self.broker.publish("decision", decision.model_dump(mode="json"))

    def _effective_mode(self, now: datetime) -> OperatingMode:
        ov = self.mode.override
        if ov is not None and not ov.active(now):
            self.mode = self.mode.model_copy(update={"override": None})
            if self.mode.system_mode is SystemMode.MANUAL:
                self.mode = self.mode.model_copy(update={"system_mode": SystemMode.AUTO})
        return self.mode

    def _refresh_plan_if_due(self, now: datetime) -> None:
        if (
            self._plan_at is None
            or now - self._plan_at >= timedelta(minutes=15)
            or self.plan is None
        ):
            from dch_api.application.plan_service import build_plan

            self._record_forecast_run(now)
            self.plan = build_plan(
                self.evaluator.pv_expected_corrected(self.house.pv_expected_kw),
                self._prices(),
                now,
                self.hems,
            )
            self._plan_at = now
            self.broker.publish("plan", self.plan.model_dump(mode="json"))

    # ------------------------------------------------------------------ Kommandos
    async def switch_actuator(
        self, key: str, state: bool, duration_min: int | None
    ) -> tuple[bool, bool | None, str | None]:
        if key in ("hp_release_contact", "hp_block_contact"):
            return False, None, "Wärmepumpen-Kontakte nur über den Betriebsmodus."
        ttl = duration_min * 60 if duration_min else None
        ok = self.house.set_actuator(key, state, ttl)
        observed = self.house.actuators.get(key)
        self._after_step_publish()
        return ok, observed, None if ok else "unbekannter Aktor"

    async def history_rows(
        self, start: datetime, end: datetime
    ) -> list[dict[str, float | str | None]]:
        return self.history.series(start, end)

    async def recent_decisions(self, limit: int) -> list[Decision]:
        return list(self.decisions)[:limit]

    async def set_heat_pump_mode(
        self,
        system_mode: SystemMode,
        profile: AutoProfile | None,
        manual_state: str | None,
        duration_min: int,
    ) -> OperatingMode:
        now = self.now
        override: Override | None = None
        if system_mode is SystemMode.MANUAL:
            kind = OverrideKind.FORCE_RELEASE if manual_state == "on" else OverrideKind.FORCE_OFF
            override = Override(
                kind=kind, started_at=now, ends_at=now + timedelta(minutes=duration_min)
            )
        self.mode = OperatingMode(
            system_mode=system_mode,
            auto_profile=profile or self.mode.auto_profile,
            override=override,
        )
        # sofort neu entscheiden
        self._next_tick_at = now
        self._control_tick(self.snapshot)
        self._after_step_publish()
        return self.mode

    def demo_control(
        self,
        speed: float | None,
        fault_key: str | None,
        fault_quality: str | None,
        fault_duration_s: int | None,
        scenario: str | None,
    ) -> None:
        if speed is not None:
            self.speed = speed
        if fault_key and fault_quality:
            self.house.inject_fault(fault_key, Quality(fault_quality), fault_duration_s or 300)
        if scenario == "reset":
            self.house.faults.clear()
        elif scenario == "sunny_surplus":
            self.house.temps = [48.0, 45.0, 40.0, 34.0]
            self.house.battery_soc = 1.0
        elif scenario == "buffer_full":
            self.house.temps = [61.5, 61.0, 60.0, 58.0]
        elif scenario == "cold_evening":
            self.house.temps = [43.0, 40.0, 36.0, 30.0]
        elif scenario == "sensor_outage":
            self.house.inject_fault("grid_power_kw", Quality.UNAVAILABLE, 600)
        self._after_step_publish()

    # ------------------------------------------------------------------ Ausgabe
    def _today_kwh(self) -> dict[str, float]:
        local = self.now.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0)
        start = local.astimezone(UTC)
        end = self.now + timedelta(minutes=1)
        h = self.history
        return {
            "pv_kwh": h.energy_kwh("pv_power_kw", start, end),
            "import_kwh": h.energy_kwh("grid_power_kw", start, end),
            "export_kwh": round(
                -h.energy_kwh("grid_power_kw", start, end, positive_only=False)
                + h.energy_kwh("grid_power_kw", start, end),
                3,
            ),
            "heat_pump_kwh": h.energy_kwh("heat_pump_power_kw", start, end),
            "ev_kwh": h.energy_kwh("ev_power_kw", start, end),
            "house_kwh": h.energy_kwh("house_power_kw", start, end),
        }

    def live_state(self) -> LiveStateOut:
        prices = self._prices()
        return LiveStateOut(
            snapshot=self.snapshot,
            buffer=self.buffer,
            heat_pump=self.hp,
            decision=self.decision,
            operating_mode=self._effective_mode(self.now),
            price_rank=price_rank(prices, self.now),
            today_kwh=self._today_kwh(),
            system=SystemStatusOut(
                mode=self.settings.mode,
                server_time=self.now,
                sim_speed=self.speed,
                bridge_online=True,
                sse_clients=self.broker.client_count,
                version=VERSION,
                connection_label_de="Demo-Modus" if self.settings.mode == "demo" else "live",
            ),
        )

    def _after_step_publish(self) -> None:
        self.snapshot = self.house.snapshot()  # Aktorzustände sofort sichtbar
        self.broker.publish("snapshot", self.live_state().model_dump(mode="json"))

    # ------------------------------------------------------------------ Laufzeit
    async def _loop(self) -> None:
        log.info("demo loop started", speed=self.speed, sim_time=self.now.isoformat())
        try:
            while True:
                await asyncio.sleep(1.0)
                async with self._lock:
                    if self.speed > 0:
                        self.advance(self.speed, step_s=min(10.0, self.speed))
                    self._after_step_publish()
        except asyncio.CancelledError:
            log.info("demo loop stopped")
            raise

    async def start(self) -> None:
        self.warmup(self.settings.demo_warmup_hours)
        self._after_step_publish()
        if self.settings.demo_autostart:
            self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._task
