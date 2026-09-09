"""Untergrenze für den Speicher: wann der Regler ihn anhält und wann er ihn wieder freigibt.

**Wozu das gut ist.** Der myenergi Libbi kennt keine einstellbare Entladegrenze. Er entlädt bis zu
seiner eigenen Sicherheitsgrenze, meldet dann 0 %, und wenn dieser Stand eine Stunde lang steht,
holt er sich rund 6 % aus dem Netz zurück (Fehlercode 233, „SoC Recovery"). Am 03.09.2026 waren das
zwei Nachladungen von je 0,32 kWh zu 37 bis 39 ct. Sie sind nicht bloß teuer, sie sind nutzlos: in
denselben Stunden hat der Speicher **nichts** ins Haus abgegeben, die gekaufte Energie war drei
Stunden später wieder verschwunden. Bezahlt werden dafür Netzstrom, Wirkungsgrad und Zyklen, und
zwar im untersten, für die Zelle unfreundlichsten Bereich der Kennlinie.

Die letzten Prozent zu fahren bringt also nichts: was das Haus daraus bekommt, kauft das Gerät
gleich darauf teurer zurück. Deshalb hält dieser Regler den Speicher oberhalb einer Grenze an. Was
das Haus dann braucht, kommt direkt aus dem Netz - zum selben Preis, aber ohne Umweg und ohne Zyklus.

**Warum es nur einen Schalter gibt.** Der Libbi kennt genau drei setzbare Betriebsarten: Stopped,
Normal, Export. Ein „nicht mehr entladen, aber noch laden" gibt es nicht. `Stopped` hält beides an.
Die Freigabe muss deshalb aktiv erfolgen, sobald PV-Überschuss da ist, sonst stünde der Speicher an
einem sonnigen Morgen bei seiner Grenze und liesse die Sonne vorbeiziehen.

Reine Entscheidungslogik ohne I/O. Das Schalten macht die Runtime.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

BatteryCommand = Literal["normal", "stopped"]

# Abstand zwischen Halten und Freigeben. Ohne Hysterese schaltet der Regler an der Grenze im
# Sekundentakt hin und her, und jeder Wechsel ist ein Aufruf in die myenergi-Cloud.
RELEASE_MARGIN = 0.02
# Ab so viel Überschuss gilt die Sonne als tragfähig. Darunter wäre die Freigabe ein Strohfeuer:
# der Speicher liefe sofort wieder unter die Grenze.
SURPLUS_RELEASE_KW = 0.3


@dataclass(frozen=True)
class ReserveDecision:
    command: BatteryCommand
    reason_de: str

    @property
    def holding(self) -> bool:
        return self.command == "stopped"


def decide_reserve(
    *,
    soc: float | None,
    reserve_soc: float,
    surplus_kw: float | None,
    holding: bool,
) -> ReserveDecision:
    """Was mit dem Speicher geschehen soll.

    `soc` und `reserve_soc` sind Anteile (0..1), `surplus_kw` ist PV minus Hausverbrauch, `holding`
    der zuletzt gesetzte Zustand. Fehlt der Ladestand, wird nicht eingegriffen: ein Regler, der ohne
    Messwert schaltet, ist gefährlicher als gar keiner.
    """
    if reserve_soc <= 0.0:
        return ReserveDecision("normal", "Untergrenze nicht gesetzt.")
    if soc is None:
        return ReserveDecision("normal", "Kein Ladestand: kein Eingriff.")
    if surplus_kw is not None and surplus_kw >= SURPLUS_RELEASE_KW:
        # Überschuss hat Vorrang vor der Grenze: `stopped` würde auch das Laden verhindern.
        return ReserveDecision("normal", f"PV-Überschuss {surplus_kw:.1f} kW: Speicher frei.")
    if soc <= reserve_soc:
        return ReserveDecision(
            "stopped", f"Ladestand {soc:.0%} auf Untergrenze {reserve_soc:.0%}: angehalten."
        )
    if holding and soc < reserve_soc + RELEASE_MARGIN:
        # In der Hysterese bleibt es beim Halten, sonst pendelt der Regler an der Grenze.
        return ReserveDecision("stopped", f"Ladestand {soc:.0%} knapp über der Grenze: gehalten.")
    return ReserveDecision("normal", f"Ladestand {soc:.0%} über der Grenze.")
