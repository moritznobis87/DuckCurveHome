"""Mitteilungen an die iOS-App: Apple Push Notification service.

**Warum es diesen zweiten Weg gibt.** `push.py` verschickt Web Push mit einem VAPID-Paar. Das ist
für das Dashboard im Browser der richtige Weg und für die App keiner: eine iOS-App kann Web Push
nicht empfangen. Apple lässt Mitteilungen nur über APNs zu, und dort ist die Adresse kein
Endpunkt beim Push-Dienst des Browsers, sondern ein Gerätetoken, das das Betriebssystem vergibt.

**Wie es sich einfügt, ohne etwas umzubauen.** Ein APNs-Gerät wird als Abonnement gespeichert wie
jedes andere, nur mit einer Adresse der Form ``apns://<token>?env=sandbox``. Damit gelten für es
alle Regeln, die schon da sind: es steht in der Geräteliste, sein Zustellprotokoll wird geführt,
ein 410 löscht es. `PushService` sieht an der Adresse, welchen Weg eine Mitteilung nimmt. Kein
neues Schema, keine Migration, keine zweite Geräteverwaltung.

**Was der Hausherr beschaffen muss.** Einen Signierschlüssel aus seinem Apple-Developer-Konto:
eine ``.p8``-Datei, die Schlüsselkennung und die Teamkennung. Ohne den kann kein Dienst auf der
Welt eine Mitteilung an diese App schicken - das ist Apples Entwurf und nicht zu umgehen. Es ist
zugleich die einzige Stelle des ganzen Projekts, an der etwas von außen beschafft werden muss,
das sich nicht selbst erzeugen lässt: das VAPID-Paar für Web Push erzeugt der Dienst sich selbst
(siehe `push.py`), einen APNs-Schlüssel nicht.

Eingetragen wird er als::

    DCH_APNS_KEY_P8="-----BEGIN PRIVATE KEY-----\\n…"   # Inhalt der .p8-Datei
    DCH_APNS_KEY_ID="ABC123DEFG"
    DCH_APNS_TEAM_ID="1234567890"
    DCH_APNS_TOPIC="home.duckcurve.app"                  # die Bundle-Kennung der App

Fehlt einer davon, bleibt der Weg zu und die App sagt das auf ihrer Seite „Mitteilungen".
"""

from __future__ import annotations

import base64
import json
import time
from dataclasses import dataclass
from typing import Any
from urllib.parse import parse_qs, urlsplit

import structlog
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric import utils as asym_utils

log = structlog.get_logger("apns")

#: Das Vorzeichen einer APNs-Adresse in der Abonnementtabelle.
PRAEFIX = "apns://"

#: So lange darf eine Mitteilung bei Apple liegen, wenn das Gerät aus ist. Dieselbe Frist wie bei
#: Web Push: ein Ausfall von gestern ist morgen noch interessant, eine Woche später nicht.
TTL_S = 12 * 3600

#: Ein Signierschlüssel gilt bei Apple höchstens eine Stunde. Erneuert wird nach fünfzig Minuten -
#: früh genug, dass keine Mitteilung an einem gerade abgelaufenen Token scheitert.
JWT_GUELTIG_S = 50 * 60


def adresse(token: str, sandbox: bool) -> str:
    """Die Adresse, unter der ein Gerätetoken als Abonnement gespeichert wird.

    Die Umgebung gehört dazu und nicht in ein zweites Feld: ein Token aus einem
    Entwicklungsbau gilt bei Apple an einer anderen Adresse als eines aus dem App Store, und wer
    das verwechselt, bekommt ``BadDeviceToken`` ohne weitere Auskunft. Steht die Umgebung in der
    Adresse, kann ein Haus beide gleichzeitig haben - das iPad aus TestFlight und das iPhone aus
    Xcode.
    """
    return f"{PRAEFIX}{token}?env={'sandbox' if sandbox else 'prod'}"


def ist_apns(endpunkt: str) -> bool:
    return endpunkt.startswith(PRAEFIX)


def zerlege(endpunkt: str) -> tuple[str, bool]:
    """Aus der Adresse das Token und die Umgebung. Ohne Angabe gilt Produktion."""
    teile = urlsplit(endpunkt)
    token = (teile.netloc or teile.path.lstrip("/")).strip()
    umgebung = parse_qs(teile.query).get("env", ["prod"])[0]
    return token, umgebung == "sandbox"


@dataclass(frozen=True, slots=True)
class ApnsSchluessel:
    """Der Signierschlüssel aus dem Apple-Developer-Konto."""

    p8: str
    key_id: str
    team_id: str
    topic: str

    @property
    def vollstaendig(self) -> bool:
        return all(teil.strip() for teil in (self.p8, self.key_id, self.team_id, self.topic))

    def fehlt_de(self) -> str:
        """Was fehlt, in einem Satz - für die Seite „Mitteilungen" in der App."""
        fehlend = [
            name
            for name, wert in (
                ("DCH_APNS_KEY_P8", self.p8),
                ("DCH_APNS_KEY_ID", self.key_id),
                ("DCH_APNS_TEAM_ID", self.team_id),
                ("DCH_APNS_TOPIC", self.topic),
            )
            if not wert.strip()
        ]
        if not fehlend:
            return ""
        return "Für Mitteilungen an die App fehlt: " + ", ".join(fehlend) + "."


def _b64(rohdaten: bytes) -> str:
    return base64.urlsafe_b64encode(rohdaten).rstrip(b"=").decode()


def signiere(schluessel: ApnsSchluessel, jetzt: float | None = None) -> str:
    """Das Signierzeichen (JWT) für APNs, mit ES256 unterschrieben.

    **Hier steckt die Falle, an der die meisten Umsetzungen scheitern.** `cryptography`
    unterschreibt ECDSA im DER-Format - eine Folge mit zwei ganzen Zahlen, variabler Länge und
    Längenbytes davor. JWS verlangt etwas anderes: die beiden Zahlen ``r`` und ``s`` roh
    hintereinander, jede genau 32 Byte, mit Nullen vorne aufgefüllt. Wer die DER-Folge
    base64-kodiert und abschickt, bekommt von Apple ``InvalidProviderToken`` und sucht den Fehler
    im Schlüssel, in der Teamkennung und in der Uhr - überall, nur nicht hier.
    """
    jetzt = time.time() if jetzt is None else jetzt
    kopf = {"alg": "ES256", "kid": schluessel.key_id.strip(), "typ": "JWT"}
    rumpf = {"iss": schluessel.team_id.strip(), "iat": int(jetzt)}
    eng = (",", ":")
    anfang = (
        f"{_b64(json.dumps(kopf, separators=eng).encode())}."
        f"{_b64(json.dumps(rumpf, separators=eng).encode())}"
    )

    privat = serialization.load_pem_private_key(schluessel.p8.encode(), password=None)
    if not isinstance(privat, ec.EllipticCurvePrivateKey):
        raise ValueError(
            "Der APNs-Schlüssel ist kein EC-Schlüssel (erwartet: P-256 aus der .p8-Datei)."
        )
    der = privat.sign(anfang.encode(), ec.ECDSA(hashes.SHA256()))
    r, s = asym_utils.decode_dss_signature(der)
    roh = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    return f"{anfang}.{_b64(roh)}"


@dataclass(frozen=True, slots=True)
class ApnsAntwort:
    """Was Apple auf eine Mitteilung geantwortet hat."""

    status: int
    grund: str

    @property
    def ok(self) -> bool:
        return self.status == 200

    @property
    def weg(self) -> bool:
        """Das Gerät gibt es nicht mehr - zurückgesetzt, App gelöscht, Erlaubnis entzogen.

        ``410 Unregistered`` ist die saubere Auskunft. ``400 BadDeviceToken`` kommt dazu, weil
        Apple sie auch für ein Token schickt, das zur falschen Umgebung gehört - und ein solches
        Token wird in dieser Umgebung nie wieder jemanden erreichen.
        """
        return self.status == 410 or self.grund == "BadDeviceToken"

    @property
    def schluessel_schuld(self) -> bool:
        """Nicht das Gerät ist schuld, sondern der Schlüssel. Soll nicht das Abo löschen."""
        return self.grund in {
            "InvalidProviderToken",
            "ExpiredProviderToken",
            "MissingProviderToken",
            "TopicDisallowed",
        }

    def satz_de(self, label: str) -> str:
        wer = label or "Gerät"
        if self.ok:
            return f"{wer}: zugestellt."
        if self.weg:
            return f"{wer}: ist nicht mehr angemeldet."
        if self.schluessel_schuld:
            return f"{wer}: Apple nimmt den Signierschlüssel nicht an ({self.grund})."
        return f"{wer}: Apple antwortet mit {self.status} {self.grund}".rstrip() + "."


class ApnsVersender:
    """Verschickt Mitteilungen über APNs. Hält einen Signierschlüssel und zwei Verbindungen.

    **Warum zwei Verbindungen.** Sandbox und Produktion sind verschiedene Rechner bei Apple, und
    ein Haus kann Geräte in beiden haben. Die Verbindungen bleiben offen: APNs ist HTTP/2 und
    erwartet, dass ein Dienst nicht für jede Mitteilung neu anklopft.
    """

    PRODUKTION = "https://api.push.apple.com"
    SANDBOX = "https://api.sandbox.push.apple.com"

    def __init__(self, schluessel: ApnsSchluessel) -> None:
        self.schluessel = schluessel
        self._jwt: str = ""
        self._jwt_bis: float = 0.0
        self._klienten: dict[bool, Any] = {}

    @property
    def bereit(self) -> bool:
        return self.schluessel.vollstaendig

    def _zeichen(self) -> str:
        jetzt = time.time()
        if self._jwt and jetzt < self._jwt_bis:
            return self._jwt
        self._jwt = signiere(self.schluessel, jetzt)
        self._jwt_bis = jetzt + JWT_GUELTIG_S
        return self._jwt

    async def _klient(self, sandbox: bool) -> Any:
        vorhanden = self._klienten.get(sandbox)
        if vorhanden is not None:
            return vorhanden
        import httpx

        # HTTP/2 ist bei APNs nicht wahlfrei. Ohne `h2` antwortet httpx mit HTTP/1.1, und Apple
        # lehnt die Verbindung ab - die Fehlermeldung nennt dabei nicht den Grund.
        klient = httpx.AsyncClient(
            base_url=self.SANDBOX if sandbox else self.PRODUKTION,
            http2=True,
            timeout=httpx.Timeout(10.0, connect=5.0),
        )
        self._klienten[sandbox] = klient
        return klient

    async def schliesse(self) -> None:
        for klient in self._klienten.values():
            await klient.aclose()
        self._klienten.clear()

    async def sende(self, endpunkt: str, titel: str, rumpf: str, tag: str, url: str) -> ApnsAntwort:
        """Eine Mitteilung an ein Gerät.

        Der Inhalt ist derselbe wie bei Web Push (siehe `Mitteilung.payload`), nur in Apples
        Form: Titel und Rumpf unter ``aps.alert``, das Ziel als eigenes Feld daneben. Der ``tag``
        wird ``apns-collapse-id``: eine neue Mitteilung derselben Sache ersetzt die alte auf dem
        Sperrbildschirm, statt sich darunter zu stapeln.
        """
        if not self.bereit:
            return ApnsAntwort(0, "MissingProviderToken")
        token, sandbox = zerlege(endpunkt)
        if not token:
            return ApnsAntwort(0, "BadDeviceToken")

        inhalt = {
            "aps": {
                "alert": {"title": titel, "body": rumpf},
                "sound": "default",
                "thread-id": tag,
            },
            "url": url,
        }
        kopfzeilen = {
            "authorization": f"bearer {self._zeichen()}",
            "apns-topic": self.schluessel.topic.strip(),
            "apns-push-type": "alert",
            "apns-expiration": str(int(time.time()) + TTL_S),
            # Die Mitteilungen dieses Dienstes sind Warnungen, keine Werbung: sie dürfen das
            # Gerät wecken. 5 wäre „irgendwann", 10 ist „jetzt".
            "apns-priority": "10",
            "apns-collapse-id": tag[:64],
        }
        try:
            klient = await self._klient(sandbox)
            antwort = await klient.post(f"/3/device/{token}", json=inhalt, headers=kopfzeilen)
        except Exception as exc:
            return ApnsAntwort(0, str(exc)[:120])

        if antwort.status_code == 200:
            return ApnsAntwort(200, "")
        grund = ""
        try:
            grund = str(antwort.json().get("reason", ""))
        except Exception:
            grund = (antwort.text or "").strip()[:120]
        # Ein abgelaufenes Signierzeichen wird einmal erneuert und die Mitteilung wiederholt:
        # das ist der Normalfall nach fünfzig Minuten Ruhe und kein Fehler, den jemand lesen muss.
        if grund == "ExpiredProviderToken":
            self._jwt = ""
            self._jwt_bis = 0.0
            kopfzeilen["authorization"] = f"bearer {self._zeichen()}"
            try:
                antwort = await klient.post(f"/3/device/{token}", json=inhalt, headers=kopfzeilen)
            except Exception as exc:
                return ApnsAntwort(0, str(exc)[:120])
            if antwort.status_code == 200:
                return ApnsAntwort(200, "")
            try:
                grund = str(antwort.json().get("reason", ""))
            except Exception:
                grund = (antwort.text or "").strip()[:120]
        return ApnsAntwort(antwort.status_code, grund)
