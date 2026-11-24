"""Was gerade von Hand gestellt ist, und der Griff, der alles zurück auf Automatik stellt.

Die Seite „Einstellen“ (Entscheidung des Hausherrn vom 24.11.2026) zeigt oben, was gerade von
der Automatik abweicht, und bietet „Alles zurück auf Automatik“ an. Die Eingriffe liegen im
Dienst verstreut bei ihrem Gerät; hier werden sie zu einer Liste mit fertigen Sätzen, damit
Dashboard und App dasselbe zeigen.

**Was zurückgestellt wird, und was nicht.** Zurück gehen die befristeten Eingriffe: die
Wärmepumpe von Hand an oder aus, der Ofen von Hand an oder aus, der Speicher angehalten oder
freigegeben. Sie gehen dorthin, wohin sie auch nach Ablauf ihrer Frist gingen. Ein Raum, den
jemand von Hand gestellt hat, steht in der Liste, bleibt aber: Sein Sollwert ist eine Vorgabe,
und die Ruhe der Raum-Automatik endet von selbst. Übersteuerte Parameter des Regelkreises
stehen nicht hier; sie sind eine Abstimmung und keine Handlung des Augenblicks.
"""

from __future__ import annotations

from datetime import datetime

from dch_api.application.battery_control import DEFAULT_MODE as SPEICHER_VORGABE
from dch_api.application.runtime import Runtime
from dch_api.errors import DchError
from dch_api.schemas import (
    AutomatikZurueckOut,
    BatteryLiveOut,
    HandeingriffeOut,
    HandeingriffOut,
    LiveStateOut,
    RoomShiftOut,
)
from hems_core.domain import OverrideKind, SystemMode
from hems_core.simulation import BERLIN

__all__ = ["liste", "zuruecksetzen"]

#: Wo man einen Eingriff sieht und ändert. Wärmepumpe und Ofen stellt man im Dock der
#: Startseite, den Speicher auf seiner Seite, einen Raum im Haus.
WEGE = {"waermepumpe": "/", "ofen": "/", "speicher": "/strom/speicher", "raum": "/haus"}

NICHTS_ZURUECK = "Es war nichts von Hand gestellt, das zurückgehen könnte."


def _bis(bis: datetime, jetzt: datetime) -> str:
    """„bis 20:00 Uhr“ am selben Tag, sonst mit Datum. In der Uhr des Hauses."""
    ende = bis.astimezone(BERLIN)
    if ende.date() == jetzt.astimezone(BERLIN).date():
        return f"bis {ende:%H:%M} Uhr"
    return f"bis {ende:%d.%m.} um {ende:%H:%M} Uhr"


def liste(
    zustand: LiveStateOut, speicher: BatteryLiveOut, raeume: RoomShiftOut | None, jetzt: datetime
) -> HandeingriffeOut:
    """Die Eingriffe, die gerade gelten, mit einem Satz je Eingriff."""
    aus: list[HandeingriffOut] = []

    modus = zustand.operating_mode
    eingriff = modus.override
    if modus.system_mode is SystemMode.MANUAL and eingriff is not None and eingriff.active(jetzt):
        an = eingriff.kind is OverrideKind.FORCE_RELEASE
        aus.append(
            HandeingriffOut(
                art="waermepumpe",
                weg=WEGE["waermepumpe"],
                satz_de=f"Wärmepumpe von Hand {'angefordert' if an else 'gesperrt'}, "
                f"{_bis(eingriff.ends_at, jetzt)}.",
                bis=eingriff.ends_at,
                zuruecksetzbar=True,
            )
        )

    ofen = zustand.stove
    if ofen.present and ofen.mode in ("on", "off") and ofen.ends_at is not None:
        aus.append(
            HandeingriffOut(
                art="ofen",
                weg=WEGE["ofen"],
                satz_de=f"Ofen von Hand {'an' if ofen.mode == 'on' else 'aus'}, "
                f"{_bis(ofen.ends_at, jetzt)}.",
                bis=ofen.ends_at,
                zuruecksetzbar=True,
            )
        )

    if speicher.mode in ("hold", "normal") and speicher.ends_at is not None:
        aus.append(
            HandeingriffOut(
                art="speicher",
                weg=WEGE["speicher"],
                satz_de=f"Speicher von Hand {'angehalten' if speicher.mode == 'hold' else 'freigegeben'}, "
                f"{_bis(speicher.ends_at, jetzt)}.",
                bis=speicher.ends_at,
                zuruecksetzbar=True,
            )
        )

    for raum in raeume.active if raeume is not None else []:
        if raum.paused_until is None or raum.paused_until <= jetzt:
            continue
        aus.append(
            HandeingriffOut(
                art="raum",
                weg=WEGE["raum"],
                satz_de=f"{raum.name} von Hand gestellt; die Raum-Automatik ruht "
                f"{_bis(raum.paused_until, jetzt)}.",
                bis=raum.paused_until,
                zuruecksetzbar=False,
            )
        )
    return HandeingriffeOut(eingriffe=aus)


async def _raeume(runner: Runtime) -> RoomShiftOut | None:
    try:
        return await runner.rooms_automatik()
    except Exception:
        # Ohne Auskunft der Raum-Automatik fehlen nur die Räume in der Liste.
        return None


async def aktuell(runner: Runtime) -> HandeingriffeOut:
    """Die Liste aus dem Stand des Dienstes."""
    return liste(runner.live_state(), runner.battery_state(), await _raeume(runner), runner.now)


async def zuruecksetzen(runner: Runtime) -> AutomatikZurueckOut:
    """Alle befristeten Eingriffe beenden, jeden so, wie ihn der Ablauf seiner Frist beendet.

    Ein Gerät, das sich nicht stellen lässt, hält die anderen nicht auf; sein Grund steht in der
    Meldung.
    """
    vorher = await aktuell(runner)
    zurueck = [e for e in vorher.eingriffe if e.zuruecksetzbar]
    if not zurueck:
        return AutomatikZurueckOut(ok=True, meldung_de=NICHTS_ZURUECK, handeingriffe=vorher)
    fehler: list[str] = []
    for e in zurueck:
        try:
            if e.art == "waermepumpe":
                await runner.set_heat_pump_mode(
                    SystemMode.AUTO, runner.live_state().operating_mode.auto_profile, None, 0
                )
            elif e.art == "ofen":
                await runner.set_stove_mode("auto", 0)
            elif e.art == "speicher":
                await runner.set_battery_mode(SPEICHER_VORGABE, 0, None)
        except DchError as f:
            fehler.append(f.message)
        except Exception as f:  # pragma: no cover - ein Gerät, das anders scheitert
            fehler.append(str(f))
    nachher = await aktuell(runner)
    if fehler:
        return AutomatikZurueckOut(
            ok=False,
            meldung_de="Nicht alles ließ sich zurückstellen: " + " ".join(fehler),
            handeingriffe=nachher,
        )
    anzahl = len(zurueck)
    return AutomatikZurueckOut(
        ok=True,
        meldung_de=(
            "Der Eingriff ist zurückgestellt; die Automatik regelt wieder."
            if anzahl == 1
            else f"{anzahl} Eingriffe sind zurückgestellt; die Automatik regelt wieder."
        ),
        handeingriffe=nachher,
    )
