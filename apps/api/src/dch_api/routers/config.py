from __future__ import annotations

from fastapi import APIRouter, Request

from hems_core.domain import HemsConfig

router = APIRouter(prefix="/config", tags=["Konfiguration"])


@router.get("", response_model=HemsConfig, summary="Aktive Regler- und Modellkonfiguration")
def config(request: Request) -> HemsConfig:
    hems: HemsConfig = request.app.state.hems
    return hems
