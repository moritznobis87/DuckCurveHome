"""Regelbasierter Wärmepumpen-Controller (Stufe 1) – K1-Pfad.

Zustandsmaschine (siehe HEMS_CONTROL.md):
  IDLE → ARMING → RELEASED → RUNNING_RELEASED → COOLDOWN → IDLE
Der Controller entscheidet nur über die Kontakte K1 (Freigabe) und K2 (Sperre, in dieser Stufe
immer aus). Er steuert keine internen Parameter der Wärmepumpe. Jede Entscheidung trägt
Reason-Codes, Blocker, Eingangsgrößen und eine Gültigkeit (TTL).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta

from hems_core.balance.energy_balance import pv_surplus_kw
from hems_core.control.explain import explain
from hems_core.control.smoothing import Ewma
from hems_core.domain.buffer import BufferState
from hems_core.domain.config import HemsConfig
from hems_core.domain.decision import (
    ControllerState,
    Decision,
    DecisionInputs,
    NextExpected,
    ReasonCode,
)
from hems_core.domain.heat_pump import HeatPumpState
from hems_core.domain.modes import AutoProfile, OperatingMode, OverrideKind, SystemMode
from hems_core.domain.snapshot import EnergySnapshot


@dataclass(frozen=True)
class ControlInputs:
    now: datetime
    snapshot: EnergySnapshot
    buffer: BufferState
    hp: HeatPumpState
    mode: OperatingMode
    price_rank: float | None  # 0 günstigst … 1 teuerst, None ohne Preisreihe
    price_age_s: float | None  # Alter der Preisreihe
    next_cheap_window_start: datetime | None = None
    planned_release: bool = False


@dataclass
class HeatPumpController:
    cfg: HemsConfig
    state: ControllerState = ControllerState.IDLE
    surplus_ewma: Ewma = field(init=False)
    import_ewma: Ewma = field(init=False)
    arming_since: datetime | None = None
    released_at: datetime | None = None
    hold_broken_since: datetime | None = None
    sensor_bad_since: datetime | None = None
    not_responding_until: datetime | None = None
    failsafe_until: datetime | None = None
    cooldown_reason: ReasonCode | None = None
    cooldown_since: datetime | None = None
    last_decision: Decision | None = None
    _k1_changes: list[datetime] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.surplus_ewma = Ewma(self.cfg.control.ewma_seconds)
        self.import_ewma = Ewma(self.cfg.control.ewma_seconds)

    # ------------------------------------------------------------------ Hilfen
    def _seconds(self, since: datetime | None, now: datetime) -> float | None:
        return None if since is None else (now - since).total_seconds()

    def _buffer_full(self, inp: ControlInputs) -> bool:
        top = inp.snapshot.buffer_temps_c.top
        if top.usable and top.value_or(0.0) >= self.cfg.buffer.max_temperature_c:
            return True
        return inp.buffer.soc is not None and inp.buffer.soc >= self.cfg.buffer.soc_full

    def _sensors_ok(self, inp: ControlInputs) -> list[ReasonCode]:
        codes: list[ReasonCode] = []
        needed = [inp.snapshot.grid_power_kw, inp.snapshot.heat_pump_power_kw]
        needed += inp.snapshot.buffer_temps_c.as_list()
        for m in needed:
            if not m.usable:
                code = (
                    ReasonCode.SENSOR_STALE
                    if m.quality.value == "stale"
                    else ReasonCode.SENSOR_UNAVAILABLE
                )
                if code not in codes:
                    codes.append(code)
        return codes

    def _price_fresh(self, inp: ControlInputs) -> bool:
        if inp.price_age_s is None or inp.price_rank is None:
            return False
        return inp.price_age_s <= self.cfg.control.price.price_max_age_h * 3600.0

    def _triggers(self, inp: ControlInputs, surplus: float | None) -> list[ReasonCode]:
        codes: list[ReasonCode] = []
        profile = inp.mode.auto_profile
        pv_cfg = self.cfg.control.pv
        if surplus is not None and surplus >= pv_cfg.on_surplus_kw:
            codes.append(ReasonCode.PV_SURPLUS)
        if profile in (AutoProfile.PRICE, AutoProfile.SMART) and self._price_fresh(inp):
            price = inp.snapshot.electricity_price_ct_kwh
            if (
                self.cfg.control.price.negative_price_release
                and price.usable
                and price.value_or(0.0) < 0
            ):
                codes.append(ReasonCode.PRICE_NEGATIVE)
            elif (
                inp.price_rank is not None
                and inp.price_rank <= self.cfg.control.price.cheap_quantile
            ):
                codes.append(ReasonCode.PRICE_CHEAP_WINDOW)
        if profile is AutoProfile.SMART and inp.planned_release:
            codes.append(ReasonCode.PLANNED_WINDOW)
        return codes

    def _hold(self, inp: ControlInputs, import_ewma: float | None) -> tuple[bool, list[ReasonCode]]:
        """Haltebedingung im Lauf: nicht zu viel Bezug ODER Preisgrund weiter aktiv."""
        codes: list[ReasonCode] = []
        pv_ok = import_ewma is not None and import_ewma <= self.cfg.control.pv.off_import_kw
        if pv_ok:
            codes.append(ReasonCode.PV_SURPLUS)
        price_codes = [
            c
            for c in self._triggers(inp, None)
            if c
            in (ReasonCode.PRICE_NEGATIVE, ReasonCode.PRICE_CHEAP_WINDOW, ReasonCode.PLANNED_WINDOW)
        ]
        codes += price_codes
        return (pv_ok or bool(price_codes)), codes

    def _record_k1(self, k1: bool, now: datetime) -> None:
        prev = self.last_decision.k1_release if self.last_decision else False
        if k1 != prev:
            self._k1_changes.append(now)
        cutoff = now - timedelta(hours=1)
        self._k1_changes = [t for t in self._k1_changes if t >= cutoff]

    # ------------------------------------------------------------------ Tick
    def tick(self, inp: ControlInputs) -> Decision:
        now = inp.now
        cfg = self.cfg
        hp_cfg = cfg.heat_pump
        snap = inp.snapshot

        raw_surplus = pv_surplus_kw(
            grid=snap.grid_power_kw,
            battery=snap.battery_power_kw,
            battery_soc=snap.battery_soc,
            ev=snap.ev_power_kw,
            heat_pump=snap.heat_pump_power_kw,
            cfg=cfg.control.pv,
        )
        surplus = self.surplus_ewma.update(raw_surplus, now)
        imp = self.import_ewma.update(snap.import_kw if snap.grid_power_kw.usable else None, now)

        since_stop = self._seconds(inp.hp.stopped_since, now)
        since_start = self._seconds(inp.hp.running_since, now)
        inputs = DecisionInputs(
            surplus_ewma_kw=None if surplus is None else round(surplus, 3),
            import_ewma_kw=None if imp is None else round(imp, 3),
            hp_running=inp.hp.running,
            hp_power_kw=inp.hp.power_kw,
            buffer_soc=inp.buffer.soc,
            buffer_top_c=snap.buffer_temps_c.top.value,
            price_ct_kwh=snap.electricity_price_ct_kwh.value,
            price_rank=inp.price_rank,
            outdoor_temp_c=snap.outdoor_temp_c.value,
            starts_today=inp.hp.starts_today,
            seconds_since_stop=since_stop,
            seconds_since_start=since_start,
        )

        reasons: list[ReasonCode] = []
        blocked: list[ReasonCode] = []
        k1 = False
        nxt: NextExpected | None = None
        override_ends: datetime | None = None
        min_off = hp_cfg.min_offtime_min * 60.0
        min_run = hp_cfg.min_runtime_min * 60.0

        # 1) Failsafe
        if self.failsafe_until is not None and now < self.failsafe_until:
            self.state = ControllerState.FAILSAFE
            reasons = [ReasonCode.FAILSAFE]
        elif self.failsafe_until is not None:
            self.failsafe_until = None
            self.state = ControllerState.IDLE

        # 2) Modus OFF
        if self.state is not ControllerState.FAILSAFE and inp.mode.system_mode is SystemMode.OFF:
            self.state = ControllerState.OFF
            reasons = [ReasonCode.MODE_OFF]

        # 3) Manuelle Übersteuerung
        elif self.state is not ControllerState.FAILSAFE and (
            inp.mode.override is not None and inp.mode.override.active(now)
        ):
            ov = inp.mode.override
            override_ends = ov.ends_at
            self.state = ControllerState.MANUAL
            reasons = [ReasonCode.MANUAL_OVERRIDE]
            if ov.kind is OverrideKind.FORCE_RELEASE:
                if self._buffer_full(inp):
                    blocked = [ReasonCode.BUFFER_FULL]
                else:
                    k1 = True
            # FORCE_OFF und FORCE_BLOCK: K1 aus; K2 bleibt in Stufe 1 immer aus.

        elif self.state is not ControllerState.FAILSAFE:
            if self.state in (ControllerState.OFF, ControllerState.MANUAL):
                self.state = ControllerState.IDLE
                self.hold_broken_since = None
                self.arming_since = None

            sensor_codes = self._sensors_ok(inp)
            if sensor_codes:
                self.sensor_bad_since = self.sensor_bad_since or now
            else:
                self.sensor_bad_since = None
            grace_exceeded = (
                self.sensor_bad_since is not None
                and (now - self.sensor_bad_since).total_seconds()
                >= cfg.control.sensor_grace_min * 60
            )

            triggers = self._triggers(inp, surplus)
            full = self._buffer_full(inp)
            headroom_low = (
                inp.buffer.headroom_soc is not None
                and inp.buffer.headroom_soc < cfg.control.pv.min_buffer_headroom_soc
            )

            start_blockers: list[ReasonCode] = []
            if sensor_codes:
                start_blockers += sensor_codes
            if full:
                start_blockers.append(ReasonCode.BUFFER_FULL)
            elif headroom_low:
                start_blockers.append(ReasonCode.BUFFER_NO_HEADROOM)
            if not inp.hp.running and since_stop is not None and since_stop < min_off:
                start_blockers.append(ReasonCode.MIN_OFFTIME_PENDING)
            if inp.hp.starts_today >= hp_cfg.max_starts_per_day:
                start_blockers.append(ReasonCode.MAX_STARTS_REACHED)
            if self.not_responding_until is not None and now < self.not_responding_until:
                start_blockers.append(ReasonCode.HP_NOT_RESPONDING)
            price_stale = inp.mode.auto_profile in (
                AutoProfile.PRICE,
                AutoProfile.SMART,
            ) and not self._price_fresh(inp)

            if self.state in (ControllerState.IDLE, ControllerState.COOLDOWN):
                if self.state is ControllerState.COOLDOWN:
                    self.cooldown_since = self.cooldown_since or now
                    in_cooldown_s = (now - self.cooldown_since).total_seconds()
                    # Läuft die Wärmepumpe 5 min nach Rücknahme der Freigabe weiter, ist das ihre
                    # eigene Regelung – der Regler geht zurück in IDLE und beobachtet.
                    own_control = inp.hp.running and in_cooldown_s > 300
                    rested = not inp.hp.running and (since_stop is None or since_stop >= min_off)
                    if own_control or rested:
                        self.state = ControllerState.IDLE
                        self.cooldown_reason = None
                        self.cooldown_since = None
                if self.state is ControllerState.COOLDOWN:
                    lead = [self.cooldown_reason] if self.cooldown_reason else []
                    if full and ReasonCode.BUFFER_FULL not in lead:
                        lead.append(ReasonCode.BUFFER_FULL)
                    reasons = [*lead, ReasonCode.MIN_OFFTIME_PENDING]
                    blocked = [*lead, ReasonCode.MIN_OFFTIME_PENDING]
                    if inp.hp.stopped_since is not None:
                        nxt = NextExpected(
                            action="start",
                            at=inp.hp.stopped_since + timedelta(seconds=min_off),
                            because=ReasonCode.MIN_OFFTIME_PENDING,
                            text_de="frühester nächster Start",
                        )
                elif triggers and not start_blockers:
                    self.state = ControllerState.ARMING
                    self.arming_since = now
                    reasons = triggers
                    reasons.append(ReasonCode.ON_DELAY_PENDING)
                    nxt = NextExpected(
                        action="start",
                        at=now + timedelta(minutes=cfg.control.pv.on_delay_min),
                        because=triggers[0],
                        text_de="Start, wenn Bedingung stabil bleibt",
                    )
                else:
                    blocked = (
                        start_blockers if triggers else [ReasonCode.NO_TRIGGER, *start_blockers]
                    )
                    if inp.hp.running:
                        reasons = [ReasonCode.HP_RUNNING_OWN_CONTROL]
                    elif triggers:
                        reasons = triggers
                    elif (
                        self.last_decision is not None
                        and self.last_decision.reasons
                        and self.last_decision.reasons[0] is ReasonCode.PV_SURPLUS
                    ):
                        reasons = [ReasonCode.PV_SURPLUS_FADING]
                    else:
                        reasons = [ReasonCode.NO_TRIGGER]
                    if price_stale:
                        blocked.append(ReasonCode.PRICE_DATA_STALE)
                    if inp.next_cheap_window_start is not None and not inp.hp.running:
                        nxt = NextExpected(
                            action="window_start",
                            at=inp.next_cheap_window_start,
                            because=ReasonCode.PRICE_CHEAP_WINDOW,
                            text_de="nächstes günstiges Preisfenster",
                        )

            elif self.state is ControllerState.ARMING:
                if triggers and not start_blockers and self.arming_since is not None:
                    held = (now - self.arming_since).total_seconds()
                    if held >= cfg.control.pv.on_delay_min * 60:
                        self.state = ControllerState.RELEASED
                        self.released_at = now
                        k1 = True
                        reasons = triggers
                    else:
                        reasons = [*triggers, ReasonCode.ON_DELAY_PENDING]
                        nxt = NextExpected(
                            action="start",
                            at=self.arming_since + timedelta(minutes=cfg.control.pv.on_delay_min),
                            because=triggers[0],
                            text_de="Start, wenn Bedingung stabil bleibt",
                        )
                else:
                    self.state = ControllerState.IDLE
                    self.arming_since = None
                    reasons = triggers if triggers else [ReasonCode.PV_SURPLUS_FADING]
                    blocked = start_blockers or [ReasonCode.NO_TRIGGER]

            elif self.state is ControllerState.RELEASED:
                if full or (sensor_codes and grace_exceeded):
                    self.state = ControllerState.IDLE
                    blocked = [ReasonCode.BUFFER_FULL] if full else sensor_codes
                    reasons = [ReasonCode.PV_SURPLUS_FADING]
                elif inp.hp.running:
                    self.state = ControllerState.RUNNING_RELEASED
                    k1 = True
                    reasons = triggers or [ReasonCode.PV_SURPLUS]
                elif (
                    self.released_at is not None
                    and (now - self.released_at).total_seconds() >= hp_cfg.start_timeout_min * 60
                ):
                    self.state = ControllerState.IDLE
                    self.not_responding_until = now + timedelta(
                        minutes=2 * hp_cfg.start_timeout_min
                    )
                    reasons = [ReasonCode.HP_NOT_RESPONDING]
                    blocked = [ReasonCode.HP_NOT_RESPONDING]
                else:
                    k1 = True
                    reasons = triggers or [ReasonCode.PV_SURPLUS]
                    if self.released_at is not None:
                        nxt = NextExpected(
                            action="start",
                            at=self.released_at + timedelta(minutes=hp_cfg.start_timeout_min),
                            because=ReasonCode.HP_NOT_RESPONDING,
                            text_de="spätester erwarteter Anlauf",
                        )

            elif self.state is ControllerState.RUNNING_RELEASED:
                hold_ok, hold_codes = self._hold(inp, imp)
                runtime_ok = since_start is not None and since_start >= min_run
                if full:
                    self.state = ControllerState.COOLDOWN
                    self.cooldown_reason = ReasonCode.BUFFER_FULL
                    reasons = [ReasonCode.BUFFER_FULL]
                    blocked = [ReasonCode.BUFFER_FULL]
                elif sensor_codes and grace_exceeded:
                    self.state = ControllerState.COOLDOWN
                    self.cooldown_reason = sensor_codes[0]
                    reasons = sensor_codes
                    blocked = sensor_codes
                elif not inp.hp.running and since_stop is not None and since_stop > 120:
                    # Wärmepumpe hat selbst abgeschaltet – Freigabe zurücknehmen
                    self.state = ControllerState.COOLDOWN
                    self.cooldown_reason = ReasonCode.HP_RUNNING_OWN_CONTROL
                    reasons = [ReasonCode.MIN_OFFTIME_PENDING]
                elif hold_ok:
                    self.hold_broken_since = None
                    k1 = True
                    reasons = hold_codes
                    if not runtime_ok and inp.hp.running_since is not None:
                        nxt = NextExpected(
                            action="stop",
                            at=inp.hp.running_since + timedelta(seconds=min_run),
                            because=ReasonCode.MIN_RUNTIME_HOLD,
                            text_de="frühestes reguläres Ende",
                        )
                else:
                    self.hold_broken_since = self.hold_broken_since or now
                    broken_for = (now - self.hold_broken_since).total_seconds()
                    if not runtime_ok:
                        k1 = True
                        reasons = [ReasonCode.MIN_RUNTIME_HOLD, ReasonCode.IMPORT_TOO_HIGH]
                        if inp.hp.running_since is not None:
                            nxt = NextExpected(
                                action="stop",
                                at=inp.hp.running_since + timedelta(seconds=min_run),
                                because=ReasonCode.MIN_RUNTIME_HOLD,
                                text_de="Ende nach Mindestlaufzeit",
                            )
                    elif broken_for < cfg.control.pv.off_delay_min * 60:
                        k1 = True
                        reasons = [ReasonCode.PV_SURPLUS_FADING, ReasonCode.OFF_DELAY_PENDING]
                        nxt = NextExpected(
                            action="stop",
                            at=self.hold_broken_since
                            + timedelta(minutes=cfg.control.pv.off_delay_min),
                            because=ReasonCode.IMPORT_TOO_HIGH,
                            text_de="Ende, wenn Überschuss ausbleibt",
                        )
                    else:
                        self.state = ControllerState.COOLDOWN
                        self.cooldown_reason = ReasonCode.PV_SURPLUS_FADING
                        self.hold_broken_since = None
                        reasons = [ReasonCode.PV_SURPLUS_FADING, ReasonCode.IMPORT_TOO_HIGH]

        # Guards, die immer gelten
        k2 = False  # Stufe 1: Sperre nie
        if k1 and k2:
            k1 = False
        if self.state is ControllerState.FAILSAFE:
            k1 = False

        # Schalthäufigkeit
        self._record_k1(k1, now)
        if len(self._k1_changes) > cfg.control.max_toggles_per_hour:
            self.failsafe_until = now + timedelta(minutes=cfg.control.failsafe_hold_min)
            self.state = ControllerState.FAILSAFE
            k1 = False
            reasons = [ReasonCode.FAILSAFE, ReasonCode.TOGGLE_RATE_EXCEEDED]
            blocked = [ReasonCode.TOGGLE_RATE_EXCEEDED]
            self._k1_changes.clear()

        text = explain(
            self.state,
            reasons,
            blocked,
            inputs,
            min_offtime_s=min_off,
            min_runtime_s=min_run,
            override_ends=override_ends,
        )
        prev = self.last_decision
        changed = (
            prev is None
            or prev.controller_state is not self.state
            or prev.k1_release != k1
            or prev.k2_block != k2
            or prev.reasons[:1] != reasons[:1]
        )
        decision = Decision(
            at=now,
            controller_state=self.state,
            k1_release=k1,
            k2_block=k2,
            reasons=reasons,
            blocked_by=blocked,
            inputs=inputs,
            valid_until=now + timedelta(minutes=hp_cfg.release_ttl_min),
            next_expected=nxt,
            explanation_de=text,
            changed=changed,
        )
        self.last_decision = decision
        return decision
