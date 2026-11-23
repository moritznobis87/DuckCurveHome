"""Die Rechtematrix und der Postausgang - reine Logik, ohne Datenbank.

Die Matrix ist die eine Stelle, an der steht, wer was darf (`dch_api/auth/rechte.py`). Sie hat
keine Datenbank und kein HTTP, also lässt sie sich hier Zeile für Zeile festhalten - und genau
das ist der Sinn: an einer Tabelle, die sich mit jedem neuen Endpunkt verschiebt, soll man sehen,
was sich verschoben hat.
"""

from __future__ import annotations

import pytest

from dch_api.auth import rechte
from dch_api.post import aktiv, fehlende_angaben, versandweg
from dch_api.settings import Settings

AKTEN = [
    "/import/tibber-invoice",
    "/import/tibber-invoices",
    "/energy/pv",
    "/export/minutes",
    "/system/door",
    "/auth/personen",
    "/alfred/rechnung",
]


@pytest.mark.parametrize("pfad", AKTEN)
def test_akten_bleiben_dem_hausherrn(pfad: str) -> None:
    assert rechte.ist_akte(pfad)
    assert rechte.darf("hausherr", "GET", pfad)
    for rolle in ("bewohner", "gast", "service"):
        assert not rechte.darf(rolle, "GET", pfad), rolle
        assert not rechte.darf(rolle, "POST", pfad), rolle


@pytest.mark.parametrize(
    "pfad",
    ["/live/state", "/history", "/plan", "/haus", "/waerme", "/energy/strom", "/waermepumpe"],
)
def test_alle_duerfen_das_haus_sehen(pfad: str) -> None:
    for rolle in rechte.ROLLEN:
        assert rechte.darf(rolle, "GET", pfad), rolle


def test_bewohner_stellt_im_haus() -> None:
    for pfad in ("/control/actuators/licht", "/rooms/1/setpoint", "/push/subscribe", "/alfred/ask"):
        assert rechte.darf("bewohner", "POST", pfad), pfad
    # Nicht an der Anlage und nicht am Gerät.
    for pfad in ("/config/heat", "/waermepumpe/einstellungen/x", "/system/update", "/import/ha"):
        assert not rechte.darf("bewohner", "POST", pfad), pfad


def test_service_arbeitet_am_geraet_und_nicht_im_haus() -> None:
    for pfad in ("/system/update", "/system/geraet/aktion"):
        assert rechte.darf("service", "POST", pfad), pfad
    for pfad in ("/control/actuators/licht", "/rooms/1/setpoint", "/config/heat"):
        assert not rechte.darf("service", "POST", pfad), pfad


def test_gast_stellt_nichts() -> None:
    for pfad in ("/control/actuators/licht", "/rooms/1/setpoint", "/push/subscribe"):
        assert not rechte.darf("gast", "POST", pfad), pfad


def test_eigene_sachen_darf_jeder_angemeldete() -> None:
    """Passkeys, Sitzungen und Abmelden gehören der Person - auch einem Gast."""
    for rolle in rechte.ROLLEN:
        assert rechte.darf(rolle, "POST", "/auth/abmelden"), rolle
        assert rechte.darf(rolle, "POST", "/auth/passkeys/beginnen"), rolle
        assert rechte.darf(rolle, "GET", "/auth/ich"), rolle


def test_unbekannter_pfad_ist_lesbar_und_nicht_stellbar() -> None:
    """Die Richtung, in der ein Versehen harmlos bleibt: ein neuer Bericht wird versehentlich
    sichtbar, ein neuer Schalter nicht versehentlich bedienbar."""
    assert rechte.darf("gast", "GET", "/etwas/ganz/neues")
    assert not rechte.darf("bewohner", "POST", "/etwas/ganz/neues")
    assert rechte.darf("hausherr", "POST", "/etwas/ganz/neues")


# ---------------------------------------------------------------------------
# Postausgang
# ---------------------------------------------------------------------------


def test_ohne_konfiguration_wird_nichts_verschickt() -> None:
    s = Settings()
    assert versandweg(s) == ""
    assert not aktiv(s)
    assert "DCH_SMTP_HOST oder DCH_RESEND_SCHLUESSEL" in fehlende_angaben(s)


def test_smtp_hat_vorrang_vor_https() -> None:
    s = Settings(
        smtp_host="mail.example.org",
        resend_schluessel="re_x",
        absender="haus@example.org",
        anmelde_url="https://home.duckcurve.de",
    )
    assert versandweg(s) == "smtp"
    assert aktiv(s)
    assert fehlende_angaben(s) == []


def test_https_allein_genuegt() -> None:
    s = Settings(
        resend_schluessel="re_x",
        absender="haus@example.org",
        anmelde_url="https://home.duckcurve.de",
    )
    assert versandweg(s) == "https"
    assert aktiv(s)


def test_absender_fehlt() -> None:
    s = Settings(smtp_host="mail.example.org", anmelde_url="https://home.duckcurve.de")
    assert not aktiv(s)
    assert fehlende_angaben(s) == ["DCH_ABSENDER"]


def test_anmelde_url_faellt_auf_die_erste_herkunft_zurueck() -> None:
    """Eine Einstellung weniger: die Adresse des Links steht schon in den Passkey-Herkünften."""
    s = Settings(passkey_herkuenfte=["https://home.duckcurve.de/"])
    assert s.anmeldung_url == "https://home.duckcurve.de"


# ---------------------------------------------------------------------------
# Passkey-Einstellungen
# ---------------------------------------------------------------------------


def test_passkey_einstellung_wird_geprueft() -> None:
    gut = Settings(passkey_rp_id="duckcurve.de", passkey_herkuenfte=["https://home.duckcurve.de"])
    assert gut.passkey_problem() is None
    # localhost gilt dem Browser als sicherer Kontext, auch ohne https.
    assert (
        Settings(
            passkey_rp_id="localhost", passkey_herkuenfte=["http://localhost:3000"]
        ).passkey_problem()
        is None
    )
    # Eine Herkunft, die nicht zur RP-ID passt, laesst jede Zeremonie scheitern.
    assert "passt nicht" in (
        Settings(
            passkey_rp_id="duckcurve.de", passkey_herkuenfte=["https://example.org"]
        ).passkey_problem()
        or ""
    )
    assert "nicht https" in (
        Settings(
            passkey_rp_id="duckcurve.de", passkey_herkuenfte=["http://home.duckcurve.de"]
        ).passkey_problem()
        or ""
    )
