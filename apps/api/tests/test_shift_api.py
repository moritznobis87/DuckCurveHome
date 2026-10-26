"""Der Vergleichslauf über die API: Struktur, Vorzeichen, und was ohne Daten passiert."""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from dch_api.main import create_app
from dch_api.settings import Settings


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(
        create_app(Settings(mode="demo", demo_autostart=False, demo_warmup_hours=40))
    ) as c:
        yield c


def test_der_tag_wird_gerechnet_und_die_rechnung_geht_auf(client: TestClient) -> None:
    d = client.get("/api/v1/energy/shift", params={"period": "day"}).json()
    assert d["days_used"] >= 1
    # Die Ersparnis ist die Differenz der beiden Rechnungen, nicht eine dritte Zahl.
    assert d["saving_eur"] == pytest.approx(d["naive_eur"] - d["actual_eur"], abs=0.02)
    assert d["heat_pump_kwh"] > 0
    # Ohne die Annahmen ist die Zahl eine Behauptung.
    assert len(d["assumptions_de"]) >= 4
    assert "geschätzt" in d["method_de"].lower()


def test_ein_zeitraum_ohne_daten_behauptet_nichts(client: TestClient) -> None:
    d = client.get("/api/v1/energy/shift", params={"period": "day", "anchor": "2020-01-01"}).json()
    assert d["days_used"] == 0
    assert d["saving_eur"] == 0
    assert d["saving_ct_per_kwh"] is None


def test_jeder_tag_sagt_ob_er_zaehlt(client: TestClient) -> None:
    d = client.get("/api/v1/energy/shift", params={"period": "week"}).json()
    gezaehlt = [t for t in d["days"] if not t["note_de"]]
    assert len(gezaehlt) == d["days_used"]
    # Ein Tag ohne Aussage steht trotzdem in der Liste, mit dem Grund daneben.
    for t in d["days"]:
        assert t["note_de"] or t["heat_pump_kwh"] > 0
