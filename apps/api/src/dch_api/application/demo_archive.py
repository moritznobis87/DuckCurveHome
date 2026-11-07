"""Ein gerechnetes Prognosearchiv für den Demobetrieb.

Der Demolauf hat keine Datenbank; seine Historie liegt im Arbeitsspeicher, und `forecast_runs` gibt
es dort nicht. Ohne Ersatz bliebe die Rückblickseite in der Demo leer, und damit auch unprüfbar.

Deshalb **rechnet** diese Klasse das Archiv, statt es zu lesen: aus den Kurven des Demohauses und
einem Fehler, der mit dem Vorlauf wächst. Sie ist damit keine Aussage über die Güte der echten
Prognose, sondern zeigt die Seite. Der Hinweis dazu steht in der Antwort.

Der Fehler ist absichtlich **deterministisch** und nicht zufällig: eine Seite, die bei jedem
Neuladen andere Kennzahlen zeigt, lässt sich nicht beurteilen und nicht in einem Test festhalten.
Die Pseudostreuung kommt aus einer Sinusfunktion über Zeitpunkt und Ausgabezeit, nicht aus einem
Zufallsgenerator.
"""

from __future__ import annotations

import math
from collections.abc import Callable
from datetime import UTC, datetime, timedelta

from hems_core.forecasting.archive import PV, WETTER

#: Wie oft die Demo einen Lauf ausgegeben hätte.
LAUF_ABSTAND_MIN = 60

#: Wie weit ein Lauf reicht. Derselbe Horizont, den der Zwilling plant.
HORIZONT_H = 48

#: Wie groß der Fehler bei einem Tag Vorlauf ist, je Reihe und in deren Einheit.
#:
#: Zahlen aus der Größenordnung, die man bei Open-Meteo und einer einfachen PV-Rechnung erwartet,
#: nicht aus einer Messung. Sie stehen hier, damit die Seite plausible Verhältnisse zeigt.
FEHLER_BEI_24H = {"temp_c": 1.8, "ac_kw": 0.9}


class DemoArchiv:
    """Erfüllt denselben Vertrag wie das Repository, rechnet die Läufe aber aus dem Demohaus."""

    def __init__(
        self,
        pv_kw: Callable[[datetime], float],
        aussen_c: Callable[[datetime], float],
        minuten: Callable[[datetime, datetime, list[str]], list[dict[str, float | str | None]]],
    ) -> None:
        self.pv_kw = pv_kw
        self.aussen_c = aussen_c
        self._minuten = minuten

    # ------------------------------------------------------------------ Fehlermodell
    @staticmethod
    def _streuung(erstellt: datetime, ts: datetime) -> float:
        """Eine reproduzierbare Zahl zwischen -1 und 1, die mit Lauf und Zeitpunkt wechselt."""
        a = erstellt.timestamp() / 3600.0
        b = ts.timestamp() / 3600.0
        return math.sin(a * 1.7 + b * 0.9) * 0.6 + math.sin(b * 0.31) * 0.4

    def _abweichung(self, variable: str, erstellt: datetime, ts: datetime) -> float:
        """Der Fehler wächst mit der Wurzel des Vorlaufs: schnell am Anfang, dann flacher.

        Die Wurzel und nicht eine Gerade, weil sich so die beiden Enden der Vorlaufleiter
        unterscheiden, ohne dass der späteste Lauf absurd wird. Das ist eine Form, keine Messung.
        """
        vorlauf = max(0.0, (ts - erstellt).total_seconds() / 3600.0)
        groesse = FEHLER_BEI_24H.get(variable, 1.0) * math.sqrt(vorlauf / 24.0)
        return groesse * self._streuung(erstellt, ts)

    def _ausgabezeiten(self, von: datetime, bis: datetime) -> list[datetime]:
        erste = (von - timedelta(hours=HORIZONT_H)).replace(minute=0, second=0, microsecond=0)
        schritt = timedelta(minutes=LAUF_ABSTAND_MIN)
        out: list[datetime] = []
        t = erste
        while t < bis:
            out.append(t)
            t += schritt
        return out

    # ------------------------------------------------------------------ Vertrag
    async def forecast_history(
        self,
        art: str,
        variable: str,
        von: datetime,
        bis: datetime,
        *,
        vorlauf_h: int = HORIZONT_H,
    ) -> list[tuple[datetime, datetime, float]]:
        if art == PV:
            kurve, raster = self.pv_kw, 15
        elif art == WETTER:
            kurve, raster = self.aussen_c, 60
        else:
            return []
        von, bis = von.astimezone(UTC), bis.astimezone(UTC)
        out: list[tuple[datetime, datetime, float]] = []
        for erstellt in self._ausgabezeiten(von, bis):
            t = max(von, erstellt.replace(minute=0, second=0, microsecond=0))
            ende = min(bis, erstellt + timedelta(hours=vorlauf_h))
            while t < ende:
                wahr = kurve(t + timedelta(minutes=raster / 2))
                out.append((erstellt, t, round(wahr + self._abweichung(variable, erstellt, t), 3)))
                t += timedelta(minutes=raster)
        return out

    async def forecast_run_count(self, art: str, von: datetime, bis: datetime) -> int:
        """Stündliche Läufe im gefragten Fenster. Ohne den Vorlauf-Vorsprung aus
        `_ausgabezeiten`: der Aufrufer hat ihn schon abgezogen, und zweimal wäre es zweimal."""
        if art not in (PV, WETTER):
            return 0
        spanne = (bis.astimezone(UTC) - von.astimezone(UTC)).total_seconds() / 60.0
        return max(0, int(spanne // LAUF_ABSTAND_MIN))

    async def minute_series(
        self, start: datetime, end: datetime, keys: list[str]
    ) -> list[dict[str, float | str | None]]:
        return self._minuten(start, end, keys)
