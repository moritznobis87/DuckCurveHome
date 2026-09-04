"""Betriebsmodi und manuelle Übersteuerungen."""

from __future__ import annotations

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict


class SystemMode(StrEnum):
    OFF = "off"
    MANUAL = "manual"
    AUTO = "auto"


class AutoProfile(StrEnum):
    ECO = "eco"
    PV = "pv"
    PRICE = "price"
    SMART = "smart"


class OverrideKind(StrEnum):
    FORCE_RELEASE = "force_release"  # K1 an
    FORCE_OFF = "force_off"  # K1 aus, keine Freigabe durch Regeln
    FORCE_BLOCK = "force_block"  # K2 an (nur wenn Sperre freigegeben)


class Override(BaseModel):
    model_config = ConfigDict(frozen=True)

    kind: OverrideKind
    started_at: datetime
    ends_at: datetime
    set_by: str = "dashboard"

    def active(self, now: datetime) -> bool:
        return self.started_at <= now < self.ends_at


class OperatingMode(BaseModel):
    model_config = ConfigDict(frozen=True)

    system_mode: SystemMode = SystemMode.AUTO
    auto_profile: AutoProfile = AutoProfile.SMART
    override: Override | None = None
