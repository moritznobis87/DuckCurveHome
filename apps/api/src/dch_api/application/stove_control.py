"""Der Bedienzustand des Pelletofens: Absicht des Menschen, getrennt von der Beobachtung.

Der Ofen ist der einzige Verbraucher im Haus, den DCH **einschalten** kann, ohne dass ein Mensch im
Raum steht. Das ist eine andere Klasse von Eingriff als eine Lichterkette, und der Unterschied ist
hier an drei Stellen eingebaut:

* **Freigabe.** Ohne `stove.control_enabled` in der Konfiguration nimmt der Regler keinen Befehl an.
  Die Oberfläche zeigt den Ofen dann weiterhin, aber ohne Schaltflächen.
* **Befristung.** Ein manueller Eingriff läuft ab. Danach fällt der Zustand auf `auto` zurück, und
  `auto` heißt derzeit: DCH schaltet nicht, der Ofen regelt sich selbst. Ein Dauerbefehl, den
  niemand mehr zurücknimmt, wäre bei einer Feuerstätte die schlechteste Betriebsart.
* **Trennung von Wunsch und Wirklichkeit.** `mode` ist gewollt, `running` ist gemessen. Ein Ofen
  braucht Minuten zum Zünden und noch mehr zum Ausbrennen; in dieser Zeit stimmt beides zugleich,
  „an" und „läuft noch nicht". Die Oberfläche zeigt deshalb beides und nicht eine geglättete Lüge.

Reine Zustandslogik, kein I/O: das tatsächliche Schalten macht die Runtime über die Bridge.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Literal

from dch_api.schemas import StoveLiveOut
from hems_core.domain import Measurement, Quality
from hems_core.domain.config import StoveConfig

StoveMode = Literal["auto", "on", "off"]

# Nach dieser Zeit ohne frischen Rahmen gilt der Ofenzustand als veraltet. Die Bridge fragt alle
# 15 Sekunden; fünf Minuten Schweigen sind damit kein Taktproblem mehr, sondern ein Ausfall.
STALE_AFTER_S = 300.0

MeasurementLookup = Callable[[str, float], Measurement]

# Der Zustand nach einem Neustart und nach jedem abgelaufenen Eingriff. Bewusst `off` und nicht
# `auto`: die Automatik ist fertig und geprüft, aber sie soll nicht von selbst anlaufen, weil ein
# Dienst neu gestartet wurde. Wer will, dass der Planer den Ofen führt, drückt einmal **Auto**.
#
# `off` heißt hier nicht „DCH schaltet den Ofen aus". Es heißt: DCH lässt ihn in Ruhe. Ein Befehl
# geht nur hinaus, wenn jemand eine Schaltfläche drückt oder der Planer im Modus `auto` etwas
# anderes vorsieht. Ein von Hand angezündeter Ofen brennt also weiter, und die Zustandszeile zeigt
# das auch so.
DEFAULT_MODE: StoveMode = "off"


@dataclass
class StoveController:
    """Hält den gewünschten Betriebszustand und setzt ihn mit dem gemessenen zusammen."""

    cfg: StoveConfig
    mode: StoveMode = DEFAULT_MODE
    ends_at: datetime | None = None

    @property
    def controllable(self) -> bool:
        return self.cfg.present and self.cfg.control_enabled

    def effective_mode(self, now: datetime) -> StoveMode:
        """Den gültigen Modus liefern und einen abgelaufenen Eingriff dabei verfallen lassen.

        Ein abgelaufener Eingriff fällt auf die Vorgabe zurück, nicht auf `auto`. Sonst hieße „an
        für zwei Stunden" in Wahrheit „an für zwei Stunden, danach entscheidet der Planer", und das
        hat niemand angetippt.
        """
        if self.ends_at is not None and now >= self.ends_at:
            self.mode, self.ends_at = DEFAULT_MODE, None
        return self.mode

    def set(self, mode: StoveMode, duration_min: int, now: datetime) -> StoveMode:
        """Einen Modus setzen. `auto` hebt einen laufenden Eingriff auf, ohne selbst zu schalten."""
        if mode == "auto":
            self.mode, self.ends_at = "auto", None
        else:
            self.mode = mode
            self.ends_at = now + timedelta(minutes=duration_min)
        return self.mode

    def state(
        self,
        measure: MeasurementLookup,
        now: datetime,
        *,
        planned_on: bool | None = None,
        plan_until: datetime | None = None,
        plan_note_de: str = "",
    ) -> StoveLiveOut:
        """Den Zustand für die Oberfläche zusammensetzen.

        Der Fahrplan kommt von außen herein, statt hier gerechnet zu werden: dieser Teil hält den
        Bedienzustand, der Planer die Optimierung, und beide sollen sich einzeln prüfen lassen.
        """
        if not self.cfg.present:
            return StoveLiveOut(note_de="Kein Ofen konfiguriert.")
        mode = self.effective_mode(now)
        run = measure("stove_running", STALE_AFTER_S)
        fresh = run.quality in (Quality.OK, Quality.STALE) and run.value is not None
        running = bool(run.value) if fresh else None
        level = _value(measure("stove_power_level", STALE_AFTER_S))
        return StoveLiveOut(
            present=True,
            control_enabled=self.controllable,
            mode=mode,
            ends_at=self.ends_at,
            running=running,
            power_level=level,
            fume_temp_c=_value(measure("stove_fume_temp_c", STALE_AFTER_S)),
            boiler_temp_c=_value(measure("stove_boiler_temp_c", STALE_AFTER_S)),
            observed_at=run.observed_at if fresh else None,
            quality=run.quality,
            planned_on=planned_on,
            plan_until=plan_until,
            plan_note_de=plan_note_de,
            note_de=note(
                mode, running, level, self.ends_at, self.controllable, planned_on, plan_until
            ),
        )


def _value(m: Measurement) -> float | None:
    return m.value if m.quality in (Quality.OK, Quality.STALE) else None


def note(
    mode: StoveMode,
    running: bool | None,
    level: float | None,
    ends_at: datetime | None,
    controllable: bool,
    planned_on: bool | None = None,
    plan_until: datetime | None = None,
) -> str:
    """Ein Satz, der Wunsch und Wirklichkeit nebeneinanderstellt, statt einen davon zu verschweigen."""
    if running is None:
        return "Keine Verbindung zum Ofen."
    if running:
        stufe = f" auf Stufe {int(level)}" if level else ""
        was = f"Der Ofen brennt{stufe}."
    else:
        was = "Der Ofen ist aus."
    if not controllable:
        return f"{was} DCH schaltet ihn nicht (Steuerung nicht freigegeben)."
    if mode == "auto":
        if planned_on is None:
            # Ohne Fahrplan wird nicht behauptet, es entscheide jemand. Das ist der Zustand bei
            # fehlenden Preisen, blindem Puffer oder zu kurzem Horizont.
            return f"{was} Auto: kein Fahrplan, der Ofen regelt selbst."
        bis = f" bis {plan_until:%H:%M}" if plan_until else ""
        return f"{was} Auto: Planer sagt {'an' if planned_on else 'aus'}{bis}."
    if mode == "off" and ends_at is None:
        # Die Vorgabe, kein Eingriff: DCH lässt den Ofen in Ruhe, in beide Richtungen.
        return f"{was} DCH lässt ihn in Ruhe; für den Planer auf Auto stellen."
    wunsch = "an" if mode == "on" else "aus"
    bis = f" bis {ends_at:%H:%M}" if ends_at else ""
    return f"{was} Manuell {wunsch}{bis}."
