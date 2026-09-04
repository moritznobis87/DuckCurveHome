"""FastAPI-Anwendung. App-Fabrik, damit Tests eigene Instanzen mit eigenen Settings bekommen."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from dch_api.application.demo_runner import DemoRunner
from dch_api.errors import install_error_handlers
from dch_api.infrastructure.logging import configure_logging
from dch_api.routers import config, control, demo, health, history, live, plan
from dch_api.settings import Settings, get_settings

API_PREFIX = "/api/v1"


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)
    log = structlog.get_logger("app")

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        runner = DemoRunner(settings)
        app.state.runner = runner
        await runner.start()
        log.info("started", mode=settings.mode, role=settings.role, speed=settings.demo_speed)
        try:
            yield
        finally:
            await runner.stop()

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
    for r in (live.router, history.router, plan.router, control.router, config.router, demo.router):
        app.include_router(r, prefix=API_PREFIX)
    return app


app = create_app()


def run() -> None:
    import uvicorn

    s = get_settings()
    uvicorn.run("dch_api.main:app", host=s.host, port=s.port, log_level=s.log_level.lower())
