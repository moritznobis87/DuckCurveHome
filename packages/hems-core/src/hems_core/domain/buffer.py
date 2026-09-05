"""Zustand des Pufferspeichers (abgeleitet aus vier Temperaturen)."""

from __future__ import annotations

from enum import StrEnum

from pydantic import BaseModel, ConfigDict


class BufferStatus(StrEnum):
    COLD = "cold"
    PARTIAL = "partial"
    WARM = "warm"
    FULL = "full"
    UNKNOWN = "unknown"

    @property
    def label_de(self) -> str:
        return {
            BufferStatus.COLD: "kalt",
            BufferStatus.PARTIAL: "teilgeladen",
            BufferStatus.WARM: "warm",
            BufferStatus.FULL: "voll geladen",
            BufferStatus.UNKNOWN: "unbekannt",
        }[self]


class BufferState(BaseModel):
    model_config = ConfigDict(frozen=True)

    soc: float | None  # 0–1, None wenn Sensoren fehlen
    usable_energy_kwh: float | None
    capacity_kwh: float
    volume_liters: float
    mean_temp_c: float | None
    status: BufferStatus
    method: str
    headroom_soc: float | None  # 1 - soc

    @property
    def usable(self) -> bool:
        return self.soc is not None
