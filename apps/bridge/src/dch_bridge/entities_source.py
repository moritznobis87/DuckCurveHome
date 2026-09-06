"""Woher das Entity-Mapping kommt: aus dem Repository, aus /config oder aus dem letzten Abruf.

Die Datei von Hand nach Home Assistant zu kopieren war die häufigste Fehlerquelle beim Nachziehen von
Änderungen – ein Add-on-Update ohne Dateikopie sieht aus wie ein Fehler, ist aber nur ein alter Stand.
Deshalb holt die Bridge das Mapping standardmäßig selbst aus dem Repository. Die Datei in /config
übersteuert es weiterhin, für Versuche und für den Fall, dass jemand ohne Repository arbeitet.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

import structlog
import yaml

from dch_bridge.mapping import EntityMap

log = structlog.get_logger("entities")
Fetch = Callable[[str], str]


def fetch_text(url: str, timeout_s: float = 15.0) -> str:
    import httpx

    r = httpx.get(url, timeout=timeout_s, follow_redirects=True)
    r.raise_for_status()
    return r.text


def _parse(text: str) -> EntityMap:
    data = yaml.safe_load(text) or {}
    return EntityMap.model_validate(data)


def load_entity_map(
    file: Path,
    url: str,
    cache: Path,
    fetch: Fetch = fetch_text,
) -> tuple[EntityMap, str]:
    """Mapping laden und sagen, woher es stammt.

    Reihenfolge: die Datei in /config übersteuert alles. Sonst das Repository, dessen Antwort als
    Zwischenspeicher abgelegt wird – damit die Bridge auch ohne Internet startet. Erst wenn beides
    ausfällt, greift der letzte erfolgreiche Abruf.
    """
    if file.is_file():
        return _parse(file.read_text(encoding="utf-8")), f"datei:{file}"
    if url:
        try:
            text = fetch(url)
            entity_map = _parse(text)  # erst prüfen, dann ablegen: kein kaputter Zwischenspeicher
            try:
                cache.parent.mkdir(parents=True, exist_ok=True)
                cache.write_text(text, encoding="utf-8")
            except OSError as exc:
                log.warning("Zwischenspeicher nicht schreibbar", error=str(exc)[:200])
            return entity_map, f"repository:{url}"
        except Exception as exc:
            log.warning("Mapping nicht abrufbar", url=url, error=str(exc)[:200])
    if cache.is_file():
        log.warning("Mapping aus dem Zwischenspeicher – möglicherweise nicht der neueste Stand")
        return _parse(cache.read_text(encoding="utf-8")), f"zwischenspeicher:{cache}"
    raise FileNotFoundError(
        f"Kein Entity-Mapping: weder {file} noch abrufbar unter {url or '(keine URL gesetzt)'}"
    )
