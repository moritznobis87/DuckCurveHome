"""Zeitbasierter exponentiell gewichteter Mittelwert (EWMA)."""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class Ewma:
    tau_s: float
    value: float | None = None
    last_at: datetime | None = field(default=None)

    def update(self, x: float | None, at: datetime) -> float | None:
        if x is None:
            # fehlender Wert: Mittelwert altert, wird aber nicht verfälscht
            return self.value
        if self.value is None or self.last_at is None:
            self.value = x
        else:
            dt = max(0.0, (at - self.last_at).total_seconds())
            alpha = 1.0 - math.exp(-dt / self.tau_s) if self.tau_s > 0 else 1.0
            self.value = self.value + alpha * (x - self.value)
        self.last_at = at
        return self.value

    def reset(self) -> None:
        self.value = None
        self.last_at = None
