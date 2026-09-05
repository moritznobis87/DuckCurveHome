"""Einstellungen (pydantic-settings). Alle Variablen mit Präfix DCH_ – siehe CONFIGURATION.md."""

from __future__ import annotations

import json
from datetime import datetime
from functools import lru_cache
from typing import Annotated, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


def parse_list(value: object) -> list[str]:
    """Listen aus Umgebungsvariablen tolerant lesen: JSON-Liste, kommagetrennt oder ein einzelner Wert."""
    if value is None:
        return []
    if isinstance(value, list | tuple):
        return [str(v).strip() for v in value if str(v).strip()]
    text = str(value).strip()
    if not text:
        return []
    if text.startswith("["):
        parsed = json.loads(text)
        if not isinstance(parsed, list):
            raise ValueError("JSON-Liste erwartet")
        return [str(v).strip() for v in parsed if str(v).strip()]
    return [part.strip().strip("'\"") for part in text.split(",") if part.strip().strip("'\"")]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DCH_", env_file=".env", extra="ignore")

    mode: Literal["demo", "live"] = "demo"
    role: Literal["all", "api", "worker"] = "all"
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "INFO"
    cors_origins: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: ["http://localhost:3000"]
    )

    # Demo-Modus
    demo_speed: float = 1.0  # Simulationssekunden je Echtzeitsekunde (288 = 24 h in 5 min)
    demo_seed: int = 7
    demo_start: datetime | None = None  # None = jetzt
    demo_warmup_hours: float = 30.0  # Vorlauf, damit Chart und Historie sofort gefüllt sind
    demo_autostart: bool = True  # False in Tests: Simulation nur auf Abruf vorrücken

    # Regelung
    tick_s: int = 10
    history_retention_hours: int = 72
    actuation_enabled: bool = False  # Phase 2: nur lesen; Phase 3 schaltet frei
    plan_refresh_min: int = 15

    # Live-Modus
    database_url: str = Field(default="", validation_alias="DATABASE_URL")
    db_create_all: bool = False  # nur SQLite/Tests: Schema ohne Alembic anlegen
    # Klartext-Tokens der Bridges (Secrets): JSON-Liste, kommagetrennt oder ein einzelnes Token
    bridge_tokens: Annotated[list[str], NoDecode] = Field(default_factory=list)
    api_token: str = (
        ""  # Bearer, den das Web-BFF mitschickt; leer = keine Prüfung (nur Entwicklung)
    )
    config_file: str = ""  # YAML mit site/pv_system/hems (config/hems.example.yaml)
    tibber_token: str = ""
    tibber_home_id: str = ""
    weather_refresh_min: int = 60
    price_refresh_min: int = 30
    raw_retention_days: int = 14

    @field_validator("cors_origins", "bridge_tokens", mode="before")
    @classmethod
    def _lists(cls, value: object) -> list[str]:
        return parse_list(value)

    @property
    def runs_api(self) -> bool:
        return self.role in ("all", "api")

    @property
    def runs_worker(self) -> bool:
        return self.role in ("all", "worker")


@lru_cache
def get_settings() -> Settings:
    return Settings()
