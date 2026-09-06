"""Woher das Entity-Mapping kommt und was passiert, wenn eine Quelle ausfällt."""

from __future__ import annotations

from pathlib import Path

import pytest

from dch_bridge.entities_source import load_entity_map

REPO = """
sensors:
  - { key: pv_power_kw, entity: sensor.pv, unit: W }
"""
LOKAL = """
sensors:
  - { key: pv_power_kw, entity: sensor.anders, unit: W }
  - { key: grid_power_kw, entity: sensor.netz, unit: W }
"""
URL = "https://example.invalid/entities.yaml"


def boom(url: str) -> str:
    raise ConnectionError("kein Netz")


def test_local_file_overrides_the_repository(tmp_path: Path) -> None:
    file = tmp_path / "entities.yaml"
    file.write_text(LOKAL, encoding="utf-8")
    entity_map, origin = load_entity_map(file, URL, tmp_path / "cache.yaml", lambda _: REPO)
    assert [s.entity for s in entity_map.sensors] == ["sensor.anders", "sensor.netz"]
    assert origin.startswith("datei:")


def test_repository_is_used_and_cached(tmp_path: Path) -> None:
    cache = tmp_path / "cache.yaml"
    entity_map, origin = load_entity_map(tmp_path / "fehlt.yaml", URL, cache, lambda _: REPO)
    assert [s.entity for s in entity_map.sensors] == ["sensor.pv"]
    assert origin == f"repository:{URL}"
    assert cache.read_text(encoding="utf-8") == REPO  # beim nächsten Start ohne Netz verfügbar


def test_cache_carries_the_bridge_through_an_outage(tmp_path: Path) -> None:
    cache = tmp_path / "cache.yaml"
    cache.write_text(REPO, encoding="utf-8")
    entity_map, origin = load_entity_map(tmp_path / "fehlt.yaml", URL, cache, boom)
    assert [s.entity for s in entity_map.sensors] == ["sensor.pv"]
    assert origin.startswith("zwischenspeicher:")


def test_broken_answer_does_not_poison_the_cache(tmp_path: Path) -> None:
    """Ein kaputter Abruf darf den letzten guten Stand nicht überschreiben."""
    cache = tmp_path / "cache.yaml"
    cache.write_text(REPO, encoding="utf-8")
    entity_map, origin = load_entity_map(
        tmp_path / "fehlt.yaml", URL, cache, lambda _: "sensors: [{key: pv_power_kw}]"
    )
    assert origin.startswith("zwischenspeicher:")  # Abruf war ungültig → alter Stand
    assert cache.read_text(encoding="utf-8") == REPO
    assert [s.entity for s in entity_map.sensors] == ["sensor.pv"]


def test_nothing_available_is_a_clear_error(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError, match="Kein Entity-Mapping"):
        load_entity_map(tmp_path / "fehlt.yaml", URL, tmp_path / "cache.yaml", boom)
