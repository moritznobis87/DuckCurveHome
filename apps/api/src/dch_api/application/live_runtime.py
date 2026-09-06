"""Live-Runtime: Telemetrie der Bridge → LiveState + PostgreSQL; Regler-Tick; Planung; SSE.

Phase 2 ist „read-only“: Entscheidungen werden berechnet, gespeichert und angezeigt, aber erst mit
DCH_ACTUATION_ENABLED=true an die Bridge geschickt (Phase 3/4).
"""

from __future__ import annotations

import asyncio
import contextlib
from collections import deque
from datetime import UTC, date, datetime, timedelta
from typing import Any, cast

import structlog

from dch_api.application.config_loader import AppConfig
from dch_api.application.energy_accounting import ENERGY_KEYS, EnergyAccounting
from dch_api.application.forecast_evaluation import EvaluatorState, ForecastEvaluator
from dch_api.application.forecast_service import ForecastService
from dch_api.application.ha_import import HaImporter, ImportResult, Kind, load_entity_rules
from dch_api.application.myenergi_source import MyenergiSource, StatusClient
from dch_api.application.plan_service import build_plan
from dch_api.errors import DchError
from dch_api.infrastructure.bridge_hub import BridgeHub
from dch_api.infrastructure.db.repositories import SqlRepositories
from dch_api.infrastructure.history import SERIES
from dch_api.infrastructure.live_state import LiveState
from dch_api.infrastructure.sse_broker import SseBroker
from dch_api.schemas import (
    BackfillResultOut,
    EnergySummaryOut,
    EvReportOut,
    ForecastEvaluationOut,
    HeatReportOut,
    LiveStateOut,
    Period,
    PlanOut,
    SourceStatusOut,
    SystemEventOut,
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
    OperatingMode,
    Override,
    OverrideKind,
    Quality,
    SystemMode,
)
from hems_core.planning import cheap_windows, current_price, next_window_after, price_rank
from hems_core.protocol import DeviceHealthFrame, EventFrame, RawReading
from hems_core.simulation import BERLIN
from hems_core.thermal import compute_buffer_state

log = structlog.get_logger("live")
VERSION = "0.1.0-phase2"
HISTORY_KEYS = [k for k in SERIES if k != "hp_release_contact"] + ["actuator:hp_release_contact"]


class LiveRuntime:
    def __init__(
        self,
        settings: Settings,
        config: AppConfig,
        repos: SqlRepositories,
        hub: BridgeHub,
        forecasts: ForecastService,
        myenergi: StatusClient | None = None,
    ) -> None:
        self.settings = settings
        self.config = config
        self.hems = config.hems
        self.repos = repos
        self.hub = hub
        self.forecasts = forecasts
        self.broker = SseBroker()
        self.live = LiveState(self.hems)
        self.tracker = HeatPumpTracker(self.hems.heat_pump)
        self.controller = HeatPumpController(self.hems)
        self.mode = OperatingMode(system_mode=SystemMode.AUTO, auto_profile=AutoProfile.SMART)
        self.decision: Decision | None = None
        self.decisions: deque[Decision] = deque(maxlen=100)
        self.plan: PlanOut | None = None
        self._plan_at: datetime | None = None
        self._last_publish = 0.0
        self._last_price_stored: datetime | None = None
        self._tasks: list[asyncio.Task[None]] = []
        loc = config.site.location
        self.evaluator = ForecastEvaluator(
            latitude=loc.latitude,
            longitude=loc.longitude,
            tz=BERLIN,
            source="simple_clear_sky_v1",
            source_label_de="DCH-Prognose (Open-Meteo-Bewölkung × Klarhimmel)",
        )
        self.accounting = EnergyAccounting(
            self.hems,
            BERLIN,
            lambda s, e: repos.minute_series(s, e, ENERGY_KEYS),
            store=(repos.energy_hours, repos.upsert_energy_hours, repos.last_energy_hour),
            data_since=repos.first_measurement_at,
        )
        hub.on_telemetry = self.on_telemetry
        hub.on_event = self.on_bridge_event
        self.myenergi: MyenergiSource | None = None
        if myenergi is not None:
            self.myenergi = MyenergiSource(
                myenergi,
                self.on_source_readings,
                poll_s=settings.myenergi_poll_s,
                backfill_hours=settings.myenergi_backfill_hours,
                minute_rows=repos.minute_series,
                on_backfilled=self.accounting.recompute,
                on_state_change=self._on_source_state,
            )

    @property
    def now(self) -> datetime:
        return datetime.now(UTC)

    # ------------------------------------------------------------------ Eingang
    async def on_telemetry(self, items: list[RawReading], is_backlog: bool) -> None:
        await self.repos.add_readings(items)
        if is_backlog:
            return
        self.live.apply(items)
        loop_time = asyncio.get_running_loop().time()
        if loop_time - self._last_publish >= 1.0:
            self._last_publish = loop_time
            self.broker.publish("snapshot", self.live_state().model_dump(mode="json"))

    async def on_source_readings(self, items: list[RawReading]) -> None:
        """Messwerte einer serverseitigen Quelle (myenergi): speichern, Live-Zustand, Stream."""
        await self.repos.add_readings(items)
        self.live.apply(items)
        loop_time = asyncio.get_running_loop().time()
        if loop_time - self._last_publish >= 1.0:
            self._last_publish = loop_time
            self.broker.publish("snapshot", self.live_state().model_dump(mode="json"))

    async def _on_source_state(self, online: bool, error: str) -> None:
        await self.repos.add_event(
            "info" if online else "warning",
            "myenergi.connection",
            "myenergi erreichbar" if online else f"myenergi nicht erreichbar: {error}",
        )
        self.broker.publish("system", {"sources": self._sources()})

    def _sources(self) -> list[SourceStatusOut]:
        out = [
            SourceStatusOut(
                name="bridge",
                online=self.hub.online,
                detail_de="Home-Assistant-Bridge" if self.hub.online else "Bridge offline",
            )
        ]
        if self.myenergi is not None:
            out.append(SourceStatusOut(**self.myenergi.status_out()))
        return out

    async def on_bridge_event(self, frame: EventFrame | DeviceHealthFrame) -> None:
        if isinstance(frame, EventFrame):
            await self.repos.add_event(
                frame.severity, f"bridge.{frame.code}", frame.message, frame.context
            )
        else:
            await self.repos.add_event(
                "info" if frame.status == "ok" else "warning",
                "bridge.device_health",
                f"{frame.source}: {frame.status}",
                frame.details,
            )
        self.broker.publish(
            "system", {"bridge_online": self.hub.online, "health": frame.model_dump(mode="json")}
        )

    # ------------------------------------------------------------------ Regelung
    def _states(self) -> tuple[EnergySnapshot, BufferState, HeatPumpState]:
        snap = self.live.snapshot(self.now)
        hp = self.tracker.update(
            snap.heat_pump_power_kw,
            snap.hp_release_contact.value_or(0.0) >= 0.5,
            snap.hp_block_contact.value_or(0.0) >= 0.5,
            snap.timestamp,
        )
        return snap, compute_buffer_state(snap.buffer_temps_c, self.hems.buffer), hp

    async def _ingest_price(self) -> None:
        """Aktuellen Tibber-Preis als Messwert führen: so erscheint er im Live-Zustand und in der Historie
        (Preiskurve im Chart), ohne dass Home Assistant einen Preissensor liefern muss."""
        p = current_price(self.forecasts.prices, self.now)
        if p is None:
            return
        reading = RawReading(
            key="electricity_price_ct_kwh",
            value=round(p.ct_kwh, 3),
            observed_at=self.now,
            quality=Quality.OK,
            source="tibber:price",
        )
        self.live.apply([reading])
        if self._last_price_stored is None or self.now - self._last_price_stored >= timedelta(
            seconds=55
        ):
            self._last_price_stored = self.now
            await self.repos.add_readings([reading])

    async def control_tick(self) -> Decision:
        await self._ingest_price()
        snap, buffer, hp = self._states()
        now = snap.timestamp
        prices = self.forecasts.prices
        rank = price_rank(prices, now)
        cheap = cheap_windows(
            prices, self.hems.control.price.cheap_quantile, self.hems.control.price.min_window_min
        )
        nxt = next_window_after(cheap, now)
        planned = False
        if self.plan is not None:
            cur = next(
                (i for i in self.plan.intervals if i.ts <= now < i.ts + timedelta(minutes=15)), None
            )
            planned = cur is not None and cur.planned_hp_state == "release"
        inputs = ControlInputs(
            now=now,
            snapshot=snap,
            buffer=buffer,
            hp=hp,
            mode=self._effective_mode(now),
            price_rank=rank,
            price_age_s=self.forecasts.price_age_s(now),
            next_cheap_window_start=nxt.start if nxt else None,
            planned_release=planned,
        )
        decision = self.controller.tick(inputs)
        self.decision = decision
        if decision.changed:
            self.decisions.appendleft(decision)
            await self.repos.add_decision(decision)
            log.info(
                "decision",
                state=decision.controller_state,
                k1=decision.k1_release,
                text=decision.explanation_de,
            )
            self.broker.publish("decision", decision.model_dump(mode="json"))
            if self.settings.actuation_enabled:
                await self._apply_contacts(decision)
        return decision

    async def _apply_contacts(self, decision: Decision) -> None:
        if not self.hub.online:
            return
        result = await self.hub.send_command(
            "hp_release_contact",
            decision.k1_release,
            self.hems.heat_pump.hw_auto_off_release_s,
            decision.id,
        )
        if not result.ok:
            await self.repos.add_event(
                "warning", "actuator.failed", f"K1 → {decision.k1_release}: {result.error}", {}
            )

    def _effective_mode(self, now: datetime) -> OperatingMode:
        ov = self.mode.override
        if ov is not None and not ov.active(now):
            self.mode = OperatingMode(
                system_mode=SystemMode.AUTO, auto_profile=self.mode.auto_profile, override=None
            )
        return self.mode

    async def refresh_plan(self) -> None:
        now = self.now
        self.plan = build_plan(
            self.evaluator.pv_expected_corrected(self.forecasts.pv_expected_kw),
            self.forecasts.prices,
            now,
            self.hems,
        )
        self._plan_at = now
        self.broker.publish("plan", self.plan.model_dump(mode="json"))

    # ------------------------------------------------------------------ Kommandos (Dashboard)
    async def switch_actuator(
        self, key: str, state: bool, duration_min: int | None
    ) -> tuple[bool, bool | None, str | None]:
        if key in ("hp_release_contact", "hp_block_contact"):
            return False, None, "Wärmepumpen-Kontakte nur über den Betriebsmodus."
        if not self.settings.actuation_enabled:
            return False, None, "Steuerung ist in dieser Phase deaktiviert (nur lesen)."
        if not self.hub.online:
            return False, None, "Bridge nicht verbunden."
        result = await self.hub.send_command(
            key, state, duration_min * 60 if duration_min else None, None
        )
        return result.ok, result.observed_state, result.error

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
        await self.repos.save_mode(self.mode)
        await self.control_tick()
        self.broker.publish("snapshot", self.live_state().model_dump(mode="json"))
        return self.mode

    # ------------------------------------------------------------------ Ausgabe
    def live_state(self) -> LiveStateOut:
        snap, buffer, hp = self._states()
        now = snap.timestamp
        return LiveStateOut(
            snapshot=snap,
            buffer=buffer,
            heat_pump=hp,
            decision=self.decision,
            operating_mode=self._effective_mode(now),
            price_rank=price_rank(self.forecasts.prices, now),
            today_kwh={},
            system=SystemStatusOut(
                mode="live",
                server_time=now,
                sim_speed=1.0,
                bridge_online=self.hub.online,
                sse_clients=self.broker.client_count,
                version=VERSION,
                connection_label_de=self._connection_label(),
                sources=self._sources(),
            ),
        )

    def _connection_label(self) -> str:
        me = self.myenergi is not None and self.myenergi.online
        if self.hub.online and me:
            return "live"
        if self.hub.online:
            return "live" if self.myenergi is None else "live · myenergi offline"
        if me:
            return "live · Bridge offline"
        return "Bridge offline"

    async def history_rows(
        self, start: datetime, end: datetime
    ) -> list[dict[str, float | str | None]]:
        rows = await self.repos.minute_series(start, end, HISTORY_KEYS)
        for row in rows:  # Schlüsselname wie im Demo-Modus
            row["hp_release_contact"] = row.pop("actuator:hp_release_contact", None)
        return rows

    async def recent_decisions(self, limit: int) -> list[Decision]:
        if self.decisions:
            return list(self.decisions)[:limit]
        return await self.repos.recent_decisions(limit)

    # ------------------------------------------------------------------ Prognosebewertung
    CALIBRATION_MODEL = "pv_forecast_v1"

    async def _pv_rows(self, start: datetime, end: datetime) -> list[tuple[datetime, float | None]]:
        rows = await self.repos.minute_series(start, end, ["pv_power_kw"])
        out: list[tuple[datetime, float | None]] = []
        for row in rows:
            v = row.get("pv_power_kw")
            out.append(
                (datetime.fromisoformat(str(row["ts"])), v if isinstance(v, float) else None)
            )
        return out

    async def _record_forecast_run(self) -> None:
        pv = self.forecasts.pv
        if pv is None or not pv.points:
            return
        self.evaluator.record_run(pv.issued_at, [(p.ts, p.ac_kw) for p in pv.points], pv.provider)
        await self._close_forecast_days()
        await self._save_calibration()

    async def _close_forecast_days(self) -> None:
        closed = False
        for d in self.evaluator.days_to_close(self.now):
            s, e = self.evaluator.day_bounds(d)
            upd = self.evaluator.close_day(d, await self._pv_rows(s, e))
            if upd is not None:
                closed = True
                log.info("forecast day closed", day=d.isoformat(), mae_kw=upd.score.mae_kw)
        if closed:
            await self._save_calibration()

    async def _save_calibration(self) -> None:
        try:
            await self.repos.save_calibration(
                self.CALIBRATION_MODEL, self.evaluator.to_state().model_dump(mode="json")
            )
        except Exception as exc:
            log.warning("calibration save failed", error=repr(exc)[:200])

    async def _load_calibration(self) -> None:
        try:
            raw = await self.repos.load_calibration(self.CALIBRATION_MODEL)
            if raw:
                self.evaluator.load_state(EvaluatorState.model_validate(raw))
        except Exception as exc:
            log.warning("calibration load failed", error=repr(exc)[:200])

    # ------------------------------------------------------------------ Energiebilanz
    async def energy_summary(self, period: Period, anchor: date) -> EnergySummaryOut:
        return await self.accounting.summary(period, anchor, self.now)

    async def heat_report(self, period: Period, anchor: date) -> HeatReportOut:
        temps: list[tuple[datetime, float]] = []
        w = self.forecasts.weather
        if w is not None:
            temps = [
                (p.ts, p.temp_c)
                for p in w.points
                if p.temp_c is not None and p.ts >= self.now - timedelta(hours=1)
            ][:48]
        return await self.accounting.heat_report(period, anchor, self.now, temps)

    async def ev_report(self, period: Period, anchor: date) -> EvReportOut:
        return await self.accounting.ev_report(period, anchor, self.now)

    async def import_history(
        self, payload: bytes, kind: str, dry_run: bool, extra_map: dict[str, dict[str, Any]] | None
    ) -> ImportResult:
        rules = load_entity_rules(self.settings.import_entities_file, extra_map)
        if not rules:
            raise DchError(
                "config",
                f"Kein Entity-Mapping gefunden ({self.settings.import_entities_file}).",
                500,
            )
        prices = self.forecasts.prices
        importer = HaImporter(
            self.hems,
            rules,
            self.repos.energy_hours,
            self.repos.upsert_energy_hours,
            self.repos.add_readings,
            price_history=prices.fetch_range
            if prices is not None and hasattr(prices, "fetch_range")
            else None,
        )
        result = await importer.run(payload, cast(Kind, kind), dry_run)
        log.info("ha import", **result.model_dump(exclude={"entities", "unmapped"}, mode="json"))
        return result

    async def myenergi_backfill(self, hours: int) -> BackfillResultOut:
        if self.myenergi is None:
            raise DchError(
                "config", "myenergi ist nicht konfiguriert (DCH_MYENERGI_SERIAL/_API_KEY).", 400
            )
        now = self.now
        start = now - timedelta(hours=max(1, min(hours, 24 * 14)))
        end = now - timedelta(minutes=2)
        try:
            n = await self.myenergi.backfill(start, end)
        except Exception as exc:
            self.myenergi.last_backfill_error = repr(exc)[:200]
            return BackfillResultOut(ok=False, start=start, end=end, error_de=repr(exc)[:300])
        return BackfillResultOut(ok=True, readings=n, start=start, end=end)

    async def recent_events(self, limit: int) -> list[SystemEventOut]:
        rows = await self.repos.recent_events(limit)
        return [
            SystemEventOut(
                at=r.at if r.at.tzinfo else r.at.replace(tzinfo=UTC),
                severity=r.severity,
                code=r.code,
                message=r.message,
                context=dict(r.context or {}),
            )
            for r in rows
        ]

    async def _accounting_loop(self) -> None:
        while True:
            try:
                n = await self.accounting.refresh(self.now)
                log.info("energy hours refreshed", hours=n)
            except Exception as exc:
                log.warning("energy refresh failed", error=repr(exc)[:200])
            await asyncio.sleep(300)

    async def forecast_evaluation(self) -> ForecastEvaluationOut:
        now = self.now
        today = now.astimezone(BERLIN).date()
        ts, te = self.evaluator.day_bounds(today)
        ys, ye = self.evaluator.day_bounds(today - timedelta(days=1))
        return self.evaluator.evaluation(
            now, await self._pv_rows(ts, te), await self._pv_rows(ys, ye)
        )

    # ------------------------------------------------------------------ Laufzeit
    async def start(self) -> None:
        self.live.apply(await self.repos.latest())
        stored = await self.repos.load_mode()
        if stored is not None:
            self.mode = stored
        await self._load_calibration()
        await self.forecasts.refresh_prices(self.now)
        await self.forecasts.refresh_weather(self.now)
        await self._record_forecast_run()
        await self.refresh_plan()
        if self.settings.runs_worker:
            self._tasks = [
                asyncio.create_task(self._control_loop(), name="control"),
                asyncio.create_task(self._forecast_loop(), name="forecast"),
                asyncio.create_task(self._housekeeping_loop(), name="housekeeping"),
                asyncio.create_task(self._accounting_loop(), name="accounting"),
            ]
            if self.myenergi is not None:
                self.myenergi.start()
        log.info("live runtime started", actuation=self.settings.actuation_enabled)

    async def stop(self) -> None:
        if self.myenergi is not None:
            await self.myenergi.stop()
        for t in self._tasks:
            t.cancel()
        for t in self._tasks:
            with contextlib.suppress(asyncio.CancelledError):
                await t

    async def _control_loop(self) -> None:
        while True:
            await asyncio.sleep(self.settings.tick_s)
            try:
                await self.control_tick()
                if self._plan_at is None or self.now - self._plan_at >= timedelta(
                    minutes=self.settings.plan_refresh_min
                ):
                    await self.refresh_plan()
                self.broker.publish("snapshot", self.live_state().model_dump(mode="json"))
            except Exception as exc:
                log.error("control tick failed", error=repr(exc)[:300])

    async def _forecast_loop(self) -> None:
        last_weather = self.now
        last_prices = self.now
        while True:
            await asyncio.sleep(60)
            now = self.now
            local_h = now.astimezone(BERLIN).hour
            price_every = 30 if 13 <= local_h <= 15 else self.settings.price_refresh_min
            if now - last_prices >= timedelta(minutes=price_every):
                await self.forecasts.refresh_prices(now)
                last_prices = now
            if now - last_weather >= timedelta(minutes=self.settings.weather_refresh_min):
                await self.forecasts.refresh_weather(now)
                last_weather = now
                await self._record_forecast_run()
                await self.refresh_plan()
            else:
                await self._close_forecast_days()

    async def _housekeeping_loop(self) -> None:
        while True:
            await asyncio.sleep(3600)
            with contextlib.suppress(Exception):
                deleted = await self.repos.prune_raw(
                    timedelta(days=self.settings.raw_retention_days)
                )
                log.info("raw pruned", rows=deleted)
