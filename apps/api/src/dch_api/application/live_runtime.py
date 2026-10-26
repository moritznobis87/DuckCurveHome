"""Live-Runtime: Telemetrie der Bridge → LiveState + PostgreSQL; Regler-Tick; Planung; SSE.

**Was von hier aus geschaltet wird, und was nicht.** Die Wärmepumpe bleibt zurückhaltend: ihre
Entscheidungen werden gerechnet, gespeichert und angezeigt, aber nur mit
`DCH_HEAT_PUMP_ACTUATION_ENABLED=true` als K1-Kontakt gestellt. Der Pelletofen dagegen wird geführt,
sobald beide Freigaben stehen (`stove.control_enabled` und `mcz_allow_control` in der Bridge): sein
Fahrplan kommt alle 15 Minuten aus dem MILP, und der Regeltakt setzt ihn um.

Der Unterschied ist kein Zufall. Der K1-Kontakt greift in eine Maschine ein, die ihre eigene
Regelung hat und deren Sicherheitsketten wir nicht kennen; der Ofen bekommt genau einen Befehl, den
er selbst kennt, und regelt danach allein weiter.
"""

from __future__ import annotations

import asyncio
import contextlib
from collections import deque
from collections.abc import AsyncIterator
from datetime import UTC, date, datetime, timedelta
from typing import Any, cast

import structlog

from dch_api.application import rooms
from dch_api.application.battery_control import BatteryController, BatteryMode
from dch_api.application.config_loader import AppConfig
from dch_api.application.energy_accounting import ENERGY_KEYS, HEAT_KEYS, EnergyAccounting
from dch_api.application.forecast_evaluation import EvaluatorState, ForecastEvaluator
from dch_api.application.forecast_service import ForecastService
from dch_api.application.ha_import import HaImporter, ImportResult, Kind, load_entity_rules
from dch_api.application.inexogy_source import InexogySource, MeterClient
from dch_api.application.invoice_service import InvoiceService
from dch_api.application.myenergi_source import (
    MyenergiSource,
    StatusClient,
    price_readings_for_gaps,
)
from dch_api.application.plan_service import build_plan
from dch_api.application.push import Mitteilung, PushService
from dch_api.application.stove_control import STALE_AFTER_S, StoveController, StoveMode
from dch_api.application.stove_planner import StovePlan, decide_switch, plan_stove
from dch_api.application.tibber_invoice import MeasuredPeriod
from dch_api.errors import DchError
from dch_api.infrastructure.bridge_hub import BridgeHub
from dch_api.infrastructure.db.repositories import SqlRepositories
from dch_api.infrastructure.history import SERIES
from dch_api.infrastructure.live_state import LiveState
from dch_api.infrastructure.sse_broker import SseBroker
from dch_api.schemas import (
    AlarmOut,
    BackfillResultOut,
    BatteryLiveOut,
    EnergySummaryOut,
    EvReportOut,
    ForecastEvaluationOut,
    HeatBalanceOut,
    HeatConfigIn,
    HeatReportOut,
    InvoiceReportOut,
    InvoiceSummaryOut,
    LiveStateOut,
    Period,
    PlanOut,
    PvTaxReportOut,
    RoomEffectOut,
    RoomHistoryOut,
    RoomLiveOut,
    RoomSeriesOut,
    RoomsLiveOut,
    ShiftReportOut,
    SourceStatusOut,
    StoveLiveOut,
    SystemEventOut,
    SystemStatusOut,
    WatchFindingOut,
    YearMapOut,
)
from dch_api.settings import Settings
from hems_core.accounting import summarize
from hems_core.accounting.stove_cost import budget_window, estimated_kg_burned, remaining_kg
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
from hems_core.planning import cheap_windows, current_price, next_window_after, price_rank
from hems_core.protocol import DeviceHealthFrame, EventFrame, RawReading
from hems_core.simulation import BERLIN
from hems_core.thermal import compute_buffer_state, room_shift
from hems_core.watch import BRIDGE, RULES, back_text, findings

log = structlog.get_logger("live")
VERSION = "0.1.0-phase2"
HISTORY_KEYS = [k for k in SERIES if k != "hp_release_contact"] + ["actuator:hp_release_contact"]


#: So lange nach einer Meldung bleibt dieselbe Regel still, auch wenn sie erneut wechselt.
MELDE_PAUSE_MIN = 30


class LiveRuntime:
    def __init__(
        self,
        settings: Settings,
        config: AppConfig,
        repos: SqlRepositories,
        hub: BridgeHub,
        forecasts: ForecastService,
        myenergi: StatusClient | None = None,
        inexogy: MeterClient | None = None,
        push: PushService | None = None,
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
        self.stove = StoveController(self.hems.stove)
        self.battery = BatteryController(self.hems.battery)
        self.battery_sent_at: datetime | None = None
        self.battery_error: str | None = None
        self.stove_plan = StovePlan()
        self.energy_rebuild = "ausstehend"
        self.push = push
        # Was der Wächter beim letzten Takt sah, je Regel, und wann zuletzt etwas gemeldet wurde.
        # Beides nur im Speicher; den Stand über Neustarts hinweg holt `start()` aus den
        # Ereignissen, damit ein Neustart nicht alles noch einmal meldet.
        self._watch_state: dict[str, bool] = {}
        self._watch_sent: dict[str, datetime] = {}
        # Seit wann dieser Vorgang läuft. Der Wächter braucht es für den Fall, dass die Brücke
        # sich seit dem Start nie gemeldet hat: Dann beginnt die Stille hier und nicht in der
        # Ewigkeit (siehe `_watch`).
        self.started_at = datetime.now(UTC)
        self._stove_switched_at: datetime | None = None
        self.decision: Decision | None = None
        self.decisions: deque[Decision] = deque(maxlen=100)
        self.plan: PlanOut | None = None
        self._plan_at: datetime | None = None
        # Wann K1 zuletzt gesendet wurde: der Hardware-Timer läuft ab Befehl, nicht ab Entscheidung.
        self._k1_sent_at: datetime | None = None
        self._plan_status_vorher: str = ""  # damit nur der Wechsel ein Ereignis wird
        self._last_publish = 0.0
        self._last_price_stored: datetime | None = None
        self.price_fill_note: str | None = None
        self._tasks: list[asyncio.Task[None]] = []
        loc = config.site.location
        self.evaluator = ForecastEvaluator(
            latitude=loc.latitude,
            longitude=loc.longitude,
            tz=BERLIN,
            source="simple_clear_sky_v1",
            source_label_de="DCH-Prognose (Open-Meteo-Bewölkung × Klarhimmel)",
        )
        self.invoice_service = InvoiceService(
            BERLIN,
            load_all=self._load_invoices,
            save=self._save_invoice,
            measure=self._measure_period,
        )
        self.accounting = EnergyAccounting(
            self.hems,
            BERLIN,
            lambda s, e: repos.minute_series(s, e, ENERGY_KEYS),
            store=(repos.energy_hours, repos.upsert_energy_hours, repos.last_energy_hour),
            data_since=repos.first_measurement_at,
            device_events=self._libbi_events,
            # Eigene, breitere Abfrage für die Wärmeseite: der Ofen steht nicht in ENERGY_KEYS,
            # und ohne ihn meldete die Ofenauswertung im Live-Betrieb „keine Daten", während
            # die Spalten gefüllt dastanden.
            heat_rows=lambda s, e: repos.minute_series(s, e, HEAT_KEYS),
            heat_store=(repos.heat_hours, repos.upsert_heat_hours),
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
                on_backfilled=self._after_backfill,
                on_state_change=self._on_source_state,
                on_libbi_state=self._on_libbi_state,
            )
        # Der amtliche Zähler läuft als zweite Meinung mit und schreibt auf eigene Schlüssel. Er
        # ändert an keiner Bilanz etwas; erst wenn feststeht, wie stabil er überträgt, ist die
        # Frage zu stellen, wer den Netzwert tragen soll.
        self.inexogy: InexogySource | None = None
        if inexogy is not None:
            self.inexogy = InexogySource(
                inexogy,
                self.on_source_readings,
                meter=settings.inexogy_meter,
                poll_s=settings.inexogy_poll_s,
                backfill_hours=settings.inexogy_backfill_hours,
                on_state_change=self._on_inexogy_state,
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

    async def _after_backfill(self, start: datetime, end: datetime) -> None:
        """Nachgetragene Minuten brauchen einen Preis: Tibber-Historie für Lücken, dann Stunden neu rechnen."""
        prices = self.forecasts.price_provider
        if prices is None or not hasattr(prices, "fetch_range"):
            self.price_fill_note = "kein Tibber-Token konfiguriert"
        else:
            try:
                points = await prices.fetch_range(start, end)
                existing = await self.repos.minute_series(start, end, ["electricity_price_ct_kwh"])
                readings = price_readings_for_gaps(points, existing, start, end)
                for i in range(0, len(readings), 2000):
                    await self.repos.add_readings(readings[i : i + 2000])
                self.price_fill_note = (
                    f"{len(points)} Tibber-Stundenpreise, {len(readings)} Minuten ergänzt"
                )
                log.info("price gaps filled", points=len(points), readings=len(readings))
            except Exception as exc:
                self.price_fill_note = f"Tibber-Historie fehlgeschlagen: {repr(exc)[:200]}"
                log.warning("tibber history failed", error=repr(exc)[:200])
                await self.repos.add_event("warning", "tibber.history", self.price_fill_note)
        # Erst verdichten, dann rechnen. Die nachgetragenen Rohwerte tragen alte Zeitstempel, und
        # die regelmäßige Verdichtung holt nur ab der letzten verdichteten Minute auf - sie hätte
        # diese Zeilen nie angefasst. Sie wären über `minute_series` in die Stundenbilanz
        # eingegangen, nach Ablauf der Aufbewahrungsfrist aber gelöscht worden, ohne je im
        # dauerhaften Bestand zu stehen: die Lücke käme dann zurück, sobald die Stunden einmal neu
        # gerechnet werden. Das ist zugleich die Voraussetzung dafür, die Frist kurz zu halten.
        rolled = await self.repos.rollup_minutes(start, end)
        log.info("backfilled minutes rolled up", rows=rolled, start=start.isoformat())
        await self.accounting.recompute(start, end)

    async def _on_inexogy_state(self, online: bool, error: str) -> None:
        await self.repos.add_event(
            "info" if online else "warning",
            "inexogy.connection",
            "Zähler erreichbar" if online else f"Zähler nicht erreichbar: {error}",
        )
        self.broker.publish("system", {"sources": self._sources()})

    async def _on_source_state(self, online: bool, error: str) -> None:
        await self.repos.add_event(
            "info" if online else "warning",
            "myenergi.connection",
            "myenergi erreichbar" if online else f"myenergi nicht erreichbar: {error}",
        )
        self.broker.publish("system", {"sources": self._sources()})

    def _sources(self) -> list[SourceStatusOut]:
        """Eine Zeile je Messquelle, auch für die, die es gerade nicht gibt.

        **Eine fehlende Quelle wird genannt, nicht weggelassen.** Wer wissen will, warum vom Zähler
        nichts kommt, sucht sonst eine Zeile, die gar nicht da ist, und findet nichts - was aussieht
        wie eine Auskunft und keine ist. Der häufigste Grund steht deshalb gleich dabei: die
        Zugangsdaten fehlen in der Umgebung des Dienstes.
        """
        out = [
            SourceStatusOut(
                name="bridge",
                online=self.hub.online,
                detail_de="Home-Assistant-Bridge" if self.hub.online else "Bridge offline",
            )
        ]
        out.append(
            SourceStatusOut(**self.myenergi.status_out())
            if self.myenergi is not None
            else SourceStatusOut(
                name="myenergi",
                online=False,
                detail_de="nicht eingerichtet: DCH_MYENERGI_SERIAL und DCH_MYENERGI_API_KEY fehlen",
            )
        )
        out.append(
            SourceStatusOut(**self.inexogy.status_out())
            if self.inexogy is not None
            else SourceStatusOut(
                name="inexogy",
                online=False,
                detail_de="nicht eingerichtet: DCH_INEXOGY_EMAIL und DCH_INEXOGY_PASSWORD fehlen",
            )
        )
        return out

    def _watch(self, now: datetime) -> list[WatchFindingOut]:
        """Was gerade schweigt.

        Die Zeitpunkte kommen aus dem Rohbestand (`live.readings`), nicht aus dem Snapshot: Der
        Snapshot ersetzt alte Werte durch „unavailable" und verliert dabei genau die Auskunft, um
        die es hier geht - **wann** zuletzt etwas kam. Beim Start lädt `start()` den letzten Stand
        aus der Datenbank, also überlebt diese Auskunft einen Neustart des Dienstes.

        Die Brücke ist eine Zeile wie die anderen, mit ihrem letzten Lebenszeichen. Eine stehende
        Verbindung, durch die nichts geht, ist der Fall vom 23.10.2026 und soll gemeldet werden.
        """
        return [
            WatchFindingOut(
                name=f.name,
                title_de=f.title_de,
                severity=f.severity,
                since=f.since,
                silent_min=round(f.silent_min, 1),
                text_de=f.text_de,
            )
            for f in findings(self._last_seen(), now, self.started_at)
        ]

    async def _watch_notify(self, now: datetime) -> None:
        """Aus einem Befund wird eine Mitteilung - einmal, wenn er auftritt, und einmal, wenn er geht.

        **Zustandswechsel, nicht Zustand.** Ein Ausfall, der seit zwei Tagen läuft, ist eine
        Nachricht und nicht 17 280 Nachrichten. Gemeldet wird deshalb nur der Übergang.

        **Ein Neustart ist kein Ausfall.** Der letzte bekannte Stand steht in den Ereignissen
        (`watch.<name>`), und `start()` liest ihn zurück. Ohne das meldete jeder Deploy alle
        offenen Befunde noch einmal - und davon gibt es an einem schlechten Tag mehrere.

        **Die Pause ist ein Sicherheitsventil.** Liefert eine Quelle genau im Takt ihrer eigenen
        Frist, wechselt der Befund ständig. Der Zustand wird dann weitergeführt, aber nicht
        gemeldet; sonst klingelt das Telefon im Viertelstundentakt.
        """
        if self.push is None:
            return
        offen = {f.name: f for f in findings(self._last_seen(), now, self.started_at)}
        for rule in RULES:
            aktiv = rule.name in offen
            vorher = self._watch_state.get(rule.name, False)
            self._watch_state[rule.name] = aktiv
            if aktiv == vorher:
                continue
            zuletzt = self._watch_sent.get(rule.name)
            if zuletzt is not None and (now - zuletzt) < timedelta(minutes=MELDE_PAUSE_MIN):
                continue
            self._watch_sent[rule.name] = now
            if aktiv:
                befund = offen[rule.name]
                # Der Titel ist die Sache, der Rumpf der Satz ohne sie: „Die Puffertemperaturen" /
                # „seit 2 Tagen still. Ohne sie gibt es keinen Ladezustand …". Auf einem Telefon
                # steht der Name der App ohnehin darüber.
                rumpf = befund.text_de.removeprefix(f"{rule.title_de} ")
                await self.repos.add_event("warning", f"watch.{rule.name}", befund.text_de)
                await self.push.send(
                    Mitteilung(title=rule.title_de, body=rumpf, tag=f"watch-{rule.name}", url="/")
                )
            else:
                satz = back_text(rule)
                await self.repos.add_event("info", f"watch.{rule.name}", satz)
                await self.push.send(
                    Mitteilung(
                        title=rule.title_de,
                        body=satz.removeprefix(f"{rule.title_de} "),
                        tag=f"watch-{rule.name}",
                        url="/",
                    )
                )

    def _last_seen(self) -> dict[str, datetime | None]:
        """Wann zu jedem Schlüssel zuletzt etwas kam, die Brücke eingeschlossen."""
        zuletzt: dict[str, datetime | None] = {
            k: r.observed_at for k, r in self.live.readings.items()
        }
        zuletzt[BRIDGE] = self.hub.last_frame_at
        return zuletzt

    async def _load_watch_state(self) -> None:
        """Den Stand des Wächters aus den Ereignissen zurückholen, damit ein Neustart nicht meldet."""
        for rule in RULES:
            row = await self.repos.latest_event(f"watch.{rule.name}")
            self._watch_state[rule.name] = row is not None and row.severity == "warning"

    async def _libbi_events(self, start: datetime, end: datetime) -> list[tuple[datetime, str]]:
        """Die Zustandsmeldungen des Speichers eines Zeitraums, für die Tagesdiagnose."""
        rows = await self.repos.events_between("libbi_state", start, end)
        return [(r.at, r.message) for r in rows]

    async def _on_libbi_state(self, message: str, report: dict[str, object]) -> None:
        """Eine Zustandsmeldung des Speichers ins Ereignisprotokoll schreiben.

        Sie landet unter dem Code `libbi_state` und erscheint in der Tagesdiagnose. Damit steht
        neben der Frage „wann hat der Speicher aus dem Netz geladen" auch die Antwort auf „in
        welchem Zustand war er dabei" - die einzige Spur, die DCH von den Entscheidungen des
        Geräts überhaupt bekommen kann, denn die myenergi-Cloud nennt keine Gründe.
        """
        await self.repos.add_event("info", "libbi_state", message, report)

    async def on_bridge_event(self, frame: EventFrame | DeviceHealthFrame) -> None:
        if isinstance(frame, EventFrame):
            await self.repos.add_event(
                frame.severity, f"bridge.{frame.code}", frame.message, frame.context, at=frame.at
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
        # Drei Zustände, nicht zwei. „release" ist ein Grund zu starten, „off" ein ausdrückliches
        # Nein des Fahrplans, alles andere heißt, dass er dazu nichts sagt. Vorher fiel das Nein
        # mit dem Schweigen in einen Topf, und ein Fahrplan, der nur freigeben und nie pausieren
        # kann, ist keiner.
        planned = planned_off = False
        if self.plan is not None:
            cur = next(
                (i for i in self.plan.intervals if i.ts <= now < i.ts + timedelta(minutes=15)), None
            )
            planned = cur is not None and cur.planned_hp_state == "release"
            planned_off = cur is not None and cur.planned_hp_state == "off"
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
            planned_off=planned_off,
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
            if self.settings.heat_pump_actuation_enabled:
                await self._apply_contacts(decision)
        elif self.settings.heat_pump_actuation_enabled and decision.k1_release:
            # **Die Freigabe muss nachgesendet werden, sonst fällt sie von selbst.** Der Befehl geht
            # mit einem Hardware-Timer hinaus (`hw_auto_off_release_s`, 30 min): bleibt das nächste
            # Kommando aus, schaltet der Shelly zurück. Das war richtig, solange eine Freigabe aus
            # einem Preisfenster kam und selten länger stand. Ein Fahrplan hält sie über Stunden,
            # und weil nur bei *geänderter* Entscheidung gesendet wurde, wäre sie nach einer halben
            # Stunde stillschweigend weg gewesen - ohne Eintrag, ohne Zustandswechsel, ohne dass
            # jemand etwas davon sieht. Nachgesendet wird nach der Hälfte der Frist.
            frist = self.hems.heat_pump.hw_auto_off_release_s
            faellig = (
                self._k1_sent_at is None or (now - self._k1_sent_at).total_seconds() >= frist / 2
            )
            if faellig:
                await self._apply_contacts(decision)
        # Der Ofen hängt nicht am Regler der Wärmepumpe: seine Entscheidung steht im Fahrplan, und
        # dieser Aufruf setzt sie um. Er läuft in jedem Takt, schaltet aber nur bei einem Unterschied.
        await self._apply_stove_plan(now)
        return decision

    async def _apply_contacts(self, decision: Decision) -> None:
        if not self.hub.online:
            return
        self._k1_sent_at = decision.at
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
        # Der Ofen zuerst: sein Fahrplan geht in den Plan ein, und ein Plan mit dem Ofenstand von
        # vor einer Viertelstunde zeigt Brennphasen, die der Optimierer gerade verworfen hat.
        await self.refresh_stove_plan()
        self.plan = build_plan(
            self.evaluator.pv_expected_corrected(self.forecasts.pv_expected_kw),
            self.forecasts.prices,
            now,
            self.hems,
            stove_on=self.stove_plan.on_at,
            hp_on=self.stove_plan.hp_on_at,
            planner_status=self.stove_plan.status,
            planner_note_de=self.stove_plan.note_de,
            planner_warn_de=self.stove_plan.warnung_de(),
        )
        self._plan_at = now
        self.broker.publish("plan", self.plan.model_dump(mode="json"))

    # ------------------------------------------------------------------ Der Ofen
    async def refresh_stove_plan(self) -> None:
        """Den Ofenfahrplan neu rechnen, im selben Takt wie den Plan der Wärmepumpe.

        Der Solver braucht einige hundert Millisekunden; alle 15 Minuten ist das billig, in jedem
        Regeltakt wäre es Verschwendung. Zwischen zwei Läufen liest der Regeltakt einfach den
        bestehenden Fahrplan ab.

        Gerechnet wird in einem Thread. HiGHS ist synchron und darf im schlechtesten Fall bis zu
        seiner Zeitgrenze laufen; im Ereignisschleifen-Thread hieße das, dass so lange kein SSE-Frame
        und keine Antwort herausgeht. Eine Sekunde Rechnen ist in Ordnung, eine Sekunde Stillstand
        des ganzen Dienstes nicht.
        """
        # Kein Ausstieg ohne Ofen mehr: `plan_stove` rechnet dann die Wärmepumpe allein, und die
        # führt inzwischen. Hier auszusteigen hieße, ihren Fahrplan wegen eines anderen Geräts
        # nicht einmal zu rechnen.
        _, buffer, hp = self._states()
        remaining = await self._stove_remaining_kg()
        pv_expected = self.evaluator.pv_expected_corrected(self.forecasts.pv_expected_kw)
        temps = self._temps_48h()
        self.stove_plan = await asyncio.to_thread(
            plan_stove,
            now=self.now,
            tz=BERLIN,
            cfg=self.hems,
            prices=list(self.forecasts.prices),
            pv_expected=pv_expected,
            temps=temps,
            buffer=buffer,
            hp_running=hp.running,
            stove_running=self._stove_running() is True,
            remaining_kg=remaining,
        )
        plan = self.stove_plan
        # Dieselbe Beurteilung wie für Ereignis und Oberfläche: nicht der Abbruch ist die
        # Meldung, sondern der Abstand. Sonst stünde hier alle 15 Minuten eine Warnung, und eine
        # Warnung, die immer dasteht, liest nach einer Woche niemand mehr.
        ebene = log.warning if plan.warnung_de() else log.info
        ebene(
            "stove plan",
            status=plan.status,
            hours=plan.runtime_h(),
            kg=plan.pellet_kg,
            budget_kg=plan.fuel_budget_kg,
            ms=plan.solve_ms,
            gap=plan.mip_gap,
            note=plan.note_de,
        )
        # Ein Abbruch gehört ins Ereignisprotokoll, nicht nur in die Konsole. Sonst merkt niemand,
        # dass der Fahrplan am Relais ein anderer ist als der, den der Optimierer gewollt hätte;
        # es steht ja eine Zahl da, und die sieht aus wie jede andere. Nur beim Wechsel, damit ein
        # dauerhaft knapper Solver nicht alle 15 Minuten dieselbe Zeile schreibt.
        if plan.status != self._plan_status_vorher:
            self._plan_status_vorher = plan.status
            if plan.warnung_de():
                gap = f" (bis zu {plan.mip_gap * 100:.0f} % vom Besten)" if plan.mip_gap else ""
                await self.repos.add_event(
                    "warning",
                    "planner.timeout",
                    f"Der Optimierer brach nach {plan.solve_ms} ms ab{gap}. "
                    f"Der Fahrplan gilt, ist aber nicht der beste.",
                    {"solve_ms": plan.solve_ms, "mip_gap": plan.mip_gap},
                )

    def _stove_running(self) -> bool | None:
        """Der gemessene Betriebszustand, oder None, wenn nichts Frisches vorliegt."""
        m = self.live.measurement("stove_running", self.now, STALE_AFTER_S)
        if m.value is None or m.quality not in (Quality.OK, Quality.STALE):
            return None
        return bool(m.value)

    async def _stove_remaining_kg(self) -> float | None:
        """Was seit dem letzten Nachfüllen noch im Behälter liegt, aus den Leistungsstufen geschätzt.

        Ohne jede Ofenmeldung im laufenden Fenster kommt `None` zurück, und der Planer rechnet dann
        mit einer vollen Füllung. Das ist die optimistische Annahme; sie ist vertretbar, weil ohne
        Ofendaten ohnehin kein Schaltbefehl ankäme.
        """
        start_local, _ = budget_window(self.hems.stove, self.now.astimezone(BERLIN))
        rows = await self.repos.minute_series(
            start_local.astimezone(UTC), self.now, ["stove_power_level", "stove_running"]
        )
        by_level: dict[str, int] = {}
        seen = False
        for row in rows:
            level = row.get("stove_power_level")
            running = row.get("stove_running")
            if running is None:
                continue
            seen = True
            if running and isinstance(level, int | float) and level >= 1:
                key = str(int(level))
                by_level[key] = by_level.get(key, 0) + 1
        if not seen:
            return None
        return remaining_kg(self.hems.stove, estimated_kg_burned(self.hems.stove, by_level))

    def _temps_48h(self) -> list[tuple[datetime, float]]:
        w = self.forecasts.weather
        if w is None:
            return []
        return [
            (p.ts, p.temp_c)
            for p in w.points
            if p.temp_c is not None and p.ts >= self.now - timedelta(hours=1)
        ][:48]

    async def _apply_stove_plan(self, now: datetime) -> None:
        """Den Fahrplan umsetzen, solange niemand von Hand eingegriffen hat.

        Die Entscheidung selbst trifft `decide_switch`; hier steht nur noch, was danach passiert.
        Fehlt eine der Freigaben, plant DCH weiter und schaltet nicht: der Fahrplan bleibt im
        Dashboard sichtbar, und die Sperre steht daneben.
        """
        d = decide_switch(
            plan=self.stove_plan,
            now=now,
            mode=self.stove.effective_mode(now),
            controllable=self.stove.controllable,
            actuation_enabled=self.settings.actuation_enabled,
            bridge_online=self.hub.online,
            observed=self._stove_running(),
            last_switch_at=self._stove_switched_at,
            min_runtime_min=self.hems.stove.min_runtime_min,
            min_offtime_min=self.hems.stove.min_offtime_min,
        )
        if not d.switch:
            return
        want = d.state
        self._stove_switched_at = now
        result = await self.hub.send_command("stove", want, None, None)
        log.info("stove auto switch", want=want, ok=result.ok, error=result.error)
        await self.repos.add_event(
            "info" if result.ok else "warning",
            "stove.auto",
            f"Planer: Ofen {'an' if want else 'aus'}"
            + ("" if result.ok else f" fehlgeschlagen: {result.error}"),
            {"note": self.stove_plan.note_de},
        )

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

    def _stove_state(self, now: datetime) -> StoveLiveOut:
        return self.stove.state(
            lambda key, stale: self.live.measurement(key, now, stale),
            now,
            planned_on=self.stove_plan.on_at(now),
            plan_until=self.stove_plan.until(now),
            plan_note_de=self.stove_plan.note_de,
        )

    async def set_stove_mode(self, mode: StoveMode, duration_min: int) -> StoveLiveOut:
        """Den Ofen von Hand stellen. `auto` nimmt einen Eingriff zurueck, ohne selbst zu schalten.

        Geschaltet wird nur, wenn die Konfiguration es freigibt und die Bridge steht. Scheitert der
        Befehl, bleibt der alte Modus stehen: eine Absicht, die das Geraet nie erreicht hat, waere
        in der Oberflaeche eine Luege.
        """
        now = self.now
        if not self.hems.stove.present:
            raise DchError("no_stove", "Für dieses Haus ist kein Ofen konfiguriert.", 404)
        if not self.stove.controllable:
            raise DchError(
                "stove_control_disabled",
                "Die Ofensteuerung ist nicht freigegeben (stove.control_enabled).",
                409,
            )
        if mode in ("on", "off"):
            if not self.settings.actuation_enabled:
                raise DchError(
                    "actuation_disabled", "Steuerung ist in dieser Phase deaktiviert.", 409
                )
            if not self.hub.online:
                raise DchError("bridge_offline", "Bridge nicht verbunden.", 503)
            result = await self.hub.send_command("stove", mode == "on", None, None)
            if not result.ok:
                await self.repos.add_event(
                    "warning", "stove.failed", f"Ofen → {mode}: {result.error}", {}
                )
                raise DchError(
                    "stove_not_confirmed", result.error or "Ofen hat nicht bestätigt.", 502
                )
        before = self.stove.mode
        if mode in ("on", "off"):
            # Auch ein Eingriff von Hand startet die Sperre: gleich danach darf der Planer nicht
            # zurückschalten, sonst wäre der Knopf ein Vorschlag und keine Anweisung.
            self._stove_switched_at = now
        self.stove.set(mode, duration_min, now)
        if self.stove.mode != before:
            await self.repos.add_event(
                "info", "stove.mode", f"Ofen: {before} → {self.stove.mode}", {}
            )
        state = self._stove_state(now)
        self.broker.publish("snapshot", self.live_state().model_dump(mode="json"))
        return state

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

    # ------------------------------------------------------------------ Alarmanlage
    ALARM_WORT = {
        0.0: "unscharf",
        1.0: "zu Hause scharf",
        2.0: "unterwegs scharf",
        3.0: "schaltet gerade",
        4.0: "ausgelöst",
    }

    def _alarm_state(self, now: datetime) -> AlarmOut:
        """Was die Anlage meldet, und ob von hier aus geschärft werden darf.

        Die Reihe heißt `alarm_state` und kommt wie jede andere über die Entity-Zuordnung. Fehlt
        sie, ist keine Anlage eingerichtet - dann sagt die Anzeige das und zeigt keinen Knopf.
        """
        m = self.live.measurement("alarm_state", now, 1800)
        da = m.value is not None or m.observed_at is not None
        return AlarmOut(
            present=da,
            state=m.value,
            state_de=self.ALARM_WORT.get(m.value, "unbekannt")
            if m.value is not None
            else "keine Meldung",
            # Geschärft wird nur, wenn die Brücke steht und die Steuerung überhaupt frei ist. Ob
            # es die Bridge-Seite freigibt, weiß erst der Befehl; das sagt dann seine Antwort.
            can_arm=da and self.hub.online and self.settings.actuation_enabled,
            observed_at=m.observed_at,
        )

    async def arm_alarm(self, mode: str) -> tuple[bool, str]:
        """Die Anlage schärfen. Unscharf wird hier nicht geschaltet - siehe `AlarmOut`."""
        if mode not in ("home", "away"):
            raise DchError("invalid_mode", "Nur 'home' oder 'away'.", 422)
        if not self.settings.actuation_enabled:
            raise DchError("actuation_disabled", "Steuerung ist in dieser Phase deaktiviert.", 409)
        if not self.hub.online:
            raise DchError("bridge_offline", "Bridge nicht verbunden.", 503)
        result = await self.hub.send_command(f"alarm:arm_{mode}", True, None, None)
        wort = "zu Hause" if mode == "home" else "unterwegs"
        if not result.ok:
            return False, result.error or "Die Anlage hat nicht bestätigt."
        await self.repos.add_event(
            "info", "alarm.armed", f"Alarmanlage {wort} scharf geschaltet.", {"mode": mode}
        )
        log.info("alarm armed", mode=mode)
        return True, f"Alarmanlage wird {wort} scharf geschaltet."

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
            stove=self._stove_state(now),
            price_rank=price_rank(self.forecasts.prices, now),
            today_kwh={},
            alarm=self._alarm_state(now),
            system=SystemStatusOut(
                mode="live",
                server_time=now,
                sim_speed=1.0,
                bridge_online=self.hub.online,
                sse_clients=self.broker.client_count,
                version=VERSION,
                connection_label_de=self._connection_label(),
                sources=self._sources(),
                watch=self._watch(now),
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

    # ------------------------------------------------------------------ Einzelraumregelung
    async def _room_meta(self) -> dict[int, rooms.RoomMeta]:
        """Namen, Etagen und Kreiszahlen aus dem jüngsten `rooms.list` der Brücke."""
        ereignis = await self.repos.latest_event(rooms.EVENT_CODE)
        if ereignis is None:
            return {}
        return rooms.meta_from_context(ereignis.context or {})

    def _room_ids(self, meta: dict[int, rooms.RoomMeta]) -> list[int]:
        """Welche Räume es gibt: was gerade meldet, vereint mit dem, was benannt ist.

        Beide Quellen allein wären unvollständig. Ein Raum, dessen Funkfühler seit Tagen schweigt,
        steht nur noch in der Namensliste - und soll sichtbar bleiben, denn das Schweigen ist die
        Aussage. Ein gerade in Controme angelegter Raum meldet schon, bevor die Brücke die neue
        Liste geschickt hat, und soll nicht bis dahin fehlen.
        """
        return sorted(set(rooms.ids_from_keys(self.live.readings)) | set(meta))

    @staticmethod
    def _room_name(meta: dict[int, rooms.RoomMeta], rid: int) -> rooms.RoomMeta:
        return meta.get(rid) or rooms.RoomMeta(id=rid, name=f"Raum {rid}", rank=rid)

    async def rooms_live(self) -> RoomsLiveOut:
        now = self.now
        meta = await self._room_meta()
        ids = self._room_ids(meta)
        out: list[RoomLiveOut] = []
        for rid in ids:
            m = self._room_name(meta, rid)

            def wert(feld: str, _rid: int = rid) -> Measurement:
                return self.live.measurement(f"room_{_rid}_{feld}", now, rooms.STALE_S)

            ist = wert("temp_c")
            soll = wert("setpoint_c")
            offset = wert("offset_k")
            ziel = rooms.ziel(soll.value, offset.value)
            abweichung = (
                round(ist.value - ziel, 2) if ist.value is not None and ziel is not None else None
            )
            out.append(
                RoomLiveOut(
                    id=rid,
                    name=m.name,
                    floor=m.floor,
                    circuits=m.circuits,
                    temp_c=ist.value,
                    setpoint_c=soll.value,
                    offset_k=offset.value,
                    target_c=ziel,
                    humidity_pct=wert("humidity_pct").value,
                    valve=wert("valve").value,
                    window=wert("window").value,
                    deviation_k=abweichung,
                    observed_at=ist.observed_at if ist.value is not None else None,
                    quality=ist.quality,
                )
            )
        out.sort(key=lambda r: rooms.sort_key(self._room_name(meta, r.id)))
        return RoomsLiveOut(at=now, named=bool(meta), rooms=out)

    async def set_room_setpoint(self, room_id: int, setpoint_c: float) -> tuple[bool, float, str]:
        """Die Solltemperatur eines Raums stellen, dauerhaft.

        **Die Anzeige bekommt keinen Wert geschenkt.** Gelingt der Befehl, steht der neue Sollwert
        trotzdem erst da, wenn Controme ihn das nächste Mal meldet - die Brücke stößt diese Abfrage
        sofort an. Hier wird nichts in die Messreihe geschrieben: eine Zahl, die aus der Absicht
        stammt und nicht aus der Anlage, wäre in einer Messreihe eine Fälschung, und genau an ihr
        würde man später die Frage „hat er wirklich gestellt?" nicht mehr beantworten können.

        Jede Änderung steht als Ereignis in der Datenbank, mit altem und neuem Wert. Wer in einem
        halben Jahr vor einer Abweichung steht, soll nachlesen können, wann jemand gedreht hat.
        """
        werte = rooms.runde_soll(setpoint_c)
        if not (rooms.SOLL_MIN <= werte <= rooms.SOLL_MAX):
            raise DchError(
                "invalid_setpoint",
                f"Sollwert muss zwischen {rooms.SOLL_MIN:.0f} und {rooms.SOLL_MAX:.0f} Grad liegen.",
                422,
            )
        meta = await self._room_meta()
        if room_id not in self._room_ids(meta):
            raise DchError("unknown_room", f"Raum {room_id} ist nicht bekannt.", 404)
        name = self._room_name(meta, room_id).name
        if not self.settings.actuation_enabled:
            raise DchError("actuation_disabled", "Steuerung ist in dieser Phase deaktiviert.", 409)
        if not self.hub.online:
            raise DchError("bridge_offline", "Bridge nicht verbunden.", 503)
        vorher = self.live.measurement(f"room_{room_id}_setpoint_c", self.now, rooms.STALE_S).value
        result = await self.hub.send_command(f"room:{room_id}:soll", True, None, None, value=werte)
        if not result.ok:
            return False, werte, result.error or "Controme hat den Sollwert nicht bestätigt."
        await self.repos.add_event(
            "info",
            "rooms.setpoint",
            f"{name}: Sollwert auf {werte:.1f} Grad gestellt"
            + (f" (vorher {vorher:.1f})" if vorher is not None else ""),
            {"room": room_id, "name": name, "from": vorher, "to": werte},
        )
        log.info("room setpoint set", room=room_id, to=werte, before=vorher)
        return True, werte, f"{name} steht jetzt auf {werte:.1f} Grad."

    async def room_effect(self, room_id: int, delta_k: float) -> RoomEffectOut:
        """Die Wirkung einer Sollwertänderung, gerechnet mit dem Wetter und den Preisen von jetzt.

        **Die Preise kommen aus dem Fahrplan, nicht aus dem Augenblick.** Für die Dauerkosten zählt
        der mittlere Preis der nächsten 24 Stunden; wer sie mit dem Preis dieser Minute bewertete,
        bekäme mittags eine andere Antwort als abends, obwohl sich an der Wirkung nichts geändert
        hat. Für das Verschieben zählen das günstigste und das teuerste Viertel derselben Stunden.
        """
        meta = await self._room_meta()
        if room_id not in self._room_ids(meta):
            raise DchError("unknown_room", f"Raum {room_id} ist nicht bekannt.", 404)
        info = self._room_name(meta, room_id)
        kreise_gesamt = sum(max(1, self._room_name(meta, r).circuits) for r in self._room_ids(meta))
        now = self.now
        aussen = self.live.measurement("outdoor_temp_c", now, 3600).value
        preise = [
            iv.price_ct_kwh
            for iv in (self.plan.intervals if self.plan else [])
            if iv.price_ct_kwh is not None and now <= iv.ts < now + timedelta(hours=24)
        ]
        mittel = sum(preise) / len(preise) if preise else None
        if mittel is None:
            mittel = self.live.measurement("electricity_price_ct_kwh", now, 3600).value
        wirkung = room_shift.effect(
            delta_k=delta_k,
            circuits=max(1, info.circuits),
            total_circuits=max(1, kreise_gesamt),
            cfg=self.hems.heat_demand,
            outdoor_c=aussen if aussen is not None else 7.0,
            price_ct_kwh=mittel,
            cheap_ct_kwh=min(preise) if preise else None,
            expensive_ct_kwh=max(preise) if preise else None,
        )
        return RoomEffectOut(
            room_id=room_id,
            name=info.name,
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
            outdoor_c=round(aussen if aussen is not None else 7.0, 1),
            price_ct_kwh=round(mittel, 1) if mittel is not None else None,
            cheap_ct_kwh=round(min(preise), 1) if preise else None,
            expensive_ct_kwh=round(max(preise), 1) if preise else None,
            note_de=wirkung.note_de,
        )

    async def rooms_history(self, start: datetime, end: datetime, step_min: int) -> RoomHistoryOut:
        """Die Tageszeitreihe der Räume, verdichtet auf Fenster von `step_min` Minuten.

        **Welche Räume gefragt werden, entscheidet die Gegenwart.** `minute_series` braucht die
        Reihennamen vorab - die Werte liegen in der JSON-Spalte `extra`, und danach lässt sich
        nicht nach „allen Räumen" suchen. Gefragt wird also nach den heute bekannten Räumen. Ein
        Raum, den jemand in Controme gelöscht hat, fehlt damit auch in den Tagen, in denen er noch
        gemessen hat; seine Werte sind nicht verloren, nur über diesen Weg nicht zu sehen.
        """
        meta = await self._room_meta()
        ids = self._room_ids(meta)
        if not ids:
            # Keine Räume, aber die Zeitachse gibt es trotzdem: die Anzeige soll einen leeren Tag
            # zeichnen können statt an einer fehlenden Achse zu scheitern.
            return RoomHistoryOut(
                start=start,
                end=end,
                step_min=step_min,
                ts=rooms.bucket_starts(start, end, step_min),
                rooms=[],
            )
        zeilen = await self.repos.minute_series(
            start, end, rooms.keys_for(ids, rooms.SERIES_FIELDS)
        )
        ts, reihen = rooms.condense(zeilen, ids, start, end, step_min)
        nach_id = {r.id: r for r in reihen}
        sortiert = sorted(ids, key=lambda i: rooms.sort_key(self._room_name(meta, i)))
        return RoomHistoryOut(
            start=start,
            end=end,
            step_min=step_min,
            ts=ts,
            rooms=[
                RoomSeriesOut(
                    id=i,
                    name=self._room_name(meta, i).name,
                    floor=self._room_name(meta, i).floor,
                    circuits=self._room_name(meta, i).circuits,
                    temp_c=nach_id[i].values["temp_c"],
                    setpoint_c=nach_id[i].values["setpoint_c"],
                    offset_k=nach_id[i].values["offset_k"],
                    valve=nach_id[i].values["valve"],
                    window=nach_id[i].values["window"],
                )
                for i in sortiert
            ],
        )

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
        return await self.accounting.heat_report(period, anchor, self.now, self._temps_48h())

    async def heat_balance(self, period: Period, anchor: date) -> HeatBalanceOut:
        return await self.accounting.heat_balance(period, anchor, self.now, self._temps_48h())

    async def update_heat_config(self, patch: HeatConfigIn) -> HemsConfig:
        """Geänderte Wärmeannahmen übernehmen, speichern und sofort wirksam machen."""
        werte = patch.model_dump(exclude_none=True)
        try:
            neu = apply_heat_patch(self.hems, werte)
        except ValueError as exc:
            raise DchError("invalid_config", str(exc), 422) from exc
        await self.repos.save_config("heat", werte, created_by="owner")
        self._apply_hems(neu)
        log.info("heat config updated", fields=sorted(werte))
        return neu

    def _apply_hems(self, neu: HemsConfig) -> None:
        """Die neue Konfiguration überall einsetzen, wo eine Referenz auf die alte liegt.

        Regler und Nachführung halten ihre Konfiguration als schlichtes Feld und lesen sie bei jedem
        Takt. Sie neu zu bauen wäre der naheliegende Weg und der falsche: dabei gingen Haltezeiten,
        Startzähler und die Entprellung verloren, und ein geänderter Heizwert von Pellets würde die
        Wärmepumpe anhalten.
        """
        self.hems = neu
        self.accounting.hems = neu
        self.live.cfg = neu
        self.controller.cfg = neu
        self.tracker.cfg = neu.heat_pump
        self.stove.cfg = neu.stove

    async def ev_report(self, period: Period, anchor: date) -> EvReportOut:
        return await self.accounting.ev_report(period, anchor, self.now)

    async def pv_report(self, period: Period, anchor: date) -> PvTaxReportOut:
        return await self.accounting.pv_report(period, anchor, self.now)

    async def shift_report(self, period: Period, anchor: date) -> ShiftReportOut:
        return await self.accounting.shift_report(period, anchor, self.now)

    async def year_map(self, year: int) -> YearMapOut:
        return await self.accounting.year_map(year, self.now)

    async def diagnose_day(self, day: date) -> str:
        return await self.accounting.diagnose_day(day)

    def export_csv(self, kind: str, start: datetime, end: datetime) -> AsyncIterator[str]:
        """Rohdaten eines Zeitraums als CSV-Strom. `kind` ist "minutes" oder "hours"."""
        if kind == "minutes":
            return self.repos.stream_minutes_csv(start, end)
        if kind == "hours":
            return self.repos.stream_hours_csv(start, end)
        raise DchError("invalid_kind", f"Unbekannter Export: {kind}", 422)

    async def check_invoice(self, payload: bytes, file_name: str | None) -> InvoiceReportOut:
        return await self.invoice_service.check(payload, file_name)

    async def invoices(self) -> list[InvoiceSummaryOut]:
        return await self.invoice_service.history()

    async def invoice(self, number: str) -> InvoiceReportOut | None:
        return await self.invoice_service.detail(number)

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

    async def _load_invoices(self) -> list[InvoiceReportOut]:
        return [
            InvoiceReportOut.model_validate(row.invoice | {"findings": row.findings})
            for row in await self.repos.tibber_invoices()
        ]

    async def _save_invoice(
        self, report: InvoiceReportOut, sha256: str, file_name: str | None
    ) -> None:
        inv = report.invoice
        await self.repos.upsert_tibber_invoice(
            {
                "number": inv.number,
                "issued_on": inv.issued_on,
                "period_start": inv.period_start,
                "period_end": inv.period_end,
                "period_label": inv.period_label,
                "kwh": inv.kwh,
                "total_net_eur": inv.total_net_eur,
                "total_gross_eur": inv.total_gross_eur,
                "avg_ct_kwh_gross": inv.avg_ct_kwh_gross,
                "verdict": report.verdict,
                "invoice": report.model_dump(mode="json", exclude={"findings"}),
                "findings": [f.model_dump(mode="json") for f in report.findings],
                "file_sha256": sha256,
                "file_name": file_name,
                "uploaded_at": datetime.now(UTC),
                "checked_at": report.checked_at,
            }
        )

    async def import_history(
        self,
        payload: bytes,
        kind: str,
        dry_run: bool,
        extra_map: dict[str, dict[str, Any]] | None,
        replace_until: datetime | None = None,
    ) -> ImportResult:
        rules = load_entity_rules(self.settings.import_entities_file, extra_map)
        if not rules:
            raise DchError(
                "config",
                f"Kein Entity-Mapping gefunden ({self.settings.import_entities_file}).",
                500,
            )
        prices = self.forecasts.price_provider
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
        result = await importer.run(payload, cast(Kind, kind), dry_run, replace_until)
        log.info("ha import", **result.model_dump(exclude={"entities", "unmapped"}, mode="json"))
        return result

    async def myenergi_backfill(
        self, hours: int, start: datetime | None = None, end: datetime | None = None
    ) -> BackfillResultOut:
        if self.myenergi is None:
            raise DchError(
                "config", "myenergi ist nicht konfiguriert (DCH_MYENERGI_SERIAL/_API_KEY).", 400
            )
        now = self.now
        if start is not None:
            start = start.astimezone(UTC) if start.tzinfo else start.replace(tzinfo=UTC)
            end = (
                (end.astimezone(UTC) if end.tzinfo else end.replace(tzinfo=UTC))
                if end is not None
                else start + timedelta(hours=hours)
            )
            end = min(end, now - timedelta(minutes=2), start + timedelta(days=62))
        else:
            start = now - timedelta(hours=max(1, min(hours, 24 * 14)))
            end = now - timedelta(minutes=2)
        if end <= start:
            raise DchError("validation", "Zeitraum leer.", 400)
        try:
            n = await self.myenergi.backfill(start, end)
        except Exception as exc:
            self.myenergi.last_backfill_error = repr(exc)[:200]
            return BackfillResultOut(ok=False, start=start, end=end, error_de=repr(exc)[:300])
        return BackfillResultOut(
            ok=True, readings=n, start=start, end=end, price_note_de=self.price_fill_note
        )

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

    async def _rollup_minutes(self, now: datetime) -> int:
        """Abgeschlossene Minuten aus den Rohwerten in den dauerhaften Bestand verdichten.

        Aufgeholt wird ab der letzten verdichteten Minute, ein paar Minuten überlappend: Rohwerte
        treffen mit dem Zeitstempel ihrer Quelle ein und können einer bereits verdichteten Minute
        nachträglich zufallen. Erneutes Verdichten ersetzt die Zeile, es entsteht nichts doppelt.

        Die laufende Minute bleibt aus: ihr Mittelwert wäre noch unvollständig, und er würde
        festgeschrieben, während weitere Messwerte noch unterwegs sind.
        """
        current = now.astimezone(UTC).replace(second=0, microsecond=0)
        last = await self.repos.last_minute_bucket()
        oldest_raw = await self.repos.oldest_raw_at()
        if oldest_raw is None:
            return 0
        begin = max(last - timedelta(minutes=5), oldest_raw) if last else oldest_raw
        if begin >= current:
            return 0
        # Tageweise, damit der erste Lauf über die ganzen Rohwerte nicht eine einzige riesige
        # Abfrage wird.
        total = 0
        cursor = begin
        while cursor < current:
            stop = min(cursor + timedelta(days=1), current)
            total += await self.repos.rollup_minutes(cursor, stop)
            cursor = stop
        return total

    async def _rebuild_energy_once(self) -> None:
        """Die gespeicherten Stundenbilanzen einmalig neu rechnen, wenn sich die Methode geändert hat.

        Eine Stundenbilanz trägt nicht bei sich, nach welchem Verfahren sie entstanden ist. Ändert
        sich das Verfahren - hier: Minutenlücken werden gehalten statt als null Energie gezählt -,
        bleiben alte Zeilen sonst für immer falsch, und die Jahresansicht zeigt eine Mischung aus
        zwei Rechnungen. Der Marker steht als Systemereignis in der Datenbank; er wird erst gesetzt,
        wenn der Durchlauf fertig ist, damit ein Absturz mittendrin ihn nicht überspringt.

        Läuft im Hintergrund und tageweise: ein Jahr sind über eine halbe Million Minutenzeilen.
        """
        # Die Kennung waechst mit dem Verfahren. v1 hielt Messwerte fuenf Minuten - das reicht fuer
        # einen Takt, nicht fuer eine Nacht ohne PV-Meldung; v2 laesst eine gemessene Null unbegrenzt
        # gelten; v3 ordnet Stunden, die es nur als Stundenmittel gibt, neu zu, statt ihnen Netzladung
        # anzudichten; v4 prueft die Ladung gegen ein Fuenf-Minuten-Fenster, weil Netzzaehler und
        # Speicher nicht im selben Moment melden; v5 laesst eine Rechnung aus echten Minutenwerten
        # eine importierte Stunde ersetzen, die nur deshalb 60 Minuten zaehlt, weil ein Stundenmittel
        # ausgerollt wurde; v6 gibt die PV zuerst dem Speicher und erst den Rest dem Haus. Wer die
        # Kennung nicht mitzieht, laesst die alten Zeilen stehen. v7 traegt den Stundenpreis nach
        # (`price_hours_ct`), ohne den der Vergleichslauf keine Stunde ohne Netzbezug bewerten kann.
        marker = "energy.rebuild_price_hours_v7"
        try:
            if await self.repos.has_event(marker):
                self.energy_rebuild = "erledigt"
                return
            # Ab der aeltesten gespeicherten Stunde, nicht ab der ersten Messung: die Stundentabelle
            # reicht weiter zurueck als jede Minutenzeile, weil der Historienimport Stunden direkt
            # geschrieben hat - und genau die sind hier zu korrigieren.
            start = await self.repos.first_energy_hour() or await self.repos.first_measurement_at()
            if start is None:
                self.energy_rebuild = "keine Daten"
                return
            began = self.now
            self.energy_rebuild = f"laeuft seit {began:%H:%M}"
            hours = await self.accounting.recompute(start, began, repair_coarse=True)
            self.energy_rebuild = f"{hours} Stunden neu gerechnet"
            await self.repos.add_event(
                "info",
                marker,
                f"{hours} Stundenbilanzen ab {start:%d.%m.%Y} neu gerechnet (Quellenzuordnung).",
                {"hours": hours},
            )
            log.info("energy hours rebuilt", hours=hours, since=start.isoformat())
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            # Ein stiller Fehlschlag hier ist der teuerste: die Zahlen bleiben falsch, und niemand
            # sieht warum. Deshalb steht der Grund im Zustand und im Ereignisprotokoll.
            self.energy_rebuild = f"fehlgeschlagen: {type(exc).__name__}"
            log.warning("energy rebuild failed", error=repr(exc)[:300])
            with contextlib.suppress(Exception):
                await self.repos.add_event("warning", "energy.rebuild_failed", repr(exc)[:300], {})

    async def _rollup_loop(self) -> None:
        while True:
            try:
                n = await self._rollup_minutes(self.now)
                if n:
                    log.info("minutes rolled up", rows=n)
            except Exception as exc:
                log.warning("minute rollup failed", error=repr(exc)[:200])
            await asyncio.sleep(300)

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

    # ------------------------------------------------------------------ Speicher
    def _battery_surplus_kw(self) -> float | None:
        """PV minus Hausverbrauch. None, wenn eine der beiden Groessen fehlt."""
        snap = self.live.snapshot(self.now)
        pv = snap.pv_power_kw.value
        house = snap.house_power_kw.value
        if pv is None or house is None:
            return None
        return float(pv) - float(house)

    def _battery_soc(self) -> float | None:
        m = self.live.measurement("battery_soc", self.now, 600.0)
        if m.value is None or m.quality not in (Quality.OK, Quality.STALE):
            return None
        return float(m.value)

    async def _apply_battery(self) -> None:
        """Den gewuenschten Befehl senden, wenn er sich geaendert hat.

        Nur bei Aenderung: die myenergi-Cloud ist kein Ort fuer einen Aufruf je Regeltakt. Scheitert
        der Befehl, bleibt `sent` stehen, damit der naechste Durchlauf es erneut versucht, und der
        Grund steht im Zustand - ein stiller Fehlschlag waere hier der teuerste.
        """
        want = self.battery.wanted(self.now, self._battery_soc(), self._battery_surplus_kw())
        if want is None or want == self.battery.sent:
            return
        if self.myenergi is None or not self.settings.actuation_enabled:
            self.battery_error = "Schalten nicht freigegeben."
            return
        try:
            await self.myenergi.set_libbi_mode(want)
        except Exception as exc:
            self.battery_error = repr(exc)[:200]
            log.warning("libbi mode failed", mode=want, error=self.battery_error)
            return
        self.battery.sent = want
        self.battery_sent_at = self.now
        self.battery_error = None
        log.info("libbi mode set", mode=want, reason=self.battery.reason_de)

    async def _battery_loop(self) -> None:
        while True:
            try:
                await self._apply_battery()
            except Exception as exc:
                log.warning("battery loop failed", error=repr(exc)[:200])
            await asyncio.sleep(60)

    def battery_state(self) -> BatteryLiveOut:
        return BatteryLiveOut(
            control_enabled=self.battery.controllable,
            mode=self.battery.effective_mode(self.now),
            ends_at=self.battery.ends_at,
            reserve_soc=self.battery.cfg.reserve_soc,
            soc=self._battery_soc(),
            command=self.battery.sent,
            sent_at=self.battery_sent_at,
            last_error=self.battery_error,
            note_de=self.battery.reason_de,
        )

    async def set_battery_mode(
        self, mode: BatteryMode, duration_min: int, reserve_soc: float | None
    ) -> BatteryLiveOut:
        """Den Speicher von Hand stellen. `off` nimmt einen Eingriff zurueck, ohne zu senden."""
        if not self.battery.controllable:
            raise DchError(
                "battery_control_disabled",
                "Die Steuerung des Speichers ist in der Konfiguration nicht freigegeben.",
                409,
            )
        if reserve_soc is not None:
            self.battery.cfg = self.battery.cfg.model_copy(update={"reserve_soc": reserve_soc})
        self.battery.set(mode, duration_min, self.now)
        await self._apply_battery()
        return self.battery_state()

    # ------------------------------------------------------------------ Laufzeit
    async def start(self) -> None:
        # Der gespeicherte Konfigurationsstand zuerst: alles danach soll ihn schon sehen.
        gespeichert = await self.repos.active_config("heat")
        if gespeichert:
            with contextlib.suppress(ValueError):
                self._apply_hems(apply_heat_patch(self.hems, gespeichert))
        self.live.apply(await self.repos.latest())
        stored = await self.repos.load_mode()
        if stored is not None:
            self.mode = stored
        await self._load_calibration()
        await self._load_watch_state()
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
                asyncio.create_task(self._battery_loop(), name="battery"),
                asyncio.create_task(self._rollup_loop(), name="rollup"),
                asyncio.create_task(self._rebuild_energy_once(), name="energy-rebuild"),
            ]
            if self.myenergi is not None:
                self.myenergi.start()
            if self.inexogy is not None:
                self.inexogy.start()
        log.info(
            "live runtime started",
            actuation=self.settings.actuation_enabled,
            heat_pump_actuation=self.settings.heat_pump_actuation_enabled,
        )

    async def stop(self) -> None:
        if self.inexogy is not None:
            await self.inexogy.stop()
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
                await self._watch_notify(self.now)
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
                # Erst verdichten, dann löschen. Andersherum verschwänden Rohwerte, deren Minute noch
                # nicht im dauerhaften Bestand steht - und die sind dann für immer weg.
                await self._rollup_minutes(self.now)
                deleted = await self.repos.prune_raw(
                    timedelta(days=self.settings.raw_retention_days)
                )
                log.info("raw pruned", rows=deleted)
