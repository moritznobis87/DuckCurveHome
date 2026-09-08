"""Was eine Kilowattstunde Wärme kostet: Pelletofen gegen Wärmepumpe.

Ohne diese Rechnung kann ein Planer nicht entscheiden, welche der beiden Quellen den Puffer laden
soll. Sie ist der fehlende Baustein zwischen „der Ofen ist angebunden" und „der Ofen wird
eingeplant".

**Die Kette beim Ofen** ist kurz und hat keine unbekannte Größe mehr:

    Nennleistung / Verbrennungswirkungsgrad = Feuerungsleistung
    Feuerungsleistung / Heizwert             = Pelletdurchsatz
    Pelletdurchsatz × Preis                  = Kosten je Stunde
    Kosten je Stunde / gelieferte Wärme      = Wärmepreis

Der letzte Schritt hat eine Entscheidung darin, und sie ist die einzige, über die man streiten kann:
**zählt die Raumwärme als Nutzen?** Der Ofen gibt bei diesem Gerät zwölf Kilowatt ab, davon neun ins
Wasser und drei in den Aufstellraum. Die drei Kilowatt sind kein Verlust, sie heizen die Küche. In
der Heizperiode ersetzen sie damit Wärme, die sonst die Wärmepumpe liefern müsste. Im Sommer, oder
wenn die Küche ohnehin zu warm ist, sind sie wertlos. Deshalb steht der Anrechnungsgrad in der
Konfiguration und nicht in dieser Formel, und deshalb gibt diese Datei **beide** Preise aus.

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
    eur_per_hour: float
    ct_per_kwh_water: float  # alle Kosten auf die Pufferwärme umgelegt
    ct_per_kwh_useful: float  # Kosten auf Puffer plus angerechnete Raumwärme

    @property
    def credited_heat_kw(self) -> float:
        return self.eur_per_hour * 100.0 / self.ct_per_kwh_useful if self.ct_per_kwh_useful else 0.0


def stove_economics(cfg: StoveConfig) -> StoveEconomics:
    """Volllastbetrieb durchrechnen. Teillast wird bewusst nicht modelliert.

    Der Ofen läuft in diesem Haus praktisch immer auf Stufe 5, und für einen Planer, der ihn nur
    ein- oder ausschaltet, ist das auch die einzige Betriebsart, die zählt. Eine Teillastkennlinie
    zu erfinden, die niemand gemessen hat, würde die Rechnung nicht genauer machen, nur länger.
    """
    eff = max(cfg.combustion_efficiency, 1e-6)
    fuel_kw = cfg.nominal_heat_kw / eff
    kg_per_hour = fuel_kw / max(cfg.pellet_kwh_per_kg, 1e-6)
    eur_per_hour = kg_per_hour * cfg.pellet_price_eur_per_t / 1000.0
    room_kw = max(cfg.nominal_heat_kw - cfg.water_heat_kw, 0.0)
    credited_kw = cfg.water_heat_kw + room_kw * cfg.room_heat_credit
    return StoveEconomics(
        fuel_kw=round(fuel_kw, 2),
        chimney_loss_kw=round(fuel_kw - cfg.nominal_heat_kw, 2),
        water_heat_kw=cfg.water_heat_kw,
        room_heat_kw=round(room_kw, 2),
        kg_per_hour=round(kg_per_hour, 3),
        eur_per_hour=round(eur_per_hour, 3),
        ct_per_kwh_water=round(_ct_per_kwh(eur_per_hour, cfg.water_heat_kw), 2),
        ct_per_kwh_useful=round(_ct_per_kwh(eur_per_hour, credited_kw), 2),
    )


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
    econ = stove_economics(cfg)
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
    econ = stove_economics(cfg)
    stove_ct = econ.ct_per_kwh_useful if credit_room_heat else econ.ct_per_kwh_water
    return round(price_ct_kwh / stove_ct, 2) if stove_ct > 1e-6 else float("inf")
