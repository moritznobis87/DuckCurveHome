"""Der Morgenbrief aus dem Fahrplan des Dienstes.

Gerechnet und formuliert wird in `hems_core.planning.morgenbrief`. Hier steht nur, wie aus dem
Fahrplan, den die Oberfläche auch bekommt, die Viertelstunden für den Brief werden, und was der
Dienst über den Brief nach außen sagt.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, tzinfo

from dch_api.schemas import MorgenbriefOut, PlanOut
from hems_core.planning.morgenbrief import TITEL, Brief, Viertel, morgenbrief

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
            ofen=iv.planned_stove_on,
            waerme_kw=(
                None
                if iv.heat_demand_kw is None and iv.dhw_demand_kw is None
                else (iv.heat_demand_kw or 0.0) + (iv.dhw_demand_kw or 0.0)
            ),
            strom_eur=iv.planned_hp_cost_eur,
            pellet_eur=iv.planned_pellet_cost_eur,
        )
        for iv in plan.intervals
    ]
    hat_fahrplan = any(iv.reason_code == "planned_optimizer" for iv in plan.intervals)
    return morgenbrief(viertel, jetzt=jetzt, tz=tz, hat_fahrplan=hat_fahrplan)


def faellig(jetzt: datetime, tz: tzinfo, zuletzt_am: object) -> bool:
    """Ist jetzt die Zeit für den Brief, und ist er heute noch nicht verschickt?"""
    lokal = jetzt.astimezone(tz)
    return BRIEF_STUNDE <= lokal.hour < BRIEF_BIS_STUNDE and zuletzt_am != lokal.date()


def morgen_frueh(jetzt: datetime, tz: tzinfo) -> datetime:
    """Der nächste Morgen um sieben, Ortszeit."""
    lokal = jetzt.astimezone(tz)
    return lokal.replace(hour=BRIEF_STUNDE, minute=0, second=0, microsecond=0) + timedelta(days=1)


def zuletzt_satz(am: date | None, erreicht: int | None, geraete: int | None) -> str:
    """Wann der Brief zuletzt ging und bei wie vielen Geräten er ankam, als Satz.

    Ohne diesen Satz ist ein Brief, der nicht kommt, nicht von einem zu unterscheiden, der nie
    verschickt wurde (Nutzer am 12.11.2026: „Ich bekomme gar keine Push-Nachrichten. Da war
    doch ein Morning Briefing geplant."). Die Zahlen fehlen bei Briefen aus der Zeit davor.
    """
    if am is None:
        return "Bisher ist kein Morning Briefing verschickt worden."
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
    """Das aktuelle Briefing: das von heute, wie es jetzt verschickt würde.

    **Seit dem 13.11.2026 ist das eine Regel für alles**, die Vorschau auf der Seite und beide
    Probeknöpfe (Nutzerwunsch: die Probe soll „nicht einfach nur eine Testmitteilung" sein,
    „sondern die aktuelle Meldung, die an diesem Tag rausgeschickt worden wäre, beziehungsweise
    das aktuelle Morning Briefing"). Vorher zeigte die Seite nach neun Uhr das Briefing von
    morgen früh, und die Probe unter „Mitteilungen" schickte einen festen Satz.

    Das Briefing gilt für den Rest des heutigen Tages. Spät am Abend ist davon zu wenig übrig
    (unter zwei Stunden); dann steht hier das von morgen früh, und `fuer_de` sagt es.
    """
    brief = aus_plan(plan, jetzt, tz)
    morgen = brief is None
    if brief is None:
        brief = aus_plan(plan, morgen_frueh(jetzt, tz), tz)
    return MorgenbriefOut(
        enabled=an,
        uhrzeit=f"{BRIEF_STUNDE:02d}:00",
        fuer_de="morgen" if morgen else "heute",
        titel=brief.titel if brief else TITEL,
        zeilen=list(brief.zeilen) if brief else [],
        hinweis_de=""
        if brief
        else "Gerade gibt es kein Briefing: der Fahrplan reicht dafür nicht. Die Preise für "
        "morgen kommen am frühen Nachmittag.",
        zuletzt_de=zuletzt_de,
    )
