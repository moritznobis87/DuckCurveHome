"""Zutrittsereignisse von UniFi Access, über den WebSocket der Entwickler-Schnittstelle.

    wss://<konsole>:12445/api/v1/developer/devices/notifications
    Authorization: Bearer <token>

Der Token entsteht in der Access-Oberfläche unter Einstellungen → Allgemein → API-Token.

**Warum ein WebSocket und kein Abruf im Takt.** Hinter der Tür steht jemand. Ein Abruf alle zwei
Sekunden wäre im Mittel eine Sekunde zu spät und im schlechtesten Fall zwei; die offene Verbindung
liefert das Ereignis, sobald es entsteht. Sie ist zugleich die ehrlichere Konstruktion: ein
abgerissener Strom fällt sofort auf, ein Abruf, der leere Antworten bekommt, sieht aus wie Ruhe.

**Das Zertifikat der Konsole ist selbstsigniert.** Es wird deshalb nicht geprüft - eine
UniFi-Konsole im eigenen Heimnetz hat keine Kette, gegen die man prüfen könnte. Das ist vertretbar,
weil die Verbindung das Heimnetz nicht verlässt, und es ist genau der Grund, warum die Freigabe
nicht an dieser Verbindung hängt, sondern an der Prüfung in `hems_core.control.door_access`.

**Diese Quelle wertet nichts.** Sie übersetzt und gibt weiter. Ob ein Ereignis eine Tür öffnet,
entscheidet die reine Funktion, die dafür da ist, und nicht der Code, der zufällig die Verbindung
hält.
"""

from __future__ import annotations

import asyncio
import contextlib
import json
import ssl
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any

import structlog
import websockets

from hems_core.control import AccessEvent

log = structlog.get_logger("unifi")

NOTIFICATIONS_PATH = "/api/v1/developer/devices/notifications"
# Nur dieses Ereignis trägt einen Zutritt. Die Konsole schickt über denselben Strom auch
# Geräte- und Systemmeldungen; sie werden gezählt, aber nicht gedeutet.
ACCESS_EVENT = "access.logs.add"
MAX_BACKOFF_S = 60.0
# Ohne Rahmen so lange gilt die Verbindung als tot. Das ist keine Willkür: die Konsole schickt von
# sich aus regelmäßig einen Keepalive-Rahmen mit dem Inhalt "Hello". Bleibt selbst der aus, liegt
# nicht Ruhe im Haus vor, sondern eine Leitung, die niemand mehr bedient.
IDLE_TIMEOUT_S = 300.0
# So viel eines unlesbaren Rahmens landet im Protokoll. Genug, um die Felder zu benennen,
# wenig genug, um das Protokoll nicht mit Kennungen zu fluten.
RAW_FRAME_CHARS = 2000
# Ein „Access Granted" der Konsole in den Sprachen, in denen sie es schreibt. Verlässlicher als das
# Wort ist es nicht - deshalb entscheidet am Ende ohnehin die Erlaubnisliste und nicht dieses Feld.
GRANTED_MARKERS = ("granted", "erlaubt", "zutritt gewährt")
# Das Ergebnisfeld selbst trägt bei einer gelungenen Öffnung nur das Wort „ACCESS"; das Wort
# „Granted" steht daneben in `display_message` („Access Granted (Face)"). Abgelesen an einem echten
# Gesichtsscan an der eigenen Haustür, nicht der Dokumentation entnommen.
GRANTED_RESULTS = ("access",)
# Eine Ablehnung schlägt eine Zusage. Wie die Konsole sie schreibt, haben wir noch nicht gesehen -
# umso mehr Wörter stehen hier, und umso mehr zählt danach die Erlaubnisliste.
DENIED_MARKERS = ("denied", "blocked", "rejected", "failed", "abgelehnt", "verweigert")


def _sub(body: dict[str, Any], key: str) -> dict[str, Any]:
    """Ein verschachteltes Objekt, oder ein leeres, wenn es fehlt oder etwas anderes ist."""
    value = body.get(key)
    return value if isinstance(value, dict) else {}


def _body(frame: dict[str, Any]) -> dict[str, Any]:
    """Zu den Nutzdaten hinabsteigen, so tief die Konsole sie legt.

    An der eigenen Haustür liegen sie unter `data._source`. Die Beschreibung der Schnittstelle
    zeigt sie eine Ebene höher, ältere Firmware legt sie flach in den Rahmen. Statt auf eine
    Variante zu wetten, wird jede vorhandene Hülle geöffnet: das kostet zwei Zeilen und hat uns
    bereits zwei Tage gekostet, als es sie nicht gab.
    """
    body = frame
    for key in ("data", "_source"):
        nested = _sub(body, key)
        if nested:
            body = nested
    return body


def _granted(result: str, message: str) -> bool:
    """Meldet das Ereignis einen Erfolg? Eine Ablehnung schlägt jedes Ja."""
    text = f"{result} {message}".strip().lower()
    if any(marker in text for marker in DENIED_MARKERS):
        return False
    return result.strip().lower() in GRANTED_RESULTS or any(m in text for m in GRANTED_MARKERS)


def _target(payload: dict[str, Any], kind: str) -> str:
    for t in payload.get("target") or []:
        if isinstance(t, dict) and str(t.get("type", "")).lower() == kind:
            return str(t.get("display_name") or t.get("id") or "")
    return ""


def _published_at(payload: dict[str, Any], fallback: datetime) -> datetime:
    ms = payload.get("published")
    if isinstance(ms, int | float) and not isinstance(ms, bool):
        return datetime.fromtimestamp(float(ms) / 1000.0, tz=UTC)
    return fallback


def parse_event(frame: dict[str, Any], now: datetime) -> AccessEvent | None:
    """Einen Rahmen des Ereignisstroms übersetzen, oder None, wenn es kein Zutritt ist.

    Der Rahmen trägt die Nutzdaten je nach Firmware direkt oder unter `data`. Beides wird
    angenommen: eine Anbindung, die an einer Verschachtelung scheitert, ist an einer Haustür die
    falsche Art von Strenge.
    """
    if str(frame.get("event", "")) != ACCESS_EVENT:
        return None
    body = _body(frame)
    # Ergebnis, Zeitstempel und Meldung stehen unter `event`, das Verfahren unter
    # `authentication.credential_provider`, die Tür in der Liste `target` beim Eintrag vom Typ
    # „door" (daneben stehen dort Hub, Reader, Etage und Gebäude - alle mit Anzeigenamen, von denen
    # keiner die Tür ist). Die flachen Felder bleiben als Rückfall stehen.
    inner = _sub(body, "event")
    actor = _sub(body, "actor")
    auth = _sub(body, "authentication")
    result = str(inner.get("result") or body.get("result") or "")
    message = str(inner.get("display_message") or body.get("display_message") or "")
    method = str(auth.get("credential_provider") or body.get("authentication_type") or "")
    name = str(actor.get("display_name") or actor.get("alternate_name") or "")
    return AccessEvent(
        at=_published_at(inner, _published_at(body, now)),
        door=_target(body, "door") or _target(inner, "door"),
        actor=name or _target(body, "user") or _target(inner, "user"),
        method=method,
        granted=_granted(result, message),
    )


def unreadable(event: AccessEvent) -> bool:
    """Ein Zutritt ohne Tür, ohne Person und ohne Verfahren ist keiner - er ist ungelesen."""
    return not (event.door.strip() or event.actor.strip() or event.method.strip())


class UnifiAccessEvents:
    """Hält die Verbindung und reicht jedes Zutrittsereignis weiter."""

    name = "unifi_access"

    def __init__(
        self,
        host: str,
        token: str,
        *,
        port: int = 12445,
        verify_tls: bool = False,
        idle_timeout_s: float = IDLE_TIMEOUT_S,
    ) -> None:
        self.url = f"wss://{host.strip()}:{port}{NOTIFICATIONS_PATH}"
        self.token = token
        # Wird von `DoorService` gesetzt. Ohne Empfänger läuft die Verbindung trotzdem und zählt -
        # das ist der Beobachtungsbetrieb in seiner rohesten Form.
        self.on_event: Callable[[AccessEvent, dict[str, Any]], Awaitable[None]] | None = None
        self.verify_tls = verify_tls
        self.idle_timeout_s = idle_timeout_s
        self.online = False
        self.last_error: str | None = None
        self.events_seen = 0
        self.access_events = 0
        self.unreadable_events = 0
        self.last_event_at: datetime | None = None
        self._task: asyncio.Task[None] | None = None

    def _ssl(self) -> ssl.SSLContext:
        ctx = ssl.create_default_context()
        if not self.verify_tls:
            # Die Konsole stellt sich selbst aus. Siehe Modulkopf: die Freigabe hängt nicht hieran.
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
        return ctx

    async def _consume(self) -> None:
        async with websockets.connect(
            self.url,
            additional_headers={"Authorization": f"Bearer {self.token}"},
            ssl=self._ssl(),
            # **Keine Protokoll-Pings.** Die Konsole beantwortet sie nicht, und die Bibliothek
            # beendet die Verbindung dann nach zwei Takten von sich aus:
            #
            #     ConnectionClosedError(Close(code=1011, reason='keepalive ping timeout'))
            #
            # Die Verbindung war dabei völlig in Ordnung - wir haben sie selbst umgebracht. Die
            # Konsole hält sie stattdessen mit eigenen Textrahmen offen („Hello"), und das genügt
            # sowohl der Leitung als auch uns: an ihnen erkennt man auch, dass noch jemand da ist.
            ping_interval=None,
        ) as ws:
            self.online = True
            self.last_error = None
            log.info("unifi access online", url=self.url)
            await self.pump(ws)

    async def pump(self, ws: Any) -> None:
        """Rahmen lesen, bis nichts mehr kommt.

        Eigen benannt und nicht in `_consume` verschachtelt, weil hier der Totmannschalter sitzt:
        ohne Protokoll-Pings ist das die einzige Stelle, an der eine Leitung auffliegt, die nur
        noch aussieht wie eine. Was sich prüfen lässt, gehört in eine Funktion, die man prüfen kann.
        """
        while True:
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=self.idle_timeout_s)
            except TimeoutError:
                raise ConnectionError(
                    f"seit {self.idle_timeout_s:.0f} s kein Rahmen, auch kein Keepalive"
                ) from None
            self.events_seen += 1
            try:
                frame = json.loads(raw)
            except (TypeError, ValueError):
                continue
            # Der Keepalive der Konsole ist der nackte Text „Hello" und damit kein Objekt. Er wird
            # mitgezählt und sonst übergangen: gerade an ihm sieht man, dass die Leitung lebt.
            if not isinstance(frame, dict):
                continue
            event = parse_event(frame, datetime.now(UTC))
            if event is None:
                continue
            self.access_events += 1
            self.last_event_at = event.at
            if unreadable(event):
                # Der Rahmen war ein Zutritt, aber keines der Felder stand, wo wir es erwartet
                # haben. Dann ist der Rahmen selbst die einzige brauchbare Auskunft. Er steht nur
                # in diesem Fall im Protokoll, und gekürzt: er enthält Namen und Kennungen.
                self.unreadable_events += 1
                log.warning(
                    "access event unleserlich",
                    hinweis="Rahmen im Rohzustand, damit die Felder benannt werden koennen",
                    frame=json.dumps(frame, ensure_ascii=False)[:RAW_FRAME_CHARS],
                )
            if self.on_event is not None:
                with contextlib.suppress(Exception):
                    await self.on_event(event, frame)

    def _explain(self, exc: Exception) -> str:
        """Aus einer Ausnahme eine Meldung machen, mit der man etwas anfangen kann.

        Ein abgelehnter Handschlag ist der wahrscheinlichste Fehler beim Einrichten, und die
        Standardmeldung der Bibliothek zeigt davon nur den Statuscode und eine abgeschnittene
        Kopfzeilenliste. Die Antwort der Konsole trägt aber einen Grund im Rumpf, und der ist beim
        Einrichten mehr wert als alles andere im Protokoll.
        """
        status = getattr(getattr(exc, "response", None), "status_code", None)
        if status == 401:
            return (
                "401 Unauthorized: der Token wird abgelehnt. Häufigste Ursachen: er stammt aus "
                "UniFi Protect oder Network statt aus Access, oder ihm fehlen Berechtigungen - "
                "beim Anlegen unter Access → Einstellungen alle Rechte vergeben, mindestens "
                "Space, Device und System Log."
            )
        if status == 404:
            return (
                "404: die Konsole kennt den Pfad nicht. Läuft die Access-Anwendung auf dieser "
                "Konsole, und ist der Port richtig (Vorgabe 12445)?"
            )
        if status is not None:
            return f"HTTP {status} beim Verbindungsaufbau"
        return repr(exc)[:200]

    async def run(self) -> None:
        backoff = 1.0
        while True:
            try:
                await self._consume()
                backoff = 1.0
            except Exception as exc:
                self.online = False
                self.last_error = self._explain(exc)
                log.warning("unifi access offline", error=self.last_error, url=self.url)
            await asyncio.sleep(backoff)
            backoff = min(MAX_BACKOFF_S, backoff * 2)

    def start(self) -> None:
        self._task = asyncio.create_task(self.run(), name="unifi-access")

    async def stop(self) -> None:
        if self._task is not None:
            self._task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._task
            self._task = None

    def status(self) -> dict[str, Any]:
        return {
            "online": self.online,
            "events": self.events_seen,
            "access_events": self.access_events,
            "unreadable_events": self.unreadable_events,
            "last_event_at": self.last_event_at.isoformat() if self.last_event_at else None,
            "error": self.last_error,
        }
