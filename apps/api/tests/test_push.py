"""Web Push: Schlüssel, Anmeldungen, Zustellung.

Geprüft wird vor allem die Form des Schlüssels. Er wandert durch drei fremde Hände - `py_vapid`,
`pywebpush`, den Browser -, und jede erwartet eine andere Darstellung derselben Zahl. Ein falsch
kodierter Schlüssel fällt sonst erst auf, wenn die erste echte Mitteilung ausbleibt.
"""

from __future__ import annotations

import base64
from typing import Any

import pytest
from fastapi.testclient import TestClient

from dch_api.application.push import (
    PLATZHALTER,
    MemoryPushStore,
    Mitteilung,
    PushService,
    erzeuge_paar,
    tauglich,
)
from dch_api.main import create_app
from dch_api.settings import Settings


def entpacke(b64: str) -> bytes:
    return base64.urlsafe_b64decode(b64 + "=" * (-len(b64) % 4))


def test_schluesselpaar_hat_die_form_die_alle_erwarten() -> None:
    privat, oeffentlich = erzeuge_paar()
    # Der private Teil ist der rohe Skalar: 32 Byte. Der öffentliche ist der unkomprimierte
    # Punkt: 65 Byte, beginnend mit 0x04. Genau das erwartet der Browser als applicationServerKey.
    assert len(entpacke(privat)) == 32
    roh = entpacke(oeffentlich)
    assert len(roh) == 65 and roh[0] == 0x04
    # Kein Füllzeichen: base64url ohne "=" ist, was die Browser-API annimmt.
    assert "=" not in privat and "=" not in oeffentlich

    # Und pywebpush muss ihn lesen können, ohne eine Datei zu sehen.
    from py_vapid import Vapid01

    assert Vapid01.from_string(private_key=privat) is not None


async def test_der_dienst_erzeugt_sein_paar_einmal() -> None:
    push = PushService(MemoryPushStore(), "mailto:x@example.invalid")
    erst = await push.keys()
    nochmal = await push.keys()
    assert erst == nochmal


async def test_anmelden_abmelden_zaehlen() -> None:
    push = PushService(MemoryPushStore(), "mailto:x@example.invalid")
    await push.subscribe("https://push.example/a", "p", "a", "iPhone")
    await push.subscribe("https://push.example/a", "p", "a", "iPhone")
    assert await push.count() == 1  # dasselbe Gerät klingelt nicht zweimal
    await push.subscribe("https://push.example/b", "p", "a", "iPad")
    assert await push.count() == 2
    assert await push.unsubscribe("https://push.example/a") is True
    assert await push.unsubscribe("https://push.example/a") is False
    assert await push.count() == 1


async def test_zustellung_und_verschwundene_geraete(monkeypatch: pytest.MonkeyPatch) -> None:
    push = PushService(MemoryPushStore(), "mailto:x@example.invalid")
    await push.subscribe("https://push.example/gut", "p", "a")
    await push.subscribe("https://push.example/weg", "p", "a")
    gesendet: list[str] = []

    import pywebpush

    class Antwort:
        status_code = 410

    def fake(subscription_info: dict[str, Any], **kw: Any) -> None:
        endpoint = str(subscription_info["endpoint"])
        if endpoint.endswith("weg"):
            exc = pywebpush.WebPushException("fort")
            exc.response = Antwort()  # type: ignore[assignment]
            raise exc
        gesendet.append(endpoint)

    monkeypatch.setattr(pywebpush, "webpush", fake)
    erreicht = await push.send(Mitteilung(title="t", body="b"))
    assert erreicht == 1
    assert gesendet == ["https://push.example/gut"]
    # Ein Endpunkt, den der Push-Dienst nicht mehr kennt, wird gelöscht: Sonst sammelt sich hier
    # über Jahre eine Liste von Adressen, die nie wieder jemanden erreichen.
    assert await push.count() == 1


async def test_der_grund_einer_ablehnung_steht_im_bericht_und_bei_dem_geraet(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Lehnt der Push-Dienst ab, muss die Seite sagen können, warum.

    Am 12.11.2026 kam im Haus keine einzige Mitteilung an, und die Oberfläche hatte dazu nur
    eine Zahl. Der Grund stand im Protokoll des Dienstes, wo ihn niemand liest.
    """
    push = PushService(MemoryPushStore(), PLATZHALTER)
    await push.subscribe("https://push.example/apfel", "p", "a", "iPhone")
    await push.subscribe("https://push.example/gut", "p", "a", "Mac")

    import pywebpush

    class Antwort:
        status_code = 403
        text = '{"reason":"BadJwtToken"}'

    def fake(subscription_info: dict[str, Any], **kw: Any) -> None:
        if str(subscription_info["endpoint"]).endswith("apfel"):
            exc = pywebpush.WebPushException("abgelehnt")
            exc.response = Antwort()  # type: ignore[assignment]
            raise exc

    monkeypatch.setattr(pywebpush, "webpush", fake)
    bericht = await push.send_bericht(Mitteilung(title="t", body="b"))
    nach_geraet = {z.label: z for z in bericht}
    assert nach_geraet["Mac"].ok is True
    iphone = nach_geraet["iPhone"]
    assert iphone.ok is False and iphone.weg is False and iphone.status == 403
    assert "BadJwtToken" in iphone.satz_de and iphone.satz_de.startswith("iPhone: ")
    # Abgelehnt ist nicht verschwunden: das Gerät bleibt angemeldet, mit dem Grund daneben.
    assert await push.count() == 2
    fehler = {str(abo.label): grund for abo, grund in await push.geraete()}
    assert "BadJwtToken" in fehler["iPhone"] and fehler["Mac"] == ""

    # Die nächste angenommene Mitteilung räumt den Grund wieder ab.
    monkeypatch.setattr(pywebpush, "webpush", lambda **kw: None)
    assert await push.send(Mitteilung(title="t", body="b")) == 2
    assert all(grund == "" for _, grund in await push.geraete())


async def test_der_absender_ist_die_eigene_adresse_der_oberflaeche_wenn_sie_taugt(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Solange niemand eine Adresse setzt, nennt der Dienst die Herkunft der Seite als Absender,
    wenn der Push-Dienst sie annehmen kann, und sonst den Platzhalter."""
    absender: list[str] = []

    import pywebpush

    def fake(vapid_claims: dict[str, Any], **kw: Any) -> None:
        absender.append(str(vapid_claims["sub"]))

    monkeypatch.setattr(pywebpush, "webpush", fake)

    push = PushService(MemoryPushStore(), PLATZHALTER)
    erwartet = [
        # Was keine Herkunft ist, wird nicht übernommen: der Wert kommt aus dem Browser.
        ("javascript:alert(1)", PLATZHALTER),
        ("http://haus.example.org", PLATZHALTER),
        # Der Port fällt weg: mit ihm wirft die Signaturbibliothek, bevor etwas verschickt wird.
        ("https://haus.fritz.box:8443", "https://haus.fritz.box"),
        ("https://Haus.Example.org", "https://haus.example.org"),
        # Ein Haus, das nur im eigenen Netz so heißt: gemerkt, aber nicht als Absender benutzt.
        ("https://haus.local", PLATZHALTER),
    ]
    for herkunft, _ in erwartet:
        await push.subscribe("https://push.example/a", "p", "a", "iPhone", herkunft)
        await push.send(Mitteilung(title="t", body="b"))
    assert absender == [soll for _, soll in erwartet]

    # Eine gesetzte Adresse gilt, wenn sie taugt.
    eigen = PushService(MemoryPushStore(), "mailto:haus@example.net")
    await eigen.subscribe("https://push.example/a", "p", "a", "iPhone", "https://haus.example.org")
    await eigen.send(Mitteilung(title="t", body="b"))
    assert absender[-1] == "mailto:haus@example.net"

    # Der alte Platzhalter, in einer Umgebung noch von Hand gesetzt, wird übergangen: mit ihm
    # kam am 12.11.2026 auf keinem iPhone etwas an.
    alt = PushService(MemoryPushStore(), "mailto:duck-curve-home@example.invalid")
    await alt.subscribe("https://push.example/a", "p", "a", "iPhone")
    await alt.send(Mitteilung(title="t", body="b"))
    assert absender[-1] == PLATZHALTER


@pytest.mark.parametrize(
    ("absender", "geht"),
    [
        # Gemessen am 12.11.2026 gegen web.push.apple.com: abgelehnt mit 403 BadJwtToken ...
        ("mailto:duck-curve-home@example.invalid", False),
        ("mailto:x@example.test", False),
        ("mailto:x@example.local", False),
        ("mailto:x@localhost", False),
        ("mailto:x@haus.example", False),
        ("https://localhost", False),
        ("https://haus.local", False),
        ("https://haus.invalid", False),
        ("https://haus.lan", False),
        ("https://haus.home", False),
        ("https://haus.internal", False),
        ("https://haus.localhost", False),
        ("https://haus.onion", False),
        # ... und angenommen:
        ("mailto:duck-curve-home@example.org", True),
        ("mailto:duck-curve-home@example.com", True),
        ("mailto:x@example.net", True),
        ("https://example.org", True),
        ("https://192.168.178.20", True),
        ("https://haus.fritz.box", True),
        ("https://haus.home.arpa", True),
        ("https://abc.ts.net", True),
        # Diese lässt schon die Signaturbibliothek nicht zu:
        ("https://haus.example.org:8443", False),
        ("http://haus.example.org", False),
        ("https://haus", False),
        ("", False),
    ],
)
def test_welcher_absender_taugt(absender: str, geht: bool) -> None:
    assert tauglich(absender) is geht


async def test_lehnt_der_push_dienst_den_absender_ab_kommt_der_naechste_dran(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Welche Endungen ein Push-Dienst annimmt, steht nirgends vollständig. Rutscht eine Adresse
    durch die Vorprüfung und wird doch abgelehnt, darf deshalb keine Mitteilung ausfallen."""
    versuche: list[str] = []

    import pywebpush

    class Antwort:
        status_code = 403
        text = '{"reason":"BadJwtToken"}'

    def fake(vapid_claims: dict[str, Any], **kw: Any) -> None:
        versuche.append(str(vapid_claims["sub"]))
        if vapid_claims["sub"] != PLATZHALTER:
            exc = pywebpush.WebPushException("abgelehnt")
            exc.response = Antwort()  # type: ignore[assignment]
            raise exc

    monkeypatch.setattr(pywebpush, "webpush", fake)
    push = PushService(MemoryPushStore(), PLATZHALTER)
    # Die Endung gibt es nicht, sie steht aber auch nicht auf der Liste der bekannten.
    await push.subscribe("https://push.example/a", "p", "a", "iPhone", "https://haus.heimnetz")
    bericht = await push.send_bericht(Mitteilung(title="t", body="b"))
    assert [z.ok for z in bericht] == [True]
    assert versuche == ["https://haus.heimnetz", PLATZHALTER]
    assert all(grund == "" for _, grund in await push.geraete())

    # Beim nächsten Mal wird der abgelehnte Absender bei diesem Dienst nicht wieder versucht.
    versuche.clear()
    assert await push.send(Mitteilung(title="t", body="b")) == 1
    assert versuche == [PLATZHALTER]


def test_der_platzhalter_ist_der_aus_den_einstellungen() -> None:
    """Der Dienst erkennt den Platzhalter am Wortlaut. Ändert ihn jemand nur an einer Stelle,
    gälte er als gesetzte Adresse, und die Herkunft der Oberfläche käme nie zum Zug."""
    assert Settings(mode="demo").push_subject == PLATZHALTER


def test_die_api_gibt_den_oeffentlichen_schluessel_heraus() -> None:
    with TestClient(create_app(Settings(mode="demo", demo_autostart=False))) as c:
        erst = c.get("/api/v1/push/key").json()
        assert erst["devices"] == 0
        assert len(entpacke(erst["public_key"])) == 65
        c.post(
            "/api/v1/push/subscribe",
            json={
                "endpoint": "https://push.example/x",
                "p256dh": "p",
                "auth": "a",
                "label": "iPad",
            },
        )
        zweit = c.get("/api/v1/push/key").json()
        # Derselbe Schlüssel: Ein neuer machte alle bestehenden Anmeldungen ungültig.
        assert zweit["public_key"] == erst["public_key"]
        assert zweit["devices"] == 1
        probe = c.post("/api/v1/push/test").json()
        # Zugestellt wird nichts: Den Endpunkt gibt es nicht. Die Auskunft darüber ist der Zweck,
        # und zwar je Gerät mit dem Grund.
        assert probe["devices"] == 1 and probe["ok"] is False
        assert len(probe["details_de"]) == 1 and probe["details_de"][0].startswith("iPad: ")
        liste = c.get("/api/v1/push/geraete").json()["devices"]
        assert [g["label"] for g in liste] == ["iPad"]
        assert liste[0]["fehlversuche"] == 1 and liste[0]["letzter_fehler_de"].startswith("iPad: ")
        assert "endpoint" not in liste[0]
        # Der Morgenbrief sagt, an wie viele Geräte er ginge.
        assert c.get("/api/v1/push/morgenbrief").json()["geraete"] == 1


def test_ohne_geraet_sagt_die_probe_das_und_nichts_anderes() -> None:
    with TestClient(create_app(Settings(mode="demo", demo_autostart=False))) as c:
        probe = c.post("/api/v1/push/test").json()
        assert probe == {
            "ok": False,
            "devices": 0,
            "message_de": "Kein Gerät ist für Mitteilungen angemeldet.",
            "details_de": [],
        }
        assert c.get("/api/v1/push/morgenbrief").json()["geraete"] == 0
