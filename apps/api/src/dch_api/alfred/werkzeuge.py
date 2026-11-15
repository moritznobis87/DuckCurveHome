"""
Alfreds Werkzeuge (docs/ALFRED.md).

Das Sprachmodell ruft benannte Funktionen auf und erklaert deren Ergebnis; es rechnet nicht selbst.
Jedes Werkzeug liest ueber das `Runtime`-Protokoll - dieselben Funktionen, die auch die Seiten
fuellen -, und jede Zahl einer Antwort ist damit dieselbe wie auf dem Bildschirm.

Dieses Modul ist die einzige Stelle, an der Daten des Hauses zum Modell gelangen, und `ausfuehren`
die einzige Funktion, die sie hinauslaesst. Wer wissen will, was der Anbieter erfaehrt, liest hier.

**Was nie hinausgeht.** Alarmanlage, Tuer- und Fensterkontakte, Haustuer und Zutritte: Sie sagen,
ob jemand zu Hause ist und ob das Haus offen steht. Es gibt dafuer kein Werkzeug, und `kompakt`
streicht die Felder zusaetzlich, falls sie in einem anderen Ergebnis mitreisen. Ebenso wenig der
Standort des Hauses: Koordinaten stehen in keinem Ergebnis.

**Kein Werkzeug schreibt.** `schalten_vorschlagen` und `sollwert_vorschlagen` haengen einen
Vorschlag an die Antwort; geschaltet wird erst, wenn der Anwender den Knopf drueckt, und zwar ueber
die gewoehnlichen Endpunkte der Oberflaeche mit ihren eigenen Pruefungen.
"""

from __future__ import annotations

import math
import re
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any, cast

import structlog
from pydantic import BaseModel

from dch_api.alfred.leitfaeden import LEITFAEDEN, leitfaden
from dch_api.alfred.papiere import nachschlagen
from dch_api.application.runtime import Runtime
from hems_core.simulation import BERLIN

log = structlog.get_logger("alfred")

#: Schaltbare Verbraucher, die Alfred vorschlagen darf, mit Anzeigename. Eine Liste und keine
#: Regel: "alles ausser den gefaehrlichen" waere beim naechsten neuen Aktor stillschweigend zu
#: grosszuegig. Die Waermepumpenanforderung (K1) steht bewusst nicht darin. Gegenprobe gegen die
#: Aktoren der Steuerung in tests/test_alfred.py.
SCHALTBAR: dict[str, str] = {
    "terrace_light": "Licht Terrasse",
    "courtyard_light": "Licht Innenhof",
    "garden_fence_light": "Licht Gartenzaun",
    "coffee_machine": "Kaffeemaschine",
}

#: Das Band, in dem Alfred Raumsollwerte vorschlagen darf, und der groesste Schritt. Enger als der
#: Endpunkt (5 bis 30 Grad), weil dort ein Mensch dreht, der weiss, was er will. Ein Vorschlag aus
#: einem Satz, den ein Sprachmodell verstanden zu haben glaubt, bleibt im Wohnbereich und in
#: kleinen Schritten - auch dann noch, wenn jemand den Bestaetigungsknopf zu schnell drueckt.
SOLL_ALFRED_MIN = 16.0
SOLL_ALFRED_MAX = 24.0
SOLL_ALFRED_SCHRITT_K = 3.0

#: Felder, die nie an das Modell gehen, gleich in welchem Ergebnis sie stehen (siehe oben).
GESPERRT = frozenset(
    {
        "alarm",
        "contacts",
        "door",
        "doors",
        "window",
        "lock",
        "latitude",
        "longitude",
        "lat",
        "lon",
        "file_name",
        "file_sha256",
        "urheber",
        # Interne Kennungen (Entscheidungen, Laeufe): Sie erklaeren nichts und kosten Token.
        "id",
        "run_id",
    }
)

#: Hoechstzahl der Eintraege einer Liste im Ergebnis. Zeitreihen werden gleichmaessig ausgeduennt:
#: Fuer "wann war es teuer" genuegen 24 Punkte eines Tages, 1440 Minuten kosten nur Token.
LISTE_MAX = 24

#: Hoechstlaenge eines Ergebnisses in Zeichen. Wird sie ueberschritten, werden die Listen weiter
#: ausgeduennt, bis es passt.
ERGEBNIS_MAX = 9000


class WerkzeugError(Exception):
    """Das Werkzeug konnte nicht ausgefuehrt werden. Die Meldung geht an das Modell und darf nichts
    Internes enthalten."""


#: Was Alfred vom Dienst sehen darf: Lesefunktionen, sonst nichts. Eine Liste und keine Regel
#: ("alles ausser set_*"): `switch_actuator`, `arm_alarm`, `import_history` heissen nicht set_, und
#: die naechste schreibende Funktion hiesse vielleicht auch anders. Eine neue Lesefunktion, die
#: hier fehlt, faellt im Test sofort auf; eine schreibende, die hier fehlt, faellt nie auf - und
#: genau so soll es sein.
LESEN = frozenset(
    {
        "now",
        "plan",
        "live_state",
        "energy_summary",
        "heat_report",
        "heat_balance",
        "shift_report",
        "ev_report",
        "pv_report",
        "nachbetrachtung",
        "waermepumpe",
        "kontaktwirkung",
        "rooms_live",
        "recent_decisions",
        "forecast_evaluation",
        "diagnose_day",
        "invoices",
        "invoice",
    }
)


class SchreibsperreError(PermissionError):
    """Ein Werkzeug hat versucht, an eine Funktion ausserhalb von `LESEN` zu kommen."""


class NurLesen:
    """Der Dienst, wie Alfred ihn sieht: nur die Funktionen aus `LESEN`.

    **Das ist die eigentliche Sicherheitsschicht.** Kein Werkzeug schreibt, und das steht in
    jedem Docstring - aber ein Docstring haelt niemanden auf. Dieser Filter tut es: Selbst ein
    fehlerhaftes oder spaeter hinzugefuegtes Werkzeug, selbst ein Modell, das ein Werkzeug mit
    boesen Argumenten ruft, erreicht kein `switch_actuator`, kein `set_room_setpoint`, kein
    `arm_alarm`. Geschaltet wird ausschliesslich ueber die Endpunkte der Oberflaeche, und dorthin
    fuehrt aus Alfred kein Weg ausser dem Knopf, den ein Mensch drueckt.
    """

    __slots__ = ("_dienst",)

    def __init__(self, dienst: Runtime) -> None:
        object.__setattr__(self, "_dienst", dienst)

    def __getattr__(self, name: str) -> Any:
        if name not in LESEN:
            raise SchreibsperreError(f"Alfred darf {name!r} nicht benutzen.")
        return getattr(object.__getattribute__(self, "_dienst"), name)

    def __setattr__(self, name: str, wert: Any) -> None:
        raise SchreibsperreError("Alfred darf am Dienst nichts setzen.")


@dataclass
class Kontext:
    """Was ein Werkzeug braucht: den Zugang zu den Daten und die Vorschlagsliste dieser Frage.

    `runner` ist immer der gefilterte Dienst (`NurLesen`), auch wenn der Aufrufer den echten
    uebergibt: Die Huelle entsteht hier und nicht beim Aufrufer, damit niemand sie vergessen kann.
    """

    runner: Runtime
    vorschlaege: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        if not isinstance(self.runner, NurLesen):
            self.runner = cast(Runtime, NurLesen(self.runner))


@dataclass(frozen=True)
class Werkzeug:
    name: str
    beschreibung: str
    #: JSON-Schema der Parameter. Leere `properties` heisst Aufruf ohne Argumente.
    schema: dict[str, Any]
    ausfuehrung: Callable[..., Awaitable[dict[str, Any]]]


# ---------------------------------------------------------------------------
# Hilfen
# ---------------------------------------------------------------------------


def _zahl(wert: float) -> float | None:
    """Gerundet und JSON-tauglich. NaN und Unendlich kennt JSON nicht."""
    if not math.isfinite(wert):
        return None
    return round(wert, 3)


def _duennen(liste: list[Any], hoechstens: int) -> list[Any]:
    if len(liste) <= hoechstens:
        return liste
    schritt = len(liste) / hoechstens
    return [liste[int(i * schritt)] for i in range(hoechstens)]


def _kompakt_wert(wert: Any, hoechstens: int) -> Any:
    if isinstance(wert, BaseModel):
        # Auch verschachtelt: Ein Modell in einem Woerterbuch kaeme sonst als seine
        # Zeichenkettenform hinaus ("timestamp=datetime.datetime(...)").
        wert = wert.model_dump(mode="json")
    if isinstance(wert, dict):
        return {
            str(k): _kompakt_wert(v, hoechstens)
            for k, v in wert.items()
            if str(k).lower() not in GESPERRT
        }
    if isinstance(wert, list):
        gekuerzt = _duennen(wert, hoechstens)
        werte = [_kompakt_wert(v, hoechstens) for v in gekuerzt]
        if len(gekuerzt) < len(wert):
            return {"ausgeduennt": f"{len(gekuerzt)} von {len(wert)} Eintraegen", "werte": werte}
        return werte
    if isinstance(wert, float):
        return _zahl(wert)
    return wert


def kompakt(wert: Any) -> Any:
    """Ein Ergebnis in die Form, die an das Modell geht: gesperrte Felder gestrichen, Zahlen
    gerundet, lange Listen ausgeduennt und das Ganze unter `ERGEBNIS_MAX` Zeichen."""
    import json

    hoechstens = LISTE_MAX
    while True:
        ergebnis = _kompakt_wert(wert, hoechstens)
        if (
            hoechstens <= 3
            or len(json.dumps(ergebnis, ensure_ascii=False, default=str)) <= ERGEBNIS_MAX
        ):
            return ergebnis
        hoechstens //= 2


def _heute(k: Kontext) -> date:
    return k.runner.now.astimezone(BERLIN).date()


def _tag(k: Kontext, text: str | None) -> date:
    """Ein Datum aus der Angabe des Modells; leer heisst heute. Zukunft wird abgewiesen."""
    if not text:
        return _heute(k)
    try:
        tag = date.fromisoformat(str(text).strip()[:10])
    except ValueError as fehler:
        raise WerkzeugError(
            f"Das Datum {text!r} ist nicht lesbar. Erwartet wird JJJJ-MM-TT."
        ) from fehler
    if tag > _heute(k):
        raise WerkzeugError("Fuer die Zukunft gibt es keine Messwerte.")
    return tag


_ZEITRAEUME = ("day", "week", "month", "year")
_ZEITRAUM_DE = {"tag": "day", "woche": "week", "monat": "month", "jahr": "year"}


def _zeitraum(text: str | None, vorgabe: str = "day") -> str:
    wert = (text or vorgabe).strip().lower()
    wert = _ZEITRAUM_DE.get(wert, wert)
    if wert not in _ZEITRAEUME:
        raise WerkzeugError("Zeitraum muss tag, woche, monat oder jahr sein.")
    return wert


def _ergebnis(zeitraum: str, stichtag: date, daten: Any) -> dict[str, Any]:
    return {"zeitraum": zeitraum, "stichtag": stichtag.isoformat(), "daten": kompakt(daten)}


# ---------------------------------------------------------------------------
# Lesende Werkzeuge
# ---------------------------------------------------------------------------


async def _jetzt(k: Kontext) -> dict[str, Any]:
    zustand = k.runner.live_state()
    return {
        "stand": k.runner.now.isoformat(),
        "daten": kompakt(
            {
                "leistung": zustand.snapshot,
                "puffer": zustand.buffer,
                "waermepumpe": zustand.heat_pump,
                "letzte_entscheidung": zustand.decision,
                "betriebsmodus": zustand.operating_mode,
                "ofen": zustand.stove,
                "preisrang_jetzt": zustand.price_rank,
                "heute_kwh": zustand.today_kwh,
            }
        ),
    }


def _zeitraum_werkzeug(
    methode: str, vorgabe: str = "day"
) -> Callable[..., Awaitable[dict[str, Any]]]:
    async def lauf(
        k: Kontext, zeitraum: str | None = None, stichtag: str | None = None
    ) -> dict[str, Any]:
        z = _zeitraum(zeitraum, vorgabe)
        tag = _tag(k, stichtag)
        aufruf = cast(Callable[[str, date], Awaitable[Any]], getattr(k.runner, methode))
        return _ergebnis(z, tag, await aufruf(z, tag))

    return lauf


async def _nachbetrachtung(k: Kontext, tag: str | None = None) -> dict[str, Any]:
    t = _tag(k, tag)
    return {"tag": t.isoformat(), "daten": kompakt(await k.runner.nachbetrachtung(t))}


async def _fahrplan(k: Kontext) -> dict[str, Any]:
    plan = getattr(k.runner, "plan", None)
    if plan is None:
        raise WerkzeugError("Es liegt noch kein Plan vor.")
    return {"daten": kompakt(plan)}


async def _waermepumpe(k: Kontext) -> dict[str, Any]:
    return {"daten": kompakt(await k.runner.waermepumpe())}


async def _kontaktwirkung(k: Kontext, tage: int | None = None) -> dict[str, Any]:
    n = max(1, min(int(tage or 14), 60))
    return {"tage": n, "daten": kompakt(await k.runner.kontaktwirkung(n))}


async def _raeume(k: Kontext) -> dict[str, Any]:
    live = await k.runner.rooms_live()
    return {
        "daten": [
            {
                "raum": r.name,
                "geschoss": r.floor,
                "ist_c": r.temp_c,
                "soll_c": r.setpoint_c,
                "regelziel_c": r.target_c,
                "abweichung_k": r.deviation_k,
                "ventile_offen_anteil": r.valve,
                "feuchte_pct": r.humidity_pct,
            }
            for r in live.rooms
        ]
    }


async def _entscheidungen(k: Kontext, anzahl: int | None = None) -> dict[str, Any]:
    n = max(1, min(int(anzahl or 10), 30))
    return {
        "daten": kompakt([d.model_dump(mode="json") for d in await k.runner.recent_decisions(n)])
    }


async def _prognoseguete(k: Kontext) -> dict[str, Any]:
    return {"daten": kompakt(await k.runner.forecast_evaluation())}


async def _tagesdiagnose(k: Kontext, tag: str | None = None) -> dict[str, Any]:
    t = _tag(k, tag)
    text = await k.runner.diagnose_day(t)
    return {"tag": t.isoformat(), "text": text[:ERGEBNIS_MAX]}


async def _rechnungen(k: Kontext) -> dict[str, Any]:
    zeilen = await k.runner.invoices()
    return {
        "daten": kompakt(
            [
                {
                    "zeitraum": z.period_label,
                    "von": z.period_start,
                    "bis": z.period_end,
                    "kwh_laut_rechnung": z.kwh,
                    "kwh_gemessen": z.measured_kwh,
                    "abdeckung_messung": z.coverage,
                    "brutto_eur": z.total_gross_eur,
                    "ct_je_kwh_brutto": z.avg_ct_kwh_gross,
                    "ct_je_kwh_gemessen": z.measured_avg_ct_kwh,
                    "urteil": z.verdict,
                    "befunde": z.problems,
                }
                for z in zeilen
            ]
        )
    }


async def _rechnung(k: Kontext, zeitraum: str) -> dict[str, Any]:
    """Eine Rechnung, ausgewaehlt ueber ihre Zeitraumsbezeichnung. Die Rechnungsnummer verlaesst den
    Dienst nicht; aufgeloest wird hier."""
    gesucht = " ".join(str(zeitraum or "").lower().split())
    for zeile in await k.runner.invoices():
        if " ".join(zeile.period_label.lower().split()) == gesucht:
            bericht = await k.runner.invoice(zeile.number)
            if bericht is None:
                break
            daten = bericht.model_dump(mode="json")
            daten.get("invoice", {}).pop("number", None)
            return {"zeitraum": zeile.period_label, "daten": kompakt(daten)}
    bekannt = ", ".join(z.period_label for z in await k.runner.invoices()) or "keine"
    raise WerkzeugError(f"Eine Rechnung fuer {zeitraum!r} gibt es nicht. Vorhanden: {bekannt}.")


async def _wochenrueckblick(k: Kontext, stichtag: str | None = None) -> dict[str, Any]:
    """Die Woche bis zum Stichtag in einem Ergebnis: Bilanz, Waerme, Verschiebung, Kontaktwirkung."""
    tag = _tag(k, stichtag)
    bilanz = (await k.runner.energy_summary("week", tag)).model_dump(mode="json")
    waerme = (await k.runner.heat_report("week", tag)).model_dump(mode="json")
    wirkung = (await k.runner.kontaktwirkung(7)).model_dump(mode="json")
    # Fuer einen Rueckblick genuegen die Summen der Woche. Die Tageszeilen der Bilanz, die in der
    # Waerme noch einmal enthaltene Bilanz und die Methodenbeschreibung kosteten das Dreifache an
    # Token und sagen nichts, was die Summen nicht sagen.
    waerme.pop("summary", None)
    wirkung.pop("methode_de", None)
    # Als Ganzes kompakt, damit die Obergrenze fuer das ganze Ergebnis gilt und nicht je Teil.
    ergebnis: dict[str, Any] = kompakt(
        {
            "woche_bis": tag.isoformat(),
            "woche_ab": (tag - timedelta(days=6)).isoformat(),
            "energiebilanz": {"summen": bilanz.get("totals"), "meta": bilanz.get("meta")},
            "waerme": waerme,
            "verschiebung": await k.runner.shift_report("week", tag),
            "kontaktwirkung": wirkung,
        }
    )
    return ergebnis


async def _leitfaden(_k: Kontext, frage: str) -> dict[str, Any]:
    gefunden = leitfaden(frage)
    if gefunden is None:
        return {
            "hinweis": "Dazu gibt es keinen Leitfaden. Beantworte die Frage mit den passenden Werkzeugen.",
            "vorhanden": [ll.name for ll in LEITFAEDEN],
        }
    return {
        "leitfaden": gefunden.name,
        "werkzeuge_in_dieser_reihenfolge": list(gefunden.werkzeuge),
        "die_antwort_muss_enthalten": list(gefunden.bestandteile),
        "vorsicht": gefunden.vorsicht,
    }


async def _nachschlagen(_k: Kontext, stichwort: str) -> dict[str, Any]:
    treffer = nachschlagen(stichwort)
    if not treffer:
        return {"hinweis": "In den Methodenpapieren steht dazu nichts."}
    return {
        "fundstellen": [
            {"papier": t.papier, "abschnitt": t.ueberschrift, "text": t.text} for t in treffer
        ]
    }


# ---------------------------------------------------------------------------
# Vorschlaege - schreiben nichts
# ---------------------------------------------------------------------------


def _normal(text: str) -> str:
    return re.sub(r"\s+", " ", str(text or "")).strip().lower()


async def _schalten_vorschlagen(k: Kontext, verbraucher: str, an: bool) -> dict[str, Any]:
    gesucht = _normal(verbraucher)
    treffer = [
        (schluessel, name)
        for schluessel, name in SCHALTBAR.items()
        if gesucht in (_normal(schluessel), _normal(name)) or (gesucht and gesucht in _normal(name))
    ]
    if len(treffer) != 1:
        raise WerkzeugError(
            "Schaltbar sind nur: "
            + ", ".join(SCHALTBAR.values())
            + (". Die Angabe passt auf mehrere." if treffer else ".")
        )
    schluessel, name = treffer[0]
    # Der heutige Zustand, damit die Bestaetigung "aus -> ein" zeigen kann und nicht nur "ein".
    messung = k.runner.live_state().snapshot.actuators.get(schluessel)
    war_an = None if messung is None or messung.value is None else bool(messung.value)
    vorschlag = {
        "art": "schalten",
        "ziel": schluessel,
        "name": name,
        "an": bool(an),
        "war_an": war_an,
    }
    if vorschlag not in k.vorschlaege:
        k.vorschlaege.append(vorschlag)
    return {
        **vorschlag,
        "hinweis": "Vorgemerkt. Geschaltet wird NICHTS, bis der Anwender den Knopf drueckt.",
    }


async def _sollwert_vorschlagen(k: Kontext, raum: str, grad: float) -> dict[str, Any]:
    from dch_api.application import rooms as rooms_logic

    live = await k.runner.rooms_live()
    gesucht = _normal(raum)
    treffer = [r for r in live.rooms if _normal(r.name) == gesucht] or [
        r for r in live.rooms if gesucht and gesucht in _normal(r.name)
    ]
    if len(treffer) != 1:
        namen = ", ".join(r.name for r in live.rooms) or "keine"
        raise WerkzeugError(f"Der Raum ist nicht eindeutig. Bekannt sind: {namen}.")
    r = treffer[0]
    try:
        wert = float(grad)
    except (TypeError, ValueError) as fehler:
        raise WerkzeugError("Die Temperatur ist keine Zahl.") from fehler
    untere = max(rooms_logic.SOLL_MIN, SOLL_ALFRED_MIN)
    obere = min(rooms_logic.SOLL_MAX, SOLL_ALFRED_MAX)
    if not math.isfinite(wert) or not untere <= wert <= obere:
        raise WerkzeugError(
            f"Alfred schlaegt nur Sollwerte zwischen {untere:g} und {obere:g} Grad vor. "
            "Andere Werte stellt der Anwender selbst auf der Seite Haus."
        )
    # Auf halbe Grad wie der Endpunkt: Ein Knopf, der 21,3 verspricht, wo 21,5 gestellt wird,
    # verspraeche etwas anderes, als die Anwendung tut.
    wert = round(wert * 2) / 2
    if r.setpoint_c is not None and abs(wert - r.setpoint_c) > SOLL_ALFRED_SCHRITT_K:
        raise WerkzeugError(
            f"Alfred aendert einen Sollwert um hoechstens {SOLL_ALFRED_SCHRITT_K:g} Grad "
            f"(jetzt {r.setpoint_c:g}). Groessere Schritte stellt der Anwender selbst."
        )
    vorschlag = {
        "art": "sollwert",
        "ziel": r.id,
        "name": r.name,
        "alt": r.setpoint_c,
        "neu": wert,
    }
    k.vorschlaege[:] = [
        v for v in k.vorschlaege if not (v.get("art") == "sollwert" and v.get("ziel") == r.id)
    ]
    k.vorschlaege.append(vorschlag)
    return {
        **{kk: vv for kk, vv in vorschlag.items() if kk != "ziel"},
        "hinweis": "Vorgemerkt. Gestellt wird NICHTS, bis der Anwender den Knopf drueckt.",
    }


# ---------------------------------------------------------------------------
# Katalog
# ---------------------------------------------------------------------------

_OHNE: dict[str, Any] = {"type": "object", "properties": {}}

_ZEITRAUM_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "zeitraum": {
            "type": "string",
            "enum": ["tag", "woche", "monat", "jahr"],
            "description": "Tag, Kalenderwoche, Kalendermonat oder Kalenderjahr um den Stichtag.",
        },
        "stichtag": {
            "type": "string",
            "description": "Ein Datum im Zeitraum als JJJJ-MM-TT; leer heisst heute.",
        },
    },
}

_TAG_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {"tag": {"type": "string", "description": "JJJJ-MM-TT; leer heisst heute."}},
}

WERKZEUGE: tuple[Werkzeug, ...] = (
    Werkzeug(
        "jetzt",
        "Der Augenblick: Leistungen (PV, Netz, Speicher, Haus, Waermepumpe, Wallbox), "
        "Pufferspeicher, Waermepumpe, Ofen, Preisrang und die letzte Regler-Entscheidung mit "
        "Begruendung, dazu die Tagessummen bis jetzt.",
        _OHNE,
        _jetzt,
    ),
    Werkzeug(
        "energiebilanz",
        "Strombilanz eines Zeitraums: PV, Bezug, Einspeisung, Speicher, Verbrauch nach "
        "Verbrauchern, Autarkie, Eigenverbrauch, mittlerer Bezugspreis und Kosten.",
        _ZEITRAUM_SCHEMA,
        _zeitraum_werkzeug("energy_summary"),
    ),
    Werkzeug(
        "waerme",
        "Waerme eines Zeitraums: Strom und Kosten der Waermepumpe, Waermebedarfsprognose.",
        _ZEITRAUM_SCHEMA,
        _zeitraum_werkzeug("heat_report"),
    ),
    Werkzeug(
        "waermebilanz",
        "Wie viel Waerme Waermepumpe und Pelletofen geliefert haben, was Heizung und Warmwasser "
        "entnommen haben und was verloren ging, mit den Annahmen.",
        _ZEITRAUM_SCHEMA,
        _zeitraum_werkzeug("heat_balance"),
    ),
    Werkzeug(
        "verschiebung",
        "Was das Verschieben der Waermepumpe in guenstige Stunden gebracht hat: Vergleichslauf "
        "derselben Stunden ohne Preisblick, mit Annahmen. Eine Rechnung, keine Messung.",
        _ZEITRAUM_SCHEMA,
        _zeitraum_werkzeug("shift_report", "month"),
    ),
    Werkzeug(
        "wallbox",
        "Wallbox eines Zeitraums: Ladeenergie, Herkunft (PV, Netz, Speicher), Kosten, Ladevorgaenge.",
        _ZEITRAUM_SCHEMA,
        _zeitraum_werkzeug("ev_report"),
    ),
    Werkzeug(
        "pv_abrechnung",
        "PV-Abrechnung eines Zeitraums: Einspeisung, Eigenverbrauch, Verguetung, Umsatzsteuer.",
        _ZEITRAUM_SCHEMA,
        _zeitraum_werkzeug("pv_report", "year"),
    ),
    Werkzeug(
        "nachbetrachtung",
        "Ein vergangener Tag in Euro: was der Fahrplan versprochen hat, was gehalten wurde und "
        "woran die Abweichung lag (Prognose, Nachfuehren, Maschine).",
        _TAG_SCHEMA,
        _nachbetrachtung,
    ),
    Werkzeug(
        "fahrplan",
        "Der aktuelle Plan: guenstige und teure Preisfenster, PV-Ueberschussfenster und das "
        "15-Minuten-Raster voraus.",
        _OHNE,
        _fahrplan,
    ),
    Werkzeug(
        "waermepumpe",
        "Die Waermepumpe im Augenblick mit allem, was ihr eigener Bus meldet.",
        _OHNE,
        _waermepumpe,
    ),
    Werkzeug(
        "kontaktwirkung",
        "Ob die Waermepumpe der Anforderung folgt: Anteil, Verzoegerung, Faelle.",
        {
            "type": "object",
            "properties": {
                "tage": {"type": "integer", "description": "Rueckblick in Tagen, 1 bis 60."}
            },
        },
        _kontaktwirkung,
    ),
    Werkzeug(
        "raeume",
        "Die Raeume im Augenblick: Ist- und Solltemperatur, Abweichung, Ventile, Feuchte.",
        _OHNE,
        _raeume,
    ),
    Werkzeug(
        "entscheidungen",
        "Die letzten Zustandswechsel des Reglers mit Begruendungscodes und Erklaerung.",
        {
            "type": "object",
            "properties": {"anzahl": {"type": "integer", "description": "1 bis 30."}},
        },
        _entscheidungen,
    ),
    Werkzeug(
        "prognoseguete",
        "Wie gut die PV- und Verbrauchsprognosen waren: Prognose gegen Ist, Korrekturfaktoren.",
        _OHNE,
        _prognoseguete,
    ),
    Werkzeug(
        "tagesdiagnose",
        "Ein Tag als Text: Stundenwerte und auffaellige Minuten. Fuer 'diese Zahl kann nicht stimmen'.",
        _TAG_SCHEMA,
        _tagesdiagnose,
    ),
    Werkzeug(
        "rechnungen",
        "Die gepruefte Stromrechnungen mit Zeitraum, kWh laut Rechnung und gemessen, Preis und Urteil.",
        _OHNE,
        _rechnungen,
    ),
    Werkzeug(
        "rechnung",
        "Eine gepruefte Rechnung mit allen Positionen und Befunden. Zeitraum genau so angeben, "
        "wie ihn 'rechnungen' nennt.",
        {
            "type": "object",
            "properties": {"zeitraum": {"type": "string"}},
            "required": ["zeitraum"],
        },
        _rechnung,
    ),
    Werkzeug(
        "wochenrueckblick",
        "Die sieben Tage bis zum Stichtag in einem Ergebnis: Strombilanz, Waerme, was das "
        "Verschieben gebracht hat und ob die Waermepumpe der Anforderung gefolgt ist.",
        {
            "type": "object",
            "properties": {
                "stichtag": {
                    "type": "string",
                    "description": "Letzter Tag der Woche; leer heisst heute.",
                }
            },
        },
        _wochenrueckblick,
    ),
    Werkzeug(
        "leitfaden",
        "Holt den Leitfaden zu einer Auswertungsfrage: welche Werkzeuge sie braucht und was die "
        "Antwort enthalten muss. ZUERST aufrufen bei: warum teurer, lohnt das Verschieben, folgt "
        "die Waermepumpe, stimmt die Rechnung, wie war die Woche, warum lag die Prognose daneben.",
        {
            "type": "object",
            "properties": {
                "frage": {
                    "type": "string",
                    "enum": [ll.name for ll in LEITFAEDEN],
                    "description": "\n".join(f"{ll.name}: {ll.frage}" for ll in LEITFAEDEN),
                }
            },
            "required": ["frage"],
        },
        _leitfaden,
    ),
    Werkzeug(
        "nachschlagen",
        "Schlaegt in den eigenen Methodenpapieren nach: Regelung der Waermepumpe, Wirkung des "
        "Kontakts, Nachbetrachtung, Ofen-Optimierung, PV-Abrechnung, Prognose und Waermemodell. "
        "Fuer Fragen, WIE oder WARUM etwas gerechnet oder geregelt wird.",
        {
            "type": "object",
            "properties": {
                "stichwort": {
                    "type": "string",
                    "description": "Wonach gesucht wird, in Stichworten. Mehrere Woerter treffen besser.",
                }
            },
            "required": ["stichwort"],
        },
        _nachschlagen,
    ),
    Werkzeug(
        "schalten_vorschlagen",
        "Schlaegt vor, einen Verbraucher ein- oder auszuschalten. Schaltet NICHTS: Der Anwender "
        "bekommt einen Knopf. Schaltbar: " + ", ".join(SCHALTBAR.values()) + ".",
        {
            "type": "object",
            "properties": {
                "verbraucher": {"type": "string", "enum": list(SCHALTBAR.values())},
                "an": {"type": "boolean", "description": "true einschalten, false ausschalten."},
            },
            "required": ["verbraucher", "an"],
        },
        _schalten_vorschlagen,
    ),
    Werkzeug(
        "sollwert_vorschlagen",
        "Schlaegt eine neue Solltemperatur fuer einen Raum vor. Stellt NICHTS: Der Anwender bekommt "
        "einen Knopf. Den Raumnamen so angeben, wie 'raeume' ihn nennt.",
        {
            "type": "object",
            "properties": {
                "raum": {"type": "string"},
                "grad": {"type": "number", "description": "Neue Solltemperatur in Grad Celsius."},
            },
            "required": ["raum", "grad"],
        },
        _sollwert_vorschlagen,
    ),
)

_NACH_NAME = {w.name: w for w in WERKZEUGE}


async def ausfuehren(name: str, argumente: dict[str, Any], kontext: Kontext) -> dict[str, Any]:
    """Fuehrt ein Werkzeug aus; die einzige Stelle, die Daten hinausgibt.

    Argumente ausserhalb des Schemas werden verworfen. Jeder Fehlschlag ergibt ein Feld `fehler`
    statt einer Ausnahme, damit das Modell den Grund nennen kann. Der Text stammt immer aus diesem
    Modul, nie aus einer Bibliotheksmeldung, die Pfade oder Kennungen zitieren koennte.
    """
    werkzeug = _NACH_NAME.get(name)
    if werkzeug is None:
        return {"fehler": f"Ein Werkzeug namens {name!r} gibt es nicht."}
    erlaubt = set(werkzeug.schema.get("properties", {}))
    argumente = {k: v for k, v in (argumente or {}).items() if k in erlaubt}
    try:
        return await werkzeug.ausfuehrung(kontext, **argumente)
    except WerkzeugError as fehler:
        return {"fehler": str(fehler)}
    except SchreibsperreError:
        # Darf nie vorkommen: Kein Werkzeug soll an eine schreibende Funktion. Kommt es doch vor,
        # ist das ein Fehler im Code und gehoert laut ins Protokoll, nicht still in die Antwort.
        log.warning("alfred_schreibsperre", werkzeug=name)
        return {"fehler": "Das ist Alfred nicht erlaubt."}
    except TypeError:
        return {"fehler": "Dem Aufruf fehlt eine Angabe."}
    except Exception:
        return {"fehler": "Das Werkzeug konnte nichts liefern."}
