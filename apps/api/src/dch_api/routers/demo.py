from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.demo_runner import DemoRunner
from dch_api.dependencies import get_runner
from dch_api.errors import DchError
from dch_api.schemas import DemoControlIn

router = APIRouter(prefix="/demo", tags=["Demo"])


@router.post("", summary="Demo steuern: Zeitraffer, Störungen, Szenarien")
def control(
    cmd: DemoControlIn, runner: Annotated[DemoRunner, Depends(get_runner)]
) -> dict[str, object]:
    if runner.settings.mode != "demo":
        raise DchError("not_demo", "Nur im Demo-Modus verfügbar.", 409)
    runner.demo_control(
        cmd.speed, cmd.fault_key, cmd.fault_quality, cmd.fault_duration_s, cmd.scenario
    )
    return {
        "speed": runner.speed,
        "sim_time": runner.now.isoformat(),
        "faults": [f.key for f in runner.house.faults],
    }
