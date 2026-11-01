"""Der Urheber: Gerät heute, Person später, und keines von beidem erfunden.

Die Gerätenamen hier sind erfunden. Das Repository ist öffentlich.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from dch_api import urheber as u
from dch_api.infrastructure.db import models as m
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories

KOPF = {"authorization": "Bearer api-geheim"}


def test_ein_geraet_traegt_seinen_namen_als_kennung() -> None:
    a = u.aus_kopfzeilen({"x-dch-urheber-name": "iPad Flur"})
    assert a is not None
    assert (a.art, a.id, a.name, a.geraet) == ("geraet", "ipad-flur", "iPad Flur", "iPad Flur")


def test_ohne_name_gibt_es_keinen_urheber() -> None:
    # Lieber keine Angabe als eine erfundene.
    assert u.aus_kopfzeilen({}) is None
    assert u.aus_kopfzeilen({"x-dch-urheber-name": "   "}) is None


def test_eine_fehlende_art_ist_ein_geraet_und_keine_person() -> None:
    # Der heutige Stand. Eine fehlende Angabe zur Person zu erklären, verdürbe das Protokoll.
    a = u.aus_kopfzeilen({"x-dch-urheber-name": "Wandanzeige"})
    assert a is not None and a.art == "geraet"


def test_eine_unbekannte_art_wird_nicht_uebernommen() -> None:
    a = u.aus_kopfzeilen({"x-dch-urheber-name": "X", "x-dch-urheber-art": "hausmeister"})
    assert a is not None and a.art == "geraet"


def test_mit_benutzersystem_bleibt_das_geraet_daneben_stehen() -> None:
    a = u.aus_kopfzeilen(
        {
            "x-dch-urheber-art": "person",
            "x-dch-urheber-id": "u_17",
            "x-dch-urheber-name": "Vorname",
            "x-dch-urheber-geraet": "iPad Flur",
        }
    )
    assert a is not None
    assert (a.art, a.id, a.name, a.geraet) == ("person", "u_17", "Vorname", "iPad Flur")
    assert a.text() == "Vorname, am iPad Flur"


def test_ohne_eigenes_geraet_nennt_der_text_nur_den_namen() -> None:
    assert (
        u.Urheber(art="geraet", id="x", name="iPad Flur", geraet="iPad Flur").text() == "iPad Flur"
    )
    assert u.AUTOMATIK.text() == "Automatik"


def test_lange_angaben_werden_beschnitten() -> None:
    # `config_versions.created_by` ist 64 Zeichen breit; was nicht passt, darf nicht erst bis zur
    # Datenbank reisen, um dort zu scheitern.
    a = u.aus_kopfzeilen({"x-dch-urheber-name": "N" * 500, "x-dch-urheber-id": "i" * 500})
    assert a is not None
    assert len(a.id) <= u.MAX_ID and len(a.name) <= u.MAX_NAME


def test_kennung_macht_aus_einem_namen_eine_kennung() -> None:
    assert u.kennung("iPad Flur") == "ipad-flur"
    # Umlaute bleiben: `ü` ist alphanumerisch, und `wandanzeige-kche` wäre schlechter zu lesen
    # als `wandanzeige-küche`. Die Kennung landet in einer Textspalte, nicht in einer Adresse.
    assert u.kennung("  Wandanzeige / Küche  ") == "wandanzeige-küche"
    assert u.kennung("---") == ""


def test_der_urheber_ueberlebt_den_weg_durch_ein_ereignis() -> None:
    a = u.Urheber(art="person", id="u_17", name="Vorname", geraet="iPad Flur", rolle="owner")
    kontext = a.als_kontext()
    # Flache Zeichenketten, wie `raum.1.name`: durchsuchbar und auch über die Brücke tragfähig.
    assert kontext == {
        "urheber.art": "person",
        "urheber.id": "u_17",
        "urheber.name": "Vorname",
        "urheber.geraet": "iPad Flur",
        "urheber.rolle": "owner",
    }
    assert u.aus_kontext(kontext) == a


def test_ein_kontext_ohne_urheber_liefert_nichts() -> None:
    assert u.aus_kontext({"room": 3, "to": 21.5}) is None


def test_leere_felder_stehen_nicht_im_kontext() -> None:
    assert u.AUTOMATIK.als_kontext() == {
        "urheber.art": "automatik",
        "urheber.id": "automatik",
        "urheber.name": "Automatik",
    }


def test_die_kontextvariable_faengt_leer_an_und_laesst_sich_zuruecksetzen() -> None:
    assert u.aktueller() is None
    merker = u.setze(u.AUTOMATIK)
    assert u.aktueller() == u.AUTOMATIK
    u.zuruecksetzen(merker)
    assert u.aktueller() is None


# ------------------------------------------------------------------ bis in die Ablage


@pytest.fixture
async def repos(tmp_path: Path) -> SqlRepositories:
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'urheber.sqlite'}")
    await create_all_for_tests(engine)
    return SqlRepositories(engine)


async def test_ein_ereignis_bekommt_den_urheber_von_selbst(repos: SqlRepositories) -> None:
    merker = u.setze(u.Urheber(art="geraet", id="ipad-flur", name="iPad Flur", geraet="iPad Flur"))
    try:
        await repos.add_event("info", "rooms.setpoint", "gestellt", {"room": 3})
    finally:
        u.zuruecksetzen(merker)
    (ev,) = await repos.recent_events(10)
    assert ev.context["room"] == 3
    assert u.aus_kontext(ev.context) == u.Urheber(
        art="geraet", id="ipad-flur", name="iPad Flur", geraet="iPad Flur"
    )


async def test_ohne_anfrage_steht_kein_urheber_am_ereignis(repos: SqlRepositories) -> None:
    # Takt, Start, Bruecke: ein „System" an jeder der zehntausend Bruecken-Meldungen waere
    # Rauschen und kein Hinweis.
    await repos.add_event("info", "bridge.telemetry", "Takt", {"seq": 1})
    (ev,) = await repos.recent_events(10)
    assert u.aus_kontext(ev.context) is None


async def test_ein_mitgegebener_urheber_wird_nicht_ueberschrieben(repos: SqlRepositories) -> None:
    merker = u.setze(u.Urheber(art="geraet", id="ipad-flur", name="iPad Flur"))
    try:
        await repos.add_event("info", "rooms.automatik", "vorgeladen", u.AUTOMATIK.als_kontext())
    finally:
        u.zuruecksetzen(merker)
    (ev,) = await repos.recent_events(10)
    wer = u.aus_kontext(ev.context)
    assert wer is not None and wer.art == "automatik"


async def test_die_konfiguration_merkt_sich_wer_sie_geaendert_hat(repos: SqlRepositories) -> None:
    merker = u.setze(u.Urheber(art="person", id="u_17", name="Vorname", geraet="iPad Flur"))
    try:
        await repos.save_config("heat", {"a": 1})
    finally:
        u.zuruecksetzen(merker)
    # Ohne Urheber bleibt es beim alten Verhalten.
    await repos.save_config("room_shift", {"b": 2})

    # Gelesen wird direkt: `created_by` ist eine Spalte fuer die Nachschau, keine Schnittstelle.
    async with repos.maker() as sitzung:
        zeilen = dict(
            (r.kind, r.created_by)
            for r in (await sitzung.execute(select(m.ConfigVersion))).scalars().all()
        )
    assert zeilen["heat"] == "u_17"
    assert zeilen["room_shift"] == "system"


def test_der_urheber_der_anfrage_landet_im_raumprotokoll(client: TestClient) -> None:
    raeume = client.get("/api/v1/rooms", headers=KOPF).json()["rooms"]
    rid = raeume[0]["id"]
    client.post(
        f"/api/v1/rooms/{rid}/setpoint",
        json={"setpoint_c": 21.5},
        headers={**KOPF, "x-dch-urheber-name": "iPad Flur"},
    )
    eintraege = client.get(f"/api/v1/rooms/{rid}/log?hours=2", headers=KOPF).json()["entries"]
    eigene = [e for e in eintraege if e["quelle"] == "app"]
    assert eigene and eigene[-1]["urheber"] == "iPad Flur"


def test_ohne_kopfzeile_bleibt_das_feld_leer(client: TestClient) -> None:
    raeume = client.get("/api/v1/rooms", headers=KOPF).json()["rooms"]
    rid = raeume[1]["id"]
    client.post(f"/api/v1/rooms/{rid}/setpoint", json={"setpoint_c": 20.5}, headers=KOPF)
    eintraege = client.get(f"/api/v1/rooms/{rid}/log?hours=2", headers=KOPF).json()["entries"]
    eigene = [e for e in eintraege if e["quelle"] == "app"]
    # Leer heisst unbekannt, nicht „niemand" - und auf keinen Fall ein erfundener Name.
    assert eigene and eigene[-1]["urheber"] == ""
