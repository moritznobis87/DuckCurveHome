"""Leitet den Laufzustand der Wärmepumpe aus der elektrischen Leistung ab (mit Entprellung)."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime

from hems_core.domain.config import HeatPumpConfig
from hems_core.domain.heat_pump import HeatPumpState
from hems_core.domain.measurement import Measurement


@dataclass
class HeatPumpTracker:
    cfg: HeatPumpConfig
    running: bool = False
    running_since: datetime | None = None
    stopped_since: datetime | None = None
    starts_today: int = 0
    _candidate_since: datetime | None = field(default=None, repr=False)
    _day: object = field(default=None, repr=False)

    def update(
        self,
        power: Measurement,
        release_on: bool,
        block_on: bool,
        now: datetime,
    ) -> HeatPumpState:
        if self._day != now.date():
            self._day = now.date()
            self.starts_today = 0
        known = power.usable
        above = known and power.value_or(0.0) >= self.cfg.running_threshold_kw
        if known:
            if above != self.running:
                if self._candidate_since is None:
                    self._candidate_since = now
                elif (now - self._candidate_since).total_seconds() >= self.cfg.running_debounce_s:
                    self.running = above
                    self._candidate_since = None
                    if above:
                        self.running_since = now
                        self.stopped_since = None
                        self.starts_today += 1
                    else:
                        self.stopped_since = now
                        self.running_since = None
            else:
                self._candidate_since = None
        return HeatPumpState(
            running=self.running,
            running_since=self.running_since,
            stopped_since=self.stopped_since,
            power_kw=round(power.value_or(0.0), 3),
            release_contact_on=release_on,
            block_contact_on=block_on,
            starts_today=self.starts_today,
            power_known=known,
        )
