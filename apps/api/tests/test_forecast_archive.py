"""Prognoseläufe liegen bleiben, und zwar die richtigen.

Der Zweck der Ablage ist eine Frage, die sich sonst nie beantworten lässt: was hätte die
ursprüngliche Prognose gekostet. Sie braucht den Lauf von damals, nicht seine Kennzahlen. Diese
Prüfungen halten die drei Regeln fest, die das leisten: eine Wiederholung ist kein Lauf, ein
kanonischer Lauf je Ortstag bleibt für immer, und das Löschen nimmt seine Punkte mit.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import func, select

from dch_api.infrastructure.db import models as m
from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
from dch_api.infrastructure.db.repositories import SqlRepositories
from hems_core.forecasting import PLAN, PREIS, WETTER, Lauf, Punkt, kanonisch, stand_vor

BERLIN = ZoneInfo("Europe/Berlin")


def lauf(
    *,
    art: str = WETTER,
    erstellt: datetime | None = None,
    wert: float = 4.0,
    anzahl: int = 3,
) -> Lauf:
    ab = erstellt or datetime(2026, 11, 7, 5, 0, tzinfo=UTC)
    return Lauf(
        art=art,
        anbieter="open_meteo",
        erstellt=ab,
        von=ab,
        bis=ab + timedelta(hours=anzahl),
        schritt_min=60,
        punkte=tuple(
            Punkt(ts=ab + timedelta(hours=i), variable="temp_c", wert=wert + i)
            for i in range(anzahl)
        ),
    )


async def zaehle(repos: SqlRepositories, tabelle: type[m.Base]) -> int:
    async with repos.maker() as s:
        return int((await s.execute(select(func.count()).select_from(tabelle))).scalar_one())


@pytest.fixture
async def repos(tmp_path: Path):  # type: ignore[no-untyped-def]
    engine = make_engine(f"sqlite+aiosqlite:///{tmp_path / 'forecast.sqlite'}")
    await create_all_for_tests(engine)
    yield SqlRepositories(engine)
    await engine.dispose()


# ------------------------------------------------------------------ Ablegen


async def test_ein_lauf_liegt_mit_allen_punkten(repos: SqlRepositories) -> None:
    await repos.save_forecast_run(lauf(anzahl=5))
    assert await zaehle(repos, m.ForecastRun) == 1
    assert await zaehle(repos, m.ForecastPoint) == 5


async def test_der_fingerabdruck_wandert_mit_in_die_zeile(repos: SqlRepositories) -> None:
    """Sonst müsste der nächste Abruf alle Punkte lesen, um zu wissen, ob er etwas Neues bringt."""
    l1 = lauf()
    await repos.save_forecast_run(l1)
    assert await repos.last_forecast_fingerprint(WETTER) == l1.fingerabdruck


async def test_ohne_lauf_gibt_es_keinen_fingerabdruck(repos: SqlRepositories) -> None:
    assert await repos.last_forecast_fingerprint(WETTER) is None


async def test_der_fingerabdruck_kommt_vom_juengsten_lauf(repos: SqlRepositories) -> None:
    alt = lauf(erstellt=datetime(2026, 11, 7, 5, 0, tzinfo=UTC), wert=4.0)
    neu = lauf(erstellt=datetime(2026, 11, 7, 6, 0, tzinfo=UTC), wert=9.0)
    await repos.save_forecast_run(alt)
    await repos.save_forecast_run(neu)
    assert await repos.last_forecast_fingerprint(WETTER) == neu.fingerabdruck


async def test_die_arten_stoeren_sich_nicht(repos: SqlRepositories) -> None:
    await repos.save_forecast_run(lauf(art=WETTER))
    assert await repos.last_forecast_fingerprint(PREIS) is None


# ------------------------------------------------------------------ Kanonischer Lauf


async def test_der_kanonische_lauf_eines_tages_laesst_sich_finden(
    repos: SqlRepositories,
) -> None:
    """Die Auswahl selbst steckt in hems_core; hier zaehlt, dass die Paare dort richtig ankommen.

    Abgelegt wird in UTC, so wie es die Laufzeit tut, und das Fenster kommt als Ortsmitternacht
    herein. Genau diese Mischung ist die Stelle, an der SQLite und PostgreSQL auseinanderlaufen
    wuerden, wenn die Abfrage ihre Grenzen nicht selbst nach UTC drehte.
    """
    # 02:00, 04:45 und 06:00 UTC sind im November 03:00, 05:45 und 07:00 in Berlin.
    kennungen = {}
    for stunde, minute in ((2, 0), (4, 45), (6, 0)):
        t = datetime(2026, 11, 7, stunde, minute, tzinfo=UTC)
        kennungen[(stunde, minute)] = await repos.save_forecast_run(lauf(erstellt=t, wert=stunde))

    start = datetime(2026, 11, 7, 0, 0, tzinfo=BERLIN)
    paare = await repos.forecast_runs_between(WETTER, start, start + timedelta(days=1))
    assert len(paare) == 3

    kennung = kanonisch(paare, date(2026, 11, 7), 6, BERLIN)
    # Der um 05:45 Ortszeit, nicht der um 07:00: zur kanonischen Stunde war er der gueltige.
    assert kennung == kennungen[(4, 45)]

    await repos.mark_forecast_canonical(kennung, date(2026, 11, 7))
    async with repos.maker() as s:
        zeile = await s.get(m.ForecastRun, kennung)
        assert zeile is not None
        assert zeile.canonical_day == date(2026, 11, 7)


async def test_ein_lauf_ausserhalb_des_fensters_zaehlt_nicht_mit(
    repos: SqlRepositories,
) -> None:
    await repos.save_forecast_run(lauf(erstellt=datetime(2026, 11, 8, 5, 0, tzinfo=UTC)))
    start = datetime(2026, 11, 7, 0, 0, tzinfo=BERLIN)
    assert await repos.forecast_runs_between(WETTER, start, start + timedelta(days=1)) == []


# ------------------------------------------------------------------ Löschen


async def test_alte_laeufe_gehen_mit_ihren_punkten(repos: SqlRepositories) -> None:
    jetzt = datetime.now(UTC)
    await repos.save_forecast_run(lauf(erstellt=jetzt - timedelta(days=40), anzahl=4))
    weg = await repos.prune_forecast_runs(timedelta(days=30))
    assert weg == 1
    assert await zaehle(repos, m.ForecastRun) == 0
    # Punkte ohne Lauf fallen erst auf, wenn jemand sie zaehlt. Also zaehlt jemand sie.
    assert await zaehle(repos, m.ForecastPoint) == 0


async def test_ein_kanonischer_lauf_bleibt_auch_nach_jahren(repos: SqlRepositories) -> None:
    jetzt = datetime.now(UTC)
    kennung = await repos.save_forecast_run(lauf(erstellt=jetzt - timedelta(days=400), anzahl=4))
    await repos.mark_forecast_canonical(kennung, date(2025, 10, 4))
    assert await repos.prune_forecast_runs(timedelta(days=30)) == 0
    assert await zaehle(repos, m.ForecastRun) == 1
    assert await zaehle(repos, m.ForecastPoint) == 4


async def test_junge_laeufe_bleiben_unberuehrt(repos: SqlRepositories) -> None:
    await repos.save_forecast_run(lauf(erstellt=datetime.now(UTC) - timedelta(days=3)))
    assert await repos.prune_forecast_runs(timedelta(days=30)) == 0
    assert await zaehle(repos, m.ForecastRun) == 1


async def test_das_loeschen_trennt_kanonisch_von_veraltet(repos: SqlRepositories) -> None:
    """Der eigentliche Fall: ein Monat Laeufe, davon einer je Tag kanonisch."""
    jetzt = datetime.now(UTC)
    behalten = []
    for i in range(5):
        tag = jetzt - timedelta(days=40 + i)
        kennung = await repos.save_forecast_run(lauf(erstellt=tag))
        if i % 2 == 0:
            await repos.mark_forecast_canonical(kennung, tag.date())
            behalten.append(kennung)
    assert await repos.prune_forecast_runs(timedelta(days=30)) == 2
    async with repos.maker() as s:
        uebrig = (await s.execute(select(m.ForecastRun.id))).scalars().all()
    assert set(uebrig) == set(behalten)


async def test_ein_abgelegter_fahrplan_laesst_sich_als_absicht_lesen(
    repos: SqlRepositories,
) -> None:
    """Der ganze Weg: Fahrplan ablegen, und später fragen, was er für einen Zeitpunkt vorsah.

    Zwei Läufe über dieselbe Stunde, der zweite widerruft den ersten. Gefragt wird einmal vor und
    einmal nach dem zweiten Lauf - die Antwort muss sich ändern, und zwar genau an seiner
    Erstellungszeit. Das ist die Zeile „geplant" der Wiedergabe.
    """
    ziel = datetime(2026, 11, 10, 9, 0, tzinfo=UTC)
    for erstellt, wert in ((ziel - timedelta(hours=1), 1.0), (ziel + timedelta(minutes=5), 0.0)):
        await repos.save_forecast_run(
            Lauf(
                art=PLAN,
                anbieter="milp_v1",
                erstellt=erstellt,
                von=ziel,
                bis=ziel,
                schritt_min=15,
                punkte=(Punkt(ts=ziel, variable="hp_release", wert=wert),),
            )
        )
    punkte = await repos.forecast_history(
        PLAN, "hp_release", ziel - timedelta(hours=1), ziel + timedelta(hours=1), vorlauf_h=3
    )
    stand = stand_vor(punkte, raster_min=15)
    assert stand(ziel + timedelta(minutes=2)) == 1.0, "um 9:02 galt die Freigabe von 8:00"
    assert stand(ziel + timedelta(minutes=8)) == 0.0, "um 9:08 der Widerruf von 9:05"
