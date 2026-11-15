"""
Stromrechnungen anderer Anbieter lesen (docs/ALFRED.md, "Rechnungen anderer Anbieter").

Die Tibber-Pruefung (application/tibber_invoice.py) liest ihre Rechnungen mit festen Regeln und
ist dort richtig: Sie kennt jede Zeile und irrt nicht. Fuer jede andere Rechnung muesste man einen
zweiten, dritten, vierten Leser bauen. Hier liest stattdessen das Sprachmodell - und alles, was
danach kommt, ist wieder fest: Pruefung der gelesenen Werte, Vergleich mit dem eigenen Zaehler,
Befunde.

**Was das Haus verlaesst, ist eine Positivliste.** Eine Rechnung traegt Name, Anschrift,
Kundennummer, Zaehlernummer, Marktlokation und Bankverbindung. Nichts davon braucht die Pruefung.
`relevante_zeilen` behaelt nur Zeilen mit Mengen, Preisen, Betraegen und Zeitraeumen, und
`schwaerzen` tilgt darin noch IBAN, Mailadressen, Telefonnummern und lange Ziffernfolgen
(Kunden-, Zaehler- und Marktlokationsnummern). Deterministisch, gegen Muster - nicht durch ein
Modell, das gelegentlich einen Namen uebersieht, ohne dass jemand erfaehrt welchen.

**Nichts wird gespeichert.** Das Ergebnis geht an die Oberflaeche und sonst nirgends hin. Wer eine
Ablage will, braucht eine Tabelle mit eigener Entscheidung darueber, was darin stehen darf.
"""

from __future__ import annotations

import io
import re
from datetime import date, timedelta
from typing import TYPE_CHECKING, Any, Literal

from pydantic import BaseModel

from dch_api.application.runtime import Runtime

if TYPE_CHECKING:
    from dch_api.schemas import InvoiceReportOut

#: Hoechstzahl der Zeilen, die an das Modell gehen. Eine Rechnung hat selten mehr als hundert
#: relevante; die Grenze haelt eine Datei mit Anhang davon ab, die Rechnung zu sprengen.
ZEILEN_MAX = 160

#: Abweichung zwischen Rechnung und eigener Messung, ab der es ein Befund ist (Prozent).
TOLERANZ_PCT = 5.0

#: Mindestabdeckung der eigenen Messung, damit der Vergleich etwas aussagt.
ABDECKUNG_MIN = 0.9

_SCHLUESSELWOERTER = re.compile(
    r"kwh|ct|cent|€|eur\b|euro|arbeitspreis|grundpreis|verbrauch|zeitraum|abrechnung|"
    r"netto|brutto|mwst|umsatzsteuer|stromsteuer|zählerstand|zaehlerstand|summe|gesamt|"
    r"abschlag|guthaben|nachzahlung|netzentgelt|konzession|umlage|tag(e)?\b|monat|von|bis|tarif",
    re.IGNORECASE,
)

_SCHWAERZEN = (
    (re.compile(r"\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]{4}){3,7}(?:\s?[A-Z0-9]{1,3})?\b"), "[IBAN]"),
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "[Mail]"),
    (re.compile(r"(?:\+49|0049|\b0)\s?\d{2,5}[\s/-]?\d{3,}[\s-]?\d*"), "[Telefon]"),
    # Kunden-, Vertrags-, Zaehler-, Marktlokationsnummern: acht und mehr Ziffern am Stueck oder in
    # Gruppen. Betraege und Zaehlerstaende haben Komma oder Punkt und bleiben stehen.
    (re.compile(r"\b(?:DE)?\d[\d ]{7,}\d\b"), "[Nummer]"),
)


class GeleseneRechnung(BaseModel):
    """Was das Modell gelesen hat, nach Pruefung der Typen."""

    anbieter: str | None = None
    von: date | None = None
    bis: date | None = None
    kwh: float | None = None
    arbeitspreis_ct_kwh: float | None = None
    grundpreis_eur_monat: float | None = None
    brutto_eur: float | None = None
    netto_eur: float | None = None


class Befund(BaseModel):
    stufe: str  # ok | info | warning
    titel: str
    text: str


class Rechnungsergebnis(BaseModel):
    gelesen: GeleseneRechnung
    mittlerer_preis_ct_kwh: float | None
    gemessen_kwh: float | None
    abdeckung: float | None
    befunde: list[Befund]
    #: Wie viele Zeilen an den Anbieter gingen - damit die Oberflaeche es sagen kann.
    zeilen_gesendet: int


def pdf_text(payload: bytes) -> str:
    from pypdf import PdfReader

    try:
        leser = PdfReader(io.BytesIO(payload))
        return "\n".join(seite.extract_text() or "" for seite in leser.pages)
    except Exception as fehler:
        raise ValueError(f"PDF nicht lesbar: {fehler.__class__.__name__}") from fehler


def schwaerzen(zeile: str) -> str:
    for muster, ersatz in _SCHWAERZEN:
        zeile = muster.sub(ersatz, zeile)
    return zeile


def relevante_zeilen(text: str) -> list[str]:
    """Nur Zeilen mit einer Ziffer UND einem Schluesselwort, geschwaerzt und gekuerzt."""
    zeilen = []
    for roh in text.splitlines():
        zeile = " ".join(roh.split())
        if not zeile or not re.search(r"\d", zeile) or not _SCHLUESSELWOERTER.search(zeile):
            continue
        zeilen.append(schwaerzen(zeile)[:200])
        if len(zeilen) >= ZEILEN_MAX:
            break
    return zeilen


SYSTEMTEXT = (
    "Du liest Zeilen aus einer deutschen Stromrechnung eines Privathaushalts. Antworte NUR mit "
    "einem JSON-Objekt mit genau diesen Feldern, unbekannte Werte als null:\n"
    '{"anbieter": Name des Stromanbieters oder null, "von": "JJJJ-MM-TT" Beginn des '
    'Abrechnungszeitraums, "bis": "JJJJ-MM-TT" Ende, "kwh": abgerechneter Verbrauch in kWh, '
    '"arbeitspreis_ct_kwh": Arbeitspreis brutto in ct/kWh, "grundpreis_eur_monat": Grundpreis '
    'brutto je Monat in Euro, "brutto_eur": Rechnungsbetrag fuer den Zeitraum brutto, '
    '"netto_eur": derselbe netto}\n'
    "Du rechnest nichts aus. Steht ein Wert nicht in den Zeilen, ist er null. Gibt es mehrere "
    "Arbeitspreise, nimm den mit der groessten Menge. Zahlen mit Punkt als Dezimaltrenner."
)


def _float(wert: Any) -> float | None:
    if wert is None or isinstance(wert, bool):
        return None
    if isinstance(wert, int | float):
        return float(wert)
    text = str(wert).strip().replace("€", "").replace(" ", "")
    # "1.234,56" ist deutsch mit Tausenderpunkt; "12,5" und "12.5" sind dasselbe.
    text = (
        text.replace(".", "").replace(",", ".")
        if "," in text and "." in text
        else text.replace(",", ".")
    )
    try:
        return float(text)
    except ValueError:
        return None


def _datum(wert: Any) -> date | None:
    try:
        return date.fromisoformat(str(wert)[:10]) if wert else None
    except ValueError:
        return None


def lesen(roh: dict[str, Any]) -> GeleseneRechnung:
    """Die Antwort des Modells, Feld fuer Feld geprueft; Unlesbares wird None statt falsch."""
    anbieter = roh.get("anbieter")
    gelesen = GeleseneRechnung(
        anbieter=str(anbieter)[:60] if isinstance(anbieter, str) and anbieter.strip() else None,
        von=_datum(roh.get("von")),
        bis=_datum(roh.get("bis")),
        kwh=_float(roh.get("kwh")),
        arbeitspreis_ct_kwh=_float(roh.get("arbeitspreis_ct_kwh")),
        grundpreis_eur_monat=_float(roh.get("grundpreis_eur_monat")),
        brutto_eur=_float(roh.get("brutto_eur")),
        netto_eur=_float(roh.get("netto_eur")),
    )
    if gelesen.von and gelesen.bis and gelesen.bis < gelesen.von:
        gelesen.von, gelesen.bis = gelesen.bis, gelesen.von
    return gelesen


async def gemessen(runner: Runtime, von: date, bis: date) -> tuple[float, float]:
    """Netzbezug und Abdeckung des eigenen Zaehlers zwischen `von` und `bis` (beide einschliesslich).

    Ganze Kalendermonate auf einmal, die Raender tageweise: so bleiben es fuer ein Jahr gut zwanzig
    Abfragen statt dreihundertfuenfundsechzig.
    """
    import_kwh = 0.0
    minuten = 0
    tag = von
    while tag <= bis:
        monatsende = (tag.replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1)
        if tag.day == 1 and monatsende <= bis:
            summe = await runner.energy_summary("month", tag)
            tag = monatsende + timedelta(days=1)
        else:
            summe = await runner.energy_summary("day", tag)
            tag = tag + timedelta(days=1)
        import_kwh += summe.totals.import_kwh
        minuten += summe.totals.minutes
    soll = ((bis - von).days + 1) * 24 * 60
    return round(import_kwh, 2), round(min(1.0, minuten / soll), 3) if soll else 0.0


async def pruefen(runner: Runtime, gelesen: GeleseneRechnung, zeilen: int) -> Rechnungsergebnis:
    """Die festen Pruefungen nach dem Lesen. Hier rechnet der Dienst, nicht das Modell."""
    befunde: list[Befund] = []
    preis = (
        round(gelesen.brutto_eur / gelesen.kwh * 100, 2)
        if gelesen.brutto_eur and gelesen.kwh
        else None
    )
    fehlend = [n for n in ("von", "bis", "kwh", "brutto_eur") if getattr(gelesen, n) is None]
    if fehlend:
        befunde.append(
            Befund(
                stufe="info",
                titel="Nicht alles gelesen",
                text="Nicht gefunden: "
                + ", ".join(fehlend)
                + ". Bitte auf der Rechnung nachsehen.",
            )
        )
    kwh_gemessen: float | None = None
    abdeckung: float | None = None
    if gelesen.von and gelesen.bis and gelesen.bis <= runner.now.date():
        if (gelesen.bis - gelesen.von).days > 400:
            befunde.append(
                Befund(
                    stufe="info",
                    titel="Zeitraum zu lang",
                    text="Verglichen wird hoechstens ein Jahr.",
                )
            )
        else:
            kwh_gemessen, abdeckung = await gemessen(runner, gelesen.von, gelesen.bis)
    if gelesen.kwh is not None and kwh_gemessen is not None and abdeckung is not None:
        if abdeckung < ABDECKUNG_MIN:
            befunde.append(
                Befund(
                    stufe="info",
                    titel="Messung lueckenhaft",
                    text=f"Der eigene Zaehler deckt nur {abdeckung:.0%} des Zeitraums ab; "
                    "ein Unterschied in den kWh sagt deshalb wenig.",
                )
            )
        elif kwh_gemessen > 0:
            abweichung = (gelesen.kwh - kwh_gemessen) / kwh_gemessen * 100
            befunde.append(
                Befund(
                    stufe="warning" if abs(abweichung) > TOLERANZ_PCT else "ok",
                    titel="Verbrauch gegen eigene Messung",
                    text=f"Rechnung {gelesen.kwh:.0f} kWh, gemessen {kwh_gemessen:.0f} kWh "
                    f"({abweichung:+.1f} %).",
                )
            )
    if preis is not None and gelesen.arbeitspreis_ct_kwh and preis < gelesen.arbeitspreis_ct_kwh:
        befunde.append(
            Befund(
                stufe="warning",
                titel="Preis unplausibel",
                text=f"Der mittlere Preis ({preis:.2f} ct/kWh) liegt unter dem Arbeitspreis "
                f"({gelesen.arbeitspreis_ct_kwh:.2f} ct/kWh). Vermutlich ist ein Wert falsch gelesen.",
            )
        )
    return Rechnungsergebnis(
        gelesen=gelesen,
        mittlerer_preis_ct_kwh=preis,
        gemessen_kwh=kwh_gemessen,
        abdeckung=abdeckung,
        befunde=befunde,
        zeilen_gesendet=zeilen,
    )


# ---------------------------------------------------------------------------
# Tibber-Rechnungen: erkannt und geprueft ohne Sprachmodell
# ---------------------------------------------------------------------------


class TibberZusammenfassung(BaseModel):
    """Das Ergebnis der festen Tibber-Pruefung, so knapp, wie Alfred es im Panel sagt. Die volle
    Auswertung steht auf der Rechnungsseite, auf die `AlfredRechnungOut.link` zeigt."""

    zeitraum: str
    von: date
    bis: date
    kwh: float
    brutto_eur: float
    ct_kwh_brutto: float
    gemessen_kwh: float | None
    abdeckung: float | None
    urteil: str
    befunde: list[Befund]
    #: Dieselbe Rechnung lag schon vor; der Stand wurde ersetzt.
    schon_bekannt: bool


class AlfredRechnungOut(BaseModel):
    """`tibber`: erkannt, geprueft und abgelegt wie auf der Rechnungsseite, ohne Sprachmodell.
    `andere`: vom Sprachmodell gelesen, fest gegen die eigene Messung gehalten, nicht gespeichert."""

    art: Literal["tibber", "andere"]
    tibber: TibberZusammenfassung | None = None
    andere: Rechnungsergebnis | None = None
    #: Die Seite mit der vollen Auswertung, nur bei `tibber`.
    link: str | None = None


#: Welche Befunde der Tibber-Pruefung Alfred nennt: alles ausser `ok`, damit die Zusammenfassung
#: das sagt, worauf es ankommt, und nicht die zwanzig Posten, die stimmen.
_STUFEN = {"error": "warning", "warning": "warning", "info": "info"}


def tibber_zusammenfassung(bericht: InvoiceReportOut) -> TibberZusammenfassung:
    r = bericht.invoice
    return TibberZusammenfassung(
        zeitraum=r.period_label,
        von=r.period_start,
        bis=r.period_end,
        kwh=r.kwh,
        brutto_eur=r.total_gross_eur,
        ct_kwh_brutto=r.avg_ct_kwh_gross,
        gemessen_kwh=bericht.measured.import_kwh if bericht.measured else None,
        abdeckung=bericht.measured.coverage if bericht.measured else None,
        urteil=bericht.verdict,
        befunde=[
            Befund(stufe=_STUFEN[f.severity], titel=f.title_de, text=f.detail_de)
            for f in bericht.findings
            if f.severity in _STUFEN
        ],
        schon_bekannt=bericht.already_known,
    )


def ist_tibber(payload: bytes) -> bool:
    """Ob die feste Tibber-Pruefung das PDF lesen kann. Deterministisch, ohne Modell: Was sie liest,
    ist eine Tibber-Rechnung; alles andere geht an den Weg fuer andere Anbieter."""
    from dch_api.application.tibber_invoice import InvoiceParseError, parse_pdf

    try:
        parse_pdf(payload)
    except InvoiceParseError:
        return False
    return True
