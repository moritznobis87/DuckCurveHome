"""Energiebilanz: Minutenwerte → Stundenenergien mit Quellen-Zuordnung und Kosten.

Reine Rechenlogik. Vorzeichen wie im Domänenmodell: grid > 0 Bezug, battery > 0 Entladen. Je Minute wird
der Hausverbrauch auf die Quellen PV direkt, Batterie und Netz verteilt; Verbraucher (Wärmepumpe, Wallbox)
erhalten diese Quellen anteilig an ihrer Leistung. Kosten: Netzbezug × Preis; PV- und Batterieanteile werden
mit der entgangenen Einspeisevergütung bewertet („Opportunität“).

Zusätzlich wird der steuerlich verwertbare Eigenverbrauch geführt: welcher Teil des Hausverbrauchs aus
eigener PV stammt (direkt oder über den Speicher) und was seine Wiederbeschaffung aus dem Netz netto
gekostet hätte. Der Speicher macht das nichttrivial, weil er auch Netzstrom aufnimmt; dafür läuft ein
Herkunftskonto (BatteryOrigin) über die Stunden hinweg mit.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from hems_core.domain.config import TariffConfig

STEP_H = 1.0 / 60.0


@dataclass(frozen=True)
class MinuteSample:
    ts: datetime
    pv_kw: float | None
    grid_kw: float | None
    battery_kw: float | None
    heat_pump_kw: float | None
    ev_kw: float | None
    price_ct_kwh: float | None


@dataclass
class BatteryOrigin:
    """Herkunftskonto des Speicherinhalts in kWh: wie viel davon ist PV, wie viel kam aus dem Netz.

    Ohne dieses Konto ließe sich eine Entladung nicht zuordnen - nachts fließt Strom aus dem Speicher,
    ohne dass in derselben Stunde geladen wurde. Es wird über die Stunden fortgeschrieben. Geladen wird
    anteilig gutgeschrieben, entladen anteilig abgebucht. Der Inhalt wird auf die Speicherkapazität
    begrenzt: Ladeverluste bedeuten, dass über die Zeit mehr hinein- als herausgeht, sonst wüchse das
    Konto unbegrenzt und die Anteile wären irgendwann von Jahren alten Ladungen bestimmt.
    """

    pv_kwh: float = 0.0
    grid_kwh: float = 0.0

    @property
    def content_kwh(self) -> float:
        return self.pv_kwh + self.grid_kwh

    def charge(self, pv_kwh: float, grid_kwh: float, capacity_kwh: float | None) -> None:
        self.pv_kwh += pv_kwh
        self.grid_kwh += grid_kwh
        content = self.content_kwh
        if capacity_kwh and content > capacity_kwh > 0.0:
            f = capacity_kwh / content
            self.pv_kwh *= f
            self.grid_kwh *= f

    def discharge(self, kwh: float) -> tuple[float, float, float]:
        """Entnahme aufteilen. Liefert (PV-Anteil, Netzanteil, geschätzter Anteil).

        Ist das Konto leer - beim ersten Start, oder wenn Ladeverluste es leergerechnet haben -, gilt die
        Entnahme als PV. Das ist die richtige Annahme für eine Anlage, die fast nur aus PV lädt, aber sie
        ist eine Annahme; ihr Umfang wird mitgezählt und auf der Abrechnungsseite ausgewiesen.
        """
        content = self.content_kwh
        take = min(kwh, content)
        if take > 1e-12:
            share = self.pv_kwh / content
            pv = take * share
            grid = take - pv
            self.pv_kwh -= pv
            self.grid_kwh -= grid
        else:
            pv = grid = 0.0
        rest = max(0.0, kwh - take)
        return pv + rest, grid, rest


class EnergyTotals(BaseModel):
    """Energien (kWh) und Geld (EUR) eines Zeitraums - Stunde, Tag, Woche, Monat oder Jahr."""

    model_config = ConfigDict(frozen=True)

    minutes: int = 0  # bewertete Minuten (Datenabdeckung)
    pv_kwh: float = 0.0
    import_kwh: float = 0.0
    export_kwh: float = 0.0
    battery_charge_kwh: float = 0.0
    battery_discharge_kwh: float = 0.0
    house_kwh: float = 0.0  # gesamter Verbrauch inkl. Wärmepumpe und Wallbox
    heat_pump_kwh: float = 0.0
    ev_kwh: float = 0.0
    base_kwh: float = 0.0  # Rest: Haus ohne Wärmepumpe und Wallbox
    # Herkunft des Hausverbrauchs
    pv_direct_kwh: float = 0.0
    battery_to_house_kwh: float = 0.0
    grid_to_house_kwh: float = 0.0
    pv_to_battery_kwh: float = 0.0
    grid_to_battery_kwh: float = 0.0
    # Herkunft der Speicherentladung ins Haus: nur der PV-Anteil ist Eigenverbrauch eigener Erzeugung,
    # der Netzanteil war beim Bezug bereits Netzstrom. battery_origin_estimated_kwh ist der Teil, dessen
    # Herkunft das Konto nicht kannte und der als PV angenommen wurde.
    battery_pv_to_house_kwh: float = 0.0
    battery_origin_estimated_kwh: float = 0.0
    # Verbraucher nach Herkunft
    heat_pump_pv_kwh: float = 0.0
    heat_pump_battery_kwh: float = 0.0
    heat_pump_grid_kwh: float = 0.0
    ev_pv_kwh: float = 0.0
    ev_battery_kwh: float = 0.0
    ev_grid_kwh: float = 0.0
    # Geld
    import_cost_eur: float = 0.0
    export_revenue_eur: float = 0.0
    heat_pump_cost_eur: float = 0.0  # Netzanteil × Preis (bezahlt)
    heat_pump_opportunity_eur: float = 0.0  # PV-/Batterieanteil × Einspeisevergütung (entgangen)
    ev_cost_eur: float = 0.0
    ev_opportunity_eur: float = 0.0
    battery_savings_eur: float = 0.0  # Entladung ins Haus × (Preis − Vergütung)
    pv_direct_savings_eur: float = 0.0  # PV direkt × (Preis − Vergütung)
    price_weighted_ct: float = 0.0  # Σ Bezug × Preis, für den Mittelpreis
    # Steuerliche Bewertung des Eigenverbrauchs: Σ selbst verbrauchte PV-kWh × Netto-Bezugspreis derselben
    # Minute (Wiederbeschaffungspreis). Netto, weil das die Bemessungsgrundlage der unentgeltlichen
    # Wertabgabe ist.
    self_consumption_value_eur: float = 0.0
    price_missing_minutes: int = 0

    @property
    def avg_import_price_ct(self) -> float | None:
        return (
            round(self.price_weighted_ct / self.import_kwh, 2) if self.import_kwh > 1e-6 else None
        )

    @property
    def self_consumption_kwh(self) -> float:
        """Eigenverbrauch eigener Erzeugung: PV direkt plus der PV-Anteil der Speicherentladung."""
        return round(self.pv_direct_kwh + self.battery_pv_to_house_kwh, 4)

    @property
    def self_consumption_ct_kwh(self) -> float | None:
        """Mittlerer Netto-Wiederbeschaffungspreis des Eigenverbrauchs in ct/kWh."""
        kwh = self.self_consumption_kwh
        return round(self.self_consumption_value_eur * 100.0 / kwh, 2) if kwh > 1e-6 else None

    @property
    def autarky(self) -> float | None:
        """Anteil des Hausverbrauchs, der nicht aus dem Netz kam."""
        if self.house_kwh <= 1e-6:
            return None
        return round(max(0.0, min(1.0, 1.0 - self.grid_to_house_kwh / self.house_kwh)), 4)

    @property
    def self_consumption_share(self) -> float | None:
        """Anteil der PV-Erzeugung, der im Haus blieb (direkt oder über die Batterie)."""
        if self.pv_kwh <= 1e-6:
            return None
        return round(max(0.0, min(1.0, 1.0 - self.export_kwh / self.pv_kwh)), 4)


class HourlyEnergy(EnergyTotals):
    model_config = ConfigDict(frozen=True)

    hour_start: datetime
    # Stand des Herkunftskontos am Ende der Stunde. Gehört bewusst nicht zu EnergyTotals: ein Bestand
    # darf über Stunden nicht aufsummiert werden. Gespeichert wird er, damit eine Neuberechnung dort
    # weiterrechnen kann, wo die vorige aufgehört hat, statt das Konto wieder bei null zu beginnen.
    battery_pv_stored_kwh: float = 0.0
    battery_grid_stored_kwh: float = 0.0


_SUM_FIELDS = [
    f for f in EnergyTotals.model_fields if f not in ("minutes", "price_missing_minutes")
]


def _r(x: float) -> float:
    return round(x, 4)


def hourly_energy(
    hour_start: datetime,
    samples: Iterable[MinuteSample],
    tariff: TariffConfig,
    origin: BatteryOrigin | None = None,
    capacity_kwh: float | None = None,
) -> HourlyEnergy:
    """Eine Stunde bilanzieren.

    `origin` ist der Stand des Speicher-Herkunftskontos zu Beginn der Stunde; es wird dabei verändert und
    steht danach für die Folgestunde bereit. Ohne Angabe beginnt die Rechnung mit einem leeren Konto -
    dann gilt jede Entladung als PV und wird als geschätzt gezählt.
    """
    acc: dict[str, float] = dict.fromkeys(_SUM_FIELDS, 0.0)
    minutes = 0
    price_missing = 0
    feed_in = tariff.feed_in_ct_kwh
    vat = 0.0 if tariff.small_business else tariff.vat_rate
    net_factor = 1.0 / (1.0 + vat) if tariff.price_includes_vat else 1.0
    bat_origin = origin if origin is not None else BatteryOrigin()
    for smp in samples:
        if smp.pv_kw is None or smp.grid_kw is None:
            continue  # ohne PV und Netz keine Bilanz
        pv = max(0.0, smp.pv_kw)
        grid = smp.grid_kw
        bat = smp.battery_kw or 0.0
        hp = max(0.0, smp.heat_pump_kw or 0.0)
        ev = max(0.0, smp.ev_kw or 0.0)
        price = smp.price_ct_kwh
        if price is None:
            price = tariff.fallback_import_ct_kwh
            price_missing += 1
        minutes += 1

        imp = max(0.0, grid)
        exp = max(0.0, -grid)
        dis = max(0.0, bat)
        chg = max(0.0, -bat)
        house = max(0.0, pv + grid + bat)
        hp = min(hp, house)
        ev = min(ev, house - hp)
        base = max(0.0, house - hp - ev)

        pv_direct = min(pv, house)
        pv_rest = pv - pv_direct
        pv_to_bat = min(pv_rest, chg)
        grid_to_bat = max(0.0, chg - pv_to_bat)
        bat_to_house = min(dis, max(0.0, house - pv_direct))
        grid_to_house = max(0.0, house - pv_direct - bat_to_house)

        share = (1.0 / house) if house > 1e-9 else 0.0
        spread = max(0.0, price - feed_in)

        acc["pv_kwh"] += pv * STEP_H
        acc["import_kwh"] += imp * STEP_H
        acc["export_kwh"] += exp * STEP_H
        acc["battery_charge_kwh"] += chg * STEP_H
        acc["battery_discharge_kwh"] += dis * STEP_H
        acc["house_kwh"] += house * STEP_H
        acc["heat_pump_kwh"] += hp * STEP_H
        acc["ev_kwh"] += ev * STEP_H
        acc["base_kwh"] += base * STEP_H
        acc["pv_direct_kwh"] += pv_direct * STEP_H
        acc["battery_to_house_kwh"] += bat_to_house * STEP_H
        acc["grid_to_house_kwh"] += grid_to_house * STEP_H
        acc["pv_to_battery_kwh"] += pv_to_bat * STEP_H
        acc["grid_to_battery_kwh"] += grid_to_bat * STEP_H

        # Herkunftskonto fortschreiben. Entnommen wird die gesamte Entladung, gutgeschrieben als
        # Eigenverbrauch nur der Teil, der ins Haus ging - was aus dem Speicher ins Netz fließt, ist
        # Einspeisung und über export_kwh bereits erfasst.
        bat_origin.charge(pv_to_bat * STEP_H, grid_to_bat * STEP_H, capacity_kwh)
        bat_pv_house = 0.0
        if dis > 1e-9:
            pv_out, _grid_out, guessed = bat_origin.discharge(dis * STEP_H)
            house_share = (bat_to_house / dis) if dis > 1e-9 else 0.0
            bat_pv_house = pv_out * house_share
            acc["battery_pv_to_house_kwh"] += bat_pv_house
            acc["battery_origin_estimated_kwh"] += guessed * house_share
        acc["self_consumption_value_eur"] += (
            (pv_direct * STEP_H + bat_pv_house) * price * net_factor / 100.0
        )
        for name, load in (("heat_pump", hp), ("ev", ev)):
            f = load * share
            l_pv = f * pv_direct * STEP_H
            l_bat = f * bat_to_house * STEP_H
            l_grid = f * grid_to_house * STEP_H
            acc[f"{name}_pv_kwh"] += l_pv
            acc[f"{name}_battery_kwh"] += l_bat
            acc[f"{name}_grid_kwh"] += l_grid
            acc[f"{name}_cost_eur"] += l_grid * price / 100.0
            acc[f"{name}_opportunity_eur"] += (l_pv + l_bat) * feed_in / 100.0
        acc["import_cost_eur"] += imp * STEP_H * price / 100.0
        acc["export_revenue_eur"] += exp * STEP_H * feed_in / 100.0
        acc["battery_savings_eur"] += bat_to_house * STEP_H * spread / 100.0
        acc["pv_direct_savings_eur"] += pv_direct * STEP_H * spread / 100.0
        acc["price_weighted_ct"] += imp * STEP_H * price

    return HourlyEnergy(
        hour_start=hour_start,
        minutes=minutes,
        price_missing_minutes=price_missing,
        battery_pv_stored_kwh=_r(bat_origin.pv_kwh),
        battery_grid_stored_kwh=_r(bat_origin.grid_kwh),
        **{k: _r(v) for k, v in acc.items()},
    )


def summarize(parts: Iterable[EnergyTotals]) -> EnergyTotals:
    acc: dict[str, float] = dict.fromkeys(_SUM_FIELDS, 0.0)
    minutes = 0
    missing = 0
    for p in parts:
        minutes += p.minutes
        missing += p.price_missing_minutes
        for k in _SUM_FIELDS:
            acc[k] += getattr(p, k)
    return EnergyTotals(
        minutes=minutes, price_missing_minutes=missing, **{k: _r(v) for k, v in acc.items()}
    )


def samples_from_rows(
    rows: Iterable[dict[str, float | str | None]],
) -> list[MinuteSample]:
    """Minutenzeilen der Historie (Schlüssel wie in der 1-min-Serie) in Stichproben wandeln."""
    out: list[MinuteSample] = []
    for row in rows:
        ts_raw = row.get("ts")
        if not isinstance(ts_raw, str):
            continue
        ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))

        def num(key: str, r: dict[str, float | str | None] = row) -> float | None:
            v = r.get(key)
            return float(v) if isinstance(v, int | float) else None

        out.append(
            MinuteSample(
                ts=ts,
                pv_kw=num("pv_power_kw"),
                grid_kw=num("grid_power_kw"),
                battery_kw=num("battery_power_kw"),
                heat_pump_kw=num("heat_pump_power_kw"),
                ev_kw=num("ev_power_kw"),
                price_ct_kwh=num("electricity_price_ct_kwh"),
            )
        )
    return out
