"""Die Wiedergabe: ein vergangener Tag als Folge von Anlagenbildern.

Schritt 10 des Zwillingsentwurfs, „Zeitschieber am Schema". Die Seite „Anlage" zeigt den
Augenblick; hier wird derselbe Augenblick aus der Minutenreihe nachgebaut, einmal je Schritt, und
die Oberfläche fährt darüber hin und her.

**Ein Bildweg, nicht zwei.** Die Versuchung ist groß, aus den Minutenzeilen gleich `AnlageOut` zu
bauen: es sind ja nur Zuweisungen. Dann gäbe es zwei Stellen, die das Anlagenbild erzeugen, und sie
laufen auseinander - die eine kennt die Zapferkennung, die andere nicht, die eine rundet, die
andere nicht, und am Ende zeigt die Wiedergabe ein anderes Haus als die Live-Seite. Deshalb
rekonstruiert dieses Modul die **Eingänge** von `anlage.zusammensetzen` und ruft dann die
vorhandene Zusammensetzung auf. Wer das Bild ändert, ändert beide Ansichten.

**Was sich nicht rekonstruieren lässt, sagt das Bild selbst.** Zwei Lücken gibt es, und keine
wird gefüllt:

* **Der Heizkreis.** Die Ventilstellungen der Räume stehen nicht in der Minutentabelle. Im
  Rückblick ist `rooms_total` deshalb null, und der Heizkreis bleibt dunkel. Eine Schätzung („es
  war ja kalt, also war offen") wäre eine Erfindung an genau der Stelle, an der die Wiedergabe
  überzeugen soll.
* **Die Takthistorie der Wärmepumpe.** `running_since` kommt nicht aus einem Gedächtnis, sondern
  wird über die Bilder hinweg mitgezählt: sobald die Leistung die Schwelle übersteigt, beginnt der
  Lauf. Beim ersten Bild des Tages ist deshalb unbekannt, wie lange die Maschine schon lief, und
  `running_since` bleibt leer, statt den Tagesanfang zu behaupten.

**Warum ein Schritt und nicht jede Minute.** Ein Tag hat 1440 Minuten; als Bilder mit je sieben
Unterobjekten wären das mehrere Megabyte für eine Seite, die man durchschiebt. Fünf Minuten sind
288 Bilder und reichen für ein Auge: der Puffer braucht eine Viertelstunde, um sich um ein Grad zu
bewegen. Wer genauer hinsehen will, stellt die Schrittweite kleiner.

Reine Zusammensetzung, kein I/O. Die Zeilen holt die Laufzeit.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta, tzinfo

from dch_api.application.anlage import (
    BUFFER_KEYS,
    DHW_INLET,
    DHW_OUTLET,
    WP_VORLAUF,
    zusammensetzen,
)
from dch_api.schemas import AnlageOut, AnlageReplayOut, RoomsLiveOut, StoveLiveOut
from hems_core.domain import (
    BufferTemperatures,
    EnergySnapshot,
    HeatPumpState,
    HemsConfig,
    Measurement,
    Quality,
)
from hems_core.thermal.buffer_soc import compute_buffer_state

Zeile = dict[str, float | str | None]

#: Wie weit jedes Bild in die Minutenreihe zurücksieht. Dieselbe Spanne wie live: genug für die
#: Nettoleistung des Speichers (eine Viertelstunde plus Lücke) und für eine laufende Zapfung.
RUECKBLICK_MIN = 120
#: Ab dieser elektrischen Leistung gilt die Wärmepumpe als laufend. Dieselbe Schwelle wie die
#: Kennzahl „gelaufen" auf der Fahrplanseite; wer sie hier anders setzt, erzeugt zwei Wahrheiten.
LAEUFT_AB_KW = 0.05
#: Die Reihen, die ein Bild überhaupt braucht. Alles andere aus der Minutentabelle bleibt liegen.
REIHEN: tuple[str, ...] = (
    "pv_power_kw",
    "grid_power_kw",
    "battery_power_kw",
    "battery_soc",
    "house_power_kw",
    "base_load_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
    "electricity_price_ct_kwh",
    "outdoor_temp_c",
    *BUFFER_KEYS,
    "hp_release_contact",
    WP_VORLAUF,
    DHW_OUTLET,
    DHW_INLET,
    "stove_running",
    "stove_power_level",
    "stove_boiler_temp_c",
    "stove_return_temp_c",
    "stove_pump_pct",
)

QUELLE = "replay"


def _zeit(ts: object) -> datetime:
    return datetime.fromisoformat(str(ts).replace("Z", "+00:00"))


def _zahl(zeile: Zeile, key: str) -> float | None:
    wert = zeile.get(key)
    return float(wert) if isinstance(wert, int | float) else None


def _m(zeile: Zeile, key: str, ts: datetime) -> Measurement:
    """Eine Spalte als Messung. Fehlt der Wert, fehlt die Messung - kein stillschweigendes Null.

    `UNAVAILABLE` und nicht `STALE`: die Zeile gibt es, und in ihr steht nichts. Das ist etwas
    anderes als ein Wert, der zu alt geworden ist, und die Zusammensetzung unterscheidet beides
    über `usable` ohnehin nicht - wohl aber jeder, der später ins Protokoll sieht.
    """
    wert = _zahl(zeile, key)
    if wert is None:
        return Measurement.missing(Quality.UNAVAILABLE, ts, QUELLE)
    return Measurement.ok(wert, ts, QUELLE)


def schnappschuss(zeile: Zeile, ts: datetime) -> EnergySnapshot:
    """Die Stromseite und die Fühler einer Minute als Schnappschuss."""
    return EnergySnapshot(
        timestamp=ts,
        pv_power_kw=_m(zeile, "pv_power_kw", ts),
        grid_power_kw=_m(zeile, "grid_power_kw", ts),
        battery_power_kw=_m(zeile, "battery_power_kw", ts),
        battery_soc=_m(zeile, "battery_soc", ts),
        house_power_kw=_m(zeile, "house_power_kw", ts),
        base_load_kw=_m(zeile, "base_load_kw", ts),
        heat_pump_power_kw=_m(zeile, "heat_pump_power_kw", ts),
        ev_power_kw=_m(zeile, "ev_power_kw", ts),
        electricity_price_ct_kwh=_m(zeile, "electricity_price_ct_kwh", ts),
        outdoor_temp_c=_m(zeile, "outdoor_temp_c", ts),
        buffer_temps_c=BufferTemperatures(
            top=_m(zeile, BUFFER_KEYS[0], ts),
            mid_top=_m(zeile, BUFFER_KEYS[1], ts),
            mid_bottom=_m(zeile, BUFFER_KEYS[2], ts),
            bottom=_m(zeile, BUFFER_KEYS[3], ts),
        ),
        hp_release_contact=_m(zeile, "hp_release_contact", ts),
        # K2 steht nicht in der Minutentabelle. Es als „aus" zu führen wäre eine Behauptung über
        # eine Netzbetreibersperre, die niemand aufgeschrieben hat.
        hp_block_contact=Measurement.missing(Quality.UNAVAILABLE, ts, QUELLE),
    )


def ofen_zustand(zeile: Zeile, cfg: HemsConfig) -> StoveLiveOut:
    """Der Ofen aus seinen Spalten. Ohne Ofen in der Konfiguration bleibt er abwesend.

    `running` kommt aus der Spalte und nicht aus der Leistungsstufe: ein Ofen in der Ausbrandphase
    meldet weiter „läuft", und genau das soll das Bild zeigen.
    """
    if not cfg.stove.present:
        return StoveLiveOut()
    laeuft = _zahl(zeile, "stove_running")
    return StoveLiveOut(
        present=True,
        control_enabled=cfg.stove.control_enabled,
        running=None if laeuft is None else laeuft > 0.5,
        power_level=_zahl(zeile, "stove_power_level"),
        boiler_temp_c=_zahl(zeile, "stove_boiler_temp_c"),
        observed_at=_zeit(zeile["ts"]) if zeile.get("ts") else None,
        quality=Quality.OK if laeuft is not None else Quality.UNAVAILABLE,
    )


@dataclass
class Takt:
    """Der Takt der Wärmepumpe über die Bilder hinweg.

    Ein Zustandsobjekt und keine reine Funktion, weil `running_since` von der Vorgeschichte
    abhängt und die Bilder in Reihenfolge entstehen. Vor dem ersten Wechsel bleibt es leer: wie
    lange die Maschine vor dem ersten Bild schon lief, steht in diesen Zeilen nicht.
    """

    #: `None` heißt „vor dem ersten Bild", und das ist nicht dasselbe wie „stand".
    #:
    #: Mit `False` als Anfangswert sah das erste Bild einer schon laufenden Maschine wie ein Anlauf
    #: aus: `running_since` stand auf der Tagesmitternacht, und das Schema behauptete eine Laufzeit,
    #: die niemand gemessen hat. Gefunden von `test_eine_laufende_pumpe_im_ersten_bild_erfindet_
    #: keinen_anfang`, nachdem der Modulkopf genau das Gegenteil versprochen hatte.
    laeuft: bool | None = None
    seit: datetime | None = None
    gestoppt: datetime | None = None
    starts: int = 0

    def schritt(self, leistung: float | None, ts: datetime) -> HeatPumpState:
        laeuft = (leistung or 0.0) > LAEUFT_AB_KW
        if self.laeuft is None:
            # Das erste Bild ist kein Wechsel. Weder ein Anlauf noch ein Stillstand beginnt hier,
            # also bleiben Anfang und Ende leer, bis wirklich einer zu sehen ist.
            pass
        elif laeuft and not self.laeuft:
            self.seit, self.gestoppt, self.starts = ts, None, self.starts + 1
        elif not laeuft and self.laeuft:
            self.seit, self.gestoppt = None, ts
        self.laeuft = laeuft
        return HeatPumpState(
            running=laeuft,
            running_since=self.seit,
            stopped_since=self.gestoppt,
            power_kw=leistung or 0.0,
            # Der Freigabekontakt steht je Zeile und nicht im Takt; er wird beim Bauen gesetzt.
            release_contact_on=False,
            block_contact_on=False,
            starts_today=self.starts,
            power_known=leistung is not None,
        )


def _naechste(zeilen: Sequence[Zeile], ts: datetime, *, toleranz_min: float) -> Zeile | None:
    """Die jüngste Zeile bei oder vor `ts`, sofern sie nicht zu alt ist.

    Vorwärts wird nicht gesucht. Ein Bild um 8:00 darf nicht aus einer Messung von 8:04 bestehen:
    die Wiedergabe soll zeigen, was zu diesem Zeitpunkt bekannt war, nicht was danach kam.
    """
    beste: Zeile | None = None
    grenze = ts - timedelta(minutes=toleranz_min)
    for z in zeilen:
        t = _zeit(z["ts"])
        if t > ts:
            break
        if t >= grenze:
            beste = z
    return beste


def bilder(
    zeilen: Sequence[Zeile],
    cfg: HemsConfig,
    *,
    von: datetime,
    bis: datetime,
    step_min: int,
) -> list[AnlageOut]:
    """Die Bilder eines Zeitraums, eines je Schritt, in der Reihenfolge der Zeit.

    `zeilen` sind die Minutenzeilen des Zeitraums **plus** `RUECKBLICK_MIN` davor; den Rückblick
    braucht jedes Bild für die Nettoleistung des Speichers und die Zapferkennung. Zeitpunkte ohne
    Messung in der Toleranz werden übersprungen und nicht erfunden - eine Lücke in der Wiedergabe
    ist eine Lücke in der Erfassung, und sie darf als solche zu sehen sein.
    """
    if step_min <= 0:
        raise ValueError("step_min muss positiv sein")
    takt = Takt()
    out: list[AnlageOut] = []
    schritt = timedelta(minutes=step_min)
    # Die Toleranz wächst mit der Schrittweite: bei 5 Minuten Schritt ist eine 4 Minuten alte
    # Messung noch dieses Bild, bei einer Minute Schritt wäre sie das Nachbarbild.
    toleranz = max(float(step_min), 2.0)
    ts = von
    while ts < bis:
        zeile = _naechste(zeilen, ts, toleranz_min=toleranz)
        if zeile is None:
            ts += schritt
            continue
        snap = schnappschuss(zeile, ts)
        hp = takt.schritt(_zahl(zeile, "heat_pump_power_kw"), ts)
        k1 = _zahl(zeile, "hp_release_contact")
        hp = hp.model_copy(update={"release_contact_on": bool(k1 and k1 > 0.5)})
        rueck = [
            z for z in zeilen if ts - timedelta(minutes=RUECKBLICK_MIN) <= _zeit(z["ts"]) <= ts
        ]
        out.append(
            zusammensetzen(
                now=ts,
                snap=snap,
                buffer=compute_buffer_state(snap.buffer_temps_c, cfg.buffer),
                hp=hp,
                cfg=cfg,
                stove=ofen_zustand(zeile, cfg),
                stove_return=_m(zeile, "stove_return_temp_c", ts),
                stove_pump=_m(zeile, "stove_pump_pct", ts),
                dhw_outlet=_m(zeile, DHW_OUTLET, ts),
                dhw_inlet=_m(zeile, DHW_INLET, ts),
                wp_vorlauf=_m(zeile, WP_VORLAUF, ts),
                # Die Ventilstellungen stehen nicht in der Minutentabelle, siehe Modulkopf.
                raeume=RoomsLiveOut(at=ts, named=False, rooms=[]),
                zeilen=list(rueck),
            )
        )
        ts += schritt
    return out


#: Erlaubte Schrittweiten. Keine freie Zahl: ein Schritt von 7 Minuten ergibt ein Band, dessen
#: Rasterlinien zu nichts passen, und ein Schritt von 1 Minute ergibt 1440 Bilder.
SCHRITTE: tuple[int, ...] = (1, 5, 15)


def fenster(day: date, tz: tzinfo) -> tuple[datetime, datetime]:
    """Der Ortstag als UTC-Fenster, von Mitternacht bis Mitternacht.

    Ortszeit und nicht UTC, weil ein Tag für den Bewohner um Mitternacht beginnt und nicht um ein
    oder zwei Uhr. An den Umstellungstagen ist das Fenster 23 oder 25 Stunden lang, und das ist
    richtig so: an jenem Sonntag hatte der Tag wirklich 25 Stunden.
    """
    von = datetime.combine(day, time(0), tzinfo=tz)
    bis = datetime.combine(day + timedelta(days=1), time(0), tzinfo=tz)
    return von.astimezone(UTC), bis.astimezone(UTC)


def hinweise(frames: Sequence[AnlageOut], erwartet: int, *, laeuft_noch: bool) -> list[str]:
    """Was an dieser Wiedergabe zu wissen ist, in Sätzen und nicht als Fehlercode.

    `laeuft_noch` heißt: der Tag ist der heutige und noch nicht vorbei. Dann ist `erwartet` schon
    auf jetzt beschnitten, und was dahinter fehlt, ist keine Lücke, sondern der Abend. Ohne diese
    Unterscheidung stand am Vorführtag „9 von 96 Bildern fehlen", während in Wahrheit nur noch
    nicht Abend war - eine Erfassungslücke behauptet, wo keine ist.
    """
    out: list[str] = []
    if not frames:
        out.append(
            "Für diesen Tag liegen keine Minutenwerte vor. Die Wiedergabe ist leer, und das heißt "
            "nicht, dass nichts geschah."
            if not laeuft_noch
            else "Von diesem Tag ist noch nichts erfasst. Er hat gerade erst begonnen."
        )
        return out
    if laeuft_noch:
        out.append(
            f"Der Tag läuft noch: bis jetzt sind {erwartet} Bilder möglich, und die Wiedergabe "
            "endet am letzten gemessenen Zeitpunkt."
        )
    if len(frames) < erwartet:
        fehlt = erwartet - len(frames)
        out.append(
            f"{fehlt} von {erwartet} Bildern fehlen: zu diesen Zeitpunkten lag keine Messung vor. "
            "Lücken werden nicht überbrückt, sondern übersprungen."
        )
    out.append(
        "Der Heizkreis bleibt im Rückblick dunkel: die Ventilstellungen der Räume stehen nicht in "
        "der Minutentabelle, und geschätzt wird hier nichts."
    )
    if frames[0].waermepumpe.running and frames[0].waermepumpe.running_since is None:
        out.append(
            "Die Wärmepumpe lief schon beim ersten Bild. Wie lange, steht in diesen Zeilen nicht, "
            "deshalb bleibt die Laufzeit zunächst leer."
        )
    return out


def zusammenstellen(
    zeilen: Sequence[Zeile],
    cfg: HemsConfig,
    day: date,
    tz: tzinfo,
    *,
    step_min: int,
    jetzt: datetime | None = None,
) -> AnlageReplayOut:
    """Die ganze Antwort: Fenster, Bilder, Hinweise. Beide Laufzeiten rufen nur das hier.

    `zeilen` muss `RUECKBLICK_MIN` Minuten vor `von` beginnen, sonst fehlt den ersten Bildern die
    Nettoleistung des Speichers - sie wäre dann nicht falsch, sondern leer, und das sähe aus wie
    ein stehender Speicher.
    """
    von, bis = fenster(day, tz)
    # Beim laufenden Tag endet beides an jetzt: die Bilder und das Erwartete. Sonst zaehlte der
    # noch nicht gewesene Abend als fehlende Messung - und zugleich entstuenden ein, zwei Bilder
    # *hinter* jetzt, weil ein Zeitpunkt eine bis zu schrittweite alte Messung annehmen darf. Dann
    # stand in der Kopfzeile "261 von 259 Bildern", gesehen am 09.11.2026.
    laeuft_noch = jetzt is not None and von <= jetzt < bis
    ende = min(bis, jetzt) if laeuft_noch and jetzt is not None else bis
    rahmen = bilder(zeilen, cfg, von=von, bis=ende, step_min=step_min)
    erwartet = max(int((ende - von).total_seconds() // (step_min * 60)), 0)
    return AnlageReplayOut(
        day=day,
        step_min=step_min,
        von=von,
        bis=bis,
        erwartet=erwartet,
        frames=rahmen,
        hinweise_de=hinweise(rahmen, erwartet, laeuft_noch=laeuft_noch),
    )
