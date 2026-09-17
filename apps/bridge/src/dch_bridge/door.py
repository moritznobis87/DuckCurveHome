"""Gesichtsscan öffnet Haustür: die Kette vom Ereignis zum Schloss.

    Reader → UniFi-Konsole → WebSocket → *hier* → lokales HTTP → Nuki

Alles im Heimnetz. Weder die DCH-Cloud noch Home Assistant noch die Nuki-Cloud stehen in diesem
Weg, und das ist der eigentliche Zweck: eine Tür, die nur aufgeht, wenn drei Dienste und zwei
Internetstrecken gleichzeitig mitspielen, geht irgendwann nicht auf.

**Die Cloud hat keinen Weg zur Tür.** Es gibt in DCH keinen Endpunkt, keine Schaltfläche und
keinen Befehl, der hier ankommt. Der einzige Auslöser ist ein Ereignis der Zutrittskonsole, geprüft
an einer Erlaubnisliste, die in der Konfiguration der Bridge steht. Ein Fehler in der Cloud kann
diese Tür nicht öffnen, weil es dafür keinen Pfad gibt - nicht, weil wir ihn gerade zugesperrt
haben.

**Der Beobachtungsbetrieb ist die Vorgabe.** Ohne `door_enabled` protokolliert der Dienst jedes
Zutrittsereignis mit Tür, Person und Verfahren und rührt das Schloss nicht an. So findet man die
Werte für die Erlaubnisliste an der eigenen Tür heraus, statt sie zu raten - insbesondere den Namen
des Verfahrens, den die Konsole für den Gesichtsscan verwendet und der nirgends dokumentiert ist.
Erst wenn die Liste steht, wird freigegeben.

**Jede Öffnung steht im Protokoll**, mit Person, Tür, Verfahren und Ergebnis. Eine abgelehnte
ebenso, mit dem Grund. Eine Tür ohne Protokoll ist eine Tür, über die man hinterher nichts sagen
kann.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import structlog

from dch_bridge.sources.nuki_lock import NukiError, NukiLock
from dch_bridge.sources.unifi_access import UnifiAccessEvents
from hems_core.control import AccessEvent, DoorGate, DoorPolicy
from hems_core.control.door_access import stale_cutoff

log = structlog.get_logger("door")


class DoorService:
    """Bindet den Ereignisstrom an das Schloss - über die Prüfung, nie daran vorbei."""

    def __init__(self, events: UnifiAccessEvents, lock: NukiLock, policy: DoorPolicy) -> None:
        self.events = events
        self.lock = lock
        self.gate = DoorGate(policy)
        self.opened = 0
        self.refused = 0
        self.failed = 0
        self.last_de: str = "noch kein Zutritt beobachtet"
        events.on_event = self.handle

    async def handle(self, event: AccessEvent, frame: dict[str, Any]) -> None:
        now = datetime.now(UTC)
        self.gate.forget_before(stale_cutoff(now))
        decision = self.gate.decide(event, now)
        # Im Beobachtungsbetrieb ist das Protokoll der ganze Zweck: hier stehen die Werte, die in
        # die Erlaubnisliste gehören. `authentication_type` ist der wichtigste davon.
        log.info(
            "access event",
            door=event.door,
            actor=event.actor,
            method=event.method,
            granted=event.granted,
            open_door=decision.open_door,
            reason=decision.reason_de,
        )
        if not decision.open_door:
            self.refused += 1
            self.last_de = f"{event.actor or 'unbekannt'}: {decision.reason_de}"
            return
        try:
            await self.lock.unlatch()
        except NukiError as exc:
            # Die Wiederholsperre wird bewusst nicht gesetzt: wer vor der Tür steht und einen
            # Fehlschlag erlebt, versucht es sofort noch einmal, und das soll gehen.
            self.failed += 1
            self.last_de = f"Öffnen fehlgeschlagen: {exc}"
            log.error("unlatch failed", actor=event.actor, error=str(exc))
            return
        self.gate.note_open(event.actor, now)
        self.opened += 1
        self.last_de = f"Geöffnet für {event.actor} um {now.astimezone():%H:%M:%S}."
        log.info("door opened", actor=event.actor, door=event.door, method=event.method)

    def status(self) -> dict[str, Any]:
        return {
            "enabled": self.gate.policy.enabled,
            "opened": self.opened,
            "refused": self.refused,
            "failed": self.failed,
            "last": self.last_de,
            **self.events.status(),
        }
