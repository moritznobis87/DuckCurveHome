"""Was eine Kilowattstunde Wärme kostet: Pelletofen gegen Wärmepumpe.

Ohne diese Rechnung kann ein Planer nicht entscheiden, welche der beiden Quellen den Puffer laden
soll. Sie ist der fehlende Baustein zwischen „der Ofen ist angebunden" und „der Ofen wird
eingeplant".

**Die Kette beim Ofen** ist kurz und hat keine unbekannte Größe mehr:

    Nennleistung / Verbrennungswirkungsgrad = Feuerungsleistung
    Feuerungsleistung / Heizwert             = Pelletdurchsatz
    Pelletdurchsatz × Preis                  = Kosten je Stunde
    Kosten je Stunde / gelieferte Wärme      = Wärmepreis

Der letzte Schritt hat eine Entscheidung darin: **zählt die Raumwärme als Nutzen?** Der Ofen gibt
11,9 kW ab, davon 10 ins Wasser und 1,9 in die Küche. Die 1,9 kW sind kein Verlust, sie heizen den
Aufstellraum, und in der Heizperiode ersetzen sie Wärme, die sonst die Wärmepumpe liefern müsste.
Der Anrechnungsgrad steht deshalb in der Konfiguration, und diese Datei gibt **beide** Preise aus.
Bei diesem Gerät ist der Unterschied klein, weil fast alles ins Wasser geht.

**Die Kette prüft sich selbst.** Das Datenblatt nennt neben Leistung und Wirkungsgrad auch den
maximalen Pelletverbrauch. Beide Wege müssen zum selben Ergebnis führen, und sie tun es:

    vorwärts:   11,9 / 0,904 / 4,9        = 2,686 kg/h   (Datenblatt: 2,7)
    rückwärts:  2,7 × 4,9 × 0,904         = 11,96 kW     (Datenblatt: 11,9)

Damit ist auch der Heizwert bestätigt. Mit den geschätzten 5,4 kWh/kg käme die Rechnung auf
2,44 kg/h und läge zehn Prozent unter dem Datenblatt. `datasheet_deviation` prüft das laufend, damit
eine falsch eingetragene Zahl nicht still eine falsche Entscheidung erzeugt.

**Der Eigenverbrauch** von 75 W ist klein, aber er gehört dazu: er ist Strom zum Marktpreis und
verschiebt den Vergleich in dieselbe Richtung wie ein teurer Strompreis, nur um wenige Zehntel.

**Teillast kostet dasselbe.** Das ist das überraschendste Ergebnis dieser Rechnung und der Grund,
warum der Planer keine Teillastkennlinie braucht. Der Ofen ist auf kleiner Flamme
wirkungsgradbesser (96,1 statt 91,1 %), weil das Rauchgas kühler abzieht, verliert aber gleichzeitig
Wasseranteil (56 statt 84 %). Auf die gesamte Nutzwärme gerechnet heben sich beide Effekte fast
genau auf:

    Volllast     11,9 kW nutzbar    2,67 kg/h    10,27 ct/kWh
    Minimallast   3,2 kW nutzbar    0,68 kg/h    10,26 ct/kWh

Für den Planer heißt das: die Modulation ist **keine Kostenfrage, sondern eine Zeitfrage.** Sie
entscheidet, wie schnell der Puffer voll wird, nicht wie teuer die Wärme ist. Wer nur ein- und
ausschaltet, verliert dadurch nichts.

**Die Wärmepumpe** ist die einfachere Seite: Strompreis geteilt durch Arbeitszahl. Solange der
Wärmemengenzähler fehlt, ist die Arbeitszahl eine Kennlinie über der Außentemperatur und damit eine
Schätzung. Das ist der schwächste Punkt des Vergleichs, und er sitzt auf der Seite der Wärmepumpe,
nicht auf der des Ofens.

Reine Rechenlogik, kein I/O.
"""

from __future__ import annotations

from dataclasses import dataclass

from hems_core.domain.config import StoveConfig


@dataclass(frozen=True)
class StoveEconomics:
    """Der Ofen bei Volllast, vollständig aufgeschlüsselt."""

    fuel_kw: float  # Feuerungsleistung
    chimney_loss_kw: float
    water_heat_kw: float  # in den Puffer
    room_heat_kw: float  # in den Aufstellraum
    kg_per_hour: float
    pellet_eur_per_hour: float
    electricity_eur_per_hour: float  # Eigenverbrauch des Ofens zum Strompreis
    eur_per_hour: float  # beides zusammen
    ct_per_kwh_water: float  # alle Kosten auf die Pufferwärme umgelegt
    ct_per_kwh_useful: float  # Kosten auf Puffer plus angerechnete Raumwärme
    datasheet_deviation: float  # gerechneter Durchsatz gegen den Datenblattwert, als Anteil

    @property
    def plausible(self) -> bool:
        """Stimmt die gerechnete Kette mit dem Datenblatt überein?

        Fünf Prozent Abweichung sind die Toleranz, in der sich Rundung, Feuchte der Pellets und die
        Angabe des Herstellers bewegen. Darüber stimmt eine der eingetragenen Zahlen nicht, und dann
        ist die ganze Entscheidung zwischen Ofen und Wärmepumpe schief.
        """
        return abs(self.datasheet_deviation) <= 0.05


def stove_economics(cfg: StoveConfig, aux_price_ct_kwh: float = 0.0) -> StoveEconomics:
    """Volllastbetrieb durchrechnen. Teillast wird bewusst nicht modelliert.

    Der Ofen läuft in diesem Haus praktisch immer auf Stufe 5, und für einen Planer, der ihn nur
    ein- oder ausschaltet, ist das auch die einzige Betriebsart, die zählt. Das Datenblatt kennt zwar
    einen Minimalverbrauch von 0,7 kg/h, aber eine Teillastkennlinie zu erfinden, die niemand
    gemessen hat, würde die Rechnung nicht genauer machen, nur länger.

    `aux_price_ct_kwh` ist der Strompreis für den Eigenverbrauch des Ofens. Ohne Angabe zählt nur
    der Brennstoff; das ist die Zahl fürs Datenblatt, nicht die für eine Entscheidung.
    """
    eff = max(cfg.combustion_efficiency, 1e-6)
    fuel_kw = cfg.nominal_heat_kw / eff
    kg_per_hour = fuel_kw / max(cfg.pellet_kwh_per_kg, 1e-6)
    pellet_eur = kg_per_hour * cfg.pellet_price_eur_per_t / 1000.0
    electricity_eur = cfg.electric_w / 1000.0 * aux_price_ct_kwh / 100.0
    total_eur = pellet_eur + electricity_eur
    room_kw = max(cfg.nominal_heat_kw - cfg.water_heat_kw, 0.0)
    credited_kw = cfg.water_heat_kw + room_kw * cfg.room_heat_credit
    rated = cfg.pellet_kg_per_hour_max
    deviation = (kg_per_hour - rated) / rated if rated > 1e-6 else 0.0
    return StoveEconomics(
        fuel_kw=round(fuel_kw, 2),
        chimney_loss_kw=round(fuel_kw - cfg.nominal_heat_kw, 2),
        water_heat_kw=cfg.water_heat_kw,
        room_heat_kw=round(room_kw, 2),
        kg_per_hour=round(kg_per_hour, 3),
        pellet_eur_per_hour=round(pellet_eur, 3),
        electricity_eur_per_hour=round(electricity_eur, 4),
        eur_per_hour=round(total_eur, 3),
        ct_per_kwh_water=round(_ct_per_kwh(total_eur, cfg.water_heat_kw), 2),
        ct_per_kwh_useful=round(_ct_per_kwh(total_eur, credited_kw), 2),
        datasheet_deviation=round(deviation, 4),
    )


def stove_economics_min_load(cfg: StoveConfig, aux_price_ct_kwh: float = 0.0) -> StoveEconomics:
    """Derselbe Ofen auf kleinster Flamme, für die Gegenprobe gegen das Datenblatt.

    Gebraucht wird das nicht zum Planen, sondern zum Prüfen: der Minimalverbrauch ist der zweite
    unabhängige Punkt, an dem sich die Kette bestätigen lässt. Trifft sie beide, stimmen Heizwert,
    Wirkungsgrade und Leistungsangaben zusammen.
    """
    return stove_economics(
        cfg.model_copy(
            update={
                "nominal_heat_kw": cfg.min_heat_kw,
                "water_heat_kw": cfg.min_water_heat_kw,
                "combustion_efficiency": cfg.min_combustion_efficiency,
                "pellet_kg_per_hour_max": cfg.pellet_kg_per_hour_min,
            }
        ),
        aux_price_ct_kwh=aux_price_ct_kwh,
    )


def hopper_runtime_h(cfg: StoveConfig) -> float:
    """Wie lange der Behälterinhalt bei Volllast reicht.

    Eine harte Grenze für den Planer: eine Nacht durchheizen geht, zwei Nächte nicht. Wer eine
    Laufzeit einplant, für die kein Brennstoff im Gerät ist, plant eine Wärmelieferung, die ausfällt.
    """
    econ = stove_economics(cfg)
    return round(cfg.hopper_kg / econ.kg_per_hour, 1) if econ.kg_per_hour > 1e-6 else float("inf")


def _ct_per_kwh(eur_per_hour: float, kw: float) -> float:
    return eur_per_hour * 100.0 / kw if kw > 1e-6 else float("inf")


def heat_pump_ct_per_kwh(price_ct_kwh: float, cop: float) -> float:
    """Wärmepreis der Wärmepumpe. `price_ct_kwh` ist der Preis der Stunde, `cop` die Arbeitszahl.

    Der Grenzpreis, nicht der Durchschnitt: für die Frage „wer soll jetzt laden?" zählt, was die
    nächste Kilowattstunde kostet. Eigener Solarstrom gehört mit seinem Opportunitätswert hier
    hinein, also mit der entgangenen Einspeisevergütung, nicht mit null.
    """
    return price_ct_kwh / cop if cop > 1e-6 else float("inf")


@dataclass(frozen=True)
class SourceChoice:
    """Welche Quelle in dieser Stunde die günstigere Wärme liefert."""

    stove_ct: float
    heat_pump_ct: float
    cheaper: str  # "stove" | "heat_pump"
    saving_ct_per_kwh: float
    note_de: str


def cheaper_source(
    cfg: StoveConfig,
    price_ct_kwh: float,
    cop: float,
    *,
    credit_room_heat: bool = True,
) -> SourceChoice:
    """Die beiden Wärmepreise gegenüberstellen.

    `credit_room_heat` schaltet zwischen den beiden Lesarten um: mit Anrechnung der Raumwärme ist
    der Ofen deutlich günstiger, ohne sie deutlich teurer. Wer das ohne Angabe der Lesart vergleicht,
    vergleicht nichts.
    """
    econ = stove_economics(cfg, aux_price_ct_kwh=price_ct_kwh)
    stove_ct = econ.ct_per_kwh_useful if credit_room_heat else econ.ct_per_kwh_water
    hp_ct = heat_pump_ct_per_kwh(price_ct_kwh, cop)
    stove_wins = stove_ct < hp_ct
    diff = abs(hp_ct - stove_ct)
    basis = "mit angerechneter Raumwärme" if credit_room_heat else "nur auf die Pufferwärme"
    winner = "Ofen" if stove_wins else "Wärmepumpe"
    return SourceChoice(
        stove_ct=round(stove_ct, 2),
        heat_pump_ct=round(hp_ct, 2),
        cheaper="stove" if stove_wins else "heat_pump",
        saving_ct_per_kwh=round(diff, 2),
        note_de=(
            f"{winner} günstiger um {diff:.1f} ct/kWh: Ofen {stove_ct:.1f} ({basis}), "
            f"Wärmepumpe {hp_ct:.1f} bei {price_ct_kwh:.1f} ct/kWh Strom und COP {cop:.2f}."
        ),
    )


def break_even_cop(
    cfg: StoveConfig, price_ct_kwh: float, *, credit_room_heat: bool = True
) -> float:
    """Ab welcher Arbeitszahl die Wärmepumpe den Ofen schlägt.

    Die anschaulichste Form des Vergleichs: eine Zahl, die man gegen die COP-Kennlinie halten kann.
    Liegt der Wert über dem, was die Maschine bei der aktuellen Außentemperatur schafft, ist der
    Ofen dran.
    """
    econ = stove_economics(cfg, aux_price_ct_kwh=price_ct_kwh)
    stove_ct = econ.ct_per_kwh_useful if credit_room_heat else econ.ct_per_kwh_water
    return round(price_ct_kwh / stove_ct, 2) if stove_ct > 1e-6 else float("inf")
