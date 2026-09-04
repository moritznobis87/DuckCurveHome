"""Einstellungen (pydantic-settings). Alle Variablen mit Präfix DCH_ – siehe CONFIGURATION.md."""

from __future__ import annotations

from datetime import datetime
from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DCH_", env_file=".env", extra="ignore")

    mode: Literal["demo"] = "demo"  # Phase 2: "live"
    role: Literal["all", "api", "worker"] = "all"
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "INFO"
    cors_origins: list[str] = Field(default_factory=lambda: ["http://localhost:3000"])

    # Demo-Modus
    demo_speed: float = 1.0  # Simulationssekunden je Echtzeitsekunde (288 = 24 h in 5 min)
    demo_seed: int = 7
    demo_start: datetime | None = None  # None = jetzt
    demo_warmup_hours: float = 30.0  # Vorlauf, damit Chart und Historie sofort gefüllt sind
    demo_autostart: bool = True  # False in Tests: Simulation nur auf Abruf vorrücken

    # Regelung
    tick_s: int = 10
    history_retention_hours: int = 72

    @property
    def runs_api(self) -> bool:
        return self.role in ("all", "api")

    @property
    def runs_worker(self) -> bool:
        return self.role in ("all", "worker")


@lru_cache
def get_settings() -> Settings:
    return Settings()
