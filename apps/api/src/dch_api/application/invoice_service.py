"""Rechnungsprüfung als Dienst: PDF entgegennehmen, prüfen, speichern, Verlauf ausgeben.

Die Rechnung selbst wird nicht abgelegt – nur die gelesenen Werte, die Befunde und eine Prüfsumme der Datei.
Der Zugang ist derselbe wie für das Dashboard (API-Token), damit eine Automatisierung wie OpenClaw eine neue
Rechnung aus dem Postfach direkt hochladen kann.
"""

from __future__ import annotations

import hashlib
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from zoneinfo import ZoneInfo

import structlog

from dch_api.application.tibber_invoice import (
    InvoiceFinding,
    MeasuredPeriod,
    TibberInvoice,
    check_invoice,
    check_meter_chain,
    compare_with_measurement,
    parse_pdf,
    period_bounds_utc,
    verdict,
)
from dch_api.schemas import InvoiceReportOut, InvoiceSummaryOut

log = structlog.get_logger("invoices")

# (number) → gespeicherter Bericht; die Ablage bestimmt der Betriebsmodus (SQL oder Speicher)
LoadAll = Callable[[], Awaitable[list[InvoiceReportOut]]]
Save = Callable[[InvoiceReportOut, str, str | None], Awaitable[None]]
Measure = Callable[[datetime, datetime], Awaitable[MeasuredPeriod]]


class InvoiceService:
    def __init__(self, tz: ZoneInfo, load_all: LoadAll, save: Save, measure: Measure) -> None:
        self.tz = tz
        self.load_all = load_all
        self.save = save
        self.measure = measure

    async def check(self, payload: bytes, file_name: str | None = None) -> InvoiceReportOut:
        """Rechnung prüfen und speichern. Dieselbe Rechnungsnummer ersetzt den bisherigen Bericht."""
        invoice = parse_pdf(payload)
        stored = await self.load_all()
        previous = _previous(invoice, stored)
        start, end = period_bounds_utc(invoice, self.tz)
        measured = await self.measure(start, end)
        findings = (
            check_invoice(invoice)
            + check_meter_chain(invoice, previous)
            + compare_with_measurement(invoice, measured)
        )
        report = InvoiceReportOut(
            invoice=invoice,
            findings=findings,
            verdict=verdict(findings),
            measured=measured,
            checked_at=datetime.now(UTC),
            file_name=file_name,
            already_known=any(s.invoice.number == invoice.number for s in stored),
        )
        await self.save(report, hashlib.sha256(payload).hexdigest(), file_name)
        log.info(
            "invoice checked",
            number=invoice.number,
            period=invoice.period_label,
            verdict=report.verdict,
            findings=len(findings),
            problems=sum(1 for f in findings if f.severity in ("error", "warning")),
        )
        return report

    async def history(self) -> list[InvoiceSummaryOut]:
        """Alle geprüften Rechnungen, neueste zuerst, mit dem gemessenen Vergleichswert."""
        reports = sorted(await self.load_all(), key=lambda r: r.invoice.period_start, reverse=True)
        return [
            InvoiceSummaryOut(
                number=r.invoice.number,
                period_label=r.invoice.period_label,
                period_start=r.invoice.period_start,
                period_end=r.invoice.period_end,
                issued_on=r.invoice.issued_on,
                kwh=r.invoice.kwh,
                measured_kwh=r.measured.import_kwh if r.measured else None,
                measured_avg_ct_kwh=r.measured.avg_price_ct_kwh if r.measured else None,
                coverage=r.measured.coverage if r.measured else None,
                total_net_eur=r.invoice.total_net_eur,
                total_gross_eur=r.invoice.total_gross_eur,
                avg_ct_kwh_gross=r.invoice.avg_ct_kwh_gross,
                energy_net_eur=r.invoice.energy_net_eur,
                fees_net_eur=r.invoice.fees_net_eur,
                verdict=r.verdict,
                problems=sum(1 for f in r.findings if f.severity in ("error", "warning")),
                checked_at=r.checked_at,
            )
            for r in reports
        ]

    async def detail(self, number: str) -> InvoiceReportOut | None:
        for r in await self.load_all():
            if r.invoice.number == number:
                return r
        return None


def _previous(invoice: TibberInvoice, stored: list[InvoiceReportOut]) -> TibberInvoice | None:
    """Die Rechnung, die zeitlich unmittelbar vor dieser liegt – Grundlage der Zählerstandskette."""
    earlier = [
        r.invoice
        for r in stored
        if r.invoice.period_end < invoice.period_start and r.invoice.number != invoice.number
    ]
    return max(earlier, key=lambda i: i.period_end) if earlier else None


def findings_json(findings: list[InvoiceFinding]) -> list[dict[str, object]]:
    return [f.model_dump(mode="json") for f in findings]
