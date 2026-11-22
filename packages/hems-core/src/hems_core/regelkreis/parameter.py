"""Das Parameterregister: jede Zahl der Regelstrecke mit ihrer Herkunft.

**Warum ein Register und keine verstreuten Konstanten.** Die Regelung dieses Hauses hängt an rund
dreißig Zahlen. Ein Teil davon ist gemessen, ein Teil geschätzt, ein Teil geraten, und ein Teil ist
kein Messwert, sondern Entwurfsergebnis. Verstreut über die Module sieht das alles gleich aus - eine
Gleitkommazahl neben der anderen -, und genau diese Gleichheit ist das Problem: wer den
Verlustkoeffizienten des Hauses für gemessen hält, zieht aus dem Fahrplan Schlüsse, die er nicht
ziehen darf.

Deshalb trägt hier jeder Parameter seine **Herkunft** mit: woher der Startwert kommt, welche
Auswertung ihn nachführt, in welchen Grenzen er plausibel ist und was er in der Regelung bewirkt.
Die Karte zeigt diese Herkunft als Farbe, und der Mensch sieht auf einen Blick, welche Zahl eine
Messung ist und welche eine Annahme.

**Der Startwert kommt aus der Konfiguration, wo es dort einen gibt.** `pfad` nennt Abschnitt und
Feld in `HemsConfig`; was die Konfiguration nicht kennt (Totzeiten, Zeitkonstanten, Raumkapazitäten),
steht als `vorgabe` hier, mit der Begründung im Text. Doppelt gepflegte Zahlen gibt es nicht: ändert
jemand die Wärmeannahmen auf der Einstellungsseite, ändert sich der Startwert hier mit.

**Was dieses Modul nicht tut.** Es schätzt nicht, es rechnet keine Regler aus und es liest keine
Daten. Es beschreibt. Geschätzt wird in `schaetzer`, entworfen in `entwurf`, zusammengesetzt in
`karte`.
"""

from __future__ import annotations

from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from typing import Literal

from hems_core.domain.config import HemsConfig

#: Woher der geltende Wert eines Parameters stammt.
#:
#: * `gemessen` - eine bestehende Auswertung über echten Messreihen liefert ihn (COP-Kennlinie,
#:   Kontaktwirkung, Wärmebilanz). Der belastbarste Fall.
#: * `geschaetzt` - ein laufender Schätzer hat ihn aus dem Betrieb nachgeführt.
#: * `annahme` - Startwert aus Konfiguration oder Datenblatt, noch nie nachgeführt.
#: * `fest` - geometrisch oder vertraglich festgelegt, wird nicht geschätzt.
#: * `entwurf` - kein Messwert, sondern Ergebnis der Auslegung oder eine freie Entwurfsgröße.
#: * `uebersteuert` - ein Mensch hat die Schätzung überschrieben.
Herkunft = Literal["gemessen", "geschaetzt", "annahme", "fest", "entwurf", "uebersteuert"]

#: Mit welchem Verfahren der Parameter nachgeführt wird.
Schaetzart = Literal["ausgleich", "rls", "ereignis", "bilanz", "ewma", "keiner"]

#: Was jedes Verfahren tut, in einem Satz für die Oberfläche.
SCHAETZART_TEXT: Mapping[Schaetzart, str] = {
    "ausgleich": "Kleinste Quadrate über die Messpunkte, geschlossen gelöst. Liefert Restfehler und "
    "Gültigkeitsbereich mit.",
    "rls": "Rekursive kleinste Quadrate mit Vergessensfaktor. Das Modell ist in diesem Parameter "
    "linear, deshalb genügt die geschlossene Form; die Kovarianz liefert die Unsicherheit.",
    "ereignis": "Auswertung einzelner Schaltereignisse gegen die gleiche Tageszeit ohne Schaltung. "
    "Liefert Totzeit und Zeitkonstante, nicht die Verstärkung.",
    "bilanz": "Aus dem Rest der Wärmebilanz. Das Haus hat keinen Wärmemengenzähler; was die Bilanz "
    "nicht erklärt, wird auf diesen Parameter zurückgerechnet.",
    "ewma": "Exponentiell gewichteter Mittelwert über das Verhältnis Ist zu Erwartung.",
    "keiner": "Wird nicht geschätzt.",
}


@dataclass(frozen=True)
class Parameter:
    """Ein Parameter der Regelstrecke oder des Entwurfs."""

    id: str
    #: Der Block der Karte, an dem er hängt.
    block: str
    symbol: str
    name: str
    #: Einheit für die Anzeige; `"—"` heißt dimensionslos.
    einheit: str
    #: Dezimalstellen der Anzeige. Keine Rechengenauigkeit, nur Darstellung.
    stellen: int
    schaetzart: Schaetzart
    #: Plausibilitätsgrenzen. Was darüber hinaus geschätzt wird, ist ein Messfehler und keine
    #: Erkenntnis; die Übernahmeprüfung lehnt es ab und sagt, dass sie es getan hat.
    unten: float
    oben: float
    #: Was die Zahl in der Regelung bewirkt. Ein Satz, für das Detailblatt.
    warum: str
    #: Abschnitt und Feld in `HemsConfig`, wenn es dort einen Startwert gibt.
    pfad: tuple[str, str] | None = None
    #: Startwert, wenn die Konfiguration keinen kennt.
    vorgabe: float | None = None
    #: Umrechnung vom Konfigurationswert in die Einheit des Registers (kW/K → W/K).
    faktor: float = 1.0
    #: Welche bestehende Auswertung den Wert liefern kann. Leer heißt: noch keine.
    quelle: str | None = None
    #: Was sich mitändert, wenn dieser Parameter sich ändert. Für das Detailblatt.
    wirkt_auf: tuple[str, ...] = field(default_factory=tuple)

    @property
    def geschaetzt(self) -> bool:
        """Ob überhaupt ein Verfahren vorgesehen ist."""
        return self.schaetzart != "keiner"


def _puffer_kapazitaet(cfg: HemsConfig) -> float:
    """Wärmekapazität des Puffers aus seinem Volumen: Wasser, 4,186 kJ/(kg·K), in kWh/K."""
    return cfg.buffer.volume_liters * 4.186 / 3600.0


def _ofen_raumanteil(cfg: HemsConfig) -> float:
    """Was der Ofen nicht ins Wasser gibt, gibt er an seinen Aufstellraum."""
    return max(0.0, cfg.stove.nominal_heat_kw - cfg.stove.water_heat_kw)


def cop_ebene(cfg: HemsConfig) -> tuple[float, float, float]:
    """Startwerte der COP-Ebene aus der Kennlinie der Konfiguration.

    Die Konfiguration kennt den COP nur über der Außentemperatur, gültig bei Puffer-Zieltemperatur
    (`HeatDemandConfig.cop_curve`). Die Regelung braucht ihn über **beiden** Temperaturen, weil die
    Vorlaufregelung an der Verstärkung des Erzeugers dreht. Also: Steigung über der Außentemperatur
    aus der Kennlinie nach kleinsten Quadraten, Steigung über der Vorlauftemperatur als Annahme aus
    der Carnot-Zahl (ein Grad Vorlauf kostet bei diesen Temperaturen rund 0,045 Arbeitszahl), und
    der Achsabschnitt so, dass die Ebene die Kennlinie am Zielpunkt trifft.

    Sobald genug eigene Messpunkte vorliegen, ersetzt `thermal.kennlinie.ausgleich` alle drei
    Zahlen - gemessen statt gerechnet. Diese Funktion liefert nur den Anfang.
    """
    punkte: Sequence[tuple[float, float]] = sorted(cfg.heat_demand.cop_curve)
    ziel = cfg.buffer.target_temperature_c
    if len(punkte) < 2:
        return (3.0 + VORLAUF_BEIWERT * ziel, 0.08, -VORLAUF_BEIWERT)
    n = len(punkte)
    mt = sum(t for t, _ in punkte) / n
    mc = sum(c for _, c in punkte) / n
    oben = sum((t - mt) * (c - mc) for t, c in punkte)
    unten = sum((t - mt) ** 2 for t, _ in punkte)
    b = oben / unten if unten > 1e-9 else 0.08
    # Die Kennlinie gilt bei Zieltemperatur: dort muss die Ebene sie treffen.
    a = mc - b * mt + VORLAUF_BEIWERT * ziel
    return (a, b, -VORLAUF_BEIWERT)


#: Was ein Grad Vorlauf an Arbeitszahl kostet, solange es niemand gemessen hat. Aus dem Verhältnis
#: der Carnot-Zahlen bei den Temperaturen dieses Hauses abgeschätzt, nicht aus einem Datenblatt.
VORLAUF_BEIWERT = 0.045

#: Startwerte, die sich nicht aus einem einzelnen Konfigurationsfeld ergeben.
_ABGELEITETE_STARTWERTE: Mapping[str, Callable[[HemsConfig], float]] = {
    "puffer_c": _puffer_kapazitaet,
    "ofen_raum": _ofen_raumanteil,
    "cop_a": lambda cfg: cop_ebene(cfg)[0],
    "cop_b": lambda cfg: cop_ebene(cfg)[1],
    "cop_c": lambda cfg: cop_ebene(cfg)[2],
}

_REGISTER: tuple[Parameter, ...] = (
    # ---------------------------------------------------------------- Wärmebedarf des Hauses
    Parameter(
        id="h_haus",
        block="bedarf",
        symbol="H",
        name="Verlustkoeffizient des Hauses",
        einheit="kW/K",
        stellen=3,
        schaetzart="rls",
        unten=0.08,
        oben=0.45,
        pfad=("heat_demand", "heat_loss_kw_per_k"),
        quelle="Wärmebilanz gegen Gradstunden (thermal.heat_balance)",
        wirkt_auf=("Bedarfsprognose", "Vorsteuerung des Pufferkreises", "Heizkennlinie"),
        warum="Wärmestrom je Kelvin Temperaturdifferenz. Die wichtigste Zahl der Prognose; bis zur "
        "Messung eine Schätzung, und als solche gekennzeichnet.",
    ),
    Parameter(
        id="q_intern",
        block="bedarf",
        symbol="Q̇int",
        name="Interne Gewinne",
        einheit="kW",
        stellen=2,
        schaetzart="rls",
        unten=0.0,
        oben=2.0,
        pfad=("heat_demand", "internal_gains_kw"),
        quelle="Wärmebilanz gegen Gradstunden",
        wirkt_auf=("Bedarfsprognose", "Heizgrenze"),
        warum="Personen, Geräte, Kochen. Verschiebt die Heizgrenze: je größer, desto früher darf "
        "die Heizung aus.",
    ),
    Parameter(
        id="ww_tag",
        block="bedarf",
        symbol="Q̇WW",
        name="Warmwasserbedarf",
        einheit="kWh/d",
        stellen=1,
        schaetzart="bilanz",
        unten=1.0,
        oben=25.0,
        pfad=("heat_demand", "dhw_kwh_per_day"),
        quelle="Rest der Wärmebilanz (thermal.heat_balance.draw_kw)",
        wirkt_auf=("Fahrplan", "Hysterese am Puffer"),
        warum="Die größte nicht gemessene Last am Puffer. Ohne Wärmemengenzähler nur aus dem "
        "Bilanzrest zu bekommen.",
    ),
    Parameter(
        id="heizgrenze",
        block="bedarf",
        symbol="Ta,grenze",
        name="Heizgrenze",
        einheit="°C",
        stellen=1,
        schaetzart="bilanz",
        unten=8.0,
        oben=20.0,
        pfad=("heat_demand", "heating_limit_c"),
        quelle="Wärmebilanz: ab wann das Haus wirklich Wärme zog",
        wirkt_auf=("Bedarfsprognose", "Heizkennlinie"),
        warum="Oberhalb davon rechnet die Prognose mit null. Zu hoch gesetzt heißt heizen, wenn "
        "die Gewinne längst reichen.",
    ),
    # ---------------------------------------------------------------- COP-Kennfeld
    Parameter(
        id="cop_a",
        block="cop",
        symbol="a",
        name="COP-Kennfeld: Achsabschnitt",
        einheit="—",
        stellen=2,
        schaetzart="ausgleich",
        unten=1.0,
        oben=9.0,
        quelle="thermal.kennlinie.ausgleich (gemessene Fenster im Heizbetrieb)",
        wirkt_auf=("Grenzkosten der Wärmepumpe", "Verstärkung des Pufferkreises"),
        warum="Lage der Ausgleichsebene. Bestimmt mit b und c jede Zuordnungsentscheidung zwischen "
        "Wärmepumpe und Ofen.",
    ),
    Parameter(
        id="cop_b",
        block="cop",
        symbol="b",
        name="COP-Kennfeld: Außentemperatur",
        einheit="1/K",
        stellen=3,
        schaetzart="ausgleich",
        unten=0.0,
        oben=0.4,
        quelle="thermal.kennlinie.ausgleich",
        wirkt_auf=("Umschaltpunkt zum Ofen", "Fahrplan"),
        warum="Was ein Grad draußen an Arbeitszahl bringt. Steuert, wie stark der Fahrplan die "
        "Freigabe in milde Stunden verschiebt.",
    ),
    Parameter(
        id="cop_c",
        block="cop",
        symbol="c",
        name="COP-Kennfeld: Vorlauftemperatur",
        einheit="1/K",
        stellen=3,
        schaetzart="ausgleich",
        unten=-0.25,
        oben=0.0,
        quelle="thermal.kennlinie.ausgleich",
        wirkt_auf=("Leitventil-Logik", "Grenzkosten der Wärmepumpe"),
        warum="Was ein Grad Vorlauf kostet. Macht die Kopplung zwischen Vorlaufregelung und "
        "Erzeugerwirkungsgrad überhaupt erst rechenbar.",
    ),
    # ---------------------------------------------------------------- Wärmepumpe
    Parameter(
        id="wp_p_el",
        block="wp",
        symbol="Pel",
        name="Elektrische Aufnahme im Freigabebetrieb",
        einheit="kW",
        stellen=2,
        schaetzart="rls",
        unten=1.0,
        oben=9.0,
        pfad=("heat_pump", "nominal_electric_power_kw"),
        quelle="Median der Minuten mit stehender Anforderung, ohne Heizstabminuten",
        wirkt_auf=("Verstärkung des Pufferkreises", "Kosten im Fahrplan"),
        warum="Was die Maschine zieht, wenn sie der Anforderung folgt. Datenblattwerte liegen hier "
        "regelmäßig zu hoch.",
    ),
    Parameter(
        id="wp_totzeit",
        block="wp",
        symbol="Tt",
        name="Totzeit der Wärmepumpe",
        einheit="min",
        stellen=1,
        schaetzart="ereignis",
        unten=0.5,
        oben=25.0,
        vorgabe=3.0,
        quelle="Ereignisstudie der Anforderungen (thermal.kontaktwirkung)",
        wirkt_auf=("Auslegung des Pufferkreises", "Taktbewertung"),
        warum="Von der Anforderung bis zum messbaren Leistungsanstieg. Begrenzt die erreichbare "
        "Bandbreite des Pufferkreises unmittelbar - vor jeder Reglereinstellung.",
    ),
    Parameter(
        id="wp_t1",
        block="wp",
        symbol="T1",
        name="Anlaufzeitkonstante",
        einheit="min",
        stellen=1,
        schaetzart="ereignis",
        unten=1.0,
        oben=45.0,
        vorgabe=8.0,
        quelle="Ereignisstudie der Anforderungen",
        wirkt_auf=("Auslegung des Pufferkreises", "Mindestlaufzeit"),
        warum="Hochlauf des Verdichters bis zur stationären Leistung.",
    ),
    # ---------------------------------------------------------------- Pelletofen
    Parameter(
        id="ofen_eta",
        block="ofen",
        symbol="η",
        name="Kesselwirkungsgrad",
        einheit="—",
        stellen=3,
        schaetzart="bilanz",
        unten=0.55,
        oben=1.0,
        pfad=("stove", "combustion_efficiency"),
        quelle="Pelletverbrauch gegen Wärmebilanz (accounting.stove_cost)",
        wirkt_auf=("Grenzkosten des Ofens", "Umschaltpunkt"),
        warum="Verhältnis Nutzwärme zu Brennstoffenergie. Setzt mit dem Pelletpreis die Linie, "
        "gegen die die Wärmepumpe läuft.",
    ),
    Parameter(
        id="ofen_mdot",
        block="ofen",
        symbol="ṁmax",
        name="Pelletdurchsatz bei Volllast",
        einheit="kg/h",
        stellen=2,
        schaetzart="bilanz",
        unten=0.8,
        oben=5.0,
        pfad=("stove", "pellet_kg_per_hour_max"),
        quelle="Behälterfüllungen gegen Betriebsstunden",
        wirkt_auf=("Grenzkosten des Ofens", "Nachlegezeitpunkt"),
        warum="Verbindet Leistungsstufe und Kosten je Stunde.",
    ),
    Parameter(
        id="ofen_totzeit",
        block="ofen",
        symbol="Tt",
        name="Zünd- und Anlaufzeit",
        einheit="min",
        stellen=1,
        schaetzart="ereignis",
        unten=3.0,
        oben=45.0,
        vorgabe=12.0,
        quelle="Zündereignisse gegen die erste Wärme im Wasser",
        wirkt_auf=("Mindestlaufzeit", "Startkosten im Fahrplan"),
        warum="Vom Startbefehl bis Wärme im Wasser. Der Grund, warum der Ofen in den Fahrplan "
        "gehört und nicht in einen schnellen Kreis.",
    ),
    Parameter(
        id="ofen_raum",
        block="ofen",
        symbol="Q̇Raum",
        name="Direkte Raumwärme des Ofens",
        einheit="kW",
        stellen=2,
        schaetzart="bilanz",
        unten=0.2,
        oben=6.0,
        quelle="Wärmebilanz: Leistung minus Wasseranteil",
        wirkt_auf=("Einzelraumregelung des Aufstellraums",),
        warum="Der Anteil, der nicht ins Wasser geht. Für die Einzelraumregelung dieses Raums eine "
        "Störgröße in der Größe seines ganzen Heizkreises - gestellt von der Ebene darüber.",
    ),
    # ---------------------------------------------------------------- Puffer
    Parameter(
        id="puffer_c",
        block="puffer",
        symbol="Cbuf",
        name="Wärmekapazität des Puffers",
        einheit="kWh/K",
        stellen=3,
        schaetzart="keiner",
        unten=0.2,
        oben=4.0,
        quelle="Geometrie: Volumen mal Wärmekapazität des Wassers",
        wirkt_auf=("Verstärkung des Pufferkreises", "thermischer Ladestand"),
        warum="Tausend Liter Wasser. Festgelegt, nicht geschätzt - hier gibt es nichts zu lernen.",
    ),
    Parameter(
        id="puffer_ua",
        block="puffer",
        symbol="UA",
        name="Verlustbeiwert des Speichers",
        einheit="W/K",
        stellen=1,
        schaetzart="rls",
        unten=0.5,
        oben=25.0,
        pfad=("buffer", "loss_kw_per_k"),
        faktor=1000.0,
        quelle="Abkühlung in Nächten ohne Erzeugung und ohne Zapfung",
        wirkt_auf=("Bilanzrest", "Fahrplan"),
        warum="Steht im Modell gegen die Übertemperatur zum Aufstellraum. Die Hälfte dieses "
        "Verlusts heizt den Technikraum und ist deshalb nicht verloren.",
    ),
    Parameter(
        id="puffer_schicht",
        block="puffer",
        symbol="Tschicht",
        name="Schichtungszeitkonstante",
        einheit="min",
        stellen=0,
        schaetzart="rls",
        unten=3.0,
        oben=90.0,
        vorgabe=18.0,
        quelle="Laufzeit einer Temperaturfront von Fühler zu Fühler",
        wirkt_auf=("Beobachter", "Totzeit des Pufferkreises"),
        warum="Macht aus dem Speicher eine Kette von vier Gliedern statt eines einzigen. Der "
        "Regler sieht die obere Schicht, meint aber die Energie.",
    ),
    # ---------------------------------------------------------------- Vorlauf
    Parameter(
        id="vl_k",
        block="heizkreis",
        symbol="KVL",
        name="Mischerverstärkung",
        einheit="K/%",
        stellen=2,
        schaetzart="rls",
        unten=0.05,
        oben=2.5,
        vorgabe=0.8,
        quelle="Vorlauftemperatur gegen Mischerstellung im Arbeitsbereich",
        wirkt_auf=("Auslegung des Vorlaufkreises",),
        warum="Vorlaufhub je Prozent Stellung. Über den Hub nichtlinear; geschätzt wird die "
        "Steigung dort, wo der Mischer wirklich steht.",
    ),
    Parameter(
        id="vl_t1",
        block="heizkreis",
        symbol="T1",
        name="Zeitkonstante Vorlauf",
        einheit="min",
        stellen=1,
        schaetzart="ereignis",
        unten=0.3,
        oben=25.0,
        vorgabe=3.5,
        quelle="Sprungantwort des Mischers",
        wirkt_auf=("Auslegung des Vorlaufkreises",),
        warum="Mischer, Pumpe und Rohrinhalt zusammen.",
    ),
    Parameter(
        id="vl_totzeit",
        block="heizkreis",
        symbol="Tt",
        name="Transportzeit bis zum Fühler",
        einheit="min",
        stellen=1,
        schaetzart="ereignis",
        unten=0.1,
        oben=12.0,
        vorgabe=1.4,
        quelle="Sprungantwort des Mischers",
        wirkt_auf=("Auslegung des Vorlaufkreises",),
        warum="Wasserlaufzeit vom Mischer zum Vorlauffühler. Reine Totzeit, und damit die "
        "Obergrenze der Kreisverstärkung.",
    ),
    Parameter(
        id="kl_steil",
        block="kennlinie",
        symbol="s",
        name="Steilheit der Heizkennlinie",
        einheit="—",
        stellen=2,
        schaetzart="bilanz",
        unten=0.3,
        oben=2.5,
        vorgabe=1.2,
        quelle="Ventilhübe und Rücklauftemperaturen über Tage",
        wirkt_auf=("Vorlaufsollwert", "COP der Wärmepumpe"),
        warum="Zu steil heißt dauerhaft zu warmer Vorlauf, also jeden Tag ein kleinerer COP, "
        "obwohl die Räume stimmen. Man sieht es nicht an der Raumtemperatur, nur an den Hüben.",
    ),
    # ---------------------------------------------------------------- Einzelraum
    Parameter(
        id="ventil_autoritaet",
        block="ventil",
        symbol="av",
        name="Ventilautorität",
        einheit="—",
        stellen=2,
        schaetzart="rls",
        unten=0.05,
        oben=1.0,
        vorgabe=0.5,
        quelle="Hub gegen Rücklauftemperatur je Heizkreis",
        wirkt_auf=("Verstärkung des Raumkreises", "Linearisierung des Hubs"),
        warum="Anteil des Druckverlusts am Ventil. Klein heißt: der halbe Hub bewirkt fast den "
        "vollen Durchfluss, der Kreis wird nichtlinear.",
    ),
    Parameter(
        id="ventil_stellzeit",
        block="ventil",
        symbol="Tstell",
        name="Stellzeit des Antriebs",
        einheit="s",
        stellen=0,
        schaetzart="ereignis",
        unten=10.0,
        oben=600.0,
        vorgabe=90.0,
        quelle="Motorstrom und Hub am Verteilerregler",
        wirkt_auf=("Auslegung des Raumkreises",),
        warum="Vollhub des stufenlosen Antriebs. Gegen die Zeitkonstanten des Estrichs klein, "
        "gehört aber in die Rechnung und nicht in die Fehlersuche.",
    ),
    Parameter(
        id="raum_c_luft",
        block="raum",
        symbol="CLuft",
        name="Wärmekapazität Luft und Einrichtung",
        einheit="kWh/K",
        stellen=3,
        schaetzart="rls",
        unten=0.005,
        oben=0.25,
        vorgabe=0.04,
        quelle="Raumtemperatur gegen Ventilhub und Störgrößen",
        wirkt_auf=("zweite Zeitkonstante des Raumkreises",),
        warum="Der schnelle Knoten. Bestimmt, wie rasch Sonne und offene Fenster sich in der "
        "Temperatur zeigen.",
    ),
    Parameter(
        id="raum_c_estrich",
        block="raum",
        symbol="CEstrich",
        name="Wärmekapazität des Estrichs",
        einheit="kWh/K",
        stellen=2,
        schaetzart="rls",
        unten=0.1,
        oben=3.0,
        vorgabe=0.7,
        quelle="Raumtemperatur gegen Ventilhub über Stunden",
        wirkt_auf=("dominante Zeitkonstante des Raumkreises", "Nachstellzeit"),
        warum="Der langsame Knoten, und damit die dominante Zeitkonstante des ganzen Hauses.",
    ),
    Parameter(
        id="raum_r",
        block="raum",
        symbol="RE→L",
        name="Übergangswiderstand Estrich zu Raumluft",
        einheit="K/kW",
        stellen=2,
        schaetzart="rls",
        unten=1.0,
        oben=30.0,
        vorgabe=7.5,
        quelle="Raumtemperatur gegen Ventilhub über Stunden",
        wirkt_auf=("Zeitkonstanten des Raumkreises",),
        warum="Bodenaufbau und Belag. Jeder Teppich verschiebt diese Zahl.",
    ),
    Parameter(
        id="raum_h",
        block="raum",
        symbol="HRaum",
        name="Verlustkoeffizient des Raums",
        einheit="kW/K",
        stellen=3,
        schaetzart="rls",
        unten=0.004,
        oben=0.2,
        vorgabe=0.034,
        quelle="Auskühlung des Raums gegen die Außentemperatur",
        wirkt_auf=("Verstärkung des Raumkreises", "Plausibilitätsprüfung gegen H"),
        warum="Hülle und Lüftung dieses Raums. Die Summe über alle Räume muss zu H des Hauses "
        "passen - eine laufende Prüfung, die Messfehler auffliegen lässt.",
    ),
    Parameter(
        id="raum_a_eff",
        block="raum",
        symbol="Aeff·g",
        name="Wirksame solare Apertur",
        einheit="m²",
        stellen=2,
        schaetzart="rls",
        unten=0.1,
        oben=15.0,
        vorgabe=2.5,
        quelle="Raumtemperatur gegen Globalstrahlung, nur Sonnenstunden",
        wirkt_auf=("Störgrößenaufschaltung Sonne", "Bedarfsprognose"),
        warum="Fensterfläche mal Energiedurchlass mal Verschattung. Nur aus Sonnenstunden "
        "schätzbar, deshalb langsam.",
    ),
    Parameter(
        id="raum_totzeit",
        block="raum",
        symbol="Tt",
        name="Totzeit der Fußbodenheizung",
        einheit="min",
        stellen=0,
        schaetzart="ereignis",
        unten=3.0,
        oben=120.0,
        vorgabe=15.0,
        quelle="Kreuzkorrelation von Hub und Raumtemperatur",
        wirkt_auf=("Auslegung des Raumkreises",),
        warum="Vom Ventilhub bis zur ersten messbaren Reaktion der Raumluft.",
    ),
    Parameter(
        id="raum_q_max",
        block="raum",
        symbol="Q̇max",
        name="Auslegungsleistung des Heizkreises",
        einheit="kW",
        stellen=2,
        schaetzart="keiner",
        unten=0.1,
        oben=6.0,
        vorgabe=1.2,
        quelle="Rohrabstand, Länge und Auslegungsspreizung",
        wirkt_auf=("Verstärkung des Raumkreises",),
        warum="Rohrabstand, Länge und Auslegungsspreizung des Kreises. Eine feste Größe des "
        "Bauwerks, die nur eine Sanierung ändert - geschätzt wird sie deshalb nicht.",
    ),
    # ---------------------------------------------------------------- Prognose
    Parameter(
        id="pv_bias",
        block="pv",
        symbol="k[b]",
        name="Bias-Korrektur der PV-Prognose",
        einheit="—",
        stellen=3,
        schaetzart="ewma",
        unten=0.5,
        oben=1.5,
        vorgabe=1.0,
        quelle="Bestehender Korrektor, Zustand in model_calibrations (pv_forecast_v1)",
        wirkt_auf=("Fahrplan", "Grenzkosten der Wärmepumpe"),
        warum="Fängt systematische Fehler der Prognosequellen: falsche kWp, Horizontverschattung, "
        "Verschmutzung. Gezeigt wird die Klasse der mittleren Sonnenhöhe.",
    ),
    # ---------------------------------------------------------------- Entwurfsgrößen
    Parameter(
        id="lam_r0",
        block="raum_regler",
        symbol="λ",
        name="Entwurfsparameter des Raumkreises",
        einheit="min",
        stellen=0,
        schaetzart="keiner",
        unten=5.0,
        oben=300.0,
        vorgabe=30.0,
        quelle="Entwurfsentscheidung, kein Messwert",
        wirkt_auf=("KR und Tn des Raumreglers",),
        warum="Die gewünschte Ersatzzeitkonstante des geschlossenen Kreises und die einzige freie "
        "Zahl im Entwurf. Klein heißt schnell und nervös, groß heißt gelassen.",
    ),
    Parameter(
        id="lam_r1",
        block="vl_regler",
        symbol="λ",
        name="Entwurfsparameter des Vorlaufkreises",
        einheit="min",
        stellen=1,
        schaetzart="keiner",
        unten=0.3,
        oben=40.0,
        vorgabe=2.1,
        quelle="Entwurfsentscheidung, kein Messwert",
        wirkt_auf=("KR und Tn des Mischerreglers",),
        warum="Grundeinstellung ist λ = Tt; alles darunter kauft Geschwindigkeit mit Reserve.",
    ),
    Parameter(
        id="lam_r2",
        block="puffer_regler",
        symbol="λ",
        name="Entwurfsparameter des Pufferkreises",
        einheit="min",
        stellen=0,
        schaetzart="keiner",
        unten=2.0,
        oben=240.0,
        vorgabe=20.0,
        quelle="Entwurfsentscheidung, kein Messwert",
        wirkt_auf=("KR, Tn und Hysteresebreite des Pufferreglers",),
        warum="Bestimmt mit der Taktzahlgrenze, wie breit die Hysterese am Kontakt wird.",
    ),
)

#: Alle Parameter, nach Kennung.
PARAMETER: Mapping[str, Parameter] = {p.id: p for p in _REGISTER}

#: Die Entwurfsgrößen je Kreis. Sie sind keine Messwerte und stehen deshalb getrennt.
LAMBDA_JE_KREIS: Mapping[str, str] = {"R0": "lam_r0", "R1": "lam_r1", "R2": "lam_r2"}


def startwert(pid: str, cfg: HemsConfig) -> float:
    """Der Startwert eines Parameters: aus der Konfiguration, wenn sie ihn kennt, sonst Vorgabe.

    Fehlt beides, ist das ein Fehler im Register und keine Laufzeitfrage - dann fliegt es hier auf
    und nicht später in einer Division.
    """
    p = PARAMETER[pid]
    sonder = _ABGELEITETE_STARTWERTE.get(pid)
    if sonder is not None:
        return sonder(cfg)
    if p.pfad is not None:
        abschnitt, feld = p.pfad
        wert = getattr(getattr(cfg, abschnitt), feld)
        if not isinstance(wert, int | float):
            raise TypeError(f"{pid}: {abschnitt}.{feld} ist keine Zahl")
        return float(wert) * p.faktor
    if p.vorgabe is None:
        raise ValueError(f"{pid}: weder Pfad noch Vorgabe")
    return p.vorgabe


def startwerte(cfg: HemsConfig) -> dict[str, float]:
    """Alle Startwerte auf einmal."""
    return {pid: startwert(pid, cfg) for pid in PARAMETER}


def begrenzt(pid: str, wert: float) -> float:
    """Auf die Plausibilitätsgrenzen beschnitten."""
    p = PARAMETER[pid]
    return min(p.oben, max(p.unten, wert))


def je_block() -> dict[str, tuple[str, ...]]:
    """Welche Parameter an welchem Block hängen, in Registerreihenfolge."""
    out: dict[str, list[str]] = {}
    for p in _REGISTER:
        out.setdefault(p.block, []).append(p.id)
    return {k: tuple(v) for k, v in out.items()}
