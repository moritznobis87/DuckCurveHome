"""Ein Messwert mit Zeitpunkt, Qualität und Herkunft."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict

from hems_core.domain.quality import Quality


class Measurement(BaseModel):
    model_config = ConfigDict(frozen=True)

    value: float | None
    observed_at: datetime
    quality: Quality
    source: str

    @classmethod
    def ok(cls, value: float, observed_at: datetime, source: str) -> Measurement:
        return cls(value=value, observed_at=observed_at, quality=Quality.OK, source=source)

    @classmethod
    def derived(cls, value: float, observed_at: datetime, source: str = "derived") -> Measurement:
        return cls(value=value, observed_at=observed_at, quality=Quality.DERIVED, source=source)

    @classmethod
    def missing(cls, quality: Quality, observed_at: datetime, source: str) -> Measurement:
        if quality.usable:
            raise ValueError("missing() verlangt eine nicht nutzbare Qualität")
        return cls(value=None, observed_at=observed_at, quality=quality, source=source)

    @property
    def usable(self) -> bool:
        return self.value is not None and self.quality.usable

    def value_or(self, fallback: float) -> float:
        return self.value if self.usable and self.value is not None else fallback

    def aged(self, now: datetime, stale_after_s: float) -> Measurement:
        """Kopie, die bei überschrittenem Alter als STALE markiert ist."""
        if self.quality is Quality.OK and (now - self.observed_at).total_seconds() > stale_after_s:
            return self.model_copy(update={"quality": Quality.STALE})
        return self
