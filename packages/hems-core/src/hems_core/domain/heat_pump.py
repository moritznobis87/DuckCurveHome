"""Ist-Zustand der Wärmepumpe – abgeleitet aus der elektrischen Leistung, nicht aus Kontakten."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class HeatPumpState(BaseModel):
    model_config = ConfigDict(frozen=True)

    running: bool
    running_since: datetime | None
    stopped_since: datetime | None
    power_kw: float
    release_contact_on: bool
    block_contact_on: bool
    starts_today: int
    power_known: bool = True  # False, wenn der 3EM-Wert nicht nutzbar ist
