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


def test_die_datei_im_haus_ergaenzt_das_repository(tmp_path: Path) -> None:
    """Was in der Datei steht, gilt. Was nur im Repository steht, kommt hinzu.

    Bis 0.14.2 ersetzte die Datei das Repository ganz. Am 14.11.2026 fehlte im Haus deshalb der
    Bus der Wärmepumpe: die Datei dort enthält Alarmanlage und Fensterkontakte, die nicht ins
    Repository gehören, und bekam darum nie mit, was im Repository dazukam.
    """
    file = tmp_path / "entities.yaml"
    file.write_text(LOKAL, encoding="utf-8")
    repo = (
        REPO
        + """  - { key: outdoor_temp_c, entity: sensor.draussen, unit: "°C" }
  - { key: netz_doppelt, entity: sensor.netz, unit: W }
actuators:
  - { key: lampe, entity: switch.lampe, label: Lampe }
mqtt:
  - kind: ebusd
    prefix: ebusd
    components:
      "heatpump/heatpump_flowmeter": heat_pump_flow_l_min
"""
    )
    cache = tmp_path / "cache.yaml"
    entity_map, origin = load_entity_map(file, URL, cache, lambda _: repo)
    # Gleicher Schlüssel: die Datei gewinnt. Gleiche Entität unter anderem Schlüssel: auch.
    assert [(s.key, s.entity) for s in entity_map.sensors] == [
        ("pv_power_kw", "sensor.anders"),
        ("grid_power_kw", "sensor.netz"),
        ("outdoor_temp_c", "sensor.draussen"),
    ]
    assert [a.key for a in entity_map.actuators] == ["lampe"]
    assert [m.kind for m in entity_map.mqtt] == ["ebusd"]
    assert "heat_pump_flow_l_min" in list(entity_map.keys())
    assert origin == f"datei+repository:{file}"
    assert cache.read_text(encoding="utf-8") == repo

    # Ohne Netz gilt die Datei mit dem letzten Abruf; ohne beides die Datei allein.
    gruende: list[str] = []
    entity_map, origin = load_entity_map(file, URL, cache, boom, gruende=gruende)
    assert origin == f"datei+zwischenspeicher:{file}" and len(gruende) == 1
    assert "heat_pump_flow_l_min" in list(entity_map.keys())
    entity_map, origin = load_entity_map(file, URL, tmp_path / "leer.yaml", boom)
    assert origin == f"datei:{file}"
    assert [s.entity for s in entity_map.sensors] == ["sensor.anders", "sensor.netz"]


def test_die_datei_kann_das_repository_ausschliessen(tmp_path: Path) -> None:
    """Für Versuche und für ein Haus, das mit dem Repository nichts zu tun haben will."""
    file = tmp_path / "entities.yaml"
    file.write_text("ersetzt_repository: true" + LOKAL, encoding="utf-8")
    gefragt: list[str] = []

    def fetch(url: str) -> str:
        gefragt.append(url)
        return REPO

    entity_map, origin = load_entity_map(file, URL, tmp_path / "cache.yaml", fetch)
    assert [s.entity for s in entity_map.sensors] == ["sensor.anders", "sensor.netz"]
    assert origin == f"datei:{file}" and gefragt == []


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


def test_warum_das_repository_nicht_genommen_wurde_geht_nicht_verloren(tmp_path: Path) -> None:
    """Am 14.11.2026 lief die Bridge im Haus mit einer Zuordnung ohne den Bus der Wärmepumpe,
    und warum, stand nur in ihrem Protokoll. Jetzt meldet sie Herkunft und Grund in die Cloud."""
    from dch_bridge.entities_source import herkunft

    cache = tmp_path / "cache.yaml"
    cache.write_text(REPO, encoding="utf-8")
    gruende: list[str] = []
    _, origin = load_entity_map(tmp_path / "fehlt.yaml", URL, cache, boom, gruende=gruende)
    assert len(gruende) == 1 and gruende[0]
    aus = herkunft(origin, gruende, kennt_bus=False)
    assert aus["herkunft"] == "zwischenspeicher" and aus["ort"] == str(cache)
    assert aus["grund"] == gruende[0] and aus["bus"] == "nein"

    file = tmp_path / "entities.yaml"
    file.write_text(LOKAL, encoding="utf-8")
    _, origin = load_entity_map(file, URL, cache, lambda _: REPO)
    assert herkunft(origin, [], kennt_bus=True) == {
        "herkunft": "datei+repository",
        "ort": str(file),
        "bus": "ja",
    }
    # Eine Adresse enthält selbst Doppelpunkte; getrennt wird nur am ersten.
    _, origin = load_entity_map(tmp_path / "fehlt.yaml", URL, cache, lambda _: REPO)
    assert herkunft(origin, [], kennt_bus=True)["ort"] == URL
