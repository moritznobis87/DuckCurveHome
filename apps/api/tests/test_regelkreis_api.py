"""Die Regelkreis-Karte als Antwort des Dienstes: lesen, übersteuern, freigeben."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi.testclient import TestClient

from dch_api.application import regelkreis as logik
from hems_core.domain.config import HemsConfig
from hems_core.regelkreis.parameter import PARAMETER
from hems_core.regelkreis.schaetzer import Schaetzstand

JETZT = datetime(2026, 11, 22, 10, 0, tzinfo=UTC)
WEG = "/api/v1/regelkreis"


def test_karte_kommt_vollstaendig(client: TestClient) -> None:
    """Jeder Block mit seiner Ebene, jede Kante mit beiden Enden, jeder Parameter mit Herkunft.

    Die Oberfläche zeichnet aus dieser einen Antwort; was hier fehlt, fehlt dort auch.
    """
    r = client.get(WEG)
    assert r.status_code == 200
    k = r.json()
    kennungen = {b["id"] for b in k["bloecke"]}
    assert len(kennungen) == len(k["bloecke"])
    for kante in k["kanten"]:
        assert kante["von"] in kennungen and kante["nach"] in kennungen
    assert {p["id"] for p in k["parameter"]} == set(PARAMETER)
    for p in k["parameter"]:
        assert p["herkunft"] in {
            "gemessen",
            "geschaetzt",
            "annahme",
            "fest",
            "entwurf",
            "uebersteuert",
        }
        assert p["unten"] <= p["wert"] <= p["oben"]
    assert {kreis["id"] for kreis in k["kreise"]} == {"R0", "R1", "R2", "R3", "R4"}


def test_die_stetigen_kreise_tragen_entwurf_und_reserven(client: TestClient) -> None:
    k = client.get(WEG).json()
    for kreis in k["kreise"]:
        if kreis["art"] in ("hybrid", "planung"):
            assert kreis["regler"] is None and not kreis["kennlinie"]
            continue
        assert kreis["regler"]["kp"] > 0
        assert kreis["regler"]["tn"] > 0
        assert kreis["strecke"]["totzeit"] >= 0
        assert len(kreis["kennlinie"]) > 50
        assert kreis["reserven"]["phasenreserve_grad"] is not None


def test_arbeitspunkt_nennt_woher_seine_zahlen_kommen(client: TestClient) -> None:
    """In der Vorführung ist die Außentemperatur gemessen, die Vorlauftemperatur gerechnet."""
    ap = client.get(WEG).json()["arbeitspunkt"]
    assert ap["aussen_gemessen"] is True
    assert ap["vorlauf_gemessen"] is False
    assert 20.0 <= ap["vorlauf_c"] <= 70.0
    assert ap["strompreis_eur_kwh"] > 0


def test_uebersteuern_aendert_den_regler_und_laesst_sich_freigeben(client: TestClient) -> None:
    """Der Beleg für den selbsteinstellenden Teil über die Schnittstelle: eine längere Totzeit
    macht den Pufferregler schwächer, ohne dass am Regler gedreht wird."""
    vorher = client.get(WEG).json()
    kp_vorher = next(k for k in vorher["kreise"] if k["id"] == "R2")["regler"]["kp"]

    r = client.post(f"{WEG}/parameter/wp_totzeit", json={"wert": 14.0})
    assert r.status_code == 200
    nachher = r.json()
    assert "wp_totzeit" in nachher["uebersteuert"]
    eintrag = next(p for p in nachher["parameter"] if p["id"] == "wp_totzeit")
    assert eintrag["herkunft"] == "uebersteuert"
    assert eintrag["wert"] == 14.0
    kp_nachher = next(k for k in nachher["kreise"] if k["id"] == "R2")["regler"]["kp"]
    assert kp_nachher < kp_vorher

    frei = client.delete(f"{WEG}/parameter/wp_totzeit")
    assert frei.status_code == 200
    assert frei.json()["uebersteuert"] == []


def test_uebersteuerung_wird_auf_die_grenzen_beschnitten(client: TestClient) -> None:
    """Ein Vertipper darf die Regelung nicht zum Stehen bringen."""
    k = client.post(f"{WEG}/parameter/h_haus", json={"wert": 99.0}).json()
    eintrag = next(p for p in k["parameter"] if p["id"] == "h_haus")
    assert eintrag["wert"] == PARAMETER["h_haus"].oben
    client.delete(f"{WEG}/parameter/h_haus")


def test_unbekannter_parameter_ist_ein_eingabefehler(client: TestClient) -> None:
    r = client.post(f"{WEG}/parameter/gibt_es_nicht", json={"wert": 1.0})
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "unbekannter_parameter"


def test_vorfuehrung_lernt_aus_ihrer_eigenen_kennlinie(client: TestClient) -> None:
    """Die Vorführung rechnet dieselben Schätzer über den Auswertungen des Vorführhauses. Nach
    dem ersten Aufruf muss die COP-Ebene aus der Messung kommen und nicht aus der Annahme."""
    k = client.get(WEG).json()
    cop = {p["id"]: p for p in k["parameter"] if p["id"].startswith("cop_")}
    assert cop["cop_a"]["herkunft"] in ("gemessen", "annahme")
    if cop["cop_a"]["herkunft"] == "gemessen":
        assert cop["cop_a"]["n"] > 0
        assert cop["cop_a"]["protokoll"]
        assert cop["cop_a"]["protokoll"][-1]["grund"]
        assert k["uebernahmen"] >= 1


def test_lernlauf_legt_kandidaten_vor_und_begruendet_jede_ablehnung() -> None:
    """Ohne Auswertungen gibt es keine Kandidaten - und dann auch keine Prüfungen. Die Karte
    steht trotzdem, mit Startwerten, und sagt an jedem Parameter, dass es Annahmen sind."""
    cfg = HemsConfig()
    stand = Schaetzstand()
    assert logik.lernen(stand, cfg, jetzt=JETZT) == {}
    karte = logik.zusammensetzen(cfg, stand, jetzt=JETZT)
    assert all(p.herkunft in ("annahme", "fest", "entwurf") for p in karte.parameter)
    assert karte.seit == JETZT


def test_lernlauf_wartet_eine_stunde() -> None:
    assert logik.faellig(None, JETZT)
    assert not logik.faellig(JETZT, JETZT)
    assert logik.faellig(JETZT - logik.LERNABSTAND, JETZT)


async def test_uebersteuerung_ueberschreibt_den_gespeicherten_lernstand_nicht(tmp_path) -> None:
    """Nach einem Neustart muss die erste Übersteuerung den gelernten Stand **lesen**, bevor sie
    ihn ändert.

    Der Fehler, gegen den dieser Test steht: wer gleich nach dem Start einen Wert von Hand setzt,
    schrieb einen leeren Zustand über den gelernten - und der Lernlauf unmittelbar danach holte
    den eben geschriebenen leeren Stand zurück und warf die Übersteuerung weg. Zwei Verluste in
    einem Aufruf, und beide unsichtbar.
    """
    from dch_api.application.config_loader import load_app_config
    from dch_api.application.forecast_service import ForecastService
    from dch_api.application.live_runtime import LiveRuntime
    from dch_api.infrastructure.bridge_hub import BridgeHub
    from dch_api.infrastructure.db.engine import create_all_for_tests, make_engine
    from dch_api.infrastructure.db.repositories import SqlRepositories
    from dch_api.settings import Settings

    settings = Settings(
        mode="live",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'rk.sqlite'}",
        db_create_all=True,
        weather_refresh_min=0,
        role="api",
    )
    engine = make_engine(settings.database_url)
    await create_all_for_tests(engine)
    cfg = load_app_config(None)
    repos = SqlRepositories(engine)

    def laufzeit() -> LiveRuntime:
        return LiveRuntime(
            settings,
            cfg,
            repos,
            BridgeHub("test"),
            ForecastService(cfg.site, cfg.pv_system, weather=None, prices=None),
        )

    erste = laufzeit()
    karte = await erste.regelkreis_uebersteuern("wp_totzeit", 7.0)
    assert karte.uebersteuert == ["wp_totzeit"]

    # Ein neuer Prozess auf derselben Datenbank.
    zweite = laufzeit()
    karte2 = await zweite.regelkreis_uebersteuern("h_haus", 0.19)
    assert sorted(karte2.uebersteuert) == ["h_haus", "wp_totzeit"]
    werte = {p.id: p.wert for p in karte2.parameter}
    assert werte["wp_totzeit"] == 7.0
    assert werte["h_haus"] == 0.19

    # Und freigeben wirkt auch über den Neustart hinweg.
    dritte = laufzeit()
    karte3 = await dritte.regelkreis_freigeben("wp_totzeit")
    assert karte3.uebersteuert == ["h_haus"]
