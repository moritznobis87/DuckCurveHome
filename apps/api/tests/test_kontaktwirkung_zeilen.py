"""Minutenzeilen werden Proben: die Brücke zwischen Bestand und Ereignisstudie."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from dch_api.application import kontaktwirkung as logik
from hems_core.domain import HemsConfig

BERLIN = ZoneInfo("Europe/Berlin")
T0 = datetime(2026, 11, 2, 0, 0, tzinfo=UTC)


def zeile(m: int, kontakt: float | None, kw: float | None) -> logik.Zeile:
    return {
        "ts": (T0 + timedelta(minutes=m)).isoformat(),
        "hp_release_contact": kontakt,
        "heat_pump_power_kw": kw,
    }


def test_der_kontakt_gilt_ab_der_haelfte_der_minute_als_geschlossen() -> None:
    p = logik.proben(
        [zeile(0, 0.0, 0.1), zeile(1, 0.4, 0.1), zeile(2, 0.5, 0.1), zeile(3, 1.0, None)]
    )
    assert [x.kontakt for x in p] == [False, False, True, True]
    assert p[3].kw is None


def test_ein_fehlender_kontakt_bleibt_unbekannt_und_wird_kein_offen() -> None:
    p = logik.proben([zeile(0, None, 2.0)])
    assert p[0].kontakt is None
    assert p[0].kw == 2.0


def test_die_stunde_des_vergleichs_ist_die_ortsstunde() -> None:
    # K1 schließt um 11:00 UTC, also um 12 Uhr in Berlin (Winterzeit). Der Vergleich gehört zu 12.
    zeilen = [
        zeile(m, 1.0 if 660 <= m < 700 else 0.0, 4.0 if 663 <= m < 720 else 0.0)
        for m in range(1440)
    ]
    cfg = HemsConfig()
    k = logik.zusammenstellen(zeilen, cfg, BERLIN, tage=7, von=T0, bis=T0 + timedelta(days=1))
    assert k.n == 1
    assert k.ereignisse[0].at.astimezone(BERLIN).hour == 12
    assert k.schwelle_kw == cfg.heat_pump.running_threshold_kw
    assert k.days == 7


def test_die_vorfuehrung_sagt_wie_weit_sie_zurueckreicht() -> None:
    k = logik.zusammenstellen(
        [], HemsConfig(), BERLIN, tage=30, von=T0, bis=T0 + timedelta(days=30), reicht_h=72
    )
    assert "72 Stunden" in k.hinweise_de[0]
    assert k.von == T0
