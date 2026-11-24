"""Die Karten der Bereichsübersicht: je Seite die wichtigste Zahl und ein Zustand.

Die Übersicht eines Bereichs zeigt je Seite eine Karte. Damit man sieht, welche Seite gerade
etwas zu sagen hat, ohne sie zu öffnen, trägt jede Karte eine Leitzahl und eine Ampel.

**Hier wird zusammengetragen, nicht neu gerechnet.** Jede Seite hat schon ihre Antwort mit einem
Zustand oder einem Urteil des Dienstes (`zustand_de`, `urteil`, `planner_warn_de`, die Reserven
des Regelkreises). Diese Datei liest daraus je Seite eine Zahl und eine Ampel. Eine eigene
Schwelle legt sie nirgends fest: wo die Seite selbst kein Urteil hat, bleibt die Ampel `gut`
(es gibt nichts zu tun) oder `aus` (es gibt gerade keine Auskunft).

**Der Dienst formuliert**, weil Dashboard und App dasselbe zeigen müssen (CLAUDE.md, „Dashboard
und App sind dasselbe“). Eine Zahl, die jede Oberfläche selbst zusammensetzte, liefe auseinander.

**Eine Quelle, die ausfällt, nimmt nur ihre Karte mit.** Die Karten werden einzeln gebaut; wirft
eine Rechnung, steht dort „Gerade keine Auskunft.“, und die anderen bleiben.

**Die Energie zeigt den heutigen Tag.** Ihre Seiten sind Berichte über einen Zeitraum; die
Übersicht hat keinen Zeitraumwähler und nimmt deshalb den Tag, der läuft. Strom, Photovoltaik
und Wallbox lesen aus derselben Tagesbilanz, die auch ihre Seiten zeigen, und die wird für alle
drei nur einmal gerechnet.
"""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from datetime import date

from dch_api.application.kennlinie import de
from dch_api.application.runtime import Runtime
from dch_api.schemas import (
    Ampel,
    AnlageOut,
    EnergySummaryOut,
    ForecastEvaluationOut,
    HeatReportOut,
    KontaktwirkungOut,
    LiveStateOut,
    PlanOut,
    RegelkreisOut,
    ReglerEinstellungenOut,
    UebersichtKarteOut,
    UebersichtOut,
    WaermepumpeOut,
)
from hems_core.simulation import BERLIN

#: Über wie viele Tage die Karte der Wirkung urteilt. Der kürzeste Zeitraum, den die Seite
#: anbietet: die Karte soll sagen, wie es zuletzt war.
WIRKUNG_TAGE = 7

#: Was auf einer Karte steht, deren Quelle gerade nicht antwortet.
KEINE_AUSKUNFT = "Gerade keine Auskunft."

#: Was auf der Karte der Wirkung steht, solange die Ereignisstudie kein Urteil fällt.
WIRKUNG_OFFEN = "Für ein Urteil gibt es noch zu wenige Ereignisse."

#: Was auf einer Karte der Energie steht, solange der Tag noch keine bewertete Minute hat.
HEUTE_LEER = "Für heute liegen noch keine Messwerte vor."

#: Die Bereiche, für die es Karten gibt, mit ihrem Schlüssel aus `docs/seitenbaum.json`.
BEREICHE = ("anlage", "energie")


def _ohne(weg: str, grund: str = KEINE_AUSKUNFT) -> UebersichtKarteOut:
    return UebersichtKarteOut(weg=weg, ampel="aus", grund_de=grund)


def karte_anlage(a: AnlageOut) -> UebersichtKarteOut:
    """Die Anlage: der Ladestand des Puffers. Er ist die eine Zahl, an der die Wasserseite hängt."""
    weg = "/waerme/anlage"
    if a.speicher.soc is None:
        return _ohne(weg, "Vom Puffer liegt kein Messwert vor.")
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=f"{de(a.speicher.soc * 100, 0)} %",
        dazu_de="Ladestand des Puffers",
        ampel="gut",
    )


def karte_waermepumpe(w: WaermepumpeOut) -> UebersichtKarteOut:
    """Die Wärmepumpe: ihre Leistung am Zähler und das Wort des Dienstes für ihren Zustand."""
    weg = "/waerme/waermepumpe"
    leistung = w.leistung_zaehler_kw
    if leistung.value is None or not leistung.quality.usable:
        return UebersichtKarteOut(
            weg=weg,
            dazu_de=w.zustand_de,
            ampel="aus",
            grund_de="Die Leistung der Wärmepumpe ist gerade nicht gemessen.",
        )
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=f"{de(leistung.value, 1)} kW",
        dazu_de=w.zustand_de,
        ampel="gut",
    )


def karte_fahrplan(plan: PlanOut | None) -> UebersichtKarteOut:
    """Der Fahrplan: wie viele Stunden die Wärmepumpe im Horizont angefordert ist.

    Dieselbe Zahl führt die Seite selbst an. Die Ampel folgt der Warnung des Planers: sie steht
    genau dann, wenn der Plan unter Zeitdruck oder mit einer Einschränkung gerechnet ist.
    """
    weg = "/waerme/fahrplan"
    if plan is None:
        return _ohne(weg, "Es ist noch kein Fahrplan gerechnet.")
    viertel = sum(1 for i in plan.intervals if i.planned_hp_state == "release")
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=f"{de(viertel / 4, 1)} h",
        dazu_de="Wärmepumpe angefordert im Horizont",
        ampel="warn" if plan.planner_warn_de else "gut",
        grund_de=plan.planner_warn_de,
    )


#: Was das Urteil der Ereignisstudie für die Ampel heißt. `offen` ist kein schlechtes Urteil,
#: sondern keines: zu wenige Ereignisse.
_WIRKUNG_AMPEL: dict[str, Ampel] = {
    "wirkt": "gut",
    "kein_unterschied": "warn",
    "seltener": "warn",
    "offen": "aus",
}


def karte_wirkung(k: KontaktwirkungOut) -> UebersichtKarteOut:
    """Die Wirkung: in welchem Anteil der Fälle die Maschine nach einer Anforderung anläuft."""
    weg = "/waerme/wirkung"
    ampel: Ampel = _WIRKUNG_AMPEL.get(k.urteil, "aus")
    if ampel == "gut":
        grund = ""
    elif k.urteil == "offen":
        # Der Satz der Seite erklärt hier über vier Zeilen, was fehlt. Auf der Karte genügt, dass
        # es noch kein Urteil gibt; das Warum steht auf der Seite.
        grund = WIRKUNG_OFFEN
    else:
        grund = k.urteil_de or KEINE_AUSKUNFT
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=None if k.quote is None else f"{de(k.quote * 100, 0)} %",
        dazu_de="Anlauf nach einer Anforderung",
        ampel=ampel,
        grund_de=grund,
    )


def karte_regelkreis(r: RegelkreisOut) -> UebersichtKarteOut:
    """Der Regelkreis: wie viele Parameter von Hand übersteuert sind, und ob die Reserven reichen.

    Beides zeigt die Seite in ihrem Kopf als Leuchte. Eine zu kleine Reserve wiegt schwerer als
    eine Übersteuerung und steht darum zuerst im Grund.
    """
    weg = "/waerme/regelkreis"
    knapp = [k.name for k in r.kreise if k.reserven is not None and not k.reserven.gut]
    n = len(r.uebersteuert)
    if knapp:
        grund = f"Die Reserve im Kreis {knapp[0]} ist zu klein."
    elif n == 1:
        grund = "Ein Parameter ist von Hand übersteuert."
    elif n > 1:
        grund = f"{n} Parameter sind von Hand übersteuert."
    else:
        grund = ""
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=str(n),
        dazu_de="Parameter übersteuert",
        ampel="warn" if grund else "gut",
        grund_de=grund,
    )


def karte_regler(e: ReglerEinstellungenOut) -> UebersichtKarteOut:
    """Der Regler: wie viele seiner Einstellungen über den Bus gelesen sind."""
    weg = "/waerme/waermepumpe/regler"
    if e.gelesen == 0:
        return _ohne(weg, e.hindernis_de or e.satz_de or KEINE_AUSKUNFT)
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=str(e.gelesen),
        dazu_de="Einstellungen gelesen",
        ampel="gut",
    )


def _kwh(weg: str, bilanz: EnergySummaryOut, kwh: float, dazu: str) -> UebersichtKarteOut:
    """Eine Karte mit einer Energiemenge des heutigen Tages aus der Tagesbilanz."""
    if bilanz.totals.minutes == 0:
        return _ohne(weg, HEUTE_LEER)
    return UebersichtKarteOut(weg=weg, leitzahl_de=f"{de(kwh, 1)} kWh", dazu_de=dazu, ampel="gut")


def karte_strom(bilanz: EnergySummaryOut) -> UebersichtKarteOut:
    """Der Strom: was das Haus heute verbraucht hat, Wärmepumpe und Wallbox eingeschlossen."""
    return _kwh("/strom", bilanz, bilanz.totals.house_kwh, "Verbrauch heute")


def karte_photovoltaik(bilanz: EnergySummaryOut) -> UebersichtKarteOut:
    """Die Photovoltaik: was die Anlage heute erzeugt hat."""
    return _kwh("/strom/pv", bilanz, bilanz.totals.pv_kwh, "Ertrag heute")


def karte_wallbox(bilanz: EnergySummaryOut) -> UebersichtKarteOut:
    """Die Wallbox: was heute ins Auto geladen wurde."""
    return _kwh("/strom/wallbox", bilanz, bilanz.totals.ev_kwh, "heute geladen")


def karte_waerme(bericht: HeatReportOut) -> UebersichtKarteOut:
    """Die Wärme: was die Wärmepumpe heute geliefert hat. Geschätzt aus Strom und Arbeitszahl,
    wie auf ihrer Seite, und deshalb auch hier so genannt."""
    weg = "/waerme"
    if bericht.summary.totals.minutes == 0:
        return _ohne(weg, HEUTE_LEER)
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=f"{de(bericht.thermal_kwh_est, 1)} kWh",
        dazu_de="Wärme heute, geschätzt",
        ampel="gut",
    )


def karte_prognose(auswertung: ForecastEvaluationOut) -> UebersichtKarteOut:
    """Die Prognose: um wie viel sie gestern neben dem Ertrag lag. Das Vorzeichen steht dabei,
    weil es die Richtung sagt: Plus heißt, die Prognose war zu hoch."""
    weg = "/system"
    wertung = auswertung.yesterday.score
    if wertung is None or wertung.energy_error_pct is None:
        return _ohne(weg, "Für gestern gibt es noch keinen Vergleich mit dem Ertrag.")
    fehler = wertung.energy_error_pct
    vorzeichen = "+" if fehler > 0 else "−" if fehler < 0 else ""
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=f"{vorzeichen}{de(abs(fehler), 0)} %",
        dazu_de="Abweichung gestern",
        ampel="gut",
    )


def karte_speicher(zustand: LiveStateOut) -> UebersichtKarteOut:
    """Der Speicher: sein Ladestand im Augenblick."""
    weg = "/strom/speicher"
    stand = zustand.snapshot.battery_soc
    if stand.value is None or not stand.quality.usable:
        return _ohne(weg, "Vom Speicher liegt kein Ladestand vor.")
    return UebersichtKarteOut(
        weg=weg, leitzahl_de=f"{de(stand.value * 100, 0)} %", dazu_de="Ladestand", ampel="gut"
    )


async def _karte[T](
    weg: str, quelle: Callable[[], Awaitable[T]], bauen: Callable[[T], UebersichtKarteOut]
) -> UebersichtKarteOut:
    """Eine Karte aus ihrer Quelle. Wirft die Quelle, bleibt die Karte stehen und sagt es."""
    try:
        return bauen(await quelle())
    except Exception:
        return _ohne(weg)


async def anlage(runner: Runtime) -> UebersichtOut:
    """Die Karten des Bereichs Anlage, in der Reihenfolge des Seitenbaums.

    Die Annahmen haben keine Karte: dort steht nichts, was sich von selbst ändert.
    """

    async def plan() -> PlanOut | None:
        return runner.plan

    karten = await asyncio.gather(
        _karte("/waerme/anlage", runner.anlage, karte_anlage),
        _karte("/waerme/waermepumpe", runner.waermepumpe, karte_waermepumpe),
        _karte("/waerme/fahrplan", plan, karte_fahrplan),
        _karte("/waerme/wirkung", lambda: runner.kontaktwirkung(WIRKUNG_TAGE), karte_wirkung),
        _karte("/waerme/regelkreis", runner.regelkreis, karte_regelkreis),
        _karte("/waerme/waermepumpe/regler", runner.regler_einstellungen, karte_regler),
    )
    return UebersichtOut(bereich="anlage", karten=list(karten))


def _heute(runner: Runtime) -> date:
    """Der Tag, der im Haus läuft. Dieselbe Rechnung wie in den Berichten (`routers/energy.py`)."""
    return runner.now.astimezone(BERLIN).date()


async def energie(runner: Runtime) -> UebersichtOut:
    """Die Karten des Bereichs Energie, in der Reihenfolge des Seitenbaums.

    Die Jahreskarte hat keine Karte: sie ist ein Bild über ein Jahr und hat keine Zahl des Tages.
    """
    heute = _heute(runner)
    bilanz: asyncio.Task[EnergySummaryOut] = asyncio.ensure_future(
        runner.energy_summary("day", heute)
    )

    async def tagesbilanz() -> EnergySummaryOut:
        return await asyncio.shield(bilanz)

    async def augenblick() -> LiveStateOut:
        return runner.live_state()

    karten = await asyncio.gather(
        _karte("/strom", tagesbilanz, karte_strom),
        _karte("/waerme", lambda: runner.heat_report("day", heute), karte_waerme),
        _karte("/strom/pv", tagesbilanz, karte_photovoltaik),
        _karte("/system", runner.forecast_evaluation, karte_prognose),
        _karte("/strom/speicher", augenblick, karte_speicher),
        _karte("/strom/wallbox", tagesbilanz, karte_wallbox),
    )
    return UebersichtOut(bereich="energie", karten=list(karten))


async def bereich(schluessel: str, runner: Runtime) -> UebersichtOut | None:
    """Die Karten eines Bereichs, oder `None`, wenn es für ihn keine Übersicht gibt."""
    if schluessel == "anlage":
        return await anlage(runner)
    if schluessel == "energie":
        return await energie(runner)
    return None
