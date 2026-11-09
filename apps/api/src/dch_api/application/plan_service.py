"""Stufe 1 der Planung: Preisfenster und erwartete PV-Überschussfenster (Chart, Energy Plan)."""

from __future__ import annotations

from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from dch_api.application.stove_planner import Zwillingspunkt
from dch_api.schemas import PlanIntervalOut, PlanOut, PriceWindowOut
from hems_core.domain import HemsConfig
from hems_core.planning import (
    PricePoint,
    PriceWindow,
    cheap_windows,
    current_price,
    expensive_windows,
    negative_windows,
    next_window_after,
)
from hems_core.simulation import BERLIN

LABELS = {
    "cheap": "günstiges Preisfenster",
    "expensive": "Wärmepumpe vermeiden, wenn thermisch möglich",
    "negative": "negativer Strompreis",
    "pv_surplus": "PV-Überschuss nutzen",
}


def _out(w: PriceWindow | tuple[datetime, datetime, str]) -> PriceWindowOut:
    if isinstance(w, PriceWindow):
        return PriceWindowOut(
            start=w.start, end=w.end, kind=w.kind, avg_ct_kwh=w.avg_ct_kwh, label_de=LABELS[w.kind]
        )
    s, e, kind = w
    return PriceWindowOut(start=s, end=e, kind=kind, label_de=LABELS[kind])


PvExpected = Callable[[datetime], float]

#: Welche Messreihen der Fahrplan neben seine Absicht legt.
IST_REIHEN: tuple[str, ...] = ("pv_power_kw", "heat_pump_power_kw", "hp_release_contact")


@dataclass(frozen=True)
class Istpunkt:
    """Was in einer Viertelstunde wirklich gemessen wurde.

    Jedes Feld darf einzeln `None` sein: die Fühler können unabhängig voneinander schweigen, und
    eine fehlende Wärmepumpenleistung sagt nichts über die PV.
    """

    pv_kw: float | None = None
    waermepumpe_kw: float | None = None
    anforderung: bool | None = None


def ist_nachschlag(
    rows: Iterable[Mapping[str, float | str | None]],
    jetzt: datetime,
) -> Callable[[datetime], Istpunkt | None]:
    """Minutenwerte zu einem Nachschlagewerk über Viertelstunden verdichten.

    **Nur abgeschlossene Viertelstunden.** Die laufende wird weggelassen, obwohl ihre ersten
    Minuten schon vorliegen. Sonst zeigte die jüngste Spalte ein Drittel der Leistung und sähe aus
    wie ein Einbruch, und zwar genau dort, wohin der Blick zuerst geht - an die Jetzt-Linie.

    **Der Kontakt wird gemittelt und dann gerundet.** `hp_release_contact` ist null oder eins je
    Minute; über eine Viertelstunde ist sein Mittel der Anteil der Zeit, in der angefordert wurde.
    Mehr als die Hälfte heißt „angefordert". Ein Schwellwert verliert Information, aber eine
    Viertelstunde mit vier Minuten Anforderung als „angefordert" zu zeigen wäre schlechter.
    """
    eimer: dict[datetime, dict[str, list[float]]] = {}
    grenze = jetzt.astimezone(UTC).replace(second=0, microsecond=0)
    grenze = grenze.replace(minute=(grenze.minute // 15) * 15)
    for row in rows:
        roh = row.get("ts")
        if roh is None:
            continue
        ts = datetime.fromisoformat(str(roh)).astimezone(UTC)
        slot = ts.replace(minute=(ts.minute // 15) * 15, second=0, microsecond=0)
        if slot >= grenze:
            continue
        fach = eimer.setdefault(slot, {})
        for key in IST_REIHEN:
            wert = row.get(key)
            if isinstance(wert, (int, float)) and not isinstance(wert, bool):
                fach.setdefault(key, []).append(float(wert))

    def mittel(fach: dict[str, list[float]], key: str) -> float | None:
        werte = fach.get(key)
        return None if not werte else sum(werte) / len(werte)

    punkte: dict[datetime, Istpunkt] = {}
    for slot, fach in eimer.items():
        kontakt = mittel(fach, "hp_release_contact")
        pv = mittel(fach, "pv_power_kw")
        wp = mittel(fach, "heat_pump_power_kw")
        punkte[slot] = Istpunkt(
            pv_kw=None if pv is None else round(pv, 3),
            waermepumpe_kw=None if wp is None else round(wp, 3),
            anforderung=None if kontakt is None else kontakt > 0.5,
        )

    def nachschlag(t: datetime) -> Istpunkt | None:
        return punkte.get(t.astimezone(UTC))

    return nachschlag


def pv_surplus_windows(
    pv_expected: PvExpected, day_start: datetime, cfg: HemsConfig
) -> list[tuple[datetime, datetime, str]]:
    """Erwartete PV-Überschussfenster (Prognose minus Grundlast ≥ Schwelle, mind. 30 min)."""
    windows: list[tuple[datetime, datetime, str]] = []
    run_start: datetime | None = None
    t = day_start
    step = timedelta(minutes=15)
    while t < day_start + timedelta(hours=24):
        exp = pv_expected(t) - 0.6
        if exp >= cfg.control.pv.on_surplus_kw:
            run_start = run_start or t
        elif run_start is not None:
            if t - run_start >= timedelta(minutes=30):
                windows.append((run_start, t, "pv_surplus"))
            run_start = None
        t += step
    if run_start is not None and t - run_start >= timedelta(minutes=30):
        windows.append((run_start, t, "pv_surplus"))
    return windows


def build_plan(
    pv_expected: PvExpected,
    prices: list[PricePoint],
    now: datetime,
    cfg: HemsConfig,
    stove_on: Callable[[datetime], bool | None] | None = None,
    hp_on: Callable[[datetime], bool | None] | None = None,
    twin: Callable[[datetime], Zwillingspunkt | None] | None = None,
    ist: Callable[[datetime], Istpunkt | None] | None = None,
    buffer_capacity_kwh: float | None = None,
    buffer_min_kwh: float | None = None,
    planner_status: str = "unavailable",
    planner_note_de: str = "",
    planner_warn_de: str = "",
    hp_actuation: bool = False,
) -> PlanOut:
    """Der Fahrplan über den Horizont.

    `stove_on`, `hp_on` und `twin` sind das Optimiererergebnis, als Nachschlagefunktionen über der
    Zeit. Sie werden hier **mitgeführt**, nicht gerechnet. `ist` ist die Gegenprobe aus der
    Messung, ebenso nachgeschlagen; sie trägt nur für abgeschlossene Viertelstunden der
    Vergangenheit etwas bei.

    **Was links der Jetzt-Linie steht, ist nicht der Plan von damals.** Der Horizont beginnt an
    der Ortsmitternacht, der Optimierer rechnet ab jetzt: für die vergangenen Viertelstunden gibt
    `hp_on` nichts her, und es greift die Regel - also das, was sie *heute* für diese Stunde
    sagen würde. Der aufbewahrte Fahrplan von damals steht in `forecast_runs` und gehört in die
    Nachbetrachtung, nicht hierher. Was hier dazukommt, ist deshalb die **Messung**, und die ist
    die ehrliche Vergangenheit dieser Seite.

    **Warum der Wärmebedarf hier auftaucht.** Er ist kein neues Modell: dasselbe Programm rechnet
    ihn längst für jede Viertelstunde, um den Fahrplan zu finden, und warf ihn danach weg. Ein
    Fahrplan, der zeigt, *wann* die Wärmepumpe laufen soll, aber nicht, *wogegen* geplant wurde,
    lässt sich nicht beurteilen - und genau das stand bis zum 07.11.2026 auf der Seite „Fahrplan".

    **Der Optimierer führt, die Regel fängt auf.** Vorher standen hier zwei Planer nebeneinander:
    der Ofen folgte einem gemischt-ganzzahligen Programm über Preis, Wärmebedarf, Puffer und
    Brennstoffbudget, die Wärmepumpe daneben einer Faustregel aus Preis- und PV-Fenstern. Dasselbe
    Programm rechnet den Fahrplan der Wärmepumpe längst mit, in derselben Pufferbilanz; er wurde nur
    nicht gelesen. Jetzt entscheidet er, wo er etwas sagt. Sagt er nichts - kein Solver, keine
    Preise, blinde Puffersensoren, oder schlicht außerhalb seines Horizonts -, gilt wieder die
    Regel. Ein Fahrplan, der bei fehlenden Eingängen „aus" plante, sähe von außen aus wie einer,
    der sich entschieden hat.
    """
    local_day = now.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0)
    day_start = local_day.astimezone(UTC)
    horizon_end = (local_day + timedelta(days=2)).astimezone(UTC)
    price_cfg = cfg.control.price
    cheap = cheap_windows(prices, price_cfg.cheap_quantile, price_cfg.min_window_min)
    expensive = expensive_windows(prices, price_cfg.expensive_quantile, 60)
    negative = negative_windows(prices)
    pv_win = pv_surplus_windows(pv_expected, day_start, cfg) + pv_surplus_windows(
        pv_expected, day_start + timedelta(days=1), cfg
    )
    if max((p.end for p in prices), default=day_start) <= day_start + timedelta(days=1):
        # ohne Morgenpreise keine PV-Fenster für morgen ausweisen
        pv_win = [w for w in pv_win if w[0] < day_start + timedelta(days=1)]
    windows = [_out(w) for w in (*negative, *cheap, *expensive)] + [_out(w) for w in pv_win]
    windows.sort(key=lambda w: w.start)

    def in_windows(t: datetime, kinds: set[str]) -> PriceWindowOut | None:
        for w in windows:
            if w.kind in kinds and w.start <= t < w.end:
                return w
        return None

    # Der Preis eines Intervalls ist der des Preispunkts, der es überdeckt - nicht der der vollen
    # Stunde. Seit die Börse auf Viertelstunden umgestellt hat, liefert Tibber vier Punkte je Stunde;
    # ein Nachschlagen über den Stundenschlüssel gäbe allen vier den Preis der ersten Viertelstunde
    # und machte den Planer blind für genau die Preisunterschiede, für die sein Raster gedacht ist.
    # Bei Stundenpreisen ist das Ergebnis unverändert.
    def price_at(t: datetime) -> float | None:
        p = current_price(prices, t)
        return p.ct_kwh if p else None

    # **Zwei Tage, immer.** Vorher endete der Fahrplan nach 24 Stunden, solange die Preise für
    # morgen noch nicht veröffentlicht waren - die Börse gibt sie erst gegen 13 Uhr frei. Damit
    # fehlte vormittags auch die PV-Vorschau für morgen, obwohl die Wetterprognose sie längst
    # hergab, und die Wandanzeige konnte über morgen nichts sagen. Wo kein Preis bekannt ist,
    # bleibt `price_ct_kwh` leer; ohne Preis gibt es dort auch kein Fenster und keinen Fahrplan,
    # sondern `free`. Eine leere Viertelstunde ist ehrlicher als eine fehlende.
    intervals: list[PlanIntervalOut] = []
    t = day_start
    end_plan = day_start + timedelta(hours=48)
    vom_optimierer = 0
    while t < end_plan:
        price = price_at(t)
        w = in_windows(t, {"negative", "pv_surplus", "cheap"})
        avoid = in_windows(t, {"expensive"})
        geplant = hp_on(t) if hp_on else None
        if geplant is not None:
            vom_optimierer += 1
            # Der Grund bleibt das Fenster, in dem der Fahrplan liegt: er sagt, *wann*, das Fenster
            # sagt, *warum*. Ohne Fenster steht der Optimierer für sich.
            grund = w or avoid
            state = "release" if geplant else "off"
            code = "planned_optimizer"
            note = grund.label_de if grund else None
        elif w is not None:
            state, code, note = "release", f"planned_{w.kind}", w.label_de
        elif avoid is not None:
            state, code, note = "avoid", "planned_avoid_peak", avoid.label_de
        else:
            state, code, note = "free", "none", None
        z = twin(t) if twin else None
        gemessen = ist(t) if ist else None
        intervals.append(
            PlanIntervalOut(
                ts=t,
                expected_pv_kw=round(pv_expected(t), 3),
                price_ct_kwh=price,
                planned_hp_state=state,
                planned_stove_on=stove_on(t) if stove_on else None,
                reason_code=code,
                note_de=note,
                heat_demand_kw=z.heizen_kw if z else None,
                dhw_demand_kw=z.warmwasser_kw if z else None,
                buffer_kwh=z.puffer_kwh if z else None,
                outdoor_temp_c=z.aussen_c if z else None,
                cop=z.cop if z else None,
                actual_pv_kw=gemessen.pv_kw if gemessen else None,
                actual_hp_kw=gemessen.waermepumpe_kw if gemessen else None,
                actual_hp_release=gemessen.anforderung if gemessen else None,
            )
        )
        t += timedelta(minutes=15)

    pv_kwh = sum(i.expected_pv_kw for i in intervals if i.ts < day_start + timedelta(days=1)) / 4
    nxt = next_window_after([*cheap, *negative], now)
    # Der Name sagt, wer geführt hat. Ein Plan, der sich „rule_based_v1" nennt, während der
    # Optimierer entschieden hat, verschweigt genau die Frage, die man an einen Fahrplan stellt.
    return PlanOut(
        created_at=now,
        planner="milp_v1" if vom_optimierer else "rule_based_v1",
        planner_status=planner_status if vom_optimierer else "unavailable",
        planner_note_de=planner_note_de if vom_optimierer else "",
        planner_warn_de=planner_warn_de if vom_optimierer else "",
        # Nicht an `vom_optimierer` gebunden: ob der Kontakt gestellt wird, gilt auch dann, wenn
        # die Regel geführt hat. Es ist eine Eigenschaft der Anlage, nicht des Planers.
        hp_actuation=hp_actuation,
        horizon_start=day_start,
        horizon_end=horizon_end,
        windows=windows,
        intervals=intervals,
        pv_forecast_today_kwh=round(pv_kwh, 1),
        next_cheap_window=_out(nxt) if nxt else None,
        buffer_capacity_kwh=buffer_capacity_kwh,
        buffer_min_kwh=buffer_min_kwh,
    )
