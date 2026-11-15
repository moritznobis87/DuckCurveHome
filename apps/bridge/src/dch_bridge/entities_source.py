"""Woher das Entity-Mapping kommt: aus dem Repository, aus /config oder aus dem letzten Abruf.

Die Datei von Hand nach Home Assistant zu kopieren war die häufigste Fehlerquelle beim Nachziehen von
Änderungen - ein Add-on-Update ohne Dateikopie sieht aus wie ein Fehler, ist aber nur ein alter Stand.
Deshalb holt die Bridge das Mapping standardmäßig selbst aus dem Repository. Eine Datei in /config
ergänzt es um das, was nur dieses Haus betrifft, und hat bei gleichen Einträgen das letzte Wort.
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
    gruende: list[str] | None = None,
) -> tuple[EntityMap, str]:
    """Mapping laden und sagen, woher es stammt.

    **Die Datei in /config ergänzt das Repository, sie ersetzt es nicht mehr** (ab 0.14.3). Bis
    dahin hatte sie Vorrang, und was im Repository dazukam, erreichte ein Haus mit eigener Datei
    nie: am 14.11.2026 fehlte so der Bus der Wärmepumpe, obwohl Add-on und Zuordnung aktuell
    waren. Die Datei im Haus enthält aber mit Grund, was nicht ins Repository gehört. Also gilt
    beides: was in der Datei steht, bleibt, was nur im Repository steht, kommt hinzu
    (`EntityMap.ergaenzt_um`). Wer das nicht will, schreibt `ersetzt_repository: true` in die
    Datei.

    Ohne Datei gilt das Repository allein. Dessen Antwort wird als Zwischenspeicher abgelegt,
    damit die Bridge auch ohne Internet startet.

    In `gruende` legt der Lader ab, warum das Repository nicht genommen wurde. Das stand bisher
    nur im Protokoll, und von dort erfuhr es niemand, der vor der Oberfläche saß.
    """
    lokal: EntityMap | None = None
    allein = False
    if file.is_file():
        data = yaml.safe_load(file.read_text(encoding="utf-8")) or {}
        allein = bool(data.pop("ersetzt_repository", False)) if isinstance(data, dict) else False
        lokal = EntityMap.model_validate(data)
        if allein or not url:
            return lokal, f"datei:{file}"
    grund: EntityMap | None = None
    woher = ""
    if url:
        try:
            text = fetch(url)
            grund = _parse(text)  # erst prüfen, dann ablegen: kein kaputter Zwischenspeicher
            woher = f"repository:{url}"
            try:
                cache.parent.mkdir(parents=True, exist_ok=True)
                cache.write_text(text, encoding="utf-8")
            except OSError as exc:
                log.warning("Zwischenspeicher nicht schreibbar", error=str(exc)[:200])
        except Exception as exc:
            log.warning("Mapping nicht abrufbar", url=url, error=str(exc)[:200])
            if gruende is not None:
                gruende.append(str(exc)[:200])
    if grund is None and cache.is_file():
        log.warning("Mapping aus dem Zwischenspeicher - möglicherweise nicht der neueste Stand")
        try:
            grund = _parse(cache.read_text(encoding="utf-8"))
            woher = f"zwischenspeicher:{cache}"
        except Exception as exc:
            # Mit eigener Datei ist ein kaputter Zwischenspeicher kein Grund, nicht zu starten.
            if lokal is None:
                raise
            log.warning("Zwischenspeicher nicht lesbar", error=str(exc)[:200])
    if lokal is None:
        if grund is None:
            raise _kein_mapping(file, url)
        return grund, woher
    if grund is None:
        log.warning("Repository nicht erreichbar - es gilt allein die Datei", datei=str(file))
        return lokal, f"datei:{file}"
    zusammen = lokal.ergaenzt_um(grund)
    log.info(
        "Zuordnung aus der Datei, ergänzt um das Repository",
        datei=str(file),
        dazu_sensoren=len(zusammen.sensors) - len(lokal.sensors),
        dazu_aktoren=len(zusammen.actuators) - len(lokal.actuators),
        dazu_geraete=[m.label or m.prefix for m in zusammen.mqtt[len(lokal.mqtt) :]],
    )
    return zusammen, f"datei+{woher.partition(':')[0]}:{file}"


def herkunft(origin: str, gruende: list[str], kennt_bus: bool) -> dict[str, str]:
    """Die Herkunft der Zuordnung, wie die Bridge sie der Cloud meldet (Quelle `zuordnung`)."""
    art, _, ort = origin.partition(":")
    aus = {"herkunft": art, "ort": ort, "bus": "ja" if kennt_bus else "nein"}
    if gruende:
        aus["grund"] = gruende[-1]
    return aus


def _kein_mapping(file: Path, url: str) -> FileNotFoundError:
    return FileNotFoundError(
        f"Kein Entity-Mapping: weder {file} noch abrufbar unter {url or '(keine URL gesetzt)'}"
    )
