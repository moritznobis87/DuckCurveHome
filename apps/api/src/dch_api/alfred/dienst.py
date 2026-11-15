"""
Anbindung des Sprachmodells (docs/ALFRED.md).

Alfred ruft benannte Werkzeuge auf (werkzeuge.py) und gibt deren Ergebnis wieder. Gerechnet wird
ausschliesslich im Dienst - in denselben Funktionen, die auch die Seiten zeigen -, damit jede Zahl
einer Antwort dieselbe ist wie auf dem Bildschirm.

Das Modell darf Werkzeuge kombinieren und nacheinander aufrufen. Drei Grenzen halten den Ablauf
endlich - `RUNDEN_MAX`, `WERKZEUGE_MAX` und `GESAMTZEIT_S` - und wirken gleich: Ist eine erreicht,
geht die naechste Anfrage ohne Werkzeugliste hinaus, und das Modell muss antworten. Die Grenze
liegt damit im Code und nicht in einer Regel des Systemtexts, an die sich ein Modell halten soll.

**Eine Nachrichtenform.** Mistral nimmt den Systemtext als erste Nachricht und den Schluessel als
Bearer; OpenAI und weitere Anbieter mit kompatiblem Endpunkt tun dasselbe, dort genuegt eine
andere Adresse in DCH_ALFRED_URL. Eine zweite Form (etwa Anthropic) kommt dazu, wenn sie gebraucht
wird, und nicht vorher: Eine Abstraktion mit einer einzigen Implementierung ist eine Behauptung
ueber die Zukunft.

Der Zugangsschluessel steht ausschliesslich im Kopf der Anfrage: nicht im Rumpf, nicht im
Protokoll, nicht in einer Fehlermeldung.
"""

from __future__ import annotations

import json
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import datetime
from typing import Any

import httpx
import structlog

from dch_api.alfred.werkzeuge import WERKZEUGE, Kontext, ausfuehren
from dch_api.settings import Settings
from hems_core.simulation import BERLIN

log = structlog.get_logger("alfred")

#: Rueckruf fuer Fortschrittsmeldungen, oder None.
Meldung = Callable[[dict[str, Any]], Awaitable[None]] | None

#: Adresse je Anbieter, falls DCH_ALFRED_URL nicht gesetzt ist.
VORGABE_URL = {
    "mistral": "https://api.mistral.ai/v1/chat/completions",
    "openai": "https://api.openai.com/v1/chat/completions",
}

#: Modell je Anbieter, falls DCH_ALFRED_MODELL nicht gesetzt ist.
#:
#: Bewusst nicht die kleinste Stufe. Im Schwesterprojekt erfand `mistral-small` auf eine
#: Bedienfrage einen Reiter und ein Feld, die es nicht gibt: Kleine Modelle halten die Anweisung,
#: nur Belegtes zu nennen, schlechter ein. Der Aufpreis liegt bei Bruchteilen eines Cents je Frage.
VORGABE_MODELL = {
    "mistral": "mistral-medium-latest",
    "openai": "gpt-4o-mini",
}

ANBIETERNAMEN = {"mistral": "Mistral", "openai": "OpenAI"}

#: Ohne Abhaengigkeit von der Spracheinstellung des Rechners: `%A` gaebe dort "Sunday".
WOCHENTAGE = ("Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag")

#: Hoechstlaenge einer Gespraechsantwort in Token.
ANTWORT_MAX = 700

#: Hoechstzahl der Runden mit Werkzeugliste. Drei, weil die aufwendigste uebliche Frage drei
#: braucht: "Warum war der Oktober teurer?" verlangt die Bilanz beider Monate und die Verschiebung.
RUNDEN_MAX = 3

#: Hoechstzahl der insgesamt ausgefuehrten Werkzeuge. Noetig neben RUNDEN_MAX, weil je Runde
#: mehrere Aufrufe zulaessig sind.
WERKZEUGE_MAX = 8

#: Zeitbudget der ganzen Frage in Sekunden. Danach werden keine Werkzeuge mehr angeboten; eine
#: Antwort kommt trotzdem.
GESAMTZEIT_S = 60.0


class AlfredError(Exception):
    """Die Frage konnte nicht beantwortet werden. Die Meldung traegt nie Frage oder Antwort."""


@dataclass(frozen=True)
class Antwort:
    """Text und Vorschlaege. Die Vorschlaege stehen neben dem Text und nicht darin: Die Oberflaeche
    macht Knoepfe daraus und muesste sie sonst aus formuliertem Fliesstext zurueckgewinnen."""

    text: str
    vorschlaege: list[dict[str, Any]]


def aktiv(settings: Settings) -> bool:
    """Ob ein Modell eingerichtet ist, also ein Schluessel vorliegt."""
    return bool(settings.alfred_schluessel.strip())


def anbietername(settings: Settings) -> str | None:
    """Der Anbieter, an den Fragen und Werkzeugdaten gehen - fuer den Hinweis im Panel
    (KI-Verordnung Art. 50). None ohne eingerichtetes Modell."""
    if not aktiv(settings):
        return None
    return ANBIETERNAMEN.get(settings.alfred_anbieter, settings.alfred_anbieter)


def modell(settings: Settings) -> str:
    return settings.alfred_modell.strip() or VORGABE_MODELL[settings.alfred_anbieter]


def _url(settings: Settings) -> str:
    return settings.alfred_url.strip() or VORGABE_URL[settings.alfred_anbieter]


def systemtext(wissen: str, jetzt: datetime) -> str:
    """Die Anweisung an das Modell samt Wissensteil.

    `wissen` sind die geprueften Hilfetexte der Oberflaeche zu dem Ort, an dem gefragt wurde -
    dieselben, die Alfred ohne Modell zeigt. Sie sind die einzige zulaessige Quelle ueber die
    Bedienung dieser Anwendung.
    """
    heute = jetzt.astimezone(BERLIN)
    wochentag = WOCHENTAGE[heute.weekday()]
    return (
        "Du bist Alfred, der Helfer von Duck Curve Home, dem Energiemanagement eines Wohnhauses "
        "mit Photovoltaik, Speicher, Waermepumpe, Pelletofen, 1000-Liter-Pufferspeicher, Wallbox "
        "und dynamischem Stromtarif.\n"
        f"Heute ist {wochentag}, {heute:%d.%m.%Y}, {heute:%H:%M} Uhr (Europe/Berlin). Datumsangaben fuer "
        "Werkzeuge schreibst du als JJJJ-MM-TT.\n\n"
        "REGELN:\n"
        "1. Ueber die Bedienung von Duck Curve Home sagst du NUR, was unter WISSEN steht. Du "
        "nennst NIE eine Seite, einen Reiter oder einen Knopf, der dort nicht woertlich steht. "
        "Kennst du den Ort nicht, sagst du: 'Wo das steht, weiss ich nicht.'\n"
        "2. Du rechnest NICHTS SELBST. Fuer Zahlen zum Haus rufst du ein Werkzeug auf und gibst "
        "dessen Ergebnis wieder. Du schaetzt keine Zahl und leitest keine ab, die nicht im "
        "Ergebnis steht. Einen Unterschied zweier Zahlen aus den Ergebnissen darfst du nennen.\n"
        "3. Allgemeine Begriffe (Autarkie, COP, Eigenverbrauch, dynamischer Tarif) darfst du aus "
        "eigenem Wissen erklaeren, aber ohne Bezug auf die Daten des Hauses.\n"
        "4. Du antwortest kurz und auf Deutsch: zwei bis vier Saetze. Hast du Werkzeuge benutzt, "
        "duerfen es bis zu acht sein; dann nennst du die Zahlen, auf die du dich stuetzt, mit "
        "Einheit und Zeitraum.\n"
        "5. Du darfst mehrere Werkzeuge benutzen, auch nacheinander. Fordere an, was du fuer die "
        "Antwort brauchst, und nicht mehr - jeder Aufruf kostet Wartezeit. Dasselbe Werkzeug mit "
        "denselben Angaben zweimal aufzurufen bringt dasselbe Ergebnis.\n"
        "6. Ist eine Frage allgemein oder betrifft sie die Bedienung, rufst du kein Werkzeug auf.\n"
        "7. Kommt ein Werkzeug nicht mehr zum Zug oder liefert es einen Fehler, antwortest du "
        "mit dem, was du hast, und sagst, was dir fehlt.\n"
        "8. Du SCHALTEST NICHTS. Will jemand ein Licht schalten oder einen Raum waermer oder "
        "kaelter haben, rufst du schalten_vorschlagen oder sollwert_vorschlagen auf. Das legt "
        "dem Anwender einen Knopf vor; erst sein Druck schaltet.\n"
        "8a. Behaupte nie, du haettest etwas geschaltet, gestellt oder gespeichert. Du hast es "
        "VORGESCHLAGEN und sagst, dass der Anwender es bestaetigen muss.\n"
        "8b. Waermepumpe, Pelletofen, Speicher, Alarmanlage und Haustuer stellst du weder noch "
        "schlaegst du es vor. Dafuer gibt es die Seiten der Anwendung und den Regler.\n"
        "8c. Schlage nur vor, wonach gefragt wurde.\n"
        "9. Bei einer AUSWERTUNGSFRAGE - warum war es teurer, hat sich das Verschieben gelohnt, "
        "folgt die Waermepumpe, stimmt die Rechnung, wie war die Woche - rufst du ZUERST "
        "leitfaden auf und arbeitest ihn danach ab. Was unter 'die_antwort_muss_enthalten' "
        "steht, gehoert in die Antwort, auch die unbequemen Teile.\n"
        "10. Fragt jemand, WIE oder WARUM etwas gerechnet oder geregelt wird, schlaegst du mit "
        "nachschlagen in den Methodenpapieren nach und nennst Papier und Abschnitt.\n"
        "10a. Die Papiere und manche Ergebnisse nennen die Anforderung an die Waermepumpe mit "
        "dem Kuerzel ihres Schaltkontakts (Buchstabe und Ziffer). Dem Anwender sagst du immer "
        "'Anforderung' - das Kuerzel versteht niemand.\n"
        "11. Du entscheidest nicht fuer den Anwender. Du legst die Zahlen hin und sagst, woran "
        "sie haengen.\n\n"
        f"WISSEN:\n{wissen}"
    )


def _werkzeugliste() -> list[dict[str, Any]]:
    return [
        {
            "type": "function",
            "function": {"name": w.name, "description": w.beschreibung, "parameters": w.schema},
        }
        for w in WERKZEUGE
    ]


class Klient:
    """Ein Anbieter in der OpenAI-Form: Systemtext als erste Nachricht, Bearer-Schluessel.

    `transport` ersetzt in Tests das Netz (httpx.MockTransport); im Betrieb bleibt er leer.
    """

    def __init__(
        self, settings: Settings, transport: httpx.AsyncBaseTransport | None = None
    ) -> None:
        self._settings = settings
        self._transport = transport

    async def anfragen(
        self,
        system: str,
        nachrichten: list[dict[str, Any]],
        mit_werkzeugen: bool,
        max_token: int = ANTWORT_MAX,
        als_json: bool = False,
    ) -> dict[str, Any]:
        rumpf: dict[str, Any] = {
            "model": modell(self._settings),
            "max_tokens": max_token,
            # Niedrig: Alfred soll wiedergeben, nicht ausschmuecken.
            "temperature": 0.2,
            "messages": [{"role": "system", "content": system}, *nachrichten],
        }
        if mit_werkzeugen:
            rumpf["tools"] = _werkzeugliste()
            rumpf["tool_choice"] = "auto"
        if als_json:
            rumpf["response_format"] = {"type": "json_object"}
        async with httpx.AsyncClient(
            transport=self._transport, timeout=self._settings.alfred_zeitlimit_s
        ) as http:
            antwort = await http.post(
                _url(self._settings),
                headers={
                    "Authorization": f"Bearer {self._settings.alfred_schluessel.strip()}",
                    "content-type": "application/json",
                },
                json=rumpf,
            )
        if antwort.status_code >= 400:
            # Nur der Statuscode (401 falscher Schluessel, 429 Kontingent, 400 unbekanntes
            # Modell). Der Rumpf bleibt draussen, weil er die Anfrage zitieren kann.
            raise AlfredError(f"HTTP {antwort.status_code}")
        nachricht: dict[str, Any] = (antwort.json().get("choices") or [{}])[0].get("message") or {}
        return nachricht

    @staticmethod
    def rufe(nachricht: dict[str, Any]) -> list[tuple[str, str, dict[str, Any]]]:
        rufe = []
        for ruf in nachricht.get("tool_calls") or []:
            funktion = ruf.get("function") or {}
            rufe.append(
                (
                    str(ruf.get("id") or ""),
                    str(funktion.get("name") or ""),
                    _als_argumente(funktion.get("arguments")),
                )
            )
        return rufe

    @staticmethod
    def text(nachricht: dict[str, Any]) -> str:
        inhalt = nachricht.get("content") or ""
        if isinstance(inhalt, list):
            # Mistral liefert bei manchen Modellen Teilstuecke statt einer Zeichenkette.
            inhalt = "".join(str(t.get("text", "")) for t in inhalt if isinstance(t, dict))
        return str(inhalt).strip()

    def anhaengen(
        self,
        nachrichten: list[dict[str, Any]],
        nachricht: dict[str, Any],
        ergebnisse: list[tuple[str, str, str]],
    ) -> None:
        # Nur die Felder, die die Schnittstelle zurueck erwartet; was der Anbieter sonst noch
        # mitschickt, gehoert nicht in die naechste Anfrage.
        nachrichten.append(
            {
                "role": "assistant",
                "content": nachricht.get("content") or "",
                "tool_calls": nachricht.get("tool_calls") or [],
            }
        )
        for kennung, name, text in ergebnisse:
            zeile: dict[str, Any] = {"role": "tool", "tool_call_id": kennung, "content": text}
            if self._settings.alfred_anbieter == "mistral":
                zeile["name"] = name
            nachrichten.append(zeile)


async def _schleife(
    klient: Klient,
    system: str,
    nachrichten: list[dict[str, Any]],
    kontext: Kontext,
    melden: Meldung,
) -> str:
    """Der Antworttext nach Anfrage, Werkzeugen und Nachfrage.

    Ist eine Grenze erreicht, geht die naechste Anfrage ohne Werkzeugliste hinaus; die Schleife
    endet deshalb immer mit einer Antwort und nie mit einem Abbruch. Ein Aufruf mit denselben
    Argumenten laeuft je Frage nur einmal.
    """
    beginn = time.monotonic()
    gerechnet: dict[tuple[str, str], str] = {}
    verbraucht = 0
    for runde in range(RUNDEN_MAX + 1):
        knapp = (
            runde >= RUNDEN_MAX
            or verbraucht >= WERKZEUGE_MAX
            or time.monotonic() - beginn > GESAMTZEIT_S
        )
        nachricht = await klient.anfragen(system, nachrichten, mit_werkzeugen=not knapp)
        rufe = [] if knapp else klient.rufe(nachricht)
        if not rufe:
            return klient.text(nachricht)
        ergebnisse: list[tuple[str, str, str]] = []
        for kennung, name, argumente in rufe:
            schluessel = (name, _als_text(argumente))
            if schluessel in gerechnet:
                ergebnisse.append((kennung, name, gerechnet[schluessel]))
                continue
            if verbraucht >= WERKZEUGE_MAX:
                # Jeder Aufruf braucht eine Antwort, sonst weist der Anbieter die Folgenachricht
                # zurueck; daher eine Absage statt eines ausbleibenden Ergebnisses.
                ergebnisse.append(
                    (
                        kennung,
                        name,
                        _als_text({"fehler": "Fuer diese Frage sind genug Werkzeuge gelaufen."}),
                    )
                )
                continue
            verbraucht += 1
            if melden is not None:
                try:
                    await melden({"werkzeug": name})
                except Exception:  # Fortschritt ist Beiwerk und darf die Antwort nicht kosten
                    log.debug("alfred_meldung_fehlgeschlagen", exc_info=True)
            text = _als_text(await ausfuehren(name, argumente, kontext))
            gerechnet[schluessel] = text
            ergebnisse.append((kennung, name, text))
        klient.anhaengen(nachrichten, nachricht, ergebnisse)
    # Unerreichbar: Die letzte Runde laeuft ohne Werkzeuge und kehrt oben zurueck.
    raise AlfredError("Werkzeugschleife ohne Ergebnis")


async def fragen(
    settings: Settings,
    frage: str,
    wissen: str,
    kontext: Kontext,
    verlauf: list[tuple[str, str]] | None = None,
    melden: Meldung = None,
    transport: httpx.AsyncBaseTransport | None = None,
) -> Antwort:
    """Stellt die Frage an das Modell und liefert Text und Vorschlaege.

    `verlauf` sind die letzten Wechsel als (Rolle, Text), aeltester zuerst. Sie kommen aus dem
    Browser und werden nirgends abgelegt; beruecksichtigt werden die letzten
    DCH_ALFRED_VERLAUF_MAX. Werkzeugaufrufe frueherer Runden gehen nicht mit, nur der Text - sonst
    wuechse jede Frage um die Ergebnisse aller vorigen und die Rechnung mit ihr.
    """
    if not aktiv(settings):
        raise AlfredError("kein Modell eingerichtet")
    gekuerzt = (
        (verlauf or [])[-settings.alfred_verlauf_max :] if settings.alfred_verlauf_max else []
    )
    nachrichten: list[dict[str, Any]] = [
        {"role": "assistant" if wer == "alfred" else "user", "content": inhalt}
        for wer, inhalt in gekuerzt
    ]
    # Ein Gespraech faengt beim Nutzer an. Alfreds Begruessung eroeffnet jedes Panel, und auch das
    # Kuerzen kann eine Antwort nach vorn schieben. Serverseitig, weil eine Regel, die nur der
    # Browser kennt, keine Regel ist.
    while nachrichten and nachrichten[0]["role"] == "assistant":
        nachrichten.pop(0)
    nachrichten.append({"role": "user", "content": frage})
    klient = Klient(settings, transport)
    try:
        text = await _schleife(
            klient, systemtext(wissen, kontext.runner.now), nachrichten, kontext, melden
        )
    except AlfredError:
        raise
    except Exception as fehler:
        # Systemgrenze zum Anbieter; uebernommen wird nur die Art des Scheiterns, da die
        # Anbietermeldung die Frage zitieren kann.
        raise AlfredError(type(fehler).__name__) from fehler
    if not text:
        raise AlfredError("leere Antwort")
    return Antwort(text=text, vorschlaege=list(kontext.vorschlaege))


async def auswerten(
    settings: Settings,
    system: str,
    text: str,
    max_token: int = 1500,
    transport: httpx.AsyncBaseTransport | None = None,
) -> dict[str, Any]:
    """Eine einzelne Anfrage ohne Werkzeuge und Verlauf, Antwort als JSON-Objekt.

    Fuer feste Auswertungen (Rechnung lesen, Zuordnung vorschlagen). Der Gespraechsweg ist dafuer
    ungeeignet: Ein Modell, das waehrend der Auswertung ein Werkzeug ruft, vermischte das
    vorgelegte Papier mit dem Bestand des Hauses.
    """
    if not aktiv(settings):
        raise AlfredError("kein Modell eingerichtet")
    klient = Klient(settings, transport)
    try:
        nachricht = await klient.anfragen(
            system,
            [{"role": "user", "content": text}],
            mit_werkzeugen=False,
            max_token=max_token,
            als_json=True,
        )
    except AlfredError:
        raise
    except Exception as fehler:
        raise AlfredError(type(fehler).__name__) from fehler
    roh = klient.text(nachricht)
    # Manche Modelle legen das JSON trotz Anweisung in einen Codeblock.
    roh = roh.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
    try:
        wert = json.loads(roh)
    except ValueError as fehler:
        raise AlfredError("Antwort ist kein JSON") from fehler
    if not isinstance(wert, dict):
        raise AlfredError("Antwort ist kein JSON-Objekt")
    return wert


def _als_text(wert: Any) -> str:
    """JSON fuer das Modell. `sort_keys` macht die Ausgabe als Zwischenspeicherschluessel
    brauchbar, `ensure_ascii=False` spart Token."""
    return json.dumps(wert, ensure_ascii=False, sort_keys=True, default=str)


def _als_argumente(roh: Any) -> dict[str, Any]:
    """Die Aufrufargumente als Woerterbuch, notfalls leer. Ein unlesbarer Rumpf ergibt einen
    Hinweis aus dem Werkzeug statt einer Ausnahme mitten im Gespraech."""
    if isinstance(roh, dict):
        return roh
    try:
        wert = json.loads(roh or "{}")
    except (TypeError, ValueError):
        return {}
    return wert if isinstance(wert, dict) else {}
