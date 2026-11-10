"""Der Satz der Startseite: was die Wärmepumpe gerade tut und warum, in Alltagssprache.

Diese Sätze stehen groß oben auf der Startseite und liest jeder im Haus. Bis zum 11.11.2026
sprachen sie die Sprache des Reglers („Wärmepumpe aus - kein nutzbarer Überschuss und kein
günstiges Preisfenster", „Freigabe gesetzt", „Mindeststillstandszeit"). Jetzt gilt:

- Ganze Sätze, die mit der Wärmepumpe beginnen, wo es um sie geht.
- Keine Wörter des Reglers: nicht Freigabe, Überschuss, Preisfenster, Übersteuerung,
  Mindestlaufzeit. Stattdessen, was gemeint ist: Sonne, günstiger Strom, Pause.
- Ein Grund, kein Zustand: „weil Strom jetzt am günstigsten ist", nicht „Preisfenster aktiv".

Die Kennungen (`ReasonCode`) bleiben, wie sie sind; an ihnen hängen Auswertung und Tests.
"""

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
    voll = "Die Wärmepumpe ist aus: der Pufferspeicher ist voll."

    def pause() -> str:
        rest = _minutes(min_offtime_s - (inputs.seconds_since_stop or 0))
        minuten = "1 Minute" if max(rest, 1) == 1 else f"{max(rest, 1)} Minuten"
        return f"Die Wärmepumpe macht noch {minuten} Pause. Das schont die Maschine."

    if state is ControllerState.OFF:
        return "Duck Curve Home schaut nur zu. Die Wärmepumpe regelt sich selbst."
    if state is ControllerState.FAILSAFE:
        return (
            "Sicherheitsmodus: Duck Curve Home greift nicht ein, die Wärmepumpe regelt sich selbst."
        )
    if state is ControllerState.MANUAL:
        ends = f" bis {override_ends.astimezone().strftime('%H:%M')}" if override_ends else ""
        if ReasonCode.MANUAL_OVERRIDE in reasons and inputs.hp_running:
            return f"Die Wärmepumpe läuft, von Hand eingeschaltet{ends}."
        return f"Von Hand eingestellt{ends}. So lange pausiert die Automatik."

    if state is ControllerState.RUNNING_RELEASED:
        if main is ReasonCode.PV_SURPLUS:
            return "Die Wärmepumpe läuft mit Strom vom eigenen Dach."
        if main is ReasonCode.PRICE_NEGATIVE:
            return "Die Wärmepumpe läuft, weil der Strompreis gerade unter null liegt."
        if main is ReasonCode.PRICE_CHEAP_WINDOW:
            return "Die Wärmepumpe läuft, weil Strom jetzt am günstigsten ist."
        if main is ReasonCode.MIN_RUNTIME_HOLD:
            rest = _minutes(min_runtime_s - (inputs.seconds_since_start or 0))
            minuten = "1 Minute" if rest == 1 else f"{rest} Minuten"
            return (
                f"Die Wärmepumpe läuft noch mindestens {minuten} weiter, "
                "damit sie nicht ständig an- und ausgeht."
            )
        return "Die Wärmepumpe läuft, von Duck Curve Home angefordert."
    if state is ControllerState.RELEASED:
        return "Die Wärmepumpe ist angefordert und sollte gleich anlaufen."
    if state is ControllerState.ARMING:
        if main is ReasonCode.PV_SURPLUS:
            return "Die Wärmepumpe startet gleich, wenn die Sonne noch kurz so stark bleibt."
        return "Die Wärmepumpe startet gleich, wenn sich in den nächsten Minuten nichts ändert."
    if state is ControllerState.COOLDOWN:
        if main is ReasonCode.BUFFER_FULL:
            return voll
        if main in (ReasonCode.SENSOR_STALE, ReasonCode.SENSOR_UNAVAILABLE):
            return "Die Wärmepumpe wird nicht mehr angefordert, weil Messwerte fehlen."
        return pause()

    # IDLE
    if inputs.hp_running:
        return "Die Wärmepumpe läuft von sich aus. Duck Curve Home muss nichts tun."
    if block is ReasonCode.BUFFER_FULL:
        return voll
    if block is ReasonCode.BUFFER_NO_HEADROOM:
        return f"Die Wärmepumpe ist aus: der Pufferspeicher ist mit {soc} fast voll."
    if block is ReasonCode.MIN_OFFTIME_PENDING:
        return pause()
    if block is ReasonCode.HP_NOT_RESPONDING:
        return "Die Wärmepumpe ist trotz Anforderung nicht angelaufen. Der nächste Versuch folgt."
    if block is ReasonCode.MAX_STARTS_REACHED:
        return "Die Wärmepumpe ist aus: für heute ist sie oft genug gestartet."
    if block in (ReasonCode.SENSOR_STALE, ReasonCode.SENSOR_UNAVAILABLE):
        return "Die Wärmepumpe wird nicht angefordert, weil Messwerte fehlen."
    if block is ReasonCode.PRICE_DATA_STALE:
        return "Die Strompreise sind veraltet. Bis neue da sind, zählt nur die Sonne."
    if block is ReasonCode.PLANNED_PAUSE:
        return "Die Wärmepumpe ist aus: der Fahrplan sieht für diese Stunde keinen Lauf vor."
    if main is ReasonCode.PV_SURPLUS_FADING:
        return "Die Wärmepumpe ist aus: die Sonne reicht nicht mehr."
    return "Die Wärmepumpe ist aus: gerade gibt es weder genug Sonne noch günstigen Strom."
