"""FastAPI-Anwendung. App-Fabrik; Demo- oder Live-Modus je nach DCH_MODE."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import structlog
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from dch_api.application.config_loader import load_app_config
from dch_api.dependencies import require_api_token
from dch_api.errors import DchError, install_error_handlers
from dch_api.infrastructure.logging import configure_logging
from dch_api.routers import (
    bridge,
    config,
    control,
    demo,
    energy,
    forecast,
    health,
    history,
    live,
    plan,
)
from dch_api.settings import Settings, get_settings

API_PREFIX = "/api/v1"


async def _start_demo(app: FastAPI, settings: Settings) -> None:
    from dch_api.application.demo_runner import DemoRunner

    runner = DemoRunner(settings)
    app.state.runner = runner
    app.state.hems = runner.hems
    await runner.start()


async def _start_live(app: FastAPI, settings: Settings) -> None:
    from dch_api.application.forecast_service import ForecastService
    from dch_api.application.live_runtime import VERSION, LiveRuntime
    from dch_api.infrastructure.bridge_hub import BridgeHub
    from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
    from dch_api.infrastructure.db.repositories import SqlRepositories
    from dch_api.integrations.open_meteo import OpenMeteoWeatherProvider
    from dch_api.integrations.tibber import TibberPriceProvider

    if not settings.database_url:
        raise DchError("config", "DATABASE_URL fehlt für den Live-Modus.", 500)
    try:
        engine = make_engine(settings.database_url)
    except Exception as exc:  # klare Meldung statt Stacktrace-Kaskade
        raise DchError("config", f"Datenbankverbindung nicht konfigurierbar: {exc}", 500) from exc
    if settings.db_create_all:
        await create_all_for_tests(engine)
    cfg = load_app_config(settings.config_file or None)
    repos = SqlRepositories(engine)
    hub = BridgeHub(VERSION)
    forecasts = ForecastService(
        cfg.site,
        cfg.pv_system,
        weather=OpenMeteoWeatherProvider() if settings.weather_refresh_min > 0 else None,
        prices=TibberPriceProvider(settings.tibber_token, settings.tibber_home_id or None)
        if settings.tibber_token
        else None,
    )
    runtime = LiveRuntime(settings, cfg, repos, hub, forecasts)
    app.state.engine = engine
    app.state.bridge_hub = hub
    app.state.runner = runtime
    app.state.hems = cfg.hems
    await runtime.start()


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)
    log = structlog.get_logger("app")

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        app.state.settings = settings
        if settings.mode == "live":
            await _start_live(app, settings)
        else:
            await _start_demo(app, settings)
        log.info(
            "started", mode=settings.mode, role=settings.role, actuation=settings.actuation_enabled
        )
        try:
            yield
        finally:
            await app.state.runner.stop()
            engine = getattr(app.state, "engine", None)
            if engine is not None:
                await engine.dispose()

    app = FastAPI(
        title="Duck Curve Home API",
        version="0.1.0",
        description="Home Energy Management System – Live-Zustand, Historie, Plan und Steuerung.",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )
    install_error_handlers(app)
    app.include_router(health.router)
    app.include_router(bridge.router)
    protected = [Depends(require_api_token)]
    for r in (
        live.router,
        history.router,
        plan.router,
        forecast.router,
        energy.router,
        control.router,
        config.router,
        demo.router,
    ):
        app.include_router(r, prefix=API_PREFIX, dependencies=protected)
    return app


app = create_app()


def run() -> None:
    import uvicorn

    s = get_settings()
    uvicorn.run("dch_api.main:app", host=s.host, port=s.port, log_level=s.log_level.lower())
