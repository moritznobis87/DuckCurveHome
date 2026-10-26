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
    MemoryPushStore,
    Mitteilung,
    PushService,
    erzeuge_paar,
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
        # Zugestellt wird nichts: Den Endpunkt gibt es nicht. Die Auskunft darüber ist der Zweck.
        assert probe["devices"] == 1 and probe["ok"] is False
