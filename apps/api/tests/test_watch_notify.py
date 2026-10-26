"""Aus einem Befund wird eine Mitteilung - einmal, und nach einem Neustart nicht noch einmal."""

from __future__ import annotations

from collections.abc import AsyncIterator
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest_asyncio

from dch_api.application.config_loader import load_app_config
from dch_api.application.forecast_service import ForecastService
from dch_api.application.live_runtime import LiveRuntime
from dch_api.application.push import Mitteilung
from dch_api.infrastructure.bridge_hub import BridgeHub
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from dch_api.settings import Settings
from hems_core.protocol import RawReading

PUFFER = (
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
)


class FakePush:
    """Nimmt entgegen, was gesendet würde. Der Weg nach draußen ist anderswo geprüft."""

    def __init__(self) -> None:
        self.gesendet: list[Mitteilung] = []

    async def send(self, mitteilung: Mitteilung) -> int:
        self.gesendet.append(mitteilung)
        return 1


async def baue(tmp_path: Path, name: str) -> tuple[LiveRuntime, FakePush, SqlRepositories]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / name}",
        db_create_all=True,
        weather_refresh_min=0,
        role="api",
    )
    engine = make_engine(settings.database_url)
    await create_all_for_tests(engine)
    cfg = load_app_config(None)
    repos = SqlRepositories(engine)
    rt = LiveRuntime(
        settings,
        cfg,
        repos,
        BridgeHub("test"),
        ForecastService(cfg.site, cfg.pv_system, weather=None, prices=None),
    )
    push = FakePush()
    rt.push = push  # type: ignore[assignment]
    return rt, push, repos


def fuehler(beobachtet: datetime) -> list[RawReading]:
    """Vier Pufferfühler mit diesem Beobachtungszeitpunkt."""
    return [RawReading(key=k, value=50.0, observed_at=beobachtet, source="test") for k in PUFFER]


@pytest_asyncio.fixture
async def stand(tmp_path: Path) -> AsyncIterator[tuple[LiveRuntime, FakePush, SqlRepositories]]:
    yield await baue(tmp_path, "a.sqlite")


async def test_ein_befund_meldet_sich_genau_einmal(
    stand: tuple[LiveRuntime, FakePush, SqlRepositories],
) -> None:
    rt, push, _ = stand
    jetzt = datetime.now(UTC)
    rt.live.apply(fuehler(jetzt - timedelta(hours=3)))

    await rt._watch_notify(jetzt)
    assert len(push.gesendet) == 1
    assert push.gesendet[0].title == "Die Puffertemperaturen"
    assert "Ladezustand" in push.gesendet[0].body

    # Zweiter Takt, derselbe Ausfall: Ein Ausfall ist eine Nachricht, nicht eine je zehn Sekunden.
    await rt._watch_notify(jetzt + timedelta(seconds=10))
    assert len(push.gesendet) == 1


async def test_die_entwarnung_kommt_auch(
    stand: tuple[LiveRuntime, FakePush, SqlRepositories],
) -> None:
    rt, push, _ = stand
    jetzt = datetime.now(UTC)
    rt.live.apply(fuehler(jetzt - timedelta(hours=3)))
    await rt._watch_notify(jetzt)

    # Die Fühler melden sich wieder - mit dem Zeitpunkt, zu dem auch der Wächter nachsieht.
    spaeter = jetzt + timedelta(minutes=31)
    rt.live.apply(fuehler(spaeter))
    # Nach der Pause, sonst schweigt die Regel absichtlich.
    await rt._watch_notify(spaeter)
    koerper = [m.body for m in push.gesendet]
    assert "melden sich wieder." in koerper
    # Nach einer halben Stunde ohne ein einziges Lebenszeichen der Brücke meldet sich auch die.
    # Das ist kein Nebeneffekt des Tests, sondern die Regel: Ein Dienst, der nie etwas hört,
    # soll das sagen.
    assert any("Ohne sie kommt nichts aus dem Haus" in k for k in koerper)


async def test_ein_neustart_meldet_nichts_noch_einmal(tmp_path: Path) -> None:
    """Jeder Deploy meldete sonst alle offenen Befunde erneut - an einem schlechten Tag mehrere."""
    erst, push1, repos = await baue(tmp_path, "b.sqlite")
    jetzt = datetime.now(UTC)
    erst.live.apply(fuehler(jetzt - timedelta(hours=3)))
    await erst._watch_notify(jetzt)
    assert len(push1.gesendet) == 1

    # Neuer Vorgang, dieselbe Datenbank: Der Stand kommt aus den Ereignissen.
    zweit = LiveRuntime(
        erst.settings,
        erst.config,
        repos,
        BridgeHub("test"),
        ForecastService(erst.config.site, erst.config.pv_system, weather=None, prices=None),
    )
    push2 = FakePush()
    zweit.push = push2  # type: ignore[assignment]
    await zweit._load_watch_state()
    zweit.live.apply(fuehler(jetzt - timedelta(hours=3)))
    await zweit._watch_notify(jetzt + timedelta(minutes=1))
    assert push2.gesendet == []


async def test_ohne_push_dienst_passiert_nichts(tmp_path: Path) -> None:
    rt, _, _ = await baue(tmp_path, "c.sqlite")
    rt.push = None
    rt.live.apply(fuehler(datetime.now(UTC) - timedelta(hours=3)))
    await rt._watch_notify(datetime.now(UTC))  # kein Fehler, kein Ereignis
    assert await rt.repos.latest_event("watch.buffer") is None


async def test_frische_werte_melden_gar_nichts(tmp_path: Path) -> None:
    rt, push, _ = await baue(tmp_path, "d.sqlite")
    jetzt = datetime.now(UTC)
    rt.live.apply(fuehler(jetzt - timedelta(minutes=6)))
    await rt._watch_notify(jetzt)
    assert push.gesendet == []
