"""Wann die Automatik einen Raum vorlädt - und wann sie ihn wieder in Ruhe lässt.

**Die Idee.** Estrich und Wände eines Raums sind ein Speicher mit rund 25 Stunden Zeitkonstante
(siehe `room_shift`). Wer ihn vor einem Preishoch um ein halbes Kelvin auflädt, kauft dieselbe
Wärme billiger und lässt den Raum während der teuren Stunden von diesem Vorrat zehren.

**Die Regel macht einen Raum höchstens wärmer, nie kälter.** Angehoben wird vor dem Preishoch;
während des Preishochs steht der Sollwert wieder auf dem Wert, den der Mensch gesetzt hat - der
Raum ist dann von selbst darüber und fordert keine Wärme an, bis er sich abgekühlt hat. Das ist
der ganze Trick, und er braucht kein Absenken. Wer trotzdem absenken will, stellt `draw_k`; die
Voreinstellung ist null, weil ein Werkzeug, das die Wohnung ohne Nachfrage kälter macht, eine
andere Zusage bricht als eines, das sie wärmer macht.

**Die Entscheidung hängt nur an jetzt und am Preis.** Kein Gedächtnis, kein Zustand, keine
Zeitgeber: Dieselbe Minute führt nach einem Neustart zur selben Entscheidung. Damit kann die
Automatik nicht in einer angehobenen Phase hängen bleiben, weil ein Dienst zur falschen Zeit
neu startete - das Schlimmste, was ein Heizungseingriff tun kann.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Literal

from hems_core.planning.price_windows import PricePoint, PriceWindow

Phase = Literal["laden", "zehren", "aus"]


@dataclass(frozen=True)
class ShiftPolicy:
    """Die Grenzen, in denen die Automatik arbeiten darf."""

    #: Um so viel wird vor dem Preishoch angehoben.
    delta_k: float = 0.5
    #: Um so viel wird während des Preishochs abgesenkt. Null heißt: zurück auf den Wert des Menschen.
    draw_k: float = 0.0
    #: So früh beginnt das Vorladen. Drei Stunden sind ein Kompromiss: Der Estrich braucht Stunden,
    #: aber was zu früh geladen wird, ist zum Preishoch schon halb an die Umgebung weg.
    lead_h: float = 3.0
    #: Unter diesem Preisabstand bleibt alles, wie es ist. Ein halbes Kelvin für zwei Cent
    #: Unterschied ist Unruhe ohne Ertrag.
    min_spread_ct: float = 5.0
    #: Länger als so wird nicht gezehrt; danach ist der Vorrat ohnehin weg.
    max_draw_h: float = 6.0
    #: So weit wird nach dem nächsten Preishoch gesucht.
    horizon_h: float = 18.0


#: Die Voreinstellung als ein Stück, damit sie nicht bei jedem Aufruf neu entsteht.
STANDARD = ShiftPolicy()


@dataclass(frozen=True)
class ShiftTarget:
    """Was die Automatik gerade will. `offset_k` ist der Aufschlag auf den Sollwert des Menschen."""

    offset_k: float
    phase: Phase
    until: datetime | None
    window_start: datetime | None
    window_end: datetime | None
    spread_ct: float | None
    reason_de: str


#: Das Ziel, wenn die Automatik aus ist: nichts anheben, und das auch sagen.
AUS = ShiftTarget(
    offset_k=0.0,
    phase="aus",
    until=None,
    window_start=None,
    window_end=None,
    spread_ct=None,
    reason_de="Die Automatik ist ausgeschaltet.",
)


def _uhr(ts: datetime | None) -> str:
    return "-" if ts is None else ts.strftime("%H:%M")


def _ct(x: float) -> str:
    """Eine Zahl, wie sie hier gelesen wird: mit Komma. Die Begründung landet in der Anzeige."""
    return f"{x:g}".replace(".", ",")


def _mittel(prices: Sequence[PricePoint], start: datetime, end: datetime) -> float | None:
    drin = [p.ct_kwh for p in prices if p.end > start and p.start < end]
    return sum(drin) / len(drin) if drin else None


def _aus(
    grund: str, fenster: PriceWindow | None = None, spread: float | None = None
) -> ShiftTarget:
    return ShiftTarget(
        offset_k=0.0,
        phase="aus",
        until=None,
        window_start=fenster.start if fenster else None,
        window_end=fenster.end if fenster else None,
        spread_ct=spread,
        reason_de=grund,
    )


def next_expensive(
    windows: Sequence[PriceWindow], now: datetime, horizon_h: float
) -> PriceWindow | None:
    """Das nächste Preishoch, das noch nicht vorbei ist und nah genug liegt."""
    grenze = now + timedelta(hours=horizon_h)
    offen = [w for w in windows if w.kind == "expensive" and w.end > now and w.start <= grenze]
    return min(offen, key=lambda w: w.start) if offen else None


def shift_target(
    now: datetime,
    prices: Sequence[PricePoint],
    windows: Sequence[PriceWindow],
    policy: ShiftPolicy = STANDARD,
) -> ShiftTarget:
    """Der Aufschlag, den die Automatik in dieser Minute haben will, mit Begründung."""
    teuer = next_expensive(windows, now, policy.horizon_h)
    if teuer is None:
        return _aus("Kein Preishoch in Sicht.")

    lade_start = teuer.start - timedelta(hours=policy.lead_h)
    vorher = _mittel(prices, lade_start, teuer.start)
    if vorher is None:
        return _aus("Für die Stunden vor dem Preishoch fehlen die Preise.", teuer)
    spread = round(teuer.avg_ct_kwh - vorher, 1)
    if spread < policy.min_spread_ct:
        return _aus(
            f"Abstand zum Preishoch ab {_uhr(teuer.start)} nur {_ct(spread)} ct - zu wenig.",
            teuer,
            spread,
        )

    if lade_start <= now < teuer.start:
        return ShiftTarget(
            offset_k=policy.delta_k,
            phase="laden",
            until=teuer.start,
            window_start=teuer.start,
            window_end=teuer.end,
            spread_ct=spread,
            reason_de=(
                f"Vorladen für das Preishoch {_uhr(teuer.start)} bis {_uhr(teuer.end)}: "
                f"{_ct(spread)} ct günstiger als dort."
            ),
        )

    zehr_ende = min(teuer.end, teuer.start + timedelta(hours=policy.max_draw_h))
    if teuer.start <= now < zehr_ende:
        return ShiftTarget(
            offset_k=-policy.draw_k,
            phase="zehren",
            until=zehr_ende,
            window_start=teuer.start,
            window_end=teuer.end,
            spread_ct=spread,
            reason_de=(
                f"Preishoch bis {_uhr(zehr_ende)}: Der Raum zehrt vom Vorrat, "
                "der Sollwert steht wieder auf deinem Wert."
                if policy.draw_k <= 0
                else f"Preishoch bis {_uhr(zehr_ende)}: {_ct(policy.draw_k)} K abgesenkt."
            ),
        )

    return _aus(f"Vorladen beginnt um {_uhr(lade_start)}.", teuer, spread)
