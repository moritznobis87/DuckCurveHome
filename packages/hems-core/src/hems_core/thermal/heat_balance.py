"""Wärmebilanz ohne Wärmemengenzähler: wer wie viel geliefert hat, und wo es geblieben ist.

Das Haus hat zwei Wärmeerzeuger an einem Kombipuffer und keinen einzigen Wärmemengenzähler. Was
gemessen wird, ist Strom (Wärmepumpe), der Betriebszustand des Ofens und die Temperatur des Puffers
an vier Stellen. Daraus lässt sich die Wärmeseite rechnen, und dieses Modul tut genau das, als reine
Funktion über einer Minutenreihe.

**Die vier Größen und woher sie kommen.**

* *Wärmepumpe.* Elektrische Leistung mal Arbeitszahl. Die Kennlinie `cop_curve` gilt bei
  Puffer-Zieltemperatur; der wirkliche Hub weicht davon ab, und zwar erheblich. Umgerechnet wird
  über das Verhältnis der Carnot-Zahlen, siehe `cop_for`.
* *Pelletofen.* Zwischen Minimallast und Volllast linear über die Leistungsstufe, getrennt nach
  Wasser und Raum. Das Datenblatt nennt beide Endpunkte; die Gerade dazwischen ist die einfachste
  Kurve, die sie trifft.
* *Puffer.* Die Änderung seines Energieinhalts. Vier Schichttemperaturen mal Volumen mal
  Wärmekapazität des Wassers, abgeleitet über die Zeit: positiv heißt, der Speicher hat geladen.
* *Verlust.* Verlustbeiwert mal Übertemperatur gegen den Raum. Diese Wärme ist nicht verloren,
  sondern heizt den Aufstellraum; sie steht deshalb als eigene Größe und nicht im Abfluss.

**Was übrig bleibt, ist die Entnahme.** Heizkreis und Warmwasser werden nicht gemessen; sie sind der
Rest der Bilanz. Diese Umkehrung ist der eigentliche Zweck des Moduls, und sie hat einen Preis: jeder
Fehler in den drei anderen Größen landet in ihr. Deshalb wird der Fehlbetrag nicht versteckt. Geht
die Bilanz nicht auf, steht die Differenz als `residual_kw` da und nicht als negative Entnahme.

**Der Rest ist das Kalibrierwerkzeug.** Ein Modell, das nie danebenliegt, hätte man nicht geprüft.
Ein dauerhaft positiver Rest heißt: es kommt mehr Wärme an, als die Erzeuger erklären - zu kleiner
COP, zu kleine Ofenleistung. Ein dauerhaft negativer Rest heißt das Gegenteil. Wer die Parameter auf
der Einstellungsseite dreht, dreht an genau dieser Zahl, bis sie klein wird.

Reine Rechenlogik, kein I/O, keine Zeitzone, keine Datenbank.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime

from pydantic import BaseModel, ConfigDict

from hems_core.accounting.heat import cop_at
from hems_core.domain.config import BufferConfig, HeatDemandConfig, HeatPumpConfig, StoveConfig

KWH_PER_LITER_KELVIN = 4.186 / 3600.0  # Wasser: 4,186 kJ/(kg·K) → kWh/(l·K)
KELVIN = 273.15
# Größere Lücken werden nicht überbrückt. Über eine Viertelstunde hinweg aus zwei Temperaturen eine
# Leistung zu bilden, hieße zu behaupten, man wisse, was dazwischen war.
MAX_GAP_MIN = 15.0
# Unter diesem Hub ist die Carnot-Zahl keine Auskunft mehr, sondern eine Division durch fast null.
MIN_LIFT_K = 3.0
# Über dieses Fenster wird die Leistung des Speichers gebildet, statt Minute gegen Minute.
#
# **Warum nicht je Minute.** 1000 Liter sind 1,16 kWh je Kelvin; über eine Minute abgeleitet
# entspricht ein Kelvin fast 70 kW. Ein Fühler, der um 0,1 K zappelt, erzeugt damit 1,7 kW aus dem
# Nichts, und ein Sprung von 0,7 K - wie er entsteht, wenn eine Temperaturfront an einem Fühler
# vorbeiläuft - erzeugt 50 kW. Durch ein Rohr dieses Hauses passen keine 50 kW.
#
# Die zentrierte Differenz über zehn Minuten ist genau die mittlere Leistung dieser zehn Minuten und
# zugleich ein Tiefpass. Sie verschmiert kurze Zapfungen, und das ist der Preis; die Alternative war
# eine Kurve, in der die Zapfung unter dem Rauschen gar nicht zu finden war.
BUFFER_WINDOW_MIN = 10.0
# Was physikalisch in den Speicher hinein oder aus ihm heraus kann. Hinein begrenzen ihn die
# Erzeuger, und mehr als sie liefern kann niemand einspeisen; heraus kann nicht mehr, als die
# Kreise desselben Hauses tragen. Was darüber steht, ist kein Wärmestrom, sondern ein Fühlersprung,
# und es gehört deshalb in den Rest und nicht in die Entnahme.
BUFFER_LIMIT_MARGIN = 1.2


@dataclass(frozen=True)
class HeatSample:
    """Eine Minute Wärmeseite. Jedes Feld darf fehlen; was fehlt, wird nicht geraten."""

    at: datetime
    heat_pump_kw: float | None = None
    outdoor_c: float | None = None
    # Schichttemperaturen von oben nach unten, so viele wie `BufferConfig.layers` Einträge hat
    buffer_c: tuple[float, ...] | None = None
    room_c: float | None = None
    stove_running: bool | None = None
    stove_level: float | None = None


class HeatPoint(BaseModel):
    """Eine Minute Wärmebilanz. Alle Leistungen in kW, thermisch."""

    model_config = ConfigDict(frozen=True)

    at: datetime
    heat_pump_kw: float = 0.0
    cop: float | None = None
    stove_water_kw: float = 0.0
    stove_room_kw: float = 0.0
    buffer_kwh: float | None = None  # Inhalt über der Bezugstemperatur, kein Summand
    # True heißt: über die Entnahme dieser Minute lässt sich nichts sagen, weil die
    # Speicherleistung fehlt oder jenseits des physikalisch Möglichen liegt.
    unknown: bool = False
    buffer_change_kw: float = 0.0  # positiv: der Speicher lädt
    loss_kw: float = 0.0  # an den Aufstellraum
    draw_kw: float = 0.0  # Heizkreis und Warmwasser, als Rest der Bilanz
    residual_kw: float = 0.0  # was die Bilanz nicht erklärt
    loss_useful_kw: float = 0.0  # der Teil des Verlusts, der den Aufstellraum nützlich heizt


class HeatTotals(BaseModel):
    """Summen eines Zeitraums in kWh, thermisch, plus die Zahlen, die sie beurteilbar machen."""

    model_config = ConfigDict(frozen=True)

    minutes: int = 0
    heat_pump_kwh: float = 0.0
    stove_water_kwh: float = 0.0
    stove_room_kwh: float = 0.0
    produced_kwh: float = 0.0  # alles, was erzeugt wurde, Raumwärme des Ofens eingeschlossen
    draw_kwh: float = 0.0
    loss_kwh: float = 0.0
    loss_useful_kwh: float = 0.0  # davon dem Haus zugute, siehe BufferConfig.loss_useful_fraction
    buffer_change_kwh: float = 0.0
    residual_kwh: float = 0.0
    electric_kwh: float = 0.0  # Strom der Wärmepumpe, Grundlage der Arbeitszahl
    cop_mean: float | None = None  # Arbeitszahl des Zeitraums: Wärme durch Strom
    stove_minutes: int = 0
    unknown_minutes: int = 0  # ohne Aussage über die Entnahme
    note_de: str = ""


def mean_temperature_c(temps: Sequence[float], cfg: BufferConfig) -> float:
    """Volumengewichtete Mitteltemperatur des Puffers."""
    if not temps:
        return 0.0
    shares = cfg.layers if len(cfg.layers) == len(temps) else [1.0 / len(temps)] * len(temps)
    total = sum(shares)
    return sum(t * s for t, s in zip(temps, shares, strict=True)) / (total or 1.0)


def stored_energy_kwh(temps: Sequence[float], cfg: BufferConfig, reference_c: float = 0.0) -> float:
    """Energieinhalt des Puffers über einer Bezugstemperatur, **ungekappt**.

    Nicht `buffer_soc.usable_energy_kwh`, und der Unterschied ist der Grund für diese Funktion:
    jene Rechnung zählt nur, was oberhalb der nutzbaren Temperatur liegt, und deckelt bei der
    Kapazität. Für den Ladezustand ist das richtig. Für eine **Änderung** über die Zeit ist es
    falsch: sobald eine Schicht unter die Nutzgrenze fällt oder der Speicher voll anschlägt, steht
    die Ableitung still, und die Bilanz verliert genau die Wärme, die dort hineingeht.

    Die Bezugstemperatur kürzt sich in jeder Differenz heraus. Sie steht hier nur, damit der absolute
    Wert nicht als Aussage missverstanden wird.
    """
    shares = (
        list(cfg.layers)
        if len(temps) == len(cfg.layers)
        else [1.0 / len(temps)] * len(temps)
        if temps
        else []
    )
    return sum(
        cfg.volume_liters * share * KWH_PER_LITER_KELVIN * (t - reference_c)
        for t, share in zip(temps, shares, strict=True)
    )


def cop_for(
    outdoor_c: float,
    sink_c: float | None,
    heat: HeatDemandConfig,
    buffer: BufferConfig,
) -> float:
    """Arbeitszahl bei dieser Außentemperatur **und diesem Hub**.

    Die hinterlegte Kennlinie gilt bei Puffer-Zieltemperatur. Das genügt für eine Prognose, nicht
    für eine Bilanz: dieselbe Wärmepumpe liefert bei 40 °C Vorlauf deutlich mehr als bei 58 °C, und
    der Puffer durchläuft an einem Wintertag beides.

    Umgerechnet wird über das Verhältnis der Carnot-Zahlen zweier Hübe. Das ist keine Messung,
    sondern die Annahme, dass der Gütegrad der Maschine über den Hub ungefähr gleich bleibt - die
    übliche Näherung, und sie trifft die Richtung und die Größenordnung der Abweichung. Die absolute
    Höhe bleibt die Sache der Kennlinie, die aus dem Datenblatt oder aus einer Messung stammt.
    """
    base = cop_at(outdoor_c, heat)
    if sink_c is None:
        return base
    ref = buffer.target_temperature_c
    lift_now = max(MIN_LIFT_K, sink_c - outdoor_c)
    lift_ref = max(MIN_LIFT_K, ref - outdoor_c)
    carnot_now = (sink_c + KELVIN) / lift_now
    carnot_ref = (ref + KELVIN) / lift_ref
    if carnot_ref <= 0:
        return base
    return round(max(1.0, base * carnot_now / carnot_ref), 3)


def stove_output_kw(level: float | None, cfg: StoveConfig) -> tuple[float, float]:
    """(ins Wasser, in den Raum) bei dieser Leistungsstufe.

    Zwischen Stufe 1 und Stufe `power_levels` linear, wie beim Pelletdurchsatz in
    `accounting.stove_cost.fuel_rate_kg_per_h`; dieselbe Annahme, dieselbe Begründung. Ohne
    gemeldete Stufe gilt Volllast: der Ofen läuft praktisch immer dort, und die Alternative wäre,
    eine laufende Flamme mit null Wärme zu verbuchen.
    """
    span = max(cfg.power_levels - 1, 1)
    t = 1.0 if level is None else min(max((level - 1.0) / span, 0.0), 1.0)
    water = cfg.min_water_heat_kw + (cfg.water_heat_kw - cfg.min_water_heat_kw) * t
    total = cfg.min_heat_kw + (cfg.nominal_heat_kw - cfg.min_heat_kw) * t
    return round(water, 3), round(max(0.0, total - water), 3)


def buffer_power_kw(
    samples: Sequence[HeatSample], buffer: BufferConfig, window_min: float = BUFFER_WINDOW_MIN
) -> list[float | None]:
    """Die Leistung des Speichers je Probe, als zentrierte Differenz über ein Zeitfenster.

    `None` heißt: für diese Minute lässt sie sich nicht bilden, weil die Temperaturen fehlen oder
    eine Lücke dazwischenliegt. Das ist etwas anderes als null, und der Unterschied darf nicht
    verlorengehen: eine fehlende Speicheränderung als null zu buchen hieße zu behaupten, alles
    Erzeugte sei in diesem Augenblick entnommen worden.

    Gesucht wird je Probe die nächste Messung mindestens ein halbes Fenster davor und dahinter; die
    Differenz zwischen ihnen, geteilt durch ihren Abstand, ist die mittlere Leistung über diese
    Spanne. Am Rand der Reihe bleibt nur die einseitige Differenz.
    """
    zeiten = [s.at for s in samples]
    inhalte: list[float | None] = [
        stored_energy_kwh(list(s.buffer_c), buffer) if s.buffer_c else None for s in samples
    ]
    gemessen = [i for i, e in enumerate(inhalte) if e is not None]
    out: list[float | None] = [None] * len(samples)
    if len(gemessen) < 2:
        return out
    halb = window_min / 2.0
    for i in range(len(samples)):
        vor = _letzte_vor(gemessen, zeiten, i, halb)
        nach = _erste_nach(gemessen, zeiten, i, halb)
        if vor is None or nach is None or vor == nach:
            continue
        minuten = (zeiten[nach] - zeiten[vor]).total_seconds() / 60.0
        # Eine Lücke überbrückt die Rechnung nicht: zwei Temperaturen im Abstand einer Stunde sind
        # keine Leistung, sondern zwei Temperaturen.
        if minuten <= 0 or minuten > MAX_GAP_MIN + window_min:
            continue
        e_vor, e_nach = inhalte[vor], inhalte[nach]
        if e_vor is None or e_nach is None:
            continue
        out[i] = (e_nach - e_vor) / (minuten / 60.0)
    return out


def _letzte_vor(gemessen: list[int], zeiten: list[datetime], i: int, halb: float) -> int | None:
    """Die letzte Messung, die mindestens `halb` Minuten vor Probe `i` liegt - sonst die letzte davor."""
    kandidat: int | None = None
    for j in gemessen:
        if j > i:
            break
        abstand = (zeiten[i] - zeiten[j]).total_seconds() / 60.0
        if abstand >= halb or kandidat is None:
            kandidat = j
    return kandidat


def _erste_nach(gemessen: list[int], zeiten: list[datetime], i: int, halb: float) -> int | None:
    """Die erste Messung, die mindestens `halb` Minuten nach Probe `i` liegt - sonst die letzte."""
    letzte: int | None = None
    for j in gemessen:
        if j < i:
            continue
        letzte = j
        if (zeiten[j] - zeiten[i]).total_seconds() / 60.0 >= halb:
            return j
    return letzte


def heat_series(
    samples: Sequence[HeatSample],
    *,
    stove: StoveConfig,
    heat: HeatDemandConfig,
    buffer: BufferConfig,
    heat_pump: HeatPumpConfig | None = None,
) -> list[HeatPoint]:
    """Die Wärmebilanz Minute für Minute.

    Die Reihe muss zeitlich sortiert sein. Die Leistung des Speichers entsteht über ein Zeitfenster
    und nicht aus zwei benachbarten Minuten; warum, steht bei `BUFFER_WINDOW_MIN`.
    """
    out: list[HeatPoint] = []
    hp_cfg = heat_pump or HeatPumpConfig()
    grenze = (hp_cfg.nominal_thermal_power_kw + stove.nominal_heat_kw) * BUFFER_LIMIT_MARGIN
    leistungen = buffer_power_kw(samples, buffer)
    for s, change in zip(samples, leistungen, strict=True):
        temps = list(s.buffer_c) if s.buffer_c else []
        energy = stored_energy_kwh(temps, buffer) if temps else None
        change_kw = change if change is not None else 0.0

        sink = temps[0] if temps else None
        cop: float | None = None
        hp_kw = 0.0
        if s.heat_pump_kw is not None and s.heat_pump_kw > 0:
            cop = cop_for(s.outdoor_c if s.outdoor_c is not None else 7.0, sink, heat, buffer)
            hp_kw = s.heat_pump_kw * cop

        water_kw = room_kw = 0.0
        if s.stove_running:
            water_kw, room_kw = stove_output_kw(s.stove_level, stove)

        # Der Verlust rechnet gegen den **Aufstellraum des Puffers**, nicht gegen den Wohnraum.
        #
        # Hier stand der Raumfühler des Ofens, ersatzweise die Wunschtemperatur des Hauses. Beides
        # ist der falsche Raum: der Puffer steht im Technikraum, der Fühler hängt beim Ofen. Die
        # Messung war echt, nur maß sie etwas anderes - die unauffälligste Art, eine Bilanz falsch
        # zu machen, denn eine Zahl stand ja da. Jetzt steht dort eine Annahme, die man als solche
        # einstellen kann; der Ofenfühler bleibt als Messwert erhalten, er trägt nur nicht mehr
        # eine Rechnung, für die er nie gedacht war.
        #
        # Die Abschneidung bei null bleibt: unter der Raumtemperatur gewinnt der Puffer Wärme, aber
        # ein Gewinn ist kein Verlust, und bei 0,004 kW/K geht es um weniger als 15 W.
        loss_kw = 0.0
        if temps:
            uebertemperatur = mean_temperature_c(temps, buffer) - buffer.ambient_c
            loss_kw = max(0.0, buffer.loss_kw_per_k * uebertemperatur)

        # Die Bilanz: was hineingeht, geht in den Speicher, an den Raum oder in die Kreise.
        #
        # Ohne Speicherleistung wird nichts behauptet. Sie als null zu lesen hiesse, alles Erzeugte
        # sei in diesem Augenblick entnommen worden - der haeufigste Weg, aus fehlenden Daten eine
        # Zahl zu machen, die aussieht wie eine Messung.
        # Ein Betrag jenseits dessen, was Erzeuger und Kreise tragen, ist ein Fuehlersprung und kein
        # Waermestrom. Ihn zu beschneiden waere die schlechtere Antwort: dann staende dort eine
        # Entnahme in Hoehe der Grenze, also eine erfundene Zahl an der Stelle einer unbekannten.
        # Fuer diese Minute laesst sich ueber die Entnahme nichts sagen, und genau das steht da.
        unbekannt = change is None or abs(change_kw) > grenze
        if unbekannt:
            draw_kw = residual_kw = 0.0
        else:
            balance = hp_kw + water_kw - change_kw - loss_kw
            draw_kw = max(0.0, balance)
            residual_kw = min(0.0, balance)

        out.append(
            HeatPoint(
                at=s.at,
                heat_pump_kw=round(hp_kw, 3),
                cop=cop,
                stove_water_kw=water_kw,
                stove_room_kw=room_kw,
                buffer_kwh=round(energy, 3) if energy is not None else None,
                buffer_change_kw=round(change_kw, 3),
                loss_kw=round(loss_kw, 3),
                loss_useful_kw=round(loss_kw * buffer.loss_useful_fraction, 3),
                draw_kw=round(draw_kw, 3),
                residual_kw=round(residual_kw, 3),
                unknown=unbekannt,
            )
        )
    return out


def heat_totals(
    points: Sequence[HeatPoint], samples: Sequence[HeatSample], step_min: float = 1.0
) -> HeatTotals:
    """Summen über einen Zeitraum. `samples` nur für den Strom der Wärmepumpe."""
    if not points:
        return HeatTotals(note_de="Für diesen Zeitraum liegen keine Wärmedaten vor.")
    h = step_min / 60.0
    hp = sum(p.heat_pump_kw for p in points) * h
    water = sum(p.stove_water_kw for p in points) * h
    room = sum(p.stove_room_kw for p in points) * h
    draw = sum(p.draw_kw for p in points) * h
    loss = sum(p.loss_kw for p in points) * h
    loss_useful = sum(p.loss_useful_kw for p in points) * h
    residual = sum(p.residual_kw for p in points) * h
    electric = sum(s.heat_pump_kw or 0.0 for s in samples) * h
    # Der Speicher: nicht die Summe der Leistungen, sondern die Differenz der Bestände. Sie ist die
    # ehrlichere Zahl, weil sich Lücken in der Reihe nicht aufsummieren.
    inhalt = [p.buffer_kwh for p in points if p.buffer_kwh is not None]
    change = (inhalt[-1] - inhalt[0]) if len(inhalt) >= 2 else 0.0
    cop = round(hp / electric, 2) if electric > 0.05 else None
    stove_minutes = sum(1 for p in points if p.stove_water_kw > 0 or p.stove_room_kw > 0)
    ohne = sum(1 for p in points if p.unknown)
    return HeatTotals(
        minutes=len(points),
        heat_pump_kwh=round(hp, 2),
        stove_water_kwh=round(water, 2),
        stove_room_kwh=round(room, 2),
        produced_kwh=round(hp + water + room, 2),
        draw_kwh=round(draw, 2),
        loss_kwh=round(loss, 2),
        loss_useful_kwh=round(loss_useful, 2),
        buffer_change_kwh=round(change, 2),
        residual_kwh=round(residual, 2),
        electric_kwh=round(electric, 2),
        cop_mean=cop,
        stove_minutes=stove_minutes,
        unknown_minutes=ohne,
        note_de=_note(hp, water + room, residual, draw) + _ohne_aussage(ohne, len(points)),
    )


def _ohne_aussage(ohne: int, gesamt: int) -> str:
    """Ein Satz, wenn nennenswert viele Minuten ohne Aussage über die Entnahme blieben.

    Schweigen über eine Lücke sieht aus wie eine Null, und eine Null sieht aus wie eine Messung.
    Unter einem Zwanzigstel bleibt es still: ein paar Minuten am Rand hat jede Reihe.
    """
    if gesamt <= 0 or ohne * 20 < gesamt:
        return ""
    return (
        f" Für {ohne} von {gesamt} Minuten ließ sich über die Entnahme nichts sagen: dort fehlte "
        "die Speichertemperatur oder sie sprang weiter, als ein Wärmestrom es kann."
    )


def _de(x: float, digits: int = 1) -> str:
    """Deutsche Schreibweise. Ein Komma, kein Punkt: die Saetze stehen in der Oberflaeche."""
    return f"{x:.{digits}f}".replace(".", ",")


def _note(hp_kwh: float, stove_kwh: float, residual_kwh: float, draw_kwh: float) -> str:
    """Ein Satz, der sagt, was man sieht - und ob man es glauben darf."""
    total = hp_kwh + stove_kwh
    if total <= 0.05:
        return "In diesem Zeitraum hat kein Erzeuger Wärme geliefert."
    anteil = round(100 * stove_kwh / total)
    wer = (
        f"Der Ofen hat {anteil} % der Wärme geliefert, die Wärmepumpe {100 - anteil} %."
        if stove_kwh > 0.05
        else "Die Wärme kam vollständig aus der Wärmepumpe."
    )
    if draw_kwh > 0.05 and abs(residual_kwh) > 0.25 * draw_kwh:
        return (
            f"{wer} Die Bilanz geht allerdings nicht auf: {_de(abs(residual_kwh))} kWh lassen sich "
            "nicht zuordnen. Das ist ein Hinweis auf einen falschen Parameter, nicht auf eine "
            "fehlende Messung."
        )
    return wer


def minutes_by_level(samples: Sequence[HeatSample], step_min: float = 1.0) -> dict[str, int]:
    """Wie viele Minuten der Ofen auf welcher Leistungsstufe brannte.

    Die Form, die `accounting.stove_cost.estimated_kg_burned` erwartet: ohne Durchsatz je Stufe
    gibt es keinen Verbrauch und ohne Verbrauch keine Kosten. Eine fehlende Stufe zählt als
    Volllast, wie in `stove_output_kw`, und aus demselben Grund: der Ofen läuft praktisch immer
    dort, und eine brennende Flamme ohne Stufe als null zu verbuchen wäre die schlechtere Annahme.

    `step_min` macht die Funktion auch für Stundenwerte brauchbar; dort steht je Stunde eine Probe
    mit der mittleren Stufe und der Zahl der Brennminuten.
    """
    out: dict[str, int] = {}
    for s in samples:
        if not s.stove_running:
            continue
        stufe = str(round(s.stove_level if s.stove_level is not None else 5.0))
        out[stufe] = out.get(stufe, 0) + round(step_min)
    return dict(sorted(out.items()))


# ------------------------------------------------------------------ Stundenraster


class HeatHourInput(BaseModel):
    """Die Eingangsgrößen einer Stunde, aus denen sich die Bilanz rechnen lässt.

    **Eingänge, nicht Ergebnisse.** Gespeichert wird, was gemessen wurde, nicht was das Modell daraus
    macht. Der Unterschied entscheidet darüber, ob eine geänderte Annahme die Vergangenheit erreicht:
    wer Wirkungsgrad oder Arbeitszahl auf der Einstellungsseite dreht, will die Jahresstatistik mit
    den neuen Zahlen sehen und nicht mit denen von damals. Ergebnisse einzufrieren hieße, jede
    Korrektur nur noch nach vorn wirken zu lassen - und niemand würde es merken.
    """

    model_config = ConfigDict(frozen=True)

    hour_start: datetime
    minutes: int = 0
    electric_kwh: float = 0.0  # Strom der Wärmepumpe in dieser Stunde
    outdoor_c: float | None = None
    buffer_top_c: float | None = None  # Mittel der obersten Schicht: die Senke der Wärmepumpe
    buffer_mean_c: float | None = None
    room_c: float | None = None
    buffer_kwh_end: float | None = None  # Inhalt am Stundenende, für die Differenz zur Vorstunde
    stove_minutes: int = 0
    stove_level_mean: float | None = None


def hourly_inputs(samples: Sequence[HeatSample], buffer: BufferConfig) -> list[HeatHourInput]:
    """Eine Minutenreihe zu Stundeneingängen verdichten.

    Die Stunden folgen der Zeitzone der Zeitstempel; wer Ortszeit will, übergibt Ortszeit.
    """
    buckets: dict[datetime, list[HeatSample]] = {}
    for s in samples:
        key = s.at.replace(minute=0, second=0, microsecond=0)
        buckets.setdefault(key, []).append(s)
    out: list[HeatHourInput] = []
    for key in sorted(buckets):
        rows = buckets[key]
        temps = [r.buffer_c for r in rows if r.buffer_c]
        letzte = temps[-1] if temps else None
        stove = [r for r in rows if r.stove_running]
        levels = [r.stove_level for r in stove if r.stove_level is not None]
        out.append(
            HeatHourInput(
                hour_start=key,
                minutes=len(rows),
                electric_kwh=round(sum(r.heat_pump_kw or 0.0 for r in rows) / 60.0, 4),
                outdoor_c=_mean([r.outdoor_c for r in rows]),
                buffer_top_c=_mean([t[0] for t in temps]) if temps else None,
                buffer_mean_c=(
                    _mean([mean_temperature_c(list(t), buffer) for t in temps]) if temps else None
                ),
                room_c=_mean([r.room_c for r in rows]),
                buffer_kwh_end=(
                    round(stored_energy_kwh(list(letzte), buffer), 3) if letzte else None
                ),
                stove_minutes=len(stove),
                stove_level_mean=_mean(levels) if levels else None,
            )
        )
    return out


def _schichten(top_c: float, mean_c: float, buffer: BufferConfig) -> tuple[float, ...]:
    """Aus Kopftemperatur und Mitteltemperatur vier Schichten bauen, deren Mittel wieder `mean_c` ist.

    **Warum nicht einfach (oben, Mittel, Mittel, Mittel).** So stand es hier, und es war falsch:
    `mean_temperature_c` gewichtet alle vier Schichten gleich und liefert daraus 0,25·oben +
    0,75·Mittel, nicht das Mittel. Bei 8 K Schichtung sind das 2 K zu viel, über ein Jahr rund
    7 % zu viel Verlust - eine Abweichung, die niemandem auffällt, weil sie in die richtige
    Richtung klein ist. Die unteren Schichten tragen deshalb genau so viel, dass das gewichtete
    Mittel wieder herauskommt.
    """
    anteile = list(buffer.layers) if len(buffer.layers) == 4 else [0.25] * 4
    summe = sum(anteile) or 1.0
    kopf = anteile[0] / summe
    rest = 1.0 - kopf
    unten = (mean_c - kopf * top_c) / rest if rest > 1e-9 else mean_c
    return (top_c, unten, unten, unten)


def samples_from_hours(rows: Sequence[HeatHourInput], buffer: BufferConfig) -> list[HeatSample]:
    """Stundeneingänge zurück in Proben, damit dieselbe Bilanz darauf läuft.

    Ein Modell, zwei Auflösungen. Die gröbere mittelt die Temperaturen über die Stunde und schätzt
    deshalb die Arbeitszahl etwas anders als die Minutenrechnung; die Größenordnung bleibt, und für
    eine Jahresstatistik ist die Stunde die richtige Auflösung. Dass es zwei Modelle **wären**, wenn
    man hier eine zweite Formel schriebe, ist der Grund für diesen Umweg.
    """
    out: list[HeatSample] = []
    for r in rows:
        temps = (
            _schichten(r.buffer_top_c, r.buffer_mean_c, buffer)
            if r.buffer_top_c is not None and r.buffer_mean_c is not None
            else None
        )
        out.append(
            HeatSample(
                at=r.hour_start,
                heat_pump_kw=r.electric_kwh if r.electric_kwh > 0 else None,
                outdoor_c=r.outdoor_c,
                buffer_c=temps,
                room_c=r.room_c,
                stove_running=r.stove_minutes > 0,
                stove_level=r.stove_level_mean,
            )
        )
    return out


def _mean(values: Sequence[float | None]) -> float | None:
    gut = [v for v in values if v is not None]
    return round(sum(gut) / len(gut), 2) if gut else None
