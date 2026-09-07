"""Steuerliche Auswertung der PV-Anlage: Einspeisung, Eigenverbrauch, Umsatzsteuer.

Bei Regelbesteuerung sind drei Größen zu trennen, die im Alltag gern verschwimmen:

* Die **Einspeisung** wird mit dem Nettosatz aus dem Bescheid des Netzbetreibers vergütet; der
  Netzbetreiber zahlt zusätzlich die Umsatzsteuer aus. Sie ist durchlaufender Posten und wird mit der
  Voranmeldung wieder abgeführt.
* Der **Eigenverbrauch** ist eine unentgeltliche Wertabgabe. Bemessungsgrundlage ist nach § 10 Abs. 4
  UStG der Einkaufspreis im Zeitpunkt des Umsatzes - für Strom also das, was der Bezug derselben Menge
  aus dem Netz netto gekostet hätte. Bei einem Tarif mit stündlichem Preis ist das keine Pauschale,
  sondern die Summe über die Stunden.
* Der **Speicher** verschiebt beides zeitlich. Nur der PV-Anteil seiner Entladung ist Eigenverbrauch
  eigener Erzeugung; Strom, der aus dem Netz in den Speicher ging, wurde bereits als Bezug versteuert.

Diese Datei rechnet nur; sie kennt weder Datenbank noch HTTP. Die Zahlen ersetzen keine
Steuerberatung - sie bereiten die Beträge so auf, dass sie prüfbar sind.
"""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from hems_core.accounting.energy import EnergyTotals
from hems_core.domain.config import TariffConfig


class PvTaxTotals(BaseModel):
    """Geldseite der PV für einen Zeitraum. Beträge in EUR, Preise in ct/kWh."""

    model_config = ConfigDict(frozen=True)

    small_business: bool = False
    vat_rate: float = 0.19
    feed_in_ct_kwh: float = 0.0

    # Einspeisung
    export_kwh: float = 0.0
    export_net_eur: float = 0.0
    export_vat_eur: float = 0.0  # vom Netzbetreiber ausgezahlt, abzuführen
    export_gross_eur: float = 0.0

    # Eigenverbrauch (unentgeltliche Wertabgabe)
    self_consumption_kwh: float = 0.0
    self_direct_kwh: float = 0.0
    self_battery_kwh: float = 0.0
    self_value_net_eur: float = 0.0  # Wiederbeschaffungswert netto = Bemessungsgrundlage
    self_vat_eur: float = 0.0  # geschuldet
    self_ct_kwh: float | None = None  # mittlerer Netto-Bezugspreis des Eigenverbrauchs
    self_estimated_kwh: float = 0.0  # davon mit geschätzter Herkunft aus dem Speicher

    # Zusammenzug
    vat_payable_eur: float = 0.0  # Einspeise-USt + USt auf die Wertabgabe
    pv_kwh: float = 0.0
    self_consumption_share: float | None = None  # Eigenverbrauchsquote der Erzeugung


def _r(x: float) -> float:
    return round(x, 2)


def pv_tax(totals: EnergyTotals, tariff: TariffConfig) -> PvTaxTotals:
    vat = 0.0 if tariff.small_business else tariff.vat_rate
    export_net = totals.export_revenue_eur  # bereits Menge × Nettosatz
    export_vat = export_net * vat
    self_net = totals.self_consumption_value_eur
    self_vat = self_net * vat
    self_kwh = totals.self_consumption_kwh
    share = round(min(1.0, self_kwh / totals.pv_kwh), 4) if totals.pv_kwh > 1e-6 else None
    # Summen werden aus den gerundeten Teilbeträgen gebildet, nicht aus den exakten. Auf einer Seite,
    # von der Zahlen in eine Voranmeldung übernommen werden, muss die angezeigte Summe die angezeigten
    # Posten ergeben; ein halber Cent Genauigkeit ist das nicht wert.
    export_net_r = _r(export_net)
    export_vat_r = _r(export_vat)
    self_net_r = _r(self_net)
    self_vat_r = _r(self_vat)
    return PvTaxTotals(
        small_business=tariff.small_business,
        vat_rate=vat,
        feed_in_ct_kwh=tariff.feed_in_ct_kwh,
        export_kwh=round(totals.export_kwh, 3),
        export_net_eur=export_net_r,
        export_vat_eur=export_vat_r,
        export_gross_eur=_r(export_net_r + export_vat_r),
        self_consumption_kwh=round(self_kwh, 3),
        self_direct_kwh=round(totals.pv_direct_kwh, 3),
        self_battery_kwh=round(totals.battery_pv_to_house_kwh, 3),
        self_value_net_eur=self_net_r,
        self_vat_eur=self_vat_r,
        self_ct_kwh=totals.self_consumption_ct_kwh,
        self_estimated_kwh=round(totals.battery_origin_estimated_kwh, 3),
        vat_payable_eur=_r(export_vat_r + self_vat_r),
        pv_kwh=round(totals.pv_kwh, 3),
        self_consumption_share=share,
    )
