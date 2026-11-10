"""Der Morgenbrief im Dienst: einmal am Morgen, nicht nach einem Neustart, abschaltbar."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

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
    """Nimmt entgegen, was gesendet würde."""

    def __init__(self) -> None:
        self.gesendet: list[Mitteilung] = []

    async def send(self, mitteilung: Mitteilung) -> int:
        self.gesendet.append(mitteilung)
        return 1


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
    assert brief.title == "Heute im Haus"
    assert brief.tag == "morgenbrief"
    assert brief.body.startswith("Sonne: ")
    assert "Strom: " in brief.body
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
    assert stand["titel"] == "Heute im Haus"
    assert stand["zeilen"] and stand["hinweis_de"] == ""
    # Die Vorführung steht am frühen Nachmittag: gezeigt wird der Brief von morgen früh.
    assert stand["fuer_de"] == "morgen"

    aus = client.put("/api/v1/push/morgenbrief", json={"enabled": False}).json()
    assert aus["enabled"] is False
    assert client.get("/api/v1/push/morgenbrief").json()["enabled"] is False
    client.put("/api/v1/push/morgenbrief", json={"enabled": True})

    # Ohne angemeldetes Gerät sagt der Versand das, statt Erfolg zu melden.
    senden = client.post("/api/v1/push/morgenbrief/senden").json()
    assert senden["ok"] is False
    assert senden["devices"] == 0
    assert "Kein Gerät" in senden["message_de"]


def test_die_vorschau_gilt_fuer_den_naechsten_morgen() -> None:
    from zoneinfo import ZoneInfo

    berlin = ZoneInfo("Europe/Berlin")
    um = lambda h, m=0, tag=10: datetime(2026, 11, tag, h, m, tzinfo=berlin)  # noqa: E731
    # Vor sieben: heute um sieben. Zwischen sieben und neun: jetzt. Danach: morgen um sieben.
    assert brief_modul.naechster_versand(um(5, 30), berlin) == um(7)
    assert brief_modul.naechster_versand(um(7, 40), berlin) == um(7, 40)
    assert brief_modul.naechster_versand(um(9), berlin) == um(7, tag=11)
    assert brief_modul.naechster_versand(um(23, 44), berlin) == um(7, tag=11)
