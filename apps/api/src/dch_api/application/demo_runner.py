"""Demo-Runner: treibt Simulation, Tracker, Regler, Historie und Live-Stream.

Im Demo-Modus spielt der Runner drei Rollen zugleich, die im Live-Betrieb getrennt sind:
Geräteschicht (Simulation statt Shelly/MyEnergi), Worker (Regler-Ticks) und API-Ingest.
"""

from __future__ import annotations

import asyncio
import contextlib
from collections import deque
from collections.abc import AsyncIterator, Callable
from datetime import UTC, date, datetime, time, timedelta
from time import monotonic
from typing import Any

import structlog

from dch_api import urheber
from dch_api.application import anlage as anlage_logic
from dch_api.application import anlage_replay, demo_house, demo_rooms, rooms
from dch_api.application import kennlinie as kennlinie_logic
from dch_api.application import kontaktwirkung as kontaktwirkung_logic
from dch_api.application import morgenbrief as brief_modul
from dch_api.application import nachbetrachtung as nachbetrachtung_logic
from dch_api.application import reglerkennzahl as kennzahl_logic
from dch_api.application import waermepumpe as wp_logic
from dch_api.application.battery_control import BatteryMode
from dch_api.application.demo_archive import DemoArchiv
from dch_api.application.energy_accounting import EnergyAccounting
from dch_api.application.forecast_evaluation import ForecastEvaluator
from dch_api.application.forecast_history import forecast_history
from dch_api.application.ha_import import ImportResult
from dch_api.application.invoice_service import InvoiceService
from dch_api.application.live_feed import Takt
from dch_api.application.plan_service import (
    Istpunkt,
    ablage_faellig,
    ist_nachschlag,
    plan_als_lauf,
)
from dch_api.application.room_automatik import (
    AutomatikConfig,
    RaumZustand,
    Stellen,
    Zurueckziehen,
    entscheide,
)
from dch_api.application.stove_control import StoveMode
from dch_api.application.stove_planner import StovePlan
from dch_api.application.tibber_invoice import MeasuredPeriod
from dch_api.errors import DchError
from dch_api.infrastructure.history import HistoryStore
from dch_api.infrastructure.sse_broker import SseBroker
from dch_api.schemas import (
    AlarmOut,
    AnlageOut,
    AnlageReplayOut,
    BackfillResultOut,
    BatteryLiveOut,
    EnergySummaryOut,
    EvReportOut,
    ForecastEvaluationOut,
    ForecastHistoryOut,
    HeatBalanceOut,
    HeatConfigIn,
    HeatReportOut,
    HouseContactOut,
    HouseOut,
    InvoiceReportOut,
    InvoiceSummaryOut,
    KennlinieOut,
    KontaktwirkungOut,
    LiveStateOut,
    MorgenbriefOut,
    NachbetrachtungOut,
    Period,
    PlanOut,
    PvTaxReportOut,
    ReglerKennzahlenOut,
    RoomEffectOut,
    RoomHistoryOut,
    RoomLiveOut,
    RoomLogEntryOut,
    RoomLogOut,
    RoomSeriesOut,
    RoomShiftEventOut,
    RoomShiftIn,
    RoomShiftOut,
    RoomShiftRoomOut,
    RoomsLiveOut,
    ShiftReportOut,
    StoveLiveOut,
    SystemEventOut,
    SystemStatusOut,
    WaermepumpeOut,
    YearMapOut,
)
from dch_api.settings import Settings
from hems_core.accounting import summarize
from hems_core.control import ControlInputs, HeatPumpController, HeatPumpTracker
from hems_core.domain import (
    AutoProfile,
    BufferState,
    Decision,
    EnergySnapshot,
    HeatPumpState,
    HemsConfig,
    Measurement,
    OperatingMode,
    Override,
    OverrideKind,
    Quality,
    SystemMode,
    apply_heat_patch,
)
from hems_core.forecasting import Lauf, stand_vor
from hems_core.planning import (
    OptimizerConfig,
    PricePoint,
    cheap_windows,
    expensive_windows,
    next_window_after,
    price_rank,
)
from hems_core.simulation import BERLIN, DemoConfig, DemoHouse, new_demo_house
from hems_core.thermal import RoomMinute, compute_buffer_state, room_shift
from hems_core.thermal.shift_plan import AUS, ShiftTarget, shift_target

log = structlog.get_logger("demo")

# Wie oft die Vorführung den Optimierer höchstens laufen lässt, in echten Sekunden.
DEMO_SOLVE_S = 30.0


class _UebersprungenError(Exception):
    """Kein Fehler: der Fahrplan ist noch frisch genug, es wird nicht neu gerechnet."""


VERSION = "0.1.0-phase1"


class DemoRunner:
    def __init__(self, settings: Settings, hems: HemsConfig | None = None) -> None:
        self.settings = settings
        # Der Eigenverbrauch des Wechselrichters ist in der Vorfuehrung aus. Das Haus hat ihn
        # gemessen (siehe BatteryConfig.inverter_idle_kw), das simulierte Speichermodell kennt ihn
        # aber nicht: Es laedt verlustfrei in den Ladestand. Ihn hier trotzdem abzuziehen hiesse,
        # der Vorfuehrung einen Verbrauch anzudichten, den ihre eigene Physik nicht hat - und die
        # Gegenprobe aus dem Ladestand widerspraeche der Ladung auf derselben Seite.
        grund = hems or HemsConfig()
        self.hems = grund.model_copy(
            update={"battery": grund.battery.model_copy(update={"inverter_idle_kw": 0.0})}
        )
        start = settings.demo_start or datetime.now(UTC)
        if start.tzinfo is None:
            start = start.replace(tzinfo=UTC)
        self.house: DemoHouse = new_demo_house(
            start - timedelta(hours=settings.demo_warmup_hours), DemoConfig(seed=settings.demo_seed)
        )
        self.tracker = HeatPumpTracker(self.hems.heat_pump)
        self.controller = HeatPumpController(self.hems)
        self.history = HistoryStore(timedelta(hours=settings.history_retention_hours))
        # Von Hand gestellte Sollwerte der Vorfuehrung, Raum auf Grad.
        self._room_setpoints: dict[int, float] = {}
        # Das Raumprotokoll der Vorführung. Die echte Laufzeit liest es aus Messreihe und
        # Ereignissen zusammen; hier wird es mitgeschrieben, weil die Vorführung keine Datenbank
        # hat. Gezeigt wird dasselbe, erzeugt wird es anders - und nur der Fall „extern" fehlt,
        # weil in einer Vorführung niemand an der Wand dreht.
        self._room_log: dict[int, list[RoomLogEntryOut]] = {}
        # Die Raumautomatik der Vorfuehrung: dieselbe Entscheidung, derselbe Schutz, nur ohne
        # Datenbank. Eine Vorfuehrung, in der ein Schalter nichts tut, zeigt die Form und
        # verschweigt die Sache.
        self.shift_cfg = AutomatikConfig()
        self._shift_states: dict[int, RaumZustand] = {}
        self._shift_log: deque[tuple[datetime, str]] = deque(maxlen=20)
        self._shift_at: datetime | None = None
        self.shift_target: ShiftTarget = AUS
        # Die Alarmanlage der Vorfuehrung: unscharf, bis jemand drueckt.
        self._alarm: float = 0.0
        self.broker = SseBroker()
        # Derselbe Takt wie im Live-Betrieb: Die Vorfuehrung soll nicht billiger aussehen,
        # als der echte Betrieb ist.
        self._takt = Takt(settings.live_push_min_s, settings.live_push_max_s)
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
        #: In der Vorführung gibt es keinen Zeitplan, nur den Schalter und die Vorschau.
        self._brief_an: bool = True
        self.stove_plan: StovePlan = StovePlan()
        self._stove_solve_at = 0.0  # monotone Echtzeit des letzten Solverlaufs
        self._plan_at: datetime | None = None
        # Das Fahrplan-Gedächtnis der Vorführung. Im Haus liegen die Läufe in `forecast_runs`;
        # hier gibt es keine Datenbank, also eine begrenzte Schlange. 96 Läufe sind vier Tage bei
        # stündlicher Ablage - mehr, als die Minutenhistorie der Vorführung ohnehin hält.
        self._plan_abgelegt: datetime | None = None
        self._plan_laeufe: deque[Lauf] = deque(maxlen=96)
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
            self.hems,
            BERLIN,
            self._minute_rows,
            store=None,
            data_since=self._data_since,
            room_rows=self._vent_rows,
        )
        # Rechnungen liegen im Demo-Modus nur im Speicher - zum Ausprobieren der Seite ohne Datenbank
        self._invoices: dict[str, InvoiceReportOut] = {}
        self.invoice_service = InvoiceService(
            BERLIN,
            load_all=self._load_invoices,
            save=self._save_invoice,
            measure=self._measure_period,
        )

    async def _load_invoices(self) -> list[InvoiceReportOut]:
        return list(self._invoices.values())

    async def _save_invoice(
        self, report: InvoiceReportOut, sha256: str, file_name: str | None
    ) -> None:
        self._invoices[report.invoice.number] = report

    async def _measure_period(self, start: datetime, end: datetime) -> MeasuredPeriod:
        """Netzbezug, Datenabdeckung und bezugsgewichteter Preis eines Abrechnungszeitraums."""
        hours = await self.accounting.hours(start, end)
        totals = summarize(h for h, _ in hours)
        minutes = (end - start).total_seconds() / 60.0
        return MeasuredPeriod(
            import_kwh=round(totals.import_kwh, 2),
            coverage=round(min(1.0, totals.minutes / minutes), 3) if minutes > 0 else None,
            avg_price_ct_kwh=totals.avg_import_price_ct,
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

    def _ist_nachschlag(self, now: datetime) -> Callable[[datetime], Istpunkt | None]:
        """Dieselbe Verdichtung wie im Livebetrieb, nur aus der Historie im Arbeitsspeicher."""
        start = now.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0)
        return ist_nachschlag(
            self.history.series(start.astimezone(UTC), now),
            now,
            laeuft_ab_kw=self.hems.heat_pump.running_threshold_kw,
        )

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

    async def shift_report(self, period: Period, anchor: date) -> ShiftReportOut:
        return await self.accounting.shift_report(period, anchor, self.now)

    async def heat_report(self, period: Period, anchor: date) -> HeatReportOut:
        base = self.now.replace(minute=0, second=0, microsecond=0)
        temps = [
            (base + timedelta(hours=i), self.house.outdoor_temp_c(base + timedelta(hours=i)))
            for i in range(48)
        ]
        return await self.accounting.heat_report(period, anchor, self.now, temps)

    async def heat_balance(self, period: Period, anchor: date) -> HeatBalanceOut:
        base = self.now.replace(minute=0, second=0, microsecond=0)
        temps = [
            (base + timedelta(hours=i), self.house.outdoor_temp_c(base + timedelta(hours=i)))
            for i in range(48)
        ]
        return await self.accounting.heat_balance(period, anchor, self.now, temps)

    async def update_heat_config(self, patch: HeatConfigIn) -> HemsConfig:
        """Im Demo-Betrieb wirkt die Änderung, überlebt aber keinen Neustart: nichts wird gespeichert.

        **Zwei Sperren, beide müssen fallen.** `_plan_at` macht den Fahrplan fällig, und das reicht
        hier nicht: der Ofenlauf hat seine eigene Drossel von DEMO_SOLVE_S echten Sekunden. Ohne
        den zweiten Griff würde der Plan neu gebaut, aber mit dem Ofenfahrplan von vorher - also
        gerade die Zahl, die der geänderte Pelletpreis verschiebt, bliebe stehen.
        """
        try:
            neu = apply_heat_patch(self.hems, patch.model_dump(exclude_none=True))
        except ValueError as exc:
            raise DchError("invalid_config", str(exc), 422) from exc
        self.hems = neu
        self.accounting.hems = neu
        self._plan_at = None
        self._stove_solve_at = monotonic() - DEMO_SOLVE_S
        return neu

    async def ev_report(self, period: Period, anchor: date) -> EvReportOut:
        return await self.accounting.ev_report(period, anchor, self.now)

    async def pv_report(self, period: Period, anchor: date) -> PvTaxReportOut:
        return await self.accounting.pv_report(period, anchor, self.now)

    async def year_map(self, year: int) -> YearMapOut:
        return await self.accounting.year_map(year, self.now)

    async def diagnose_day(self, day: date) -> str:
        return await self.accounting.diagnose_day(day)

    def battery_state(self) -> BatteryLiveOut:
        return BatteryLiveOut(note_de="Demo-Modus: kein Speicher zum Schalten.")

    async def speicher_check(self, period: Period, anchor: date) -> str:
        return await self.accounting.speicher_check(period, anchor)

    async def set_battery_mode(
        self, mode: BatteryMode, duration_min: int, reserve_soc: float | None
    ) -> BatteryLiveOut:
        raise DchError("demo_mode", "Im Demo-Modus wird nichts geschaltet.", 409)

    async def import_history(
        self,
        payload: bytes,
        kind: str,
        dry_run: bool,
        extra_map: dict[str, dict[str, Any]] | None,
        replace_until: datetime | None = None,
    ) -> ImportResult:
        raise DchError("not_supported", "Import nur im Live-Modus.", 400)

    async def myenergi_backfill(
        self, hours: int, start: datetime | None = None, end: datetime | None = None
    ) -> BackfillResultOut:
        raise DchError("not_supported", "myenergi nur im Live-Modus.", 400)

    def export_csv(self, kind: str, start: datetime, end: datetime) -> AsyncIterator[str]:
        raise DchError("not_supported", "Export nur im Live-Modus.", 400)

    async def recent_events(self, limit: int) -> list[SystemEventOut]:
        return []

    async def check_invoice(self, payload: bytes, file_name: str | None) -> InvoiceReportOut:
        return await self.invoice_service.check(payload, file_name)

    async def invoices(self) -> list[InvoiceSummaryOut]:
        return await self.invoice_service.history()

    async def invoice(self, number: str) -> InvoiceReportOut | None:
        return await self.invoice_service.detail(number)

    async def forecast_history(self, tage: int) -> ForecastHistoryOut:
        """Der Rückblick im Demobetrieb, aus einem gerechneten Archiv.

        Die Demo hat keine Datenbank; `DemoArchiv` leitet die Läufe aus den Kurven des Demohauses
        ab und legt einen Fehler darauf, der mit dem Vorlauf wächst. Das zeigt die Seite, es
        bewertet nichts.
        """
        archiv = DemoArchiv(
            self.house.pv_expected_kw,
            self.house.outdoor_temp_c,
            lambda start, end, keys: self.history.series(start, end),
        )
        out = await forecast_history(archiv, self.now, self.hems, BERLIN, tage=tage)
        return out.model_copy(
            update={
                "hinweise_de": [
                    "Demobetrieb: die Läufe sind gerechnet, nicht abgelegt. Der Fehler wächst mit "
                    "der Wurzel des Vorlaufs nach einer festen Formel - er zeigt die Seite und "
                    "nicht die Güte einer Prognose.",
                    *out.hinweise_de,
                ]
            }
        )

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
        geplant = None
        if self.plan is not None:
            cur = next(
                (
                    i
                    for i in self.plan.intervals
                    if i.ts <= snap.timestamp < i.ts + timedelta(minutes=15)
                ),
                None,
            )
            geplant = cur.planned_hp_state if cur else None
        inputs = ControlInputs(
            now=snap.timestamp,
            snapshot=snap,
            buffer=self.buffer,
            hp=self.hp,
            mode=self._effective_mode(snap.timestamp),
            price_rank=rank if price_ok else None,
            price_age_s=60.0 if price_ok else None,
            next_cheap_window_start=nxt.start if nxt else None,
            # Die Vorführung liest denselben Fahrplan wie der Betrieb. Fest verdrahtete `False`
            # hießen: das neue Verhalten ist genau dort nicht zu sehen, wo man es zeigt.
            planned_release=geplant == "release",
            planned_off=geplant == "off",
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
            from dch_api.application.stove_planner import plan_stove

            self._record_forecast_run(now)
            # Der Optimierer läuft auch in der Vorführung, und das ist kein Beiwerk: er führt
            # inzwischen die Wärmepumpe. Eine Vorführung, die ihn auslässt, zeigt genau das
            # nicht, was zu sehen sein soll, und sie zeigt es dann wie eine Entscheidung für die
            # Faustregel.
            #
            # **Zwei Zügel, beide nötig.** Dieser Pfad läuft bei jedem Simulationsschritt, und die
            # Schritte eilen: beim Nachholen der Historie vergehen Stunden in Sekunden. Ohne Zügel
            # solvte er hunderte Male und blockierte dabei die Ereignisschleife, denn anders als in
            # der Laufzeit gibt es hier keinen eigenen Thread - der Dienst kam schlicht nicht hoch.
            # Also höchstens alle DEMO_SOLVE_S **echte** Sekunden, und mit kurzer Zeitgrenze. Eine
            # Sekunde Rechenzeit reicht für eine Vorführung; im Haus gilt die Betriebsgrenze.
            basis = now.replace(minute=0, second=0, microsecond=0)
            echt = monotonic()
            try:
                if echt - self._stove_solve_at < DEMO_SOLVE_S and self.stove_plan.start is not None:
                    raise _UebersprungenError
                self._stove_solve_at = echt
                self.stove_plan = plan_stove(
                    now=now,
                    tz=BERLIN,
                    cfg=self.hems,
                    prices=self._prices(),
                    pv_expected=self.evaluator.pv_expected_corrected(self.house.pv_expected_kw),
                    temps=[
                        (
                            basis + timedelta(hours=i),
                            self.house.outdoor_temp_c(basis + timedelta(hours=i)),
                        )
                        for i in range(48)
                    ],
                    buffer=self.buffer,
                    hp_running=self.hp.running,
                    stove_running=False,
                    opt_cfg=OptimizerConfig(step_min=15, time_limit_s=1.0),
                )
            except _UebersprungenError:
                pass  # der vorige Fahrplan gilt weiter, `hp_on_at` verfällt von selbst
            except Exception as exc:
                log.warning("demo stove plan failed", error=str(exc))
                self.stove_plan = StovePlan(note_de=f"Fahrplan nicht gerechnet: {exc}")
            self.plan = build_plan(
                self.evaluator.pv_expected_corrected(self.house.pv_expected_kw),
                self._prices(),
                now,
                self.hems,
                stove_on=self.stove_plan.on_at,
                hp_on=self.stove_plan.hp_on_at,
                twin=self.stove_plan.twin_at,
                ist=self._ist_nachschlag(now),
                buffer_capacity_kwh=self.stove_plan.buffer_capacity_kwh,
                buffer_min_kwh=self.stove_plan.buffer_min_kwh,
                planner_status=self.stove_plan.status,
                planner_note_de=self.stove_plan.note_de,
                planner_warn_de=self.stove_plan.warnung_de(),
                # Im Vorführhaus kommt die Entscheidung am Kontakt an, siehe `live_state`.
                hp_actuation=True,
            )
            if ablage_faellig(self._plan_abgelegt, now):
                lauf = plan_als_lauf(self.plan, now)
                if lauf is not None:
                    self._plan_laeufe.append(lauf)
                self._plan_abgelegt = now
            self._plan_at = now
            self.broker.publish("plan", self.plan.model_dump(mode="json"))

    # ------------------------------------------------------------------ Kommandos
    async def switch_actuator(
        self, key: str, state: bool, duration_min: int | None
    ) -> tuple[bool, bool | None, str | None]:
        if key in ("hp_release_contact", "hp_block_contact"):
            return False, None, "Die Wärmepumpe lässt sich nur über den Betriebsmodus anfordern."
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

    # ------------------------------------------------------------------ Einzelraumregelung
    async def _vent_rows(
        self, start: datetime, end: datetime
    ) -> tuple[list[RoomMinute], dict[int, int], dict[int, str]]:
        """Ventil und Fenster der Vorfuehrungsraeume, Minute fuer Minute aus demselben Modell."""
        out: list[RoomMinute] = []
        schritt = timedelta(minutes=1)
        at = start
        while at < end:
            for r in demo_rooms.ROOMS:
                out.append(
                    RoomMinute(
                        at=at,
                        room_id=r.id,
                        valve=demo_rooms.valve(r, at),
                        window=demo_rooms.window(r, at),
                    )
                )
            at += schritt
        return (
            out,
            {r.id: r.circuits for r in demo_rooms.ROOMS},
            {r.id: r.name for r in demo_rooms.ROOMS},
        )

    # ------------------------------------------------------------------ Raumautomatik
    def _shift_preise(self) -> list[PricePoint]:
        """Die Preisreihe der Vorfuehrung als Punkte, so wie sie der Betrieb kennt."""
        iv = self.plan.intervals if self.plan else []
        return [
            PricePoint(start=i.ts, end=i.ts + timedelta(minutes=15), ct_kwh=i.price_ct_kwh)
            for i in iv
            if i.price_ct_kwh is not None
        ]

    def _shift_soll(self, room_id: int) -> float | None:
        raum = next((r for r in demo_rooms.ROOMS if r.id == room_id), None)
        if raum is None:
            return None
        return self._room_setpoints.get(room_id, raum.setpoint_c)

    def _shift_tick(self) -> None:
        """Dieselbe Entscheidung wie im Betrieb, nur im Arbeitsspeicher gestellt."""
        now = self.now
        if self._shift_at is not None and (now - self._shift_at).total_seconds() < 60:
            return
        self._shift_at = now
        cfg = self.shift_cfg
        preise = self._shift_preise()
        self.shift_target = (
            shift_target(
                now,
                preise,
                expensive_windows(preise, self.hems.control.price.expensive_quantile, 60),
                cfg.policy(),
            )
            if cfg.enabled
            else AUS
        )
        raeume = (
            sorted(set(cfg.rooms) | set(self._shift_states))
            if cfg.enabled
            else sorted(self._shift_states)
        )
        for rid in raeume:
            dabei = cfg.enabled and rid in cfg.rooms
            gemessen = self._shift_soll(rid)
            aktion = entscheide(
                now=now,
                ziel_offset_k=self.shift_target.offset_k if dabei else 0.0,
                grund=self.shift_target.reason_de if dabei else "nicht mehr in der Automatik",
                gemessen_c=gemessen,
                gemessen_at=now,
                fenster_offen=bool(
                    (lambda r: r is not None and (demo_rooms.window(r, now) or 0.0) >= 0.5)(
                        next((x for x in demo_rooms.ROOMS if x.id == rid), None)
                    )
                ),
                zustand=self._shift_states.get(rid),
            )
            if isinstance(aktion, Zurueckziehen):
                vorher = self._shift_states.get(rid)
                if aktion.ruhe_bis is not None and vorher is not None:
                    self._shift_states[rid] = RaumZustand(
                        base_setpoint_c=vorher.base_setpoint_c,
                        offset_k=0.0,
                        written_setpoint_c=vorher.written_setpoint_c,
                        written_at=vorher.written_at,
                        paused_until=aktion.ruhe_bis,
                    )
                    self._shift_log.appendleft((now, f"Raum {rid}: {aktion.grund}"))
                    self._room_log.setdefault(rid, []).append(
                        RoomLogEntryOut(
                            at=now,
                            quelle="automatik",
                            art="ruhe",
                            text=aktion.grund,
                            urheber=urheber.AUTOMATIK.text(),
                        )
                    )
                else:
                    self._shift_states.pop(rid, None)
            elif isinstance(aktion, Stellen):
                self._shift_states[rid] = RaumZustand(
                    base_setpoint_c=aktion.base_c,
                    offset_k=aktion.offset_k,
                    written_setpoint_c=aktion.setpoint_c,
                    written_at=now,
                    paused_until=None,
                )
                self._room_setpoints[rid] = aktion.setpoint_c
                name = next((r.name for r in demo_rooms.ROOMS if r.id == rid), str(rid))
                vorher_wert = f"{gemessen:.1f}".replace(".", ",") if gemessen is not None else "-"
                neuer_wert = f"{aktion.setpoint_c:.1f}".replace(".", ",")
                self._shift_log.appendleft(
                    (now, f"{name}: Sollwert {vorher_wert} auf {neuer_wert} ({aktion.grund})")
                )
                self._room_log.setdefault(rid, []).append(
                    RoomLogEntryOut(
                        at=now,
                        quelle="automatik",
                        art="sollwert",
                        from_c=gemessen,
                        to_c=aktion.setpoint_c,
                        text=f"{name}: Sollwert {vorher_wert} auf {neuer_wert} ({aktion.grund})",
                        urheber=urheber.AUTOMATIK.text(),
                    )
                )

    async def morgenbrief(self) -> MorgenbriefOut:
        return brief_modul.vorschau(self._brief_an, self.plan, self.now, BERLIN)

    async def set_morgenbrief(self, enabled: bool) -> MorgenbriefOut:
        self._brief_an = enabled
        return await self.morgenbrief()

    async def rooms_automatik(self) -> RoomShiftOut:
        self._shift_tick()
        ziel = self.shift_target
        return RoomShiftOut(
            enabled=self.shift_cfg.enabled,
            rooms=list(self.shift_cfg.rooms),
            delta_k=self.shift_cfg.delta_k,
            draw_k=self.shift_cfg.draw_k,
            lead_h=self.shift_cfg.lead_h,
            min_spread_ct=self.shift_cfg.min_spread_ct,
            phase=ziel.phase,
            offset_k=ziel.offset_k,
            until=ziel.until,
            window_start=ziel.window_start,
            window_end=ziel.window_end,
            spread_ct=ziel.spread_ct,
            reason_de=ziel.reason_de,
            active=[
                RoomShiftRoomOut(
                    room_id=rid,
                    name=next((r.name for r in demo_rooms.ROOMS if r.id == rid), str(rid)),
                    base_setpoint_c=z.base_setpoint_c,
                    offset_k=z.offset_k,
                    written_setpoint_c=z.written_setpoint_c,
                    written_at=z.written_at,
                    paused_until=z.paused_until,
                )
                for rid, z in sorted(self._shift_states.items())
            ],
            log=[RoomShiftEventOut(at=at, text_de=t) for at, t in self._shift_log],
            note_de="",
        )

    async def set_rooms_automatik(self, patch: RoomShiftIn) -> RoomShiftOut:
        werte = self.shift_cfg.payload()
        werte.update(patch.model_dump(exclude_none=True))
        neu = AutomatikConfig.from_payload(werte)
        bekannt = {r.id for r in demo_rooms.ROOMS}
        unbekannt = [r for r in neu.rooms if r not in bekannt]
        if unbekannt:
            raise DchError(
                "unknown_room", f"Unbekannte Räume: {', '.join(str(r) for r in unbekannt)}.", 422
            )
        self.shift_cfg = neu
        self._shift_at = None
        return await self.rooms_automatik()

    async def set_room_setpoint(self, room_id: int, setpoint_c: float) -> tuple[bool, float, str]:
        """In der Vorfuehrung wird wirklich gestellt - nur eben im Arbeitsspeicher.

        Eine Vorfuehrung, in der ein Knopf nichts tut, ist schlimmer als keine: Sie zeigt die Form
        und verschweigt, ob die Sache funktioniert. Der gesetzte Wert ueberschreibt den der
        Raumliste, bis der Dienst neu startet.
        """
        werte = rooms.runde_soll(setpoint_c)
        raum = next((r for r in demo_rooms.ROOMS if r.id == room_id), None)
        if raum is None:
            raise DchError("unknown_room", f"Raum {room_id} ist nicht bekannt.", 404)
        if not (rooms.SOLL_MIN <= werte <= rooms.SOLL_MAX):
            raise DchError(
                "invalid_setpoint",
                f"Sollwert muss zwischen {rooms.SOLL_MIN:.0f} und {rooms.SOLL_MAX:.0f} Grad liegen.",
                422,
            )
        vorher = self._room_setpoints.get(room_id, raum.setpoint_c)
        self._room_setpoints[room_id] = werte
        self._room_log.setdefault(room_id, []).append(
            RoomLogEntryOut(
                at=self.now,
                quelle="app",
                art="sollwert",
                from_c=vorher,
                to_c=werte,
                text=f"{raum.name}: Sollwert auf {werte:.1f} Grad gestellt",
                # In der Vorfuehrung gibt es meist keine Sitzung; dann bleibt das Feld leer,
                # und die Anzeige zeigt genau das, was sie ohne Paarung auch im Haus zeigt.
                urheber=(wer.text() if (wer := urheber.aktueller()) is not None else ""),
            )
        )
        return True, werte, f"{raum.name} steht jetzt auf {werte:.1f} Grad."

    async def arm_alarm(self, mode: str) -> tuple[bool, str]:
        """Auch die Vorfuehrung schaltet wirklich scharf - im Arbeitsspeicher."""
        if mode not in ("home", "away"):
            raise DchError("invalid_mode", "Nur 'home' oder 'away'.", 422)
        self._alarm = 1.0 if mode == "home" else 2.0
        wort = "zu Hause" if mode == "home" else "unterwegs"
        return True, f"Alarmanlage wird {wort} scharf geschaltet."

    async def room_effect(self, room_id: int, delta_k: float) -> RoomEffectOut:
        """Dieselbe Rechnung wie im Betrieb, mit den Preisen und dem Wetter der Vorfuehrung."""
        raum = next((r for r in demo_rooms.ROOMS if r.id == room_id), None)
        if raum is None:
            raise DchError("unknown_room", f"Raum {room_id} ist nicht bekannt.", 404)
        now = self.now
        preise = [
            iv.price_ct_kwh
            for iv in (self.plan.intervals if self.plan else [])
            if iv.price_ct_kwh is not None and now <= iv.ts < now + timedelta(hours=24)
        ]
        mittel = sum(preise) / len(preise) if preise else None
        aussen = self.house.outdoor_temp_c(now)
        wirkung = room_shift.effect(
            delta_k=delta_k,
            circuits=max(1, raum.circuits),
            total_circuits=max(1, sum(r.circuits for r in demo_rooms.ROOMS)),
            cfg=self.hems.heat_demand,
            outdoor_c=aussen,
            price_ct_kwh=mittel,
            cheap_ct_kwh=min(preise) if preise else None,
            expensive_ct_kwh=max(preise) if preise else None,
        )
        return RoomEffectOut(
            room_id=room_id,
            name=raum.name,
            delta_k=wirkung.delta_k,
            share=wirkung.share,
            daily_kwh_th=wirkung.daily_kwh_th,
            daily_kwh_el=wirkung.daily_kwh_el,
            daily_eur=wirkung.daily_eur,
            store_kwh_th=wirkung.store_kwh_th,
            store_kwh_el=wirkung.store_kwh_el,
            shift_saving_eur=wirkung.shift_saving_eur,
            half_life_h=wirkung.half_life_h,
            cop=wirkung.cop,
            outdoor_c=round(aussen, 1),
            price_ct_kwh=round(mittel, 1) if mittel is not None else None,
            cheap_ct_kwh=round(min(preise), 1) if preise else None,
            expensive_ct_kwh=round(max(preise), 1) if preise else None,
            note_de=wirkung.note_de,
        )

    async def rooms_live(self) -> RoomsLiveOut:
        now = self.now
        out: list[RoomLiveOut] = []
        for r in demo_rooms.ROOMS:
            soll = self._room_setpoints.get(r.id, r.setpoint_c)
            ist = demo_rooms.temperature_c(r, now) + (soll - r.setpoint_c)
            offset = demo_rooms.offset_k(r, now)
            ziel = rooms.ziel(soll, offset)
            out.append(
                RoomLiveOut(
                    id=r.id,
                    name=r.name,
                    floor=r.floor,
                    circuits=r.circuits,
                    temp_c=ist,
                    setpoint_c=soll,
                    offset_k=offset,
                    target_c=ziel,
                    humidity_pct=None,
                    valve=demo_rooms.valve(r, now),
                    window=demo_rooms.window(r, now),
                    deviation_k=round(ist - (ziel or soll), 2),
                    observed_at=now,
                    quality=Quality.OK,
                )
            )
        return RoomsLiveOut(at=now, named=True, rooms=out)

    async def anlage(self) -> AnlageOut:
        """Das Schema der Vorführung. Ofen und Warmwasserfühler hat sie nicht, und das steht so da."""
        now = self.now
        fehlt = Measurement.missing(Quality.UNAVAILABLE, now, "demo")
        return anlage_logic.zusammensetzen(
            now=now,
            snap=self.snapshot,
            buffer=self.buffer,
            hp=self.hp,
            cfg=self.hems,
            stove=StoveLiveOut(),
            stove_return=fehlt,
            stove_pump=fehlt,
            dhw_outlet=fehlt,
            dhw_inlet=fehlt,
            wp_vorlauf=fehlt,
            ventile=[r.valve for r in (await self.rooms_live()).rooms],
            zeilen=self.history.series(
                now - timedelta(minutes=anlage_logic.RUECKBLICK_MIN), now + timedelta(minutes=1)
            ),
        )

    async def reglerkennzahlen(self, tage: int) -> ReglerKennzahlenOut:
        """Die Auszählung der Vorführung, aus erzeugten Minuten."""
        return kennzahl_logic.zusammensetzen(self.now, tage, kennzahl_logic.vorfuehrung(self.now))

    async def kennlinie(self, tage: int) -> KennlinieOut:
        """Die Kennlinie der Vorführung: erzeugte Punkte, derselbe Ausgleich wie im Haus."""
        return kennlinie_logic.zusammensetzen(
            now=self.now,
            tage=tage,
            punkte=kennlinie_logic.vorfuehrung(self.now, tage),
            heat=self.hems.heat_demand,
            buffer=self.hems.buffer,
            vorfuehrung=True,
        )

    async def waermepumpe(self) -> WaermepumpeOut:
        """Die Wärmepumpe der Vorführung. Einen Bus hat sie nicht; die Größen entstehen aus dem
        Zustand des Modellhauses (`wp_logic.vorfuehrung`), damit die Seite dort zu sehen ist."""
        now = self.now
        t = self.snapshot.buffer_temps_c
        werte = wp_logic.vorfuehrung(
            laeuft=self.hp.running,
            aussen_c=self.snapshot.outdoor_temp_c.value_or(8.0),
            leistung_kw=self.hp.power_kw,
            puffer_oben_c=t.top.value_or(45.0),
            puffer_unten_c=t.bottom.value_or(32.0),
        )

        def mess(key: str) -> Measurement:
            wert = werte.get(key)
            if wert is None:
                return Measurement.missing(Quality.UNAVAILABLE, now, "demo")
            return Measurement.ok(wert, now, "demo:ebus")

        return wp_logic.zusammensetzen(
            now=now, snap=self.snapshot, laeuft_laut_zaehler=self.hp.running, mess=mess
        )

    async def anlage_replay(self, day: date, step_min: int) -> AnlageReplayOut:
        """Die Wiedergabe aus dem Gedaechtnis der Vorfuehrung.

        Es reicht so weit zurueck wie `history_retention_hours`, in der Vorfuehrung also Stunden
        und nicht Jahre. Ein Tag, den die Vorfuehrung noch nicht erlebt hat, ergibt ein leeres
        Band - und die Hinweiszeile sagt das, statt ein stehendes Haus zu zeigen.
        """
        von, bis = anlage_replay.fenster(day, BERLIN)
        zeilen = self.history.series(von - timedelta(minutes=anlage_replay.RUECKBLICK_MIN), bis)

        def absicht(groesse: str) -> anlage_replay.Absicht | None:
            punkte = [
                (lauf.erstellt, p.ts, p.wert)
                for lauf in self._plan_laeufe
                for p in lauf.punkte
                if p.variable == groesse and p.wert is not None and von <= p.ts < bis
            ]
            return stand_vor(punkte, raster_min=15) if punkte else None

        # Die Vorführung hat keinen Ofen: ihr Anlagenbild bekommt ein leeres Ofenobjekt, und ihre
        # Wiedergabe muss dasselbe zeigen. Mit der unveränderten Konfiguration stand im Rückblick
        # ein Ofen „ohne Verbindung" und in der Legende „Pelletofen gebrannt" - ein anderes Haus
        # als auf der Seite „Anlage", und genau das soll es nicht geben.
        ohne_ofen = self.hems.model_copy(
            update={"stove": self.hems.stove.model_copy(update={"present": False})}
        )
        return anlage_replay.zusammenstellen(
            zeilen,
            ohne_ofen,
            day,
            BERLIN,
            step_min=step_min,
            jetzt=self.now,
            # Einen Schritt früher: zu einem Bild gehört das Fenster, das an ihm endet.
            raeume=await self.rooms_history(von - timedelta(minutes=step_min), bis, step_min),
            geplant_wp=absicht("hp_release"),
            geplant_ofen=absicht("stove_on"),
        )

    async def nachbetrachtung(self, day: date) -> NachbetrachtungOut:
        """Ein Tag der Vorführung in Euro, aus ihrem Gedächtnis und ihren aufbewahrten Fahrplänen.

        Beides reicht nur so weit zurück wie die Vorführung läuft. Ein Fahrplan vom Vorabend
        fehlt ihr deshalb fast immer; der Vergleich beginnt dann mit ihrem ersten Fahrplan, und
        die Antwort sagt, ab wann.
        """
        von, bis, daten_bis = nachbetrachtung_logic.fenster(day, BERLIN, self.now)
        punkte: dict[str, nachbetrachtung_logic.Punkte] = {
            groesse: [
                (lauf.erstellt, p.ts, p.wert)
                for lauf in self._plan_laeufe
                for p in lauf.punkte
                if p.variable == groesse and p.wert is not None and von <= p.ts < bis
            ]
            for groesse in nachbetrachtung_logic.GROESSEN
        }
        # Die Vorführung hat keinen Ofen; dieselbe Begründung wie in der Wiedergabe.
        ohne_ofen = self.hems.model_copy(
            update={"stove": self.hems.stove.model_copy(update={"present": False})}
        )
        return await asyncio.to_thread(
            nachbetrachtung_logic.zusammenstellen,
            self.history.series(von, max(daten_bis, von)),
            punkte,
            ohne_ofen,
            day,
            BERLIN,
            jetzt=self.now,
            # Kurze Zeitgrenze wie im Fahrplan der Vorführung: sie rechnet im Zeitraffer.
            opt_cfg=OptimizerConfig(step_min=15, time_limit_s=2.0),
            verschieben=await self.accounting.shift_report("day", day, self.now),
        )

    async def kontaktwirkung(self, days: int) -> KontaktwirkungOut:
        """Was K1 im Vorführhaus auslöst, aus dem Gedächtnis der Vorführung.

        Das reicht Stunden zurück und nicht Monate. Für ein Urteil ist das fast immer zu wenig,
        und die Antwort sagt das: die Seite zeigt ihre Form, die Aussage braucht ein echtes Haus.
        """
        von, bis = kontaktwirkung_logic.fenster(self.now, days)
        return kontaktwirkung_logic.zusammenstellen(
            self.history.series(von, bis),
            self.hems,
            BERLIN,
            tage=days,
            von=von,
            bis=bis,
            reicht_h=float(self.settings.history_retention_hours),
        )

    async def house_plan(self) -> HouseOut:
        """Das erfundene Haus der Vorfuehrung, mit Kontakten aus der Uhrzeit."""
        now = self.now
        kontakte = [
            HouseContactOut(
                key=k.key,
                name=k.name,
                room=k.room,
                door=k.door,
                open=demo_house.contact_open(k.key, now),
                observed_at=now if demo_house.contact_open(k.key, now) is not None else None,
                quality=Quality.OK
                if demo_house.contact_open(k.key, now) is not None
                else Quality.UNAVAILABLE,
            )
            for k in demo_house.PLAN.contacts
        ]
        return HouseOut(
            at=now,
            present=True,
            plan=demo_house.PLAN,
            source_de="Vorfuehrung, erfundener Grundriss",
            received_at=now,
            error_de="",
            contacts=kontakte,
        )

    async def rooms_history(self, start: datetime, end: datetime, step_min: int) -> RoomHistoryOut:
        ts = rooms.bucket_starts(start, end, step_min)
        # **Nach jetzt kommt nichts.** Die Werte sind eine Formel und ließen sich für jede Uhrzeit
        # ausrechnen, auch für heute Abend. Dann zeigte die Vorführung um acht Uhr morgens einen
        # vollständigen Tag und sähe aus, als sage sie Raumtemperaturen voraus. Eine Vorführung
        # darf erfundene Werte zeigen, aber nicht vorgeben, mehr zu wissen als die echte Anlage.
        jetzt = self.now
        return RoomHistoryOut(
            start=start,
            end=end,
            step_min=step_min,
            ts=ts,
            rooms=[
                RoomSeriesOut(
                    id=r.id,
                    name=r.name,
                    floor=r.floor,
                    circuits=r.circuits,
                    temp_c=[demo_rooms.temperature_c(r, t) if t <= jetzt else None for t in ts],
                    setpoint_c=[
                        self._room_setpoints.get(r.id, r.setpoint_c) if t <= jetzt else None
                        for t in ts
                    ],
                    offset_k=[demo_rooms.offset_k(r, t) if t <= jetzt else None for t in ts],
                    valve=[demo_rooms.valve(r, t) if t <= jetzt else None for t in ts],
                    window=[demo_rooms.window(r, t) if t <= jetzt else None for t in ts],
                )
                for r in demo_rooms.ROOMS
            ],
        )

    async def room_log(
        self, room_id: int, start: datetime, end: datetime, step_min: int
    ) -> RoomLogOut:
        raum = next((r for r in demo_rooms.ROOMS if r.id == room_id), None)
        if raum is None:
            raise DchError("unknown_room", f"Raum {room_id} ist nicht bekannt.", 404)
        ts = rooms.bucket_starts(start, end, step_min)
        jetzt = self.now
        soll = [
            self._room_setpoints.get(raum.id, raum.setpoint_c) if t <= jetzt else None for t in ts
        ]
        offset = [demo_rooms.offset_k(raum, t) if t <= jetzt else None for t in ts]
        return RoomLogOut(
            room=RoomSeriesOut(
                id=raum.id,
                name=raum.name,
                floor=raum.floor,
                circuits=raum.circuits,
                temp_c=[demo_rooms.temperature_c(raum, t) if t <= jetzt else None for t in ts],
                setpoint_c=soll,
                offset_k=offset,
                valve=[demo_rooms.valve(raum, t) if t <= jetzt else None for t in ts],
                window=[demo_rooms.window(raum, t) if t <= jetzt else None for t in ts],
            ),
            start=start,
            end=end,
            step_min=step_min,
            ts=ts,
            target_c=[rooms.ziel(a, b) for a, b in zip(soll, offset, strict=True)],
            # Bis einschliesslich jetzt: Das Ende des Fensters ist die laufende Minute, und ein
            # Eintrag aus genau dieser Minute gehoert hinein. Mit `<` fehlte gerade der Eintrag,
            # den jemand eben erzeugt hat - und das ist der, auf den er wartet.
            entries=[e for e in self._room_log.get(room_id, []) if start <= e.at <= end],
        )

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

    async def set_stove_mode(self, mode: StoveMode, duration_min: int) -> StoveLiveOut:
        """Im Demo-Modus gibt es keinen Ofen. Ein erfundener Schaltvorgang wäre hier das Schlechteste.

        Das simulierte Haus kennt nur Wärmepumpe und Puffer; einen Ofen mitzusimulieren hieße, im
        Dashboard eine Wärmequelle zu zeigen, deren Verhalten nichts mit dem echten Gerät zu tun
        hat. Die Oberfläche blendet den Ofen im Demo-Modus deshalb aus, und dieser Weg bleibt zu.
        """
        raise DchError("no_stove", "Im Demo-Modus gibt es keinen Ofen.", 404)

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
            alarm=AlarmOut(
                present=True,
                state=self._alarm,
                state_de={0.0: "unscharf", 1.0: "zu Hause scharf", 2.0: "unterwegs scharf"}[
                    self._alarm
                ],
                can_arm=True,
                observed_at=self.now,
            ),
            system=SystemStatusOut(
                mode=self.settings.mode,
                server_time=self.now,
                sim_speed=self.speed,
                bridge_online=True,
                sse_clients=self.broker.client_count,
                version=VERSION,
                connection_label_de="Demo-Modus" if self.settings.mode == "demo" else "live",
                # In der Vorführung kommt die Entscheidung am Kontakt an, und zwar immer: das
                # Vorführhaus hat kein Relais, das man schonen müsste, und der Schalter der
                # Laufzeit gilt für echte Hardware. „Stellt K1" ist hier also die Wahrheit, nicht
                # die Einstellung.
                hp_actuation=True,
                hp_actuation_de="Duck Curve fordert im Vorführhaus selbst an",
            ),
        )

    def _after_step_publish(self) -> None:
        # Die Automatik laeuft mit der Vorfuehrung, nicht erst, wenn jemand hinsieht. Sonst waere
        # sie eine Anzeige, die sich beim Hinschauen erfindet.
        self._shift_tick()
        self.snapshot = self.house.snapshot()  # Aktorzustände sofort sichtbar
        zustand = self._takt.naechster(
            monotonic(), lambda: self.live_state().model_dump(mode="json")
        )
        if zustand is not None:
            self.broker.publish("snapshot", zustand)

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
