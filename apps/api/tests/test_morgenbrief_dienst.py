"""Der Morgenbrief im Dienst: einmal am Morgen, nicht nach einem Neustart, abschaltbar."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

from dch_api.application import morgenbrief as brief_modul
from dch_api.application.config_loader import load_app_config
from dch_api.application.forecast_service import ForecastService
from dch_api.application.live_runtime import LiveRuntime
from dch_api.application.push import Mitteilung
from dch_api.infrastructure.bridge_hub import BridgeHub
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from dch_api.schemas import PlanOut
from dch_api.settings import Settings

#: Der Tag der Vorführung; ihr Fahrplan beginnt an seiner Ortsmitternacht.
SIEBEN_ZEHN = datetime(2026, 9, 4, 5, 10, tzinfo=UTC)  # 07:10 im Haus, Sommerzeit
VOR_SIEBEN = datetime(2026, 9, 4, 4, 59, tzinfo=UTC)
NACHMITTAG = datetime(2026, 9, 4, 13, 0, tzinfo=UTC)
NAECHSTER_MORGEN_OHNE_PLAN = datetime(2026, 9, 9, 5, 10, tzinfo=UTC)


class FakePush:
    """Nimmt entgegen, was gesendet würde. `geraete` sind angemeldet, `nimmt_an` davon erreichbar."""

    def __init__(self) -> None:
        self.gesendet: list[Mitteilung] = []
        self.geraete = 1
        self.nimmt_an = 1

    async def count(self) -> int:
        return self.geraete

    async def send(self, mitteilung: Mitteilung) -> int:
        self.gesendet.append(mitteilung)
        return self.nimmt_an


async def baue(tmp_path: Path, plan: PlanOut | None) -> tuple[LiveRuntime, FakePush]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'brief.db'}",
        db_create_all=True,
        weather_refresh_min=0,
        role="api",
    )
    engine = make_engine(settings.database_url)
    await create_all_for_tests(engine)
    cfg = load_app_config(None)
    rt = LiveRuntime(
        settings,
        cfg,
        SqlRepositories(engine),
        BridgeHub("test"),
        ForecastService(cfg.site, cfg.pv_system, weather=None, prices=None),
    )
    push = FakePush()
    rt.push = push  # type: ignore[assignment]
    rt.plan = plan
    await rt._load_morgenbrief()
    return rt, push


def fahrplan(client: TestClient) -> PlanOut:
    """Der Fahrplan der Vorführung: echt gerechnet, mit Preisen, Sonne und geplanten Läufen."""
    return PlanOut.model_validate(client.get("/api/v1/plan").json())


async def test_der_brief_geht_einmal_am_morgen_und_nicht_davor(
    tmp_path: Path, client: TestClient
) -> None:
    rt, push = await baue(tmp_path, fahrplan(client))
    await rt._morgenbrief_tick(VOR_SIEBEN)
    assert push.gesendet == []

    await rt._morgenbrief_tick(SIEBEN_ZEHN)
    assert len(push.gesendet) == 1
    brief = push.gesendet[0]
    assert brief.title == "Morning Briefing"
    assert brief.tag == "morgenbrief"
    zeilen = brief.body.split("\n")
    # Sonne und Strompreis stehen immer da. Wärme und Kosten fehlen hier: der Fahrplan der
    # Vorführung beginnt in dieser Prüfung am Mittag und sagt über den Morgen nichts.
    assert [z.split(" ")[0] for z in zeilen[:2]] == ["☀️", "⚡"]
    assert " erwartet" in zeilen[0]
    assert "K1" not in brief.body

    # Eine Minute später und am Nachmittag: kein zweiter.
    await rt._morgenbrief_tick(SIEBEN_ZEHN.replace(minute=11))
    await rt._morgenbrief_tick(NACHMITTAG)
    assert len(push.gesendet) == 1
    assert (await rt.repos.latest_event("brief.morgen")) is not None


async def test_ein_neustart_schickt_keinen_zweiten(tmp_path: Path, client: TestClient) -> None:
    plan = fahrplan(client)
    rt, push = await baue(tmp_path, plan)
    await rt._morgenbrief_tick(SIEBEN_ZEHN)
    assert len(push.gesendet) == 1

    neu, push_neu = await baue(tmp_path, plan)
    await neu._morgenbrief_tick(SIEBEN_ZEHN.replace(minute=30))
    assert push_neu.gesendet == []


async def test_nach_neun_ist_es_kein_morgenbrief_mehr(tmp_path: Path, client: TestClient) -> None:
    rt, push = await baue(tmp_path, fahrplan(client))
    await rt._morgenbrief_tick(NACHMITTAG)
    assert push.gesendet == []


async def test_ohne_fahrplan_fuer_den_tag_wird_nichts_vermerkt(
    tmp_path: Path, client: TestClient
) -> None:
    rt, push = await baue(tmp_path, fahrplan(client))
    await rt._morgenbrief_tick(NAECHSTER_MORGEN_OHNE_PLAN)
    assert push.gesendet == []
    assert rt._brief_am is None, "kommt der Fahrplan um acht, geht der Brief noch"

    ohne, push_ohne = await baue(tmp_path, None)
    await ohne._morgenbrief_tick(SIEBEN_ZEHN)
    assert push_ohne.gesendet == []


async def test_ausgeschaltet_bleibt_ausgeschaltet_auch_nach_einem_neustart(
    tmp_path: Path, client: TestClient
) -> None:
    plan = fahrplan(client)
    rt, push = await baue(tmp_path, plan)
    stand = await rt.set_morgenbrief(False)
    assert stand.enabled is False
    await rt._morgenbrief_tick(SIEBEN_ZEHN)
    assert push.gesendet == []

    neu, push_neu = await baue(tmp_path, plan)
    assert neu._brief_an is False
    await neu._morgenbrief_tick(SIEBEN_ZEHN)
    assert push_neu.gesendet == []

    await neu.set_morgenbrief(True)
    await neu._morgenbrief_tick(SIEBEN_ZEHN)
    assert len(push_neu.gesendet) == 1


def test_die_api_zeigt_den_brief_und_schaltet_ihn(client: TestClient) -> None:
    stand = client.get("/api/v1/push/morgenbrief").json()
    assert stand["enabled"] is True
    assert stand["uhrzeit"] == "07:00"
    assert stand["titel"] == "Morning Briefing"
    assert stand["zeilen"] and stand["hinweis_de"] == ""
    # Die Vorführung steht am frühen Nachmittag: gezeigt wird das Briefing für den Rest von heute.
    assert stand["fuer_de"] == "heute"

    aus = client.put("/api/v1/push/morgenbrief", json={"enabled": False}).json()
    assert aus["enabled"] is False
    assert client.get("/api/v1/push/morgenbrief").json()["enabled"] is False
    client.put("/api/v1/push/morgenbrief", json={"enabled": True})

    # Ohne angemeldetes Gerät sagt der Versand das, statt Erfolg zu melden.
    senden = client.post("/api/v1/push/morgenbrief/senden").json()
    assert senden["ok"] is False
    assert senden["devices"] == 0
    assert "Kein Gerät" in senden["message_de"]


def test_die_vorschau_ist_das_briefing_von_heute_und_spaet_am_abend_das_von_morgen(
    client: TestClient,
) -> None:
    """Eine Regel für die Vorschau und beide Probeknöpfe: das aktuelle Briefing."""
    plan = fahrplan(client)
    mittag = brief_modul.vorschau(True, plan, NACHMITTAG, brief_modul_tz())
    assert mittag.fuer_de == "heute" and mittag.zeilen
    # Kurz vor Mitternacht ist vom Tag zu wenig übrig: dann das von morgen früh.
    spaet = datetime(2026, 9, 4, 21, 40, tzinfo=UTC)  # 23:40 im Haus
    abend = brief_modul.vorschau(True, plan, spaet, brief_modul_tz())
    assert abend.fuer_de == "morgen" and abend.zeilen
    assert abend.zeilen != mittag.zeilen
    # Ohne Fahrplan gibt es keines, und die Seite sagt, warum.
    leer = brief_modul.vorschau(True, None, NACHMITTAG, brief_modul_tz())
    assert leer.zeilen == [] and leer.titel == "Morning Briefing" and leer.hinweis_de


def test_waerme_und_kosten_kommen_aus_dem_fahrplan_des_optimierers() -> None:
    """Der Weg vom Fahrplan ins Briefing: Bedarf aus Heizen plus Warmwasser, Laufzeiten aus
    den geplanten Zuständen, Kosten aus der Aufteilung in Strom und Pellets."""
    from datetime import timedelta

    from dch_api.schemas import PlanIntervalOut

    berlin = brief_modul_tz()
    mitternacht = datetime(2026, 11, 11, 0, 0, tzinfo=berlin)

    def viertel(i: int) -> PlanIntervalOut:
        h = i / 4
        wp = 12 <= h < 15
        ofen = 17 <= h < 19
        return PlanIntervalOut(
            ts=mitternacht + timedelta(minutes=15 * i),
            expected_pv_kw=max(0.0, 3.0 - abs(h - 12.5) * 0.8),
            price_ct_kwh=18.0 if 13 <= h < 15 else 30.0,
            planned_hp_state="release" if wp else "off",
            planned_stove_on=ofen,
            reason_code="planned_optimizer",
            heat_demand_kw=2.5,
            dhw_demand_kw=0.5,
            planned_cost_eur=0.3 if wp or ofen else 0.0,
            planned_hp_cost_eur=0.2 if wp else 0.0,
            planned_pellet_cost_eur=0.25 if ofen else 0.0,
        )

    plan = PlanOut(
        created_at=mitternacht,
        planner="milp",
        horizon_start=mitternacht,
        horizon_end=mitternacht + timedelta(days=2),
        windows=[],
        intervals=[viertel(i) for i in range(192)],
        pv_forecast_today_kwh=11.0,
        next_cheap_window=None,
    )
    brief = brief_modul.aus_plan(plan, mitternacht + timedelta(hours=7), berlin)
    assert brief is not None
    assert brief.titel == "Morning Briefing"
    assert list(brief.zeilen) == [
        "☀️ 11 kWh erwartet, im Wesentlichen zwischen 10:30 und 14:45 Uhr",
        "⚡ Ø 29 ct, am günstigsten 13:00 bis 15:00 Uhr (18 ct)",
        "🔥 51 kWh Wärme: Wärmepumpe 3 h, Ofen 2 h",
        "💶 Wärme: 2,40 € Strom; 2,00 € Pellets",
    ]


def brief_modul_tz() -> ZoneInfo:
    return ZoneInfo("Europe/Berlin")


def test_die_probe_schickt_das_aktuelle_briefing_und_nicht_einen_festen_satz(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Nutzerwunsch 13.11.2026: Wer die Mitteilungen testet, bekommt das aktuelle Briefing."""
    gesendet: list[dict[str, str]] = []

    import pywebpush

    def fake(data: str, **kw: object) -> None:
        gesendet.append(json.loads(data))

    monkeypatch.setattr(pywebpush, "webpush", fake)
    client.post(
        "/api/v1/push/subscribe",
        json={"endpoint": "https://push.example/probe", "p256dh": "p", "auth": "a"},
    )
    try:
        vorschau = client.get("/api/v1/push/morgenbrief").json()
        for pfad in ("/api/v1/push/test", "/api/v1/push/morgenbrief/senden"):
            antwort = client.post(pfad).json()
            assert antwort["ok"] is True, antwort
            assert "Morning Briefing ging an 1 Gerät" in antwort["message_de"]
        assert len(gesendet) == 2
        for m in gesendet:
            assert m["title"] == "Morning Briefing"
            assert m["body"] == "\n".join(vorschau["zeilen"])
            assert m["body"].startswith("☀️ ")
    finally:
        client.post("/api/v1/push/unsubscribe", json={"endpoint": "https://push.example/probe"})


async def test_ohne_angemeldetes_geraet_gilt_der_brief_nicht_als_verschickt(
    tmp_path: Path, client: TestClient
) -> None:
    """Wer sich um halb acht anmeldet, bekommt den Brief von heute noch."""
    rt, push = await baue(tmp_path, fahrplan(client))
    push.geraete = 0
    await rt._morgenbrief_tick(SIEBEN_ZEHN)
    assert push.gesendet == []
    assert rt._brief_am is None
    assert (await rt.repos.latest_event("brief.morgen")) is None
    assert (
        await rt.morgenbrief()
    ).zuletzt_de == "Bisher ist kein Morning Briefing verschickt worden."

    push.geraete = 1
    await rt._morgenbrief_tick(SIEBEN_ZEHN.replace(minute=30))
    assert len(push.gesendet) == 1
    assert (await rt.morgenbrief()).zuletzt_de == (
        "Zuletzt verschickt am 4.9.2026, angekommen bei 1 von 1 Gerät."
    )


async def test_nimmt_kein_geraet_an_steht_es_da_und_es_wird_nicht_jede_minute_geschickt(
    tmp_path: Path, client: TestClient
) -> None:
    plan = fahrplan(client)
    rt, push = await baue(tmp_path, plan)
    push.geraete, push.nimmt_an = 2, 0
    await rt._morgenbrief_tick(SIEBEN_ZEHN)
    await rt._morgenbrief_tick(SIEBEN_ZEHN.replace(minute=11))
    assert len(push.gesendet) == 1
    satz = (await rt.morgenbrief()).zuletzt_de
    assert satz.startswith("Zuletzt verschickt am 4.9.2026, aber von 2 Geräten hat keines")

    # Der Stand übersteht einen Neustart: er steht im Ereignis, nicht nur im Arbeitsspeicher.
    neu, _ = await baue(tmp_path, plan)
    assert (await neu.morgenbrief()).zuletzt_de == satz
    ereignis = await neu.repos.latest_event("brief.morgen")
    assert ereignis is not None and ereignis.severity == "warning"


def test_zuletzt_satz_ohne_zahlen_aus_der_zeit_davor() -> None:
    from datetime import date

    assert brief_modul.zuletzt_satz(date(2026, 11, 12), None, None) == (
        "Zuletzt verschickt am 12.11.2026."
    )
    assert brief_modul.zuletzt_satz(date(2026, 11, 12), 2, 3) == (
        "Zuletzt verschickt am 12.11.2026, angekommen bei 2 von 3 Geräten."
    )
