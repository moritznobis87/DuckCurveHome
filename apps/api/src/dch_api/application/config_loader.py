"""Lädt site/pv_system/hems aus einer YAML-Datei (DCH_CONFIG_FILE); fehlt sie, gelten die Defaults."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

from hems_core.domain import HemsConfig
from hems_core.forecasting import PvSystemConfig, SiteConfig


@dataclass(frozen=True)
class AppConfig:
    site: SiteConfig
    pv_system: PvSystemConfig
    hems: HemsConfig


def load_app_config(path: str | None) -> AppConfig:
    if not path or not Path(path).exists():
        return AppConfig(site=SiteConfig(), pv_system=PvSystemConfig(), hems=HemsConfig())
    data = yaml.safe_load(Path(path).read_text(encoding="utf-8")) or {}
    return AppConfig(
        site=SiteConfig.model_validate(data.get("site") or {}),
        pv_system=PvSystemConfig.model_validate(data.get("pv_system") or {}),
        hems=HemsConfig.model_validate(data.get("hems") or {}),
    )
