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

**Das System gehört dem Hausherrn.** Seine Karte der Haustür zählt, wer kam, und das Protokoll
der Haustür ist eine Akte (`auth/rechte.py`). Die ganze Übersicht des Systems steht deshalb
dort in der Liste der Akten. Ihre Quellen sind die Antworten der Seiten des Systems; die
reicht der Router herein, weil sie am Gerät, am Push-Dienst und an der Datenbank hängen und
nicht an der Laufzeit.
"""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable
from datetime import date
from time import monotonic

from dch_api.application.kennlinie import de
from dch_api.application.runtime import Runtime
from dch_api.schemas import (
    Ampel,
    AnlageOut,
    CoverageOut,
    DoorLogOut,
    EnergySummaryOut,
    EnergyTotalsOut,
    ForecastEvaluationOut,
    GeraetOut,
    HeatReportOut,
    KontaktwirkungOut,
    LiveStateOut,
    PlanOut,
    PushGeraeteOut,
    RegelkreisOut,
    ReglerEinstellungenOut,
    StorageReportOut,
    UebersichtBildOut,
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
BEREICHE = ("anlage", "energie", "system")

#: Über wie viele Tage die Karte der Haustür zählt: der kürzeste Zeitraum, den ihr Protokoll
#: kennt. Die Karte soll sagen, was seit gestern war.
HAUSTUER_TAGE = 1

#: Über wie viele Tage die Karte der Datenprüfung die Abdeckung nennt.
ABDECKUNG_TAGE = 7


def _ohne(weg: str, grund: str = KEINE_AUSKUNFT) -> UebersichtKarteOut:
    return UebersichtKarteOut(weg=weg, ampel="aus", grund_de=grund)


def _fuellung(anteil: float) -> UebersichtBildOut:
    """Ein Füllstand, auf 0 bis 1 beschnitten: ein Messwert knapp darüber soll nichts zeichnen,
    was über den Rand ragt."""
    return UebersichtBildOut(art="fuellung", anteil=min(1.0, max(0.0, anteil)))


def _balken(
    bilanz: EnergySummaryOut, wert: Callable[[EnergyTotalsOut], float]
) -> UebersichtBildOut:
    """Der Verlauf des Tages in Stunden: je Stunde der Bilanz ein Wert in kWh, nie negativ."""
    return UebersichtBildOut(
        art="balken", werte=[round(max(0.0, wert(b.totals)), 3) for b in bilanz.buckets]
    )


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
        bild=_fuellung(a.speicher.soc),
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
        grund_de=plan.planner_warn_de or "",
        # Der Horizont als Streifen: je Viertelstunde, ob die Wärmepumpe angefordert ist.
        bild=UebersichtBildOut(
            art="streifen",
            werte=[1.0 if i.planned_hp_state == "release" else 0.0 for i in plan.intervals],
        ),
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
        bild=None if k.quote is None else _fuellung(k.quote),
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


def _kwh(
    weg: str, bilanz: EnergySummaryOut, wert: Callable[[EnergyTotalsOut], float], dazu: str
) -> UebersichtKarteOut:
    """Eine Karte mit einer Energiemenge des heutigen Tages aus der Tagesbilanz, mit ihrem
    Verlauf über die Stunden als Bild."""
    if bilanz.totals.minutes == 0:
        return _ohne(weg, HEUTE_LEER)
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=f"{de(wert(bilanz.totals), 1)} kWh",
        dazu_de=dazu,
        ampel="gut",
        bild=_balken(bilanz, wert),
    )


def karte_strom(bilanz: EnergySummaryOut) -> UebersichtKarteOut:
    """Der Strom: was das Haus heute verbraucht hat, Wärmepumpe und Wallbox eingeschlossen."""
    return _kwh("/strom", bilanz, lambda t: t.house_kwh, "Verbrauch heute")


def karte_photovoltaik(bilanz: EnergySummaryOut) -> UebersichtKarteOut:
    """Die Photovoltaik: was die Anlage heute erzeugt hat."""
    return _kwh("/strom/pv", bilanz, lambda t: t.pv_kwh, "Ertrag heute")


def karte_wallbox(bilanz: EnergySummaryOut) -> UebersichtKarteOut:
    """Die Wallbox: was heute ins Auto geladen wurde."""
    return _kwh("/strom/wallbox", bilanz, lambda t: t.ev_kwh, "heute geladen")


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
        # Der Strom der Wärmepumpe je Stunde: Er zeigt, wann sie gelaufen ist. Die Wärme selbst
        # gibt es nur als Schätzung für den ganzen Tag.
        bild=_balken(bericht.summary, lambda t: t.heat_pump_kwh),
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
        bild=UebersichtBildOut(art="abweichung", anteil=min(1.0, max(-1.0, fehler / 100))),
    )


def karte_speicher(zustand: LiveStateOut) -> UebersichtKarteOut:
    """Der Speicher: sein Ladestand im Augenblick."""
    weg = "/strom/speicher"
    stand = zustand.snapshot.battery_soc
    if stand.value is None or not stand.quality.usable:
        return _ohne(weg, "Vom Speicher liegt kein Ladestand vor.")
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=f"{de(stand.value * 100, 0)} %",
        dazu_de="Ladestand",
        ampel="gut",
        bild=_fuellung(stand.value),
    )


def karte_mitteilungen(g: PushGeraeteOut) -> UebersichtKarteOut:
    """Die Mitteilungen: wie viele Geräte angemeldet sind. Gelb, wenn bei einem die Zustellung
    seit der letzten angenommenen Mitteilung gescheitert ist; das zählt der Dienst je Gerät."""
    weg = "/system/mitteilungen"
    n = len(g.devices)
    if n == 0:
        return _ohne(weg, "Kein Gerät ist für Mitteilungen angemeldet.")
    gescheitert = sum(1 for d in g.devices if d.fehlversuche > 0)
    if gescheitert == 0:
        grund = ""
    elif gescheitert == 1:
        grund = "Bei einem Gerät ist die Zustellung zuletzt gescheitert."
    else:
        grund = f"Bei {gescheitert} Geräten ist die Zustellung zuletzt gescheitert."
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=str(n),
        dazu_de="Gerät angemeldet" if n == 1 else "Geräte angemeldet",
        ampel="warn" if grund else "gut",
        grund_de=grund,
    )


def karte_haustuer(protokoll: DoorLogOut) -> UebersichtKarteOut:
    """Die Haustür: wie viele Zutritte das Protokoll im Zeitraum kennt. Gelb, wenn ein Versuch
    abgelehnt wurde: das ist die Frage, wegen der man in das Protokoll sieht."""
    weg = "/system/haustuer"
    gewaehrt = sum(1 for e in protokoll.entries if e.granted)
    abgelehnt = len(protokoll.entries) - gewaehrt
    if abgelehnt == 0:
        grund = ""
    elif abgelehnt == 1:
        grund = "Ein Versuch an der Tür wurde abgelehnt."
    else:
        grund = f"{abgelehnt} Versuche an der Tür wurden abgelehnt."
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=str(gewaehrt),
        dazu_de="Zutritt seit gestern" if gewaehrt == 1 else "Zutritte seit gestern",
        ampel="warn" if grund else "gut",
        grund_de=grund,
    )


def karte_geraet(g: GeraetOut) -> UebersichtKarteOut:
    """Das Hausgerät: die Ampel und der Satz, die seine Seite oben zeigt. Eine Zahl hat es nicht."""
    weg = "/system/geraet"
    if g.ampel == "gut":
        return UebersichtKarteOut(weg=weg, ampel="gut")
    return UebersichtKarteOut(weg=weg, ampel=g.ampel, grund_de=g.text_de or KEINE_AUSKUNFT)


def karte_zugang(platz: StorageReportOut) -> UebersichtKarteOut:
    """Zugang und Sicherung: wie groß die Datenbank ist. Das ist, was zu sichern wäre."""
    weg = "/system/zugang"
    if not platz.tables:
        return _ohne(weg, platz.note_de or KEINE_AUSKUNFT)
    gb = platz.total_bytes / 1e9
    groesse = f"{de(gb, 1)} GB" if gb >= 1 else f"{de(platz.total_bytes / 1e6, 0)} MB"
    return UebersichtKarteOut(
        weg=weg, leitzahl_de=groesse, dazu_de="Größe der Datenbank", ampel="gut"
    )


def karte_daten(abdeckung: CoverageOut) -> UebersichtKarteOut:
    """Daten prüfen: die Abdeckung der schlechteren der Netzreihen. Ein Urteil fällt die Karte
    nicht, weil die Seite keines fällt; sie nennt die Zahl.

    Ist in keiner Reihe eine einzige Minute gezählt, gibt es keinen Bestand, an dem sich zählen
    ließe (ohne Datenbank ist das so). Dann steht keine Null da, sondern dieser Satz.
    """
    weg = "/system/daten"
    gezaehlt = [s for s in abdeckung.series if s.minutes_expected > 0]
    if not gezaehlt or all(s.minutes_seen == 0 for s in gezaehlt):
        return _ohne(weg, "Für die Messreihen gibt es gerade keine Zählung.")
    schlechteste = min(s.coverage for s in gezaehlt)
    return UebersichtKarteOut(
        weg=weg,
        leitzahl_de=f"{de(schlechteste * 100, 1)} %",
        dazu_de=f"Abdeckung in {ABDECKUNG_TAGE} Tagen",
        ampel="gut",
        bild=_fuellung(schlechteste),
    )


#: So lange wartet die Übersicht auf die Quelle einer Karte. Danach steht die letzte bekannte
#: Karte da, und die Quelle rechnet im Hintergrund zu Ende.
FRIST_S = 4.0

#: Wie lange eine gemerkte Karte noch gezeigt wird. Älter als das ist keine Auskunft mehr.
MERK_S = 15 * 60.0

BRAUCHT_LAENGER = "Die Auskunft braucht gerade länger."

#: Die letzte gelungene Karte je Seite, mit der Zeit, zu der sie gebaut wurde.
_GEMERKT: dict[str, tuple[float, UebersichtKarteOut]] = {}
#: Quellen, die über die Frist hinaus rechnen. Gehalten, damit sie nicht eingesammelt werden,
#: und damit eine langsame Quelle nicht bei jedem Aufruf ein zweites Mal startet.
_LAUFEND: dict[str, asyncio.Task[None]] = {}


def _merken(weg: str, karte: UebersichtKarteOut) -> None:
    _GEMERKT[weg] = (monotonic(), karte)


def _gemerkt(weg: str) -> UebersichtKarteOut | None:
    eintrag = _GEMERKT.get(weg)
    if eintrag is None or monotonic() - eintrag[0] > MERK_S:
        return None
    return eintrag[1]


async def _karte[T](
    weg: str, quelle: Callable[[], Awaitable[T]], bauen: Callable[[T], UebersichtKarteOut]
) -> UebersichtKarteOut:
    """Eine Karte aus ihrer Quelle, mit einer Frist.

    Wirft die Quelle, bleibt die Karte stehen und sagt es. **Braucht die Quelle länger als
    `FRIST_S`, wartet die Übersicht nicht auf sie:** Sie zeigt die Karte vom letzten Mal, und
    die Quelle rechnet im Hintergrund zu Ende und legt ihr Ergebnis für den nächsten Aufruf ab.
    Vorher hielt die langsamste Quelle die ganze Übersicht auf. Am echten Dienst blieben die
    Karten der Anlage so ohne Zahl, weil Wirkung und Regelkreis über Tage von Messwerten
    rechnen und die Oberfläche das Warten aufgab (gemeldet vom Hausherrn am 24.11.2026).
    """

    async def rechnen() -> None:
        try:
            _merken(weg, bauen(await quelle()))
        except Exception:
            # Eine Quelle, die wirft, löscht nichts: die gemerkte Karte verfällt von selbst.
            pass
        finally:
            if _LAUFEND.get(weg) is asyncio.current_task():
                _LAUFEND.pop(weg, None)

    davor = _GEMERKT.get(weg)
    lauf = _LAUFEND.get(weg)
    # Ein Lauf aus einer anderen Ereignisschleife (ein beendeter Dienst im selben Vorgang, wie
    # in den Tests) lässt sich nicht abwarten und wird nie fertig. Er zählt nicht.
    if lauf is None or lauf.get_loop() is not asyncio.get_running_loop():
        lauf = asyncio.ensure_future(rechnen())
        _LAUFEND[weg] = lauf
    await asyncio.wait({lauf}, timeout=FRIST_S)
    if lauf.done():
        danach = _GEMERKT.get(weg)
        # Hat dieser Lauf etwas Neues abgelegt, ist das die Karte. Sonst hat die Quelle geworfen.
        if danach is not None and danach is not davor:
            return danach[1]
        return _ohne(weg)
    return _gemerkt(weg) or _ohne(weg, BRAUCHT_LAENGER)


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


async def system(
    mitteilungen: Callable[[], Awaitable[PushGeraeteOut]],
    haustuer: Callable[[], Awaitable[DoorLogOut]],
    geraet: Callable[[], Awaitable[GeraetOut]],
    platz: Callable[[], Awaitable[StorageReportOut]],
    abdeckung: Callable[[], Awaitable[CoverageOut]],
) -> UebersichtOut:
    """Die Karten des Bereichs System, in der Reihenfolge des Seitenbaums.

    Die Quellen sind die Antworten der fünf Seiten. Der Router reicht sie als Aufrufe herein,
    damit jede einzeln ausfallen darf und diese Datei nichts vom Router wissen muss.
    """
    karten = await asyncio.gather(
        _karte("/system/mitteilungen", mitteilungen, karte_mitteilungen),
        _karte("/system/haustuer", haustuer, karte_haustuer),
        _karte("/system/geraet", geraet, karte_geraet),
        _karte("/system/zugang", platz, karte_zugang),
        _karte("/system/daten", abdeckung, karte_daten),
    )
    return UebersichtOut(bereich="system", karten=list(karten))
