"""Der Postausgang (dch_api/post.py): Einladung per SMTP und über den HTTPS-Versender.

**Hier steht ein echter kleiner SMTP-Server**, kein nachgebildetes `smtplib`. Der Unterschied ist
der Punkt: geprüft wird die Unterhaltung, wie sie über den Draht geht - Begrüßung, EHLO, MAIL,
RCPT, DATA -, und was am anderen Ende ankommt. Ein mattgesetztes `smtplib` bestätigt nur, dass
dieselben Methoden aufgerufen werden, die man selbst aufgeschrieben hat.

Gelesen wird die Nachricht mit `policy=default`, also so, wie ein Mailprogramm sie liest:
Betreffzeilen mit Umlaut stehen auf dem Draht RFC-2047-kodiert (`=?utf-8?q?f=C3=BCr?=`), und der
Rumpf ist quoted-printable - dort bricht ein langer Einladungslink mitten im Wort um (`den L=`,
Zeilenende, `ink`). Beides setzt der Empfänger zusammen; genau das prüfen diese Zeilen mit.

Für die Zweige, die ohne Zertifikat nicht zu fahren sind (STARTTLS, SSL, Anmeldung), steht
darunter die mattgesetzte Prüfung - dort geht es nur noch um die Reihenfolge.

Zwei Regeln sollen diese Datei halten (siehe post.py):

* **Der Versand ist eine Beigabe, kein Torwächter.** Was auch schiefgeht - `verschicken` wirft
  nicht, sondern meldet `False`.
* **Das Token fällt nirgends an.** Es steht im Rumpf, nicht im Betreff.
"""

from __future__ import annotations

import asyncio
import smtplib
from email import message_from_string
from email.policy import default as standard_policy
from typing import Any

import pytest

from dch_api import post
from dch_api.settings import Settings

LINK = "https://home.duckcurve.de/anmeldung/einrichten?token=GEHEIM-TOKEN-123"


class SmtpProbe:
    """Ein SMTP-Server, der gerade genug kann: begrüßen, annehmen, aufheben."""

    def __init__(self) -> None:
        self.nachrichten: list[str] = []
        self.umschlaege: list[tuple[str, list[str]]] = []

    async def _verbindung(
        self, leser: asyncio.StreamReader, schreiber: asyncio.StreamWriter
    ) -> None:
        async def sag(zeile: str) -> None:
            schreiber.write(f"{zeile}\r\n".encode())
            await schreiber.drain()

        await sag("220 probe bereit")
        absender, empfaenger = "", []
        while not leser.at_eof():
            roh = await leser.readline()
            if not roh:
                break
            befehl = roh.decode("utf-8", "replace").strip()
            gross = befehl.upper()
            if gross.startswith(("EHLO", "HELO")):
                await sag("250 probe")
            elif gross.startswith("MAIL FROM"):
                absender = befehl.split(":", 1)[1].strip()
                await sag("250 ok")
            elif gross.startswith("RCPT TO"):
                empfaenger.append(befehl.split(":", 1)[1].strip())
                await sag("250 ok")
            elif gross == "DATA":
                await sag("354 los")
                teile = []
                while True:
                    zeile = await leser.readline()
                    if not zeile or zeile in (b".\r\n", b".\n"):
                        break
                    teile.append(zeile.decode("utf-8", "replace"))
                self.nachrichten.append("".join(teile))
                self.umschlaege.append((absender, list(empfaenger)))
                await sag("250 angenommen")
            elif gross == "QUIT":
                await sag("221 tschuess")
                break
            elif gross == "RSET":
                absender, empfaenger = "", []
                await sag("250 ok")
            else:
                await sag("250 ok")
        schreiber.close()


@pytest.fixture
async def smtp() -> Any:
    probe = SmtpProbe()
    server = await asyncio.start_server(probe._verbindung, "127.0.0.1", 0)
    port = server.sockets[0].getsockname()[1]
    async with server:
        yield probe, port


def _settings(port: int, **mehr: Any) -> Settings:
    return Settings(
        smtp_host="127.0.0.1",
        smtp_port=port,
        smtp_sicherheit="keine",
        absender="haus@example.org",
        passkey_herkuenfte=["https://home.duckcurve.de"],
        **mehr,
    )


async def test_die_einladung_geht_wirklich_ueber_den_draht(smtp: Any) -> None:
    probe, port = smtp
    ok = await post.verschicken(_settings(port), "anna@example.org", "Anna", LINK, "einladung")
    assert ok is True
    assert len(probe.nachrichten) == 1
    nachricht = message_from_string(probe.nachrichten[0], policy=standard_policy)
    assert nachricht["To"] == "anna@example.org"
    assert "haus@example.org" in (nachricht["From"] or "")
    assert str(nachricht["Subject"]) == "Ihr Zugang zu Duck Curve Home"
    rumpf = nachricht.get_content()
    assert LINK in rumpf, "ohne den Link ist die Nachricht wertlos - auch nach dem Zusammensetzen"
    assert "Hallo Anna," in rumpf
    assert "72 Stunden" in rumpf, "die Frist gehört dazu"
    # Der Umschlag stimmt auch dort, wo der Kopf nicht hinsieht.
    absender, empfaenger = probe.umschlaege[0]
    assert empfaenger == ["<anna@example.org>"]
    assert "haus@example.org" in absender


async def test_das_token_steht_nicht_im_betreff(smtp: Any) -> None:
    """Betreffzeilen wandern durch Protokolle, Benachrichtigungen und Vorschauen."""
    probe, port = smtp
    await post.verschicken(_settings(port), "anna@example.org", "", LINK, "einladung")
    nachricht = message_from_string(probe.nachrichten[0], policy=standard_policy)
    assert "GEHEIM-TOKEN-123" not in str(nachricht["Subject"] or "")
    assert "GEHEIM-TOKEN-123" in nachricht.get_content()
    assert nachricht.get_content().startswith("Hallo,"), "ohne Namen eine schlichte Anrede"


async def test_der_wiederherstellungslink_hat_seinen_eigenen_text(smtp: Any) -> None:
    probe, port = smtp
    await post.verschicken(_settings(port), "anna@example.org", "Anna", LINK, "wiederherstellung")
    nachricht = message_from_string(probe.nachrichten[0], policy=standard_policy)
    assert str(nachricht["Subject"]) == "Ihr Link für einen neuen Zugang"
    assert "neuer Link angefordert" in nachricht.get_content()


async def test_ein_toter_server_nimmt_niemandem_den_zugang(smtp: Any) -> None:
    """Der Versand ist eine Beigabe: die Person ist schon angelegt, wenn das hier scheitert."""
    _, port = smtp
    settings = _settings(port + 1)  # dort hört niemand zu
    assert await post.verschicken(settings, "anna@example.org", "", LINK, "einladung") is False


async def test_ohne_konfiguration_wird_nichts_versucht(smtp: Any) -> None:
    probe, _ = smtp
    assert await post.verschicken(Settings(), "anna@example.org", "", LINK, "einladung") is False
    assert probe.nachrichten == []


async def test_starttls_und_anmeldung_in_der_richtigen_reihenfolge(monkeypatch: Any) -> None:
    """Ohne Zertifikat nicht über den Draht zu fahren - hier zählt nur die Reihenfolge.

    Sie ist nicht beliebig: wer sich vor dem `starttls` anmeldet, schickt sein Passwort im
    Klartext.
    """
    schritte: list[str] = []

    class Verbindung:
        def __init__(self, host: str, port: int, timeout: float) -> None:
            schritte.append(f"verbinden {host}:{port}")

        def __enter__(self) -> Verbindung:
            return self

        def __exit__(self, *_: object) -> None:
            schritte.append("schliessen")

        def starttls(self) -> None:
            schritte.append("starttls")

        def login(self, benutzer: str, passwort: str) -> None:
            schritte.append(f"anmelden {benutzer}")

        def send_message(self, nachricht: object) -> None:
            schritte.append("senden")

    monkeypatch.setattr(smtplib, "SMTP", Verbindung)
    settings = Settings(
        smtp_host="post.example.org",
        smtp_port=587,
        smtp_sicherheit="starttls",
        smtp_benutzer="versand@example.org",
        smtp_passwort="geheim",
        absender="haus@example.org",
        passkey_herkuenfte=["https://home.duckcurve.de"],
    )
    assert await post.verschicken(settings, "anna@example.org", "", LINK, "einladung") is True
    assert schritte == [
        "verbinden post.example.org:587",
        "starttls",
        "anmelden versand@example.org",
        "senden",
        "schliessen",
    ]


class HttpProbe:
    """Ein HTTP-Server, der eine Anfrage annimmt und ihren Rumpf aufhebt."""

    def __init__(self, status: str = "200 OK") -> None:
        self.status = status
        self.rumpf = ""
        self.kopf: dict[str, str] = {}

    async def _verbindung(
        self, leser: asyncio.StreamReader, schreiber: asyncio.StreamWriter
    ) -> None:
        kopfzeilen = await leser.readuntil(b"\r\n\r\n")
        text = kopfzeilen.decode("utf-8", "replace")
        for zeile in text.split("\r\n")[1:]:
            if ":" in zeile:
                name, _, wert = zeile.partition(":")
                self.kopf[name.strip().lower()] = wert.strip()
        laenge = int(self.kopf.get("content-length", "0"))
        self.rumpf = (await leser.readexactly(laenge)).decode("utf-8", "replace")
        schreiber.write(f"HTTP/1.1 {self.status}\r\ncontent-length: 2\r\n\r\n{{}}".encode())
        await schreiber.drain()
        schreiber.close()


async def test_der_https_versender_schickt_die_richtige_nachricht(monkeypatch: Any) -> None:
    """Der zweite Weg, für Umgebungen mit gesperrtem SMTP."""
    probe = HttpProbe()
    server = await asyncio.start_server(probe._verbindung, "127.0.0.1", 0)
    port = server.sockets[0].getsockname()[1]
    monkeypatch.setattr(post, "RESEND_URL", f"http://127.0.0.1:{port}/emails")
    settings = Settings(
        resend_schluessel="re_geheim",
        absender="haus@example.org",
        passkey_herkuenfte=["https://home.duckcurve.de"],
    )
    assert post.versandweg(settings) == "https"
    async with server:
        assert await post.verschicken(settings, "anna@example.org", "Anna", LINK, "einladung")
    assert probe.kopf["authorization"] == "Bearer re_geheim"
    assert LINK in probe.rumpf
    assert "anna@example.org" in probe.rumpf
    assert "Ihr Zugang zu Duck Curve Home" in probe.rumpf


async def test_eine_absage_des_versenders_wirft_nicht(monkeypatch: Any) -> None:
    probe = HttpProbe(status="422 Unprocessable Entity")
    server = await asyncio.start_server(probe._verbindung, "127.0.0.1", 0)
    port = server.sockets[0].getsockname()[1]
    monkeypatch.setattr(post, "RESEND_URL", f"http://127.0.0.1:{port}/emails")
    settings = Settings(
        resend_schluessel="re_geheim",
        absender="haus@example.org",
        passkey_herkuenfte=["https://home.duckcurve.de"],
    )
    async with server:
        assert await post.verschicken(settings, "anna@example.org", "", LINK, "einladung") is False


async def test_smtp_hat_vorrang_wenn_beides_eingetragen_ist(smtp: Any) -> None:
    probe, port = smtp
    settings = _settings(port, resend_schluessel="re_geheim")
    assert post.versandweg(settings) == "smtp"
    assert await post.verschicken(settings, "anna@example.org", "", LINK, "einladung") is True
    assert len(probe.nachrichten) == 1


async def test_person_anlegen_schickt_die_einladung_wirklich_hinaus(
    smtp: Any, tmp_path: Any
) -> None:
    """Der ganze Weg: Endpunkt, Dienst, Draht.

    Die Prüfungen oben sagen, dass `verschicken` funktioniert. Diese sagt, dass es auch gerufen
    wird - und dass der Link in der Nachricht derselbe ist, den die Antwort nennt. Fiele der
    Aufruf weg, bliebe oben alles grün.
    """
    from fastapi.testclient import TestClient

    from dch_api.main import create_app

    probe, port = smtp
    app = create_app(
        Settings(
            mode="live",
            database_url=f"sqlite+aiosqlite:///{tmp_path / 'post.sqlite'}",
            db_create_all=True,
            api_token="api-geheim",
            passkey_rp_id="localhost",
            passkey_herkuenfte=["http://localhost:3000"],
            anmelde_url="http://localhost:3000",
            weather_refresh_min=0,
            role="api",
            smtp_host="127.0.0.1",
            smtp_port=port,
            smtp_sicherheit="keine",
            absender="haus@example.org",
        )
    )
    kiosk = {
        "authorization": "Bearer api-geheim",
        "x-dch-urheber-art": "geraet",
        "x-dch-urheber-name": "iPad Flur",
        "x-dch-urheber-rolle": "owner",
    }
    # **Die Aufrufe gehen in einen Faden.** `TestClient` ist blockierend und haelt sonst die
    # Ereignisschleife dieses Tests an - und auf genau der lauscht der SMTP-Server. Die Anfrage
    # liefe dann in die Zeitgrenze des Versands, und der Test saehe ein `verschickt: false`, das
    # nur sein eigener Aufbau verursacht hat.
    with TestClient(app) as client:
        # Die Zugangsseite soll sagen koennen, dass der Versand steht.
        zustand = await asyncio.to_thread(client.get, "/api/v1/auth/zustand")
        assert zustand.json()["versand"] == {"aktiv": True, "weg": "smtp", "fehlt": []}
        antwort = await asyncio.to_thread(
            lambda: client.post(
                "/api/v1/auth/personen",
                json={"email": "anna@example.org", "anzeigename": "Anna", "rolle": "bewohner"},
                headers=kiosk,
            )
        )
    assert antwort.status_code == 200, antwort.text
    assert antwort.json()["verschickt"] is True
    assert len(probe.nachrichten) == 1
    nachricht = message_from_string(probe.nachrichten[0], policy=standard_policy)
    assert nachricht["To"] == "anna@example.org"
    assert antwort.json()["link"] in nachricht.get_content(), "derselbe Link wie in der Antwort"
