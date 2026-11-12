"""Der Morgenbrief aus dem Fahrplan des Dienstes.

Gerechnet und formuliert wird in `hems_core.planning.morgenbrief`. Hier steht nur, wie aus dem
Fahrplan, den die Oberfläche auch bekommt, die Viertelstunden für den Brief werden, und was der
Dienst über den Brief nach außen sagt.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, tzinfo

from dch_api.schemas import MorgenbriefOut, PlanOut
from hems_core.planning.morgenbrief import Brief, Viertel, morgenbrief

#: Die Ortsstunde, ab der der Brief verschickt wird.
BRIEF_STUNDE = 7
#: So lange wird es versucht. Danach ist es kein Morgenbrief mehr: nach einem Neustart um drei
#: Uhr nachmittags kommt keiner.
BRIEF_BIS_STUNDE = 9


def aus_plan(plan: PlanOut | None, jetzt: datetime, tz: tzinfo) -> Brief | None:
    """Der Brief für heute aus dem Fahrplan, oder `None`, wenn der Fahrplan dafür nicht reicht."""
    if plan is None:
        return None
    viertel = [
        Viertel(
            ts=iv.ts,
            preis_ct=iv.price_ct_kwh,
            pv_kw=max(0.0, iv.expected_pv_kw),
            # Nur was der Optimierer geplant hat. Wo die Preisregel einspringt, steht kein Lauf.
            wp=iv.reason_code == "planned_optimizer" and iv.planned_hp_state == "release",
        )
        for iv in plan.intervals
    ]
    hat_fahrplan = any(iv.reason_code == "planned_optimizer" for iv in plan.intervals)
    return morgenbrief(viertel, jetzt=jetzt, tz=tz, hat_fahrplan=hat_fahrplan)


def faellig(jetzt: datetime, tz: tzinfo, zuletzt_am: object) -> bool:
    """Ist jetzt die Zeit für den Brief, und ist er heute noch nicht verschickt?"""
    lokal = jetzt.astimezone(tz)
    return BRIEF_STUNDE <= lokal.hour < BRIEF_BIS_STUNDE and zuletzt_am != lokal.date()


def naechster_versand(jetzt: datetime, tz: tzinfo) -> datetime:
    """Der Zeitpunkt, für den die Vorschau gilt: der nächste Morgen, an dem ein Brief ginge.

    Abends um elf ist „der Rest von heute" eine Viertelstunde, und dafür gibt es keinen Brief.
    Wer die Seite dann öffnet, will sehen, was morgen früh kommt. Zwischen sieben und neun ist
    es der Brief von jetzt, davor der von heute um sieben, danach der von morgen um sieben.
    """
    lokal = jetzt.astimezone(tz)
    if BRIEF_STUNDE <= lokal.hour < BRIEF_BIS_STUNDE:
        return jetzt
    ziel = lokal.replace(hour=BRIEF_STUNDE, minute=0, second=0, microsecond=0)
    if lokal.hour >= BRIEF_BIS_STUNDE:
        ziel += timedelta(days=1)
    return ziel


def zuletzt_satz(am: date | None, erreicht: int | None, geraete: int | None) -> str:
    """Wann der Brief zuletzt ging und bei wie vielen Geräten er ankam, als Satz.

    Ohne diesen Satz ist ein Brief, der nicht kommt, nicht von einem zu unterscheiden, der nie
    verschickt wurde (Nutzer am 12.11.2026: „Ich bekomme gar keine Push-Nachrichten. Da war
    doch ein Morgenbrief geplant."). Die Zahlen fehlen bei Briefen aus der Zeit davor.
    """
    if am is None:
        return "Bisher ist kein Morgenbrief verschickt worden."
    tag = f"{am.day}.{am.month}.{am.year}"
    if erreicht is None or geraete is None:
        return f"Zuletzt verschickt am {tag}."
    wort = "1 Gerät" if geraete == 1 else f"{geraete} Geräten"
    if erreicht == 0:
        return (
            f"Zuletzt verschickt am {tag}, aber von {wort} hat keines ihn angenommen. "
            "Warum, zeigt eine Probe bei den Mitteilungen."
        )
    return f"Zuletzt verschickt am {tag}, angekommen bei {erreicht} von {wort}."


def vorschau(
    an: bool, plan: PlanOut | None, jetzt: datetime, tz: tzinfo, zuletzt_de: str = ""
) -> MorgenbriefOut:
    """Was der Dienst über den Brief sagt: ob er kommt, und wie der nächste aussähe."""
    wann = naechster_versand(jetzt, tz)
    morgen = wann.astimezone(tz).date() > jetzt.astimezone(tz).date()
    brief = aus_plan(plan, wann, tz)
    return MorgenbriefOut(
        enabled=an,
        uhrzeit=f"{BRIEF_STUNDE:02d}:00",
        fuer_de="morgen" if morgen else "heute",
        titel=brief.titel if brief else None,
        zeilen=list(brief.zeilen) if brief else [],
        hinweis_de=""
        if brief
        else (
            "Für morgen reicht der Fahrplan noch nicht; die Preise kommen am frühen Nachmittag."
            if morgen
            else "Für heute gibt es gerade keinen Brief: der Fahrplan reicht dafür nicht."
        ),
        zuletzt_de=zuletzt_de,
    )
