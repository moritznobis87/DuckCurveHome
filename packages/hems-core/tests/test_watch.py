"""Der Wächter: was gemeldet wird, was nicht, und wie es heißt."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from hems_core.watch import BRIDGE, WatchRule, findings, silence_text

JETZT = datetime(2026, 10, 26, 12, 0, tzinfo=UTC)

REGELN = (
    WatchRule(
        name=BRIDGE,
        keys=(BRIDGE,),
        title_de="Die Brücke",
        silence_min=20,
        severity="alarm",
        impact_de="Ohne sie kommt nichts aus dem Haus.",
        expected=True,
    ),
    WatchRule(
        name="buffer",
        keys=("buffer_temp_top_c", "buffer_temp_bottom_c"),
        title_de="Die Puffertemperaturen",
        silence_min=30,
        severity="alarm",
        impact_de="Ohne sie gibt es keinen Ladezustand.",
        plural=True,
        member_de="Fühlern",
    ),
    WatchRule(
        name="price",
        keys=("electricity_price_ct_kwh",),
        title_de="Der Strompreis",
        silence_min=180,
        severity="warn",
        impact_de="Der Fahrplan läuft ohne Preisblick.",
    ),
)


def vor(minuten: float) -> datetime:
    return JETZT - timedelta(minutes=minuten)


def test_frisches_signal_ist_kein_befund() -> None:
    zuletzt = {BRIDGE: vor(1), "buffer_temp_top_c": vor(2), "electricity_price_ct_kwh": vor(20)}
    assert findings(zuletzt, JETZT, JETZT, REGELN) == []


def test_stilles_signal_wird_gemeldet() -> None:
    zuletzt = {BRIDGE: vor(1), "buffer_temp_top_c": vor(2900), "buffer_temp_bottom_c": vor(2900)}
    (befund,) = findings(zuletzt, JETZT, JETZT, REGELN)
    assert befund.name == "buffer"
    assert befund.since == vor(2900)
    assert "seit 2 Tagen still" in befund.text_de
    # Der Satz sagt auch, was deshalb fehlt. Eine Meldung ohne Folge ist nur ein Schreck.
    assert "Ladezustand" in befund.text_de


def test_ein_einzelner_stiller_fuehler_wird_gemeldet() -> None:
    """Der Fall, den die Gruppe bis zum 22.11.2026 zugedeckt hat.

    Ein Fühler seit zwei Tagen still, der andere im Sekundentakt: vorher kam `[]` heraus, weil die
    *jüngste* Meldung der Gruppe zählte. Ohne den einen Fühler rechnet der Dienst aber keinen
    Ladezustand mehr - die Wandanzeige zeigt dann drei satte Zahlen und einen Strich, und niemand
    erfährt, warum. Fällig ist die Regel nach dem Fühler, der am längsten schweigt.
    """
    zuletzt = {BRIDGE: vor(1), "buffer_temp_top_c": vor(2900), "buffer_temp_bottom_c": vor(3)}
    (befund,) = findings(zuletzt, JETZT, JETZT, REGELN)
    assert befund.name == "buffer"
    # Die Zahl steht im Satz: „seit 2 Tagen still" allein wäre für die Gruppe falsch.
    assert befund.text_de == (
        "Die Puffertemperaturen sind unvollständig: 1 von 2 Fühlern schweigt seit 2 Tagen. "
        "Ohne sie gibt es keinen Ladezustand."
    )
    # Und die Zeit ist die des stillen Fühlers, nicht die des gesunden.
    assert befund.since == vor(2900)
    assert befund.silent_min == 2900


def test_ein_fuehler_der_nie_geliefert_hat_zaehlt_nicht_mit() -> None:
    # „Was nie da war, fehlt nicht" gilt auch für die Zahl im Satz: Ein nicht angeschlossener
    # Fühler soll nicht aus einem Ausfall einen halben machen.
    zuletzt = {BRIDGE: vor(1), "buffer_temp_top_c": vor(2900)}
    (befund,) = findings(zuletzt, JETZT, JETZT, REGELN)
    assert (
        befund.text_de
        == "Die Puffertemperaturen seit 2 Tagen still. Ohne sie gibt es keinen Ladezustand."
    )


def test_was_nie_da_war_fehlt_nicht() -> None:
    # Kein Strompreis eingerichtet: keine Meldung, egal wie lange der Dienst läuft.
    zuletzt = {BRIDGE: vor(1)}
    assert [f.name for f in findings(zuletzt, JETZT, vor(10_000), REGELN)] == []


def test_die_bruecke_wird_auch_nach_einem_neustart_erwartet() -> None:
    # Nichts in der Datenbank, nichts im Speicher, Brücke nie verbunden: Genau dieser Fall darf
    # nicht der eine sein, den niemand meldet. Die Stille beginnt beim Start des Dienstes.
    (befund,) = findings({}, JETZT, vor(45), REGELN)
    assert befund.name == BRIDGE
    assert befund.since is None
    assert befund.silent_min == 45


def test_kurz_nach_dem_start_ist_noch_nichts_faellig() -> None:
    assert findings({}, JETZT, vor(5), REGELN) == []


def test_schwere_zuerst_dann_alter() -> None:
    zuletzt = {
        BRIDGE: vor(100),
        "buffer_temp_top_c": vor(200),
        "buffer_temp_bottom_c": vor(200),
        "electricity_price_ct_kwh": vor(600),
    }
    namen = [f.name for f in findings(zuletzt, JETZT, JETZT, REGELN)]
    assert namen == ["buffer", BRIDGE, "price"]


def test_dauer_in_der_einheit_die_man_nachvollzieht() -> None:
    assert silence_text(41) == "seit 41 Minuten"
    assert silence_text(200) == "seit 3 Stunden"
    assert silence_text(3 * 24 * 60) == "seit 3 Tagen"
