"""Die Sicherheitslogik der Raumautomatik: Was in einem Raum zu tun ist - und wann nichts.

**Was hier entschieden wird.** Die Automatik kennt ein Ziel (siehe `hems_core.thermal.shift_plan`):
null oder ein halbes Kelvin Aufschlag. Dieses Modul entscheidet, ob daraus ein Befehl an die
Heizung wird. Das ist die heikle Hälfte: Ein Werkzeug, das von sich aus in eine Wohnung greift,
muss vor allem wissen, wann es die Finger wegzunehmen hat.

**Die vier Fälle, in denen nichts passiert.**

1. **Jemand anders hat gestellt.** Weicht der gemeldete Sollwert von dem ab, den die Automatik
   zuletzt geschrieben hat, war es ein Mensch - in Controme, an der Wand, egal. Dann zieht sich
   die Automatik zurück und rührt diesen Raum eine Weile nicht an. Gegen einen Menschen zu regeln
   ist das Schlimmste, was sie tun kann: Er dreht, es geht zurück, er dreht wieder.
2. **Das Fenster ist offen.** Dann wird nicht vorgeladen, egal wie billig der Strom ist.
3. **Die Schonfrist läuft.** Zwischen zwei Befehlen an denselben Raum liegen Minuten. Eine
   Fußbodenheizung beantwortet keine Minutentakte, und jeder Befehl ist ein Schreibvorgang in
   einer fremden Anlage.
4. **Es steht schon richtig.** Ein Befehl, der nichts ändert, ist kein harmloser Befehl, sondern
   eine Zeile im Protokoll, die später jemanden rätseln lässt.

**Die Rückfahrkarte steht vor der Fahrt fest.** Jede Anhebung nennt den Grundwert, auf den
zurückzustellen ist; die Laufzeit schreibt ihn in die Datenbank, bevor sie den Befehl schickt.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime, timedelta

from hems_core.thermal.shift_plan import ShiftPolicy

#: Feiner als ein Zehntel führt Controme nicht; darunter ist ein Unterschied keiner.
TOLERANZ_K = 0.05
#: So lange nach einem eigenen Befehl zählt ein älterer Messwert nicht als fremde Änderung.
#: Die Anlage meldet den neuen Sollwert erst beim nächsten Durchlauf, nicht im selben Moment.
GNADENFRIST_MIN = 3.0
#: So lange ruht ein Raum, nachdem jemand von Hand gestellt hat.
RUHE_NACH_EINGRIFF_H = 12.0
#: Mindestabstand zwischen zwei Befehlen an denselben Raum.
SCHONFRIST_MIN = 10.0


#: Harte Grenzen der Einstellungen. Sie stehen hier und nicht in der Oberfläche: Was eine Heizung
#: verstellen darf, ist keine Frage der Anzeige. Ein Kelvin ist viel für einen Raum, und mehr als
#: anderthalb wäre kein Verschieben mehr, sondern ein anderer Sollwert.
MAX_DELTA_K = 1.5
MAX_DRAW_K = 1.0
MIN_LEAD_H = 0.5
MAX_LEAD_H = 8.0


def _grenze(wert: float, unten: float, oben: float) -> float:
    return max(unten, min(oben, wert))


@dataclass(frozen=True)
class AutomatikConfig:
    """Die Einstellungen der Raumautomatik. Aus, bis jemand sie einschaltet."""

    enabled: bool = False
    #: Welche Räume mitmachen. Leer heißt: keiner - auch dann, wenn die Automatik an ist.
    rooms: tuple[int, ...] = ()
    delta_k: float = 0.5
    draw_k: float = 0.0
    lead_h: float = 3.0
    min_spread_ct: float = 5.0

    @classmethod
    def from_payload(cls, data: Mapping[str, object]) -> AutomatikConfig:
        """Aus der gespeicherten Konfiguration, mit harten Grenzen. Unsinn wird beschnitten."""

        def zahl(name: str, vorgabe: float) -> float:
            wert = data.get(name)
            return float(wert) if isinstance(wert, int | float) else vorgabe

        rohe = data.get("rooms")
        raeume = (
            tuple(int(r) for r in rohe if isinstance(r, int | float))
            if isinstance(rohe, list)
            else ()
        )
        return cls(
            enabled=bool(data.get("enabled", False)),
            rooms=raeume,
            delta_k=_grenze(zahl("delta_k", 0.5), 0.0, MAX_DELTA_K),
            draw_k=_grenze(zahl("draw_k", 0.0), 0.0, MAX_DRAW_K),
            lead_h=_grenze(zahl("lead_h", 3.0), MIN_LEAD_H, MAX_LEAD_H),
            min_spread_ct=max(0.0, zahl("min_spread_ct", 5.0)),
        )

    def payload(self) -> dict[str, object]:
        return {
            "enabled": self.enabled,
            "rooms": list(self.rooms),
            "delta_k": self.delta_k,
            "draw_k": self.draw_k,
            "lead_h": self.lead_h,
            "min_spread_ct": self.min_spread_ct,
        }

    def policy(self) -> ShiftPolicy:
        return ShiftPolicy(
            delta_k=self.delta_k,
            draw_k=self.draw_k,
            lead_h=self.lead_h,
            min_spread_ct=self.min_spread_ct,
        )


@dataclass(frozen=True)
class RaumZustand:
    """Was die Automatik über diesen Raum gespeichert hat."""

    base_setpoint_c: float
    offset_k: float
    written_setpoint_c: float
    written_at: datetime
    paused_until: datetime | None = None


@dataclass(frozen=True)
class Stellen:
    """Den Sollwert auf `setpoint_c` setzen. `base_c` ist die Rückfahrkarte."""

    setpoint_c: float
    base_c: float
    offset_k: float
    grund: str


@dataclass(frozen=True)
class Zurueckziehen:
    """Den gespeicherten Zustand vergessen; der Raum gehört wieder dem Menschen allein."""

    grund: str
    #: Gesetzt, wenn ein Mensch gestellt hat: So lange fasst die Automatik den Raum nicht an.
    ruhe_bis: datetime | None = None


Aktion = Stellen | Zurueckziehen | None


def _de(wert: float) -> str:
    """Ein Zehntel mit Komma. Die Grundlage steht im Protokoll, also in der Sprache des Hauses."""
    return f"{wert:.1f}".replace(".", ",")


def runde(wert: float) -> float:
    return round(wert, 1)


def entscheide(
    *,
    now: datetime,
    ziel_offset_k: float,
    grund: str,
    gemessen_c: float | None,
    gemessen_at: datetime | None,
    fenster_offen: bool,
    zustand: RaumZustand | None,
    schonfrist_min: float = SCHONFRIST_MIN,
) -> Aktion:
    """Was in diesem Raum jetzt zu tun ist. `None` heißt: nichts, und das ist der Normalfall."""
    if zustand is not None and zustand.paused_until is not None and now < zustand.paused_until:
        return None
    if gemessen_c is None:
        return None  # ohne gemeldeten Sollwert kein Eingriff

    angewandt = zustand is not None and abs(zustand.offset_k) > 1e-9
    if angewandt and zustand is not None:
        frisch = gemessen_at is not None and gemessen_at > zustand.written_at + timedelta(
            minutes=GNADENFRIST_MIN
        )
        if frisch and abs(gemessen_c - zustand.written_setpoint_c) > TOLERANZ_K:
            return Zurueckziehen(
                grund=(
                    f"Sollwert steht auf {_de(gemessen_c)} statt auf "
                    f"{_de(zustand.written_setpoint_c)} - jemand hat von Hand gestellt. "
                    "Die Automatik lässt diesen Raum in Ruhe."
                ),
                ruhe_bis=now + timedelta(hours=RUHE_NACH_EINGRIFF_H),
            )

    basis = zustand.base_setpoint_c if angewandt and zustand is not None else gemessen_c
    wunsch = 0.0 if fenster_offen else ziel_offset_k
    soll = runde(basis + wunsch)

    if abs(soll - gemessen_c) <= TOLERANZ_K:
        # Steht schon richtig. Ist dabei nichts mehr angehoben, gehört der Raum wieder dem
        # Menschen allein - dann darf auch die Rückfahrkarte weg, sonst hielte sie einen
        # Grundwert fest, den längst jemand anders gesetzt haben könnte.
        if abs(wunsch) <= 1e-9 and zustand is not None:
            return Zurueckziehen(grund="wieder auf dem Grundwert")
        return None

    if zustand is not None and now - zustand.written_at < timedelta(minutes=schonfrist_min):
        return None

    return Stellen(setpoint_c=soll, base_c=basis, offset_k=wunsch, grund=grund)
