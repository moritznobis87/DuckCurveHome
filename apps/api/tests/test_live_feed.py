"""Takt und Wiederholungsfilter des Live-Stroms.

Gemessen am 03.11.2026 schickte der Strom 6,4 kB je Sekunde an jeden offenen Bildschirm, also
549 MB am Tag. Diese Prüfungen halten die drei Regeln fest, die das abstellen, und die eine
Ausnahme, die ein Mensch auslöst.
"""

from __future__ import annotations

from typing import Any

from dch_api.application.live_feed import Takt, kern


def zustand(wert: float = 1.0, uhr: str = "12:00:00") -> dict[str, Any]:
    return {
        "snapshot": {"pv_power_kw": {"value": wert, "observed_at": "12:00:00"}},
        "system": {"server_time": uhr, "bridge_online": True},
    }


# ------------------------------------------------------------------ Kern


def test_die_uhrzeit_des_servers_zaehlt_nicht_zum_kern() -> None:
    """Ohne diese Ausnahme waere jeder Zustand neu und der Filter wirkungslos."""
    assert kern(zustand(uhr="12:00:00")) == kern(zustand(uhr="12:00:05"))


def test_der_zeitstempel_eines_messwerts_zaehlt_nirgends_mit() -> None:
    """Bei abgeleiteten und fehlenden Werten ist er schlicht `jetzt` und bewegt sich von selbst."""
    a = {"snapshot": {"timestamp": "12:00:01", "haus": {"value": 1.0, "observed_at": "12:00:01"}}}
    b = {"snapshot": {"timestamp": "12:00:06", "haus": {"value": 1.0, "observed_at": "12:00:06"}}}
    assert kern(a) == kern(b)


def test_eine_schlechter_werdende_qualitaet_zaehlt_sehr_wohl() -> None:
    """Dass ein Messwert alt wird, ist die Aussage - und sie steht in der Qualitaet, nicht in der Zeit."""
    a = {"snapshot": {"haus": {"value": 1.0, "quality": "ok", "observed_at": "12:00:01"}}}
    b = {"snapshot": {"haus": {"value": 1.0, "quality": "stale", "observed_at": "12:00:01"}}}
    assert kern(a) != kern(b)


def test_auch_in_listen_wird_gefiltert() -> None:
    a = {"system": {"watch": [{"code": "x", "observed_at": "12:00:01"}]}}
    b = {"system": {"watch": [{"code": "x", "observed_at": "12:00:09"}]}}
    assert kern(a) == kern(b)


def test_ein_messwert_zaehlt_sehr_wohl() -> None:
    assert kern(zustand(wert=1.0)) != kern(zustand(wert=1.1))


def test_der_kern_haengt_nicht_an_der_reihenfolge_der_felder() -> None:
    a = {"b": 1, "a": 2}
    b = {"a": 2, "b": 1}
    assert kern(a) == kern(b)


# ------------------------------------------------------------------ Takt


def test_der_erste_zustand_geht_immer_hinaus() -> None:
    t = Takt(mindestabstand_s=5.0, hoechstabstand_s=60.0)
    assert t.naechster(100.0, lambda: zustand()) is not None


def test_innerhalb_des_mindestabstands_wird_nicht_gesendet() -> None:
    t = Takt(5.0, 60.0)
    t.naechster(100.0, lambda: zustand())
    # Anderer Wert, aber zu frueh: der Takt haelt ihn zurueck.
    assert t.naechster(103.0, lambda: zustand(wert=9.9)) is None
    assert t.naechster(105.0, lambda: zustand(wert=9.9)) is not None


def test_innerhalb_des_mindestabstands_wird_der_zustand_gar_nicht_erst_gebaut() -> None:
    """Ihn zusammenzusetzen und zu verwerfen waere bei jeder Messung Arbeit fuer nichts."""
    t = Takt(5.0, 60.0)
    t.naechster(100.0, lambda: zustand())
    aufrufe = 0

    def bauen() -> dict[str, Any]:
        nonlocal aufrufe
        aufrufe += 1
        return zustand()

    assert t.naechster(102.0, bauen) is None
    assert aufrufe == 0


def test_ein_unveraenderter_zustand_wird_nicht_wiederholt() -> None:
    """Die eigentliche Ersparnis: nachts aendert sich stundenlang nichts."""
    t = Takt(5.0, 60.0)
    t.naechster(100.0, lambda: zustand())
    for i in range(1, 10):
        # Die Uhr laeuft weiter, die Messwerte nicht.
        uhr = f"12:00:{i:02d}"
        assert t.naechster(100.0 + 5.0 * i, lambda u=uhr: zustand(uhr=u)) is None  # type: ignore[misc]


def test_nach_dem_hoechstabstand_geht_er_trotzdem_hinaus() -> None:
    """Sonst bliebe ein Bildschirm, der eine Meldung verpasst hat, beliebig lange veraltet."""
    t = Takt(5.0, 60.0)
    t.naechster(100.0, lambda: zustand())
    assert t.naechster(155.0, lambda: zustand()) is None
    assert t.naechster(160.0, lambda: zustand()) is not None
    # Danach beginnt die Frist von vorn.
    assert t.naechster(165.0, lambda: zustand()) is None


def test_eine_aenderung_geht_sofort_nach_dem_mindestabstand_hinaus() -> None:
    t = Takt(5.0, 60.0)
    t.naechster(100.0, lambda: zustand(wert=1.0))
    assert t.naechster(105.0, lambda: zustand(wert=2.0)) is not None


def test_was_ein_mensch_ausgeloest_hat_wartet_nicht() -> None:
    """Wer eine Schaltflaeche drueckt, soll die Wirkung sehen und nicht den Takt abwarten."""
    t = Takt(5.0, 60.0)
    t.naechster(100.0, lambda: zustand())
    assert t.naechster(100.5, lambda: zustand(), erzwinge=True) is not None
    # Und die Frist beginnt danach von vorn.
    assert t.naechster(103.0, lambda: zustand(wert=5.0)) is None


def test_der_erzwungene_zustand_setzt_den_filter_mit() -> None:
    t = Takt(5.0, 60.0)
    t.naechster(100.0, lambda: zustand(wert=1.0))
    t.naechster(100.5, lambda: zustand(wert=2.0), erzwinge=True)
    # Derselbe Wert gilt jetzt als bekannt und wird nicht noch einmal gesendet.
    assert t.naechster(110.0, lambda: zustand(wert=2.0)) is None
