"""Die Einstellungen des Reglers der Wärmepumpe, gelesen über den Bus.

Seit dem eBUS-Add-on 0.4.0 fragt ebusd zwölf Einstellungen ab: die Heizkurve, die
Raumtemperaturen, das Warmwasser. Hier werden sie zu einer Liste für die Seite „Regler“.

**Gelesen, nicht gestellt.** Diese Seite ist die Vorstufe dafür, dass eine Einstellung eines
Tages von hier verstellt werden kann. Davor steht die Prüfung: Kennungen und Zahlenformate
stammen aus der Bus-Beschreibung einer verwandten Anlage, und ob eine Zahl bedeutet, was die
Liste sagt, zeigt nur der Vergleich mit dem Bediengerät im Haus. Deshalb bekommt eine Kennzahl
(Art der Vorlaufregelung, Betriebsart des Warmwassers) kein Wort als Wert; die Lesart der Liste
steht als Hinweis daneben (die Lehre aus „Puffer kühlen“, `waermepumpe.py`).

Reine Zusammensetzung, kein I/O.
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime

from dch_api.schemas import ReglerEinstellungenOut, ReglerEinstellungOut
from hems_core.domain.measurement import Measurement

#: So lange gilt eine gelesene Einstellung. Jede ist etwa alle zehn Minuten dran.
STALE_S = 1800.0


@dataclass(frozen=True)
class Einstellung:
    key: str
    name_de: str
    gruppe_de: str
    kennung: str
    einheit: str = ""
    stellen: int = 1
    #: Was die Bus-Beschreibung zu den Zahlen sagt. Nicht im Haus bestätigt.
    lesart: dict[int, str] = field(default_factory=dict)


EINSTELLUNGEN: tuple[Einstellung, ...] = (
    Einstellung("heat_pump_set_slope", "Steilheit", "Heizkurve", "6a71", stellen=2),
    Einstellung("heat_pump_set_offset_k", "Verschiebung", "Heizkurve", "6471", "K"),
    Einstellung("heat_pump_set_flow_max_c", "Vorlauf höchstens", "Heizkurve", "6071", "°C"),
    Einstellung("heat_pump_set_flow_min_c", "Vorlauf mindestens", "Heizkurve", "6171", "°C"),
    Einstellung("heat_pump_set_flow_fixed_c", "Vorlauf fest", "Heizkurve", "6571", "°C"),
    Einstellung(
        "heat_pump_set_curve_type",
        "Art der Vorlaufregelung",
        "Heizkurve",
        "c079",
        stellen=0,
        lesart={
            0: "fester Vorlauf",
            1: "ein und aus nach Raumthermostat",
            2: "nach Außentemperatur",
            3: "nach Raumtemperatur",
            4: "nach Außen- und Raumtemperatur",
        },
    ),
    Einstellung("heat_pump_set_room_day_c", "Raumtemperatur Tag", "Raum", "6271", "°C"),
    Einstellung("heat_pump_set_room_night_c", "Raumtemperatur Nacht", "Raum", "6371", "°C"),
    Einstellung("heat_pump_set_dhw_comfort_c", "Komforttemperatur", "Warmwasser", "6126", "°C"),
    Einstellung("heat_pump_set_dhw_eco_c", "Spartemperatur", "Warmwasser", "6226", "°C"),
    Einstellung(
        "heat_pump_set_dhw_mode",
        "Betriebsart",
        "Warmwasser",
        "c028",
        stellen=0,
        lesart={0: "aus", 1: "nach Zeitprogramm", 2: "immer an"},
    ),
    Einstellung(
        "heat_pump_set_silent",
        "Flüstermodus",
        "Sonstiges",
        "0320",
        stellen=0,
        lesart={0: "aus", 1: "an"},
    ),
)


def zusammensetzen(
    *, now: datetime, mess: Callable[[str], Measurement], vorfuehrung: bool = False
) -> ReglerEinstellungenOut:
    werte = []
    for e in EINSTELLUNGEN:
        m = mess(e.key)
        zahl = m.value if m.usable else None
        werte.append(
            ReglerEinstellungOut(
                schluessel=e.key,
                name_de=e.name_de,
                gruppe_de=e.gruppe_de,
                kennung=e.kennung,
                einheit=e.einheit,
                stellen=e.stellen,
                wert=m,
                lesart_de=e.lesart.get(round(zahl)) if zahl is not None and e.lesart else None,
            )
        )
    gelesen = sum(1 for w in werte if w.wert.usable)
    hinweise = [
        "Gelesen über den Bus, jede Einstellung etwa alle zehn Minuten. Verstellt wird von hier "
        "nichts.",
        "Kennungen und Zahlenformate stammen aus der Busbeschreibung einer verwandten Anlage. "
        "Stimmt ein Wert nicht mit dem Bediengerät überein, ist die Kennung für diese Anlage "
        "falsch gelesen, nicht die Einstellung verstellt.",
    ]
    if vorfuehrung:
        hinweise.insert(0, "Vorführung: die Einstellungen sind erfunden, nicht gelesen.")
    if gelesen == 0:
        satz = (
            "Noch keine Einstellung gelesen. Das eBUS-Add-on fragt sie ab Fassung 0.4.0 ab; "
            "danach braucht die Bridge einen Neustart."
        )
    elif gelesen < len(werte):
        satz = (
            f"{gelesen} von {len(werte)} Einstellungen gelesen. Die übrigen beantwortet der Regler "
            "nicht oder noch nicht."
        )
    else:
        satz = f"Alle {len(werte)} Einstellungen gelesen. Bitte mit dem Bediengerät vergleichen."
    return ReglerEinstellungenOut(
        now=now, gelesen=gelesen, satz_de=satz, werte=werte, hinweise_de=hinweise
    )


def vorfuehrung() -> dict[str, float]:
    """Einstellungen für die Vorführung: eine Heizkurve, die zu der der Seite „Betrieb“ passt."""
    return {
        "heat_pump_set_slope": 0.7,
        "heat_pump_set_offset_k": 0.0,
        "heat_pump_set_flow_max_c": 55.0,
        "heat_pump_set_flow_min_c": 20.0,
        "heat_pump_set_flow_fixed_c": 40.0,
        "heat_pump_set_curve_type": 2.0,
        "heat_pump_set_room_day_c": 21.0,
        "heat_pump_set_room_night_c": 17.0,
        "heat_pump_set_dhw_comfort_c": 52.0,
        "heat_pump_set_dhw_eco_c": 42.0,
        "heat_pump_set_dhw_mode": 1.0,
        "heat_pump_set_silent": 0.0,
    }
