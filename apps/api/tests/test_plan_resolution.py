"""Der Planer rechnet auf einem 15-Minuten-Raster. Er muss deshalb auch Preise auflösen können, die
feiner sind als eine Stunde - die Strombörse rechnet seit Oktober 2025 in Viertelstunden."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from dch_api.application.plan_service import build_plan
from dch_api.application.stove_planner import Zwillingspunkt
from hems_core.domain import HemsConfig
from hems_core.planning import PricePoint
from hems_core.simulation import BERLIN

NOW = datetime(2026, 9, 7, 10, 0, tzinfo=UTC)
DAY_START = (
    NOW.astimezone(BERLIN).replace(hour=0, minute=0, second=0, microsecond=0).astimezone(UTC)
)


def _quarter_prices(hours: int) -> list[PricePoint]:
    """Viertelstundenpreise, die innerhalb jeder Stunde deutlich schwanken."""
    out: list[PricePoint] = []
    for i in range(hours * 4):
        t = DAY_START + timedelta(minutes=15 * i)
        out.append(PricePoint(start=t, end=t + timedelta(minutes=15), ct_kwh=10.0 + (i % 4) * 10.0))
    return out


def _hourly_prices(hours: int) -> list[PricePoint]:
    return [
        PricePoint(
            start=DAY_START + timedelta(hours=i),
            end=DAY_START + timedelta(hours=i + 1),
            ct_kwh=20.0 + i,
        )
        for i in range(hours)
    ]


def _pv(_t: datetime) -> float:
    return 0.0


def test_quarter_hourly_prices_reach_every_interval() -> None:
    plan = build_plan(_pv, _quarter_prices(24), NOW, HemsConfig())
    first_hour = [i for i in plan.intervals if i.ts < DAY_START + timedelta(hours=1)]
    assert len(first_hour) == 4
    # Vier verschiedene Preise in einer Stunde: ein Nachschlagen über den Stundenschlüssel gäbe
    # allen vier denselben.
    assert [i.price_ct_kwh for i in first_hour] == [10.0, 20.0, 30.0, 40.0]


def test_hourly_prices_are_unchanged() -> None:
    plan = build_plan(_pv, _hourly_prices(24), NOW, HemsConfig())
    first_hour = [i for i in plan.intervals if i.ts < DAY_START + timedelta(hours=1)]
    assert [i.price_ct_kwh for i in first_hour] == [20.0] * 4


def test_zwei_tage_plan_und_preise_nur_so_weit_sie_reichen() -> None:
    """Der Horizont sind immer zwei Tage; der Preis endet, wo die Preisreihe endet.

    Vorher endete der Fahrplan nach 24 Stunden, wenn die Preise für morgen noch fehlten. Dann
    fehlte vormittags auch die PV-Vorschau für morgen, obwohl die Wetterprognose sie hergab. Jetzt
    reicht der Plan immer über zwei Tage, und die Viertelstunden ohne bekannten Preis sagen das,
    indem sie keinen tragen. Die ursprüngliche Frage dieses Tests bleibt: 96 Viertelstundenpreise
    sind ein Tag, nicht vier - eine Zählung der Punkte verwechselte das.
    """
    ein_tag = build_plan(_pv, _quarter_prices(24), NOW, HemsConfig())
    assert ein_tag.intervals[-1].ts >= DAY_START + timedelta(days=1)
    morgen = [i for i in ein_tag.intervals if i.ts >= DAY_START + timedelta(days=1)]
    assert len(morgen) == 96
    assert all(i.price_ct_kwh is None for i in morgen)
    assert all(i.planned_hp_state == "free" for i in morgen)
    assert all(i.price_ct_kwh is not None for i in ein_tag.intervals if i not in morgen)

    zwei_tage = build_plan(_pv, _quarter_prices(48), NOW, HemsConfig())
    assert all(i.price_ct_kwh is not None for i in zwei_tage.intervals)
    # Stundenpreise verhalten sich genauso
    assert all(
        i.price_ct_kwh is None
        for i in build_plan(_pv, _hourly_prices(24), NOW, HemsConfig()).intervals
        if i.ts >= DAY_START + timedelta(days=1)
    )


def test_der_ofen_steht_im_plan_oder_gar_nichts() -> None:
    """Der Fahrplan des Ofens wird mitgeführt, nicht hier gerechnet.

    `None` heißt „kein Ofenfahrplan" und ist etwas anderes als `False`: ohne diesen Unterschied
    zeigte die Zeitleiste einen Ofen, der durchgehend aus ist, wo in Wahrheit niemand geplant hat.
    """
    from datetime import UTC, datetime, timedelta

    from dch_api.application.plan_service import build_plan
    from hems_core.domain import HemsConfig

    now = datetime(2026, 10, 13, 10, 0, tzinfo=UTC)
    brennt_bis = now + timedelta(hours=2)

    ohne = build_plan(lambda t: 0.0, [], now, HemsConfig())
    assert all(iv.planned_stove_on is None for iv in ohne.intervals)

    mit = build_plan(lambda t: 0.0, [], now, HemsConfig(), stove_on=lambda t: now <= t < brennt_bis)
    an = [iv for iv in mit.intervals if iv.planned_stove_on]
    aus = [iv for iv in mit.intervals if iv.planned_stove_on is False]
    assert len(an) == 8, "zwei Stunden sind acht Viertelstunden"
    assert aus, "ausserhalb der Brennphase steht ausdrücklich „aus“"


def test_der_optimierer_fuehrt_die_waermepumpe_und_die_regel_faengt_auf() -> None:
    """Sagt der Fahrplan etwas, gilt er. Sagt er nichts, gilt wieder die Faustregel.

    Vorher rechnete dasselbe Programm den Fahrplan der Wärmepumpe mit, in derselben Pufferbilanz
    wie den des Ofens, und das Ergebnis wurde weggeworfen. Danebenher entschied eine Regel aus
    Preis- und PV-Fenstern.
    """
    laeuft_bis = NOW + timedelta(hours=2)

    ohne = build_plan(_pv, _hourly_prices(24), NOW, HemsConfig())
    assert ohne.planner == "rule_based_v1"
    assert all(iv.planned_hp_state != "off" for iv in ohne.intervals)

    mit = build_plan(
        _pv, _hourly_prices(24), NOW, HemsConfig(), hp_on=lambda t: NOW <= t < laeuft_bis
    )
    assert mit.planner == "milp_v1"
    frei = [iv for iv in mit.intervals if NOW <= iv.ts < laeuft_bis]
    assert frei and all(iv.planned_hp_state == "release" for iv in frei)
    assert all(iv.reason_code == "planned_optimizer" for iv in frei)
    # Ausserhalb seines Fensters sagt der Fahrplan ausdrücklich „nein", und das ist etwas anderes
    # als „dazu nichts": nur das Nein lässt die Preisregeln schweigen.
    assert [iv for iv in mit.intervals if iv.planned_hp_state == "off"]


def test_ein_halber_horizont_faellt_am_rand_auf_die_regel_zurueck() -> None:
    """Der Optimierer plant 36 h, der Plan zeigt bis zu 48. Dazwischen darf keine Lücke sein."""
    # Kürzer als der Planhorizont gewählt, damit die Naht im Test wirklich vorkommt: der Plan
    # beginnt an der lokalen Mitternacht, der Optimierer rechnet ab jetzt.
    horizont_ende = DAY_START + timedelta(hours=30)

    plan = build_plan(
        _pv,
        _quarter_prices(48),
        NOW,
        HemsConfig(),
        hp_on=lambda t: False if t < horizont_ende else None,
    )
    spaet = [iv for iv in plan.intervals if iv.ts >= horizont_ende]
    assert spaet, "zwei Tage Preise ergeben Intervalle jenseits des Optimiererhorizonts"
    assert all(iv.planned_hp_state in ("release", "avoid", "free") for iv in spaet)
    assert all(iv.reason_code != "planned_optimizer" for iv in spaet)


# ------------------------------------------------------------------ Die Modelleingänge im Plan


def test_ohne_zwilling_bleiben_die_felder_leer() -> None:
    """Eine Null wäre eine Behauptung. Wo nicht geplant wurde, steht nichts."""
    plan = build_plan(_pv, _hourly_prices(24), NOW, HemsConfig())
    erste = plan.intervals[0]
    assert erste.heat_demand_kw is None
    assert erste.dhw_demand_kw is None
    assert erste.buffer_kwh is None
    assert erste.outdoor_temp_c is None
    assert erste.cop is None
    assert plan.buffer_capacity_kwh is None and plan.buffer_min_kwh is None


def test_der_waermebedarf_erreicht_jedes_intervall() -> None:
    """Der Fahrplan führt die Eingänge mit, aus denen er entstand - je Viertelstunde, nicht je Tag."""
    bis = DAY_START + timedelta(hours=6)

    def zwilling(t: datetime) -> Zwillingspunkt | None:
        if not DAY_START <= t < bis:
            return None
        return Zwillingspunkt(
            heizen_kw=3.5, warmwasser_kw=0.4, puffer_kwh=12.0, aussen_c=-2.0, cop=2.8
        )

    plan = build_plan(
        _pv,
        _hourly_prices(24),
        NOW,
        HemsConfig(),
        twin=zwilling,
        buffer_capacity_kwh=31.0,
        buffer_min_kwh=9.3,
    )
    drinnen = [i for i in plan.intervals if i.ts < bis]
    draussen = [i for i in plan.intervals if i.ts >= bis]
    assert len(drinnen) == 24, "sechs Stunden sind vierundzwanzig Viertelstunden"
    assert all(i.heat_demand_kw == 3.5 and i.dhw_demand_kw == 0.4 for i in drinnen)
    assert all(i.buffer_kwh == 12.0 and i.cop == 2.8 for i in drinnen)
    assert all(i.outdoor_temp_c == -2.0 for i in drinnen)
    assert all(i.heat_demand_kw is None for i in draussen), (
        "jenseits des Planungshorizonts bleibt die Kurve eine Lücke"
    )
    assert plan.buffer_capacity_kwh == 31.0 and plan.buffer_min_kwh == 9.3


# ------------------------------------------------------------------ Was wirklich geschah


def test_die_messung_steht_neben_der_absicht() -> None:
    """Links der Jetzt-Linie liegt der halbe Fahrplan, und dort stand bis zum 08.11.2026 nur der Plan.

    Der Horizont beginnt an der Ortsmitternacht. Mittags ist die Hälfte der Zeichnung Vergangenheit,
    und die PV-Kurve dort war eine Prognose, die aussah wie eine Messung.
    """
    from dch_api.application.plan_service import ist_nachschlag

    jetzt = DAY_START + timedelta(hours=6)
    rows: list[dict[str, float | str | None]] = []
    for minute in range(6 * 60):
        ts = DAY_START + timedelta(minutes=minute)
        rows.append(
            {
                "ts": ts.isoformat(),
                "pv_power_kw": 2.0,
                "heat_pump_power_kw": 1.5,
                "hp_release_contact": 1.0,
            }
        )

    plan = build_plan(_pv, _hourly_prices(24), jetzt, HemsConfig(), ist=ist_nachschlag(rows, jetzt))
    gemessen = [i for i in plan.intervals if i.actual_pv_kw is not None]
    assert len(gemessen) == 24, "sechs Stunden sind vierundzwanzig Viertelstunden"
    assert all(i.actual_pv_kw == 2.0 for i in gemessen)
    assert all(i.actual_hp_kw == 1.5 for i in gemessen)
    assert all(i.actual_hp_release is True for i in gemessen)
    zukunft = [i for i in plan.intervals if i.ts >= jetzt]
    assert all(i.actual_pv_kw is None for i in zukunft), (
        "eine Null in der Zukunft wäre eine Behauptung über morgen"
    )


def test_die_laufende_viertelstunde_bleibt_draussen() -> None:
    """Sie ist erst zu einem Drittel vorbei und zeigte sonst ein Drittel der Leistung.

    Und zwar genau an der Stelle, auf die der Blick zuerst fällt: an der Jetzt-Linie. Ein Einbruch,
    der keiner ist, ist schlimmer als eine fehlende Spalte.
    """
    from dch_api.application.plan_service import ist_nachschlag

    jetzt = DAY_START + timedelta(hours=1, minutes=5)
    rows: list[dict[str, float | str | None]] = [
        {"ts": (DAY_START + timedelta(minutes=m)).isoformat(), "pv_power_kw": 3.0}
        for m in range(66)
    ]
    nachschlag = ist_nachschlag(rows, jetzt)
    assert nachschlag(DAY_START + timedelta(minutes=45)) is not None
    laufend = nachschlag(DAY_START + timedelta(hours=1))
    assert laufend is None, "die Viertelstunde ab 01:00 läuft noch"


def test_der_kontakt_wird_gemittelt_und_dann_gerundet() -> None:
    """`hp_release_contact` ist je Minute null oder eins; über eine Viertelstunde ist er ein Anteil.

    Vier von fünfzehn Minuten als „angefordert" zu zeigen wäre falscher als der Schwellwert.
    """
    from dch_api.application.plan_service import ist_nachschlag

    jetzt = DAY_START + timedelta(hours=1)

    def reihe(minuten_an: int) -> list[dict[str, float | str | None]]:
        return [
            {
                "ts": (DAY_START + timedelta(minutes=m)).isoformat(),
                "hp_release_contact": 1.0 if m < minuten_an else 0.0,
            }
            for m in range(15)
        ]

    knapp = ist_nachschlag(reihe(4), jetzt)(DAY_START)
    ueberwiegend = ist_nachschlag(reihe(12), jetzt)(DAY_START)
    assert knapp is not None and knapp.anforderung is False
    assert ueberwiegend is not None and ueberwiegend.anforderung is True


def test_ein_stummer_fuehler_zieht_die_anderen_nicht_mit() -> None:
    """Jedes Feld steht für sich: eine fehlende Wärmepumpenleistung sagt nichts über die PV."""
    from dch_api.application.plan_service import ist_nachschlag

    jetzt = DAY_START + timedelta(hours=1)
    rows: list[dict[str, float | str | None]] = [
        {
            "ts": (DAY_START + timedelta(minutes=m)).isoformat(),
            "pv_power_kw": 1.0,
            "heat_pump_power_kw": None,
        }
        for m in range(15)
    ]
    punkt = ist_nachschlag(rows, jetzt)(DAY_START)
    assert punkt is not None
    assert punkt.pv_kw == 1.0
    assert punkt.waermepumpe_kw is None
    assert punkt.anforderung is None
