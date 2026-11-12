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
import re
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


#: Der Platzhalter aus den Einstellungen. Eine echte Adresse gehört nicht ins Repository.
PLATZHALTER = "mailto:duck-curve-home@example.invalid"
#: Eine Herkunft, wie der Browser sie nennt: https, ein Rechnername, höchstens ein Port.
HERKUNFT = re.compile(r"^https://[a-z0-9]([a-z0-9.-]*[a-z0-9])?(:\d{1,5})?$")


@dataclass(frozen=True)
class Zustellung:
    """Was aus einer Mitteilung an ein Gerät geworden ist, mit dem Grund, wenn sie nicht ankam.

    Bis zum 12.11.2026 gab `send` nur eine Zahl zurück, und der Grund stand im Protokoll des
    Dienstes. Auf der Seite hieß eine gescheiterte Probe schlicht „nicht angekommen", und wer
    wissen wollte, warum, hätte das Protokoll lesen müssen (Nutzer am 12.11.2026: „Ich bekomme
    gar keine Push-Nachrichten"). Jetzt steht der Grund da, wo die Probe ausgelöst wird.
    """

    label: str
    ok: bool
    #: Der Push-Dienst kennt das Abonnement nicht mehr; es ist gelöscht.
    weg: bool = False
    status: int | None = None
    grund: str = ""

    @property
    def satz_de(self) -> str:
        wer = self.label or "Gerät"
        if self.ok:
            return f"{wer}: angenommen. Kommt nichts an, liegt es an den Einstellungen des Geräts."
        if self.weg:
            return (
                f"{wer}: Das Abonnement gibt es beim Push-Dienst nicht mehr. Es ist gelöscht; "
                "bitte auf dem Gerät neu einschalten."
            )
        if self.status == 403:
            return (
                f"{wer}: Der Push-Dienst lehnt die Mitteilung ab (403 {self.grund}). Meist hilft "
                "es, die Mitteilungen auf dem Gerät aus- und wieder einzuschalten."
            )
        if self.status is not None:
            return f"{wer}: Der Push-Dienst antwortet mit {self.status} {self.grund}".rstrip() + "."
        return f"{wer}: Die Mitteilung ließ sich nicht verschicken ({self.grund})."


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
    async def push_origin(self) -> str | None: ...
    async def save_push_origin(self, origin: str) -> None: ...


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
        self._herkunft: str | None = None

    async def push_origin(self) -> str | None:
        return self._herkunft

    async def save_push_origin(self, origin: str) -> None:
        self._herkunft = origin

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
        #: Der letzte Grund je Endpunkt, warum eine Mitteilung nicht ankam. Im Arbeitsspeicher:
        #: nach einem Neustart zeigt die nächste Probe ihn wieder.
        self._letzter_fehler: dict[str, str] = {}

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

    async def absender(self) -> str:
        """Wer die Mitteilung schickt, für den VAPID-Anspruch `sub`.

        Eine gesetzte Adresse (`DCH_PUSH_SUBJECT`) gilt. Sonst die eigene Herkunft der
        Oberfläche, sobald sich ein Gerät angemeldet hat: sie ist eine gültige Adresse, und der
        Push-Dienst kennt sie ohnehin, denn das Abonnement hängt an ihr. Der Platzhalter mit der
        reservierten Endung `.invalid` bleibt nur, solange es nichts Besseres gibt. Apple ist
        beim Absender strenger als andere Dienste; ob es diese Endung ablehnt, ist nicht belegt,
        und mit einer echten Herkunft stellt sich die Frage nicht.
        """
        if self.subject != PLATZHALTER:
            return self.subject
        return await self.store.push_origin() or self.subject

    async def subscribe(
        self, endpoint: str, p256dh: str, auth: str, label: str = "", origin: str = ""
    ) -> None:
        await self.store.add_push_subscription(endpoint, p256dh, auth, label)
        self._letzter_fehler.pop(endpoint, None)
        if HERKUNFT.fullmatch(origin):
            await self.store.save_push_origin(origin)

    async def unsubscribe(self, endpoint: str) -> bool:
        self._letzter_fehler.pop(endpoint, None)
        return await self.store.drop_push_subscription(endpoint)

    async def count(self) -> int:
        return len(await self.store.push_subscriptions())

    async def geraete(self) -> list[tuple[Any, str]]:
        """Die angemeldeten Geräte, je mit dem letzten Grund eines Fehlschlags (oder leer)."""
        return [
            (abo, self._letzter_fehler.get(abo.endpoint, ""))
            for abo in await self.store.push_subscriptions()
        ]

    async def send(self, mitteilung: Mitteilung) -> int:
        """An alle angemeldeten Geräte. Gibt zurück, wie viele es erreicht hat."""
        return sum(1 for z in await self.send_bericht(mitteilung) if z.ok)

    async def send_bericht(self, mitteilung: Mitteilung) -> list[Zustellung]:
        """An alle angemeldeten Geräte, mit dem Ergebnis je Gerät.

        Ein Endpunkt, den der Push-Dienst mit 404 oder 410 beantwortet, gibt es nicht mehr: Das
        Gerät wurde zurückgesetzt oder die Erlaubnis entzogen. Er wird sofort gelöscht, sonst
        sammelt sich hier über Jahre eine Liste von Adressen, die nie wieder jemanden erreichen.
        """
        abos = await self.store.push_subscriptions()
        if not abos:
            return []
        privat, _ = await self.keys()
        absender = await self.absender()
        bericht: list[Zustellung] = []
        for abo in abos:
            z = await asyncio.to_thread(self._send_one, abo, mitteilung, privat, absender)
            bericht.append(z)
            if z.weg:
                await self.store.drop_push_subscription(abo.endpoint)
                self._letzter_fehler.pop(abo.endpoint, None)
                log.info("push subscription gone", endpoint=abo.endpoint[:40])
                continue
            await self.store.push_delivered(abo.endpoint, z.ok)
            if z.ok:
                self._letzter_fehler.pop(abo.endpoint, None)
            else:
                self._letzter_fehler[abo.endpoint] = z.satz_de
        return bericht

    def _send_one(self, abo: Abo, mitteilung: Mitteilung, privat: str, absender: str) -> Zustellung:
        """Eine Mitteilung an ein Gerät. Läuft in einem Faden: `pywebpush` ist synchron."""
        from pywebpush import WebPushException, webpush

        label = str(getattr(abo, "label", "") or "")
        try:
            webpush(
                subscription_info={
                    "endpoint": abo.endpoint,
                    "keys": {"p256dh": abo.p256dh, "auth": abo.auth},
                },
                data=mitteilung.payload(),
                vapid_private_key=privat,
                vapid_claims={"sub": absender},
                ttl=TTL_S,
            )
        except WebPushException as exc:
            antwort = getattr(exc, "response", None)
            status = getattr(antwort, "status_code", None)
            # Der Rumpf sagt, was der Dienst auszusetzen hat (Apple: {"reason":"BadJwtToken"}).
            grund = str(getattr(antwort, "text", "") or "").strip()[:120]
            if status in (404, 410):
                return Zustellung(label, ok=False, weg=True, status=status, grund=grund)
            log.warning("push failed", status=status, error=str(exc)[:200])
            return Zustellung(label, ok=False, status=status, grund=grund or str(exc)[:120])
        except Exception as exc:  # Netz, DNS, alles andere
            log.warning("push error", error=str(exc)[:200])
            return Zustellung(label, ok=False, grund=str(exc)[:120])
        return Zustellung(label, ok=True)
