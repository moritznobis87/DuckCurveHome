"""Tests der Zustandsmaschine: Hysterese, Mindestlaufzeit, Mindestauszeit, PV-Überschuss, negative
Preise, Puffer voll, manuelle Übersteuerung, Sensorausfall, Tibber-Ausfall."""

from __future__ import annotations

from datetime import timedelta

from hc_helpers import T0, make_snapshot

from hems_core.control import ControlInputs, HeatPumpController, HeatPumpTracker
from hems_core.domain import (
    AutoProfile,
    BufferConfig,
    ControllerState,
    HemsConfig,
    OperatingMode,
    Override,
    OverrideKind,
    Quality,
    ReasonCode,
    SystemMode,
)
from hems_core.thermal import compute_buffer_state


class Harness:
    """Treibt Controller und Tracker mit einer synthetischen Wärmepumpe, die K1 folgt."""

    def __init__(
        self, cfg: HemsConfig | None = None, profile: AutoProfile = AutoProfile.SMART
    ) -> None:
        self.cfg = cfg or HemsConfig()
        self.ctrl = HeatPumpController(self.cfg)
        self.tracker = HeatPumpTracker(self.cfg.heat_pump)
        self.now = T0
        self.mode = OperatingMode(system_mode=SystemMode.AUTO, auto_profile=profile)
        self.hp_follows_k1 = True
        self.k1 = False
        self.last = None

    def step(
        self,
        minutes: float,
        *,
        tick_s: int = 10,
        price_rank: float | None = 0.5,
        price_age_s: float | None = 60.0,
        **snap_kw: object,
    ):
        steps = int(minutes * 60 / tick_s)
        for _ in range(steps):
            self.now += timedelta(seconds=tick_s)
            hp_power = snap_kw.pop("hp", None)
            if hp_power is None:
                hp_power = 3.6 if (self.k1 and self.hp_follows_k1) else 0.0
            snap = make_snapshot(at=self.now, hp=float(hp_power), release=self.k1, **snap_kw)  # type: ignore[arg-type]
            hp_state = self.tracker.update(snap.heat_pump_power_kw, self.k1, False, self.now)
            buf = compute_buffer_state(snap.buffer_temps_c, self.cfg.buffer)
            inp = ControlInputs(
                now=self.now,
                snapshot=snap,
                buffer=buf,
                hp=hp_state,
                mode=self.mode,
                price_rank=price_rank,
                price_age_s=price_age_s,
            )
            self.last = self.ctrl.tick(inp)
            self.k1 = self.last.k1_release
        return self.last


def test_pv_surplus_starts_only_after_on_delay() -> None:
    h = Harness()
    d = h.step(2, grid=-5.0)
    assert d.controller_state is ControllerState.ARMING
    assert not d.k1_release
    assert ReasonCode.ON_DELAY_PENDING in d.reasons
    d = h.step(4, grid=-5.0)
    assert d.k1_release
    assert d.controller_state in (ControllerState.RELEASED, ControllerState.RUNNING_RELEASED)
    assert d.reasons[0] is ReasonCode.PV_SURPLUS


def test_short_surplus_spike_does_not_start() -> None:
    h = Harness()
    h.step(2, grid=-6.0)
    d = h.step(3, grid=0.5)
    assert not d.k1_release
    assert d.controller_state is ControllerState.IDLE


def test_hysteresis_keeps_running_while_import_below_threshold() -> None:
    h = Harness()
    h.step(6, grid=-5.0)
    # Wärmepumpe läuft (3,6 kW), Netz leicht im Bezug: unter off_import_kw → weiter laufen
    d = h.step(40, grid=1.0)
    assert d.k1_release
    assert d.controller_state is ControllerState.RUNNING_RELEASED


def test_min_runtime_holds_release_despite_high_import() -> None:
    h = Harness()
    h.step(6, grid=-5.0)
    d = h.step(5, grid=3.0)  # sofort hoher Bezug, aber Mindestlaufzeit 30 min
    assert d.k1_release
    assert ReasonCode.MIN_RUNTIME_HOLD in d.reasons
    assert d.next_expected is not None and d.next_expected.action == "stop"


def test_stops_after_min_runtime_and_off_delay() -> None:
    h = Harness()
    h.step(6, grid=-5.0)
    h.step(31, grid=-5.0)
    d = h.step(14, grid=3.0)  # Bezug-EWMA braucht ~2 min, dann off_delay 10 min
    assert not d.k1_release
    assert d.controller_state is ControllerState.COOLDOWN
    assert d.reasons[0] is ReasonCode.PV_SURPLUS_FADING


def test_min_offtime_blocks_restart() -> None:
    h = Harness()
    h.step(6, grid=-5.0)
    h.step(31, grid=-5.0)
    h.step(14, grid=3.0)
    d = h.step(6, grid=-6.0)  # neuer Überschuss, aber Mindestauszeit 20 min
    assert not d.k1_release
    assert (
        ReasonCode.MIN_OFFTIME_PENDING in d.blocked_by
        or d.controller_state is ControllerState.COOLDOWN
    )
    d = h.step(22, grid=-6.0)
    assert d.k1_release or d.controller_state is ControllerState.ARMING


def test_negative_price_releases_without_pv() -> None:
    h = Harness(profile=AutoProfile.PRICE)
    d = h.step(6, grid=1.0, pv=0.0, price=-2.0, price_rank=0.0)
    assert d.k1_release
    assert d.reasons[0] is ReasonCode.PRICE_NEGATIVE


def test_cheap_window_releases_in_price_profile() -> None:
    h = Harness(profile=AutoProfile.PRICE)
    d = h.step(6, grid=1.0, pv=0.0, price=15.0, price_rank=0.05)
    assert d.k1_release
    assert d.reasons[0] is ReasonCode.PRICE_CHEAP_WINDOW


def test_pv_profile_ignores_price() -> None:
    h = Harness(profile=AutoProfile.PV)
    d = h.step(6, grid=1.0, pv=0.0, price=-2.0, price_rank=0.0)
    assert not d.k1_release


def test_buffer_full_prevents_start_and_stops_run() -> None:
    h = Harness()
    d = h.step(6, grid=-5.0, temps=(62.0, 62.0, 61.0, 61.0))
    assert not d.k1_release
    assert ReasonCode.BUFFER_FULL in d.blocked_by
    h2 = Harness()
    h2.step(6, grid=-5.0)
    d = h2.step(2, grid=-5.0, temps=(63.0, 60.0, 50.0, 40.0))
    assert not d.k1_release
    assert ReasonCode.BUFFER_FULL in d.reasons or ReasonCode.BUFFER_FULL in d.blocked_by
    assert "vollständig geladen" in d.explanation_de


def test_low_headroom_blocks_start() -> None:
    cfg = HemsConfig(buffer=BufferConfig(soc_full=0.99))
    h = Harness(cfg)
    d = h.step(6, grid=-5.0, temps=(61.0, 61.0, 61.0, 58.0))
    assert not d.k1_release
    assert ReasonCode.BUFFER_NO_HEADROOM in d.blocked_by


def test_manual_force_release_and_expiry() -> None:
    h = Harness()
    h.mode = OperatingMode(
        system_mode=SystemMode.AUTO,
        auto_profile=AutoProfile.SMART,
        override=Override(
            kind=OverrideKind.FORCE_RELEASE, started_at=T0, ends_at=T0 + timedelta(minutes=30)
        ),
    )
    d = h.step(1, grid=2.0, pv=0.0)
    assert d.k1_release
    assert d.controller_state is ControllerState.MANUAL
    assert "manuell" in d.explanation_de.lower()
    d = h.step(31, grid=2.0, pv=0.0)
    assert not d.k1_release
    assert d.controller_state is not ControllerState.MANUAL


def test_manual_force_off_blocks_pv_release() -> None:
    h = Harness()
    h.mode = OperatingMode(
        override=Override(
            kind=OverrideKind.FORCE_OFF, started_at=T0, ends_at=T0 + timedelta(hours=2)
        )
    )
    d = h.step(10, grid=-6.0)
    assert not d.k1_release
    assert ReasonCode.MANUAL_OVERRIDE in d.reasons


def test_manual_release_never_overheats_buffer() -> None:
    h = Harness()
    h.mode = OperatingMode(
        override=Override(
            kind=OverrideKind.FORCE_RELEASE, started_at=T0, ends_at=T0 + timedelta(hours=2)
        )
    )
    d = h.step(1, temps=(63.0, 62.0, 60.0, 55.0))
    assert not d.k1_release
    assert ReasonCode.BUFFER_FULL in d.blocked_by


def test_mode_off_never_releases() -> None:
    h = Harness()
    h.mode = OperatingMode(system_mode=SystemMode.OFF)
    d = h.step(10, grid=-6.0)
    assert not d.k1_release
    assert d.controller_state is ControllerState.OFF


def test_sensor_unavailable_blocks_start() -> None:
    h = Harness()
    d = h.step(6, grid=-6.0, grid_quality=Quality.UNAVAILABLE)
    assert not d.k1_release
    assert ReasonCode.SENSOR_UNAVAILABLE in d.blocked_by


def test_sensor_stale_during_run_ends_release_after_grace() -> None:
    h = Harness()
    h.step(6, grid=-5.0)
    d = h.step(3, grid=-5.0, grid_quality=Quality.STALE)
    assert d.k1_release  # Karenz 5 min
    d = h.step(3, grid=-5.0, grid_quality=Quality.STALE)
    assert not d.k1_release
    assert ReasonCode.SENSOR_STALE in d.blocked_by
    assert d.controller_state is ControllerState.COOLDOWN


def test_tibber_outage_pauses_price_rules_but_not_pv() -> None:
    h = Harness(profile=AutoProfile.SMART)
    d = h.step(6, grid=1.0, pv=0.0, price=-5.0, price_rank=None, price_age_s=None)
    assert not d.k1_release
    assert ReasonCode.PRICE_DATA_STALE in d.blocked_by
    d = h.step(10, grid=-6.0, price=None, price_rank=None, price_age_s=None)  # EWMA + on_delay
    assert d.k1_release
    assert d.reasons[0] is ReasonCode.PV_SURPLUS


def test_hp_not_responding_backs_off() -> None:
    h = Harness()
    h.hp_follows_k1 = False
    d = h.step(6, grid=-5.0)
    assert d.k1_release
    d = h.step(11, grid=-5.0)
    assert not d.k1_release
    assert ReasonCode.HP_NOT_RESPONDING in d.blocked_by
    assert "nicht reagiert" in d.explanation_de


def test_never_both_contacts() -> None:
    h = Harness()
    for _ in range(60):
        d = h.step(1, grid=-5.0)
        assert not (d.k1_release and d.k2_block)
        assert d.k2_block is False


def test_toggle_rate_triggers_failsafe() -> None:
    cfg = HemsConfig()
    h = Harness(cfg)
    # Künstlich viele Schaltwechsel erzeugen: Override an/aus im Wechsel
    for _ in range(6):
        h.mode = OperatingMode(
            override=Override(
                kind=OverrideKind.FORCE_RELEASE,
                started_at=h.now,
                ends_at=h.now + timedelta(minutes=1),
            )
        )
        h.step(1)
        h.mode = OperatingMode()
        d = h.step(1, grid=0.0, pv=0.0)
    assert d.controller_state is ControllerState.FAILSAFE
    assert not d.k1_release


def test_every_reason_code_has_explanation_text() -> None:
    from hems_core.control.explain import explain
    from hems_core.domain import DecisionInputs

    inputs = DecisionInputs(
        surplus_ewma_kw=0.0,
        import_ewma_kw=0.0,
        hp_running=False,
        hp_power_kw=0.0,
        buffer_soc=0.5,
        buffer_top_c=50.0,
        price_ct_kwh=20.0,
        price_rank=0.5,
        outdoor_temp_c=10.0,
        starts_today=0,
        seconds_since_stop=0.0,
        seconds_since_start=None,
    )
    for code in ReasonCode:
        text = explain(
            ControllerState.IDLE, [code], [code], inputs, min_offtime_s=1200, min_runtime_s=1800
        )
        assert isinstance(text, str) and len(text) > 10
