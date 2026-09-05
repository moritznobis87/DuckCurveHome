"""Einstellungen der Bridge. Als HA-Add-on kommen sie aus /data/options.json (run.sh exportiert sie als
Umgebungsvariablen DCH_BRIDGE_*), lokal aus .env."""

from __future__ import annotations

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class BridgeSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DCH_BRIDGE_", env_file=".env", extra="ignore")

    bridge_id: str = "haus"
    # Home Assistant: im Add-on über den Supervisor-Proxy, lokal per URL + Long-Lived Token
    ha_ws_url: str = "ws://supervisor/core/websocket"
    ha_rest_url: str = "http://supervisor/core/api"
    ha_token: str = Field(default="", validation_alias="SUPERVISOR_TOKEN")
    # API auf Railway
    api_ws_url: str = "wss://api-home.duckcurve.de/bridge/ws"
    api_token: str = ""
    # Mapping
    entities_file: Path = Path("/config/duckcurve/entities.yaml")
    # Verhalten
    telemetry_interval_s: float = 1.0
    state_refresh_s: float = (
        30.0  # kompletter get_states-Refresh, damit unveränderte Werte frisch bleiben
    )
    heartbeat_entity: str = "sensor.duckcurve_bridge_heartbeat"
    heartbeat_interval_s: int = 30
    offline_release_s: int = 180  # ohne Cloud: Wärmepumpen-Kontakte zurücksetzen
    outbox_path: Path = Path("/data/outbox.sqlite")
    outbox_max_age_h: int = 24 * 7
    log_level: str = "INFO"
