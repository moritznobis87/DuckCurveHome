"""Tibber-Rechnungen prüfen: PDF-Text lesen, Positionen erkennen, rechnen und gegen eigene Messwerte halten.

Die Prüfung trennt zwei Arten von Befunden:

* **Rechnerisch** – nur aus der Rechnung selbst: Preis × Menge je Position, Zwischensummen, Mehrwertsteuer,
  Durchschnittspreis, Grundgebühr nach Tagen, Zählerstandsdifferenz. Diese Befunde sind hart: eine Abweichung
  über die Rundungstoleranz hinaus ist ein Rechenfehler.
* **Abgleich** – gegen unsere Messung und die gespeicherte Tibber-Preisreihe. Diese Befunde sind Hinweise:
  unser Netzzähler ist eine CT-Messung, nicht der geeichte Zähler, und unsere Datenabdeckung ist selten 100 %.
"""

from __future__ import annotations

import re
from datetime import UTC, date, datetime, timedelta
from typing import Literal
from zoneinfo import ZoneInfo

from pydantic import BaseModel, ConfigDict, Field

VAT_RATE = 0.19
Severity = Literal["ok", "info", "warning", "error"]

MONTHS_DE = {
    "jan": 1,
    "januar": 1,
    "feb": 2,
    "februar": 2,
    "mär": 3,
    "märz": 3,
    "mrz": 3,
    "apr": 4,
    "april": 4,
    "mai": 5,
    "jun": 6,
    "juni": 6,
    "jul": 7,
    "juli": 7,
    "aug": 8,
    "august": 8,
    "sep": 9,
    "sept": 9,
    "september": 9,
    "okt": 10,
    "oktober": 10,
    "nov": 11,
    "november": 11,
    "dez": 12,
    "dezember": 12,
}
GROUPS = {
    "Stromeinkauf": "Stromeinkauf",
    "Netz": "Netz",
    "Steuern, Abgaben & Umlagen": "Steuern, Abgaben & Umlagen",
}


class InvoiceParseError(ValueError):
    """Der Text stammt nicht aus einer bekannten Tibber-Rechnung."""


def _num(text: str) -> float:
    """Deutsche Zahl mit Tausenderpunkt und Dezimalkomma."""
    return float(text.strip().replace(".", "").replace(",", "."))


def _decimals(text: str) -> int:
    part = text.strip().split(",")
    return len(part[1]) if len(part) > 1 else 0


def _german_date(text: str) -> date:
    m = re.match(r"\s*(\d{1,2})\.\s*([A-Za-zÄÖÜäöüß]+)\.?\s*(\d{4})", text)
    if not m:
        raise InvoiceParseError(f"Datum nicht lesbar: {text!r}")
    month = MONTHS_DE.get(m.group(2).lower().rstrip("."))
    if month is None:
        raise InvoiceParseError(f"Monat unbekannt: {m.group(2)!r}")
    return date(int(m.group(3)), month, int(m.group(1)))


class InvoicePosition(BaseModel):
    model_config = ConfigDict(frozen=True)

    label: str
    group: str
    ct_per_kwh: float
    ct_decimals: int  # angegebene Nachkommastellen – bestimmt die Rundungstoleranz
    amount_eur: float


class InvoiceFee(BaseModel):
    model_config = ConfigDict(frozen=True)

    label: str
    amount_eur: float
    rate_eur: float | None = None
    per: Literal["month", "day"] | None = None
    days: int | None = None


class TibberInvoice(BaseModel):
    model_config = ConfigDict(frozen=True)

    number: str
    issued_on: date
    period_start: date
    period_end: date
    period_label: str
    kwh: float
    meter_start: float | None = None
    meter_end: float | None = None
    meter_estimated: bool = False
    positions: list[InvoicePosition] = Field(default_factory=list)
    fees: list[InvoiceFee] = Field(default_factory=list)
    energy_net_eur: float
    energy_gross_eur: float
    fees_net_eur: float
    fees_gross_eur: float
    total_net_eur: float
    total_gross_eur: float
    vat_eur: float
    avg_ct_kwh: float
    avg_ct_kwh_gross: float

    @property
    def days(self) -> int:
        return (self.period_end - self.period_start).days + 1


class InvoiceFinding(BaseModel):
    model_config = ConfigDict(frozen=True)

    code: str
    severity: Severity
    title_de: str
    detail_de: str
    expected: float | None = None
    actual: float | None = None
    unit: str = ""

    @property
    def delta(self) -> float | None:
        if self.expected is None or self.actual is None:
            return None
        return round(self.actual - self.expected, 4)


# ---------------------------------------------------------------------- Parsen
_RE_NUMBER = re.compile(r"Rechnungsnummer:\s*(\S+)")
_RE_ISSUED = re.compile(r"Rechnungsdatum:\s*(.+)")
_RE_PERIOD = re.compile(
    r"(\d{1,2}\.\s*[A-Za-zÄÖÜäöüß]+\.?\s*\d{4})\s*-\s*(\d{1,2}\.\s*[A-Za-zÄÖÜäöüß]+\.?\s*\d{4})"
)
_RE_METER = re.compile(
    r"([\d.]+,\d+)\s*\((errechnet|abgelesen)\)\s*([\d.]+,\d+)\s*\((errechnet|abgelesen)\)\s*([\d.]+,\d+)\s*kWh"
)
_RE_TOTAL_KWH = re.compile(r"Stromverbrauch für ganze Periode\s*([\d.]+,\d+)\s*kWh")
_RE_ENERGY = re.compile(
    r"Kosten Stromverbrauch für ([^\d]+\d{4})\s*([\d.]+,\d+)\s*€\s*([\d.]+,\d+)\s*€"
)
_RE_FEES = re.compile(r"Kosten Grundgebühr für [^\d]+\d{4}\s*([\d.]+,\d+)\s*€\s*([\d.]+,\d+)\s*€")
_RE_GRAND = re.compile(r"Gesamtbetrag\s*([\d.]+,\d+)\s*€\s*([\d.]+,\d+)\s*€")
_RE_VAT = re.compile(r"Davon MwSt\s*\d+%\s*([\d.]+,\d+)\s*€")
_RE_AVG = re.compile(r"Durchschnittspreis\s*([\d.]+,\d+)\s*ct/kWh")
_RE_AVG_GROSS = re.compile(r"Durchschnittspreis \(brutto\)\s*([\d.]+,\d+)\s*ct/kWh")
_RE_POSITION = re.compile(r"^(.+?)\s+([\d.]+,\d+)\s*ct/kWh\s+([\d.]+,\d+)\s*€\s*$")
_RE_FEE_LINE = re.compile(r"^(Tibber Gebühr|Netznutzungsgebühr) für .+?\s+([\d.]+,\d+)\s*€\s*$")
_RE_FEE_RATE = re.compile(
    r"^([\d.]+,\d+)\s*€/(Monat|Tag)\s*-\s*Betrag hier für\s*(\d+)\s*Tage?\s*$"
)


def parse_invoice(text: str) -> TibberInvoice:
    """Rechnungstext (aus dem PDF extrahiert) in ein geprüftes Modell überführen."""
    number = _RE_NUMBER.search(text)
    issued = _RE_ISSUED.search(text)
    if number is None or issued is None:
        raise InvoiceParseError(
            "Keine Tibber-Rechnung erkannt (Rechnungsnummer oder Rechnungsdatum fehlen)."
        )
    period = _RE_PERIOD.search(text)
    if period is None:
        raise InvoiceParseError("Abrechnungszeitraum nicht gefunden.")
    energy = _RE_ENERGY.search(text)
    fees_sum = _RE_FEES.search(text)
    grand = _RE_GRAND.search(text)
    if energy is None or fees_sum is None or grand is None:
        raise InvoiceParseError(
            "Kostenübersicht (Verbrauch, Grundgebühr, Gesamtbetrag) unvollständig."
        )
    total_kwh = _RE_TOTAL_KWH.search(text)
    meter = _RE_METER.search(text)
    if total_kwh is None and meter is None:
        raise InvoiceParseError("Verbrauchsmenge nicht gefunden.")

    positions: list[InvoicePosition] = []
    fees: list[InvoiceFee] = []
    group = ""
    lines = [ln.strip() for ln in text.splitlines()]
    for i, line in enumerate(lines):
        if line in GROUPS:
            group = GROUPS[line]
            continue
        p = _RE_POSITION.match(line)
        if p and group:
            positions.append(
                InvoicePosition(
                    label=p.group(1).strip(),
                    group=group,
                    ct_per_kwh=_num(p.group(2)),
                    ct_decimals=_decimals(p.group(2)),
                    amount_eur=_num(p.group(3)),
                )
            )
            continue
        f = _RE_FEE_LINE.match(line)
        if f:
            rate = _RE_FEE_RATE.match(lines[i + 1]) if i + 1 < len(lines) else None
            fees.append(
                InvoiceFee(
                    label=f.group(1),
                    amount_eur=_num(f.group(2)),
                    rate_eur=_num(rate.group(1)) if rate else None,
                    per="month" if rate and rate.group(2) == "Monat" else ("day" if rate else None),
                    days=int(rate.group(3)) if rate else None,
                )
            )
    avg = _RE_AVG.search(text)
    avg_gross = _RE_AVG_GROSS.search(text)
    vat = _RE_VAT.search(text)
    kwh = _num(total_kwh.group(1)) if total_kwh else _num(meter.group(5))  # type: ignore[union-attr]
    return TibberInvoice(
        number=number.group(1).strip(),
        issued_on=_german_date(issued.group(1)),
        period_start=_german_date(period.group(1)),
        period_end=_german_date(period.group(2)),
        period_label=energy.group(1).strip(),
        kwh=kwh,
        meter_start=_num(meter.group(1)) if meter else None,
        meter_end=_num(meter.group(3)) if meter else None,
        meter_estimated=bool(meter and "errechnet" in (meter.group(2), meter.group(4))),
        positions=positions,
        fees=fees,
        energy_net_eur=_num(energy.group(2)),
        energy_gross_eur=_num(energy.group(3)),
        fees_net_eur=_num(fees_sum.group(1)),
        fees_gross_eur=_num(fees_sum.group(2)),
        total_net_eur=_num(grand.group(1)),
        total_gross_eur=_num(grand.group(2)),
        vat_eur=_num(vat.group(1))
        if vat
        else round(_num(grand.group(2)) - _num(grand.group(1)), 2),
        avg_ct_kwh=_num(avg.group(1)) if avg else 0.0,
        avg_ct_kwh_gross=_num(avg_gross.group(1)) if avg_gross else 0.0,
    )


# ---------------------------------------------------------------------- Prüfen
CENT = 0.01
SUM_TOL = 0.02  # gerundete Einzelposten summieren sich um wenige Cent auf


def _gross_tolerance(items: int) -> float:
    """Tibber rechnet die Mehrwertsteuer je Position und summiert danach.

    Der Bruttobetrag einer Summe weicht deshalb um bis zu einen halben Cent je Position vom Bruttowert der
    Nettosumme ab (Juni 2026: 86,05 € statt 86,06 €). Das ist Rundung, kein Rechenfehler."""
    return CENT + 0.005 * max(0, items)


def _ok(
    code: str, title: str, detail: str, expected: float, actual: float, unit: str
) -> InvoiceFinding:
    return InvoiceFinding(
        code=code,
        severity="ok",
        title_de=title,
        detail_de=detail,
        expected=round(expected, 4),
        actual=round(actual, 4),
        unit=unit,
    )


def _cmp(
    code: str,
    title: str,
    detail: str,
    expected: float,
    actual: float,
    tol: float,
    unit: str = "€",
    severity: Severity = "error",
) -> InvoiceFinding:
    """Erwartung gegen Rechnungswert; innerhalb der Toleranz ist der Befund „ok“."""
    good = abs(actual - expected) <= tol + 1e-9
    return InvoiceFinding(
        code=code,
        severity="ok" if good else severity,
        title_de=title,
        detail_de=detail,
        expected=round(expected, 4),
        actual=round(actual, 4),
        unit=unit,
    )


def _euro(v: float) -> str:
    return f"{v:.2f}".replace(".", ",") + " €"


def _price_tolerance(pos: InvoicePosition, kwh: float) -> float:
    """Der angegebene ct-Preis ist gerundet; daraus folgt die zulässige Abweichung des Betrags."""
    half_step = 0.5 * 10.0 ** (-pos.ct_decimals)
    return float(kwh * half_step / 100.0 + CENT)


def check_invoice(inv: TibberInvoice) -> list[InvoiceFinding]:
    """Rein rechnerische Prüfung der Rechnung – ohne eigene Messwerte."""
    out: list[InvoiceFinding] = []

    for pos in inv.positions:
        out.append(
            _cmp(
                f"position:{pos.label}",
                pos.label,
                f"{pos.ct_per_kwh} ct/kWh × {inv.kwh} kWh",
                pos.ct_per_kwh * inv.kwh / 100.0,
                pos.amount_eur,
                _price_tolerance(pos, inv.kwh),
            )
        )
    if inv.positions:
        out.append(
            _cmp(
                "positions_sum",
                "Summe der Verbrauchspositionen",
                "Alle Einzelposten zusammen müssen die Kosten für den Stromverbrauch ergeben.",
                sum(p.amount_eur for p in inv.positions),
                inv.energy_net_eur,
                SUM_TOL,
            )
        )
        out.append(
            _cmp(
                "positions_ct_sum",
                "Summe der Einzelpreise",
                "Die ct-Beträge der Einzelposten müssen den Durchschnittspreis ergeben.",
                sum(p.ct_per_kwh for p in inv.positions),
                inv.avg_ct_kwh,
                0.02,
                unit="ct/kWh",
            )
        )
    if inv.kwh > 0:
        out.append(
            _cmp(
                "avg_price",
                "Durchschnittspreis (netto)",
                f"{_euro(inv.energy_net_eur)} ÷ {inv.kwh} kWh",
                inv.energy_net_eur / inv.kwh * 100.0,
                inv.avg_ct_kwh,
                0.011,
                unit="ct/kWh",
            )
        )
    out.append(
        _cmp(
            "avg_price_gross",
            "Durchschnittspreis (brutto)",
            "Nettopreis zuzüglich 19 % Mehrwertsteuer.",
            inv.avg_ct_kwh * (1 + VAT_RATE),
            inv.avg_ct_kwh_gross,
            0.02,
            unit="ct/kWh",
        )
    )
    out.append(
        _cmp(
            "energy_gross",
            "Stromkosten brutto",
            "Nettobetrag zuzüglich 19 % Mehrwertsteuer.",
            inv.energy_net_eur * (1 + VAT_RATE),
            inv.energy_gross_eur,
            _gross_tolerance(len(inv.positions)),
        )
    )

    for fee in inv.fees:
        if fee.rate_eur is None or fee.days is None:
            continue
        if fee.per == "day":
            expected = fee.rate_eur * fee.days
        else:
            in_month = _days_in_month(inv.period_start)
            expected = fee.rate_eur * (fee.days / in_month if fee.days < in_month else 1.0)
        out.append(
            _cmp(
                f"fee:{fee.label}",
                fee.label,
                f"{_euro(fee.rate_eur)} je {'Tag' if fee.per == 'day' else 'Monat'} × {fee.days} Tage",
                expected,
                fee.amount_eur,
                CENT,
            )
        )
        out.append(
            _cmp(
                f"fee_days:{fee.label}",
                f"{fee.label}: berechnete Tage",
                f"Abrechnungszeitraum {inv.period_start:%d.%m.%Y} bis {inv.period_end:%d.%m.%Y}.",
                inv.days,
                fee.days,
                0,
                unit="Tage",
            )
        )
    if inv.fees:
        out.append(
            _cmp(
                "fees_sum",
                "Summe der Grundgebühren",
                "Tibber-Gebühr und Netznutzungsgebühr zusammen.",
                sum(f.amount_eur for f in inv.fees),
                inv.fees_net_eur,
                SUM_TOL,
            )
        )
    out.append(
        _cmp(
            "fees_gross",
            "Grundgebühr brutto",
            "Nettobetrag zuzüglich 19 % Mehrwertsteuer.",
            inv.fees_net_eur * (1 + VAT_RATE),
            inv.fees_gross_eur,
            _gross_tolerance(len(inv.fees)),
        )
    )
    out.append(
        _cmp(
            "total_net",
            "Gesamtbetrag netto",
            "Stromkosten plus Grundgebühr.",
            inv.energy_net_eur + inv.fees_net_eur,
            inv.total_net_eur,
            CENT,
        )
    )
    out.append(
        _cmp(
            "total_gross",
            "Gesamtbetrag brutto",
            "Nettobetrag zuzüglich 19 % Mehrwertsteuer.",
            inv.total_net_eur * (1 + VAT_RATE),
            inv.total_gross_eur,
            _gross_tolerance(len(inv.positions) + len(inv.fees)),
        )
    )
    out.append(
        _cmp(
            "vat",
            "Ausgewiesene Mehrwertsteuer",
            "Differenz zwischen Brutto- und Nettobetrag.",
            inv.total_gross_eur - inv.total_net_eur,
            inv.vat_eur,
            CENT,
        )
    )
    out.append(
        _cmp(
            "vat_rate",
            "Mehrwertsteuersatz",
            "Die ausgewiesene Steuer muss 19 % des Nettobetrags sein.",
            VAT_RATE * 100,
            inv.vat_eur / inv.total_net_eur * 100 if inv.total_net_eur else 0.0,
            0.1,
            unit="%",
        )
    )
    if inv.meter_start is not None and inv.meter_end is not None:
        out.append(
            _cmp(
                "meter_delta",
                "Zählerstandsdifferenz",
                f"{inv.meter_end:.2f} − {inv.meter_start:.2f} kWh",
                inv.meter_end - inv.meter_start,
                inv.kwh,
                0.02,
                unit="kWh",
            )
        )
    if inv.meter_estimated:
        out.append(
            InvoiceFinding(
                code="meter_estimated",
                severity="info",
                title_de="Zählerstände errechnet",
                detail_de=(
                    "Tibber weist die Zählerstände als errechnet aus, nicht als abgelesen. Der Verbrauch "
                    "beruht damit auf einer Schätzung des Netzbetreibers und wird später korrigiert."
                ),
            )
        )
    return out


def _days_in_month(day: date) -> int:
    nxt = date(day.year + (day.month == 12), (day.month % 12) + 1, 1)
    return (nxt - date(day.year, day.month, 1)).days


class MeasuredPeriod(BaseModel):
    """Was wir für den Abrechnungszeitraum selbst gemessen haben."""

    model_config = ConfigDict(frozen=True)

    import_kwh: float
    coverage: float | None = None  # Anteil bewerteter Minuten (0–1)
    avg_price_ct_kwh: float | None = None  # bezugsgewichteter Mittelwert der Tibber-Preise (brutto)


def compare_with_measurement(
    inv: TibberInvoice, measured: MeasuredPeriod, tolerance_pct: float = 5.0
) -> list[InvoiceFinding]:
    """Abgleich mit der eigenen Messung. Hinweise, keine harten Fehler: unser Netzwert ist eine CT-Messung."""
    out: list[InvoiceFinding] = []
    cov = measured.coverage
    if cov is not None and cov < 0.98:
        out.append(
            InvoiceFinding(
                code="coverage",
                severity="info",
                title_de="Eigene Messung unvollständig",
                detail_de=(
                    f"Für den Zeitraum liegen {cov * 100:.0f} % der Minuten vor. Der Mengenvergleich "
                    "wird entsprechend hochgerechnet und bleibt ein Näherungswert."
                ),
                expected=100.0,
                actual=round(cov * 100, 1),
                unit="%",
            )
        )
    # Unter der Hälfte wird nicht hochgerechnet – daraus ließe sich kein belastbarer Vergleich bilden.
    scaled = measured.import_kwh / cov if cov and cov >= 0.5 else measured.import_kwh
    if scaled > 0:
        deviation = abs(inv.kwh - scaled) / scaled * 100.0
        out.append(
            InvoiceFinding(
                code="measured_kwh",
                severity="ok" if deviation <= tolerance_pct else "warning",
                title_de="Abgerechnete Menge gegen eigene Messung",
                detail_de=(
                    f"Eigene Messung {scaled:.1f} kWh Netzbezug"
                    + (
                        f" (auf {cov * 100:.0f} % Abdeckung hochgerechnet)"
                        if cov and cov < 0.98
                        else ""
                    )
                    + f", Rechnung {inv.kwh:.2f} kWh – Abweichung {deviation:.1f} %."
                ),
                expected=round(scaled, 2),
                actual=inv.kwh,
                unit="kWh",
            )
        )
    if measured.avg_price_ct_kwh is not None and inv.avg_ct_kwh_gross > 0:
        delta = abs(inv.avg_ct_kwh_gross - measured.avg_price_ct_kwh)
        out.append(
            InvoiceFinding(
                code="measured_price",
                severity="ok" if delta <= 1.5 else "warning",
                title_de="Durchschnittspreis gegen eigene Preisreihe",
                detail_de=(
                    f"Aus den gespeicherten Tibber-Preisen und unserem Bezug ergeben sich "
                    f"{measured.avg_price_ct_kwh:.2f} ct/kWh, die Rechnung nennt "
                    f"{inv.avg_ct_kwh_gross:.2f} ct/kWh (brutto)."
                ),
                expected=round(measured.avg_price_ct_kwh, 2),
                actual=inv.avg_ct_kwh_gross,
                unit="ct/kWh",
            )
        )
    return out


def check_meter_chain(inv: TibberInvoice, previous: TibberInvoice | None) -> list[InvoiceFinding]:
    """Lückenlose Fortschreibung: der Endstand der Vorrechnung ist der Anfangsstand dieser Rechnung."""
    if previous is None or previous.meter_end is None or inv.meter_start is None:
        return []
    out = [
        _cmp(
            "meter_chain",
            "Anschluss an die Vorrechnung",
            f"Endstand {previous.period_label} ({previous.meter_end:.2f} kWh) gegen Anfangsstand dieser Rechnung.",
            previous.meter_end,
            inv.meter_start,
            0.02,
            unit="kWh",
        )
    ]
    gap = (inv.period_start - previous.period_end).days
    if gap != 1:
        out.append(
            InvoiceFinding(
                code="period_gap",
                severity="warning" if gap > 1 else "error",
                title_de="Lücke oder Überschneidung im Zeitraum",
                detail_de=(
                    f"Die Vorrechnung endet am {previous.period_end:%d.%m.%Y}, diese beginnt am "
                    f"{inv.period_start:%d.%m.%Y}."
                ),
                expected=1,
                actual=gap,
                unit="Tage",
            )
        )
    return out


def verdict(findings: list[InvoiceFinding]) -> Severity:
    """Schlechtester Befund bestimmt die Ampel."""
    order: tuple[Severity, ...] = ("error", "warning", "info")
    for level in order:
        if any(f.severity == level for f in findings):
            return level
    return "ok"


def parse_pdf(payload: bytes) -> TibberInvoice:
    """PDF einlesen und in ein Rechnungsmodell überführen."""
    import io

    from pypdf import PdfReader

    try:
        reader = PdfReader(io.BytesIO(payload))
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
    except InvoiceParseError:
        raise
    except Exception as exc:
        raise InvoiceParseError(f"PDF nicht lesbar: {exc.__class__.__name__}") from exc
    if not text.strip():
        raise InvoiceParseError("Das PDF enthält keinen Text (vermutlich ein Scan).")
    return parse_invoice(text)


def period_bounds_utc(inv: TibberInvoice, tz: ZoneInfo) -> tuple[datetime, datetime]:
    """Abrechnungszeitraum als UTC-Grenzen (lokale Mitternacht bis Mitternacht des Folgetags)."""
    start = datetime.combine(inv.period_start, datetime.min.time(), tzinfo=tz)
    end = datetime.combine(inv.period_end + timedelta(days=1), datetime.min.time(), tzinfo=tz)
    return start.astimezone(UTC), end.astimezone(UTC)
