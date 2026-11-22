"""Die Wärmebilanz über den Endpunkt: kommt der Ofen an, und geht die Rechnung auf.

Der wichtigste Test ist `test_der_ofen_kommt_in_der_bilanz_an`. Bis zu dieser Fassung las die
Ofenauswertung über `ENERGY_KEYS`, und dort steht keine einzige Ofenspalte: im Live-Betrieb meldete
sie „keine Ofendaten", während die Spalten in der Minutentabelle gefüllt dastanden. Ein Fehler, den
kein Test gesehen hat, weil im Demo-Betrieb alle Spalten kommen.
"""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable, Iterator
from datetime import UTC, date, datetime, timedelta
from itertools import pairwise
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from dch_api.application.energy_accounting import (
    ENERGY_KEYS,
    HEAT_KEYS,
    EnergyAccounting,
    MinuteRow,
    MinuteRows,
)
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from dch_api.main import create_app
from dch_api.settings import Settings
from hems_core.domain import HemsConfig, Quality
from hems_core.protocol import RawReading
from hems_core.simulation import BERLIN

AUTH = {"authorization": "Bearer api-geheim"}
# Ortszeit Berlin: 6 Uhr des 12.10.2026 ist 4 Uhr UTC.
TAG = "2026-10-12"
START = datetime(2026, 10, 12, 4, 0, tzinfo=UTC)


@pytest.fixture
def client(tmp_path: Path) -> Iterator[TestClient]:
    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'waerme.sqlite'}",
        db_create_all=True,
        bridge_tokens=["geheim"],
        api_token="api-geheim",
        weather_refresh_min=0,
        role="api",
    )
    with TestClient(create_app(settings)) as c:
        yield c


def test_die_ofenspalten_fehlen_in_der_bilanzliste_und_stehen_in_der_waermeliste() -> None:
    """Die Trennung ist Absicht, und genau deshalb muss sie festgehalten sein."""
    assert not [k for k in ENERGY_KEYS if k.startswith("stove_")]
    assert "stove_running" in HEAT_KEYS
    assert "stove_power_level" in HEAT_KEYS
    assert "stove_ambient_temp_c" in HEAT_KEYS
    assert set(ENERGY_KEYS) <= set(HEAT_KEYS)


async def _seed(tmp_path: Path, minuten: int = 120) -> SqlRepositories:
    """Zwei Stunden Haus: Wärmepumpe läuft, Ofen brennt, Puffer kühlt langsam aus."""
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'seed.sqlite'}")
    await create_all_for_tests(engine)
    repos = SqlRepositories(engine)
    items: list[RawReading] = []
    for i in range(minuten):
        ts = START + timedelta(minutes=i, seconds=10)
        temp = 52.0 - 0.02 * i
        werte = {
            "heat_pump_power_kw": 2.0,
            "outdoor_temp_c": 4.0,
            "buffer_temp_top_c": temp,
            "buffer_temp_mid_top_c": temp - 1,
            "buffer_temp_mid_bottom_c": temp - 2,
            "buffer_temp_bottom_c": temp - 3,
            "stove_running": 1.0,
            "stove_power_level": 5.0,
            "stove_ambient_temp_c": 21.0,
        }
        items.extend(
            RawReading(key=k, value=v, observed_at=ts, quality=Quality.OK, source="t")
            for k, v in werte.items()
        )
    await repos.add_readings(items)
    await repos.rollup_minutes(START, START + timedelta(minutes=minuten))
    return repos


async def test_der_ofen_kommt_in_der_bilanz_an(tmp_path: Path) -> None:
    repos = await _seed(tmp_path)
    rows = await repos.minute_series(START, START + timedelta(hours=2), HEAT_KEYS)
    assert rows, "ohne Minutenzeilen sagt der Test nichts"
    assert any(r.get("stove_running") == 1.0 for r in rows)
    assert any(r.get("stove_power_level") == 5.0 for r in rows)
    # Und über die schmale Liste eben nicht: das ist der Fehler, den die Trennung behebt.
    schmal = await repos.minute_series(START, START + timedelta(hours=2), ENERGY_KEYS)
    assert all("stove_running" not in r for r in schmal)


def test_ein_leerer_tag_antwortet_mit_null_und_einem_satz(client: TestClient) -> None:
    r = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["totals"]["heat_pump_kwh"] == 0.0
    assert body["note_de"]
    assert body["params"]["buffer_volume_liters"] > 0


def test_die_annahmen_stehen_im_bericht(client: TestClient) -> None:
    """Eine gerechnete Wärmemenge ohne ihre Annahmen ist keine Zahl, sondern eine Behauptung."""
    body = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH).json()
    p = body["params"]
    assert p["cop_curve"], "ohne Kennlinie keine Wärmepumpenwärme"
    assert p["stove_water_heat_kw"] > 0
    assert p["pellet_kwh_per_kg"] > 0
    # Nicht mehr der Ofenfühler: der Puffer steht woanders, und das muss im Bericht stehen.
    assert "Aufstellraum" in p["room_source_de"]
    assert p["buffer_ambient_c"] > 0
    assert 0.0 <= p["buffer_loss_useful_fraction"] <= 1.0


def test_es_ist_nicht_oeffentlich(client: TestClient) -> None:
    assert client.get("/api/v1/energy/waermebilanz").status_code == 401


def test_ein_jahr_wird_nicht_aus_minuten_gerechnet(client: TestClient) -> None:
    """525 000 Minutenzeilen für zwölf Balken sind keine Auswertung, sondern ein Ausfall.

    Lange Zeiträume kommen deshalb aus den Stundeneingängen. Liegen keine vor, sagt der Bericht das,
    statt eine Null zu zeigen, die wie eine Messung aussieht.
    """
    body = client.get(f"/api/v1/energy/waermebilanz?period=year&anchor={TAG}", headers=AUTH).json()
    assert "Minuten" not in body["resolution_de"]
    assert body["series"] == []


def test_der_tag_hat_einen_verlauf_und_die_woche_nicht(client: TestClient) -> None:
    tag = client.get(f"/api/v1/energy/waermebilanz?period=day&anchor={TAG}", headers=AUTH).json()
    woche = client.get(f"/api/v1/energy/waermebilanz?period=week&anchor={TAG}", headers=AUTH).json()
    assert tag["resolution_de"].startswith("aus Minuten")
    assert woche["series"] == []


async def test_die_stundeneingaenge_entstehen_aus_den_minuten(tmp_path: Path) -> None:
    """Der Weg für lange Zeiträume: Minuten einmal verdichten, danach Stunden lesen."""
    from datetime import date

    from dch_api.application.energy_accounting import HEAT_KEYS, EnergyAccounting
    from hems_core.domain import HemsConfig
    from hems_core.simulation import BERLIN

    repos = await _seed(tmp_path)
    acc = EnergyAccounting(
        HemsConfig(),
        BERLIN,
        lambda s, e: repos.minute_series(s, e, HEAT_KEYS),
        heat_store=(repos.heat_hours, repos.upsert_heat_hours),
    )
    n = await acc.refresh_heat_hours(START, START + timedelta(hours=2))
    assert n == 2
    stunden = await repos.heat_hours(START, START + timedelta(hours=2))
    assert len(stunden) == 2
    assert stunden[0].electric_kwh == 2.0  # eine Stunde mal zwei Kilowatt
    assert stunden[0].stove_minutes == 60
    assert stunden[0].buffer_top_c is not None and stunden[0].buffer_top_c > 50.0

    # Und die Jahresrechnung findet sie dann auch.
    bericht = await acc.heat_balance("year", date(2026, 10, 12), START + timedelta(hours=3))
    assert "Stunden" in bericht.resolution_de
    assert bericht.totals.heat_pump_kwh > 0
    assert bericht.totals.stove_water_kwh > 0


# ------------------------------------------------------------------ Parameter ändern


def test_geaenderte_annahmen_gelten_sofort_und_rueckwirkend(client: TestClient) -> None:
    """Der Kern des Schreibwegs: eine Korrektur, die nur nach vorn wirkt, ist keine Korrektur.

    Gespeichert sind Eingänge und keine Ergebnisse, also muss derselbe Tag nach der Änderung anders
    dastehen als vorher.
    """
    vorher = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH).json()
    assert vorher["params"]["pellet_kwh_per_kg"] != 5.25

    r = client.post("/api/v1/config/heat", json={"pellet_kwh_per_kg": 5.25}, headers=AUTH)
    assert r.status_code == 200, r.text
    assert r.json()["stove"]["pellet_kwh_per_kg"] == 5.25

    nachher = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH).json()
    assert nachher["params"]["pellet_kwh_per_kg"] == 5.25
    # Und die Konfigurationsseite zeigt denselben Stand.
    assert client.get("/api/v1/config", headers=AUTH).json()["stove"]["pellet_kwh_per_kg"] == 5.25


def test_ein_widerspruch_wird_abgelehnt_und_aendert_nichts(client: TestClient) -> None:
    vorher = client.get("/api/v1/config", headers=AUTH).json()["stove"]["water_heat_kw"]
    r = client.post("/api/v1/config/heat", json={"stove_water_heat_kw": 99.0}, headers=AUTH)
    assert r.status_code == 422
    assert "Wasseranteil" in r.text
    assert client.get("/api/v1/config", headers=AUTH).json()["stove"]["water_heat_kw"] == vorher


def test_eine_unsinnige_kennlinie_kommt_nicht_durch(client: TestClient) -> None:
    for kurve in ([[7.0, 3.0]], [[7.0, 3.0], [-7.0, 2.0]], [[0.0, 3.0], [7.0, 99.0]]):
        r = client.post("/api/v1/config/heat", json={"cop_curve": kurve}, headers=AUTH)
        assert r.status_code == 422, kurve


def test_die_kennlinie_laesst_sich_setzen(client: TestClient) -> None:
    kurve = [[-10.0, 2.1], [0.0, 2.8], [10.0, 3.9]]
    r = client.post("/api/v1/config/heat", json={"cop_curve": kurve}, headers=AUTH)
    assert r.status_code == 200, r.text
    body = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH).json()
    assert body["params"]["cop_curve"] == kurve


def test_der_schreibweg_ist_nicht_oeffentlich(client: TestClient) -> None:
    assert client.post("/api/v1/config/heat", json={"pellet_kwh_per_kg": 5.0}).status_code == 401


def test_die_vorschau_gibt_es_nur_fuer_heute(client: TestClient) -> None:
    """Ein Folgetag eines vergangenen Tages waere keine Prognose, sondern eine Behauptung."""
    alt = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH).json()
    assert alt["forecast_heat_kwh"] is None
    assert alt["forecast_note_de"] == ""
    woche = client.get("/api/v1/energy/waermebilanz?period=week", headers=AUTH).json()
    assert woche["forecast_heat_kwh"] is None


async def test_der_laufende_betrieb_fuellt_die_waermestunden(tmp_path: Path) -> None:
    """Sonst entstuenden sie nur beim Nachrechnen, und die Jahresstatistik bliebe leer."""
    from dch_api.application.energy_accounting import HEAT_KEYS, EnergyAccounting
    from hems_core.domain import HemsConfig
    from hems_core.simulation import BERLIN

    repos = await _seed(tmp_path)
    acc = EnergyAccounting(
        HemsConfig(),
        BERLIN,
        lambda s, e: repos.minute_series(s, e, HEAT_KEYS),
        store=(repos.energy_hours, repos.upsert_energy_hours, repos.last_energy_hour),
        heat_rows=lambda s, e: repos.minute_series(s, e, HEAT_KEYS),
        heat_store=(repos.heat_hours, repos.upsert_heat_hours),
    )
    await acc.refresh(START + timedelta(hours=2))
    stunden = await repos.heat_hours(START, START + timedelta(hours=3))
    assert len(stunden) >= 2


# ------------------------------------------------------------------ Kosten


async def test_der_ofen_bekommt_einen_preis(tmp_path: Path) -> None:
    """Der Ofen meldet keine Kilogramm. Über Stufe und Durchsatz wird daraus eine Menge.

    Zwei Stunden Volllast: rund 2,7 kg je Stunde laut Datenblatt, bei 450 €/t also gut 2,40 €.
    """
    from datetime import date

    from dch_api.application.energy_accounting import HEAT_KEYS, EnergyAccounting
    from hems_core.domain import HemsConfig
    from hems_core.simulation import BERLIN

    repos = await _seed(tmp_path)
    acc = EnergyAccounting(
        HemsConfig(),
        BERLIN,
        lambda s, e: repos.minute_series(s, e, HEAT_KEYS),
        heat_rows=lambda s, e: repos.minute_series(s, e, HEAT_KEYS),
    )
    b = await acc.heat_balance("day", date(2026, 10, 12), START + timedelta(hours=3))
    assert 4.0 < b.cost.stove_kg < 7.0, b.cost.stove_kg
    assert 1.8 < b.cost.stove_eur < 3.2, b.cost.stove_eur
    assert b.cost.stove_ct_per_kwh is not None
    # Die Wärme ins Wasser plus angerechnete Raumwärme; der Preis je kWh muss plausibel sein.
    assert 5.0 < b.cost.stove_ct_per_kwh < 25.0, b.cost.stove_ct_per_kwh
    assert "ct je Kilowattstunde" in b.cost.cheaper_de


def test_ohne_ofen_gibt_es_keine_pelletkosten(client: TestClient) -> None:
    body = client.get(f"/api/v1/energy/waermebilanz?anchor={TAG}", headers=AUTH).json()
    assert body["cost"]["stove_kg"] == 0.0
    assert body["cost"]["stove_eur"] == 0.0
    assert body["cost"]["stove_ct_per_kwh"] is None


def test_eine_geaenderte_annahme_macht_den_fahrplan_faellig(client: TestClient) -> None:
    """Nach einer Änderung ist der Fahrplan nicht alt, sondern falsch.

    Gemeldet am 09.11.2026: „den Pelletpreis geändert, die Planung wurde aber nicht neu
    gerechnet". Richtig beobachtet. Die Auswertungen rechnen bei jeder Abfrage neu und waren sofort
    richtig; der Fahrplan wird im Takt gerechnet, und `update_heat_config` sagte dem Takt nichts.
    Bis zu `plan_refresh_min` Minuten stand damit ein Fahrplan auf der Seite, der mit der alten
    Annahme entstanden war - von außen nicht von „die Änderung wirkt nicht" zu unterscheiden.

    Geprüft wird der Griff selbst und nicht das Ergebnis: die Regelschleife läuft im Test nicht,
    und ein Löserlauf im Prüflauf wäre eine Messung der Maschine statt des Verhaltens.
    """
    runner = client.app.state.runner
    runner._plan_at = datetime.now(UTC)
    r = client.post("/api/v1/config/heat", json={"pellet_price_eur_per_t": 300.0}, headers=AUTH)
    assert r.status_code == 200, r.text
    assert runner._plan_at is None, "der nächste Regeltakt muss den Fahrplan neu rechnen"


def test_eine_abgelehnte_aenderung_laesst_den_fahrplan_stehen(client: TestClient) -> None:
    """Fällig wird er nur, wenn sich wirklich etwas geändert hat. Ein 422 ändert nichts."""
    runner = client.app.state.runner
    vorher = datetime.now(UTC)
    runner._plan_at = vorher
    assert (
        client.post(
            "/api/v1/config/heat", json={"stove_water_heat_kw": 99.0}, headers=AUTH
        ).status_code
        == 422
    )
    assert runner._plan_at == vorher


# ------------------------------------------------------------------ Rechnung im Faden

#: Beginn der gesäten Minutenzeilen der Fadentests - Oktober, mit dem Umstellungstag darin.
FADEN_BEGINN = datetime(2026, 10, 1, tzinfo=UTC)


def _minutenzeilen(beginn: datetime, minuten: int) -> list[MinuteRow]:
    """Minutenzeilen, wie sie live aus `measurements_minute` kommen - Wärme *und* Strom.

    Die Stromspalten stehen mit darin, weil `minute_rows` und `heat_rows` im Demo-Betrieb
    dieselbe Abfrage sind und die Kostenseite der Bilanz (`_heat_cost` -> `summary`) sonst über
    leeren Stunden rechnet.
    """
    return [
        {
            "ts": (beginn + timedelta(minutes=i)).isoformat(),
            "heat_pump_power_kw": 2.0,
            "outdoor_temp_c": 4.0,
            "buffer_temp_top_c": 50.0 + (i % 60) * 0.05,
            "buffer_temp_mid_top_c": 49.0 + (i % 60) * 0.05,
            "buffer_temp_mid_bottom_c": 48.0 + (i % 60) * 0.05,
            "buffer_temp_bottom_c": 47.0 + (i % 60) * 0.05,
            "stove_running": 1.0,
            "stove_power_level": 5.0,
            "pv_power_kw": 1.5,
            "grid_power_kw": 0.8,
            "battery_power_kw": -0.2,
            "electricity_price_ct_kwh": 28.0,
        }
        for i in range(minuten)
    ]


def _leser(zeilen: list[MinuteRow]) -> MinuteRows:
    """Eine Minutenabfrage auf eine feste Liste - sie schneidet den Zeitraum heraus."""

    async def lesen(start: datetime, end: datetime) -> list[MinuteRow]:
        return [r for r in zeilen if start <= datetime.fromisoformat(str(r["ts"])) < end]

    return lesen


async def _mit_puls(ruf: Callable[[], Awaitable[Any]]) -> tuple[Any, float, list[float]]:
    """Etwas rechnen lassen und daneben alle fünf Millisekunden anklopfen.

    Zurück kommen das Ergebnis, die gesamte Antwortzeit und die Zeitpunkte, an denen der Puls
    durchkam: aus ihren Abständen lesen die Tests ab, wie lange die Schleife stand.
    """
    schlaege: list[float] = []

    async def puls() -> None:
        while True:
            schlaege.append(asyncio.get_running_loop().time())
            await asyncio.sleep(0.005)

    p = asyncio.create_task(puls())
    t0 = asyncio.get_running_loop().time()
    ergebnis = await ruf()
    gesamt = asyncio.get_running_loop().time() - t0
    p.cancel()
    assert len(schlaege) > 5, f"der Puls kam nur {len(schlaege)}-mal durch"
    assert gesamt > 0.1, f"zu schnell für eine Aussage über Nebenläufigkeit ({gesamt:.3f} s)"
    return ergebnis, gesamt, schlaege


async def test_die_rechnung_blockiert_die_ereignisschleife_nicht() -> None:
    """Die Wärmebilanz rechnet lange - und der Dienst muss daneben weiter antworten.

    Gemessen war der Grund: `/live/state` brauchte im Ruhezustand 79 ms und neben einer laufenden
    Monatsbilanz 4933 ms. `heat_balance` ist `async`, rechnete zwischen ihren `await`-Punkten aber
    durch, und solange sie das tat, stand die Ereignisschleife und mit ihr jede andere Antwort.

    Geprüft wird nicht die Dauer, sondern die Nebenläufigkeit: ein Puls, der alle fünf
    Millisekunden schlagen will, darf während der Rechnung nicht stehenbleiben. Die Zeilen kommen
    deshalb nur über `heat_rows`; `minute_rows` bleibt leer, damit dieser Test die Minutenrechnung
    misst und nur sie. Was die Kostenseite daneben noch kostet, hält der Test unter diesem fest -
    getrennt, weil sonst ein Wachstum der einen Seite in der Schranke der anderen verschwindet.
    """
    tage = 7
    zeilen = _minutenzeilen(FADEN_BEGINN, tage * 24 * 60)

    async def keine(start: datetime, end: datetime) -> list[MinuteRow]:
        return []

    acc = EnergyAccounting(HemsConfig(), BERLIN, keine, heat_rows=_leser(zeilen))
    bilanz, gesamt, schlaege = await _mit_puls(
        lambda: acc.heat_balance("month", date(2026, 10, 15), FADEN_BEGINN + timedelta(days=tage))
    )

    assert bilanz.totals.heat_pump_kwh > 0, "ohne gerechnete Wärme sagt der Test nichts"
    assert bilanz.buckets, "ohne Eimer wäre der teure Teil der Rechnung nicht gelaufen"
    pause = max(b - a for a, b in pairwise(schlaege))
    assert pause < gesamt / 3, f"längste Pause {pause:.3f} s von {gesamt:.3f} s"


async def test_die_schleife_steht_auch_mit_der_kostenseite_nicht_lange() -> None:
    """Derselbe Test mit gefüllten `minute_rows` - so, wie der Dienst wirklich antwortet.

    **Warum es diesen zweiten Fall gibt.** Der Test über diesem hängt für `minute_rows` einen
    leeren Leser ein, und damit ist genau der Teil abgeschaltet, der weiter in der Schleife
    rechnet: `_heat_cost` holt sich `summary`, und die rechnet im Schleifenfaden. Mit gefüllten
    Zeilen gemessen, stand die Schleife in derselben Testform einmal 296 ms am Stück von 494 ms
    Antwortzeit - die strenge Schranke des ersten Falls (`pause < gesamt / 3`) fällt dort, und
    zwar zu Recht. Geprüft wird deshalb hier nicht die längste einzelne Pause, sondern die
    **Summe** aller Pausen über 50 ms: sie sagt, wie viel von der Antwort die
    Schleife insgesamt noch steht, und sie wächst mit, wenn die Kostenseite wächst.

    50 ms ist die Schwelle, unter der eine Pause an einer Wandanzeige niemandem auffällt; alles
    darüber ist eine Antwort, die wartet.

    **Die Schranke ist mit Absicht keine strenge.** Gemessen stehen hier 0,28 bis 0,36 s von 0,49
    bis 0,58 s Antwortzeit, also 0,55 bis 0,62 - und das ist kein Rest, sondern der Weg, der noch
    offen ist: `summary` rechnet weiter im Schleifenfaden, sie nimmt einen anderen Weg (`hours`,
    `_compute_hours`) und braucht ihre eigene Prüfung auf Reinheit. Dieser Test hält den heutigen
    Stand fest, damit er nicht unbemerkt schlechter wird; ist `summary` nachgezogen, gehört die
    Schranke auf ein Drittel heruntergesetzt wie die des Tests über diesem.
    """
    tage = 7
    zeilen = _minutenzeilen(FADEN_BEGINN, tage * 24 * 60)
    leser = _leser(zeilen)
    acc = EnergyAccounting(HemsConfig(), BERLIN, leser, heat_rows=leser)
    bilanz, gesamt, schlaege = await _mit_puls(
        lambda: acc.heat_balance("month", date(2026, 10, 15), FADEN_BEGINN + timedelta(days=tage))
    )

    assert bilanz.totals.heat_pump_kwh > 0, "ohne gerechnete Wärme sagt der Test nichts"
    assert bilanz.cost.heat_pump_paid_eur > 0, "ohne Stromkosten lief die Kostenseite nicht mit"
    summe = sum(d for a, b in pairwise(schlaege) if (d := b - a) > 0.05)
    assert summe < gesamt * 0.75, f"Pausen über 50 ms zusammen {summe:.3f} s von {gesamt:.3f} s"


# ------------------------------------------------------------- Monatsgrenze und Zeitumstellung


async def test_ein_abgeschlossener_monat_mit_zeitumstellung_rechnet_aus_minuten() -> None:
    """Oktober hat in Berliner Zeit 31 Tage und eine Stunde - und fiel genau daran aus.

    `HEAT_MINUTE_DAYS = 31` wurde gegen die **Dauer** des Zeitraums geprüft, und die ist an dem
    Sonntag mit der Rückstellung eine Stunde länger als 31 Tage. Gemessen hat die Bilanz eines
    abgeschlossenen Oktobers deshalb `minutes == 0` und „keine Daten im Zeitraum“ gemeldet,
    während derselbe Monat im Laufen (`stop = now + 1 min`, also kürzer als sein Ende)
    vollständig gerechnet wurde. Im März war es umgekehrt. Gezählt werden jetzt Kalendertage.
    """
    zeilen = _minutenzeilen(FADEN_BEGINN, 7 * 24 * 60)

    async def keine(start: datetime, end: datetime) -> list[MinuteRow]:
        return []

    acc = EnergyAccounting(HemsConfig(), BERLIN, keine, heat_rows=_leser(zeilen))
    _start, ende = acc.period_bounds("month", date(2026, 10, 15))
    assert ende - _start > timedelta(days=31), "ohne die Umstellungsstunde prüft der Test nichts"

    bilanz = await acc.heat_balance("month", date(2026, 10, 15), ende + timedelta(days=1))
    assert bilanz.resolution_de == "aus Minutenwerten"
    assert bilanz.totals.minutes == 7 * 24 * 60
    assert bilanz.totals.heat_pump_kwh > 0


async def test_ein_ganzer_monat_geht_wirklich_einmal_durch_den_dienst() -> None:
    """31 Tage Minutenzeilen am Stück - der Fall, der 206 s brauchte, bevor der Puffergriff fiel.

    Dezember, weil darin keine Uhr umgestellt wird: 44 640 Proben, ein abgeschlossener Monat,
    und die Eimer stehen für jeden seiner Tage. Der Test ist der Wächter über die Größenordnung,
    mit der die Wärmeseite im Betrieb wirklich gerufen wird - die Fadentests darüber säen sieben
    Tage, weil sie etwas anderes messen.
    """
    beginn = datetime(2026, 12, 1, tzinfo=UTC)
    zeilen = _minutenzeilen(beginn, 31 * 24 * 60)

    async def keine(start: datetime, end: datetime) -> list[MinuteRow]:
        return []

    acc = EnergyAccounting(HemsConfig(), BERLIN, keine, heat_rows=_leser(zeilen))
    _start, ende = acc.period_bounds("month", date(2026, 12, 15))
    bilanz = await acc.heat_balance("month", date(2026, 12, 15), ende + timedelta(days=1))

    assert bilanz.resolution_de == "aus Minutenwerten"
    assert bilanz.totals.minutes > 44_000, f"nur {bilanz.totals.minutes} Minuten gerechnet"
    assert len(bilanz.buckets) == 31
    assert bilanz.totals.heat_pump_kwh > 0
    assert not bilanz.series, "der Verlauf gehört nur zum Tag"


async def test_die_uebersetzung_der_zeilen_laeuft_im_faden() -> None:
    """Nur die Abfrage der Zeilen gehört auf die Ereignisschleife, ihre Übersetzung nicht.

    Der Faden endete eine Zeile zu früh: `_heat_samples` holte die Zeilen und übersetzte sie
    gleich danach in einer gewöhnlichen Schleife weiter *auf* der Schleife - gemessen 232 bis
    257 ms für 44 640 Zeilen, und eine Monatsbilanz übersetzt zweimal. Der Test fährt genau
    diesen Schritt allein: fast die ganze Zeit ist Übersetzung, und stünde sie noch in der
    Schleife, wäre die längste Pause so lang wie der Aufruf selbst.
    """
    beginn = datetime(2026, 12, 1, tzinfo=UTC)
    zeilen = _minutenzeilen(beginn, 31 * 24 * 60)

    async def keine(start: datetime, end: datetime) -> list[MinuteRow]:
        return []

    acc = EnergyAccounting(HemsConfig(), BERLIN, keine, heat_rows=_leser(zeilen))
    (proben, schritt), gesamt, schlaege = await _mit_puls(
        lambda: acc._samples_for(beginn, beginn + timedelta(days=31))
    )

    assert len(proben) == 31 * 24 * 60, "ohne die Proben sagt der Test nichts"
    assert schritt == 1.0
    pause = max(b - a for a, b in pairwise(schlaege))
    assert pause < gesamt / 3, f"längste Pause {pause:.3f} s von {gesamt:.3f} s"
