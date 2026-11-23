"""Anmeldung mit Passkey, Rollen und Personenverwaltung (dch_api/auth, ADR-0002).

Ein Software-Authenticator (`Geraet`) spielt das Telefon: er erzeugt ein echtes EC-Schlüsselpaar,
baut Anlage- und Anmeldeantwort nach WebAuthn Level 3 und **signiert sie**. Geprüft wird damit die
ganze Zeremonie, wie sie aus dem Browser kommt - nicht eine nachgebildete Prüfung. Übernommen aus
`duckcurve/tests/test_passkeys.py`.

Gegangen wird jeder Weg über HTTP, also durch dieselbe Tür wie die Oberfläche: Middleware,
Abhängigkeiten, Rechtematrix.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
from collections.abc import Iterator
from pathlib import Path

import cbor2
import pytest
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.settings import Settings

API = "/api/v1"
HERKUNFT = "http://localhost:3000"
RP_ID = "localhost"


def _b64(daten: bytes) -> str:
    return base64.urlsafe_b64encode(daten).rstrip(b"=").decode()


class Geraet:
    """Ein Authenticator in Software: Plattform, Nutzerprüfung, Signaturzähler."""

    def __init__(
        self, herkunft: str = HERKUNFT, rp_id: str = RP_ID, nutzerpruefung: bool = True
    ) -> None:
        self.schluessel = ec.generate_private_key(ec.SECP256R1())
        self.kennung = os.urandom(16)
        self.herkunft, self.rp_id, self.nutzerpruefung = herkunft, rp_id, nutzerpruefung
        self.zaehler = 0
        self.benutzerkennung: str | None = None

    def _cose(self) -> bytes:
        z = self.schluessel.public_key().public_numbers()
        return cbor2.dumps(
            {1: 2, 3: -7, -1: 1, -2: z.x.to_bytes(32, "big"), -3: z.y.to_bytes(32, "big")}
        )

    def _kopf(self, angelegt: bool) -> bytes:
        merker = 0x01 | (0x04 if self.nutzerpruefung else 0) | (0x40 if angelegt else 0)
        return (
            hashlib.sha256(self.rp_id.encode()).digest()
            + bytes([merker])
            + self.zaehler.to_bytes(4, "big")
        )

    def anlegen(self, optionen: dict) -> dict:
        self.benutzerkennung = optionen["user"]["id"]
        client = json.dumps(
            {
                "type": "webauthn.create",
                "challenge": optionen["challenge"],
                "origin": self.herkunft,
                "crossOrigin": False,
            }
        ).encode()
        daten = (
            self._kopf(True)
            + bytes(16)
            + len(self.kennung).to_bytes(2, "big")
            + self.kennung
            + self._cose()
        )
        objekt = cbor2.dumps({"fmt": "none", "attStmt": {}, "authData": daten})
        return {
            "id": _b64(self.kennung),
            "rawId": _b64(self.kennung),
            "type": "public-key",
            "response": {
                "clientDataJSON": _b64(client),
                "attestationObject": _b64(objekt),
                "transports": ["internal", "hybrid"],
            },
            "clientExtensionResults": {},
            "authenticatorAttachment": "platform",
        }

    def anmelden(self, optionen: dict) -> dict:
        self.zaehler += 1
        client = json.dumps(
            {
                "type": "webauthn.get",
                "challenge": optionen["challenge"],
                "origin": self.herkunft,
                "crossOrigin": False,
            }
        ).encode()
        daten = self._kopf(False)
        signatur = self.schluessel.sign(
            daten + hashlib.sha256(client).digest(), ec.ECDSA(hashes.SHA256())
        )
        return {
            "id": _b64(self.kennung),
            "rawId": _b64(self.kennung),
            "type": "public-key",
            "response": {
                "clientDataJSON": _b64(client),
                "authenticatorData": _b64(daten),
                "signature": _b64(signatur),
                "userHandle": self.benutzerkennung,
            },
            "clientExtensionResults": {},
        }


@pytest.fixture
def client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'auth.sqlite'}",
        db_create_all=True,
        api_token="api-geheim",
        passkey_rp_id=RP_ID,
        passkey_herkuenfte=[HERKUNFT],
        anmelde_url=HERKUNFT,
        weather_refresh_min=0,
        role="api",
    )
    app = create_app(settings)
    with TestClient(app) as c:
        yield c


#: Eine Maschine mit dem API-Token: die Bridge, ein Zeitplan, die iOS-App. Seit dem 23.11.2026
#: ist das der einzige Weg herein, der keine Person ist - die Gerätepaarung mit ihrem stehenden
#: URL-Token ist ausgebaut.
DIENST = {
    "authorization": "Bearer api-geheim",
    "x-dch-urheber-art": "geraet",
    "x-dch-urheber-name": "iPhone von Moritz",
}
#: Dieselbe Maschine, die von sich sagt, sie sei nur ein Gast. Die iOS-App kennt diese Rolle.
DIENST_GAST = {**DIENST, "x-dch-urheber-rolle": "gast", "x-dch-urheber-name": "Besuch"}


def person_anlegen(
    client: TestClient, email: str = "moritz@example.org", rolle: str = "hausherr"
) -> str:
    """Legt eine Person an und gibt den Einladungstoken zurück."""
    antwort = client.post(
        f"{API}/auth/personen",
        json={"email": email, "anzeigename": "Moritz", "rolle": rolle, "einladen": False},
        headers=DIENST,
    )
    assert antwort.status_code == 200, antwort.text
    link = antwort.json()["link"]
    return link.split("token=")[1]


def einrichten(client: TestClient, token: str, geraet: Geraet) -> dict:
    """Den Weg hinter dem Einladungslink gehen: Passkey anlegen, angemeldet sein."""
    z = client.post(f"{API}/auth/einladung/passkey/beginnen", json={"token": token})
    assert z.status_code == 200, z.text
    antwort = client.post(
        f"{API}/auth/einladung/passkey/abschliessen",
        json={
            "token": token,
            "schritt": z.json()["schritt"],
            "antwort": geraet.anlegen(json.loads(z.json()["optionen"])),
            "name": "Telefon",
        },
    )
    assert antwort.status_code == 200, antwort.text
    return antwort.json()


def anmelden(client: TestClient, geraet: Geraet) -> dict:
    z = client.post(f"{API}/auth/anmeldung/beginnen", json={})
    assert z.status_code == 200, z.text
    antwort = client.post(
        f"{API}/auth/anmeldung/abschliessen",
        json={
            "schritt": z.json()["schritt"],
            "antwort": geraet.anmelden(json.loads(z.json()["optionen"])),
        },
    )
    assert antwort.status_code == 200, antwort.text
    return antwort.json()


def mit(token: str) -> dict[str, str]:
    return {"authorization": f"Bearer {token}"}


# ---------------------------------------------------------------------------
# Der Weg herein
# ---------------------------------------------------------------------------


def test_zustand_sagt_dass_noch_niemand_da_ist(client: TestClient) -> None:
    antwort = client.get(f"{API}/auth/zustand")
    assert antwort.status_code == 200
    assert antwort.json()["anmeldung"] is True
    assert antwort.json()["personen"] == 0
    assert antwort.json()["rp_id"] == RP_ID


def test_ganzer_weg_einladung_passkey_anmeldung(client: TestClient) -> None:
    """Einladen, Passkey anlegen, abmelden, mit Passkey wieder herein."""
    token = person_anlegen(client)
    ergebnis = einrichten(client, token, (geraet := Geraet()))
    assert ergebnis["ausweis"]["rolle"] == "hausherr"
    assert ergebnis["ausweis"]["art"] == "person"
    # Beim ersten Passkey entstehen die zehn Codes - einmal, hier.
    assert len(ergebnis["codes"]) == 10

    sitzung = ergebnis["token"]
    ich = client.get(f"{API}/auth/ich", headers=mit(sitzung))
    assert ich.status_code == 200
    assert [p["name"] for p in ich.json()["passkeys"]] == ["Telefon"]
    assert ich.json()["codes_offen"] == 10

    assert client.post(f"{API}/auth/abmelden", headers=mit(sitzung)).status_code == 200
    # Die Sitzung ist weg, nicht nur das Cookie: ein zweiter Versuch mit demselben Token scheitert.
    assert client.get(f"{API}/auth/ich", headers=mit(sitzung)).status_code == 401

    neu = anmelden(client, geraet)
    assert neu["ausweis"]["email"] == "moritz@example.org"
    assert neu["token"] != sitzung


def test_einladungslink_gilt_nur_einmal(client: TestClient) -> None:
    token = person_anlegen(client)
    einrichten(client, token, Geraet())
    z = client.post(f"{API}/auth/einladung/passkey/beginnen", json={"token": token})
    assert z.status_code == 404
    assert "benutzt" in z.json()["error"]["message"]


def test_ein_neuer_link_entwertet_den_alten(client: TestClient) -> None:
    alt = person_anlegen(client)
    personen = client.get(f"{API}/auth/personen", headers=DIENST).json()
    neu = client.post(
        f"{API}/auth/personen/{personen[0]['id']}/einladen",
        json={"einladen": False},
        headers=DIENST,
    )
    assert neu.status_code == 200
    assert client.get(f"{API}/auth/einladung", params={"token": alt}).status_code == 404
    token_neu = neu.json()["link"].split("token=")[1]
    assert client.get(f"{API}/auth/einladung", params={"token": token_neu}).status_code == 200


def test_fremde_challenge_wird_abgewiesen(client: TestClient) -> None:
    """Ein Gerät, das die Challenge eines anderen Schritts signiert, kommt nicht herein."""
    token = person_anlegen(client)
    einrichten(client, token, (geraet := Geraet()))
    erster = client.post(f"{API}/auth/anmeldung/beginnen", json={}).json()
    zweiter = client.post(f"{API}/auth/anmeldung/beginnen", json={}).json()
    antwort = client.post(
        f"{API}/auth/anmeldung/abschliessen",
        json={
            "schritt": erster["schritt"],
            "antwort": geraet.anmelden(json.loads(zweiter["optionen"])),
        },
    )
    assert antwort.status_code == 401


def test_schritt_gilt_nur_einmal(client: TestClient) -> None:
    token = person_anlegen(client)
    einrichten(client, token, (geraet := Geraet()))
    z = client.post(f"{API}/auth/anmeldung/beginnen", json={}).json()
    rumpf = {"schritt": z["schritt"], "antwort": geraet.anmelden(json.loads(z["optionen"]))}
    assert client.post(f"{API}/auth/anmeldung/abschliessen", json=rumpf).status_code == 200
    assert client.post(f"{API}/auth/anmeldung/abschliessen", json=rumpf).status_code == 401


def test_falsche_herkunft_wird_abgewiesen(client: TestClient) -> None:
    """Dasselbe Schlüsselpaar, aber die Seite kommt von woanders - das ist der Phishing-Schutz."""
    token = person_anlegen(client)
    boese = Geraet(herkunft="https://beispiel.example")
    z = client.post(f"{API}/auth/einladung/passkey/beginnen", json={"token": token}).json()
    antwort = client.post(
        f"{API}/auth/einladung/passkey/abschliessen",
        json={
            "token": token,
            "schritt": z["schritt"],
            "antwort": boese.anlegen(json.loads(z["optionen"])),
            "name": "Telefon",
        },
    )
    assert antwort.status_code == 400


def test_ohne_nutzerpruefung_wird_abgewiesen(client: TestClient) -> None:
    """`user_verification=required`: ein Passkey ohne Fingerabdruck oder PIN zählt nicht."""
    token = person_anlegen(client)
    z = client.post(f"{API}/auth/einladung/passkey/beginnen", json={"token": token}).json()
    antwort = client.post(
        f"{API}/auth/einladung/passkey/abschliessen",
        json={
            "token": token,
            "schritt": z["schritt"],
            "antwort": Geraet(nutzerpruefung=False).anlegen(json.loads(z["optionen"])),
            "name": "Telefon",
        },
    )
    assert antwort.status_code == 400


def test_abgeschaltete_person_kommt_nicht_herein(client: TestClient) -> None:
    token = person_anlegen(client, rolle="hausherr")
    einrichten(client, token, (geraet := Geraet()))
    # Ein zweiter Hausherr, damit der erste abgeschaltet werden darf.
    person_anlegen(client, email="zweiter@example.org", rolle="hausherr")
    zweiter_token = client.get(f"{API}/auth/personen", headers=DIENST).json()
    einrichten(client, person_anlegen(client, email="dritt@example.org"), Geraet())
    del zweiter_token

    personen = client.get(f"{API}/auth/personen", headers=DIENST).json()
    moritz = next(p for p in personen if p["email"] == "moritz@example.org")
    aus = client.post(f"{API}/auth/personen/{moritz['id']}", json={"aktiv": False}, headers=DIENST)
    assert aus.status_code == 200
    assert aus.json()["aktiv"] is False

    z = client.post(f"{API}/auth/anmeldung/beginnen", json={}).json()
    antwort = client.post(
        f"{API}/auth/anmeldung/abschliessen",
        json={"schritt": z["schritt"], "antwort": geraet.anmelden(json.loads(z["optionen"]))},
    )
    assert antwort.status_code == 401
    # Immer derselbe Text: woran es lag, bleibt im Dienst.
    assert antwort.json()["error"]["message"] == "Die Anmeldung ist nicht möglich."


def test_abschalten_beendet_die_sitzungen_sofort(client: TestClient) -> None:
    sitzung = einrichten(client, person_anlegen(client, rolle="bewohner"), Geraet())["token"]
    assert client.get(f"{API}/auth/ich", headers=mit(sitzung)).status_code == 200
    person = client.get(f"{API}/auth/personen", headers=DIENST).json()[0]
    client.post(f"{API}/auth/personen/{person['id']}", json={"aktiv": False}, headers=DIENST)
    assert client.get(f"{API}/auth/ich", headers=mit(sitzung)).status_code == 401


# ---------------------------------------------------------------------------
# Wiederherstellung
# ---------------------------------------------------------------------------


def test_wiederherstellungscode_bringt_herein_und_gilt_einmal(client: TestClient) -> None:
    ergebnis = einrichten(client, person_anlegen(client), Geraet())
    code = ergebnis["codes"][0]
    erste = client.post(
        f"{API}/auth/wiederherstellung", json={"email": "moritz@example.org", "code": code}
    )
    assert erste.status_code == 200
    assert erste.json()["ausweis"]["art"] == "person"
    zweite = client.post(
        f"{API}/auth/wiederherstellung", json={"email": "moritz@example.org", "code": code}
    )
    assert zweite.status_code == 401


def test_wiederherstellung_mit_falschem_code(client: TestClient) -> None:
    einrichten(client, person_anlegen(client), Geraet())
    antwort = client.post(
        f"{API}/auth/wiederherstellung", json={"email": "moritz@example.org", "code": "aaaaa-bbbbb"}
    )
    assert antwort.status_code == 401


def test_neue_codes_entwerten_die_alten(client: TestClient) -> None:
    ergebnis = einrichten(client, person_anlegen(client), Geraet())
    alt = ergebnis["codes"][0]
    neu = client.post(f"{API}/auth/codes", headers=mit(ergebnis["token"]))
    assert neu.status_code == 200
    assert len(neu.json()["codes"]) == 10
    assert alt not in neu.json()["codes"]
    assert (
        client.post(
            f"{API}/auth/wiederherstellung", json={"email": "moritz@example.org", "code": alt}
        ).status_code
        == 401
    )


# ---------------------------------------------------------------------------
# Passkeys verwalten
# ---------------------------------------------------------------------------


def test_letzter_passkey_bleibt(client: TestClient) -> None:
    ergebnis = einrichten(client, person_anlegen(client), Geraet())
    sitzung, kopf = ergebnis["token"], mit(ergebnis["token"])
    passkey = client.get(f"{API}/auth/ich", headers=kopf).json()["passkeys"][0]
    antwort = client.post(f"{API}/auth/passkeys/{passkey['id']}/loeschen", headers=kopf)
    assert antwort.status_code == 409
    assert "letzte Passkey" in antwort.json()["error"]["message"]

    # Mit einem zweiten geht es.
    z = client.post(f"{API}/auth/passkeys/beginnen", headers=kopf).json()
    zweites = Geraet()
    assert (
        client.post(
            f"{API}/auth/passkeys/abschliessen",
            json={
                "schritt": z["schritt"],
                "antwort": zweites.anlegen(json.loads(z["optionen"])),
                "name": "Laptop",
            },
            headers=kopf,
        ).status_code
        == 200
    )
    assert (
        client.post(f"{API}/auth/passkeys/{passkey['id']}/loeschen", headers=kopf).status_code
        == 200
    )
    # Und mit dem zweiten kommt man herein.
    assert anmelden(client, zweites)["token"] != sitzung


def test_fremder_passkey_laesst_sich_nicht_loeschen(client: TestClient) -> None:
    eine = einrichten(client, person_anlegen(client), Geraet())
    andere = einrichten(
        client, person_anlegen(client, email="gast@example.org", rolle="bewohner"), Geraet()
    )
    fremd = client.get(f"{API}/auth/ich", headers=mit(andere["token"])).json()["passkeys"][0]
    antwort = client.post(f"{API}/auth/passkeys/{fremd['id']}/loeschen", headers=mit(eine["token"]))
    assert antwort.status_code == 404
    # Dieselbe Meldung wie für „gibt es nicht": sonst wäre sie eine Auskunft über fremde Geräte.
    assert antwort.json()["error"]["message"] == "Diesen Passkey gibt es nicht."


def test_derselbe_passkey_nicht_zweimal(client: TestClient) -> None:
    ergebnis = einrichten(client, person_anlegen(client), (geraet := Geraet()))
    kopf = mit(ergebnis["token"])
    z = client.post(f"{API}/auth/passkeys/beginnen", headers=kopf).json()
    antwort = client.post(
        f"{API}/auth/passkeys/abschliessen",
        json={
            "schritt": z["schritt"],
            "antwort": geraet.anlegen(json.loads(z["optionen"])),
            "name": "noch mal",
        },
        headers=kopf,
    )
    assert antwort.status_code == 400
    assert "schon" in antwort.json()["error"]["message"]


# ---------------------------------------------------------------------------
# Rollen - die Matrix am Endpunkt, nicht in der Anzeige
# ---------------------------------------------------------------------------


def test_bewohner_darf_stellen_aber_keine_akten(client: TestClient) -> None:
    person_anlegen(client)  # ein Hausherr muss existieren
    sitzung = einrichten(
        client, person_anlegen(client, email="kind@example.org", rolle="bewohner"), Geraet()
    )["token"]
    kopf = mit(sitzung)
    # Lesen im Haus: ja.
    assert client.get(f"{API}/live/state", headers=kopf).status_code == 200
    # Die Akten: nein.
    assert client.get(f"{API}/energy/pv", headers=kopf).status_code == 403
    assert client.get(f"{API}/export/minutes", headers=kopf).status_code == 403
    assert client.get(f"{API}/system/door", headers=kopf).status_code == 403
    # Die Verwaltung: nein.
    assert client.get(f"{API}/auth/personen", headers=kopf).status_code == 403
    # Die eigenen Sachen: ja.
    assert client.get(f"{API}/auth/ich", headers=kopf).status_code == 200


def test_gast_darf_nur_lesen(client: TestClient) -> None:
    person_anlegen(client)
    sitzung = einrichten(
        client, person_anlegen(client, email="besuch@example.org", rolle="gast"), Geraet()
    )["token"]
    kopf = mit(sitzung)
    assert client.get(f"{API}/live/state", headers=kopf).status_code == 200
    antwort = client.post(
        f"{API}/control/actuators/courtyard_light", json={"on": True}, headers=kopf
    )
    assert antwort.status_code == 403
    assert antwort.json()["error"]["message"] == "Gastzugang: nur Ansicht."


def test_service_darf_am_geraet_aber_nicht_im_haus(client: TestClient) -> None:
    person_anlegen(client)
    sitzung = einrichten(
        client, person_anlegen(client, email="support@example.org", rolle="service"), Geraet()
    )["token"]
    kopf = mit(sitzung)
    assert client.get(f"{API}/live/state", headers=kopf).status_code == 200
    # Nicht im Haus stellen: ein Beratungszugang schaltet keine Lichter.
    assert (
        client.post(
            f"{API}/control/actuators/courtyard_light", json={"on": True}, headers=kopf
        ).status_code
        == 403
    )
    # Und niemals die Akten - auch nicht das Protokoll der Haustür.
    assert client.get(f"{API}/system/door", headers=kopf).status_code == 403


def test_hausherr_darf_alles(client: TestClient) -> None:
    sitzung = einrichten(client, person_anlegen(client), Geraet())["token"]
    kopf = mit(sitzung)
    assert client.get(f"{API}/auth/personen", headers=kopf).status_code == 200
    assert client.get(f"{API}/system/door", headers=kopf).status_code == 200


def test_ohne_token_kein_zugang(client: TestClient) -> None:
    assert client.get(f"{API}/live/state").status_code == 401
    assert client.get(f"{API}/auth/ich").status_code == 401


def test_die_rolle_aus_der_kopfzeile_wird_durchgesetzt(client: TestClient) -> None:
    """Eine Maschine, die sich als Gast ausgibt, wird daran auch gehalten.

    Das betrifft die iOS-App: sie spricht direkt mit dem Dienst, und eine Beschränkung in ihrer
    Anzeige wäre nur eine ausgeblendete Schaltfläche. Beweis ist die Angabe nicht - wer das Token
    hat, könnte jede Rolle behaupten und dürfte ohnehin alles (docs/URHEBER.md).
    """
    assert client.get(f"{API}/live/state", headers=DIENST_GAST).status_code == 200
    assert client.get(f"{API}/energy/pv", headers=DIENST_GAST).status_code == 403
    assert (
        client.post(
            f"{API}/control/actuators/courtyard_light", json={"on": True}, headers=DIENST_GAST
        ).status_code
        == 403
    )


def test_ein_dienst_mit_dem_api_token_darf_personen_anlegen(client: TestClient) -> None:
    """Wer das API-Token hat, darf alles - das ist unverändert und war immer so."""
    antwort = client.post(
        f"{API}/auth/personen",
        json={"email": "erster@example.org", "rolle": "hausherr", "einladen": False},
        headers=DIENST,
    )
    assert antwort.status_code == 200
    assert client.get(f"{API}/auth/zustand").json()["personen"] == 1
    # Ein Gast dagegen nicht.
    assert (
        client.post(
            f"{API}/auth/personen",
            json={"email": "wer@example.org", "rolle": "hausherr", "einladen": False},
            headers=DIENST_GAST,
        ).status_code
        == 403
    )


def test_ein_dienst_hat_keine_eigenen_passkeys(client: TestClient) -> None:
    """`/auth/ich` gilt nur für Personen: eine Maschine ist keine."""
    assert client.get(f"{API}/auth/ich", headers=DIENST).status_code == 403


# ---------------------------------------------------------------------------
# Personenverwaltung
# ---------------------------------------------------------------------------


def test_doppelte_adresse_wird_abgelehnt(client: TestClient) -> None:
    person_anlegen(client)
    antwort = client.post(
        f"{API}/auth/personen",
        json={"email": "moritz@example.org", "rolle": "bewohner", "einladen": False},
        headers=DIENST,
    )
    assert antwort.status_code == 400
    assert "schon" in antwort.json()["error"]["message"]


def test_der_letzte_hausherr_bleibt(client: TestClient) -> None:
    """Sonst sperrt sich das Haus selbst aus: niemand könnte mehr Personen verwalten."""
    person_anlegen(client)
    person = client.get(f"{API}/auth/personen", headers=DIENST).json()[0]
    for rumpf in ({"aktiv": False}, {"rolle": "bewohner"}):
        antwort = client.post(f"{API}/auth/personen/{person['id']}", json=rumpf, headers=DIENST)
        assert antwort.status_code == 400
        assert "letzte aktive Hausherr" in antwort.json()["error"]["message"]
    assert (
        client.post(f"{API}/auth/personen/{person['id']}/loeschen", headers=DIENST).status_code
        == 400
    )

    # Mit einem zweiten geht alles davon.
    person_anlegen(client, email="zweiter@example.org", rolle="hausherr")
    assert (
        client.post(
            f"{API}/auth/personen/{person['id']}", json={"rolle": "bewohner"}, headers=DIENST
        ).status_code
        == 200
    )


def test_loeschen_nimmt_passkeys_und_sitzungen_mit(client: TestClient) -> None:
    person_anlegen(client)  # Hausherr bleibt
    ergebnis = einrichten(
        client,
        person_anlegen(client, email="weg@example.org", rolle="bewohner"),
        (geraet := Geraet()),
    )
    person = next(
        p
        for p in client.get(f"{API}/auth/personen", headers=DIENST).json()
        if p["email"] == "weg@example.org"
    )
    assert (
        client.post(f"{API}/auth/personen/{person['id']}/loeschen", headers=DIENST).status_code
        == 200
    )
    # Die Sitzung ist weg.
    assert client.get(f"{API}/auth/ich", headers=mit(ergebnis["token"])).status_code == 401
    # Und der Passkey auch: die Anmeldung findet ihn nicht mehr.
    z = client.post(f"{API}/auth/anmeldung/beginnen", json={}).json()
    assert (
        client.post(
            f"{API}/auth/anmeldung/abschliessen",
            json={"schritt": z["schritt"], "antwort": geraet.anmelden(json.loads(z["optionen"]))},
        ).status_code
        == 401
    )


def test_unbekannte_rolle_wird_abgelehnt(client: TestClient) -> None:
    antwort = client.post(
        f"{API}/auth/personen",
        json={"email": "x@example.org", "rolle": "chef", "einladen": False},
        headers=DIENST,
    )
    assert antwort.status_code == 422  # pydantic lehnt schon das Schema ab


def test_sitzung_eines_anderen_geraets_beenden(client: TestClient) -> None:
    ergebnis = einrichten(client, person_anlegen(client), (geraet := Geraet()))
    zweite = anmelden(client, geraet)
    kopf = mit(zweite["token"])
    sitzungen = client.get(f"{API}/auth/ich", headers=kopf).json()["sitzungen"]
    assert len(sitzungen) == 2
    andere = next(s for s in sitzungen if not s["diese"])
    assert (
        client.post(f"{API}/auth/sitzungen/{andere['id']}/beenden", headers=kopf).status_code == 200
    )
    assert client.get(f"{API}/auth/ich", headers=mit(ergebnis["token"])).status_code == 401
    assert len(client.get(f"{API}/auth/ich", headers=kopf).json()["sitzungen"]) == 1


def test_ueberall_abmelden(client: TestClient) -> None:
    ergebnis = einrichten(client, person_anlegen(client), (geraet := Geraet()))
    anmelden(client, geraet)
    antwort = client.post(f"{API}/auth/sitzungen/beenden-alle", headers=mit(ergebnis["token"]))
    assert antwort.status_code == 200
    assert antwort.json()["beendet"] == 2
    assert client.get(f"{API}/auth/ich", headers=mit(ergebnis["token"])).status_code == 401


def test_der_erste_hausherr_entsteht_beim_start(tmp_path: Path) -> None:
    """Der Ersatz für die Gerätepaarung: eine Variable, ein Start, ein Link im Protokoll.

    Ein offener Endpunkt „erste Person anlegen" wäre keiner - wer die Adresse zuerst fände, hätte
    das Haus. Hier entscheidet, wer die Umgebung des Dienstes setzen kann, und das ist dieselbe
    Person, die auch an die Datenbank käme.
    """
    einstellungen = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'erst.sqlite'}",
        db_create_all=True,
        api_token="api-geheim",
        passkey_rp_id=RP_ID,
        passkey_herkuenfte=[HERKUNFT],
        anmelde_url=HERKUNFT,
        erste_person="moritz@example.org",
        weather_refresh_min=0,
        role="api",
    )
    with TestClient(create_app(einstellungen)) as erster:
        personen = erster.get(f"{API}/auth/personen", headers=DIENST).json()
        assert [(p["email"], p["rolle"], p["einladung_offen"]) for p in personen] == [
            ("moritz@example.org", "hausherr", True)
        ]
        assert erster.get(f"{API}/auth/zustand").json()["personen"] == 1

    # Beim zweiten Start passiert nichts mehr: die Variable prüft, ob wirklich noch niemand da ist.
    with TestClient(create_app(einstellungen)) as zweiter:
        assert zweiter.get(f"{API}/auth/zustand").json()["personen"] == 1
        personen = zweiter.get(f"{API}/auth/personen", headers=DIENST).json()
        assert len(personen) == 1


def test_eine_benutzte_sitzung_laeuft_nicht_ab(client: TestClient) -> None:
    """Die Frist gleitet mit - sonst fiele die Wandanzeige nach dreißig Tagen heraus.

    Früher hielt dafür ein Gerätecookie ein halbes Jahr. Seit die Paarung weg ist, muss die
    Sitzung einer Person das leisten: wer sie benutzt, behält sie.
    """
    from datetime import datetime

    ergebnis = einrichten(client, person_anlegen(client), Geraet())
    erste_frist = datetime.fromisoformat(ergebnis["laeuft_ab_am"])
    kopf = mit(ergebnis["token"])

    # Der Vermerk wird nur alle VERMERK_S geschrieben; für den Test den Abstand aufheben.
    from dch_api.auth import dienst as auth_dienst

    alt = auth_dienst.VERMERK_S
    auth_dienst.VERMERK_S = -1
    try:
        assert client.get(f"{API}/auth/ich", headers=kopf).status_code == 200
        sitzungen = client.get(f"{API}/auth/ich", headers=kopf).json()["sitzungen"]
    finally:
        auth_dienst.VERMERK_S = alt
    neue_frist = datetime.fromisoformat(sitzungen[0]["laeuft_ab_am"])
    assert neue_frist > erste_frist, "die Frist muss mitrücken"


def test_notzugang_holt_einen_ausgesperrten_zurueck(tmp_path: Path) -> None:
    """Der Rückweg, wenn alles andere zu ist - und die Lücke, die am 23.11.2026 auffiel.

    `DCH_ERSTE_PERSON` greift nur bei leerer Tabelle und ist damit kein Rückweg: wer sich
    aussperrt, hat ja schon einen Zugang. Mit `DCH_NOTZUGANG` wird die genannte Person wieder
    aktiv, wird `hausherr` und bekommt einen Link - auch wenn sie abgeschaltet und
    heruntergestuft war.
    """
    datei = tmp_path / "notzugang.sqlite"
    gemeinsam = {
        "mode": "live",
        "database_url": f"sqlite+aiosqlite:///{datei}",
        "db_create_all": True,
        "api_token": "api-geheim",
        "passkey_rp_id": RP_ID,
        "passkey_herkuenfte": [HERKUNFT],
        "anmelde_url": HERKUNFT,
        "weather_refresh_min": 0,
        "role": "api",
    }

    # Ausgangslage: zwei Personen, und die eine ist abgeschaltet und nur noch Gast.
    with TestClient(create_app(Settings(**gemeinsam))) as client:
        person_anlegen(client, email="zweiter@example.org", rolle="hausherr")
        person_anlegen(client, email="moritz@example.org", rolle="hausherr")
        personen = client.get(f"{API}/auth/personen", headers=DIENST).json()
        moritz = next(p for p in personen if p["email"] == "moritz@example.org")
        client.post(f"{API}/auth/personen/{moritz['id']}", json={"rolle": "gast"}, headers=DIENST)
        client.post(f"{API}/auth/personen/{moritz['id']}", json={"aktiv": False}, headers=DIENST)

    # DCH_ERSTE_PERSON hilft hier nicht: die Tabelle ist nicht leer.
    with TestClient(create_app(Settings(**gemeinsam, erste_person="moritz@example.org"))) as ohne:
        gleich = next(
            p
            for p in ohne.get(f"{API}/auth/personen", headers=DIENST).json()
            if p["email"] == "moritz@example.org"
        )
        assert gleich["aktiv"] is False and gleich["rolle"] == "gast"

    # Der Notzugang schon - und der Link führt wirklich hinein.
    with TestClient(create_app(Settings(**gemeinsam, notzugang="moritz@example.org"))) as mit_not:
        zurueck = next(
            p
            for p in mit_not.get(f"{API}/auth/personen", headers=DIENST).json()
            if p["email"] == "moritz@example.org"
        )
        assert zurueck["aktiv"] is True
        assert zurueck["rolle"] == "hausherr"
        assert zurueck["einladung_offen"] is True

        token = client_token(mit_not, "moritz@example.org")
        ergebnis = einrichten(mit_not, token, Geraet())
        assert ergebnis["ausweis"]["rolle"] == "hausherr"
        assert mit_not.get(f"{API}/auth/ich", headers=mit(ergebnis["token"])).status_code == 200


def client_token(client: TestClient, email: str) -> str:
    """Den offenen Einladungstoken einer Person holen - über einen neuen Link.

    Den aus dem Protokoll zu fischen wäre näher am Betrieb, aber brüchig im Test; der Hausherr
    stellt hier stattdessen einen neuen aus, und das entwertet den alten ohnehin.
    """
    person = next(
        p for p in client.get(f"{API}/auth/personen", headers=DIENST).json() if p["email"] == email
    )
    antwort = client.post(
        f"{API}/auth/personen/{person['id']}/einladen", json={"einladen": False}, headers=DIENST
    )
    assert antwort.status_code == 200, antwort.text
    return antwort.json()["link"].split("token=")[1]
