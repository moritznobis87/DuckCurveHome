"""Das Archiv lesen: wie gut die Prognosen waren, nach Abstand zur Lieferung.

Holt die abgelegten Läufe aus `forecast_runs`/`forecast_points`, legt die Messung daneben und gibt
die Kennzahlen je Vorlaufklasse heraus. Die Rechnung selbst steht in
`hems_core.forecasting.rueckblick`; hier stehen nur das I/O und die eine Umrechnung, die
Konfiguration braucht.

**Was das von `/system` unterscheidet.** Die Prognoseseite zeigt, was der `ForecastEvaluator` im
Arbeitsspeicher hält: PV, gestern und heute, verloren beim Neustart. Hier wird der dauerhafte
Bestand gelesen, und damit auch die Außentemperatur - die Größe, an der im Modell v1 der gesamte
Wärmebedarf hängt.

**Die dritte Reihe ist abgeleitet.** Aus dem Temperaturfehler wird mit dem Bedarfsmodell ein
Wärmebedarfsfehler in Kilowatt. Beide Seiten der Probe gehen durch dasselbe Modell, also fällt das
Modell heraus und übrig bleibt, was die **Prognose** am Bedarf falsch gemacht hat. Was das Modell
falsch macht, steht hier nicht und wird erst mit einem Wärmemengenzähler sichtbar. Nur der
Heizanteil wird umgerechnet: das Warmwasser hängt nicht an der Außentemperatur, steht also auf
beiden Seiten gleich und hebt sich in der Differenz ohnehin auf.
"""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, datetime, time, timedelta
from typing import Protocol
from zoneinfo import ZoneInfo

from dch_api.schemas import ForecastHistoryOut
from hems_core.accounting import heat_demand_kw
from hems_core.domain import HemsConfig
from hems_core.forecasting.rueckblick import (
    REIHEN,
    Probe,
    ReiheOut,
    mittel_je_raster,
    proben,
    reihe_out,
    umgerechnet,
)

#: Welche Reihe den Wärmebedarf trägt. Die Umrechnung hängt an ihr, nicht an einer Position.
WETTER_REIHE = "temp_c"

#: Standardfenster des Rückblicks. Sieben Tage sind kurz genug, dass die Abfrage eine Abfrage
#: bleibt, und lang genug, dass eine Vorlaufklasse mehr als eine Handvoll Proben hat.
TAGE = 7


class Bestand(Protocol):
    """Was der Rückblick vom Repository braucht - nicht mehr, damit er prüfbar bleibt."""

    async def forecast_history(
        self, art: str, variable: str, von: datetime, bis: datetime, *, vorlauf_h: int = 48
    ) -> list[tuple[datetime, datetime, float]]: ...

    async def forecast_run_count(self, art: str, von: datetime, bis: datetime) -> int: ...

    async def minute_series(
        self, start: datetime, end: datetime, keys: list[str]
    ) -> list[dict[str, float | str | None]]: ...


def _ist_rows(
    rows: list[dict[str, float | str | None]], key: str
) -> list[tuple[datetime, float | None]]:
    out: list[tuple[datetime, float | None]] = []
    for row in rows:
        v = row.get(key)
        out.append((datetime.fromisoformat(str(row["ts"])), v if isinstance(v, float) else None))
    return out


def _heizlast(cfg: HemsConfig, zone: ZoneInfo) -> Callable[[datetime, float], float]:
    """Der Wandler von Außentemperatur auf Heizleistung, als Funktion über (Zeit, Grad).

    Die Stunde wird gebraucht, weil `heat_demand_kw` sie für das Warmwasser nimmt; der Heizanteil
    hängt nicht an ihr. Sie wird trotzdem richtig übergeben, damit hier keine stille Abweichung von
    der Rechnung des Planers entsteht, falls das Modell die Stunde einmal auch zum Heizen nutzt.
    """

    def wandler(ts: datetime, grad: float) -> float:
        stunde = ts.astimezone(zone).hour
        heizen, _ = heat_demand_kw(grad, stunde, cfg.heat_demand)
        return heizen

    return wandler


async def forecast_history(
    bestand: Bestand,
    now: datetime,
    cfg: HemsConfig,
    zone: ZoneInfo,
    *,
    tage: int = TAGE,
) -> ForecastHistoryOut:
    """Den Rückblick für die letzten `tage` Ortstage bis jetzt zusammenstellen.

    Das Fenster endet **jetzt** und nicht an der letzten Mitternacht: die Vorlaufklasse „bis 1
    Stunde" lebt genau von den Stunden, die gerade vergangen sind, und ein Fenster bis Mitternacht
    hätte sie an einem Vormittag immer leer.
    """
    bis = now
    von = (
        datetime.combine(
            now.astimezone(zone).date() - timedelta(days=tage - 1), time(0), tzinfo=zone
        )
    ).astimezone(UTC)

    reihen: list[ReiheOut] = []
    waerme: ReiheOut | None = None
    for reihe in REIHEN:
        punkte = await bestand.forecast_history(reihe.art, reihe.variable, von, bis)
        laeufe = await bestand.forecast_run_count(reihe.art, von - timedelta(hours=48), bis)
        ist = mittel_je_raster(
            _ist_rows(await bestand.minute_series(von, bis, [reihe.ist_reihe]), reihe.ist_reihe),
            reihe.raster_min,
        )
        xs: list[Probe] = proben(punkte, ist, schwelle=reihe.schwelle, von=von, bis=bis)
        reihen.append(reihe_out(reihe, xs, laeufe))
        if reihe.variable == WETTER_REIHE:
            waerme = reihe_out(
                reihe,
                umgerechnet(xs, _heizlast(cfg, zone)),
                laeufe,
                key="abgeleitet.heizlast_kw",
                label_de="Heizlast aus der Temperatur",
                einheit="kW",
            )
    if waerme is not None:
        reihen.append(waerme)

    return ForecastHistoryOut(
        generated_at=now,
        von=von,
        bis=bis,
        tage=tage,
        reihen=reihen,
        hinweise_de=_hinweise(cfg, reihen),
    )


def _hinweise(cfg: HemsConfig, reihen: list[ReiheOut]) -> list[str]:
    h = [
        "Verglichen wird jeder abgelegte Lauf einzeln. Dasselbe Intervall kommt mehrfach vor, "
        "einmal je Lauf, der es beschrieben hat - bewertet werden Läufe, nicht Viertelstunden.",
        "Der Vorlauf ist der Abstand zwischen der Ausgabe eines Laufs und dem Intervall. "
        "Je kleiner, desto besser sollte die Prognose sein; ob sie das ist, steht in der Tabelle.",
        f"„Heizlast aus der Temperatur“ rechnet beide Seiten mit {cfg.heat_demand.heat_loss_kw_per_k:.2f}"
        " kW/K durch dasselbe Bedarfsmodell. Übrig bleibt der Fehler der Prognose; wie gut das "
        "Modell selbst ist, sagt das nicht - dafür fehlt die Messung der Wärme.",
        "Die Außentemperatur kommt stündlich, die PV-Prognose viertelstündlich. Die Messung wird "
        "auf das jeweilige Raster gemittelt.",
    ]
    if all(r.laeufe == 0 for r in reihen):
        h.insert(
            0,
            "Noch keine Läufe im Zeitraum. Die Ablage läuft seit dem 07.11.2026; für die Zeit davor "
            "gibt es keine Prognosen mehr, und das ist nicht nachholbar.",
        )
    elif all(r.gesamt.n == 0 for r in reihen):
        h.insert(
            0,
            "Läufe sind abgelegt, aber noch keine Messung liegt in denselben Intervallen. "
            "Der Vergleich beginnt, sobald beide Seiten denselben Zeitraum abdecken.",
        )
    return h
