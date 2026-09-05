"""Deutsche Erklärungssätze aus Reason-Codes und Eingangsgrößen."""

from __future__ import annotations

from datetime import datetime

from hems_core.domain.decision import ControllerState, DecisionInputs, ReasonCode


def _minutes(seconds: float | None) -> int:
    return round((seconds or 0) / 60.0)


def explain(
    state: ControllerState,
    reasons: list[ReasonCode],
    blocked_by: list[ReasonCode],
    inputs: DecisionInputs,
    *,
    min_offtime_s: float,
    min_runtime_s: float,
    override_ends: datetime | None = None,
) -> str:
    main = reasons[0] if reasons else None
    block = blocked_by[0] if blocked_by else None
    soc = f"{round((inputs.buffer_soc or 0) * 100)} %"

    if state is ControllerState.OFF:
        return "Duck Curve Home beobachtet nur – Wärmepumpe regelt sich selbst."
    if state is ControllerState.FAILSAFE:
        return "Sicherheitsmodus – alle Eingriffe zurückgenommen, Wärmepumpe regelt sich selbst."
    if state is ControllerState.MANUAL:
        ends = f" bis {override_ends.astimezone().strftime('%H:%M')}" if override_ends else ""
        if ReasonCode.MANUAL_OVERRIDE in reasons and inputs.hp_running:
            return f"Wärmepumpe läuft – manuelle Freigabe{ends}."
        return f"Manuelle Übersteuerung aktiv{ends}."

    if state is ControllerState.RUNNING_RELEASED:
        if main is ReasonCode.PV_SURPLUS:
            return "Wärmepumpe läuft – PV-Überschuss wird genutzt."
        if main is ReasonCode.PRICE_NEGATIVE:
            return "Wärmepumpe läuft – negativer Strompreis."
        if main is ReasonCode.PRICE_CHEAP_WINDOW:
            return "Wärmepumpe läuft – Strompreis im günstigsten Tagesfenster."
        if main is ReasonCode.MIN_RUNTIME_HOLD:
            rest = _minutes(min_runtime_s - (inputs.seconds_since_start or 0))
            return f"Wärmepumpe läuft weiter – Mindestlaufzeit noch {rest} Minuten."
        return "Wärmepumpe läuft mit Freigabe."
    if state is ControllerState.RELEASED:
        return "Freigabe gesetzt – Wärmepumpe sollte in Kürze anlaufen."
    if state is ControllerState.ARMING:
        if main is ReasonCode.PV_SURPLUS:
            return "Wärmepumpe startet gleich – PV-Überschuss muss noch kurz stabil bleiben."
        return "Wärmepumpe startet gleich – Bedingung muss noch kurz stabil bleiben."
    if state is ControllerState.COOLDOWN:
        if main is ReasonCode.BUFFER_FULL:
            return "Wärmepumpe aus – Pufferspeicher vollständig geladen."
        if main in (ReasonCode.SENSOR_STALE, ReasonCode.SENSOR_UNAVAILABLE):
            return "Freigabe zurückgenommen – Messwerte fehlen oder sind veraltet."
        rest = _minutes(min_offtime_s - (inputs.seconds_since_stop or 0))
        return f"Wärmepumpe wartet – Mindeststillstandszeit noch {max(rest, 1)} Minuten."

    # IDLE
    if inputs.hp_running:
        return "Wärmepumpe läuft in eigener Regelung – kein Eingriff nötig."
    if block is ReasonCode.BUFFER_FULL:
        return "Wärmepumpe aus – Pufferspeicher vollständig geladen."
    if block is ReasonCode.BUFFER_NO_HEADROOM:
        return f"Wärmepumpe aus – Pufferspeicher mit {soc} nahezu voll."
    if block is ReasonCode.MIN_OFFTIME_PENDING:
        rest = _minutes(min_offtime_s - (inputs.seconds_since_stop or 0))
        return f"Wärmepumpe wartet – Mindeststillstandszeit noch {max(rest, 1)} Minuten."
    if block is ReasonCode.HP_NOT_RESPONDING:
        return "Wärmepumpe hat auf die Freigabe nicht reagiert – nächster Versuch später."
    if block is ReasonCode.MAX_STARTS_REACHED:
        return "Wärmepumpe aus – maximale Anzahl Starts für heute erreicht."
    if block in (ReasonCode.SENSOR_STALE, ReasonCode.SENSOR_UNAVAILABLE):
        return "Keine Freigabe – Messwerte fehlen oder sind veraltet."
    if block is ReasonCode.PRICE_DATA_STALE:
        return "Preisregeln pausiert – Strompreise veraltet; PV-Regel bleibt aktiv."
    if main is ReasonCode.PV_SURPLUS_FADING:
        return "Wärmepumpe aus – PV-Überschuss reicht nicht mehr."
    return "Wärmepumpe aus – kein nutzbarer Überschuss und kein günstiges Preisfenster."
