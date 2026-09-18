"""Wer die Tür tatsächlich aufmacht - austauschbar, weil die Antwort darauf noch offen ist.

Es gibt drei Wege zu diesem Schloss, und sie unterscheiden sich nicht in dem, was sie tun, sondern
darin, woran sie hängen:

* **Home Assistant** ruft `lock.open` auf der Matter-Entität auf. Das Schloss bleibt auf Thread,
  das WLAN bleibt aus, die Batterie hält. Dafür stehen HA und der Border Router in der Kette.
* **Nuki-Bridge**, das Steckdosengerät, spricht Bluetooth mit dem Schloss und bietet eine lokale
  HTTP-API. Damit fielen HA und der HomePod aus dem Türweg heraus. Bluetooth ist nach Nukis
  eigener Rangfolge die sparsamste Verbindung.
* Ein dritter Weg über MQTT bräuchte das WLAN des Schlosses und kostet Batterie. Er steht hier
  bewusst nicht.

Welcher der richtige ist, entscheidet nicht die Theorie, sondern die Messung: wenn die Strecke über
Home Assistant im Betrieb aussetzt, wandert der Türweg auf die Nuki-Bridge. Deshalb ist der Öffner
ein Protokoll und keine Klasse - der Wechsel ist dann eine Einstellung.

**Der Dienstname ist ebenfalls Einstellung.** Ob die Matter-Anbindung eines Schlosses `lock.open`
kennt oder nur `lock.unlock`, hängt vom Gerät, von der Firmware und von der HA-Version ab. Das
lässt sich in zehn Sekunden ausprobieren und nicht zuverlässig nachschlagen; also gehört es in die
Konfiguration und nicht in den Quelltext.
"""

from __future__ import annotations

from typing import Protocol

import structlog

from dch_bridge.home_assistant.rest_client import HaRestClient
from dch_bridge.sources.nuki_lock import NukiLock

log = structlog.get_logger("door")


class OpenerError(RuntimeError):
    pass


class Opener(Protocol):
    """Öffnet die Tür oder wirft. Ein stiller Fehlschlag ist hier die schlechteste Antwort."""

    name: str

    async def open_door(self) -> None: ...


class HomeAssistantOpener:
    """Über Home Assistant, das als zweiter Matter-Verwalter mit dem Schloss spricht."""

    name = "home_assistant"

    def __init__(self, rest: HaRestClient, entity_id: str, service: str = "lock.open") -> None:
        self.rest = rest
        self.entity_id = entity_id.strip()
        # „lock.open" zieht die Falle, „lock.unlock" dreht nur den Riegel zurück. Welcher von
        # beiden geht, sagt der Versuch an der eigenen Tür.
        domain, _, action = service.strip().partition(".")
        self.domain = domain or "lock"
        self.service = action or "open"

    async def open_door(self) -> None:
        try:
            await self.rest.call_service(self.domain, self.service, self.entity_id)
        except Exception as exc:
            raise OpenerError(f"{self.domain}.{self.service} fehlgeschlagen: {exc}") from exc

    async def reachable(self) -> bool:
        """Ist das Schloss über Home Assistant gerade ansprechbar?

        Das ist die Messgröße, an der sich entscheidet, ob diese Strecke trägt. `unavailable` und
        `unknown` sind Zustände, die Home Assistant für ein Gerät meldet, das es nicht erreicht -
        genau der Fall, den wir suchen.
        """
        try:
            state = await self.rest.state_of(self.entity_id)
        except Exception:
            return False
        return state is not None and state not in ("unavailable", "unknown")


class NukiBridgeOpener:
    """Über die Nuki-Bridge im Heimnetz, per Bluetooth zum Schloss. Ohne HA, ohne HomePod."""

    name = "nuki_bridge"

    def __init__(self, lock: NukiLock) -> None:
        self.lock = lock

    async def open_door(self) -> None:
        try:
            await self.lock.unlatch()
        except Exception as exc:
            raise OpenerError(f"Nuki-Bridge: {exc}") from exc

    async def reachable(self) -> bool:
        try:
            await self.lock.state()
        except Exception:
            return False
        return True
