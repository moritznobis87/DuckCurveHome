"""Mitteilungen auf das Telefon: Web Push.

**Warum überhaupt.** Der Wächter (`hems_core.watch`) sieht, wenn eine Quelle schweigt. Das nützt
nur jemandem, der gerade auf die Wandanzeige sieht - und genau das tat im Oktober 2026 zwei Tage
lang niemand. Eine Mitteilung geht den Weg umgekehrt: Sie sucht sich den Menschen.

**Das Schlüsselpaar erzeugt der Dienst selbst.** Web Push verlangt ein VAPID-Paar; der private
Teil ist ein Geheimnis. Es steht deshalb nicht in der Umgebung und schon gar nicht im Repository,
sondern entsteht beim ersten Gebrauch und bleibt in der Datenbank (`push_keys`). Niemand muss es
sehen, kopieren oder eintragen. Geht es verloren, melden sich die Geräte beim nächsten Besuch der
Seite neu an.

**Was gespeichert wird, ist kein Konto.** Ein Abonnement ist eine Adresse beim Push-Dienst des
Browsers plus zwei Schlüssel, mit denen der Inhalt für dieses Gerät verschlüsselt wird. Der Dienst
erfährt vom Inhalt nichts; wir erfahren vom Gerät nichts außer dieser Adresse.
"""

from __future__ import annotations

import asyncio
import base64
import json
from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any, Protocol

import structlog
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

log = structlog.get_logger("push")

#: So lange darf eine Mitteilung beim Push-Dienst liegen, wenn das Gerät aus ist. Ein Ausfall von
#: gestern ist morgen noch interessant, eine Woche später nicht.
TTL_S = 12 * 3600


@dataclass(frozen=True)
class Mitteilung:
    """Was auf dem Telefon steht. `tag` ersetzt eine ältere Mitteilung derselben Sache."""

    title: str
    body: str
    tag: str = "dch"
    url: str = "/"

    def payload(self) -> str:
        return json.dumps(
            {"title": self.title, "body": self.body, "tag": self.tag, "url": self.url}
        )


class Abo(Protocol):
    endpoint: str
    p256dh: str
    auth: str


class PushStore(Protocol):
    """Was der Dienst zum Speichern braucht. `SqlRepositories` erfüllt das; im Demo-Modus
    übernimmt `MemoryPushStore`, damit die Oberfläche auch ohne Datenbank zu bedienen ist."""

    async def push_key(self) -> tuple[str, str] | None: ...
    async def save_push_key(self, private_key: str, public_key: str) -> None: ...
    async def add_push_subscription(
        self, endpoint: str, p256dh: str, auth: str, label: str = ""
    ) -> None: ...
    async def push_subscriptions(self) -> list[Any]: ...
    async def drop_push_subscription(self, endpoint: str) -> bool: ...
    async def push_delivered(self, endpoint: str, ok: bool) -> None: ...


@dataclass
class _Eintrag:
    endpoint: str
    p256dh: str
    auth: str
    label: str = ""
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))
    last_ok_at: datetime | None = None
    failures: int = 0


class MemoryPushStore:
    """Dasselbe im Arbeitsspeicher, für den Demo-Modus ohne Datenbank."""

    def __init__(self) -> None:
        self._key: tuple[str, str] | None = None
        self._abos: dict[str, _Eintrag] = {}

    async def push_key(self) -> tuple[str, str] | None:
        return self._key

    async def save_push_key(self, private_key: str, public_key: str) -> None:
        self._key = (private_key, public_key)

    async def add_push_subscription(
        self, endpoint: str, p256dh: str, auth: str, label: str = ""
    ) -> None:
        self._abos[endpoint] = _Eintrag(endpoint, p256dh, auth, label)

    async def push_subscriptions(self) -> list[Any]:
        return list(self._abos.values())

    async def drop_push_subscription(self, endpoint: str) -> bool:
        return self._abos.pop(endpoint, None) is not None

    async def push_delivered(self, endpoint: str, ok: bool) -> None:
        eintrag = self._abos.get(endpoint)
        if eintrag is None:
            return
        if ok:
            eintrag.last_ok_at = datetime.now(UTC)
            eintrag.failures = 0
        else:
            eintrag.failures += 1


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def erzeuge_paar() -> tuple[str, str]:
    """Ein frisches VAPID-Paar: (privater Skalar, öffentlicher Punkt), beide base64url.

    Der private Teil ist der rohe 32-Byte-Skalar, weil `pywebpush` genau diese Form annimmt; der
    öffentliche ist der unkomprimierte Punkt, den der Browser als `applicationServerKey` erwartet.
    """
    key = ec.generate_private_key(ec.SECP256R1())
    privat = key.private_numbers().private_value.to_bytes(32, "big")
    oeffentlich = key.public_key().public_bytes(
        encoding=serialization.Encoding.X962,
        format=serialization.PublicFormat.UncompressedPoint,
    )
    return _b64(privat), _b64(oeffentlich)


class PushService:
    def __init__(self, store: PushStore, subject: str) -> None:
        self.store = store
        self.subject = subject
        self._lock = asyncio.Lock()

    async def keys(self) -> tuple[str, str]:
        """Das Paar des Dienstes, beim ersten Mal erzeugt. Unter Schloss, damit zwei gleichzeitige
        Anfragen nicht zwei Paare anlegen und das zweite das erste ungültig macht."""
        async with self._lock:
            vorhanden = await self.store.push_key()
            if vorhanden is not None:
                return vorhanden
            privat, oeffentlich = erzeuge_paar()
            await self.store.save_push_key(privat, oeffentlich)
            log.info("vapid key created")
            return privat, oeffentlich

    async def public_key(self) -> str:
        return (await self.keys())[1]

    async def subscribe(self, endpoint: str, p256dh: str, auth: str, label: str = "") -> None:
        await self.store.add_push_subscription(endpoint, p256dh, auth, label)

    async def unsubscribe(self, endpoint: str) -> bool:
        return await self.store.drop_push_subscription(endpoint)

    async def count(self) -> int:
        return len(await self.store.push_subscriptions())

    async def send(self, mitteilung: Mitteilung) -> int:
        """An alle angemeldeten Geräte. Gibt zurück, wie viele es erreicht hat.

        Ein Endpunkt, den der Push-Dienst mit 404 oder 410 beantwortet, gibt es nicht mehr: Das
        Gerät wurde zurückgesetzt oder die Erlaubnis entzogen. Er wird sofort gelöscht, sonst
        sammelt sich hier über Jahre eine Liste von Adressen, die nie wieder jemanden erreichen.
        """
        abos = await self.store.push_subscriptions()
        if not abos:
            return 0
        privat, _ = await self.keys()
        erreicht = 0
        for abo in abos:
            ok, weg = await asyncio.to_thread(self._send_one, abo, mitteilung, privat)
            if weg:
                await self.store.drop_push_subscription(abo.endpoint)
                log.info("push subscription gone", endpoint=abo.endpoint[:40])
                continue
            await self.store.push_delivered(abo.endpoint, ok)
            erreicht += 1 if ok else 0
        return erreicht

    def _send_one(self, abo: Abo, mitteilung: Mitteilung, privat: str) -> tuple[bool, bool]:
        """(zugestellt, Endpunkt gibt es nicht mehr). Läuft in einem Faden: `pywebpush` ist synchron."""
        from pywebpush import WebPushException, webpush

        try:
            webpush(
                subscription_info={
                    "endpoint": abo.endpoint,
                    "keys": {"p256dh": abo.p256dh, "auth": abo.auth},
                },
                data=mitteilung.payload(),
                vapid_private_key=privat,
                vapid_claims={"sub": self.subject},
                ttl=TTL_S,
            )
        except WebPushException as exc:
            status = getattr(getattr(exc, "response", None), "status_code", None)
            if status in (404, 410):
                return False, True
            log.warning("push failed", status=status, error=str(exc)[:200])
            return False, False
        except Exception as exc:  # Netz, DNS, alles andere
            log.warning("push error", error=str(exc)[:200])
            return False, False
        return True, False
