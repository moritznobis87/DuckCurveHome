"""Der Ofenfahrplan: was der Optimierer mit echten Prognosen daraus macht.

Die Fragen hier sind die, an denen sich ein Planer von einer Regel unterscheidet: Läuft der Ofen,
wenn die Wärmepumpe teurer ist? Bleibt er aus, wenn sie billiger ist? Und hält er sich an den
Brennstoff, der wirklich im Behälter liegt, statt an den, der hineinpassen würde?
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from dch_api.application.stove_planner import (
    STEP_MIN,
    StovePlan,
    SwitchDecision,
    decide_switch,
    plan_stove,
    stove_eur_per_h,
)
from hems_core.domain import BufferState, BufferStatus, HemsConfig
from hems_core.planning.price_windows import PricePoint
from hems_core.simulation import BERLIN

NOW = datetime(2026, 1, 15, 16, 0, tzinfo=UTC)  # Winterabend, Ortszeit 17 Uhr


def prices(
    ct: float, hours: int = 48, *, peak: tuple[int, int, float] | None = None
) -> list[PricePoint]:
    """Viertelstundenpreise ab NOW. `peak` setzt in einem Stundenfenster einen anderen Preis."""
    out: list[PricePoint] = []
    t = NOW
    for i in range(hours * 4):
        value = ct
        if peak is not None:
            h = i // 4
            if peak[0] <= h < peak[1]:
                value = peak[2]
        out.append(PricePoint(start=t, end=t + timedelta(minutes=15), ct_kwh=value))
        t += timedelta(minutes=15)
    return out


def temps(c: float, hours: int = 48) -> list[tuple[datetime, float]]:
    return [(NOW + timedelta(hours=i), c) for i in range(hours)]


def buffer(kwh: float = 15.0) -> BufferState:
    return BufferState(
        soc=kwh / 31.0,
        usable_energy_kwh=kwh,
        capacity_kwh=31.0,
        volume_liters=1000.0,
        mean_temp_c=48.0,
        status=BufferStatus.PARTIAL,
        method="test",
        headroom_soc=1.0 - kwh / 31.0,
    )


def plan(**kw: object) -> StovePlan:
    args: dict[str, object] = {
        "now": NOW,
        "tz": BERLIN,
        "cfg": HemsConfig(),
        "prices": prices(30.0),
        "pv_expected": lambda t: 0.0,
        "temps": temps(-5.0),
        "buffer": buffer(),
        "hp_running": False,
        "stove_running": False,
    }
    args.update(kw)
    return plan_stove(**args)  # type: ignore[arg-type]


# ------------------------------------------------------------------ Voraussetzungen


def test_ohne_preise_wird_nicht_geplant() -> None:
    """Ein Planer, der ohne Preise „aus" plant, sieht aus wie einer, der sich entschieden hat."""
    p = plan(prices=[])
    assert p.available is False
    assert "Preisreihe" in p.note_de


def test_ohne_pufferzustand_wird_nicht_geplant() -> None:
    blind = buffer().model_copy(update={"usable_energy_kwh": None, "soc": None})
    p = plan(buffer=blind)
    assert p.available is False and "Fühler" in p.note_de


def test_zu_kurzer_horizont_wird_abgelehnt() -> None:
    p = plan(prices=prices(30.0, hours=4))
    assert p.available is False
    assert "Stunden" in p.note_de


def test_ohne_ofen_kein_fahrplan() -> None:
    cfg = HemsConfig.model_validate({"stove": {"present": False}})
    assert plan(cfg=cfg).available is False


# ------------------------------------------------------------------ Die eigentliche Entscheidung


def test_teurer_strom_und_kalt_bringt_den_ofen_ins_spiel() -> None:
    """45 ct bei minus fünf Grad: die Wärmepumpe liefert für gut 20 ct/kWh, der Ofen für zehn."""
    p = plan(prices=prices(45.0), temps=temps(-5.0))
    assert p.available is True
    assert any(p.on), "der Ofen muss hier laufen"
    assert p.pellet_kg > 0


def test_billiger_strom_laesst_den_ofen_aus() -> None:
    p = plan(prices=prices(8.0), temps=temps(-5.0))
    assert p.available is True
    assert not any(p.on), "bei 8 ct heizt die Wärmepumpe für unter vier Cent je kWh"
    assert "bleibt aus" in p.note_de


# Nachgefüllt wird um 7 Uhr Ortszeit. NOW ist 17 Uhr Ortszeit, das laufende Budgetfenster reicht
# also noch 14 Stunden, das sind 56 Viertelstunden. Danach ist der Behälter wieder voll, und der
# Fahrplan darf dort selbstverständlich wieder Ofen vorsehen.
BIS_ZUM_NACHFUELLEN = 14 * 4
KG_PRO_STUNDE = 2.666  # Volllast, siehe stove_cost


def test_der_brennstoff_im_behaelter_begrenzt_das_laufende_fenster() -> None:
    """Nicht die Behältergröße zählt, sondern was noch drin ist. 3 kg sind gut eine Stunde."""
    p = plan(prices=prices(60.0), temps=temps(-8.0), remaining_kg=3.0)
    assert p.available is True
    assert p.fuel_budget_kg == 3.0
    verbrannt = sum(p.on[:BIS_ZUM_NACHFUELLEN]) * 0.25 * KG_PRO_STUNDE
    assert verbrannt <= 3.0 + 1e-6, "mehr als vorhanden darf er heute nicht verplanen"
    assert p.pellet_kg > 3.0, "morgen nach dem Nachfüllen darf er wieder mehr"


def test_ein_leerer_behaelter_laesst_den_ofen_bis_zum_nachfuellen_aus() -> None:
    p = plan(prices=prices(60.0), temps=temps(-8.0), remaining_kg=0.0)
    assert p.available is True
    assert not any(p.on[:BIS_ZUM_NACHFUELLEN]), "im laufenden Fenster ist nichts mehr zu holen"
    assert any(p.on[BIS_ZUM_NACHFUELLEN:]), "nach dem Nachfüllen schon"


# ------------------------------------------------------------------ Kostenseite


def test_die_raumwaerme_wird_zum_wärmepreis_der_wärmepumpe_gutgeschrieben() -> None:
    cfg = HemsConfig()
    teuer = stove_eur_per_h(cfg, price_ct_kwh=45.0, cop=2.2)
    billig = stove_eur_per_h(cfg, price_ct_kwh=10.0, cop=4.0)
    assert teuer < billig, "je teurer der Strom, desto mehr ist die Küchenwärme wert"
    # 1,9 kW Raumwärme zu 45/2,2 = 20,45 ct/kWh sind 0,39 EUR je Stunde Gutschrift.
    assert teuer == pytest.approx(1.2434 - 0.3886, abs=0.02)


def test_ohne_anrechnung_der_raumwaerme_kostet_die_stunde_den_vollen_betrag() -> None:
    cfg = HemsConfig.model_validate({"stove": {"room_heat_credit": 0.0}})
    assert stove_eur_per_h(cfg, price_ct_kwh=45.0, cop=2.2) == pytest.approx(1.24, abs=0.02)


# ------------------------------------------------------------------ Ablesen des Fahrplans


def test_der_fahrplan_sagt_was_jetzt_gilt_und_bis_wann() -> None:
    p = StovePlan(
        available=True,
        status="optimal",
        start=NOW,
        on=[False] * 4 + [True] * 8 + [False] * 4,
    )
    assert p.on_at(NOW) is False
    assert p.on_at(NOW + timedelta(hours=1)) is True
    assert p.until(NOW + timedelta(hours=1)) == NOW + timedelta(hours=3)
    assert p.runtime_h() == 2.0
    assert p.on_at(NOW - timedelta(minutes=STEP_MIN)) is None, "vor dem Horizont gilt nichts"
    assert p.on_at(NOW + timedelta(hours=9)) is None, "und dahinter auch nicht"


def test_ein_nicht_vorhandener_fahrplan_behauptet_nichts() -> None:
    p = StovePlan(note_de="Ohne Preisreihe kein Fahrplan.")
    assert p.on_at(NOW) is None and p.until(NOW) is None


# ------------------------------------------------------------------ Die Schaltentscheidung
# Jede Sperre hier ist ein Ausschaltknopf. Sie einzeln zu prüfen ist der Sinn dieser Tests: eine
# Feuerstätte, die aus Versehen anspringt, weil eine Bedingung im Gesamtausdruck untergegangen ist,
# ist ein anderer Fehler als eine Lichterkette, die nicht schaltet.

LAEUFT = StovePlan(available=True, status="optimal", start=NOW, on=[True] * 96)
AUS = StovePlan(available=True, status="optimal", start=NOW, on=[False] * 96)


def decide(**kw: object) -> SwitchDecision:
    args: dict[str, object] = {
        "plan": LAEUFT,
        "now": NOW,
        "mode": "auto",
        "controllable": True,
        "actuation_enabled": True,
        "bridge_online": True,
        "observed": False,
        "last_switch_at": None,
        "min_runtime_min": 120.0,
        "min_offtime_min": 60.0,
    }
    args.update(kw)
    return decide_switch(**args)  # type: ignore[arg-type]


def test_der_planer_schaltet_ein_wenn_alles_stimmt() -> None:
    d = decide()
    assert d.switch is True and d.state is True
    assert "Fahrplan" in d.reason_de


def test_der_planer_schaltet_aus_wenn_der_fahrplan_es_sagt() -> None:
    d = decide(plan=AUS, observed=True)
    assert d.switch is True and d.state is False


@pytest.mark.parametrize(
    ("kw", "grund"),
    [
        ({"controllable": False}, "freigegeben"),
        ({"mode": "on"}, "Von Hand"),
        ({"mode": "off"}, "Von Hand"),
        ({"actuation_enabled": False}, "deaktiviert"),
        ({"bridge_online": False}, "Bridge"),
        ({"observed": None}, "unbekannt"),
        ({"observed": True}, "bereits"),
        ({"plan": StovePlan()}, "Kein Fahrplan"),
    ],
)
def test_jede_sperre_haelt_fuer_sich_allein(kw: dict[str, object], grund: str) -> None:
    d = decide(**kw)
    assert d.switch is False
    assert grund in d.reason_de


def test_nach_dem_einschalten_gilt_die_mindestlaufzeit() -> None:
    """Zwei Stunden. Ein Fahrplan, der 15 Minuten später etwas anderes sagt, kommt nicht durch."""
    d = decide(plan=AUS, observed=True, last_switch_at=NOW - timedelta(minutes=30))
    assert d.switch is False and "Schaltsperre" in d.reason_de
    spaeter = decide(plan=AUS, observed=True, now=NOW + timedelta(hours=3), last_switch_at=NOW)
    assert spaeter.switch is True


def test_nach_dem_ausschalten_gilt_die_mindestpause() -> None:
    d = decide(observed=False, last_switch_at=NOW - timedelta(minutes=30))
    assert d.switch is False and "Schaltsperre" in d.reason_de
    assert decide(observed=False, last_switch_at=NOW - timedelta(minutes=61)).switch is True
