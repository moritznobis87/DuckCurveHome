"""Die Einzelraumregelung lesen: Istwerte und Tageszeitreihe je Raum."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Annotated, Literal

from fastapi import APIRouter, Body, Depends, Query

from dch_api.application import rooms as room_logic
from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import (
    RoomEffectOut,
    RoomHistoryOut,
    RoomSetpointIn,
    RoomSetpointOut,
    RoomsLiveOut,
)
from hems_core.simulation import BERLIN

router = APIRouter(prefix="/rooms", tags=["Räume"])


@router.get("", response_model=RoomsLiveOut, summary="Räume im Augenblick")
async def rooms_live(runner: Annotated[Runtime, Depends(get_runner)]) -> RoomsLiveOut:
    return await runner.rooms_live()


@router.post(
    "/{room_id}/setpoint",
    response_model=RoomSetpointOut,
    summary="Solltemperatur eines Raums stellen",
)
async def set_setpoint(
    runner: Annotated[Runtime, Depends(get_runner)],
    room_id: int,
    body: Annotated[RoomSetpointIn, Body()],
) -> RoomSetpointOut:
    """Den Sollwert dauerhaft setzen - derselbe Griff, den Contromes eigene Oberfläche anbietet.

    Gerundet wird auf halbe Grad. Eine Fußbodenheizung beantwortet feinere Stufen nicht, und eine
    Anzeige, die 21,3 zeigt, wo 21,5 steht, wäre falsch.
    """
    ok, gestellt, text = await runner.set_room_setpoint(room_id, body.setpoint_c)
    live = await runner.rooms_live()
    raum = next((r for r in live.rooms if r.id == room_id), None)
    if raum is None:
        raise DchError("unknown_room", f"Raum {room_id} ist nicht bekannt.", 404)
    return RoomSetpointOut(ok=ok, room=raum, setpoint_c=gestellt, message_de=text)


@router.get(
    "/{room_id}/wirkung",
    response_model=RoomEffectOut,
    summary="Was eine Sollwertänderung bedeutet",
)
async def room_effect(
    runner: Annotated[Runtime, Depends(get_runner)],
    room_id: int,
    delta_k: Annotated[float, Query(ge=-14.0, le=14.0, description="Änderung in Kelvin")] = 0.5,
) -> RoomEffectOut:
    """Geschätzte Kosten je Tag und das Verschiebepotenzial des Raums als Wärmespeicher."""
    return await runner.room_effect(room_id, delta_k)


@router.get("/history", response_model=RoomHistoryOut, summary="Raumtemperaturen eines Tages")
async def rooms_history(
    runner: Annotated[Runtime, Depends(get_runner)],
    day: str | None = Query(default=None, description="Kalendertag als YYYY-MM-DD, Ortszeit"),
    range_: Annotated[Literal["today", "yesterday", "24h"], Query(alias="range")] = "today",
    step_min: Annotated[int, Query(description="Fensterbreite in Minuten")] = 15,
) -> RoomHistoryOut:
    """Ein Kalendertag in Ortszeit, oder die letzten 24 Stunden.

    **Der Tag ist der hiesige, nicht der der Datenbank.** Ein Heiztag beginnt um Mitternacht in
    Geilenkirchen; in UTC gerechnet wäre er im Sommer um zwei Stunden verschoben, und die
    Nachtabsenkung läge halb im Vortag.
    """
    if step_min not in room_logic.STEPS:
        raise DchError(
            "invalid_step",
            f"step_min muss einer von {', '.join(str(s) for s in room_logic.STEPS)} sein.",
            422,
        )
    now = runner.now
    if day is not None:
        try:
            tag = datetime.strptime(day, "%Y-%m-%d").date()
        except ValueError as exc:
            raise DchError("invalid_day", "day muss YYYY-MM-DD sein.", 422) from exc
        start_lokal = datetime.combine(tag, datetime.min.time(), tzinfo=BERLIN)
        start, end = start_lokal.astimezone(UTC), (start_lokal + timedelta(days=1)).astimezone(UTC)
    elif range_ == "24h":
        # **Der Anfang liegt auf dem Raster, das Ende ist jetzt.**
        #
        # Gerastert wird, damit zwei Abrufe kurz hintereinander nicht gegeneinander verschobene
        # Fenster liefern - sonst wäre jede Kurve beim Neuladen eine andere. Gerastert wird aber
        # der Anfang, nicht das Ende: Ein abgerundetes Ende hätte die letzten bis zu 15 Minuten
        # verschwiegen, und das sind genau die, auf die jemand schaut, der vor der Anzeige steht.
        # Das letzte Fenster ist dadurch angeschnitten und sein Mittel noch unfertig; das ist bei
        # einer laufenden Viertelstunde die richtige Auskunft.
        anfang = now.replace(second=0, microsecond=0) - timedelta(hours=24)
        start, end = anfang - timedelta(minutes=anfang.minute % step_min), now
    else:
        lokal = now.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0)
        if range_ == "yesterday":
            lokal -= timedelta(days=1)
        start, end = lokal.astimezone(UTC), (lokal + timedelta(days=1)).astimezone(UTC)
    return await runner.rooms_history(start, end, step_min)
