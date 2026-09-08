"""Den Fahrplan des Ofens rechnen: das MILP mit echten Prognosen füttern.

Bis hierher konnte der Optimierer den Ofen, aber niemand rief ihn damit auf. Dieses Modul ist die
Übersetzung zwischen beidem: aus Preisreihe, Wetterprognose, PV-Erwartung und Pufferzustand werden
Intervalle, aus dem Ergebnis wird ein Fahrplan, den der Regeltakt ablesen kann.

**Warum ein Fahrplan und keine Regel je Viertelstunde.** Der Brennstoff ist knapp: 15 kg am Tag,
nachgefüllt wird von Hand. Ob eine Ofenstunde sich lohnt, hängt damit nicht am Preis dieser Stunde,
sondern daran, ob es im selben Budgetfenster eine teurere gibt. Das ist ein Rucksackproblem, und es
braucht den ganzen Horizont auf einmal.

**Was hier bewusst grob bleibt:**

* Die Wärmepumpe geht mit ihren Nennwerten ein (4,5 kW elektrisch, 12 kW thermisch), nicht mit einer
  COP-abhängigen Leistung. Die Maschine moduliert, aber ihre Wärmeleistung ist nach oben durch die
  Bauart begrenzt; mit COP 4 zu rechnen ergäbe 18 kW, die sie nie liefert.
* Der Wärmebedarf kommt aus dem Modell v1 (Heizgradstunden plus Warmwasserprofil), nicht aus einer
  Messung. Solange der Wärmemengenzähler fehlt, ist das die beste verfügbare Zahl.
* Der Pufferverlust ist je Intervall konstant, gerechnet aus der mittleren Puffertemperatur gegen
  20 °C Aufstellraum.

Jede dieser Näherungen ist kleiner als die Prognoseunsicherheit, gegen die hier optimiert wird. Was
sie nicht sind: unsichtbar. `note_de` sagt bei jedem Fahrplan, worauf er beruht.
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass, field, replace
from datetime import datetime, timedelta, tzinfo

import structlog

from hems_core.accounting import cop_at, heat_demand_kw
from hems_core.accounting.stove_cost import (
    budget_window,
    heat_pump_ct_per_kwh,
    stove_economics,
)
from hems_core.domain import BufferState, HemsConfig
from hems_core.planning import current_price
from hems_core.planning.milp import (
    Interval,
    OptimizerConfig,
    SolverUnavailableError,
    optimize,
)
from hems_core.planning.price_windows import PricePoint

log = structlog.get_logger("stove-plan")

HORIZON_H = 36
STEP_MIN = 15
# Unter diesem Horizont wird nicht geplant. Ein Rucksackproblem über vier Stunden ist keines mehr:
# es fehlt die teurere Stunde, gegen die sich die billigere durchsetzen müsste.
MIN_HORIZON_H = 8
# Grundlast des Hauses, die von der PV-Erwartung abgeht, bevor von Überschuss die Rede ist.
# Dieselbe Annahme wie in `plan_service.pv_surplus_windows`; sie gehört irgendwann gemessen.
BASE_LOAD_KW = 0.6
ROOM_TEMP_C = 20.0  # Aufstellraum des Puffers, für den Verlustterm


@dataclass(frozen=True)
class StovePlan:
    """Der Fahrplan über den Horizont. `available=False` heißt: es wurde nicht geplant, und warum."""

    available: bool = False
    status: str = "unavailable"
    start: datetime | None = None
    step_min: int = STEP_MIN
    on: list[bool] = field(default_factory=list)
    hp_on: list[bool] = field(default_factory=list)
    cost_eur: float = 0.0
    pellet_kg: float = 0.0
    starts: int = 0
    fuel_budget_kg: float = 0.0
    solve_ms: int = 0
    note_de: str = ""

    def index_at(self, t: datetime) -> int | None:
        if not self.available or self.start is None or not self.on:
            return None
        i = int((t - self.start).total_seconds() // (self.step_min * 60))
        return i if 0 <= i < len(self.on) else None

    def on_at(self, t: datetime) -> bool | None:
        """Soll der Ofen zu diesem Zeitpunkt brennen? `None`, wenn der Fahrplan nichts dazu sagt."""
        i = self.index_at(t)
        return None if i is None else self.on[i]

    def until(self, t: datetime) -> datetime | None:
        """Bis wann der jetzige Zustand laut Fahrplan gilt. `None` am Ende des Horizonts."""
        i = self.index_at(t)
        if i is None or self.start is None:
            return None
        state = self.on[i]
        for j in range(i + 1, len(self.on)):
            if self.on[j] != state:
                return self.start + timedelta(minutes=self.step_min * j)
        return None

    def runtime_h(self) -> float:
        return round(sum(self.on) * self.step_min / 60.0, 1)


@dataclass(frozen=True)
class SwitchDecision:
    """Ob jetzt geschaltet wird, und wenn nicht: warum nicht. Der Grund ist nie leer."""

    switch: bool
    state: bool = False
    reason_de: str = ""


def decide_switch(
    *,
    plan: StovePlan,
    now: datetime,
    mode: str,
    controllable: bool,
    actuation_enabled: bool,
    bridge_online: bool,
    observed: bool | None,
    last_switch_at: datetime | None,
    min_runtime_min: float,
    min_offtime_min: float,
) -> SwitchDecision:
    """Die Entscheidung, den Ofen zu schalten, als reine Funktion.

    Sie steht bewusst getrennt von der Runtime: jede der Sperren hier ist ein Ausschaltknopf, und
    Ausschaltknöpfe gehören einzeln geprüft. Die Reihenfolge ist die der Zuständigkeiten - zuerst
    was der Mensch bestimmt hat, dann was die Anlage hergibt, zuletzt was das Gerät verträgt.
    """
    if not controllable:
        return SwitchDecision(False, reason_de="Ofensteuerung ist nicht freigegeben.")
    if mode != "auto":
        return SwitchDecision(False, reason_de="Von Hand gestellt; der Planer greift nicht ein.")
    if not actuation_enabled:
        return SwitchDecision(False, reason_de="Steuerung ist in dieser Phase deaktiviert.")
    if not bridge_online:
        return SwitchDecision(False, reason_de="Bridge nicht verbunden.")
    want = plan.on_at(now)
    if want is None:
        return SwitchDecision(False, reason_de="Kein Fahrplan für diesen Zeitpunkt.")
    if observed is None:
        return SwitchDecision(
            False, reason_de="Ofenzustand unbekannt; es wird nicht blind geschaltet."
        )
    if observed == want:
        return SwitchDecision(False, reason_de="Der Ofen ist bereits im gewünschten Zustand.")
    # Nach einem Schaltvorgang gilt eine Sperre, gleich ob er vom Planer oder von Hand kam. Der
    # Fahrplan hält Mindestlaufzeit und Mindestpause selbst ein, aber er wird alle 15 Minuten neu
    # gerechnet, und zwei aufeinanderfolgende Fahrpläne können sich widersprechen.
    wait_min = min_runtime_min if observed else min_offtime_min
    if last_switch_at is not None and now - last_switch_at < timedelta(minutes=wait_min):
        rest = wait_min - (now - last_switch_at).total_seconds() / 60.0
        return SwitchDecision(False, reason_de=f"Schaltsperre, noch {rest:.0f} Minuten.")
    return SwitchDecision(True, state=want, reason_de=f"Fahrplan: Ofen {'an' if want else 'aus'}.")


def plan_stove(
    *,
    now: datetime,
    tz: tzinfo,
    cfg: HemsConfig,
    prices: list[PricePoint],
    pv_expected: Callable[[datetime], float],
    temps: Sequence[tuple[datetime, float]],
    buffer: BufferState,
    hp_running: bool,
    stove_running: bool,
    remaining_kg: float | None = None,
) -> StovePlan:
    """Einen Fahrplan für beide Wärmequellen rechnen und den Ofenteil davon zurückgeben.

    Fehlt eine Voraussetzung, kommt kein halber Fahrplan zurück, sondern `available=False` mit einem
    Satz, der sagt, was fehlt. Ein Planer, der bei fehlenden Preisen einfach „aus" plant, sähe von
    außen genauso aus wie einer, der sich entschieden hat.
    """
    stove = cfg.stove
    if not stove.present:
        return StovePlan(note_de="Kein Ofen konfiguriert.")
    if buffer.usable_energy_kwh is None:
        return StovePlan(note_de="Ohne Pufferzustand kein Fahrplan: die Fühler fehlen.")
    if not prices:
        return StovePlan(note_de="Ohne Preisreihe kein Fahrplan.")

    step = timedelta(minutes=STEP_MIN)
    start = _floor(now, STEP_MIN)
    covered_until = max(p.end for p in prices)
    end = min(start + timedelta(hours=HORIZON_H), covered_until)
    if end - start < timedelta(hours=MIN_HORIZON_H):
        hours = (end - start).total_seconds() / 3600.0
        return StovePlan(
            note_de=(
                f"Die Preisreihe reicht nur {hours:.0f} Stunden. Der Ofen wird erst ab "
                f"{MIN_HORIZON_H} Stunden Horizont geplant, sonst fehlt der Vergleich."
            )
        )

    econ = stove_economics(stove)
    dt_h = STEP_MIN / 60.0
    window_start, _ = budget_window(stove, now.astimezone(tz))
    per_window_kg = stove.hopper_kg * max(stove.refills_per_day, 1.0)
    intervals: list[Interval] = []
    windows_seen = 0
    t = start
    while t < end:
        price = current_price(prices, t)
        ct = price.ct_kwh if price else cfg.tariff.fallback_import_ct_kwh
        temp_c = _temp_at(temps, t)
        local_hour = t.astimezone(tz).hour
        heating_kw, dhw_kw = heat_demand_kw(temp_c, local_hour, cfg.heat_demand)
        cop = cop_at(temp_c, cfg.heat_demand)
        w = int((t.astimezone(tz) - window_start) // timedelta(days=1))
        windows_seen = max(windows_seen, w)
        intervals.append(
            Interval(
                price_ct_kwh=ct,
                feed_in_ct_kwh=cfg.tariff.feed_in_ct_kwh,
                surplus_kw=max(0.0, pv_expected(t) - BASE_LOAD_KW),
                demand_kwh=(heating_kw + dhw_kw) * dt_h,
                stove_eur_per_h=stove_eur_per_h(cfg, price_ct_kwh=ct, cop=cop),
                budget_window=max(w, 0),
            )
        )
        t += step

    first_budget = per_window_kg if remaining_kg is None else max(remaining_kg, 0.0)
    budgets = [first_budget] + [per_window_kg] * (windows_seen + 1)
    capacity = buffer.capacity_kwh
    mean_c = (
        buffer.mean_temp_c if buffer.mean_temp_c is not None else cfg.buffer.target_temperature_c
    )
    loss_kwh = max(0.0, cfg.buffer.loss_kw_per_k * (mean_c - ROOM_TEMP_C)) * dt_h

    try:
        result = optimize(
            intervals,
            electric_kw=cfg.heat_pump.nominal_electric_power_kw,
            thermal_kw=cfg.heat_pump.nominal_thermal_power_kw,
            buffer_start_kwh=buffer.usable_energy_kwh,
            buffer_min_kwh=cfg.buffer.status_thresholds[0] * capacity,
            buffer_max_kwh=capacity,
            buffer_loss_kwh_per_step=loss_kwh,
            min_runtime_min=cfg.heat_pump.min_runtime_min,
            min_offtime_min=cfg.heat_pump.min_offtime_min,
            running_now=hp_running,
            stove_thermal_kw=stove.water_heat_kw,
            stove_kg_per_h=econ.kg_per_hour,
            stove_min_runtime_min=stove.min_runtime_min,
            stove_min_offtime_min=stove.min_offtime_min,
            stove_running_now=stove_running,
            fuel_budget_kg=budgets,
            cfg=OptimizerConfig(step_min=STEP_MIN),
        )
    except SolverUnavailableError as exc:
        return StovePlan(note_de=f"Kein Solver verfügbar: {exc}")

    if result.status not in ("optimal", "feasible") or not result.stove_on:
        return StovePlan(
            status=result.status,
            note_de=f"Der Optimierer fand keinen Fahrplan ({result.status}).",
        )

    plan = StovePlan(
        available=True,
        status=result.status,
        start=start,
        on=list(result.stove_on),
        hp_on=list(result.on),
        cost_eur=result.stove_cost_eur,
        pellet_kg=result.stove_pellet_kg,
        starts=result.stove_starts,
        fuel_budget_kg=round(first_budget, 1),
        solve_ms=result.solve_ms,
    )
    return replace(plan, note_de=_note(plan, first_budget))


def stove_eur_per_h(cfg: HemsConfig, *, price_ct_kwh: float, cop: float) -> float:
    """Was eine Betriebsstunde Ofen den Haushalt kostet, für die Zielfunktion des Optimierers.

    Pellets plus Eigenstrom, abzüglich der Raumwärme. Die Gutschrift ist kein Rabatt, sondern eine
    vermiedene Ausgabe: was in der Küche ankommt, muss die Wärmepumpe nicht liefern. Bewertet wird
    sie deshalb zum Wärmepreis der Wärmepumpe in genau dieser Stunde, nicht mit einer Pauschale.
    `room_heat_credit` steuert, wie viel davon angerechnet wird; 1,0 heißt: die Küche wäre sonst
    genauso warm geworden.
    """
    econ = stove_economics(cfg.stove, aux_price_ct_kwh=price_ct_kwh)
    credit_ct = heat_pump_ct_per_kwh(price_ct_kwh, cop)
    if credit_ct == float("inf"):
        credit_ct = 0.0
    credit_eur = cfg.stove.room_heat_credit * econ.room_heat_kw * credit_ct / 100.0
    return round(econ.eur_per_hour - credit_eur, 4)


def _note(plan: StovePlan, budget_kg: float) -> str:
    if not any(plan.on):
        return (
            f"Der Ofen bleibt aus: über {len(plan.on) * plan.step_min // 60} Stunden ist die "
            "Wärmepumpe durchgehend günstiger."
        )
    hours = plan.runtime_h()
    return (
        f"{hours:.1f} h Ofen in {plan.starts} Zündung{'en' if plan.starts != 1 else ''}, "
        f"{plan.pellet_kg:.1f} von {budget_kg:.1f} kg Brennstoff, {plan.cost_eur:.2f} EUR."
    )


def _floor(t: datetime, step_min: int) -> datetime:
    return t.replace(minute=(t.minute // step_min) * step_min, second=0, microsecond=0)


def _temp_at(temps: Sequence[tuple[datetime, float]], t: datetime) -> float:
    """Die Außentemperatur zum Zeitpunkt. Ohne Prognose 7 °C, wie überall sonst im Projekt."""
    if not temps:
        return 7.0
    best = temps[0]
    for point in temps:
        if point[0] <= t:
            best = point
        else:
            break
    return best[1]
