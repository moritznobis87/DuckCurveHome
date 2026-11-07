"""Das Archiv wird gelesen: Prognose gegen Ist, nach Abstand zur Lieferung.

Bis zu diesen Prüfungen wurde in `forecast_runs` geschrieben und nie gelesen. Geschrieben ohne
gelesen ist nicht der halbe Nutzen, sondern keiner: der Grund, alle Läufe dreißig Tage zu behalten
und nicht nur den kanonischen, ist genau die Frage, ob die Prognose besser wird, je näher die
Lieferung kommt.

Festgehalten wird deshalb viererlei: die Abfrage findet jeden Lauf, der ein Intervall beschrieben
hat, und nicht nur den letzten; die Vorlaufzeit kommt richtig heraus, auch wenn SQLite die Zeitzone
unterwegs verliert; das Fenster nach hinten begrenzt die Suche, ohne einen Lauf zu verlieren, der
noch hineinreicht; und die abgeleitete Heizlast lässt das Bedarfsmodell herausfallen.
"""

from __future__ import annotations

from datetime import UTC, datetime, time, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest

from dch_api.application.forecast_history import forecast_history
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from hems_core.domain import HemsConfig
from hems_core.forecasting import PV, WETTER, Lauf, Punkt

BERLIN = ZoneInfo("Europe/Berlin")
#: Mittags Ortszeit, damit der Tag vor „jetzt" vollständig im Fenster liegt.
NOW = datetime(2026, 11, 7, 12, 0, tzinfo=BERLIN).astimezone(UTC)
GESTERN = datetime.combine(
    NOW.astimezone(BERLIN).date() - timedelta(days=1), time(0), tzinfo=BERLIN
).astimezone(UTC)


@pytest.fixture
async def repos(tmp_path: Path):  # type: ignore[no-untyped-def]
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'rueckblick.sqlite'}")
    await create_all_for_tests(engine)
    yield SqlRepositories(engine)
    await engine.dispose()


def wetter_lauf(erstellt: datetime, stunden: int, *, abweichung: float) -> Lauf:
    """Ein Wetterlauf, der ab `GESTERN` stündlich eine Temperatur behauptet.

    Das Ist liegt bei 5,0 Grad. `abweichung` ist, um wie viel der Lauf daneben liegt - so lässt sich
    je Lauf steuern, was in der Wertung herauskommen muss.
    """
    return Lauf(
        art=WETTER,
        anbieter="open_meteo",
        erstellt=erstellt,
        von=GESTERN,
        bis=GESTERN + timedelta(hours=stunden),
        schritt_min=60,
        punkte=tuple(
            Punkt(ts=GESTERN + timedelta(hours=i), variable="temp_c", wert=5.0 + abweichung)
            for i in range(stunden)
        ),
    )


async def ist_eintragen(repos: SqlRepositories, stunden: int, grad: float) -> None:
    """Jede Minute dieselbe Temperatur, damit das Stundenmittel genau `grad` ist."""
    async with repos.maker() as s:
        from dch_api.infrastructure.db import models as m

        for i in range(stunden * 60):
            s.add(m.MeasurementMinute(bucket=GESTERN + timedelta(minutes=i), outdoor_temp_c=grad))
        await s.commit()


async def test_jeder_lauf_der_das_intervall_beschrieb_zaehlt_einzeln(
    repos: SqlRepositories,
) -> None:
    """Drei Läufe über denselben Tag sind drei Beiträge, einer je Vorlaufklasse.

    Vorher gab es diese Frage nicht zu stellen: der Bewerter im Arbeitsspeicher kennt je
    Viertelstunde nur den jüngsten Lauf.
    """
    await ist_eintragen(repos, 6, 5.0)
    # Je später der Lauf, je kleiner sein Fehler - so soll es die Leiter zeigen.
    await repos.save_forecast_run(wetter_lauf(GESTERN - timedelta(hours=20), 6, abweichung=3.0))
    await repos.save_forecast_run(wetter_lauf(GESTERN - timedelta(hours=8), 6, abweichung=2.0))
    await repos.save_forecast_run(wetter_lauf(GESTERN - timedelta(minutes=30), 6, abweichung=1.0))

    out = await forecast_history(repos, NOW, HemsConfig(), BERLIN, tage=2)
    temp = next(r for r in out.reihen if r.key == "weather.temp_c")
    assert temp.einheit == "K"
    assert temp.gesamt.n == 18, "drei Läufe über je sechs Stunden"
    assert temp.gesamt.bias > 0, "alle drei lagen zu hoch; das Vorzeichen muss das sagen"

    # Ein Lauf liegt nicht in genau einer Klasse: seine sechs Stunden verteilen sich über die
    # Leiter, je nachdem wie weit sie von seiner Ausgabe entfernt sind. Geprüft wird deshalb die
    # Richtung - näher an der Lieferung kleiner -, nicht ein Wert je Sprosse.
    je = {v.key: v.wertung for v in temp.je_vorlauf}
    assert round(je["0-1h"].mae, 1) == 1.0, "der jüngste Lauf, erste Stunde: sein eigener Fehler"
    assert je["0-1h"].mae < je["6-12h"].mae < je["12-24h"].mae


async def test_die_vorlaufzeit_ueberlebt_sqlite(repos: SqlRepositories) -> None:
    """SQLite gibt Zeitstempel ohne Zone zurück. Der Vorlauf ist eine Differenz zwischen zweien.

    Ohne bewusste Zeiten auf beiden Seiten bricht die Subtraktion, und zwar nicht mit einer falschen
    Zahl, sondern mit einem Fehler mitten in der Abfrage.
    """
    await repos.save_forecast_run(wetter_lauf(GESTERN - timedelta(hours=5), 3, abweichung=1.0))
    rows = await repos.forecast_history(WETTER, "temp_c", GESTERN, GESTERN + timedelta(days=1))
    assert rows, "der Lauf liegt im Fenster"
    for erstellt, ts, _ in rows:
        assert erstellt.tzinfo is not None and ts.tzinfo is not None
        assert (ts - erstellt).total_seconds() >= 0


async def test_der_vorlauf_begrenzt_die_suche_ohne_etwas_zu_verlieren(
    repos: SqlRepositories,
) -> None:
    """Ein Lauf von vor drei Tagen beschreibt dieses Fenster nicht mehr und wird nicht gelesen."""
    await repos.save_forecast_run(wetter_lauf(GESTERN - timedelta(hours=10), 3, abweichung=1.0))
    await repos.save_forecast_run(wetter_lauf(GESTERN - timedelta(days=3), 3, abweichung=9.0))

    rows = await repos.forecast_history(
        WETTER, "temp_c", GESTERN, GESTERN + timedelta(days=1), vorlauf_h=48
    )
    erstellt = {r[0] for r in rows}
    assert GESTERN - timedelta(hours=10) in erstellt
    assert GESTERN - timedelta(days=3) not in erstellt, "jenseits des Planungshorizonts"


async def test_punkte_ohne_wert_werden_nicht_zu_fehlern(repos: SqlRepositories) -> None:
    """Ein NULL im Archiv heißt „der Anbieter lieferte nichts", nicht „die Prognose war null"."""
    await ist_eintragen(repos, 3, 5.0)
    leer = Lauf(
        art=WETTER,
        anbieter="open_meteo",
        erstellt=GESTERN - timedelta(hours=2),
        von=GESTERN,
        bis=GESTERN + timedelta(hours=3),
        schritt_min=60,
        punkte=tuple(
            Punkt(ts=GESTERN + timedelta(hours=i), variable="temp_c", wert=None if i else 5.0)
            for i in range(3)
        ),
    )
    await repos.save_forecast_run(leer)
    out = await forecast_history(repos, NOW, HemsConfig(), BERLIN, tage=2)
    temp = next(r for r in out.reihen if r.key == "weather.temp_c")
    assert temp.gesamt.n == 1, "nur der Punkt mit Wert"
    assert temp.gesamt.mae == 0.0


async def test_die_heizlast_steht_als_eigene_reihe_daneben(repos: SqlRepositories) -> None:
    """Der Temperaturfehler wird mit dem Bedarfsmodell in Kilowatt umgerechnet.

    Beide Seiten gehen durch dasselbe Modell, also fällt das Modell heraus: 2 K Fehler sind bei
    0,22 kW/K genau 0,44 kW, unabhängig davon, ob 0,22 richtig ist. Das ist der Grund, warum diese
    Zahl etwas über die Prognose sagt und nichts über das Modell.
    """
    await ist_eintragen(repos, 4, 5.0)
    await repos.save_forecast_run(wetter_lauf(GESTERN - timedelta(hours=3), 4, abweichung=2.0))

    cfg = HemsConfig()
    out = await forecast_history(repos, NOW, cfg, BERLIN, tage=2)
    last = next(r for r in out.reihen if r.key == "abgeleitet.heizlast_kw")
    assert last.einheit == "kW"
    assert last.gesamt.n == 4
    erwartet = cfg.heat_demand.heat_loss_kw_per_k * 2.0
    assert round(last.gesamt.mae, 3) == round(erwartet, 3)
    assert last.gesamt.bias < 0, (
        "zu warm geraten heißt zu wenig Bedarf geraten - das Vorzeichen dreht sich"
    )


async def test_ohne_laeufe_sagt_die_seite_dass_nichts_da_ist(repos: SqlRepositories) -> None:
    """Leer heißt „nichts abgelegt", nicht „fehlerfrei". Der Unterschied muss im Text stehen."""
    out = await forecast_history(repos, NOW, HemsConfig(), BERLIN, tage=2)
    assert all(r.laeufe == 0 and r.gesamt.n == 0 for r in out.reihen)
    assert "keine Läufe" in out.hinweise_de[0]
    assert "nicht nachholbar" in out.hinweise_de[0], "der verlorene Lerntag gehört dazu"
    pv = next(r for r in out.reihen if r.key == "pv.ac_kw")
    assert len(pv.je_vorlauf) == 6, "die Leiter bleibt vollständig, auch wenn sie leer ist"


async def test_pv_und_wetter_werden_getrennt_gelesen(repos: SqlRepositories) -> None:
    """Zwei Arten, zwei Reihen, zwei Raster. Ein Wetterlauf darf nicht als PV erscheinen."""
    await repos.save_forecast_run(wetter_lauf(GESTERN - timedelta(hours=3), 3, abweichung=1.0))
    rows_pv = await repos.forecast_history(PV, "ac_kw", GESTERN, GESTERN + timedelta(days=1))
    assert rows_pv == []
    assert await repos.forecast_run_count(WETTER, GESTERN - timedelta(days=1), NOW) == 1
    assert await repos.forecast_run_count(PV, GESTERN - timedelta(days=1), NOW) == 0
