"""Das Protokoll eines Raums: jede Sollwertänderung mit Zeitpunkt, Urheber und Grund.

**Wozu das gebraucht wird.** Ein Raum wird wärmer, als er soll, und die Frage lautet: Hat jemand
gestellt, war es die Automatik, oder hat sich gar nichts geändert und es liegt an der Anlage? Die
Raumseite zeigt bisher Kurven; sie beantwortet die Frage nicht, weil in einer Kurve nicht steht,
wer sie verursacht hat.

**Zwei Quellen, die sich gegenseitig prüfen.**

1. Die *Messreihe* `room_<id>_setpoint_c`. Sie sagt, **dass** sich etwas geändert hat, und zwar
   lückenlos - egal, wer es war. Sie sagt nie, warum.
2. Die *Ereignisse* `rooms.setpoint` (ein Mensch über dieses Werkzeug) und `rooms.automatik`
   (die Automatik, mit ihrer Begründung im Text). Sie sagen, **warum**, aber nur für Änderungen,
   die durch dieses Haus gegangen sind.

Verschmolzen ergibt das drei Fälle, und der dritte ist der ehrliche Teil:

| Sprung in der Reihe | passendes Ereignis | heißt |
| --- | --- | --- |
| ja | `rooms.setpoint` | hier gestellt |
| ja | `rooms.automatik` | die Automatik, mit Grund |
| ja | keines | **von außen** |
| nein | eines | Befehl ohne sichtbare Wirkung |

**„Von außen" heißt nicht „der Nutzer".** Es heißt nur: nicht über dieses Werkzeug. Dahinter kann
die Controme-App stecken, das Bedienteil an der Wand - oder Contromes eigenes Heizprogramm, das
ohne jedes Zutun zur eingestellten Stunde umschaltet. Diese drei lassen sich von hier aus nicht
unterscheiden, und sie als „Nutzeränderung" auszugeben wäre eine Behauptung über einen Menschen,
die die Daten nicht hergeben.

**Gerechnet wird auf Minuten, nicht auf Fenstermitteln.** Die Kurve der Anzeige ist verdichtet;
ein Sollwertsprung im Mittel einer Viertelstunde läge irgendwo in diesen fünfzehn Minuten und
hätte unterwegs Zwischenwerte, die nie jemand gestellt hat. Die Sprünge kommen deshalb aus den
Minutenzeilen, die Kurve aus der Verdichtung - zwei Blicke auf dieselben Daten.

Dieses Modul rechnet nur. Es liest nichts und kennt weder Datenbank noch HTTP.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from itertools import pairwise
from typing import Literal

from dch_api import urheber as urheber_logik

#: Ab wann zwei Sollwerte verschieden sind. Controme führt Zehntel; alles darunter ist Rundung.
SPRUNG_K = 0.05

#: Wie lange nach einem Befehl der zugehörige Sprung noch als dessen Wirkung gilt.
#:
#: **Warum so großzügig.** Zwischen Befehl und Messwert liegen zwei Wartezeiten: Controme
#: übernimmt den Wert, und die Brücke fragt alle zwei Minuten nach. Sechs Minuten decken beides
#: mit Reserve ab. Zu eng gewählt, erschiene jeder eigene Befehl zusätzlich als Änderung „von
#: außen" - und das Protokoll behauptete einen Fremdeingriff, den es nie gab.
ZUORDNUNG_MIN = 6.0

#: Ein Sprung darf auch knapp *vor* dem Ereignis liegen: die Brücke stößt die Abfrage sofort an,
#: und die Uhren von Dienst und Anlage gehen nicht auf die Sekunde gleich.
VORLAUF_MIN = 1.0

Quelle = Literal["app", "automatik", "extern"]
Art = Literal["sollwert", "befehl", "ruhe", "einstellung"]

#: Die Ereigniscodes, die in einem Raumprotokoll vorkommen.
CODE_SETPOINT = "rooms.setpoint"
CODE_AUTOMATIK = "rooms.automatik"
CODES = (CODE_SETPOINT, CODE_AUTOMATIK)


@dataclass(frozen=True, slots=True)
class Sprung:
    """Der Sollwert stand auf `von` und steht ab `at` auf `nach`."""

    at: datetime
    von: float
    nach: float


@dataclass(frozen=True, slots=True)
class RohEreignis:
    """Ein Protokolleintrag, wie er aus der Datenbank kommt - ohne deren Typen."""

    at: datetime
    code: str
    message: str
    context: Mapping[str, object]


@dataclass(frozen=True, slots=True)
class Eintrag:
    """Eine Zeile des Protokolls."""

    at: datetime
    quelle: Quelle
    art: Art
    von: float | None
    nach: float | None
    text: str
    #: Wer es war, als Anzeigezeile („iPad Flur", später „Moritz, am iPad Flur"). Leer, wenn es
    #: niemand sagen kann: bei Änderungen von außen, und bei Zeilen aus der Zeit vor dieser
    #: Aufzeichnung. **Leer heißt unbekannt, nicht „niemand".**
    urheber: str = ""


def _zahl(wert: object) -> float | None:
    return float(wert) if isinstance(wert, int | float) and not isinstance(wert, bool) else None


def punkte(
    rows: Sequence[Mapping[str, float | str | None]], key: str
) -> list[tuple[datetime, float]]:
    """Aus Minutenzeilen die belegten Werte einer Reihe ziehen, nach Zeit sortiert.

    Zeilen ohne diesen Wert fallen weg. Eine Lücke ist keine Änderung: Wenn die Anlage eine Stunde
    geschwiegen hat, ist der Sollwert danach nicht „gesprungen", er war die ganze Zeit unbekannt.
    """
    out: list[tuple[datetime, float]] = []
    for row in rows:
        roh = row.get("ts")
        if not isinstance(roh, str):
            continue
        wert = _zahl(row.get(key))
        if wert is None:
            continue
        try:
            out.append((datetime.fromisoformat(roh.replace("Z", "+00:00")), wert))
        except ValueError:
            continue
    out.sort(key=lambda p: p[0])
    return out


def spruenge(werte: Sequence[tuple[datetime, float]], schwelle: float = SPRUNG_K) -> list[Sprung]:
    """Wo sich der Sollwert geändert hat. Der Zeitpunkt ist der des ersten neuen Messwerts.

    Das ist eine obere Schranke: Gestellt wurde irgendwann zwischen dem letzten alten und diesem
    ersten neuen Wert, also höchstens eine Minute früher. Genauer geht es nicht, und so zu tun,
    als ginge es, wäre schlimmer als die Minute Unschärfe.
    """
    out: list[Sprung] = []
    for (_, vorher), (zeit, jetzt) in pairwise(werte):
        if abs(jetzt - vorher) > schwelle:
            out.append(Sprung(at=zeit, von=vorher, nach=jetzt))
    return out


def gehoert_zu_raum(ereignis: RohEreignis, room_id: int) -> bool:
    """Ob dieses Ereignis in das Protokoll dieses Raums gehört.

    Die Einstellung der Automatik nennt keinen Raum und gilt trotzdem für jeden: Dass jemand die
    Automatik ausgeschaltet hat, erklärt, warum dieser Raum seither in Ruhe gelassen wird.
    """
    roh = ereignis.context.get("room")
    if roh is None:
        return ereignis.code == CODE_AUTOMATIK and "enabled" in ereignis.context
    return _zahl(roh) == float(room_id)


def _quelle(code: str) -> Quelle:
    return "app" if code == CODE_SETPOINT else "automatik"


def _art(ereignis: RohEreignis) -> Art:
    if "enabled" in ereignis.context and ereignis.context.get("room") is None:
        return "einstellung"
    return "sollwert" if _zahl(ereignis.context.get("to")) is not None else "ruhe"


def verschmelze(
    saetze: Sequence[Sprung],
    ereignisse: Sequence[RohEreignis],
    *,
    toleranz_min: float = ZUORDNUNG_MIN,
    vorlauf_min: float = VORLAUF_MIN,
) -> list[Eintrag]:
    """Sprünge und Ereignisse zu einer Zeitleiste zusammenlegen, älteste zuerst.

    Jedes Ereignis bekommt höchstens einen Sprung, und jeder Sprung höchstens ein Ereignis. Ohne
    diese Einschränkung hätte ein Raum, in dem die Automatik dreimal hintereinander auf denselben
    Wert stellt, drei Ereignisse am selben Sprung hängen.
    """
    frei = list(saetze)
    out: list[Eintrag] = []
    fenster = timedelta(minutes=toleranz_min)
    vorlauf = timedelta(minutes=vorlauf_min)

    for ev in sorted(ereignisse, key=lambda e: e.at):
        art = _art(ev)
        quelle = _quelle(ev.code)
        wer = urheber_logik.aus_kontext(ev.context)
        wer_text = wer.text() if wer is not None else ""
        ziel = _zahl(ev.context.get("to"))
        if art != "sollwert" or ziel is None:
            out.append(
                Eintrag(
                    at=ev.at,
                    quelle=quelle,
                    art=art,
                    von=None,
                    nach=None,
                    text=ev.message,
                    urheber=wer_text,
                )
            )
            continue
        treffer = next(
            (
                s
                for s in frei
                if abs(s.nach - ziel) <= SPRUNG_K and -vorlauf <= s.at - ev.at <= fenster
            ),
            None,
        )
        if treffer is None:
            # Befohlen, aber nie gemeldet. Das ist eine Aussage und keine Lücke: Entweder hat die
            # Anlage den Wert nicht übernommen, oder sie stand ohnehin schon dort.
            out.append(
                Eintrag(
                    at=ev.at,
                    quelle=quelle,
                    art="befehl",
                    von=_zahl(ev.context.get("from")),
                    nach=ziel,
                    text=ev.message,
                    urheber=wer_text,
                )
            )
            continue
        frei.remove(treffer)
        out.append(
            Eintrag(
                at=treffer.at,
                quelle=quelle,
                art="sollwert",
                von=treffer.von,
                nach=treffer.nach,
                text=ev.message,
                urheber=wer_text,
            )
        )

    for s in frei:
        out.append(
            Eintrag(at=s.at, quelle="extern", art="sollwert", von=s.von, nach=s.nach, text="")
        )

    out.sort(key=lambda e: e.at)
    return out
