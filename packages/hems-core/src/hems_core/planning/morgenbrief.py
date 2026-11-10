"""Der Morgenbrief: was der Tag bringt, in drei Zeilen aufs Handy.

Die Startseite sagt das auch, aber dazu muss man sie öffnen. Der Brief kommt von selbst, um
sieben, und sagt, was sich an diesem Tag zu wissen lohnt, bevor man das Haus verlässt:

- wie viel Sonne zu erwarten ist und wann am meisten,
- wann Netzstrom am günstigsten und wann am teuersten ist,
- wann die Wärmepumpe laufen soll.

Das sind dieselben Auskünfte wie im Ausblick der Startseite (`apps/web/.../home/ausblick.ts`),
mit denselben Festlegungen: ein Fenster ist zwei Stunden lang, ein Preisfenster gibt es erst ab
vier Cent Unterschied, ein Sonnenfenster erst ab einem Kilowatt im Mittel. Der Ausblick schaut 24
Stunden voraus; der Brief schaut auf den Rest des heutigen Tages, denn „morgen 02:00" ist morgens
um sieben keine Auskunft für heute.

Reine Rechnung, kein I/O. Sätze in Alltagssprache, ohne Wörter des Reglers.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta, tzinfo
from itertools import pairwise

SCHRITT = timedelta(minutes=15)
#: Ein Fenster für alles, was warten kann: zwei Stunden.
FENSTER = 8
#: Unter dieser Spanne zwischen billigstem und teuerstem Preis lohnt kein Hinweis.
MIN_SPANNE_CT = 4.0
#: Ein Sonnenfenster wird nur genannt, wenn die Erwartung darin im Mittel so hoch ist.
SONNENFENSTER_AB_KW = 1.0
#: Unter so vielen Kilowattstunden am Tag heißt es „kaum Sonne".
WENIG_SONNE_KWH = 2.0
#: So viele Läufe der Wärmepumpe nennt der Brief einzeln.
MAX_LAEUFE = 3


@dataclass(frozen=True)
class Viertel:
    """Eine Viertelstunde des Fahrplans, soweit der Brief sie braucht."""

    ts: datetime
    preis_ct: float | None
    pv_kw: float
    #: Der Optimierer hat hier einen Lauf der Wärmepumpe geplant.
    wp: bool


@dataclass(frozen=True)
class Brief:
    titel: str
    zeilen: tuple[str, ...]

    @property
    def text(self) -> str:
        return "\n".join(self.zeilen)


def _uhr(t: datetime, tz: tzinfo) -> str:
    return t.astimezone(tz).strftime("%H:%M")


def _bestes(
    reihe: Sequence[Viertel], wert: str, *, kleinstes: bool
) -> tuple[datetime, datetime, float] | None:
    """Die zwei Stunden am Stück mit dem kleinsten oder größten Mittel. Lücken zählen nicht."""
    bestes: tuple[datetime, datetime, float] | None = None
    for i in range(len(reihe) - FENSTER + 1):
        stueck = reihe[i : i + FENSTER]
        werte = [getattr(v, wert) for v in stueck]
        if any(w is None for w in werte):
            continue
        if any(b.ts - a.ts != SCHRITT for a, b in pairwise(stueck)):
            continue
        mittel = sum(werte) / FENSTER
        besser = bestes is None or (mittel < bestes[2] if kleinstes else mittel > bestes[2])
        if besser:
            bestes = (stueck[0].ts, stueck[-1].ts + SCHRITT, mittel)
    return bestes


def _laeufe(reihe: Sequence[Viertel]) -> list[tuple[datetime, datetime]]:
    out: list[tuple[datetime, datetime]] = []
    for v in reihe:
        if not v.wp:
            continue
        if out and out[-1][1] == v.ts:
            out[-1] = (out[-1][0], v.ts + SCHRITT)
        else:
            out.append((v.ts, v.ts + SCHRITT))
    return out


def morgenbrief(
    viertel: Sequence[Viertel], *, jetzt: datetime, tz: tzinfo, hat_fahrplan: bool = True
) -> Brief | None:
    """Der Brief für den Rest des heutigen Tages, oder `None`, wenn es nichts zu sagen gibt."""
    heute = jetzt.astimezone(tz).date()
    reihe = sorted(
        (v for v in viertel if v.ts + SCHRITT > jetzt and v.ts.astimezone(tz).date() == heute),
        key=lambda v: v.ts,
    )
    if len(reihe) < FENSTER:
        return None
    zeilen: list[str] = []

    # --- Sonne
    kwh = sum(v.pv_kw for v in reihe) * 0.25
    if kwh < WENIG_SONNE_KWH:
        zeilen.append("Sonne: heute kaum etwas zu erwarten.")
    else:
        sonnig = _bestes(reihe, "pv_kw", kleinstes=False)
        wann = (
            f", am meisten von {_uhr(sonnig[0], tz)} bis {_uhr(sonnig[1], tz)}"
            if sonnig and sonnig[2] >= SONNENFENSTER_AB_KW
            else ""
        )
        zeilen.append(f"Sonne: rund {kwh:.0f} kWh erwartet{wann}.")

    # --- Preis
    mit_preis = [v for v in reihe if v.preis_ct is not None]
    if len(mit_preis) >= FENSTER:
        preise = [v.preis_ct for v in mit_preis if v.preis_ct is not None]
        tief, hoch = min(preise), max(preise)
        if hoch - tief < MIN_SPANNE_CT:
            mitte = sum(preise) / len(preise)
            zeilen.append(f"Strom: der Preis bleibt heute nahezu gleich, um {mitte:.0f} ct.")
        else:
            teuerste = max(mit_preis, key=lambda v: v.preis_ct or 0.0)
            guenstig = _bestes(reihe, "preis_ct", kleinstes=True)
            teuer = f"am teuersten um {_uhr(teuerste.ts, tz)} ({hoch:.0f} ct)"
            if guenstig:
                zeilen.append(
                    f"Strom: am günstigsten von {_uhr(guenstig[0], tz)} bis "
                    f"{_uhr(guenstig[1], tz)} (rund {guenstig[2]:.0f} ct), {teuer}."
                )
            else:
                zeilen.append(f"Strom: {teuer}, am günstigsten sind {tief:.0f} ct.")

    # --- Wärmepumpe
    if hat_fahrplan:
        laeufe = _laeufe(reihe)
        if not laeufe:
            zeilen.append("Wärmepumpe: heute kein Lauf geplant.")
        else:
            genannt = [f"{_uhr(a, tz)} bis {_uhr(b, tz)}" for a, b in laeufe[:MAX_LAEUFE]]
            liste = (
                genannt[0] if len(genannt) == 1 else ", ".join(genannt[:-1]) + " und " + genannt[-1]
            )
            mehr = len(laeufe) - MAX_LAEUFE
            rest = (
                f" und {mehr} weitere Male"
                if mehr > 1
                else " und ein weiteres Mal"
                if mehr == 1
                else ""
            )
            zeilen.append(f"Wärmepumpe: geplant von {liste}{rest}.")

    return Brief(titel="Heute im Haus", zeilen=tuple(zeilen))
