"""Der Berichtsspeicher: zwei Fristen, eine Schranke - und was er nicht darf.

Geprüft wird hier **die Eigenschaft und nicht die Geschwindigkeit**. Ein Test, der eine Antwort
unter einer Zeitmarke verlangt, misst auf einem anderen Rechner etwas anderes und schlägt
irgendwann ohne Fehler an. Gemessen wurde darum von Hand, und die Zahlen stehen im Modulkopf von
`dch_api.application.berichtsspeicher`; hier wird gezählt, wie oft gerechnet wurde, und verglichen,
welchen Stand die Antwort trägt.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from pydantic import BaseModel

from dch_api.application.berichtsspeicher import FRIST, GROESSE, NACHLAUF, Berichtsspeicher
from dch_api.application.energy_accounting import EnergyAccounting
from dch_api.schemas import EnergySummaryOut, HeatBalanceOut
from hems_core.accounting import HourlyEnergy
from hems_core.domain import HemsConfig
from hems_core.simulation import BERLIN

JETZT = datetime(2026, 10, 12, 14, 30, tzinfo=UTC)
#: Ein Tag, der lange vorbei ist, und sein Ende.
GESTERN = date(2026, 10, 11)
GESTERN_ENDE = datetime(2026, 10, 10, 22, 0, tzinfo=UTC) + timedelta(days=1)
#: Der laufende Tag, und sein Ende liegt in der Zukunft.
HEUTE = date(2026, 10, 12)
HEUTE_ENDE = datetime(2026, 10, 11, 22, 0, tzinfo=UTC) + timedelta(days=1)


class Zahl(BaseModel):
    """Ein Platzhalter für eine Auswertung: er kennt seinen Stand, und das genügt."""

    generated_at: datetime
    wert: int


@dataclass
class Zaehler:
    """Rechnet und zählt mit - der einzige Weg, einen Treffer von einer Rechnung zu unterscheiden."""

    now: datetime
    laeufe: int = 0
    werte: list[int] = field(default_factory=list)

    async def rechnen(self) -> Zahl:
        self.laeufe += 1
        return Zahl(generated_at=self.now, wert=self.laeufe)


# ---------------------------------------------------------------- Die beiden Fristen


async def test_ein_abgeschlossener_zeitraum_wird_einmal_gerechnet_und_bleibt_liegen() -> None:
    """Gestern ändert sich nicht mehr. Also auch nicht seine Bilanz - und auch nicht nach Stunden."""
    s = Berichtsspeicher()
    z = Zaehler(now=JETZT)
    erst = await s.hole(
        "energy/waermebilanz", "day", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen
    )
    for versatz in (timedelta(minutes=2), timedelta(hours=3), timedelta(days=9)):
        spaeter = await s.hole(
            "energy/waermebilanz",
            "day",
            GESTERN,
            now=JETZT + versatz,
            ende=GESTERN_ENDE,
            rechnen=z.rechnen,
        )
        assert spaeter is erst
    assert z.laeufe == 1


async def test_der_laufende_zeitraum_wird_nach_der_frist_neu_gerechnet() -> None:
    """Und vorher nicht: dazwischen liegen die fünf Abfragen eines Ankerwechsels."""
    s = Berichtsspeicher()
    z = Zaehler(now=JETZT)
    await s.hole("energy/waermebilanz", "day", HEUTE, now=JETZT, ende=HEUTE_ENDE, rechnen=z.rechnen)
    kurz = await s.hole(
        "energy/waermebilanz",
        "day",
        HEUTE,
        now=JETZT + FRIST - timedelta(seconds=1),
        ende=HEUTE_ENDE,
        rechnen=z.rechnen,
    )
    assert kurz.wert == 1, "innerhalb der Frist wird nicht gerechnet"
    z.now = JETZT + FRIST
    spaet = await s.hole(
        "energy/waermebilanz", "day", HEUTE, now=JETZT + FRIST, ende=HEUTE_ENDE, rechnen=z.rechnen
    )
    assert spaet.wert == 2 and z.laeufe == 2


def test_die_frist_ist_kuerzer_als_der_takt_der_seiten() -> None:
    """Die Begründung der Zahl, als Prüfung: jedes Nachladen rechnet neu.

    Fünf Minuten sind der Takt, in dem die Berichtsseiten nachholen (`useReport.ts: REFRESH_MS`,
    in der App `Berichtstakt.nachladen`). Wäre die Frist so lang wie dieser Takt oder länger,
    bekäme ein Nachladen die Antwort des vorigen - und auf einer Wandanzeige stünden Zahlen, die
    niemand bestellt hat und die bis zu zehn Minuten alt sind.
    """
    assert FRIST.total_seconds() < 5 * 60


async def test_ein_ergebnis_aus_dem_laufenden_zeitraum_wird_nicht_nachtraeglich_dauerhaft() -> None:
    """Sonst friert die halbe Bilanz eines Tages für immer ein.

    Gefragt wird um 14:30 nach dem laufenden Tag. Zehn Stunden später ist derselbe Tag vorbei -
    das Ergebnis von damals beschreibt ihn aber nur bis 14:30. Es darf nicht dadurch dauerhaft
    werden, dass die Zeit weitergelaufen ist.
    """
    s = Berichtsspeicher()
    z = Zaehler(now=JETZT)
    await s.hole("energy/waermebilanz", "day", HEUTE, now=JETZT, ende=HEUTE_ENDE, rechnen=z.rechnen)
    z.now = HEUTE_ENDE + timedelta(hours=2)
    neu = await s.hole(
        "energy/waermebilanz", "day", HEUTE, now=z.now, ende=HEUTE_ENDE, rechnen=z.rechnen
    )
    assert neu.wert == 2, "das halbe Ergebnis wurde nicht weitergereicht"


async def test_der_nachlauf_haelt_einen_gerade_beendeten_zeitraum_fuer_laufend() -> None:
    """Die Verdichtung läuft alle fünf Minuten; um 00:01 fehlt die letzte Stunde noch."""
    s = Berichtsspeicher()
    z = Zaehler(now=HEUTE_ENDE + timedelta(minutes=1))
    await s.hole("energy/waermebilanz", "day", HEUTE, now=z.now, ende=HEUTE_ENDE, rechnen=z.rechnen)
    z.now = HEUTE_ENDE + timedelta(minutes=1) + FRIST
    assert (
        await s.hole(
            "energy/waermebilanz", "day", HEUTE, now=z.now, ende=HEUTE_ENDE, rechnen=z.rechnen
        )
    ).wert == 2, "kurz nach Mitternacht gilt noch die kurze Frist"

    # Nach dem Nachlauf dagegen: einmal gerechnet, dann liegengeblieben.
    z.now = HEUTE_ENDE + NACHLAUF
    fest = await s.hole(
        "energy/waermebilanz", "day", HEUTE, now=z.now, ende=HEUTE_ENDE, rechnen=z.rechnen
    )
    z.now = HEUTE_ENDE + NACHLAUF + timedelta(days=1)
    assert (
        await s.hole(
            "energy/waermebilanz", "day", HEUTE, now=z.now, ende=HEUTE_ENDE, rechnen=z.rechnen
        )
    ) is fest


async def test_ohne_dauerhaft_gilt_auch_fuer_gestern_nur_die_kurze_frist() -> None:
    """`/energy/heat` trägt die 48-Stunden-Prognose mit sich - die darf nicht einfrieren."""
    s = Berichtsspeicher()
    z = Zaehler(now=JETZT)
    await s.hole(
        "energy/heat",
        "day",
        GESTERN,
        now=JETZT,
        ende=GESTERN_ENDE,
        rechnen=z.rechnen,
        dauerhaft=False,
    )
    z.now = JETZT + FRIST
    zweit = await s.hole(
        "energy/heat",
        "day",
        GESTERN,
        now=z.now,
        ende=GESTERN_ENDE,
        rechnen=z.rechnen,
        dauerhaft=False,
    )
    assert zweit.wert == 2 and z.laeufe == 2


# ---------------------------------------------------------------- Der Schlüssel


async def test_endpunkt_zeitraum_und_anker_werden_nicht_verwechselt() -> None:
    """Drei Teile, und jeder von ihnen trennt. Sonst stünde die Woche unter dem Kopf des Tages."""
    s = Berichtsspeicher()
    z = Zaehler(now=JETZT)
    schluessel = [
        ("energy/waermebilanz", "day", GESTERN),
        ("energy/waermebilanz", "week", GESTERN),
        ("energy/summary", "day", GESTERN),
        ("energy/waermebilanz", "day", GESTERN - timedelta(days=1)),
    ]
    werte = [
        (await s.hole(e, p, a, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen)).wert
        for e, p, a in schluessel
    ]
    assert werte == [1, 2, 3, 4], "jeder Schlüssel hat sein eigenes Ergebnis"
    assert z.laeufe == 4


# ---------------------------------------------------------------- Die gleichzeitige zweite Abfrage


async def test_zwei_gleichzeitige_abfragen_rechnen_einmal() -> None:
    """Der Fall, der ohne Zusammenlegung durch jeden Zwischenspeicher fällt.

    Eine Berichtsseite holt die gewählte Spanne zweimal - als ihren Bericht und als eine Spalte
    des Spannenstreifens -, und zwar gleichzeitig. Beide fänden den Speicher leer vor.
    """
    s = Berichtsspeicher()
    z = Zaehler(now=JETZT)
    begonnen = asyncio.Event()
    weiter = asyncio.Event()

    async def langsam() -> Zahl:
        begonnen.set()
        await weiter.wait()
        return await z.rechnen()

    erste = asyncio.create_task(
        s.hole(
            "energy/waermebilanz", "month", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=langsam
        )
    )
    await begonnen.wait()
    zweite = asyncio.create_task(
        s.hole(
            "energy/waermebilanz", "month", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=langsam
        )
    )
    await asyncio.sleep(0)
    weiter.set()
    a, b = await erste, await zweite
    assert a is b and z.laeufe == 1


async def test_ein_fehler_erreicht_beide_wartenden_und_wird_nicht_abgelegt() -> None:
    s = Berichtsspeicher()
    begonnen = asyncio.Event()
    weiter = asyncio.Event()
    laeufe = 0

    async def scheitern() -> Zahl:
        nonlocal laeufe
        laeufe += 1
        begonnen.set()
        await weiter.wait()
        raise RuntimeError("Datenbank weg")

    erste = asyncio.create_task(
        s.hole("energy/summary", "month", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=scheitern)
    )
    await begonnen.wait()
    zweite = asyncio.create_task(
        s.hole("energy/summary", "month", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=scheitern)
    )
    await asyncio.sleep(0)
    weiter.set()
    for aufgabe in (erste, zweite):
        with pytest.raises(RuntimeError):
            await aufgabe
    assert laeufe == 1
    # Und der nächste Versuch rechnet wieder, statt den Fehler zu wiederholen.
    z = Zaehler(now=JETZT)
    assert (
        await s.hole(
            "energy/summary", "month", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen
        )
    ).wert == 1


# ---------------------------------------------------------------- Was er nicht darf


async def test_der_speicher_waechst_nicht_ueber_die_schranke() -> None:
    """Und was herausfällt, ist das am längsten nicht Gelesene, nicht das Älteste."""
    s = Berichtsspeicher(groesse=4)
    z = Zaehler(now=JETZT)

    async def hole(anker: date) -> int:
        w = await s.hole(
            "energy/summary", "day", anker, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen
        )
        return w.wert

    anker = [GESTERN - timedelta(days=i) for i in range(4)]
    erst = [await hole(a) for a in anker]
    assert erst == [1, 2, 3, 4]
    # Den ältesten noch einmal lesen: er wandert an das junge Ende.
    assert await hole(anker[0]) == 1
    # Ein fünfter drängt herein - und der jetzt am längsten nicht gelesene ist der zweite.
    assert await hole(GESTERN - timedelta(days=9)) == 5
    assert len(s._eintraege) == 4
    assert await hole(anker[0]) == 1, "der eben gelesene liegt noch da"
    assert await hole(anker[1]) == 6, "der nicht gelesene ist herausgefallen"


async def test_ein_neuer_speicher_belebt_nichts_wieder() -> None:
    """Ein Wörterbuch im Prozess und sonst nichts.

    **Warum das geprüft wird, obwohl es offensichtlich ist.** Ein Zwischenspeicher für Messdaten,
    der einen Neustart überlebt, ist gefährlich: zwischen Absturz und Start kann der Bestand
    nachgetragen worden sein, und dann wäre jede überlebende Zahl eine falsche. Die Prüfung hält
    fest, dass hier nichts dazugebaut wurde - kein Pfad, keine Tabelle, kein Redis.
    """
    z = Zaehler(now=JETZT)
    alt = Berichtsspeicher()
    await alt.hole(
        "energy/summary", "year", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen
    )
    neu = Berichtsspeicher()
    assert (
        await neu.hole(
            "energy/summary", "year", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen
        )
    ).wert == 2, "ein frischer Speicher fängt leer an"
    quelle = __import__("inspect").getsource(Berichtsspeicher)
    for verdacht in ("open(", "Path", "json", "pickle", "redis", "sqlite", "execute"):
        assert verdacht not in quelle, f"nichts Dauerhaftes im Speicher: {verdacht}"


async def test_leeren_wirft_alles_weg_und_auch_was_noch_lief() -> None:
    """Nach einem Backfill oder einem geänderten Pelletpreis darf nichts Altes übrig sein."""
    s = Berichtsspeicher()
    z = Zaehler(now=JETZT)
    await s.hole("energy/summary", "day", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen)
    s.leeren()
    assert (
        await s.hole(
            "energy/summary", "day", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen
        )
    ).wert == 2

    # Eine Rechnung, die über das Leeren hinweg lief, wird ausgeliefert - aber nicht abgelegt.
    begonnen = asyncio.Event()
    weiter = asyncio.Event()

    async def langsam() -> Zahl:
        begonnen.set()
        await weiter.wait()
        return await z.rechnen()

    laufend = asyncio.create_task(
        s.hole("energy/pv", "year", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=langsam)
    )
    await begonnen.wait()
    s.leeren()
    weiter.set()
    assert (await laufend).wert == 3, "der Fragende bekommt seine Antwort"
    assert (
        await s.hole("energy/pv", "year", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen)
    ).wert == 4, "abgelegt wurde sie nicht"


async def test_wer_nach_dem_leeren_fragt_bekommt_keine_rechnung_von_vorher() -> None:
    """Die Falle unter der Falle: eine Rechnung, die das Leeren überdauert, darf niemanden einsammeln.

    Ohne das Miträumen von `_laufend` hängte sich der zweite Fragende an die laufende Rechnung,
    merkte sich den **neuen** Zählerstand und legte deren alten Wert ab - der Zähler allein hätte
    das nicht verhindert.
    """
    s = Berichtsspeicher()
    z = Zaehler(now=JETZT)
    begonnen = asyncio.Event()
    weiter = asyncio.Event()

    async def langsam() -> Zahl:
        begonnen.set()
        await weiter.wait()
        return await z.rechnen()

    alt = asyncio.create_task(
        s.hole("energy/shift", "month", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=langsam)
    )
    await begonnen.wait()
    s.leeren()
    neu = asyncio.create_task(
        s.hole("energy/shift", "month", GESTERN, now=JETZT, ende=GESTERN_ENDE, rechnen=z.rechnen)
    )
    weiter.set()
    assert (await alt).wert != (await neu).wert, "zwei Fragen, zwei Antworten"
    assert z.laeufe == 2


def test_der_schluessel_hat_keinen_platz_fuer_eine_person_und_braucht_keinen() -> None:
    """Weil es hier keine personenabhängigen Antworten gibt - und das ist nachgesehen, nicht
    angenommen.

    **Diese Prüfung hat beim Benutzersystem angeschlagen und ist umgeschrieben worden**
    (23.11.2026). Sie sah die Rollentrennung im BFF nach (`GUEST_FORBIDDEN` in
    `apps/web/src/app/api/dch/[...path]/route.ts`). Seit ADR-0002 steht sie im Dienst, in
    `dch_api/auth/rechte.py` - der Proxy entscheidet nichts mehr, er hängt nur noch den
    Nachweis an.

    **Die Begründung trägt unverändert, und darauf kommt es an:** getrennt wird weiterhin auf
    **Pfaden**, nicht auf Inhalten. `darf(rolle, methode, pfad)` bekommt keine Person zu sehen
    und kann deshalb keine personenabhängige Antwort erzeugen; wer einen Pfad nicht sehen darf,
    bekommt 403, **bevor** der Endpunkt rechnet. Für denselben Pfad gibt es also nach wie vor
    genau eine Antwort, und der Speicher kann keine verwechseln.

    **Fallen muss sie erst, wenn ein Endpunkt je Person verschieden antwortet** - wenn also ein
    Bewohner an derselben Adresse andere Zahlen sähe als der Hausherr. Dann gehört die Person in
    den Schlüssel. Deshalb steht das hier und nicht nur im Text.
    """
    import inspect
    from pathlib import Path

    from dch_api.application import berichtsspeicher
    from dch_api.auth import rechte

    assert len(berichtsspeicher.Schluessel.__args__) == 3
    # Die Trennung kennt Rolle, Methode und Pfad - und sonst nichts. Käme hier eine Person oder
    # ein Ausweis dazu, könnte die Antwort von ihr abhängen.
    assert list(inspect.signature(rechte.darf).parameters) == ["rolle", "methode", "pfad"]
    assert all(p.startswith("/") for p in rechte.AKTEN), "verglichen wird mit Pfaden"
    # Der Proxy reicht nur noch durch: die Rolle eines gepaarten Geräts reist als Kopfzeile mit,
    # als Inhaltsfilter wirkt sie nicht.
    bff = Path(__file__).resolve().parents[3] / "apps/web/src/app/api/dch/[...path]/route.ts"
    text = bff.read_text(encoding="utf-8")
    assert "x-dch-urheber-rolle" in text, "die Rolle reist als Kopf mit, nicht als Inhaltsfilter"
    assert "GUEST_FORBIDDEN" not in text, "die Rechte liegen im Dienst, nicht im Proxy"


# ---------------------------------------------------------------- An der Auswertung


def _acc(hems: HemsConfig | None = None) -> EnergyAccounting:
    async def minute_rows(s: datetime, e: datetime) -> list[dict[str, float | str | None]]:
        return []

    async def read(s: datetime, e: datetime) -> list[tuple[HourlyEnergy, float | None]]:
        return []

    async def write(hours: list[HourlyEnergy], temps: dict[datetime, float | None]) -> None:
        return None

    async def last() -> datetime | None:
        return None

    return EnergyAccounting(hems or HemsConfig(), BERLIN, minute_rows, store=(read, write, last))


async def test_geaenderte_annahmen_verwerfen_die_abgelegten_auswertungen() -> None:
    """Ein neuer Pelletpreis wirkt auf jeden Zeitraum - auch auf abgeschlossene."""
    acc = _acc()
    erst = await acc.summary("day", GESTERN, JETZT)
    assert await acc.summary("day", GESTERN, JETZT) is erst
    acc.hems = HemsConfig()  # derselbe Weg, den `LiveRuntime._apply_hems` nimmt
    assert await acc.summary("day", GESTERN, JETZT) is not erst


async def test_nachgetragene_messwerte_verwerfen_die_abgelegten_auswertungen() -> None:
    """`recompute` schreibt vergangene Stunden neu. Ohne das Verwerfen bliebe die alte Zahl liegen."""
    acc = _acc()
    erst = await acc.summary("day", GESTERN, JETZT)
    await acc.recompute(GESTERN_ENDE - timedelta(days=1), GESTERN_ENDE)
    assert await acc.summary("day", GESTERN, JETZT) is not erst


async def test_die_auswertung_sagt_wann_sie_gerechnet_wurde() -> None:
    """Und bei einem Treffer ist das ein Zeitpunkt in der Vergangenheit."""
    acc = _acc()
    erst = await acc.summary("day", GESTERN, JETZT)
    assert erst.generated_at == JETZT
    spaeter = await acc.summary("day", GESTERN, JETZT + timedelta(hours=4))
    assert spaeter.generated_at == JETZT, "der Stand ist der der Rechnung, nicht der der Abfrage"


# ---------------------------------------------------------------- Über den Endpunkt


def test_das_feld_steht_in_der_antwort_und_im_schema(client: TestClient) -> None:
    """Die App zeigt es später; im Schema muss es jetzt stehen, damit sie es kann."""
    assert "generated_at" in EnergySummaryOut.model_fields
    assert "generated_at" in HeatBalanceOut.model_fields
    r = client.get("/api/v1/energy/waermebilanz?period=day")
    assert r.status_code == 200
    assert r.json()["generated_at"], "jede Antwort trägt ihren Stand"
    schema = client.get("/openapi.json").json()
    for name in (
        "HeatBalanceOut",
        "EnergySummaryOut",
        "HeatReportOut",
        "EvReportOut",
        "PvTaxReportOut",
        "ShiftReportOut",
    ):
        eigen = schema["components"]["schemas"][name]
        assert "generated_at" in eigen["properties"], name
        assert "generated_at" in eigen["required"], f"{name}: kein Vorgabewert, der lügen könnte"


def test_dieselbe_frage_zweimal_gibt_denselben_stand(client: TestClient) -> None:
    """Die doppelte Abfrage der gewählten Spanne - und der Dienst rechnet sie einmal."""
    erst = client.get("/api/v1/energy/waermebilanz?period=month").json()
    zweit = client.get("/api/v1/energy/waermebilanz?period=month").json()
    assert erst["generated_at"] == zweit["generated_at"]
    assert erst["totals"] == zweit["totals"]


def test_die_schranke_steht_auf_zwei_ankern() -> None:
    """Sechs Endpunkte mal vier Spannen sind 24 Plätze je Anker. Die Zahl ist kein Zufall."""
    assert GROESSE == 48
