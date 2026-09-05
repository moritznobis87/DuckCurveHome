from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.runtime import Runtime
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import ActuatorCommandIn, ActuatorCommandOut, HeatPumpModeIn
from hems_core.domain import Decision, OperatingMode, SystemMode

router = APIRouter(prefix="/control", tags=["Steuerung"])

ACTUATOR_LABELS = {
    "coffee_machine": "Kaffeemaschine",
    "terrace_light": "Licht Terrasse",
    "courtyard_light": "Licht Innenhof",
    "garden_fence_light": "Licht Gartenzaun",
}


@router.post("/actuators/{key}", response_model=ActuatorCommandOut, summary="Aktor schalten")
async def switch_actuator(
    key: str, cmd: ActuatorCommandIn, runner: Annotated[Runtime, Depends(get_runner)]
) -> ActuatorCommandOut:
    if key not in ACTUATOR_LABELS:
        raise DchError("unknown_actuator", f"Unbekannter Aktor „{key}“.", 404)
    ok, observed, error = await runner.switch_actuator(key, cmd.state, cmd.duration_min)
    label = ACTUATOR_LABELS[key]
    if not ok or observed != cmd.state:
        return ActuatorCommandOut(
            key=key,
            requested=cmd.state,
            observed=observed,
            ok=False,
            message_de=f"{label}: {error or 'Schaltung nicht bestätigt.'}",
        )
    return ActuatorCommandOut(
        key=key,
        requested=cmd.state,
        observed=observed,
        ok=True,
        message_de=f"{label} {'eingeschaltet' if cmd.state else 'ausgeschaltet'}.",
    )


@router.post(
    "/heat-pump/mode", response_model=OperatingMode, summary="Betriebsmodus der Wärmepumpe setzen"
)
async def set_mode(
    cmd: HeatPumpModeIn, runner: Annotated[Runtime, Depends(get_runner)]
) -> OperatingMode:
    if cmd.system_mode is SystemMode.MANUAL and cmd.manual_state is None:
        raise DchError(
            "manual_state_required", "Für MANUAL ist manual_state (on|off) erforderlich.", 422
        )
    return await runner.set_heat_pump_mode(
        cmd.system_mode, cmd.auto_profile, cmd.manual_state, cmd.duration_min
    )


@router.get(
    "/decisions",
    response_model=list[Decision],
    summary="Letzte Regler-Entscheidungen (Zustandswechsel)",
)
async def decisions(
    runner: Annotated[Runtime, Depends(get_runner)], limit: int = 20
) -> list[Decision]:
    return await runner.recent_decisions(max(1, min(limit, 300)))
