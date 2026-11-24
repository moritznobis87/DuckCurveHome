"""Die Karten der Bereichsübersicht: was auf ihnen steht und woher die Ampel kommt."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi.testclient import TestClient

from dch_api.application import uebersicht
from dch_api.schemas import (
    AnlageOut,
    AnlageSpeicherOut,
    ApiSelbstOut,
    CoverageOut,
    CoverageSeriesOut,
    DoorEntryOut,
    DoorLogOut,
    EnergySummaryOut,
    EnergyTotalsOut,
    ForecastDayOut,
    ForecastEvaluationOut,
    GeraetOut,
    HeatReportOut,
    KontaktwirkungOut,
    LiveStateOut,
    PlanIntervalOut,
    PlanOut,
    PushGeraeteOut,
    PushGeraetOut,
    RegelkreisOut,
    ReglerEinstellungenOut,
    StorageReportOut,
    StorageTableOut,
    WaermepumpeOut,
)
from hems_core.domain import EnergySnapshot, Measurement, Quality
from hems_core.forecasting.evaluation import ForecastScore
from hems_core.regelkreis.karte import KreisAnsicht, ReservenAnsicht

JETZT = datetime(2026, 11, 24, 12, 0, tzinfo=UTC)


def test_der_bereich_anlage_liefert_sechs_karten_in_der_reihenfolge_des_seitenbaums(
    client: TestClient,
) -> None:
    antwort = client.get("/api/v1/uebersicht/anlage")
    assert antwort.status_code == 200
    daten = antwort.json()
    assert daten["bereich"] == "anlage"
    # Die Annahmen fehlen mit Absicht: dort steht nichts, was sich von selbst ändert.
    assert [k["weg"] for k in daten["karten"]] == [
        "/waerme/anlage",
        "/waerme/waermepumpe",
        "/waerme/fahrplan",
        "/waerme/wirkung",
        "/waerme/regelkreis",
        "/waerme/waermepumpe/regler",
    ]
    for karte in daten["karten"]:
        assert karte["ampel"] in {"gut", "warn", "schlecht", "aus"}
        # Eine Ampel, die nicht gut ist, sagt warum. Eine gute schweigt.
        assert bool(karte["grund_de"]) == (karte["ampel"] != "gut"), karte


def test_ein_bereich_ohne_uebersicht_ist_nicht_gefunden(client: TestClient) -> None:
    antwort = client.get("/api/v1/uebersicht/geld")
    assert antwort.status_code == 404
    assert antwort.json()["error"]["code"] == "unknown_area"


def _anlage(soc: float | None) -> AnlageOut:
    return AnlageOut.model_construct(speicher=AnlageSpeicherOut.model_construct(soc=soc))


def test_die_anlage_zeigt_den_ladestand_des_puffers() -> None:
    karte = uebersicht.karte_anlage(_anlage(0.523))
    assert (karte.leitzahl_de, karte.dazu_de, karte.ampel) == (
        "52 %",
        "Ladestand des Puffers",
        "gut",
    )


def test_ohne_messwert_vom_puffer_hat_die_karte_keine_zahl_und_sagt_es() -> None:
    karte = uebersicht.karte_anlage(_anlage(None))
    assert karte.leitzahl_de is None
    assert karte.ampel == "aus"
    assert karte.grund_de == "Vom Puffer liegt kein Messwert vor."


def _wp(leistung: Measurement) -> WaermepumpeOut:
    return WaermepumpeOut.model_construct(zustand_de="heizt", leistung_zaehler_kw=leistung)


def test_die_waermepumpe_zeigt_die_leistung_am_zaehler_und_das_wort_des_dienstes() -> None:
    karte = uebersicht.karte_waermepumpe(_wp(Measurement.ok(1.94, JETZT, "zaehler")))
    assert (karte.leitzahl_de, karte.dazu_de, karte.ampel) == ("1,9 kW", "heizt", "gut")


def test_eine_nicht_gemessene_leistung_wird_nicht_als_null_gezeigt() -> None:
    fehlt = Measurement.missing(Quality.UNAVAILABLE, JETZT, "zaehler")
    karte = uebersicht.karte_waermepumpe(_wp(fehlt))
    assert karte.leitzahl_de is None
    assert karte.ampel == "aus"
    assert karte.dazu_de == "heizt"


def _plan(zustaende: list[str], warnung: str = "") -> PlanOut:
    return PlanOut.model_construct(
        intervals=[PlanIntervalOut.model_construct(planned_hp_state=z) for z in zustaende],
        planner_warn_de=warnung,
    )


def test_der_fahrplan_zaehlt_die_angeforderten_viertelstunden_als_stunden() -> None:
    karte = uebersicht.karte_fahrplan(_plan(["release"] * 6 + ["off", "free", "avoid"]))
    assert (karte.leitzahl_de, karte.ampel, karte.grund_de) == ("1,5 h", "gut", "")


def test_die_warnung_des_planers_macht_die_ampel_des_fahrplans_gelb() -> None:
    karte = uebersicht.karte_fahrplan(_plan(["release"], "Fahrplan unter Zeitdruck gerechnet."))
    assert karte.ampel == "warn"
    assert karte.grund_de == "Fahrplan unter Zeitdruck gerechnet."


def test_ohne_fahrplan_sagt_die_karte_dass_noch_keiner_gerechnet_ist() -> None:
    karte = uebersicht.karte_fahrplan(None)
    assert (karte.leitzahl_de, karte.ampel) == (None, "aus")
    assert karte.grund_de == "Es ist noch kein Fahrplan gerechnet."


def _wirkung(urteil: str, quote: float | None = 0.6) -> KontaktwirkungOut:
    return KontaktwirkungOut.model_construct(
        urteil=urteil, urteil_de="Der Satz der Seite.", quote=quote
    )


def test_die_ampel_der_wirkung_folgt_dem_urteil_der_seite() -> None:
    assert uebersicht.karte_wirkung(_wirkung("wirkt")).ampel == "gut"
    assert uebersicht.karte_wirkung(_wirkung("kein_unterschied")).ampel == "warn"
    assert uebersicht.karte_wirkung(_wirkung("seltener")).ampel == "warn"
    # Zu wenige Ereignisse sind kein schlechtes Urteil, sondern keines.
    assert uebersicht.karte_wirkung(_wirkung("offen")).ampel == "aus"
    # Ein Urteil, das diese Datei nicht kennt, wird nicht zu „gut“ geraten.
    assert uebersicht.karte_wirkung(_wirkung("etwas_neues")).ampel == "aus"


def test_die_wirkung_nennt_die_quote_und_bei_gutem_urteil_keinen_grund() -> None:
    gut = uebersicht.karte_wirkung(_wirkung("wirkt", 0.874))
    assert (gut.leitzahl_de, gut.grund_de) == ("87 %", "")
    # Der lange Satz der Seite gehört nicht auf die Karte: dort steht nur, dass ein Urteil fehlt.
    offen = uebersicht.karte_wirkung(_wirkung("offen", None))
    assert (offen.leitzahl_de, offen.grund_de) == (None, uebersicht.WIRKUNG_OFFEN)
    # Ein Urteil, das etwas zu sagen hat, bringt den Satz der Seite mit.
    assert uebersicht.karte_wirkung(_wirkung("seltener")).grund_de == "Der Satz der Seite."


def test_der_regler_zeigt_wie_viele_einstellungen_gelesen_sind() -> None:
    gelesen = ReglerEinstellungenOut.model_construct(
        gelesen=22, satz_de="Alle 22 gelesen.", hindernis_de=None
    )
    karte = uebersicht.karte_regler(gelesen)
    assert (karte.leitzahl_de, karte.dazu_de, karte.ampel) == ("22", "Einstellungen gelesen", "gut")
    nichts = ReglerEinstellungenOut.model_construct(
        gelesen=0, satz_de="Noch nichts gelesen.", hindernis_de=None
    )
    assert uebersicht.karte_regler(nichts).grund_de == "Noch nichts gelesen."
    assert uebersicht.karte_regler(nichts).ampel == "aus"


def test_der_regelkreis_ohne_eingriff_ist_gut_und_zaehlt_null() -> None:
    karte = uebersicht.karte_regelkreis(RegelkreisOut.model_construct(kreise=[], uebersteuert=[]))
    assert (karte.leitzahl_de, karte.ampel, karte.grund_de) == ("0", "gut", "")


def test_uebersteuerte_parameter_machen_den_regelkreis_gelb_in_einzahl_und_mehrzahl() -> None:
    einer = uebersicht.karte_regelkreis(
        RegelkreisOut.model_construct(kreise=[], uebersteuert=["a"])
    )
    assert (einer.leitzahl_de, einer.ampel) == ("1", "warn")
    assert einer.grund_de == "Ein Parameter ist von Hand übersteuert."
    drei = uebersicht.karte_regelkreis(
        RegelkreisOut.model_construct(kreise=[], uebersteuert=["a", "b", "c"])
    )
    assert drei.grund_de == "3 Parameter sind von Hand übersteuert."


def test_eine_zu_kleine_reserve_wiegt_schwerer_als_eine_uebersteuerung() -> None:
    knapp = KreisAnsicht.model_construct(
        name="Vorlauf", reserven=ReservenAnsicht.model_construct(gut=False)
    )
    gut = KreisAnsicht.model_construct(
        name="Raum", reserven=ReservenAnsicht.model_construct(gut=True)
    )
    ohne = KreisAnsicht.model_construct(name="Planung", reserven=None)
    karte = uebersicht.karte_regelkreis(
        RegelkreisOut.model_construct(kreise=[gut, ohne, knapp], uebersteuert=["a"])
    )
    assert karte.ampel == "warn"
    assert karte.grund_de == "Die Reserve im Kreis Vorlauf ist zu klein."
    # Die Zahl bleibt die der Übersteuerungen; der Grund nennt das Schwerere.
    assert karte.leitzahl_de == "1"


async def test_eine_quelle_die_wirft_nimmt_nur_ihre_karte_mit() -> None:
    async def wirft() -> AnlageOut:
        raise RuntimeError("Datenbank weg")

    karte = await uebersicht._karte("/waerme/anlage", wirft, uebersicht.karte_anlage)
    assert (karte.weg, karte.ampel, karte.grund_de) == (
        "/waerme/anlage",
        "aus",
        uebersicht.KEINE_AUSKUNFT,
    )


def test_der_bereich_energie_liefert_sechs_karten_in_der_reihenfolge_des_seitenbaums(
    client: TestClient,
) -> None:
    antwort = client.get("/api/v1/uebersicht/energie")
    assert antwort.status_code == 200
    daten = antwort.json()
    assert daten["bereich"] == "energie"
    # Die Jahreskarte fehlt mit Absicht: sie hat keine Zahl des Tages.
    assert [k["weg"] for k in daten["karten"]] == [
        "/strom",
        "/waerme",
        "/strom/pv",
        "/system",
        "/strom/speicher",
        "/strom/wallbox",
    ]
    for karte in daten["karten"]:
        assert bool(karte["grund_de"]) == (karte["ampel"] != "gut"), karte


def test_jeder_bereich_mit_karten_ist_ueber_seinen_schluessel_erreichbar(
    client: TestClient,
) -> None:
    for schluessel in uebersicht.BEREICHE:
        antwort = client.get(f"/api/v1/uebersicht/{schluessel}")
        assert antwort.status_code == 200, schluessel
        assert antwort.json()["bereich"] == schluessel


def _bilanz(minuten: int = 600, **mengen: float) -> EnergySummaryOut:
    return EnergySummaryOut.model_construct(
        totals=EnergyTotalsOut.model_construct(minutes=minuten, **mengen)
    )


def test_strom_photovoltaik_und_wallbox_lesen_dieselbe_tagesbilanz() -> None:
    bilanz = _bilanz(house_kwh=13.94, pv_kwh=0.61, ev_kwh=7.0)
    strom = uebersicht.karte_strom(bilanz)
    assert (strom.weg, strom.leitzahl_de, strom.dazu_de, strom.ampel) == (
        "/strom",
        "13,9 kWh",
        "Verbrauch heute",
        "gut",
    )
    sonne = uebersicht.karte_photovoltaik(bilanz)
    assert (sonne.weg, sonne.leitzahl_de, sonne.dazu_de) == ("/strom/pv", "0,6 kWh", "Ertrag heute")
    auto = uebersicht.karte_wallbox(bilanz)
    assert (auto.weg, auto.leitzahl_de, auto.dazu_de) == (
        "/strom/wallbox",
        "7,0 kWh",
        "heute geladen",
    )


def test_ein_tag_ohne_bewertete_minute_zeigt_keine_null() -> None:
    # Kurz nach Mitternacht oder nach einem Ausfall: 0,0 kWh waere eine Behauptung.
    leer = _bilanz(minuten=0)
    for karte in (
        uebersicht.karte_strom(leer),
        uebersicht.karte_photovoltaik(leer),
        uebersicht.karte_wallbox(leer),
        uebersicht.karte_waerme(HeatReportOut.model_construct(summary=leer, thermal_kwh_est=0.0)),
    ):
        assert (karte.leitzahl_de, karte.ampel, karte.grund_de) == (
            None,
            "aus",
            uebersicht.HEUTE_LEER,
        )


def test_die_waerme_nennt_ihre_zahl_eine_schaetzung() -> None:
    karte = uebersicht.karte_waerme(
        HeatReportOut.model_construct(summary=_bilanz(), thermal_kwh_est=24.68)
    )
    assert (karte.weg, karte.leitzahl_de, karte.dazu_de, karte.ampel) == (
        "/waerme",
        "24,7 kWh",
        "Wärme heute, geschätzt",
        "gut",
    )


def _auswertung(fehler: float | None, mit_wertung: bool = True) -> ForecastEvaluationOut:
    wertung = (
        ForecastScore(
            n=40,
            mae_kw=0.3,
            bias_kw=0.1,
            rmse_kw=0.4,
            energy_forecast_kwh=10.0,
            energy_actual_kwh=12.0,
            energy_error_pct=fehler,
        )
        if mit_wertung
        else None
    )
    return ForecastEvaluationOut.model_construct(
        yesterday=ForecastDayOut.model_construct(score=wertung)
    )


def test_die_prognose_zeigt_die_abweichung_von_gestern_mit_vorzeichen() -> None:
    zu_tief = uebersicht.karte_prognose(_auswertung(-17.6))
    assert (zu_tief.weg, zu_tief.leitzahl_de, zu_tief.dazu_de, zu_tief.ampel) == (
        "/system",
        "−18 %",
        "Abweichung gestern",
        "gut",
    )
    assert uebersicht.karte_prognose(_auswertung(4.2)).leitzahl_de == "+4 %"
    assert uebersicht.karte_prognose(_auswertung(0.0)).leitzahl_de == "0 %"


def test_ohne_vergleich_von_gestern_hat_die_prognose_keine_zahl() -> None:
    for auswertung in (_auswertung(None), _auswertung(0.0, mit_wertung=False)):
        karte = uebersicht.karte_prognose(auswertung)
        assert (karte.leitzahl_de, karte.ampel) == (None, "aus")
        assert "gestern" in karte.grund_de


def _augenblick(stand: Measurement) -> LiveStateOut:
    return LiveStateOut.model_construct(snapshot=EnergySnapshot.model_construct(battery_soc=stand))


def test_der_speicher_zeigt_seinen_ladestand_in_prozent() -> None:
    karte = uebersicht.karte_speicher(
        _augenblick(Measurement(value=0.636, observed_at=JETZT, quality=Quality.OK, source="t"))
    )
    assert (karte.weg, karte.leitzahl_de, karte.dazu_de, karte.ampel) == (
        "/strom/speicher",
        "64 %",
        "Ladestand",
        "gut",
    )


def test_ein_speicher_ohne_brauchbaren_ladestand_zeigt_keine_zahl() -> None:
    for stand in (
        Measurement(value=None, observed_at=JETZT, quality=Quality.UNAVAILABLE, source="t"),
        Measurement(value=0.5, observed_at=JETZT, quality=Quality.UNAVAILABLE, source="t"),
    ):
        karte = uebersicht.karte_speicher(_augenblick(stand))
        assert (karte.leitzahl_de, karte.ampel) == (None, "aus")
        assert karte.grund_de


def test_der_bereich_system_liefert_fuenf_karten_in_der_reihenfolge_des_seitenbaums(
    client: TestClient,
) -> None:
    antwort = client.get("/api/v1/uebersicht/system")
    assert antwort.status_code == 200
    daten = antwort.json()
    assert daten["bereich"] == "system"
    assert [k["weg"] for k in daten["karten"]] == [
        "/system/mitteilungen",
        "/system/haustuer",
        "/system/geraet",
        "/system/zugang",
        "/system/daten",
    ]
    for karte in daten["karten"]:
        assert bool(karte["grund_de"]) == (karte["ampel"] != "gut"), karte


def _angemeldet(*fehlversuche: int) -> PushGeraeteOut:
    return PushGeraeteOut(
        devices=[
            PushGeraetOut(label=f"Gerät {i}", fehlversuche=f) for i, f in enumerate(fehlversuche)
        ]
    )


def test_die_mitteilungen_zaehlen_die_angemeldeten_geraete_in_einzahl_und_mehrzahl() -> None:
    eines = uebersicht.karte_mitteilungen(_angemeldet(0))
    assert (eines.weg, eines.leitzahl_de, eines.dazu_de, eines.ampel, eines.grund_de) == (
        "/system/mitteilungen",
        "1",
        "Gerät angemeldet",
        "gut",
        "",
    )
    drei = uebersicht.karte_mitteilungen(_angemeldet(0, 0, 0))
    assert (drei.leitzahl_de, drei.dazu_de) == ("3", "Geräte angemeldet")


def test_eine_gescheiterte_zustellung_macht_die_mitteilungen_gelb() -> None:
    eine = uebersicht.karte_mitteilungen(_angemeldet(0, 2))
    assert (eine.ampel, eine.grund_de) == (
        "warn",
        "Bei einem Gerät ist die Zustellung zuletzt gescheitert.",
    )
    zwei = uebersicht.karte_mitteilungen(_angemeldet(1, 4, 0))
    assert zwei.grund_de == "Bei 2 Geräten ist die Zustellung zuletzt gescheitert."


def test_ohne_angemeldetes_geraet_sagen_die_mitteilungen_das_statt_einer_null() -> None:
    karte = uebersicht.karte_mitteilungen(_angemeldet())
    assert (karte.leitzahl_de, karte.ampel) == (None, "aus")
    assert karte.grund_de == "Kein Gerät ist für Mitteilungen angemeldet."


def _tuer(*gewaehrt: bool) -> DoorLogOut:
    return DoorLogOut(
        entries=[
            DoorEntryOut(
                at=JETZT,
                actor="jemand",
                door="Haustür",
                method="nfc",
                outcome="",
                granted=g,
                reason="",
            )
            for g in gewaehrt
        ],
        days=1,
        note_de="",
    )


def test_die_haustuer_zaehlt_die_zutritte_und_nicht_die_abgelehnten_versuche() -> None:
    karte = uebersicht.karte_haustuer(_tuer(True, True, True))
    assert (karte.weg, karte.leitzahl_de, karte.dazu_de, karte.ampel) == (
        "/system/haustuer",
        "3",
        "Zutritte seit gestern",
        "gut",
    )
    assert uebersicht.karte_haustuer(_tuer(True)).dazu_de == "Zutritt seit gestern"
    # Niemand kam: das ist eine Auskunft und keine Luecke.
    leer = uebersicht.karte_haustuer(_tuer())
    assert (leer.leitzahl_de, leer.ampel) == ("0", "gut")


def test_ein_abgelehnter_versuch_macht_die_haustuer_gelb() -> None:
    einer = uebersicht.karte_haustuer(_tuer(True, False))
    assert (einer.leitzahl_de, einer.ampel, einer.grund_de) == (
        "1",
        "warn",
        "Ein Versuch an der Tür wurde abgelehnt.",
    )
    assert (
        uebersicht.karte_haustuer(_tuer(False, False, False)).grund_de
        == "3 Versuche an der Tür wurden abgelehnt."
    )


def _geraet(ampel: str, text: str = "") -> GeraetOut:
    return GeraetOut.model_construct(
        unterstuetzt=True, api=ApiSelbstOut.model_construct(), ampel=ampel, text_de=text
    )


def test_das_hausgeraet_uebernimmt_ampel_und_satz_seiner_seite() -> None:
    gut = uebersicht.karte_geraet(_geraet("gut", "Alles in Ordnung."))
    assert (gut.weg, gut.leitzahl_de, gut.ampel, gut.grund_de) == (
        "/system/geraet",
        None,
        "gut",
        "",
    )
    gestoert = uebersicht.karte_geraet(_geraet("schlecht", "Die Sicherung von heute Nacht fehlt."))
    assert (gestoert.ampel, gestoert.grund_de) == (
        "schlecht",
        "Die Sicherung von heute Nacht fehlt.",
    )
    # Ein Zustand ohne Satz bleibt nicht stumm.
    assert uebersicht.karte_geraet(_geraet("warn")).grund_de == uebersicht.KEINE_AUSKUNFT


def _platz(bytes_gesamt: int) -> StorageReportOut:
    tabellen = (
        [
            StorageTableOut(
                name="measurements_minute",
                total_bytes=bytes_gesamt,
                table_bytes=bytes_gesamt,
                index_bytes=0,
                rows_estimate=1,
            )
        ]
        if bytes_gesamt
        else []
    )
    return StorageReportOut(
        tables=tabellen,
        total_bytes=bytes_gesamt,
        raw_retention_days=14,
        note_de="" if bytes_gesamt else "Ohne PostgreSQL gibt es keine Größenangaben.",
    )


def test_zugang_und_sicherung_nennt_die_groesse_der_datenbank() -> None:
    gross = uebersicht.karte_zugang(_platz(2_340_000_000))
    assert (gross.weg, gross.leitzahl_de, gross.dazu_de, gross.ampel) == (
        "/system/zugang",
        "2,3 GB",
        "Größe der Datenbank",
        "gut",
    )
    assert uebersicht.karte_zugang(_platz(412_000_000)).leitzahl_de == "412 MB"
    ohne = uebersicht.karte_zugang(_platz(0))
    assert (ohne.leitzahl_de, ohne.ampel, ohne.grund_de) == (
        None,
        "aus",
        "Ohne PostgreSQL gibt es keine Größenangaben.",
    )


def _abdeckung(*anteile: tuple[float, int]) -> CoverageOut:
    return CoverageOut.model_construct(
        series=[
            CoverageSeriesOut.model_construct(
                coverage=anteil, minutes_seen=gesehen, minutes_expected=10_080
            )
            for anteil, gesehen in anteile
        ]
    )


def test_daten_pruefen_nennt_die_abdeckung_der_schlechteren_reihe() -> None:
    karte = uebersicht.karte_daten(_abdeckung((0.9987, 10_067), (0.9712, 9_790)))
    assert (karte.weg, karte.leitzahl_de, karte.dazu_de, karte.ampel) == (
        "/system/daten",
        "97,1 %",
        "Abdeckung in 7 Tagen",
        "gut",
    )


def test_ohne_gezaehlte_minute_zeigt_daten_pruefen_keine_null() -> None:
    # Ohne Datenbank ist in keiner Reihe etwas gezaehlt. 0,0 % waere eine Behauptung.
    for abdeckung in (_abdeckung((0.0, 0), (0.0, 0)), _abdeckung()):
        karte = uebersicht.karte_daten(abdeckung)
        assert (karte.leitzahl_de, karte.ampel) == (None, "aus")
        assert karte.grund_de
