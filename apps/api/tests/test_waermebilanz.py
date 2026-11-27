"""Die Wärmebilanz über den Endpunkt: kommt der Ofen an, und geht die Rechnung auf.

Der wichtigste Test ist `test_der_ofen_kommt_in_der_bilanz_an`. Bis zu dieser Fassung las die
Ofenauswertung über `ENERGY_KEYS`, und dort steht keine einzige Ofenspalte: im Live-Betrieb meldete
sie „keine Ofendaten", während die Spalten in der Minutentabelle gefüllt dastanden. Ein Fehler, den
kein Test gesehen hat, weil im Demo-Betrieb alle Spalten kommen.
"""

from __future__ import annotations

import asyncio
import gc
import threading
import time
from collections.abc import Awaitable, Callable, Iterator
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

from dch_api.application import energy_accounting
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
from hems_core.thermal import HeatSample

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


class UnbrauchbarError(AssertionError):
    """Eine Messung, aus der sich nichts ablesen lässt: zu wenige Schläge oder zu kurz.

    Ein eigener Name, damit `_haelt_schritt` sie von einem Fehler im Prüfling unterscheiden und
    die Messung wiederholen kann. Sie bleibt ein `AssertionError`: Wer `_mit_puls` ohne
    `_haelt_schritt` ruft, fällt an ihr wie an jeder anderen Behauptung.
    """


async def _mit_puls(ruf: Callable[[], Awaitable[Any]]) -> tuple[Any, float, list[float]]:
    """Etwas rechnen lassen und daneben alle fünf Millisekunden anklopfen.

    Zurück kommen das Ergebnis, die gesamte Antwortzeit und die Zeitpunkte, an denen der Puls
    durchkam; was die Tests daraus ablesen, steht in `_schlagrate`.

    Die Schranke von fünf Schlägen ist kein Maßstab für den Prüfling, sondern für die Messung:
    darunter ist die Rate aus zu wenigen Punkten geschätzt, um etwas zu bedeuten. Sie fängt den
    vollständigen Rückfall allerdings mit - steht die Übersetzung wieder in der Schleife, kommt
    der Puls gemessen null Mal durch, und dieser Satz ist dann die klarste Fehlermeldung, die
    der Test geben kann. Gemeldet wird sie als `UnbrauchbarError`.

    **Die Speicherbereinigung bleibt draußen.** Vor der Messung wird einmal ganz aufgeräumt,
    während der Messung ruht sie. Eine volle Bereinigung hält den GIL und damit den Puls an,
    gleich auf welchem Faden sie anspringt, und wie lange, hängt am Haufen des ganzen Prozesses
    und nicht am Prüfling: nachgemessen 0,99 s bei 9,2 Millionen verfolgten Dingen. Der Ruf
    selbst legt so viele Dinge an, dass sie mitten in ihm anspringt. Je zwölfmal gemessen, als
    Anteil der Nulllinie: beim Fadentest 0,69 bis 1,02 mit und 0,86 bis 1,00 ohne Bereinigung in
    der Messung, neben der Kostenseite 0,39 bis 0,57 mit und 0,53 bis 0,67 ohne. Die Nulllinie
    rechnet nur und legt nichts an; sie bekam diese Pause nie ab, und das Verhältnis kürzte sie
    deshalb nicht heraus. Die älteren Messwerte in den Tests unten stammen aus der Zeit davor.
    """
    schlaege: list[float] = []

    async def puls() -> None:
        while True:
            schlaege.append(asyncio.get_running_loop().time())
            await asyncio.sleep(0.005)

    bereinigung_an = gc.isenabled()
    gc.collect()
    gc.disable()
    try:
        p = asyncio.create_task(puls())
        t0 = asyncio.get_running_loop().time()
        ergebnis = await ruf()
        gesamt = asyncio.get_running_loop().time() - t0
        p.cancel()
    finally:
        if bereinigung_an:
            gc.enable()
    if len(schlaege) <= 5:
        raise UnbrauchbarError(f"der Puls kam in {gesamt:.3f} s nur {len(schlaege)}-mal durch")
    if gesamt <= 0.1:
        raise UnbrauchbarError(f"zu schnell für eine Aussage über Nebenläufigkeit ({gesamt:.3f} s)")
    return ergebnis, gesamt, schlaege


def _schlagrate(gesamt: float, schlaege: list[float]) -> float:
    """Schläge je Sekunde: wie oft die Ereignisschleife während des Rufs überhaupt drankam.

    Gegenüber der längsten Pause ist das die belastbarere Zahl, und zwar aus zwei Gründen. Der
    erste: die längste Pause ist ein Extremwert und nimmt jeden einzelnen Aussetzer des
    Betriebssystems voll mit, die Rate mittelt über den ganzen Ruf.

    Der zweite ist schwerer und war der eigentliche Mangel. **Die längste Pause wird kleiner, je
    größer die Blockade ist.** Nachgemessen am Fadentest, mit wachsendem Anteil der Übersetzung
    auf der Schleife: 0,219 · 0,110 · 0,073 · 0,052 - und bei vollständigem Rückfall springt sie
    auf 1,000, weil dann überhaupt kein Schlag mehr durchkommt. Der Grund ist, dass die
    Schleifenarbeit vor dem **ersten** Schlag liegt: `await ruf()` gibt erst am `to_thread` ab,
    vorher ist der Puls nie gelaufen, und was vor dem ersten Schlag geschieht, ist keine Lücke
    *zwischen* zwei Schlägen. Genau im interessanten Bereich - teilweise blockiert - zeigte die
    alte Kennzahl also nach unten, wo sie nach oben hätte zeigen müssen. Die Rate teilt durch die
    gesamte Antwortzeit und fängt es: Steht die Schleife wirklich, geht sie auf null.
    """
    return len(schlaege) / gesamt


def _rechnen(dauer: float) -> int:
    """Reines Python über `dauer` Sekunden - der Vergleichsklotz für die Nulllinie.

    Absichtlich kein `sleep`: ein Faden, der *rechnet*, hält den GIL und lässt die Schleife nur
    an den Umschaltpunkten durch (`sys.setswitchinterval`, hier 5 ms). Gemessen kostet das
    allein schon die Hälfte der Schläge - neben `asyncio.sleep` kamen 193 je Sekunde durch,
    neben einem rechnenden Faden nur 96. Diesen Preis zahlt auch die richtig ausgelagerte
    Übersetzung, also muss die Nulllinie ihn mitbezahlen, sonst vergleicht sie Äpfel mit Birnen.
    """
    ende = time.perf_counter() + dauer
    x = 0
    while time.perf_counter() < ende:
        # In Blöcken rechnen, damit die Uhr nicht öfter gelesen wird als gerechnet.
        for _ in range(2000):
            x = (x * 1103515245 + 12345) % (1 << 61)
    return x


async def _nulllinie_im_faden(dauer: float) -> float:
    """Die Schlagrate neben Arbeit, die nachweislich im Faden liegt - gleicher Prozess, gleiche Dauer.

    **Warum es die Nulllinie gibt.** Eine lange Pause des Pulses hat zwei mögliche Ursachen, und
    nur eine davon gehört dem Prüfling: entweder stand die Ereignisschleife (das ist der Mangel),
    oder das Betriebssystem hat den messenden Puls nicht gescheduled (das ist die Maschine). Eine
    feste Schranke kann die beiden nicht trennen und wird auf einer ausgelasteten Maschine aus
    dem falschen Grund rot - und ein Test, der aus dem falschen Grund rot wird, nimmt dem
    richtigen Grund den Glauben.

    Die Nulllinie ist der Ausweg: dieselbe Messung neben Arbeit, die garantiert im Faden liegt.
    Auf vier Kernen gemessen fiel ihre Rate von 96 Schlägen je Sekunde (unbelastet) auf 54 bis 67
    neben sechzehn rechnenden Prozessen - und die des Prüflings von 75 bis 96 auf 39 bis 57. Die
    Maschinenlast steckt damit in beiden Zahlen und kürzt sich im Verhältnis heraus.

    `dauer` ist die gemessene Antwortzeit des Prüflings, nicht eine geratene Zahl: unter Last
    dauert er länger, und eine Nulllinie über eine ganz andere Strecke wäre nicht vergleichbar.
    Begrenzt wird sie trotzdem, weil die Rate eine Zahl *je Sekunde* ist: unter 0,3 s sind zu
    wenige Schläge beisammen, um sie zu schätzen, und über 2 s wird nichts mehr genauer - wohl
    aber der Prüflauf auf einer überlasteten Maschine unnötig lang (gemessen 38 bis 55 Schläge
    je Sekunde über 2,6 bis 3,5 s, 45 bis 55 über 1,2 bis 2,0 s: dieselbe Zahl).
    """
    try:
        _wert, gesamt, schlaege = await _mit_puls(
            lambda: asyncio.to_thread(_rechnen, min(max(dauer, 0.3), 2.0))
        )
    except UnbrauchbarError as grund:
        raise UnbrauchbarError(f"Nulllinie: {grund}") from grund
    return _schlagrate(gesamt, schlaege)


#: So oft wird die Schlagrate höchstens gemessen, bevor ein Test fällt.
MESSUNGEN = 3

#: Eine Messung: das Ergebnis des Rufs, seine Antwortzeit, seine Schlagrate und die Nulllinie.
Messung = tuple[Any, float, float, float]


async def _einmal_messen(ruf: Callable[[], Awaitable[Any]]) -> Messung:
    ergebnis, gesamt, schlaege = await _mit_puls(ruf)
    return ergebnis, gesamt, _schlagrate(gesamt, schlaege), await _nulllinie_im_faden(gesamt)


async def _haelt_schritt(
    ruf: Callable[[], Awaitable[Any]],
    anteil: float,
    *,
    messen: Callable[[Callable[[], Awaitable[Any]]], Awaitable[Messung]] = _einmal_messen,
) -> Any:
    """Der Puls kommt neben `ruf` mit mindestens `anteil` der Nulllinie durch - sonst fällt der Test.

    Zurück kommt das Ergebnis des Rufs aus der Messung, die bestanden hat.

    **Warum bis zu dreimal gemessen wird.** Eine Messung dauert hier 0,2 bis 0,7 Sekunden und
    zählt rund zwanzig Schläge. Ein einzelner Aussetzer von 0,3 Sekunden halbiert sie. Die
    Nulllinie fängt das nicht: sie wird *nach* dem Prüfling gemessen und teilt mit ihm die
    Dauerlast der Maschine, aber nicht den einen Augenblick.

    So gefallen am 26.11.2026 zweimal in der CI, an Ständen, die die Wärmebilanz nicht
    berührten: neben der Kostenseite 16 Schläge in 0,699 s (0,23 der Nulllinie), beim Fadentest
    16 Schläge in 0,514 s (0,31). Beide Male lief die Nulllinie unmittelbar danach unbelastet
    mit 99 Schlägen je Sekunde, und beide Male dauerte der Ruf rund 0,27 s länger als sonst,
    ohne dass in dieser Zeit ein Schlag dazukam. Dieselben Messungen je zwölfmal hintereinander
    auf einem Rechner, auf dem daneben der ganze Prüflauf lief: 0,39 bis 0,57 und 0,69 bis 1,02.

    Die eine Ursache, die sich nachmessen ließ, ist die Speicherbereinigung; sie ruht seither
    während der Messung, siehe `_mit_puls`. Dass sie es in der CI war, ist damit nicht gezeigt:
    ein Faden, den das Betriebssystem einen Augenblick liegen lässt, sieht in diesen Zahlen
    genauso aus. Dafür bleibt die Wiederholung. Ein echter Rückfall liegt im Prüfling und
    drückt jede Messung, ein Aussetzer nur eine. Darum genügt eine bestandene von höchstens
    `MESSUNGEN`; die Schranken selbst bleiben, wie sie waren. Fällt der Test, nennt er alle
    Messungen.

    **Auch eine unbrauchbare Messung wird wiederholt.** Am 27.11.2026 fiel der Test der Rechnung
    in der CI an der Schranke der Messung selbst: Neben dem Vergleichsklotz der Nulllinie kam
    der Puls in 0,3 s fünfmal durch, mit Pausen von 61 und 224 ms, wo sonst alle 10 ms ein
    Schlag kommt. Der Prüfling war zu diesem Zeitpunkt fertig und lief nicht mehr. Die Schranke
    stand als `assert` in `_mit_puls` und fiel durch diese Schleife hindurch, bevor etwas
    wiederholt wurde. Eine gestörte Nulllinie darf nicht gelten, weil sie den Vergleich zu milde
    macht, und sie darf den Test nicht fällen, weil sie über den Prüfling nichts sagt. Darum
    zählt ein `UnbrauchbarError` als nicht bestandene Messung. Steht die Schleife wirklich, ist
    jede Messung unbrauchbar, und der Test fällt nach der dritten mit diesem Grund.
    """
    gemessen: list[str] = []
    for _ in range(MESSUNGEN):
        try:
            ergebnis, gesamt, rate, nulllinie = await messen(ruf)
        except UnbrauchbarError as grund:
            gemessen.append(f"unbrauchbar ({grund})")
            continue
        if rate > nulllinie * anteil:
            return ergebnis
        gemessen.append(
            f"{rate:.0f} Schläge/s während {gesamt:.3f} s gegen {nulllinie:.0f} der Nulllinie"
        )
    raise AssertionError(
        f"in {MESSUNGEN} Messungen nie über {anteil:.2f} der Nulllinie: " + "; ".join(gemessen)
    )


async def test_ein_einzelner_aussetzer_laesst_die_messung_nicht_fallen() -> None:
    """Die erste Messung liegt unter der Schranke, die zweite darüber: bestanden mit der zweiten."""
    folge = iter([("erste", 0.699, 23.0, 99.0), ("zweite", 0.45, 50.0, 97.0)])
    gerufen = 0

    async def messen(_ruf: Callable[[], Awaitable[Any]]) -> Messung:
        nonlocal gerufen
        gerufen += 1
        return next(folge)

    async def ruf() -> None:
        return None

    assert await _haelt_schritt(ruf, 1 / 4, messen=messen) == "zweite"
    assert gerufen == 2


async def test_ein_dauernder_rueckfall_faellt_in_jeder_messung() -> None:
    """Liegt jede Messung unter der Schranke, fällt der Test und nennt alle drei."""

    async def messen(_ruf: Callable[[], Awaitable[Any]]) -> Messung:
        return "zu langsam", 0.7, 20.0, 99.0

    async def ruf() -> None:
        return None

    with pytest.raises(AssertionError, match=r"in 3 Messungen nie über 0\.25") as fehler:
        await _haelt_schritt(ruf, 1 / 4, messen=messen)
    assert str(fehler.value).count("20 Schläge/s") == MESSUNGEN


async def test_eine_unbrauchbare_messung_wird_wiederholt() -> None:
    """Die Nulllinie der ersten Messung kam nicht zustande, die zweite Messung besteht.

    So gefallen am 27.11.2026 in der CI: Der Puls kam neben dem Vergleichsklotz in 0,3 s nur
    fünfmal durch, und der Test fiel an der Schranke der Messung, bevor `_haelt_schritt` etwas
    wiederholen konnte.
    """
    gerufen = 0

    async def messen(_ruf: Callable[[], Awaitable[Any]]) -> Messung:
        nonlocal gerufen
        gerufen += 1
        if gerufen == 1:
            raise UnbrauchbarError("Nulllinie: der Puls kam in 0.300 s nur 5-mal durch")
        return "zweite", 0.45, 50.0, 97.0

    async def ruf() -> None:
        return None

    assert await _haelt_schritt(ruf, 1 / 3, messen=messen) == "zweite"
    assert gerufen == 2


async def test_nur_unbrauchbare_messungen_lassen_den_test_fallen() -> None:
    """Steht die Schleife ganz, ist jede Messung unbrauchbar, und der Test nennt den Grund dreimal."""

    async def messen(_ruf: Callable[[], Awaitable[Any]]) -> Messung:
        raise UnbrauchbarError("der Puls kam in 0.700 s nur 1-mal durch")

    async def ruf() -> None:
        return None

    with pytest.raises(AssertionError, match=r"in 3 Messungen nie über 0\.33") as fehler:
        await _haelt_schritt(ruf, 1 / 3, messen=messen)
    assert str(fehler.value).count("nur 1-mal durch") == MESSUNGEN
    assert not isinstance(fehler.value, UnbrauchbarError)


async def test_ein_stehender_puls_ist_eine_unbrauchbare_messung() -> None:
    """Rechnet der Ruf in der Schleife selbst, kommt der Puls nicht durch: `UnbrauchbarError`."""

    async def in_der_schleife() -> int:
        return _rechnen(0.15)

    with pytest.raises(UnbrauchbarError, match=r"nur \d-mal durch"):
        await _mit_puls(in_der_schleife)


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

    Der Maßstab ist derselbe wie beim Fadentest weiter unten und aus demselben Grund die
    Schlagrate gegen die Nulllinie und nicht die längste Pause: auch hier war diese unter Last
    nah an der alten Schranke von einem Drittel (gemessen 0,249 neben sechzehn rechnenden
    Prozessen, also noch Faktor 1,3), und dieser Test ist unter CPU-Konkurrenz schon einmal
    durchgefallen. Das Verhältnis zur Nulllinie liegt dagegen über drei Laststufen bei 0,80 bis
    1,04 - die Rechnung liegt hier also praktisch vollständig im Faden, so gut wie es der GIL
    überhaupt zulässt.
    """
    tage = 7
    zeilen = _minutenzeilen(FADEN_BEGINN, tage * 24 * 60)

    async def keine(start: datetime, end: datetime) -> list[MinuteRow]:
        return []

    acc = EnergyAccounting(HemsConfig(), BERLIN, keine, heat_rows=_leser(zeilen))
    bilanz = await _haelt_schritt(
        lambda: acc.heat_balance("month", date(2026, 10, 15), FADEN_BEGINN + timedelta(days=tage)),
        1 / 3,
    )

    assert bilanz.totals.heat_pump_kwh > 0, "ohne gerechnete Wärme sagt der Test nichts"
    assert bilanz.buckets, "ohne Eimer wäre der teure Teil der Rechnung nicht gelaufen"


async def test_die_schleife_steht_auch_mit_der_kostenseite_nicht_lange() -> None:
    """Derselbe Test mit gefüllten `minute_rows` - so, wie der Dienst wirklich antwortet.

    **Warum es diesen zweiten Fall gibt.** Der Test über diesem hängt für `minute_rows` einen
    leeren Leser ein, und damit ist genau der Teil abgeschaltet, der weiter in der Schleife
    rechnet: `_heat_cost` holt sich `summary`, und die rechnet im Schleifenfaden. Dieser Fall
    steht deshalb schlechter da als der über ihm, und zwar zu Recht - er hält fest, wie viel von
    der Antwort die Schleife wirklich noch steht, und wächst mit, wenn die Kostenseite wächst.

    **Warum nicht mehr die Summe der Pausen über 50 ms.** Bis zu dieser Fassung verlangte der
    Test, dass diese Summe unter 0,75 der Antwortzeit bleibt - und er fiel: neben achtundvierzig
    rechnenden Prozessen gemessen 6,450 s von 8,124 s, also 0,79. Die 50 ms waren als Schwelle
    gut gedacht (darunter fällt eine Pause an der Wandanzeige niemandem auf), taugen aber nicht
    als Maßstab: unter Last wird *jede* Pause länger, immer mehr davon rutschen über die
    Schwelle, und die Summe läuft gegen die Antwortzeit, ohne dass am Prüfling etwas anders ist.

    Gemessen wird deshalb auch hier die Schlagrate gegen die Nulllinie im gleichen Prozess. Die
    Zahl ist über drei Laststufen auffällig fest: 0,44 bis 0,56, also kommt der Puls neben der
    Kostenseite etwa halb so oft durch wie neben Arbeit, die vollständig im Faden liegt. Das ist
    kein Rest, sondern der Weg, der noch offen ist: `summary` nimmt mit `hours` und
    `_compute_hours` einen anderen Weg und braucht ihre eigene Prüfung auf Reinheit. Die Schranke
    von einem Viertel hält den heutigen Stand fest (Faktor 1,8 nach unten), damit er nicht
    unbemerkt schlechter wird; ist `summary` nachgezogen, gehört sie auf ein Drittel wie die der
    beiden Tests über diesem.
    """
    tage = 7
    zeilen = _minutenzeilen(FADEN_BEGINN, tage * 24 * 60)
    leser = _leser(zeilen)
    acc = EnergyAccounting(HemsConfig(), BERLIN, leser, heat_rows=leser)
    bilanz = await _haelt_schritt(
        lambda: acc.heat_balance("month", date(2026, 10, 15), FADEN_BEGINN + timedelta(days=tage)),
        1 / 4,
    )

    assert bilanz.totals.heat_pump_kwh > 0, "ohne gerechnete Wärme sagt der Test nichts"
    assert bilanz.cost.heat_pump_paid_eur > 0, "ohne Stromkosten lief die Kostenseite nicht mit"


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


async def test_die_uebersetzung_der_zeilen_laeuft_im_faden(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Nur die Abfrage der Zeilen gehört auf die Ereignisschleife, ihre Übersetzung nicht.

    Der Faden endete eine Zeile zu früh: `_heat_samples` holte die Zeilen und übersetzte sie
    gleich danach in einer gewöhnlichen Schleife weiter *auf* der Schleife - gemessen 232 bis
    257 ms für 44 640 Zeilen, und eine Monatsbilanz übersetzt zweimal. Der Test fährt genau
    diesen Schritt allein: fast die ganze Zeit ist Übersetzung, und stünde sie noch in der
    Schleife, käme der Puls während des ganzen Aufrufs kein einziges Mal durch.

    **Warum nicht die längste Pause.** Bis zu dieser Fassung verlangte der Test
    `pause < gesamt / 3` und fiel in vollen Läufen durch, allein aber 24-mal von 24-mal grün.
    Der Grund ist der Maßstab, nicht der Prüfling: die längste Pause ist ein Extremwert, und sie
    bekommt ihre Größe gar nicht von der Schleife, sondern vom GIL. Ein Faden, der rechnet, hält
    ihn, und die Schleife wartet jedes Mal bis zum nächsten Umschaltpunkt - gemessen 64 bis 82 ms
    am Stück, und das im *richtigen* Zustand. Gegen die Schranke von einem Drittel blieb damit
    nur der Faktor 1,3, und den frisst ein einziger Aussetzer des Betriebssystems. Auf einem
    Runner mit zwei Kernen wäre der Test aus dem falschen Grund rot geworden.

    **Zwei Zusicherungen, und sie messen verschiedene Dinge.** Die erste ist die direkte: welcher
    Faden `_proben_bauen` wirklich ausgeführt hat. Sie ist das, was der Name dieses Tests
    behauptet, und sie steht hier, weil die Kennzahl darunter sie *nicht* leistet - nachgemessen
    hält eine Übersetzung, die vollständig auf der Ereignisschleife läuft und alle 300 Zeilen mit
    `await asyncio.sleep(0)` abgibt, ein Verhältnis von 0,75 und ist damit von den 0,77 des
    richtigen Zustands nicht zu unterscheiden. Die Rate misst **Ansprechbarkeit**, nicht **Ort der
    Arbeit**.

    Die zweite ist die **Schlagrate gegen die Nulllinie im gleichen Prozess**
    (`_nulllinie_im_faden`), und sie ist deshalb nicht überflüssig: Ansprechbarkeit ist das, was
    an der Wandanzeige auffällt, und sie fällt auch dann, wenn die Übersetzung im Faden bleibt und
    die Schleife trotzdem stehen lässt - etwa weil jemand den Faden um eine Rechnung erweitert,
    die den GIL nicht mehr abgibt. Gemessen auf vier Kernen, ohne Last und neben acht und sechzehn
    rechnenden Prozessen: Verhältnis 0,64 bis 0,88 im richtigen Zustand, 0,00 mit der Übersetzung
    zurück auf der Schleife - dort kommt der Puls null Mal durch, weil zwischen den beiden
    `await` nichts liegt, was ihn durchlässt.

    **Was das Drittel kostet.** Wandert die *halbe* Übersetzung zurück in die Schleife, bleibt der
    Test grün: gemessen 0,38 bis 0,44, also noch Faktor 1,1 bis 1,3 über der Schranke. Bei zwei
    Dritteln fällt er (0,32), bei drei Vierteln auch (0,22). Die Nachweisgrenze dieser Kennzahl
    liegt damit bei etwa 57 Prozent des Aufrufs auf der Schleife - nicht bei zwei Dritteln, denn
    die Fadenhälfte läuft selbst nur mit 0,78 der Nulllinienrate (0,78 × 0,5 = 0,39). Strenger
    wäre zu holen: mit `/2` läge die Grenze bei etwa 36 Prozent, und beim niedrigsten unter Last
    gemessenen Wert 0,77 bliebe noch Faktor 1,5. Die Schranke bleibt trotzdem bei einem Drittel,
    weil den Rückfall, um den es geht, jetzt die Fadenzusicherung fängt - vollständig und
    lastunabhängig - und diese Kennzahl dafür Luft behalten soll.
    """
    beginn = datetime(2026, 12, 1, tzinfo=UTC)
    zeilen = _minutenzeilen(beginn, 31 * 24 * 60)

    async def keine(start: datetime, end: datetime) -> list[MinuteRow]:
        return []

    # Mitschreiben, auf welchem Faden die Übersetzung lief. `_heat_samples` sucht `_proben_bauen`
    # beim Aufruf im Modul, also greift der Ersatz hier - und er ruft das Echte, damit der Test
    # dieselbe Arbeit und dieselbe Antwortzeit messt wie ohne ihn.
    faeden: list[int] = []
    echt = energy_accounting._proben_bauen

    def mitschreiben(rows: list[dict[str, float | str | None]]) -> list[HeatSample]:
        faeden.append(threading.get_ident())
        return echt(rows)

    monkeypatch.setattr(energy_accounting, "_proben_bauen", mitschreiben)

    acc = EnergyAccounting(HemsConfig(), BERLIN, keine, heat_rows=_leser(zeilen))

    async def uebersetzen() -> tuple[list[HeatSample], float]:
        # Jede Messung ruft die Übersetzung neu; gezählt wird der Faden der letzten.
        faeden.clear()
        return await acc._samples_for(beginn, beginn + timedelta(days=31))

    proben, schritt = await _haelt_schritt(uebersetzen, 1 / 3)

    assert len(proben) == 31 * 24 * 60, "ohne die Proben sagt der Test nichts"
    assert schritt == 1.0
    assert len(faeden) == 1, f"die Übersetzung lief {len(faeden)}-mal, erwartet war einmal"
    assert faeden[0] != threading.get_ident(), (
        "die Übersetzung lief auf dem Faden der Ereignisschleife"
    )
