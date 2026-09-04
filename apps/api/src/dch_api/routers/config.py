from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends

from dch_api.application.demo_runner import DemoRunner
from dch_api.dependencies import get_runner
from hems_core.domain import HemsConfig

router = APIRouter(prefix="/config", tags=["Konfiguration"])


@router.get("", response_model=HemsConfig, summary="Aktive Regler- und Modellkonfiguration")
def config(runner: Annotated[DemoRunner, Depends(get_runner)]) -> HemsConfig:
    return runner.hems
