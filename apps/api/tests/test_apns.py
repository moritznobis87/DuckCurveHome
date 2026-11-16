"""Mitteilungen an die App: Signierzeichen, Adressen, Verteilung.

Geprüft wird vor allem die **Form der Signatur**. Sie wandert nicht durch fremde Hände wie der
VAPID-Schlüssel, sondern direkt zu Apple - und Apple antwortet auf eine falsch kodierte Signatur
mit `InvalidProviderToken`, ohne zu sagen, was daran falsch ist. Wer den Fehler dann im
Schlüssel, in der Teamkennung und in der Uhr sucht, sucht lange.
"""

from __future__ import annotations

import base64
import json
from typing import Any

import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import (
    Encoding,
    NoEncryption,
    PrivateFormat,
)
from fastapi.testclient import TestClient

from dch_api.application.apns import (
    ApnsAntwort,
    ApnsSchluessel,
    ApnsVersender,
    adresse,
    ist_apns,
    signiere,
    zerlege,
)
from dch_api.application.push import MemoryPushStore, Mitteilung, PushService
from dch_api.main import create_app
from dch_api.settings import Settings


def entpacke(b64: str) -> bytes:
    return base64.urlsafe_b64decode(b64 + "=" * (-len(b64) % 4))


@pytest.fixture
def schluessel() -> ApnsSchluessel:
    """Ein echter P-256-Schlüssel in der Form, in der Apple die .p8-Datei ausgibt."""
    privat = ec.generate_private_key(ec.SECP256R1())
    p8 = privat.private_bytes(
        Encoding.PEM, PrivateFormat.PKCS8, NoEncryption()
    ).decode()
    return ApnsSchluessel(p8=p8, key_id="ABC123DEFG", team_id="1234567890", topic="home.duckcurve.app")


# --------------------------------------------------------------------------- Das Signierzeichen


def test_signierzeichen_hat_die_form_die_apple_erwartet(schluessel: ApnsSchluessel) -> None:
    zeichen = signiere(schluessel, jetzt=1_700_000_000)
    teile = zeichen.split(".")
    assert len(teile) == 3

    kopf = json.loads(entpacke(teile[0]))
    assert kopf == {"alg": "ES256", "kid": "ABC123DEFG", "typ": "JWT"}
    rumpf = json.loads(entpacke(teile[1]))
    assert rumpf == {"iss": "1234567890", "iat": 1_700_000_000}

    # **Die Stelle, an der die meisten Umsetzungen scheitern.** JWS verlangt die beiden Zahlen r
    # und s roh hintereinander, jede genau 32 Byte - nicht die DER-Folge, die `cryptography`
    # zurückgibt. Eine DER-Folge ist 70 bis 72 Byte lang und beginnt mit 0x30.
    signatur = entpacke(teile[2])
    assert len(signatur) == 64, "die Signatur ist nicht r||s mit je 32 Byte"
    assert signatur[0] != 0x30 or len(signatur) == 64


def test_signatur_laesst_sich_mit_dem_oeffentlichen_teil_pruefen(schluessel: ApnsSchluessel) -> None:
    """Die Probe, dass die Umkodierung von DER nach r||s die Signatur nicht zerstört hat."""
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import utils as asym_utils

    zeichen = signiere(schluessel, jetzt=1_700_000_000)
    anfang, _, roh = zeichen.rpartition(".")
    signatur = entpacke(roh)
    r = int.from_bytes(signatur[:32], "big")
    s = int.from_bytes(signatur[32:], "big")
    der = asym_utils.encode_dss_signature(r, s)

    privat = serialization.load_pem_private_key(schluessel.p8.encode(), password=None)
    privat.public_key().verify(der, anfang.encode(), ec.ECDSA(hashes.SHA256()))


def test_ein_schluessel_der_kein_ec_schluessel_ist_wird_gemeldet() -> None:
    from cryptography.hazmat.primitives.asymmetric import rsa

    rsa_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    p8 = rsa_key.private_bytes(Encoding.PEM, PrivateFormat.PKCS8, NoEncryption()).decode()
    falsch = ApnsSchluessel(p8=p8, key_id="A", team_id="B", topic="C")
    with pytest.raises(ValueError, match="kein EC-Schlüssel"):
        signiere(falsch)


# ------------------------------------------------------------------------------- Vollständigkeit


def test_unvollstaendiger_schluessel_sagt_was_fehlt() -> None:
    leer = ApnsSchluessel(p8="", key_id="", team_id="", topic="")
    assert not leer.vollstaendig
    assert "DCH_APNS_KEY_P8" in leer.fehlt_de()
    assert "DCH_APNS_TOPIC" in leer.fehlt_de()

    halb = ApnsSchluessel(p8="x", key_id="y", team_id="", topic="z")
    assert not halb.vollstaendig
    assert halb.fehlt_de() == "Für Mitteilungen an die App fehlt: DCH_APNS_TEAM_ID."

    ganz = ApnsSchluessel(p8="x", key_id="y", team_id="z", topic="t")
    assert ganz.vollstaendig
    assert ganz.fehlt_de() == ""


# ----------------------------------------------------------------------------------- Die Adresse


def test_die_umgebung_steht_in_der_adresse() -> None:
    """Ein Token aus Xcode gilt bei Apple an einer anderen Adresse als eines aus dem App Store.
    Steht die Umgebung in der Adresse, kann ein Haus beide gleichzeitig haben."""
    prod = adresse("abc123", sandbox=False)
    sand = adresse("abc123", sandbox=True)
    assert prod != sand
    assert ist_apns(prod) and ist_apns(sand)
    assert zerlege(prod) == ("abc123", False)
    assert zerlege(sand) == ("abc123", True)


def test_eine_adresse_ohne_umgebung_gilt_als_produktion() -> None:
    assert zerlege("apns://abc123") == ("abc123", False)


def test_web_push_adressen_sind_keine_apns_adressen() -> None:
    assert not ist_apns("https://web.push.apple.com/abc")
    assert not ist_apns("https://fcm.googleapis.com/fcm/send/xyz")


# -------------------------------------------------------------------------------- Die Antworten


@pytest.mark.parametrize(
    ("status", "grund", "weg"),
    [
        (200, "", False),
        (410, "Unregistered", True),
        # Apple schickt BadDeviceToken auch für ein Token der falschen Umgebung - und ein solches
        # erreicht hier nie wieder jemanden.
        (400, "BadDeviceToken", True),
        (403, "InvalidProviderToken", False),
        (429, "TooManyRequests", False),
    ],
)
def test_wann_ein_geraet_geloescht_wird(status: int, grund: str, weg: bool) -> None:
    assert ApnsAntwort(status, grund).weg is weg


def test_ein_schluesselfehler_loescht_kein_geraet() -> None:
    """Nicht das Gerät ist schuld, sondern der Schlüssel. Ein abgelaufener Schlüssel darf nicht
    alle angemeldeten Geräte aus der Liste räumen."""
    for grund in ("InvalidProviderToken", "ExpiredProviderToken", "MissingProviderToken", "TopicDisallowed"):
        antwort = ApnsAntwort(403, grund)
        assert antwort.schluessel_schuld
        assert not antwort.weg


def test_die_saetze_nennen_das_geraet() -> None:
    assert ApnsAntwort(200, "").satz_de("iPad Flur").startswith("iPad Flur: zugestellt")
    assert "nicht mehr angemeldet" in ApnsAntwort(410, "Unregistered").satz_de("iPhone")
    assert "Signierschlüssel" in ApnsAntwort(403, "InvalidProviderToken").satz_de("iPad")
    # Ohne Namen bleibt ein Wort übrig, keine Lücke.
    assert ApnsAntwort(200, "").satz_de("").startswith("Gerät:")


# ---------------------------------------------------------------------------- Anmelden im Dienst


@pytest.mark.asyncio
async def test_anmelden_speichert_als_abonnement() -> None:
    dienst = PushService(MemoryPushStore(), "mailto:test@example.org")
    await dienst.subscribe_apns("abc123", label="iPad Flur", sandbox=True)
    abos = await dienst.store.push_subscriptions()
    assert len(abos) == 1
    assert ist_apns(abos[0].endpoint)
    assert abos[0].label == "iPad Flur"
    # Keine Schlüssel: APNs verschlüsselt selbst.
    assert abos[0].p256dh == "" and abos[0].auth == ""


@pytest.mark.asyncio
async def test_ein_token_steht_nie_in_beiden_umgebungen() -> None:
    """Wer eine App aus Xcode durch eine aus TestFlight ersetzt, bekommt ein neues Token - aber
    das alte bliebe stehen und würde nie wieder jemanden erreichen."""
    dienst = PushService(MemoryPushStore(), "mailto:test@example.org")
    await dienst.subscribe_apns("abc123", sandbox=True)
    await dienst.subscribe_apns("abc123", sandbox=False)
    abos = await dienst.store.push_subscriptions()
    assert len(abos) == 1
    assert zerlege(abos[0].endpoint) == ("abc123", False)


@pytest.mark.asyncio
async def test_abmelden_trifft_beide_umgebungen() -> None:
    dienst = PushService(MemoryPushStore(), "mailto:test@example.org")
    await dienst.subscribe_apns("abc123", sandbox=True)
    assert await dienst.unsubscribe_apns("abc123")
    assert await dienst.store.push_subscriptions() == []
    # Ein zweites Mal ist kein Fehler, nur kein Treffer.
    assert not await dienst.unsubscribe_apns("abc123")


@pytest.mark.asyncio
async def test_ein_leeres_token_wird_nicht_angemeldet() -> None:
    dienst = PushService(MemoryPushStore(), "mailto:test@example.org")
    await dienst.subscribe_apns("   ")
    assert await dienst.store.push_subscriptions() == []


# ------------------------------------------------------------------------------- Die Verteilung


class FalscherVersender:
    """Ein Versender, der nicht ins Netz geht und mitschreibt, was er bekommen hätte."""

    def __init__(self, antwort: ApnsAntwort) -> None:
        self.antwort = antwort
        self.gesendet: list[tuple[str, str, str, str, str]] = []

    @property
    def bereit(self) -> bool:
        return True

    async def sende(self, endpunkt: str, titel: str, rumpf: str, tag: str, url: str) -> ApnsAntwort:
        self.gesendet.append((endpunkt, titel, rumpf, tag, url))
        return self.antwort


@pytest.mark.asyncio
async def test_eine_mitteilung_nimmt_den_weg_ihrer_adresse() -> None:
    """**Das ist die Stelle, um die der ganze Entwurf gebaut ist.** Zwei Wege, eine Entscheidung
    an der Adresse - und `send_bericht` muss von den beiden nichts wissen."""
    versender = FalscherVersender(ApnsAntwort(200, ""))
    dienst = PushService(MemoryPushStore(), "mailto:test@example.org", apns=versender)  # type: ignore[arg-type]
    await dienst.subscribe_apns("abc123", label="iPad Flur")

    bericht = await dienst.send_bericht(
        Mitteilung(title="Der Puffer ist kalt", body="Seit zwei Stunden", tag="puffer", url="/waerme/anlage")
    )
    assert len(bericht) == 1
    assert bericht[0].ok
    assert bericht[0].label == "iPad Flur"
    # Der Inhalt kommt vollständig an - samt Ziel, damit ein Tipp auf die Mitteilung zur Seite führt.
    endpunkt, titel, rumpf, tag, url = versender.gesendet[0]
    assert ist_apns(endpunkt)
    assert titel == "Der Puffer ist kalt"
    assert rumpf == "Seit zwei Stunden"
    assert tag == "puffer"
    assert url == "/waerme/anlage"


@pytest.mark.asyncio
async def test_ohne_schluessel_sagt_der_bericht_warum() -> None:
    """Ein Haus ohne APNs-Schlüssel ist kein Fehlerfall - aber die Probe soll sagen, woran es liegt."""
    dienst = PushService(MemoryPushStore(), "mailto:test@example.org", apns=None)
    await dienst.subscribe_apns("abc123", label="iPad")
    bericht = await dienst.send_bericht(Mitteilung(title="t", body="b"))
    assert len(bericht) == 1
    assert not bericht[0].ok
    assert "APNs-Schlüssel" in bericht[0].grund


@pytest.mark.asyncio
async def test_ein_verschwundenes_geraet_wird_geloescht() -> None:
    versender = FalscherVersender(ApnsAntwort(410, "Unregistered"))
    dienst = PushService(MemoryPushStore(), "mailto:test@example.org", apns=versender)  # type: ignore[arg-type]
    await dienst.subscribe_apns("abc123")
    bericht = await dienst.send_bericht(Mitteilung(title="t", body="b"))
    assert bericht[0].weg
    assert await dienst.store.push_subscriptions() == []


@pytest.mark.asyncio
async def test_ein_schluesselfehler_laesst_das_geraet_stehen() -> None:
    versender = FalscherVersender(ApnsAntwort(403, "InvalidProviderToken"))
    dienst = PushService(MemoryPushStore(), "mailto:test@example.org", apns=versender)  # type: ignore[arg-type]
    await dienst.subscribe_apns("abc123")
    bericht = await dienst.send_bericht(Mitteilung(title="t", body="b"))
    assert not bericht[0].ok
    assert not bericht[0].weg
    assert len(await dienst.store.push_subscriptions()) == 1


# ------------------------------------------------------------------------------- Die Endpunkte


def test_endpunkte_melden_an_und_ab() -> None:
    app = create_app(Settings(mode="demo", api_token=""))
    with TestClient(app) as klient:
        antwort = klient.post(
            "/api/v1/push/apns/subscribe",
            json={"token": "a" * 64, "label": "iPad Flur", "sandbox": True},
        )
        assert antwort.status_code == 200
        daten = antwort.json()
        assert daten["ok"] is True
        assert daten["devices"] == 1
        # Ohne Schlüssel sagt der Satz, dass noch nichts ankommen kann.
        assert "Signierschlüssel" in daten["message_de"]

        geraete = klient.get("/api/v1/push/geraete").json()
        assert any(g["label"] == "iPad Flur" for g in geraete["devices"])

        ab = klient.post("/api/v1/push/apns/unsubscribe", json={"token": "a" * 64})
        assert ab.status_code == 200
        assert ab.json()["ok"] is True
        assert klient.get("/api/v1/push/geraete").json()["devices"] == []


def test_ein_zu_kurzes_token_wird_abgewiesen() -> None:
    app = create_app(Settings(mode="demo", api_token=""))
    with TestClient(app) as klient:
        assert klient.post("/api/v1/push/apns/subscribe", json={"token": "ab"}).status_code == 422


def test_der_versender_entsteht_nur_mit_vollstaendigem_schluessel(schluessel: ApnsSchluessel) -> None:
    from dch_api.main import apns_versender

    assert apns_versender(Settings(mode="demo")) is None
    ganz = Settings(
        mode="demo",
        apns_key_p8=schluessel.p8,
        apns_key_id=schluessel.key_id,
        apns_team_id=schluessel.team_id,
        apns_topic=schluessel.topic,
    )
    versender = apns_versender(ganz)
    assert isinstance(versender, ApnsVersender)
    assert versender.bereit


def test_ein_signierzeichen_wird_wiederverwendet(schluessel: ApnsSchluessel) -> None:
    """Ein Schlüssel gilt bei Apple eine Stunde. Für jede Mitteilung neu zu signieren wäre eine
    Elliptische-Kurven-Operation je Mitteilung - und APNs erwartet ohnehin, dass ein Dienst die
    Verbindung hält."""
    versender = ApnsVersender(schluessel)
    erstes = versender._zeichen()
    assert versender._zeichen() == erstes
    # Nach Ablauf ein neues. Der Zeitstempel im Rumpf unterscheidet sie.
    versender._jwt_bis = 0.0
    import time

    time.sleep(1.1)
    assert versender._zeichen() != erstes
