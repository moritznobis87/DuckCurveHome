"""Die Nachbetrachtung eines Tages: vom Bestand zu den Linien, mit einem echten Vergleichslauf."""

from __future__ import annotations

from collections.abc import Callable
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

from dch_api.application import nachbetrachtung as logik
from dch_api.application.anlage import BUFFER_KEYS
from dch_api.schemas import ShiftReportOut
from hems_core.domain import HemsConfig
from hems_core.planning import OptimizerConfig

BERLIN = ZoneInfo("Europe/Berlin")
TAG = date(2026, 11, 7)
VON = datetime(2026, 11, 6, 23, 0, tzinfo=UTC)  # Ortsmitternacht
BIS = VON + timedelta(days=1)
SPAETER = BIS + timedelta(days=2)
KOPF = {"authorization": "Bearer api-geheim"}
GEDULDIG = OptimizerConfig(step_min=15, time_limit_s=20.0)

OHNE_OFEN = HemsConfig().model_copy(
    update={"stove": HemsConfig().stove.model_copy(update={"present": False})}
)


def preis_des_tages(stunde: int) -> float:
    """Morgens teuer, mittags billig, sonst mittel. Die Ortsstunde zählt."""
    if 6 <= stunde < 9:
        return 45.0
    if 11 <= stunde < 15:
        return 10.0
    return 30.0


def zeilen(
    minuten: int = 1440 + 720,
    *,
    wp: Callable[[int], float | None] = lambda m: 0.05,
    pv: Callable[[int], float | None] = lambda m: 0.0,
    grund: float | None = 0.4,
    aussen: float | None = 2.0,
    preis: Callable[[int], float | None] | None = None,
) -> list[logik.Zeile]:
    """Minutenzeilen ab der Ortsmitternacht. Die Funktionen bekommen die Minute seit Mitternacht."""
    out: list[logik.Zeile] = []
    for m in range(minuten):
        ts = VON + timedelta(minutes=m)
        z: logik.Zeile = {
            "ts": ts.isoformat(),
            "heat_pump_power_kw": wp(m),
            "pv_power_kw": pv(m),
            "base_load_kw": grund,
            "house_power_kw": None,
            "ev_power_kw": 0.0,
            "electricity_price_ct_kwh": preis(m) if preis else preis_des_tages((m // 60) % 24),
            "outdoor_temp_c": aussen,
            "stove_running": None,
        }
        for key, grad in zip(BUFFER_KEYS, (46.0, 43.0, 39.0, 34.0), strict=True):
            z[key] = grad
        out.append(z)
    return out


def lauf(
    erstellt: datetime, frei: Callable[[int], bool], *, kosten: float | None = 0.3
) -> dict[str, list]:
    """Ein abgelegter Fahrplan: Punkte ab seiner Erstellung bis zum Tagesende."""
    punkte: dict[str, list] = {"hp_release": [], "stove_on": [], "cost_eur": []}
    for k in range(96):
        ts = VON + timedelta(minutes=15 * k)
        if ts <= erstellt - timedelta(minutes=15):
            continue
        an = frei(k)
        punkte["hp_release"].append((erstellt, ts, 1.0 if an else 0.0))
        if kosten is not None:
            punkte["cost_eur"].append((erstellt, ts, kosten if an else 0.0))
    return punkte


def zusammen(*laeufe: dict[str, list]) -> dict[str, list]:
    out: dict[str, list] = {"hp_release": [], "stove_on": [], "cost_eur": []}
    for teil in laeufe:
        for k, v in teil.items():
            out[k].extend(v)
    return out


def zeiten() -> list[datetime]:
    return [VON + timedelta(minutes=15 * k) for k in range(96)]


# ---------------------------------------------------------------------------- Viertelstunden


def test_verdichter_und_grundlast_werden_getrennt_gezaehlt() -> None:
    # Die ersten zehn Minuten läuft der Verdichter mit 3 kW, die übrigen fünf zieht die Anlage 0,1 kW.
    v = logik.viertelstunden(
        zeilen(30, wp=lambda m: 3.0 if m < 10 else 0.1),
        VON,
        VON + timedelta(minutes=30),
        jetzt=SPAETER,
        laeuft_ab_kw=0.5,
    )
    assert v[0].wp_kwh == pytest.approx(10 * 3.0 / 60)
    assert v[0].standby_kwh == pytest.approx(5 * 0.1 / 60)
    assert v[0].laufmin == pytest.approx(10.0)
    assert v[1].wp_kwh == 0.0 and v[1].laufmin == 0.0


def test_fehlende_minuten_werden_hochgerechnet_und_zu_viele_ergeben_eine_luecke() -> None:
    drei_fehlen = zeilen(15, wp=lambda m: None if m < 3 else 3.0)
    v = logik.viertelstunden(
        drei_fehlen, VON, VON + timedelta(minutes=15), jetzt=SPAETER, laeuft_ab_kw=0.5
    )
    assert v[0].wp_kwh == pytest.approx(0.75), "zwölf Minuten zu 3 kW, auf fünfzehn hochgerechnet"
    vier_fehlen = zeilen(15, wp=lambda m: None if m < 4 else 3.0)
    v = logik.viertelstunden(
        vier_fehlen, VON, VON + timedelta(minutes=15), jetzt=SPAETER, laeuft_ab_kw=0.5
    )
    assert v[0].wp_kwh is None, "elf Minuten sind keine Viertelstunde"


def test_eine_laufende_viertelstunde_zaehlt_noch_nicht() -> None:
    v = logik.viertelstunden(
        zeilen(30),
        VON,
        VON + timedelta(minutes=30),
        jetzt=VON + timedelta(minutes=22),
        laeuft_ab_kw=0.5,
    )
    assert v[0].wp_kwh is not None
    assert v[1].wp_kwh is None and v[1].preis_ct is None


def test_der_ueberschuss_ist_sonne_minus_haus_ohne_waermepumpe() -> None:
    v = logik.viertelstunden(
        zeilen(15, pv=lambda m: 3.0, grund=0.4),
        VON,
        VON + timedelta(minutes=15),
        jetzt=SPAETER,
        laeuft_ab_kw=0.5,
    )
    assert v[0].ueberschuss_kw == pytest.approx(2.6)
    # Ohne Sonne ist er null, auch wenn die Grundlast fehlt; mit Sonne und ohne Grundlast unbekannt.
    nachts = logik.viertelstunden(
        zeilen(15, grund=None), VON, VON + timedelta(minutes=15), jetzt=SPAETER, laeuft_ab_kw=0.5
    )
    assert nachts[0].ueberschuss_kw == 0.0
    tags = logik.viertelstunden(
        zeilen(15, pv=lambda m: 3.0, grund=None),
        VON,
        VON + timedelta(minutes=15),
        jetzt=SPAETER,
        laeuft_ab_kw=0.5,
    )
    assert tags[0].ueberschuss_kw is None


# ---------------------------------------------------------------------------- Die Fahrpläne


def test_der_erste_fahrplan_ist_der_letzte_vor_mitternacht() -> None:
    abends = lauf(VON - timedelta(hours=1), lambda k: k < 8)
    frueher = lauf(VON - timedelta(hours=5), lambda k: k >= 90)
    mittags = lauf(VON + timedelta(hours=12), lambda k: True)
    plan = logik.erster_fahrplan(zusammen(frueher, abends, mittags), zeiten(), VON)
    assert plan is not None
    assert plan.erstellt == VON - timedelta(hours=1)
    assert list(plan.wp[:9]) == [True] * 8 + [False]
    assert plan.versprochen_eur[0] == 0.3 and plan.versprochen_eur[8] == 0.0


def test_ohne_fahrplan_vom_vorabend_gilt_der_erste_des_tages() -> None:
    um_zehn = VON + timedelta(hours=10)
    plan = logik.erster_fahrplan(
        zusammen(
            lauf(um_zehn, lambda k: True), lauf(um_zehn + timedelta(hours=3), lambda k: False)
        ),
        zeiten(),
        VON,
    )
    assert plan is not None and plan.erstellt == um_zehn
    assert plan.wp[39] is None, "vor seiner Erstellung sagt er nichts"
    assert plan.wp[40] is True


def test_ohne_abgelegte_punkte_gibt_es_keinen_fahrplan() -> None:
    assert logik.erster_fahrplan({}, zeiten(), VON) is None
    assert logik.letzter_stand({}, zeiten()) is None


def test_der_letzte_stand_nimmt_nie_einen_lauf_von_danach() -> None:
    abends = lauf(VON - timedelta(hours=1), lambda k: False)
    um_zehn = lauf(VON + timedelta(hours=10) + timedelta(minutes=5), lambda k: True)
    plan = logik.letzter_stand(zusammen(abends, um_zehn), zeiten())
    assert plan is not None
    # 10:00 gehört noch dem Lauf vom Vorabend: der neue entstand um 10:05.
    assert plan.wp[40] is False
    assert plan.wp[41] is True


# ---------------------------------------------------------------------------- Der ganze Tag


def gelaufen_morgens(m: int) -> float:
    """Die Maschine lief von 6 bis 9 Uhr, zur teuersten Zeit, mit 3,4 kW."""
    return 3.4 if 360 <= m % 1440 < 540 else 0.05


def test_ein_ganzer_tag_mit_fahrplan_messung_und_vergleichslauf() -> None:
    """Der Fall, um den es geht: geplant war der Mittag, gelaufen ist der Morgen."""
    plan = lauf(VON - timedelta(hours=1), lambda k: 44 <= k < 56, kosten=0.1125)
    r = logik.zusammenstellen(
        zeilen(wp=gelaufen_morgens), plan, OHNE_OFEN, TAG, BERLIN, jetzt=SPAETER, opt_cfg=GEDULDIG
    )
    assert r.day == TAG and not r.laeuft_noch
    assert r.n_verglichen == 96
    je = {x.key: x for x in r.linien}
    # Versprochen: zwölf Viertelstunden zu 11,25 Cent, so wie abgelegt.
    assert je["versprochen"].eur == pytest.approx(1.35)
    # Gehalten: zwölf Viertelstunden Nennleistung zum Mittagspreis von 10 Cent.
    nenn_kwh = OHNE_OFEN.heat_pump.nominal_electric_power_kw / 4
    assert je["erster"].eur == pytest.approx(12 * nenn_kwh * 0.10, abs=0.01)
    assert je["letzter"].eur == je["erster"].eur, "ein einziger Lauf: erster und letzter sind eins"
    # Wirklich: drei Stunden zu 3,4 kW zum Morgenpreis von 45 Cent.
    assert je["wirklich"].wp_kwh == pytest.approx(10.2, abs=0.05)
    assert je["wirklich"].eur == pytest.approx(10.2 * 0.45, abs=0.03)
    assert je["wirklich"].wp_h == pytest.approx(3.0)
    # Die Treppe schließt sich.
    stufen = {a.key: a.eur for a in r.abstaende}
    assert stufen["nachfuehren"] == 0.0
    assert je["versprochen"].eur + sum(
        stufen[k] or 0.0 for k in ("prognosefehler", "nachfuehren", "eingriff")
    ) == pytest.approx(je["wirklich"].eur, abs=0.011)
    assert (stufen["eingriff"] or 0.0) > 2.0, "der Morgen statt des Mittags kostet"
    # Der Vergleichslauf hat gerechnet, deckt den Tag und meidet den teuren Morgen.
    perfekt = je["perfekt"]
    assert perfekt.verfuegbar, perfekt.grund_de
    an = [i for i, k in enumerate(perfekt.wp_kwh_je) if k]
    assert an, "bei zwei Grad braucht das Haus Wärme"
    assert not any(28 <= i < 36 for i in an), "nicht zwischen 6 und 9 Uhr"
    # Die Grundlast steht daneben.
    assert r.standby_kwh == pytest.approx(21 * 0.05, abs=0.02)
    assert "kostet" in r.satz_de or "gekostet" in r.satz_de


def test_ein_tag_vor_der_ablage_hat_messung_und_vergleichslauf_aber_keine_fahrplaene() -> None:
    r = logik.zusammenstellen(
        zeilen(wp=gelaufen_morgens), {}, OHNE_OFEN, TAG, BERLIN, jetzt=SPAETER, opt_cfg=GEDULDIG
    )
    je = {x.key: x for x in r.linien}
    assert r.n_verglichen == 96
    assert je["wirklich"].verfuegbar and je["perfekt"].verfuegbar
    for key in ("versprochen", "erster", "letzter"):
        assert not je[key].verfuegbar
    assert r.erster_plan_erstellt is None


def test_ein_laufender_tag_vergleicht_nur_was_vorbei_ist() -> None:
    jetzt = VON + timedelta(hours=5, minutes=7)
    plan = lauf(VON - timedelta(hours=1), lambda k: k < 4)
    r = logik.zusammenstellen(
        zeilen(5 * 60 + 7, wp=lambda m: 3.4 if m < 60 else 0.05),
        plan,
        OHNE_OFEN,
        TAG,
        BERLIN,
        jetzt=jetzt,
    )
    assert r.laeuft_noch
    assert r.n_verglichen == 20, "fünf volle Stunden; die laufende Viertelstunde zählt nicht"
    assert "bisher" in r.satz_de
    je = {x.key: x for x in r.linien}
    # Fünf Stunden sind weniger als der Mindesthorizont des Planers: kein Vergleichslauf, mit Grund.
    assert not je["perfekt"].verfuegbar
    assert "Stunden" in je["perfekt"].grund_de


def test_entsteht_der_erste_fahrplan_am_vormittag_beginnt_der_vergleich_dort() -> None:
    um_zehn = VON + timedelta(hours=10)
    r = logik.zusammenstellen(
        zeilen(wp=gelaufen_morgens),
        lauf(um_zehn, lambda k: 44 <= k < 56),
        OHNE_OFEN,
        TAG,
        BERLIN,
        jetzt=SPAETER,
        opt_cfg=GEDULDIG,
    )
    assert r.verglichen[:40] == [False] * 40 and all(r.verglichen[40:])
    assert r.erster_plan_erstellt == um_zehn
    je = {x.key: x for x in r.linien}
    # Der teure Morgenlauf liegt vor dem Vergleich und zählt für niemanden.
    assert je["wirklich"].wp_kwh == 0.0
    assert je["perfekt"].verfuegbar and je["perfekt"].wp_kwh_je[39] is None


def test_mit_ofen_stehen_seine_kosten_in_den_linien_und_der_hinweis_zum_pelletpreis() -> None:
    cfg = HemsConfig()
    assert cfg.stove.present
    r = logik.zusammenstellen(zeilen(), {}, cfg, TAG, BERLIN, jetzt=SPAETER, opt_cfg=GEDULDIG)
    assert r.hat_ofen
    assert any("Pelletpreis" in m for m in r.methode_de)
    assert next(x for x in r.linien if x.key == "wirklich").ofen_eur == 0.0


# ---------------------------------------------------------------------------- Der Endpunkt

HEUTE_DER_VORFUEHRUNG = date(2026, 9, 4)


def test_der_endpunkt_liefert_die_linien_der_vorfuehrung(client: TestClient) -> None:
    """Geprüft wird die Form: was die Vorführung erlebt hat, hängt an ihrer Laufzeit."""
    # Die Uhr der Vorführung, nicht die Wanduhr: die Vorführung der Prüfungen beginnt am 4.9.2026.
    heute = HEUTE_DER_VORFUEHRUNG.isoformat()
    r = client.get(f"/api/v1/plan/nachbetrachtung?day={heute}", headers=KOPF)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["day"] == heute
    assert [x["key"] for x in body["linien"]] == [
        "versprochen",
        "erster",
        "letzter",
        "wirklich",
        "perfekt",
    ]
    assert len(body["zeiten"]) in (92, 96, 100)
    assert len(body["verglichen"]) == len(body["zeiten"])
    assert body["hat_ofen"] is False, "die Vorführung hat keinen Ofen"
    assert body["satz_de"]
    for x in body["linien"]:
        assert x["verfuegbar"] or x["grund_de"], "eine fehlende Linie sagt, warum sie fehlt"


def test_ein_tag_in_der_zukunft_wird_abgelehnt(client: TestClient) -> None:
    morgen = (HEUTE_DER_VORFUEHRUNG + timedelta(days=2)).isoformat()
    r = client.get(f"/api/v1/plan/nachbetrachtung?day={morgen}", headers=KOPF)
    assert r.status_code == 422
    assert "Zukunft" in r.text


# ---------------------------------------------------------------------------- Ohne Preisblick


def _bericht(saving: float, tage: int, grund: str = "") -> ShiftReportOut:
    return ShiftReportOut(
        period="day",
        start=VON,
        end=BIS,
        actual_eur=4.0,
        naive_eur=4.0 + saving,
        saving_eur=saving,
        heat_pump_kwh=12.0,
        shifted_kwh=5.0,
        days_used=tage,
        days_skipped=0 if tage else 1,
        skipped_de=grund,
        method_de="",
    )


def test_der_vergleich_ohne_preisblick_wird_durchgereicht_und_nicht_neu_gerechnet() -> None:
    """Dieselbe Zahl wie auf der Kostenseite. Eine Rechnung, an mehreren Stellen gezeigt."""
    r = logik.zusammenstellen(
        zeilen(60), {}, OHNE_OFEN, TAG, BERLIN, jetzt=SPAETER, verschieben=_bericht(0.72, 1)
    )
    assert r.verschieben_eur == 0.72
    assert "0,72 € gespart" in r.verschieben_de
    assert "Kostenseite" in r.verschieben_de


def test_hat_das_verschieben_gekostet_steht_auch_das_da() -> None:
    assert "0,31 € mehr gekostet" in logik.verschieben_satz(_bericht(-0.31, 1))


def test_ohne_gerechneten_tag_gibt_es_keine_zahl_aber_den_grund() -> None:
    r = logik.zusammenstellen(
        zeilen(60),
        {},
        OHNE_OFEN,
        TAG,
        BERLIN,
        jetzt=SPAETER,
        verschieben=_bericht(0.0, 0, "zu wenige Stunden"),
    )
    assert r.verschieben_eur is None
    assert "zu wenige Stunden" in r.verschieben_de
    assert logik.verschieben_satz(None) == ""
