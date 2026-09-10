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
from dataclasses import dataclass, replace
from datetime import datetime, timedelta

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
    # Anteil der Speicherladung, den der PV-Überschuss über ein kurzes zentriertes Fenster deckt
    # (0..1), gesetzt von `with_charge_window`. Nur die Zuordnung der Ladung greift darauf zu; ist
    # er None, gilt die Minute für sich allein.
    pv_charge_share: float | None = None


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
    # Davon Minuten, deren Eingang gröber war als eine Minute (Stundenmittel aus einem
    # Historienexport). Die Summen stimmen dort, die Aufteilung auf Quellen ist geschätzt -
    # siehe hourly_energy. Ohne diese Zahl mischt eine Jahresansicht zwei Rechnungsarten,
    # ohne dass man es ihr ansieht.
    coarse_minutes: int = 0
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
    # Netzladung in Minuten ohne jede PV-Leistung. Die Unterscheidung trennt zwei sehr verschiedene
    # Ursachen: bei Dunkelheit lädt der Speicher wirklich aus dem Netz, das ist eine Einstellung
    # oder eine Entscheidung des Geräts. Bei Sonne ist es meist ein Messartefakt - PV, Netz und
    # Batterie kommen aus drei Quellen mit eigenen Abtastzeitpunkten, und in einer Minute mit
    # ziehender Wolke passen die drei Werte nicht exakt zusammen.
    grid_to_battery_dark_kwh: float = 0.0
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
    f
    for f in EnergyTotals.model_fields
    if f not in ("minutes", "coarse_minutes", "price_missing_minutes")
]


def _r(x: float) -> float:
    return round(x, 4)


# Felder, die zwischen zwei Messwerten weitergelten. Ein Preis gilt ohnehin stundenweise, eine
# Leistung bis zur nächsten Meldung.
_HOLD_FIELDS = ("pv_kw", "grid_kw", "battery_kw", "heat_pump_kw", "ev_kw", "price_ct_kwh")

# So lange gilt ein Messwert weiter, wenn kein neuer kommt. Fünf Minuten, weil myenergi-Geräte im
# Leerlauf in diesem Takt melden; länger wäre keine Lücke mehr, sondern ein Ausfall, und den soll
# die Bilanz nicht zuschütten.
MAX_HOLD_MIN = 5

# Ab dieser Eingangsauflösung ist die Zuordnung innerhalb der Stunde nicht mehr messbar, sondern
# eine Annahme. Fünf Minuten, weil die Geräte hier in diesem Takt melden; ein Stundenmittel liegt
# weit darüber.
COARSE_RESOLUTION_MIN = 5


def fill_gaps(
    samples: Iterable[MinuteSample], max_hold_min: int = MAX_HOLD_MIN
) -> list[MinuteSample]:
    """Minutenreihe auf ein lückenloses Raster bringen: jeder Messwert gilt bis zum nächsten.

    **Warum das sein muss.** Die Bilanz zählt je Minutenzeile Leistung × 1/60 h. Eine Minute ohne
    Zeile trägt damit nichts bei - sie zählt als null Energie, nicht als „unbekannt". Das ist genau
    dann falsch, wenn eine Quelle nur meldet, wenn sich etwas ändert oder wenn sie es für nötig
    hält: die myenergi-Geräte tragen den Zeitstempel ihres eigenen letzten Berichts, und im
    Leerlauf berichten sie im Minutenabstand oder seltener. Nachts, wenn der Speicher mit
    gleichmäßigen 0,35 kW das Haus trägt, fehlen dann zwei von drei Minuten - und die Entladung
    schrumpft auf ein Drittel, ohne dass irgendwo ein Fehler auftaucht.

    Ein Messwert gilt deshalb weiter, bis ein neuer kommt, höchstens aber `max_hold_min` Minuten.
    Danach ist es keine Lücke mehr, sondern ein Ausfall, und die Minute bleibt leer.

    **Eine Null altert nicht.** Die Fünf-Minuten-Grenze gilt für Werte, die sich ändern können.
    Nachts meldet die PV-Seite nichts mehr, weil sich an ihrer Null nichts ändert - und weil die
    Bilanz eine Minute ohne PV-Wert verwirft, nahm sie die Entladung des Speichers gleich mit. Der
    erste Anlauf dieser Funktion hat das nicht behoben: fünf Minuten reichen für einen Takt, nicht
    für eine ganze Nacht. Eine zuletzt gemessene Null gilt deshalb unbegrenzt weiter. Das erfindet
    keine Energie - null mal irgendetwas bleibt null -, es verhindert nur, dass die Null die
    Nachbarwerte mit in den Papierkorb zieht.

    **Zwei Grenzen, die bewusst nicht überschritten werden.** Über den letzten Messwert hinaus wird
    nicht fortgeschrieben: in der laufenden Stunde wäre das erfundene Energie, die es noch nicht
    gibt. Und eine Minute entsteht nur, wenn mindestens ein Feld einen frischen oder eben erst
    gehaltenen Wert hat - sonst zählte ein Ausfall als lückenlos abgedeckt, nur weil irgendwann
    einmal eine Null gemessen wurde.
    """
    rows = sorted(samples, key=lambda s: s.ts)
    if not rows:
        return []
    by_minute = {s.ts.replace(second=0, microsecond=0): s for s in rows}
    out: list[MinuteSample] = []
    held: dict[str, tuple[float, datetime]] = {}
    hold = timedelta(minutes=max_hold_min)
    t, stop = min(by_minute), max(by_minute)
    while t <= stop:
        cur = by_minute.get(t)
        values: dict[str, float | None] = {}
        recent = False
        for field in _HOLD_FIELDS:
            v = getattr(cur, field) if cur is not None else None
            if v is not None:
                held[field] = (v, t)
                recent = True
            else:
                prev = held.get(field)
                if prev is None:
                    v = None
                elif t - prev[1] <= hold:
                    v = prev[0]
                    recent = True
                else:
                    v = prev[0] if prev[0] == 0.0 else None
            values[field] = v
        if not recent:  # niemand hat sich gemeldet: das ist ein Ausfall, keine Lücke
            t += timedelta(minutes=1)
            continue
        out.append(MinuteSample(ts=t, **values))
        t += timedelta(minutes=1)
    return out


# Halbe Breite des Fensters, gegen das die Speicherladung geprüft wird: ±2 min, also fünf Minuten.
# Kurz genug, dass es die Stundenmittel-Verzerrung nicht wieder einführt, lang genug für den
# Zeitversatz zwischen drei Geräten.
CHARGE_WINDOW_MIN = 2


def with_charge_window(
    samples: Iterable[MinuteSample], half_width_min: int = CHARGE_WINDOW_MIN
) -> list[MinuteSample]:
    """Je Minute festhalten, welchen Anteil der Ladung die PV eines kurzen Fensters deckt.

    Die Zuordnung fragt „wie viel PV stand der Ladung gegenüber?" und vergleicht dafür zwei Größen,
    die aus **zwei verschiedenen Geräten** kommen: die Erzeugung von den Generation-CTs, die Ladung
    vom Libbi. Die myenergi-Zuordnung gibt jedem seinen eigenen Zeitstempel (`gen_at` und die Zeit
    des Libbi). An einer Wolkenkante hinkt der eine dem anderen um eine Minute nach, und in dieser
    Minute sieht es aus, als habe der Speicher ohne Sonne geladen.

    Deshalb wird im Fenster von ±`half_width_min` Minuten der **Anteil** gebildet - wie viel der
    dort geladenen Energie die dortige Erzeugung deckt - und dieser Anteil auf die Minute angewandt.
    Der Anteil, nicht die geglättete Erzeugung selbst: eine Minutenladung gegen ein Fenstermittel zu
    halten vergleicht Ungleiches und verschiebt den Fehler nur, statt ihn aufzuheben.

    Nachts ist die Erzeugung null, der Anteil damit null, und Netzladung bleibt dem Netz
    zugeschrieben. Reicht die Erzeugung nicht für die Ladeleistung, bleibt die Differenz ebenfalls
    stehen. Nur das kurze Zappeln verschwindet.
    """
    rows = sorted(samples, key=lambda s: s.ts)
    n = len(rows)
    if n == 0:
        return []
    # Dieselbe Bedingung wie in `hourly_energy`: ohne PV und Netz wird die Minute nicht bilanziert,
    # also darf sie auch das Fenster nicht mitbestimmen.
    ok = [r.pv_kw is not None and r.grid_kw is not None for r in rows]
    charge = [max(0.0, -(r.battery_kw or 0.0)) if v else 0.0 for r, v in zip(rows, ok, strict=True)]
    gen = [max(0.0, r.pv_kw or 0.0) if v else 0.0 for r, v in zip(rows, ok, strict=True)]
    out: list[MinuteSample] = []
    for i, cur in enumerate(rows):
        lo, hi = max(0, i - half_width_min), min(n, i + half_width_min + 1)
        chg_sum = sum(charge[lo:hi])
        if chg_sum <= 1e-9:
            out.append(cur)
            continue
        share = min(1.0, sum(gen[lo:hi]) / chg_sum)
        out.append(replace(cur, pv_charge_share=share))
    return out


def hourly_energy(
    hour_start: datetime,
    samples: Iterable[MinuteSample],
    tariff: TariffConfig,
    origin: BatteryOrigin | None = None,
    capacity_kwh: float | None = None,
    resolution_min: int = 1,
) -> HourlyEnergy:
    """Eine Stunde bilanzieren.

    `origin` ist der Stand des Speicher-Herkunftskontos zu Beginn der Stunde; es wird dabei verändert und
    steht danach für die Folgestunde bereit. Ohne Angabe beginnt die Rechnung mit einem leeren Konto -
    dann gilt jede Entladung als PV und wird als geschätzt gezählt.

    **Die Rangfolge: der Speicher bekommt die PV zuerst.** Gab es in einer Minute mindestens so
    viel Erzeugung wie Ladeleistung, gilt die Ladung vollständig als Sonnenstrom - auch dann, wenn
    der Zähler gleichzeitig Bezug meldet, weil das Haus mehr wollte, als übrig war. Der Bezug ist
    dann Bezug **des Hauses**, nicht des Speichers.

    Das ist eine Konvention und keine Messung; die Physik kennt keine Etiketten auf Elektronen. Die
    umgekehrte Rangfolge (Haus zuerst, Speicher aus dem Rest) ist ebenso vertretbar und war hier
    zuerst eingebaut. Gegen sie spricht, was sie anrichtet: springt an einem sonnigen Morgen die
    Wärmepumpe an, während der Speicher aus der PV lädt, schrieb sie dem Speicher Netzladung zu, die
    er nie gesehen hat. Wer dann „Netzladung" liest, sucht den Fehler beim Speicher - dabei liegt er
    beim Verbrauch, der zur falschen Zeit lief. Diese Rangfolge legt ihn dorthin, wo er hingehört.

    Der Preis dafür steht in derselben Rechnung: der direkte PV-Anteil am Hausverbrauch fällt
    kleiner aus, der Netzanteil größer, und damit sinkt die ausgewiesene Autarkie. Die PV-Menge
    selbst verschiebt sich nur, sie verschwindet nicht - was nicht direkt ins Haus geht, liegt im
    Speicher und kommt später heraus.

    `resolution_min` ist die Auflösung der Eingangsdaten. Sie ändert an der Rangfolge nichts mehr,
    zählt aber die betroffenen Minuten in `coarse_minutes`, damit eine Jahresansicht nicht
    verschweigt, dass ein Teil ihrer Zahlen aus Stundenmitteln stammt.
    """
    acc: dict[str, float] = dict.fromkeys(_SUM_FIELDS, 0.0)
    minutes = 0
    price_missing = 0
    feed_in = tariff.feed_in_ct_kwh
    vat = 0.0 if tariff.small_business else tariff.vat_rate
    net_factor = 1.0 / (1.0 + vat) if tariff.price_includes_vat else 1.0
    bat_origin = origin if origin is not None else BatteryOrigin()
    coarse = resolution_min > COARSE_RESOLUTION_MIN
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

        # Rangfolge: die Ladung des Speichers bekommt die PV zuerst, der Hausverbrauch den Rest.
        # `pv_charge_share` prüft die Ladung dabei gegen ein kurzes Fenster statt gegen die einzelne
        # Minute (siehe `with_charge_window`); ohne Fenster gilt die Minute für sich.
        share = (
            smp.pv_charge_share
            if smp.pv_charge_share is not None
            else (min(1.0, pv / chg) if chg > 1e-9 else 0.0)
        )
        pv_to_bat = share * chg
        pv_direct = min(max(0.0, pv - pv_to_bat), house)
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
        if pv < 0.05:
            acc["grid_to_battery_dark_kwh"] += grid_to_bat * STEP_H

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
        coarse_minutes=minutes if coarse else 0,
        price_missing_minutes=price_missing,
        battery_pv_stored_kwh=_r(bat_origin.pv_kwh),
        battery_grid_stored_kwh=_r(bat_origin.grid_kwh),
        **{k: _r(v) for k, v in acc.items()},
    )


def summarize(parts: Iterable[EnergyTotals]) -> EnergyTotals:
    acc: dict[str, float] = dict.fromkeys(_SUM_FIELDS, 0.0)
    minutes = 0
    coarse = 0
    missing = 0
    for p in parts:
        minutes += p.minutes
        coarse += p.coarse_minutes
        missing += p.price_missing_minutes
        for k in _SUM_FIELDS:
            acc[k] += getattr(p, k)
    return EnergyTotals(
        minutes=minutes,
        coarse_minutes=coarse,
        price_missing_minutes=missing,
        **{k: _r(v) for k, v in acc.items()},
    )


def samples_from_totals(hour: HourlyEnergy) -> list[MinuteSample]:
    """Eine gespeicherte Stundenbilanz in gleichförmige Minutenwerte zurückverwandeln.

    Für Stunden, deren Minutenwerte es nie gab: der Historienimport hat aus Stundenmitteln direkt
    Stundenbilanzen geschrieben, und eine Neuberechnung findet dafür keine einzige Minutenzeile. Die
    gespeicherten Summen enthalten aber alles, was der Import damals wusste - Erzeugung, Netzsaldo,
    Speicherfluss, Verbraucher und den mittleren Bezugspreis. Daraus lässt sich dieselbe Stunde noch
    einmal rechnen, jetzt mit der Rangfolge für grobe Auflösung (siehe `hourly_energy`).

    Es entstehen so viele Minuten, wie die Stunde bewertet hatte, jede mit der mittleren Leistung
    dieser Minuten - die Summen bleiben damit exakt erhalten. Netzbezug und Einspeisung erscheinen
    als Saldo; das ist keine Näherung, sondern der Informationsstand eines Stundenmittels.
    """
    n = max(1, hour.minutes)
    f = 60.0 / n
    grid = (hour.import_kwh - hour.export_kwh) * f
    battery = (hour.battery_discharge_kwh - hour.battery_charge_kwh) * f
    price = hour.avg_import_price_ct
    return [
        MinuteSample(
            ts=hour.hour_start + timedelta(minutes=i),
            pv_kw=hour.pv_kwh * f,
            grid_kw=grid,
            battery_kw=battery,
            heat_pump_kw=hour.heat_pump_kwh * f,
            ev_kw=hour.ev_kwh * f,
            price_ct_kwh=price,
        )
        for i in range(n)
    ]


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
