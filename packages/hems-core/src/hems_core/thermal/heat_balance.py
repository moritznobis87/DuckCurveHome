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
from hems_core.domain.config import BufferConfig, HeatDemandConfig, StoveConfig

KWH_PER_LITER_KELVIN = 4.186 / 3600.0  # Wasser: 4,186 kJ/(kg·K) → kWh/(l·K)
KELVIN = 273.15
# Größere Lücken werden nicht überbrückt. Über eine Viertelstunde hinweg aus zwei Temperaturen eine
# Leistung zu bilden, hieße zu behaupten, man wisse, was dazwischen war.
MAX_GAP_MIN = 15.0
# Unter diesem Hub ist die Carnot-Zahl keine Auskunft mehr, sondern eine Division durch fast null.
MIN_LIFT_K = 3.0


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
    buffer_change_kw: float = 0.0  # positiv: der Speicher lädt
    loss_kw: float = 0.0  # an den Aufstellraum
    draw_kw: float = 0.0  # Heizkreis und Warmwasser, als Rest der Bilanz
    residual_kw: float = 0.0  # was die Bilanz nicht erklärt


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
    buffer_change_kwh: float = 0.0
    residual_kwh: float = 0.0
    electric_kwh: float = 0.0  # Strom der Wärmepumpe, Grundlage der Arbeitszahl
    cop_mean: float | None = None  # Arbeitszahl des Zeitraums: Wärme durch Strom
    stove_minutes: int = 0
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


def heat_series(
    samples: Sequence[HeatSample],
    *,
    stove: StoveConfig,
    heat: HeatDemandConfig,
    buffer: BufferConfig,
) -> list[HeatPoint]:
    """Die Wärmebilanz Minute für Minute.

    Die Reihe muss zeitlich sortiert sein. Lücken über `MAX_GAP_MIN` beenden die Ableitung des
    Speicherinhalts, statt sie zu überbrücken.
    """
    out: list[HeatPoint] = []
    prev_at: datetime | None = None
    prev_energy: float | None = None
    for s in samples:
        temps = list(s.buffer_c) if s.buffer_c else []
        energy = stored_energy_kwh(temps, buffer) if temps else None
        gap_h = 0.0
        if prev_at is not None:
            gap_min = (s.at - prev_at).total_seconds() / 60.0
            gap_h = gap_min / 60.0 if 0 < gap_min <= MAX_GAP_MIN else 0.0

        change_kw = 0.0
        if energy is not None and prev_energy is not None and gap_h > 0:
            change_kw = (energy - prev_energy) / gap_h

        sink = temps[0] if temps else None
        cop: float | None = None
        hp_kw = 0.0
        if s.heat_pump_kw is not None and s.heat_pump_kw > 0:
            cop = cop_for(s.outdoor_c if s.outdoor_c is not None else 7.0, sink, heat, buffer)
            hp_kw = s.heat_pump_kw * cop

        water_kw = room_kw = 0.0
        if s.stove_running:
            water_kw, room_kw = stove_output_kw(s.stove_level, stove)

        loss_kw = 0.0
        if temps:
            room = s.room_c if s.room_c is not None else heat.indoor_target_c
            loss_kw = max(0.0, buffer.loss_kw_per_k * (mean_temperature_c(temps, buffer) - room))

        # Die Bilanz: was hineingeht, geht in den Speicher, an den Raum oder in die Kreise.
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
                draw_kw=round(draw_kw, 3),
                residual_kw=round(residual_kw, 3),
            )
        )
        if energy is not None:
            prev_energy = energy
            prev_at = s.at
        elif gap_h == 0.0:
            prev_at = s.at
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
    residual = sum(p.residual_kw for p in points) * h
    electric = sum(s.heat_pump_kw or 0.0 for s in samples) * h
    # Der Speicher: nicht die Summe der Leistungen, sondern die Differenz der Bestände. Sie ist die
    # ehrlichere Zahl, weil sich Lücken in der Reihe nicht aufsummieren.
    inhalt = [p.buffer_kwh for p in points if p.buffer_kwh is not None]
    change = (inhalt[-1] - inhalt[0]) if len(inhalt) >= 2 else 0.0
    cop = round(hp / electric, 2) if electric > 0.05 else None
    stove_minutes = sum(1 for p in points if p.stove_water_kw > 0 or p.stove_room_kw > 0)
    return HeatTotals(
        minutes=len(points),
        heat_pump_kwh=round(hp, 2),
        stove_water_kwh=round(water, 2),
        stove_room_kwh=round(room, 2),
        produced_kwh=round(hp + water + room, 2),
        draw_kwh=round(draw, 2),
        loss_kwh=round(loss, 2),
        buffer_change_kwh=round(change, 2),
        residual_kwh=round(residual, 2),
        electric_kwh=round(electric, 2),
        cop_mean=cop,
        stove_minutes=stove_minutes,
        note_de=_note(hp, water + room, residual, draw),
    )


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
            f"{wer} Die Bilanz geht allerdings nicht auf: {abs(residual_kwh):.1f} kWh lassen sich "
            "nicht zuordnen. Das ist ein Hinweis auf einen falschen Parameter, nicht auf eine "
            "fehlende Messung."
        )
    return wer


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


def samples_from_hours(rows: Sequence[HeatHourInput]) -> list[HeatSample]:
    """Stundeneingänge zurück in Proben, damit dieselbe Bilanz darauf läuft.

    Ein Modell, zwei Auflösungen. Die gröbere mittelt die Temperaturen über die Stunde und schätzt
    deshalb die Arbeitszahl etwas anders als die Minutenrechnung; die Größenordnung bleibt, und für
    eine Jahresstatistik ist die Stunde die richtige Auflösung. Dass es zwei Modelle **wären**, wenn
    man hier eine zweite Formel schriebe, ist der Grund für diesen Umweg.
    """
    out: list[HeatSample] = []
    for r in rows:
        temps = (
            (r.buffer_top_c, r.buffer_mean_c, r.buffer_mean_c, r.buffer_mean_c)
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
