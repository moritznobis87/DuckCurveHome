"""Gemeinsame Schnittstelle von Demo- und Live-Runtime für die Router."""

from __future__ import annotations

from datetime import datetime
from typing import Protocol

from dch_api.infrastructure.sse_broker import SseBroker
from dch_api.schemas import LiveStateOut, PlanOut
from dch_api.settings import Settings
from hems_core.domain import AutoProfile, Decision, OperatingMode, SystemMode


class Runtime(Protocol):
    settings: Settings
    broker: SseBroker
    plan: PlanOut | None

    @property
    def now(self) -> datetime: ...
    def live_state(self) -> LiveStateOut: ...
    async def history_rows(
        self, start: datetime, end: datetime
    ) -> list[dict[str, float | str | None]]: ...
    async def recent_decisions(self, limit: int) -> list[Decision]: ...
    async def switch_actuator(
        self, key: str, state: bool, duration_min: int | None
    ) -> tuple[bool, bool | None, str | None]: ...
    async def set_heat_pump_mode(
        self,
        system_mode: SystemMode,
        profile: AutoProfile | None,
        manual_state: str | None,
        duration_min: int,
    ) -> OperatingMode: ...
