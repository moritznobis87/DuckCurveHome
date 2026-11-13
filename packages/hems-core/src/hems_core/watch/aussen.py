"""Stimmt die Außentemperatur, die das Haus meldet?

**Anlass.** Am 13.11.2026 um 12:49 stand auf der Startseite „2,2 °C draußen", während es
draußen 8 bis 9 Grad hatte (Nutzer: „Woher kommt diese Angabe?"). Der Wert kam nicht von einem
Fühler am Haus, sondern von einer Wetterstation, die über Home Assistant eingebunden ist, und er
war entweder alt oder stehengeblieben. Die Seite zeigte ihn ohne Alter und ohne Zweifel.

**Die Gegenprobe ist der Wetterdienst**, dessen Vorhersage der Dienst ohnehin lädt, für den Ort
des Hauses und die laufende Stunde. Er ist kein Fühler und kann selbst um zwei, drei Grad
danebenliegen. Aber er bleibt nicht stehen, und ein Messwert, der fünf Grad von ihm abweicht
oder anderthalb Stunden alt ist, verdient kein Vertrauen mehr.

**Was dann geschieht.** Angezeigt wird der Wert des Wetterdienstes, mit dem Wort dazu, und ein
Satz sagt, warum. Gespeichert wird weiter, was gemessen wurde: die Prüfung ändert die Anzeige,
nicht die Reihe. Gemeldet aufs Telefon wird nichts; eine falsche Außentemperatur ist kein
Notfall.

**Die Grenze von fünf Grad ist gesetzt, nicht gemessen.** Sie ist weit genug, dass eine
gewöhnliche Abweichung zwischen Vorhersage und Wirklichkeit sie nicht auslöst. Kommt die
Außentemperatur später von einem echten Fühler am Haus (Wärmepumpe), kann sie zu eng sein: ein
Fühler in der Sonne liegt leicht fünf Grad über der Luft. Dann gehört sie neu angesehen.

Reine Rechnung, kein I/O.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, tzinfo

#: Ab dieser Abweichung vom Wetterdienst gilt der Messwert als unglaubwürdig.
ABWEICHUNG_K = 5.0
#: Ab diesem Alter gilt der Messwert als veraltet. Die Wetterstation meldet stündlich.
ALT_MIN = 90.0
QUELLE_WETTERDIENST = "Wetterdienst"


@dataclass(frozen=True)
class Aussenpruefung:
    #: Was die Oberfläche zeigen soll. `None`: weder Messwert noch Wetterdienst.
    angezeigt_c: float | None
    #: Leer, wenn der Messwert gezeigt wird; sonst, woher der gezeigte Wert stattdessen kommt.
    quelle_de: str
    #: Der Befund als ganzer Satz, leer, wenn nichts zu sagen ist.
    text_de: str
    alter_min: float | None


def _grad(wert: float) -> str:
    return f"{wert:.1f}".replace(".", ",") + " °C"


def pruefe(
    gemessen_c: float | None,
    gemessen_um: datetime | None,
    wetterdienst_c: float | None,
    jetzt: datetime,
    tz: tzinfo,
) -> Aussenpruefung:
    alter = (
        max(0.0, (jetzt - gemessen_um).total_seconds() / 60.0)
        if gemessen_c is not None and gemessen_um is not None
        else None
    )
    if gemessen_c is None:
        # Kein Messwert. Dass die Quelle schweigt, meldet der Wächter nach seiner eigenen Frist;
        # hier wird nur dafür gesorgt, dass trotzdem eine Zahl dasteht.
        quelle = QUELLE_WETTERDIENST if wetterdienst_c is not None else ""
        return Aussenpruefung(wetterdienst_c, quelle, "", None)

    alt = alter is not None and alter > ALT_MIN
    von = f"von {gemessen_um.astimezone(tz):%H:%M} Uhr" if gemessen_um is not None else ""
    if wetterdienst_c is None:
        # Ohne Gegenprobe bleibt der Messwert stehen. Ist er alt, sagt der Satz wenigstens das.
        text = f"Die Außentemperatur ({_grad(gemessen_c)}) ist {von}." if alt else ""
        return Aussenpruefung(gemessen_c, "", text, alter)

    if alt:
        return Aussenpruefung(
            wetterdienst_c,
            QUELLE_WETTERDIENST,
            f"Der Messwert der Außentemperatur ist {von} ({_grad(gemessen_c)}). Angezeigt wird "
            f"der Wert des Wetterdienstes ({_grad(wetterdienst_c)}).",
            alter,
        )
    abstand = abs(gemessen_c - wetterdienst_c)
    if abstand > ABWEICHUNG_K:
        return Aussenpruefung(
            wetterdienst_c,
            QUELLE_WETTERDIENST,
            f"Der Messwert der Außentemperatur ({_grad(gemessen_c)}) weicht um "
            f"{abstand:.0f} Grad vom Wetterdienst ab ({_grad(wetterdienst_c)}) und ist "
            "vermutlich stehengeblieben. Angezeigt wird der Wert des Wetterdienstes.",
            alter,
        )
    return Aussenpruefung(gemessen_c, "", "", alter)
