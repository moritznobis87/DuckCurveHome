"""Tibber-Rechnungen: Parsen, Rechenprüfung, Zählerstandskette, Abgleich mit der eigenen Messung.

Die Vorlage bildet den Aufbau echter Rechnungen nach; Name, Anschrift und Kennnummern sind erfunden.
"""

from __future__ import annotations

from datetime import date

import pytest

from dch_api.application.tibber_invoice import (
    InvoiceParseError,
    MeasuredPeriod,
    check_invoice,
    check_meter_chain,
    compare_with_measurement,
    parse_invoice,
    verdict,
)

# Positionen einer Monatsrechnung: (Bezeichnung, Gruppe, ct/kWh)
POSITIONS = [
    ("Strom-Börsenpreis", "Stromeinkauf", "13,20"),
    ("Weitere Beschaffungskosten (s. §4 AGB)", "Stromeinkauf", "1,81"),
    ("Netznutzungsentgelt (variabel)", "Netz", "7,17"),
    ("Konzessionsabgabe", "Steuern, Abgaben & Umlagen", "1,59"),
    ("Stromsteuer", "Steuern, Abgaben & Umlagen", "2,05"),
    ("Offshore Wind Umlage", "Steuern, Abgaben & Umlagen", "0,941"),
    ("KWK Umlage", "Steuern, Abgaben & Umlagen", "0,446"),
    ("Strom NEV Umlage", "Steuern, Abgaben & Umlagen", "1,56"),
]
DE = lambda v, n=2: f"{v:,.{n}f}".replace(",", "@").replace(".", ",").replace("@", ".")  # noqa: E731


def build_invoice(
    number: str = "5085697",
    month: str = "Juni 2026",
    issued: str = "6. Juli 2026",
    start: str = "1. Juni 2026",
    end: str = "30. Juni 2026",
    kwh: float = 251.40,
    meter_start: float = 60264.50,
    days: int = 30,
    tibber_fee: float = 3.35,
    grid_fee_per_day: float = 0.21,
    amounts: dict[str, float] | None = None,
    energy_net: float | None = None,
    total_net: float | None = None,
    total_gross: float | None = None,
    estimated: bool = True,
) -> str:
    """Rechnungstext wie ihn pypdf aus dem Tibber-PDF liefert."""
    pos_amounts = {
        label: round(float(ct.replace(",", ".")) * kwh / 100.0, 2) for label, _g, ct in POSITIONS
    }
    pos_amounts.update(amounts or {})
    energy = energy_net if energy_net is not None else round(sum(pos_amounts.values()), 2)
    grid_fee = round(grid_fee_per_day * days, 2)
    fees = round(tibber_fee + grid_fee, 2)
    net = total_net if total_net is not None else round(energy + fees, 2)
    gross = total_gross if total_gross is not None else round(net * 1.19, 2)
    avg = round(energy / kwh * 100, 2)
    mark = "errechnet" if estimated else "abgelesen"
    lines = [
        "Rechnung - Übersicht",
        f"Rechnungsdatum: {issued}",
        f"Rechnungsnummer: {number}",
        "Marktlokations-ID: 50000000000",
        "Zählernummer: 1TEST000000000",
        "Erika Musterfrau",
        "Beispielweg 1",
        "12345 Musterstadt",
        "Netto Brutto",
        f"Kosten Stromverbrauch für {month} {DE(energy)} € {DE(round(energy * 1.19, 2))} €",
        f"{DE(kwh)} kWh mit einem Durchschnittspreis von {DE(round(avg * 1.19, 2))} ct/kWh (brutto)",
        f"Kosten Grundgebühr für {month} {DE(fees)} € {DE(round(fees * 1.19, 2))} €",
        f"Gesamtbetrag {DE(net)} € {DE(gross)} €",
        f"Davon MwSt 19% {DE(round(gross - net, 2))} €",
        "Kosten",
    ]
    group = ""
    for label, grp, ct in POSITIONS:
        if grp != group:
            lines.append(grp)
            group = grp
        lines.append(f"{label} {ct} ct/kWh {DE(pos_amounts[label])} €")
    lines += [
        f"Durchschnittspreis {DE(avg)} ct/kWh",
        f"Durchschnittspreis (brutto) {DE(round(avg * 1.19, 2))} ct/kWh",
        "Zwischensumme",
        f"{DE(energy)} €",
        "Kosten Grundgebühr",
        f"Tibber Gebühr für {month} {DE(tibber_fee)} €",
        f"{DE(tibber_fee)} €/Monat - Betrag hier für {days} Tage",
        f"Netznutzungsgebühr für {month} {DE(grid_fee)} €",
        f"{DE(grid_fee_per_day, 4)} €/Tag - Betrag hier für {days} Tage",
        "Verbrauch",
        "Abrechnungszeitraum Ab Zählerstand Bis Zählerstand Verbrauch",
        f"{start} - {end} {DE(meter_start)} ({mark}) {DE(round(meter_start + kwh, 2))} ({mark}) {DE(kwh)} kWh",
        f"Stromverbrauch für ganze Periode {DE(kwh)} kWh",
    ]
    return "\n".join(lines)


def test_parses_all_fields() -> None:
    inv = parse_invoice(build_invoice())
    assert inv.number == "5085697"
    assert inv.issued_on == date(2026, 7, 6)
    assert (inv.period_start, inv.period_end, inv.days) == (date(2026, 6, 1), date(2026, 6, 30), 30)
    assert inv.period_label == "Juni 2026"
    assert inv.kwh == pytest.approx(251.40)
    assert inv.meter_start == pytest.approx(60264.50) and inv.meter_end == pytest.approx(60515.90)
    assert inv.meter_estimated is True
    assert len(inv.positions) == 8 and len(inv.fees) == 2
    assert inv.positions[0].label == "Strom-Börsenpreis"
    assert inv.positions[0].group == "Stromeinkauf" and inv.positions[0].ct_decimals == 2
    assert inv.positions[5].ct_decimals == 3  # 0,941 ct/kWh
    assert inv.fees[0].per == "month" and inv.fees[1].per == "day" and inv.fees[1].days == 30
    assert inv.total_net_eur == pytest.approx(81.97) and inv.total_gross_eur == pytest.approx(97.54)


def test_clean_invoice_has_no_complaints() -> None:
    findings = check_invoice(parse_invoice(build_invoice()))
    bad = [f for f in findings if f.severity in ("error", "warning")]
    assert bad == [], [f.title_de for f in bad]
    assert verdict(findings) == "info"  # nur der Hinweis auf errechnete Zählerstände
    assert verdict([f for f in findings if f.code != "meter_estimated"]) == "ok"


def test_per_position_vat_rounding_is_tolerated() -> None:
    """Tibber rundet die Steuer je Position: 86,05 € statt 86,06 € ist kein Fehler."""
    text = build_invoice().replace(
        "Kosten Stromverbrauch für Juni 2026 72,32 € 86,06 €",
        "Kosten Stromverbrauch für Juni 2026 72,32 € 86,05 €",
    )
    findings = {f.code: f for f in check_invoice(parse_invoice(text))}
    assert findings["energy_gross"].severity == "ok"


def test_wrong_position_amount_is_found() -> None:
    """Ein Posten ist zu hoch, die Zwischensumme bleibt stehen – beides muss auffallen."""
    inv = parse_invoice(build_invoice(amounts={"Stromsteuer": 15.15}, energy_net=72.32))
    findings = {f.code: f for f in check_invoice(inv)}
    assert findings["position:Stromsteuer"].severity == "error"
    assert findings["position:Stromsteuer"].expected == pytest.approx(5.15, abs=0.01)
    assert findings["positions_sum"].severity == "error"
    assert verdict(list(findings.values())) == "error"

    # dieselbe Erhöhung, aber konsequent bis zur Summe durchgerechnet: die Position bleibt auffällig
    consistent = {
        c.code: c
        for c in check_invoice(parse_invoice(build_invoice(amounts={"Stromsteuer": 15.15})))
    }
    assert consistent["position:Stromsteuer"].severity == "error"
    assert consistent["avg_price"].severity == "ok"  # Durchschnitt passt zur erhöhten Summe
    assert consistent["positions_ct_sum"].severity == "error"  # ct-Preise ergeben ihn aber nicht


def test_wrong_total_and_vat_are_found() -> None:
    f = {c.code: c for c in check_invoice(parse_invoice(build_invoice(total_net=91.97)))}
    assert f["total_net"].severity == "error" and f["total_net"].delta == pytest.approx(10.0)
    g = {c.code: c for c in check_invoice(parse_invoice(build_invoice(total_gross=99.54)))}
    assert g["total_gross"].severity == "error" and g["vat_rate"].severity == "error"


def test_wrong_fee_days_are_found() -> None:
    """31 Tage Grundgebühr für einen 30-tägigen Monat."""
    text = build_invoice(days=31)
    f = {c.code: c for c in check_invoice(parse_invoice(text))}
    assert f["fee_days:Netznutzungsgebühr"].severity == "error"
    assert (
        f["fee_days:Netznutzungsgebühr"].actual == 31
        and f["fee_days:Netznutzungsgebühr"].expected == 30
    )


def test_meter_chain_and_gap() -> None:
    may = parse_invoice(
        build_invoice(
            number="4957137",
            month="Mai 2026",
            issued="4. Juni 2026",
            start="1. Mai 2026",
            end="31. Mai 2026",
            kwh=305.05,
            meter_start=59959.45,
            days=31,
        )
    )
    june = parse_invoice(build_invoice())
    assert june.meter_start == pytest.approx(may.meter_end)
    chain = {f.code: f for f in check_meter_chain(june, may)}
    assert chain["meter_chain"].severity == "ok" and "period_gap" not in chain
    # eine Rechnung, die erst zwei Tage später beginnt und an einem anderen Stand ansetzt
    july = parse_invoice(
        build_invoice(
            number="5231104",
            month="Juli 2026",
            issued="4. Aug. 2026",
            start="3. Juli 2026",
            end="31. Juli 2026",
            kwh=366.17,
            meter_start=60600.00,
            days=29,
        )
    )
    bad = {f.code: f for f in check_meter_chain(july, june)}
    assert bad["meter_chain"].severity == "error"
    assert bad["meter_chain"].expected == pytest.approx(60515.90)
    assert bad["period_gap"].severity == "warning" and bad["period_gap"].actual == 3


def test_comparison_with_own_measurement() -> None:
    inv = parse_invoice(build_invoice())
    close = {f.code: f for f in compare_with_measurement(inv, MeasuredPeriod(import_kwh=248.0))}
    assert close["measured_kwh"].severity == "ok"
    far = {f.code: f for f in compare_with_measurement(inv, MeasuredPeriod(import_kwh=180.0))}
    assert far["measured_kwh"].severity == "warning"
    # unvollständige Abdeckung wird hochgerechnet und als Hinweis ausgewiesen
    partial = {
        f.code: f
        for f in compare_with_measurement(inv, MeasuredPeriod(import_kwh=124.0, coverage=0.5))
    }
    assert partial["coverage"].severity == "info"
    assert partial["measured_kwh"].expected == pytest.approx(248.0)
    priced = {
        f.code: f
        for f in compare_with_measurement(
            inv, MeasuredPeriod(import_kwh=250.0, avg_price_ct_kwh=39.0)
        )
    }
    assert priced["measured_price"].severity == "warning"  # 34,23 gegen 39,00 ct/kWh


def test_foreign_pdf_text_is_rejected() -> None:
    with pytest.raises(InvoiceParseError):
        parse_invoice("Rechnung der Stadtwerke\nBetrag 100 €")
