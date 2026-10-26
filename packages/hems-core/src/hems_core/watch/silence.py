"""Der Wächter: welche Quelle schweigt, seit wann, und was deshalb fehlt.

**Der Anlass.** Am 23.10.2026 um 11:05 wies der MQTT-Broker die Brücke ab. Zwei Tage lang zeigte
die Wandanzeige vier satte Puffertemperaturen, die zu diesem Zeitpunkt gehörten, der Dienst
rechnete daraus keinen Ladezustand mehr, und niemand merkte es - bis ein Foto der Küchen-Anzeige
die Lücke zeigte. Duck Curve Home *wusste* die ganze Zeit, dass nichts mehr kommt. Es sagte es nur
dem, der genau hinsah.

**Was hier anders ist als „online".** Eine Verbindung kann stehen, während nichts durch sie geht;
genau das war der Fall. Der Wächter sieht deshalb nicht auf Verbindungen, sondern auf **Signale**:
Wann kam zu diesem Schlüssel zuletzt ein Wert? Die Brücke ist dabei nur eine Zeile von mehreren.

**Was nie da war, fehlt nicht.** Gemeldet wird nur, was schon einmal geliefert hat. Ein Haus ohne
Controme soll nicht täglich lesen, dass von Controme nichts kommt. Die einzige Ausnahme steht in
der Regel selbst (`expected`): Die Brücke wird auch dann erwartet, wenn der Dienst seit dem Start
noch nie etwas von ihr gehört hat - sonst wäre ausgerechnet der Fall „kaputt und neu gestartet"
der eine, den niemand meldet.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime
from typing import Literal

Severity = Literal["warn", "alarm"]

#: Schlüssel für die Verbindung der Brücke. Kein Messwert, sondern die Leitung selbst.
BRIDGE = "bridge"


@dataclass(frozen=True)
class WatchRule:
    """Ein Signal, das sich regelmäßig melden muss."""

    name: str
    #: Ein oder mehrere Messschlüssel. Die jüngste Meldung zählt: Vier Pufferfühler sind eine
    #: Sache, und drei davon nützen nichts, wenn der vierte fehlt - aber gemeldet wird die Gruppe.
    keys: tuple[str, ...]
    title_de: str
    #: So lange darf es still sein, bevor es ein Befund wird.
    silence_min: float
    severity: Severity
    #: Was ohne dieses Signal nicht mehr geht. Ohne diesen Satz ist eine Meldung nur ein Schreck.
    impact_de: str
    #: True: auch melden, wenn seit dem Start nie etwas kam.
    expected: bool = False
    #: Mehrzahl? „Die Puffertemperaturen melden sich wieder", „Die Brücke meldet sich wieder".
    #: Steht hier, weil der Satz der Entwarnung aus der Regel gebaut wird und kein Befund mehr da
    #: ist, aus dem man ihn nehmen könnte.
    plural: bool = False


#: Die Voreinstellung. Die Zeiten sind großzügiger als die Alterung im Snapshot (dort gilt ein
#: Wert nach Minuten als alt): Eine Mitteilung auf dem Telefon soll ein Ereignis sein, keine
#: Begleitmusik. Eine Minute Funkloch ist kein Ausfall.
RULES: tuple[WatchRule, ...] = (
    WatchRule(
        name=BRIDGE,
        keys=(BRIDGE,),
        title_de="Die Brücke",
        silence_min=20,
        severity="alarm",
        impact_de="Ohne sie kommt nichts aus dem Haus, und geschaltet wird auch nichts.",
        expected=True,
    ),
    WatchRule(
        name="buffer",
        keys=(
            "buffer_temp_top_c",
            "buffer_temp_mid_top_c",
            "buffer_temp_mid_bottom_c",
            "buffer_temp_bottom_c",
        ),
        title_de="Die Puffertemperaturen",
        silence_min=30,
        severity="alarm",
        impact_de="Ohne sie gibt es keinen Ladezustand und keine Entscheidung über die Wärmepumpe.",
        plural=True,
    ),
    WatchRule(
        name="power",
        keys=("pv_power_kw", "grid_power_kw", "battery_power_kw"),
        title_de="Die Leistungen",
        silence_min=20,
        severity="alarm",
        impact_de="Ohne sie weiß DCH nicht, was das Haus gerade tut.",
        plural=True,
    ),
    WatchRule(
        name="price",
        keys=("electricity_price_ct_kwh",),
        title_de="Der Strompreis",
        silence_min=180,
        severity="warn",
        impact_de="Der Fahrplan läuft weiter, aber ohne Preisblick.",
    ),
    WatchRule(
        name="weather",
        keys=("outdoor_temp_c",),
        title_de="Die Außentemperatur",
        silence_min=180,
        severity="warn",
        impact_de="Wärmebedarf und Sonnenprognose werden ungenauer.",
    ),
)


@dataclass(frozen=True)
class Finding:
    """Ein Befund: dieses Signal schweigt seit dieser Zeit, und das fehlt deshalb."""

    name: str
    title_de: str
    severity: Severity
    #: Wann zuletzt etwas kam. None heißt: seit dem Start des Dienstes nie.
    since: datetime | None
    silent_min: float
    text_de: str


def silence_text(minutes: float) -> str:
    """„seit 40 Minuten", „seit 3 Stunden", „seit 2 Tagen" - die Einheit, die man nachvollzieht."""
    if minutes < 90:
        return f"seit {round(minutes)} Minuten"
    hours = minutes / 60
    if hours < 36:
        return f"seit {round(hours)} Stunden"
    days = hours / 24
    return f"seit {round(days)} Tagen"


def findings(
    last_seen: Mapping[str, datetime | None],
    now: datetime,
    started_at: datetime | None = None,
    rules: tuple[WatchRule, ...] = RULES,
) -> list[Finding]:
    """Die offenen Befunde, die schwersten zuerst, bei gleicher Schwere die ältesten.

    `last_seen` hält je Schlüssel den Zeitpunkt der letzten Meldung; ein Schlüssel, der gar nicht
    vorkommt, gilt als nie gesehen. `started_at` ist der Start des Dienstes und zählt nur für
    Regeln mit `expected`: Dort beginnt die Stille beim Start und nicht in der Ewigkeit.
    """
    out: list[Finding] = []
    for rule in rules:
        zeiten = [last_seen.get(k) for k in rule.keys]
        bekannt = [t for t in zeiten if t is not None]
        if not bekannt:
            if not rule.expected or started_at is None:
                continue
            seit: datetime | None = None
            stille = (now - started_at).total_seconds() / 60
        else:
            juengste = max(bekannt)
            seit = juengste
            stille = (now - juengste).total_seconds() / 60
        if stille < rule.silence_min:
            continue
        out.append(
            Finding(
                name=rule.name,
                title_de=rule.title_de,
                severity=rule.severity,
                since=seit,
                silent_min=stille,
                text_de=f"{rule.title_de} {silence_text(stille)} still. {rule.impact_de}",
            )
        )
    out.sort(key=lambda f: (0 if f.severity == "alarm" else 1, -f.silent_min))
    return out


def back_text(rule: WatchRule) -> str:
    """Die Entwarnung. Aus der Regel gebaut, weil es keinen Befund mehr gibt, wenn sie fällig ist."""
    return f"{rule.title_de} {'melden' if rule.plural else 'meldet'} sich wieder."


def rule_by_name(name: str, rules: tuple[WatchRule, ...] = RULES) -> WatchRule | None:
    return next((r for r in rules if r.name == name), None)
