"""Die Ereignisstudie zu K1 aus den Minutenzeilen: die Brücke zwischen Bestand und Rechnung.

Die Rechnung selbst steht in `hems_core.thermal.kontaktwirkung` und kennt weder Zeilen noch
Zeitzonen. Hier werden die Zeilen zu Proben, und die Ortsstunde kommt aus der Zeitzone des Hauses.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import datetime, timedelta, tzinfo

from dch_api.schemas import KontaktwirkungOut
from hems_core.domain import HemsConfig
from hems_core.thermal.kontaktwirkung import Probe, auswerten

#: Die Zeiträume, die die Oberfläche anbietet. Begrenzt und nicht frei: 90 Tage sind 130.000
#: Minutenzeilen, und mehr als ein Vierteljahr mischt Heizperiode und Sommer zu einer Quote, die
#: für keines von beiden stimmt.
TAGE = (7, 30, 90)
REIHEN: tuple[str, ...] = ("heat_pump_power_kw", "hp_release_contact")

Zeile = dict[str, float | str | None]


def fenster(jetzt: datetime, tage: int) -> tuple[datetime, datetime]:
    """Der Zeitraum: `tage` zurück bis zur letzten vollen Minute."""
    bis = jetzt.replace(second=0, microsecond=0)
    return bis - timedelta(days=tage), bis


def proben(zeilen: Sequence[Zeile]) -> list[Probe]:
    """Minutenzeilen als Proben. Ein fehlender Wert bleibt ein fehlender Wert.

    Der Kontakt steht als Minutenmittel in der Zeile, null oder eins und in der Minute des
    Schaltens etwas dazwischen. Ab der Hälfte gilt die Minute als geschlossen - dieselbe Regel wie
    im Rückblick des Fahrplans.
    """
    out: list[Probe] = []
    for z in zeilen:
        k = z.get("hp_release_contact")
        w = z.get("heat_pump_power_kw")
        out.append(
            Probe(
                ts=datetime.fromisoformat(str(z["ts"])),
                kontakt=(float(k) >= 0.5) if isinstance(k, (int, float)) else None,
                kw=float(w) if isinstance(w, (int, float)) else None,
            )
        )
    return out


def zusammenstellen(
    zeilen: Sequence[Zeile],
    cfg: HemsConfig,
    tz: tzinfo,
    *,
    tage: int,
    von: datetime,
    bis: datetime,
    reicht_h: float | None = None,
) -> KontaktwirkungOut:
    """Die Auswertung als Antwort. `reicht_h` nennt, wie weit der Bestand höchstens zurückreicht."""
    k = auswerten(
        proben(zeilen),
        schwelle_kw=cfg.heat_pump.running_threshold_kw,
        stunde=lambda t: t.astimezone(tz).hour,
        von=von,
        bis=bis,
    )
    hinweise = list(k.hinweise_de)
    if reicht_h is not None and reicht_h < tage * 24:
        hinweise.insert(
            0,
            f"Die Vorführung erinnert sich nur an die letzten {reicht_h:.0f} Stunden. Gefragt "
            f"waren {tage} Tage; ausgewertet ist, was da ist.",
        )
    return KontaktwirkungOut(
        **k.model_dump(exclude={"hinweise_de"}), hinweise_de=hinweise, days=tage
    )
