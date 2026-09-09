"""Der Bedienzustand des Speichers: Absicht des Menschen, getrennt von der Regelung.

Der Libbi ist das dritte Gerät, in das DCH hineinschreibt, und es gelten dieselben drei Regeln wie
beim Ofen:

* **Freigabe.** Ohne `battery.control_enabled` in der Konfiguration geht kein Befehl hinaus. Die
  Oberfläche zeigt den Speicher weiter, aber ohne Schaltflächen.
* **Befristung.** Ein manueller Eingriff läuft ab und fällt auf die Vorgabe zurück. Ein dauerhaft
  angehaltener Speicher wäre teuer: er nimmt dann auch keine Sonne mehr auf.
* **Trennung von Wunsch und Wirklichkeit.** `mode` ist gewollt, `command` ist zuletzt gesendet. Die
  myenergi-Cloud bestätigt nichts; was das Gerät wirklich tut, sagt erst die nächste Messung.

Die Vorgabe ist `off`, und das heißt hier: DCH lässt den Speicher in Ruhe und sendet gar nichts.
Wer die Untergrenze will, stellt einmal auf **Auto**. Ein Dienstneustart schaltet damit nichts.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Literal

from hems_core.control import BatteryCommand, decide_reserve
from hems_core.domain.config import BatteryConfig

BatteryMode = Literal["auto", "normal", "hold", "off"]
DEFAULT_MODE: BatteryMode = "off"


@dataclass
class BatteryController:
    """Hält den gewünschten Betriebszustand und leitet daraus den Befehl an den Speicher ab."""

    cfg: BatteryConfig
    mode: BatteryMode = DEFAULT_MODE
    ends_at: datetime | None = None
    # Zuletzt gesendeter Befehl. Nur bei einer Änderung wird geschrieben; die myenergi-Cloud ist
    # kein Ort für einen Aufruf je Regeltakt.
    sent: BatteryCommand | None = None
    reason_de: str = "DCH lässt den Speicher in Ruhe."

    @property
    def controllable(self) -> bool:
        return self.cfg.control_enabled

    def effective_mode(self, now: datetime) -> BatteryMode:
        if self.ends_at is not None and now >= self.ends_at:
            self.mode, self.ends_at = DEFAULT_MODE, None
        return self.mode

    def set(self, mode: BatteryMode, duration_min: int, now: datetime) -> BatteryMode:
        """Einen Modus setzen. `auto` und `off` gelten unbefristet, ein Eingriff wird befristet."""
        if mode in ("auto", "off"):
            self.mode, self.ends_at = mode, None
        else:
            self.mode = mode
            self.ends_at = now + timedelta(minutes=duration_min)
        return self.mode

    def wanted(
        self, now: datetime, soc: float | None, surplus_kw: float | None
    ) -> BatteryCommand | None:
        """Der Befehl, der jetzt gelten soll, oder None, wenn DCH nichts zu sagen hat.

        None ist nicht dasselbe wie `normal`: es heißt, dass gar nichts gesendet wird. Der Speicher
        bleibt dann in der Betriebsart, in der er ohnehin steht.
        """
        mode = self.effective_mode(now)
        if not self.controllable or mode == "off":
            self.reason_de = "DCH lässt den Speicher in Ruhe."
            return None
        if mode == "normal":
            self.reason_de = "Manuell freigegeben."
            return "normal"
        if mode == "hold":
            bis = f" bis {self.ends_at:%H:%M}" if self.ends_at else ""
            self.reason_de = f"Manuell angehalten{bis}."
            return "stopped"
        decision = decide_reserve(
            soc=soc,
            reserve_soc=self.cfg.reserve_soc,
            surplus_kw=surplus_kw,
            holding=self.sent == "stopped",
        )
        self.reason_de = decision.reason_de
        return decision.command
