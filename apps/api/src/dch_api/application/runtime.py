"""Gemeinsame Schnittstelle von Demo- und Live-Runtime für die Router."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any, Protocol

from dch_api.application.ha_import import ImportResult
from dch_api.infrastructure.sse_broker import SseBroker
from dch_api.schemas import (
    BackfillResultOut,
    EnergySummaryOut,
    EvReportOut,
    ForecastEvaluationOut,
    HeatReportOut,
    InvoiceReportOut,
    InvoiceSummaryOut,
    LiveStateOut,
    Period,
    PlanOut,
    SystemEventOut,
)
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
    async def forecast_evaluation(self) -> ForecastEvaluationOut: ...
    async def energy_summary(self, period: Period, anchor: date) -> EnergySummaryOut: ...
    async def heat_report(self, period: Period, anchor: date) -> HeatReportOut: ...
    async def ev_report(self, period: Period, anchor: date) -> EvReportOut: ...
    async def import_history(
        self,
        payload: bytes,
        kind: str,
        dry_run: bool,
        extra_map: dict[str, dict[str, Any]] | None,
        replace_until: datetime | None = None,
    ) -> ImportResult: ...
    async def myenergi_backfill(
        self, hours: int, start: datetime | None = None, end: datetime | None = None
    ) -> BackfillResultOut: ...
    async def recent_events(self, limit: int) -> list[SystemEventOut]: ...
    async def check_invoice(self, payload: bytes, file_name: str | None) -> InvoiceReportOut: ...
    async def invoices(self) -> list[InvoiceSummaryOut]: ...
    async def invoice(self, number: str) -> InvoiceReportOut | None: ...
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
