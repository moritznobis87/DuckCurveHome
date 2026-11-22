"""Die Regelstrecke des Hauses als Blockschaltbild, beschrieben als Daten.

**Warum die Struktur in den Kern gehört und nicht in die Anzeige.** Wer die Kaskade zeichnet,
behauptet etwas über die Anlage: dass der Vorlaufkreis dem Pufferkreis unterlagert ist, dass die
Warmwasserzapfung eine Last am Speicher ist und keine Stellgröße, dass die Raumwärme des Ofens von
der Ebene über der Einzelraumregelung gestellt wird. Das sind Aussagen über das Haus, nachprüfbar
und widerlegbar, und sie gehören dorthin, wo auch der Regler steht. Die Anzeige legt die Kästchen
hin; **was** verbunden ist, steht hier.

**Die fünf Ebenen und ihre Zeitskalen.** Von außen nach innen - und das ist zugleich von langsam
nach schnell, was die Kaskade überhaupt erst zulässig macht:

* **Ebene 4**, ökonomische Führung: Viertelstundentakt, 48 Stunden Horizont. Rechnet, regelt nicht.
* **Ebene 3**, Speicherladung: Zehn-Sekunden-Takt, Zeitkonstanten in Stunden.
* **Ebene 2**, Erzeuger: Totzeiten von Minuten, Mindestlaufzeiten von Stunden.
* **Ebene 1**, Vorlauftemperatur: Zeitkonstanten in Minuten. Der schnellste Kreis.
* **Ebene 0**, Einzelraum: Zeitkonstanten in Stunden. Der langsamste, wegen des Estrichs.

Dass Ebene 1 schneller ist als Ebene 0, ist kein Widerspruch zur Kaskade, sondern ihr Sinn: der
schnelle Kreis liegt **innen** und hält die Störungen vom langsamen fern. Zwischen Ebene 1 und
Ebene 3 liegt mehr als der Faktor fünf, den die Faustregel verlangt.

**Störgrößen stehen am Ort ihrer Wirkung.** Die Außentemperatur wirkt an vier Stellen gleichzeitig,
und sie wirkt dort verschieden: im Bedarf über die Transmission, im COP über die
Verdampfungstemperatur, in der Heizkennlinie als Vorsteuerung, im Raum direkt. Ein einziger
zentraler Knoten „Wetter" würde das verwischen. Deshalb hat jede Störgröße einen Knoten und mehrere
Kanten - und jede Kante sagt, ob die Störung **aufgeschaltet** (vorher bekannt und verrechnet) oder
nur **ausgeregelt** (hinterher bemerkt) wird. Das ist der regelungstechnisch interessante
Unterschied, und er steht an der Störgröße selbst.

**Zwei Signalmarken statt zweier langer Leitungen.** Die Rückwirkung der Vorlauftemperatur auf die
Arbeitszahl und die Arbeitszahl in der Kostenrechnung führen quer durch das Bild. Sie stehen als
Marke (`gibt_marke` / `marke`), wie in jedem Schaltplan, der nicht zugewachsen sein soll.

Dieses Modul rechnet nicht und liest nichts. Es beschreibt und prüft sich selbst.
"""

from __future__ import annotations

from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Literal

from hems_core.regelkreis.parameter import LAMBDA_JE_KREIS, PARAMETER, je_block

#: Die Kaskadenebene. 4 ist außen und langsam, 0 ist der einzelne Raum.
Ebene = Literal[0, 1, 2, 3, 4]

#: Was ein Block im Kreis ist.
Rolle = Literal[
    "regler",
    "stellglied",
    "strecke",
    "beobachter",
    "rechenglied",
    "modell",
    "logik",
    "vorsteuerung",
    "messglied",
    "stoergroesse",
    "summierstelle",
    "teilkreise",
]

ROLLE_TEXT: Mapping[Rolle, str] = {
    "regler": "Regelglied",
    "stellglied": "Stellglied",
    "strecke": "Regelstrecke",
    "beobachter": "Beobachter",
    "rechenglied": "Rechenglied",
    "modell": "Modell",
    "logik": "Logik",
    "vorsteuerung": "Vorsteuerung",
    "messglied": "Messglied",
    "stoergroesse": "Störgröße",
    "summierstelle": "Summierstelle",
    "teilkreise": "Teilkreise",
}

#: Art einer Verbindung.
Kantenart = Literal["signal", "stoergroesse", "rueckfuehrung", "fuehrung", "parameter"]

#: Wie eine Störgröße behandelt wird. Der eigentliche Befund an jeder Störgröße.
Behandlung = Literal["aufgeschaltet", "ausgeregelt", "beobachtet", "geplant", "erkannt"]

BEHANDLUNG_TEXT: Mapping[Behandlung, str] = {
    "aufgeschaltet": "aufgeschaltet - vor der Wirkung bekannt und verrechnet",
    "ausgeregelt": "nur ausgeregelt - fällt erst als Regelabweichung auf",
    "beobachtet": "beobachtet - nicht gemessen, aus der Bilanz geschätzt",
    "geplant": "geplant - geht als Prognose in den Fahrplan ein",
    "erkannt": "erkannt - der Regler ändert sein Verhalten, wenn sie auftritt",
}


@dataclass(frozen=True)
class Block:
    """Ein Glied des Regelkreises."""

    id: str
    ebene: Ebene
    rolle: Rolle
    name: str
    #: Das Übertragungsglied oder die Kernformel, kurz genug für ein Kästchen.
    kurz: str = ""
    #: Der Kreis, dessen Regler dieser Block ist.
    kreis: str | None = None
    #: Die Absätze für das Detailblatt. Was der Block tut, und warum er so gebaut ist.
    erklaerung: tuple[str, ...] = field(default_factory=tuple)
    #: Die Gleichungen, in der Schreibweise der Oberfläche.
    gleichungen: tuple[str, ...] = field(default_factory=tuple)
    #: Nur bei Störgrößen: wie sie behandelt wird.
    behandlung: Behandlung | None = None
    #: Woher der Wert kommt (Störgrößen und Messglieder).
    quelle: str | None = None
    #: Signalmarke, die dieser Block setzt bzw. liest.
    gibt_marke: str | None = None
    marke: str | None = None

    @property
    def parameter(self) -> tuple[str, ...]:
        """Die Parameter, die an diesem Block hängen."""
        return je_block().get(self.id, ())


@dataclass(frozen=True)
class Kante:
    """Eine Verbindung zwischen zwei Blöcken."""

    von: str
    nach: str
    signal: str
    art: Kantenart = "signal"
    #: Vorzeichen, wenn der Zielblock summiert (Summierstelle oder Bilanz einer Strecke).
    vorzeichen: Literal["+", "-"] | None = None


@dataclass(frozen=True)
class Kreis:
    """Ein Regelkreis der Kaskade."""

    id: str
    name: str
    regelgroesse: str
    stellgroesse: str
    #: Der Block, der regelt.
    regler: str
    #: Das Messglied in der Rückführung.
    messglied: str | None
    takt_s: float
    #: `stetig` lässt sich im Frequenzbereich beurteilen, `zweipunkt` im Grenzzyklus,
    #: `hybrid` und `planung` gar nicht - dort ist die Frage eine andere.
    art: Literal["stetig", "zweipunkt", "hybrid", "planung"]
    erklaerung: tuple[str, ...] = field(default_factory=tuple)


# --------------------------------------------------------------------------------------------
# Ebene 4 - ökonomische Führung
# --------------------------------------------------------------------------------------------
_E4: tuple[Block, ...] = (
    Block(
        id="preis",
        ebene=4,
        rolle="stoergroesse",
        name="Strompreis",
        kurz="pel(t) · Tibber",
        behandlung="geplant",
        quelle="Tibber, Viertelstundenpreise, 24 bis 36 Stunden voraus",
        erklaerung=(
            "Die einzige Störgröße, die man kennt, bevor sie wirkt. Deshalb wird sie nicht "
            "ausgeregelt, sondern geplant - sie ist der Grund, warum über der Regelung überhaupt "
            "eine rechnende Ebene sitzt.",
            "Der Preis, mit dem gerechnet wird, ist nicht der Tarifpreis. Bei PV-Überschuss ist "
            "es die entgangene Einspeisevergütung, bei freier Batterie die Opportunität der "
            "späteren Entnahme, erst bei Netzbezug der Tarif. Drei Zahlen für dieselbe "
            "Kilowattstunde - und der Knick zwischen ihnen ist der Grund für ein MILP.",
            "Fehlen Preise länger als 30 Stunden, pausieren nur die Preisregeln. PV-Regel und "
            "Heizbetrieb laufen weiter; das ist eine Festlegung des Reglers und keine Notmaßnahme.",
        ),
        gleichungen=(
            "pel,eff = pTibber                bei Netzbezug",
            "pel,eff = 7,41 ct/kWh            bei PV-Überschuss (entgangene Vergütung)",
            "pel,eff = p̄abend · ηRT           wenn sonst die Batterie geladen hätte",
        ),
    ),
    Block(
        id="pv_ist",
        ebene=4,
        rolle="stoergroesse",
        name="PV-Erzeugung",
        kurz="PPV · myenergi",
        behandlung="aufgeschaltet",
        quelle="myenergi-Hub, Minutenwerte",
        erklaerung=(
            "Für die Regelung zählt nicht die Erzeugung, sondern der Überschuss: Einspeisung plus "
            "Batterieladung ab 80 % Ladestand plus die Leistung der laufenden Wärmepumpe. Der "
            "letzte Summand ist der wichtige - ohne ihn nimmt sich die Wärmepumpe den Überschuss "
            "selbst weg und schaltet sich ab.",
        ),
        gleichungen=("Psurplus = Pfeed + Pbat,chg|SOC>0,8 + PWP",),
    ),
    Block(
        id="speicher",
        ebene=4,
        rolle="stoergroesse",
        name="Hausbatterie",
        kurz="SOCbat · libbi",
        behandlung="aufgeschaltet",
        quelle="myenergi libbi, 5,1 kWh",
        erklaerung=(
            "Der Ladestand entscheidet, was eine Kilowattstunde PV-Strom gerade wert ist: die "
            "Einspeisevergütung oder den abendlichen Bezugspreis. Damit ist er kein Nebenwert, "
            "sondern ein Preisbildner.",
        ),
        gleichungen=("Opportunität der Ladung: p̄abend · ηRT,  ηRT = 0,90",),
    ),
    Block(
        id="pelletpreis",
        ebene=4,
        rolle="stoergroesse",
        name="Pelletpreis",
        kurz="ppell aus der letzten Lieferung",
        behandlung="aufgeschaltet",
        quelle="Konfiguration, aus der letzten Rechnung",
        erklaerung=(
            "Ändert sich selten und wirkt auf jede Zuordnungsentscheidung: er setzt die "
            "waagerechte Linie, gegen die die Grenzkosten der Wärmepumpe laufen.",
        ),
    ),
    Block(
        id="strahlung",
        ebene=4,
        rolle="stoergroesse",
        name="Globalstrahlung",
        kurz="G · Open-Meteo",
        behandlung="geplant",
        quelle="Open-Meteo, 48 h; Messung über die PV-Leistung",
        erklaerung=(
            "Zweifache Wirkung mit sehr verschiedenen Zeitkonstanten: auf dem Dach erzeugt sie in "
            "Minuten den Strom, der die Wärmepumpe billig macht, hinter den Fenstern heizt sie "
            "über Stunden die Räume. Beide Wege stehen getrennt im Bild, weil sie getrennt "
            "behandelt werden.",
        ),
        gleichungen=("Raumgewinn: Q̇sol = Aeff·g · G⊥",),
    ),
    Block(
        id="aussen",
        ebene=4,
        rolle="stoergroesse",
        name="Außentemperatur",
        kurz="Ta · Open-Meteo und eigener Fühler",
        behandlung="aufgeschaltet",
        quelle="Open-Meteo als Prognose, eigener Fühler als Messung",
        erklaerung=(
            "Die Störgröße mit der größten Wirkung, und sie wirkt an vier Stellen gleichzeitig: "
            "im Wärmebedarf über die Transmission, im COP-Kennfeld über die "
            "Verdampfungstemperatur, im Pufferverlust und direkt im Raum.",
            "Aufgeschaltet wird sie dort, wo sie vor der Wirkung bekannt ist: in der "
            "Heizkennlinie und im Fahrplan. Im Raum selbst bleibt ein Teil, der nur ausgeregelt "
            "wird - der Wind, den keine Prognose je Raum kennt.",
        ),
    ),
    Block(
        id="kosten_wp",
        ebene=4,
        rolle="rechenglied",
        name="Grenzkosten Wärmepumpe",
        kurz="cWP = pel,eff / COP",
        marke="COP",
        erklaerung=(
            "Rechnet die thermischen Grenzkosten im aktuellen Betriebspunkt. Beide Faktoren sind "
            "beweglich: der effektive Strompreis springt zwischen drei Fällen, die Arbeitszahl "
            "läuft mit Außen- und Vorlauftemperatur. Genau deshalb gibt es keine Antwort auf die "
            "Frage, ob die Wärmepumpe billiger ist als der Ofen - nur eine Antwort je Stunde.",
        ),
        gleichungen=("cWP = pel,eff / COP(Ta, TVL)",),
    ),
    Block(
        id="kosten_ofen",
        ebene=4,
        rolle="rechenglied",
        name="Grenzkosten Pelletofen",
        kurz="cOf = ppell /(Hu·η)",
        erklaerung=(
            "Fast konstant - und gerade das macht sie zur Vergleichslinie: sie sagt, ab welcher "
            "Arbeitszahl sich die Wärmepumpe nicht mehr lohnt.",
            "Startkosten und Mindestlaufzeit stehen daneben und nicht darin: ein Ofenstart kostet "
            "zehn Cent und bindet zwei Stunden. Im Fahrplan ist das eine Ganzzahlbedingung und "
            "keine Kostenzahl, die man mitteln könnte.",
        ),
        gleichungen=(
            "cOfen = ppell / (Hu · η)",
            "Hu = 4,9 kWh/kg · Startkosten 0,10 € · Mindestlaufzeit 120 min",
        ),
    ),
    Block(
        id="pv",
        ebene=4,
        rolle="modell",
        name="PV-Prognose",
        kurz="Ensemble mit Bias-Korrektur",
        erklaerung=(
            "Drei fremde Quellen und eine eigene Rechnung. Jede Quelle bekommt eine "
            "Bias-Korrektur je Sonnenstandsklasse und ein Gewicht aus ihrem inversen "
            "Fehlerquadrat der letzten vierzehn Tage.",
            "Eine Quelle, die ausfällt oder null liefert, bekommt automatisch Gewicht null - sie "
            "wird nicht ausgeschlossen, damit sie zurückkommen kann, wenn sie wieder liefert.",
        ),
        gleichungen=(
            "P̂ = Σs ws · k[s,b] · Ps",
            "k[s,b] ← EWMA(Ist/Prognose), HWZ 10 d, begrenzt auf [0,5 … 1,5]",
        ),
    ),
    Block(
        id="bedarf",
        ebene=4,
        rolle="modell",
        name="Wärmebedarf",
        kurz="Q̇ = H·ΔT − AG − Q̇int",
        erklaerung=(
            "Das Wärmemodell des Hauses als stationäre Bilanz. Es liefert die Last für den "
            "Fahrplan und die Störgrößenaufschaltung für den Pufferkreis.",
            "Keine der drei Größen ist gemessen. Deshalb steht neben jeder eine Unsicherheit, und "
            "deshalb prüft die Lernebene laufend, ob die Summe der Raumverluste zum "
            "Verlustkoeffizienten des Hauses passt. Wenn nicht, ist einer der Räume falsch "
            "vermessen - und das ist eine nützliche Auskunft.",
        ),
        gleichungen=(
            "Q̇bedarf = H·(Ti − Ta) − Aeff·G − Q̇int + Q̇WW",
            "Heizgrenze: Ta > Ta,grenze → 0",
        ),
    ),
    Block(
        id="komfort",
        ebene=4,
        rolle="rechenglied",
        name="Komfort und Nebenbedingungen",
        kurz="Ti ≥ wi − 0,5 K",
        erklaerung=(
            "Die harten Grenzen, innerhalb derer der Fahrplan frei ist: Raumsollwerte mit "
            "Zeitprofil, Mindesttemperatur oben im Puffer für Warmwasser, Nachtruhe des Ofens, "
            "Taktzahlgrenzen.",
            "Komfort ist hier eine Nebenbedingung und kein Term in der Zielfunktion. Eine "
            "Verletzung lässt sich nicht durch Ersparnis aufwiegen - sie macht den Fahrplan "
            "unzulässig. Das ist eine Entscheidung und keine Technik: eine gewichtete Summe "
            "hätte irgendwann einen Preis genannt, für den es im Bad kalt werden darf.",
        ),
        gleichungen=(
            "Ti(t) ≥ wi(t) − 0,5 K",
            "Tbuf,oben ≥ 42 °C   (comfort_min_top_c)",
            "StartsWP ≤ 8/d · StartsOfen ≤ 2/d",
        ),
    ),
    Block(
        id="fahrplan",
        ebene=4,
        rolle="regler",
        name="Ökonomischer Führungsregler",
        kurz="min Σ ck uk Δt  (MILP, 48 h / 15 min)",
        kreis="R4",
        erklaerung=(
            "Die äußerste Schleife, und die einzige, die rechnet statt zu regeln. Ergebnis ist "
            "keine Stellgröße, sondern eine Führungsgrößen-Trajektorie für den Pufferkreis und "
            "ein Fahrplan für den Ofen.",
            "Ganzzahlig muss es sein, weil der Ofen an oder aus ist, zwei Stunden mindestens "
            "läuft und ein Start Geld kostet - und weil Bezug, Einspeisung und "
            "Batterieopportunität drei verschiedene Preise für dieselbe Kilowattstunde sind. "
            "Beides sind Knicke, die kein stetiger Regler sauber abbildet.",
            "Alle fünfzehn Minuten wird neu gerechnet und nur das erste Intervall umgesetzt: "
            "gleitender Horizont. Dadurch wirkt jede Verbesserung der Prognose unmittelbar, ohne "
            "dass am Regler etwas verstellt wird.",
        ),
        gleichungen=(
            "min Σk [ pel(k)·PWP(k) + cOf·Q̇Of(k) + cstart·δ(k) ] Δt",
            "u. B. v. Ebuf(k+1) = Ebuf(k) + (Q̇zu − Q̇ab − Q̇loss)·Δt",
            "δ(k) ∈ {0,1}, Mindestlaufzeit 120 min, Ti ≥ wi − 0,5 K",
        ),
    ),
)

# --------------------------------------------------------------------------------------------
# Ebene 3 und 2 - Speicher und Erzeuger
# --------------------------------------------------------------------------------------------
_E3: tuple[Block, ...] = (
    Block(
        id="cop",
        ebene=3,
        rolle="modell",
        name="COP-Kennfeld",
        kurz="COP = a + b·Ta + c·TVL",
        marke="TVL",
        gibt_marke="COP",
        erklaerung=(
            "Die Verstärkung der Wärmepumpe, und damit die Verstärkung des ganzen Erzeugerpfads. "
            "Sie ist nicht konstant: zwischen einem milden und einem kalten Tag ändert sie sich "
            "um den Faktor zwei. Ein Regler mit fester Verstärkung wäre an einem der beiden Tage "
            "falsch ausgelegt - deshalb wird hier die Verstärkung geplant und nicht gemittelt.",
            "Die Form ist eine Ebene, weil sich ihre drei Zahlen lesen lassen: b sagt, was ein "
            "Grad draußen bringt, c, was ein Grad Vorlauf kostet. Sie gilt nur im vermessenen "
            "Bereich; außerhalb wird eingefroren statt extrapoliert.",
            "Geschätzt wird aus Zehn-Minuten-Fenstern im eingeschwungenen Heizbetrieb, ohne "
            "Anlauf, ohne Abtauung und ohne Heizstabminuten. Das ist die Arbeitszahl im "
            "Heizbetrieb, nicht die eines Tages.",
        ),
        gleichungen=(
            "COP = a + b·Ta + c·TVL",
            "KWP = Pel · COP   → Verstärkungsplanung des Pufferkreises",
        ),
    ),
    Block(
        id="abtauung",
        ebene=3,
        rolle="stoergroesse",
        name="Abtauzyklus",
        kurz="entzieht Wärme, verfälscht die Messung",
        behandlung="erkannt",
        quelle="erkannt am Vorlaufeinbruch bei laufendem Verdichter",
        erklaerung=(
            "Abtauzyklen entziehen dem Puffer Wärme und verfälschen jede COP-Messung. Die Minuten "
            "fallen aus der Kennlinienschätzung heraus - sonst lernt das Modell Abtauen als "
            "schlechten Wirkungsgrad und senkt die Arbeitszahl dauerhaft.",
        ),
    ),
    Block(
        id="warmwasser",
        ebene=3,
        rolle="stoergroesse",
        name="Warmwasserzapfung",
        kurz="stochastisch, nicht gemessen",
        behandlung="beobachtet",
        quelle="kein Wärmemengenzähler; aus dem Bilanzrest geschätzt",
        erklaerung=(
            "Die größte nicht gemessene Last der Anlage. Eine Zapfung zeigt sich nur als "
            "Temperatureinbruch der oberen Schichten.",
            "Behandelt wird sie zweistufig: der Beobachter schätzt den laufenden Abfluss aus der "
            "Bilanz, und das Tagesprofil geht als erwartete Last in den Fahrplan ein. Was dann "
            "noch übrig ist, wird ausgeregelt.",
        ),
        gleichungen=("Q̇ab = Q̇WP + Q̇Of − Ċbuf − Q̇loss   — als Rest der Bilanz",),
    ),
    Block(
        id="aufstellraum",
        ebene=3,
        rolle="stoergroesse",
        name="Aufstellraum des Puffers",
        kurz="Tu = 17 °C, unbeheizter Technikraum",
        behandlung="aufgeschaltet",
        quelle="Annahme, am Bilanzrest kalibriert",
        erklaerung=(
            "Der Pufferverlust ist keine verlorene Wärme: die Hälfte heizt den Aufstellraum und "
            "wird als nützlich gebucht. Die andere Hälfte geht in unbeheizte Bereiche.",
            "Die Temperatur ist eine Annahme und keine Messung, und das ist kein Detail: "
            "zwischen 21 °C Wohnraum und 17 °C Technikraum liegen bei 50 °C Puffer rund 14 % "
            "Verlust.",
        ),
        gleichungen=("Q̇loss = UA · (T̄buf − Tu),  davon nützlich: 50 %",),
    ),
    Block(
        id="puffer_regler",
        ebene=3,
        rolle="regler",
        name="Pufferlade-Regler",
        kurz="PI-Entwurf, Zweipunkt-Ausführung",
        kreis="R2",
        erklaerung=(
            "Der eigentliche Regelkreis der Wärmeerzeugung. Regelgröße ist der thermische "
            "Ladestand, Stellgröße die Anforderung an die Wärmepumpe - ein Kontakt, also ein "
            "Zweipunktglied.",
            "Entworfen wird dennoch stetig: der Puffer ist aus Sicht des Reglers ein Integrierer "
            "mit Totzeit, und für den gibt es eine geschlossene Einstellregel. Aus der stetigen "
            "Auslegung folgt dann die Hysteresebreite - über die Taktzahlgrenze von acht Starts "
            "am Tag. Die Breite wird also abgeleitet und nicht gewählt.",
            "Störgrößenaufschaltung: der prognostizierte Abfluss geht direkt auf die Stellgröße, "
            "damit der Integralanteil nicht erst nach dem Einbruch zu arbeiten beginnt.",
        ),
        gleichungen=(
            "Strecke: G(s) = k′/s · e^(−Tt s),  k′ = Pel·COP / Cbuf",
            "SIMC: KR = 1/(k′(λ+Tt)),  Tn = 4(λ+Tt)",
            "Hysterese: Δ = Tzyklus / (1/ṙauf + 1/ṙab)",
        ),
    ),
    Block(
        id="zuordnung",
        ebene=3,
        rolle="logik",
        name="Erzeuger-Zuordnung",
        kurz="Split-Range nach cWP ⋚ cOfen",
        kreis="R3",
        erklaerung=(
            "Zwei Erzeuger an einem Speicher, ein Sollwert - also eine Zuordnungsaufgabe. "
            "Entschieden wird nach Grenzkosten je Kilowattstunde Wärme und nicht nach "
            "Reihenfolge: billiger deckt die Grundlast, teurer die Spitze.",
            "Weil beide Quellen Mindestlauf- und Mindestausschaltzeiten haben, liegt um den "
            "Umschaltpunkt eine Totzone. Ohne sie würde ein wandernder Strompreis die Zuordnung "
            "mehrmals je Stunde kippen und beide Maschinen takten.",
        ),
        gleichungen=(
            "Wärmepumpe, wenn cWP < cOfen − d",
            "Umschaltpunkt: COP* = pel,eff / cOfen",
            "Totzone d = 1,5 ct/kWh, Mindesthaltezeit 60 min",
        ),
    ),
    Block(
        id="wp",
        ebene=2,
        rolle="stellglied",
        name="Wärmepumpe (Anforderung)",
        kurz="KWP e^(−Tt s)/(1+T1 s)",
        erklaerung=(
            "Das Stellglied ist nur ein potenzialfreier Kontakt: er sagt der Maschine, sie "
            "solle mehr Wärme erzeugen. Er trennt sie nicht und hält sie nicht an - offen heißt, die "
            "Wärmepumpe regelt selbst weiter. Was die Anforderung in ihr anhebt, ist nicht "
            "dokumentiert und "
            "wird aus den Schaltereignissen gemessen.",
            "Für den Kreis ist das ein Glied mit Totzeit und Anlauf. Die Totzeit ist die harte "
            "Grenze: sie begrenzt die erreichbare Durchtrittsfrequenz des Pufferkreises "
            "unabhängig davon, wie gut der Regler eingestellt ist.",
            "Jeder Schaltbefehl trägt den Hardware-Abschalttimer des Shelly. Fällt die Software "
            "aus, geht der Kontakt von selbst in den sicheren Zustand - ohne Mitwirkung der "
            "Software, und das ist der Punkt.",
        ),
        gleichungen=(
            "GWP(s) = Pel·COP · e^(−Tt s) / (1 + T1 s)",
            "Mindestlaufzeit 30 min · Mindestauszeit 20 min · höchstens 8 Starts/d",
            "Auto-Off der Hardware: 1800 s",
        ),
    ),
    Block(
        id="ofen",
        ebene=2,
        rolle="stellglied",
        name="Pelletofen (Stufe 1–5)",
        kurz="KOf e^(−Tt s)/(1+T1 s)",
        erklaerung=(
            "Die zweite Wärmequelle, in fünf Stufen stellbar, mit Zündvorgang. Die Zündung ist "
            "eine Totzeit von einer Viertelstunde und kostet Pellets und Zündstrom - deshalb "
            "gehört der Ofen in den Fahrplan und nicht in einen schnellen Kreis.",
            "Ein Fünftel seiner Leistung geht nicht ins Wasser, sondern direkt in den "
            "Aufstellraum. Dieser Anteil wird der Einzelraumregelung vorher mitgeteilt, statt "
            "hinterher weggeregelt zu werden.",
        ),
        gleichungen=(
            "Q̇Wasser(Stufe) linear zwischen 1,8 und 10,0 kW",
            "Q̇Brennstoff = ṁ · Hu,  Hu = 4,9 kWh/kg",
            "Mindestlaufzeit 120 min · Startkosten 0,10 € · Zündspitze 390 W",
        ),
    ),
    Block(
        id="puffer",
        ebene=3,
        rolle="strecke",
        name="Pufferspeicher, 1000 l, vier Schichten",
        kurz="1/(Cbuf s + UA) · (1+Ts s)^−4",
        erklaerung=(
            "Das dämpfende Glied der ganzen Anlage: zwei Erzeuger, zwei Entnahmen, vier Fühler. "
            "Er entkoppelt Erzeugung und Verbrauch zeitlich und macht aus einer "
            "Augenblicksentscheidung eine Energieentscheidung.",
            "Regelungstechnisch ist er zweierlei zugleich. Über die mittlere Temperatur ein "
            "Integrierer - die Verlustzeitkonstante C/UA liegt bei rund zweihundert Stunden und "
            "ist gegen den Betrieb unendlich. Über die Schichtung eine Kette von vier Gliedern, "
            "die eine Temperaturfront mit Laufzeit durchwandert. Beides steht im Modell, weil der "
            "Regler die obere Schicht sieht, aber die Energie meint.",
            "Die Energie misst niemand. Sie wird aus vier Temperaturen rekonstruiert, und jeder "
            "Fehler der Erzeugerseite landet im Rest der Bilanz - ausgewiesen als Restglied und "
            "nicht versteckt in einer negativen Entnahme.",
        ),
        gleichungen=(
            "Cbuf dT̄/dt = Q̇zu − Q̇ab − UA(T̄ − Tu)",
            "Cbuf = 1000 l · 4,186 kJ/(kg·K) = 1,163 kWh/K",
            "Schichtung: Gstrat(s) = (1 + Ts s)^−4",
        ),
    ),
    Block(
        id="beobachter",
        ebene=3,
        rolle="beobachter",
        name="Beobachter: Ladestand und Abfluss",
        kurz="Kalman über T1…T4",
        erklaerung=(
            "Das Haus hat keinen Wärmemengenzähler. Der Beobachter rekonstruiert aus vier "
            "Schichttemperaturen, der elektrischen Leistung und dem Ofenzustand zwei Größen, die "
            "niemand messen kann: den thermischen Ladestand und den laufenden Abfluss.",
            "Ein Filter und keine Formel, weil die Fühler rauschen: 1000 Liter sind 1,16 kWh je "
            "Kelvin, über eine Minute abgeleitet entspricht ein Kelvin fast 70 kW. Ein Fühler, "
            "der um 0,1 K zappelt, erzeugt daraus 1,7 kW aus dem Nichts. Der Filter hält die "
            "Modellgleichung gegen die Messung und gewichtet beide mit ihrer Unsicherheit.",
            "Derselbe Filter liefert die Unsicherheit mit, die auf der Karte neben den Parametern "
            "steht.",
        ),
        gleichungen=(
            "x̂ = [T1..4, Q̇ab]ᵀ",
            "x̂k+1 = A x̂k + B uk + K(yk − C x̂k)",
            "SOCth = (Eist − Emin)/(Emax − Emin)",
        ),
    ),
)

# --------------------------------------------------------------------------------------------
# Ebene 1 - Vorlauftemperatur und Verteilung
# --------------------------------------------------------------------------------------------
_E1: tuple[Block, ...] = (
    Block(
        id="kennlinie",
        ebene=1,
        rolle="vorsteuerung",
        name="Heizkennlinie",
        kurz="TVL* = wi + s·(wi − Ta)",
        erklaerung=(
            "Die klassische Störgrößenaufschaltung der Heiztechnik: sie setzt die "
            "Vorlauftemperatur aus der Außentemperatur, bevor der Raum etwas davon merkt. Eine "
            "Vorsteuerung ohne Rückführung - sie kann nichts ausregeln, aber sie nimmt dem "
            "Raumkreis die halbe Arbeit ab.",
            "Zu steil eingestellt heißt: dauerhaft zu warmer Vorlauf, also jeden Tag ein "
            "kleinerer COP, obwohl die Räume stimmen. Das sieht man nicht an der Raumtemperatur, "
            "sondern nur an den Ventilhüben - wenn alle Räume drosseln, ist die Kennlinie zu "
            "hoch. Genau daraus wird die Steilheit zurückgerechnet.",
        ),
        gleichungen=(
            "TVL* = wi + s · (wi − Ta)^1,1",
            "Heizgrenze Ta > Ta,grenze → Kreis aus",
            "Lernregel: s ← s − γ·(1 − maxi hi)",
        ),
    ),
    Block(
        id="leitventil",
        ebene=1,
        rolle="logik",
        name="Leitventil-Logik",
        kurz="ΔTVL = −k·(1 − maxi hi)",
        erklaerung=(
            "Die Gegenkopplung zur Heizkennlinie: der Raum mit dem größten Bedarf bestimmt, wie "
            "weit der Vorlauf abgesenkt werden darf. Solange kein Ventil voll offen ist, ist der "
            "Vorlauf höher als nötig.",
            "Das senkt die Vorlauftemperatur so weit wie möglich und hebt damit den COP - und "
            "schließt damit den Kreis zur Erzeugerebene, denn jedes Grad Vorlauf kostet dort "
            "Arbeitszahl. Die unterste Ebene greift so in die Verstärkung der obersten ein.",
        ),
        gleichungen=(
            "ΔTVL = −k · (1 − maxi hi),  k = 8 K",
            "Begrenzung: TVL ≥ 26 °C, Änderung ≤ 2 K/h",
        ),
    ),
    Block(
        id="vl_regler",
        ebene=1,
        rolle="regler",
        name="Mischer-Regler",
        kurz="PI, Stellgrenze 0–100 %",
        kreis="R1",
        erklaerung=(
            "Der schnellste Kreis der Anlage: Mischer gegen Vorlauffühler, Zeitkonstanten in "
            "Minuten. Er ist dem Pufferkreis unterlagert, und das ist der Zweck der Kaskade - "
            "die schnelle Störung (Pufferschichtung, Pumpenstufe, Zapfung) wird hier ausgeregelt "
            "und erreicht die langsamen Kreise nicht mehr.",
            "Weil er zehnmal schneller ist als der Kreis über ihm, darf er unabhängig ausgelegt "
            "werden. Die Faustregel der Kaskade, Faktor fünf zwischen den Ebenen, ist hier mit "
            "Abstand erfüllt.",
        ),
        gleichungen=(
            "Strecke: KVL e^(−Tt s)/(1+T1 s)",
            "SIMC: KR = T1/(K(λ+Tt)),  Tn = min(T1, 4(λ+Tt))",
        ),
    ),
    Block(
        id="heizkreis",
        ebene=1,
        rolle="strecke",
        name="Mischer, Pumpe, Verteiler",
        kurz="KVL e^(−Tt s)/(1+T1 s)",
        gibt_marke="TVL",
        erklaerung=(
            "Mischer, Pumpe, Verteiler und der Wasserinhalt der Leitungen. Die Verstärkung ist "
            "über den Hub nichtlinear - ein Dreiwegeventil regelt in der Mitte anders als am "
            "Rand; geschätzt wird die Steigung im Arbeitsbereich.",
            "Die Transportzeit vom Mischer zum Fühler ist reine Totzeit und setzt die Obergrenze "
            "der Kreisverstärkung: mehr als etwa sechzig Grad Phasenreserve lassen sich bei zwei "
            "Minuten Laufzeit nicht gleichzeitig mit kurzer Ausregelzeit haben.",
            "Derselbe Block liefert die Last des Puffers: was durch die Heizkreise fließt, fehlt "
            "oben im Speicher.",
        ),
        gleichungen=(
            "GVL(s) = KVL e^(−Tt s) / (1 + T1 s)",
            "Q̇HK = ṁ·cw·(TVL − TRL)   — die Last des Puffers",
        ),
    ),
    Block(
        id="vl_fuehler",
        ebene=1,
        rolle="messglied",
        name="Vorlauffühler",
        kurz="PT1000, Tfilter = 30 s",
        quelle="eigener Fühler am Verteiler",
        erklaerung=(
            "Ein Messglied ist auch ein Übertragungsglied. Dreißig Sekunden Filterzeit sind im "
            "schnellsten Kreis nicht vernachlässigbar: sie kommen zur Totzeit hinzu und gehören "
            "in die Auslegung, statt hinterher als unerklärtes Schwingen aufzufallen.",
        ),
        gleichungen=(
            "Gm(s) = 1/(1 + 30 s · s)",
            "Ausfall: stale > 900 s → Kreis fährt auf Vorsteuerung",
        ),
    ),
)

# --------------------------------------------------------------------------------------------
# Ebene 0 - Einzelraumregelung
# --------------------------------------------------------------------------------------------
_E0: tuple[Block, ...] = (
    Block(
        id="intern",
        ebene=0,
        rolle="stoergroesse",
        name="Interne Gewinne",
        kurz="Personen, Geräte, Kochen",
        behandlung="aufgeschaltet",
        quelle="Tagesprofil, aus der Bilanz geschätzt",
        erklaerung=(
            "Nicht messbar, aber stark: 0,6 kW im Mittel verschieben die Heizgrenze um gut zwei "
            "Kelvin. Wird als Tagesprofil je Wochentag geschätzt und im Bedarfsmodell "
            "mitgeführt.",
        ),
    ),
    Block(
        id="fenster",
        ebene=0,
        rolle="stoergroesse",
        name="Fensterlüftung",
        kurz="sprunghaft, erkannt am Gradienten",
        behandlung="erkannt",
        quelle="Fensterkontakt und Temperaturgradient",
        erklaerung=(
            "Ein geöffnetes Fenster ist ein Sprung, keine Drift. Der Einzelraumregler darf darauf "
            "nicht mit dem Integralanteil antworten, sonst heizt er nach dem Schließen "
            "stundenlang nach - bei einem Estrich von fünf Stunden Zeitkonstante wirklich "
            "stundenlang.",
            "Erkannt wird es am Gradienten der Raumluft und am Fensterkontakt; der Integrator "
            "wird dann angehalten und der Hub eingefroren.",
        ),
        gleichungen=("dTi/dt < −1,5 K/h ∧ Ventil offen → Integrator halten",),
    ),
    Block(
        id="raum_regler",
        ebene=0,
        rolle="regler",
        name="Einzelraum-Regler",
        kurz="PI, Hub 0–100 %",
        kreis="R0",
        erklaerung=(
            "Zehn gleichartige Kreise, jeder mit eigenen Parametern. Regelgröße ist die "
            "Raumluft, Stellgröße der Ventilhub, und zwischen beiden liegt der Estrich: eine "
            "Zeitkonstante von Stunden plus zwanzig Minuten Totzeit.",
            "Das ist der langsamste Kreis des Hauses, und er muss langsam bleiben. Ein "
            "Raumregler, der auf eine halbe Stunde reagieren will, pumpt die Fußbodenheizung in "
            "Schwingungen, die zwei Stunden später ankommen. Die Nachstellzeit liegt deshalb bei "
            "Stunden, nicht Minuten - und das ist kein Zugeständnis, sondern das Ergebnis der "
            "Entwurfsregel.",
            "Zwei Besonderheiten: der Integrator wird bei erkanntem Lüften angehalten, und die "
            "erwartete Raumwärme des Ofens wird aufgeschaltet, statt sie nachträglich "
            "wegzuregeln.",
        ),
        gleichungen=(
            "Halbregel: T1′ = T1 + T2/2,  Tt′ = Tt + T2/2",
            "SIMC: KR = T1′/(K(λ+Tt′)),  Tn = min(T1′, 4(λ+Tt′))",
            "Hub 0–100 %, Anti-Windup durch Rückrechnung",
        ),
    ),
    Block(
        id="ventil",
        ebene=0,
        rolle="stellglied",
        name="Stellantrieb am Verteiler",
        kurz="stufenlos, Tstell",
        erklaerung=(
            "Stufenloser Motorantrieb am Heizkreisverteiler. Entscheidend ist nicht die "
            "Stellzeit, sondern die Autorität: liegt nur ein Drittel des Druckverlusts am "
            "Ventil, bewirkt der halbe Hub fast den vollen Durchfluss.",
            "Diese Kennlinie wird aus Hub und Rücklauftemperatur geschätzt und als "
            "Vorverzerrung herausgerechnet, damit der Raumregler eine lineare Strecke sieht. "
            "Ohne das wäre die Verstärkung des Kreises bei halbem Hub eine andere als bei "
            "kleinem - und eine Reglereinstellung für beide gibt es nicht.",
        ),
        gleichungen=(
            "ṁ/ṁmax = h / √(av + (1−av)h²)",
            "Linearisierung: h* = f⁻¹(Anforderung)",
        ),
    ),
    Block(
        id="raum",
        ebene=0,
        rolle="strecke",
        name="Raummodell, zwei Knoten",
        kurz="C ẋ = −(G+H)x + Q̇ + z",
        erklaerung=(
            "Zwei Knoten: die Raumluft mit Einrichtung, schnell, und der Estrich, langsam. "
            "Dazwischen ein Übergangswiderstand, der von Bodenbelag und Rohrabstand abhängt. "
            "Genau dieser Aufbau macht die Fußbodenheizung träge und gleichzeitig gutmütig.",
            "Die Angriffspunkte der Störgrößen sind verschieden, und das ist für die Regelung "
            "wesentlich: die Sonne wirkt auf die Luft (Minuten), die Außentemperatur auf die "
            "Hülle (Stunden), die Heizung auf den Estrich (viele Stunden). Ein einziger "
            "Zeitkonstanten-Begriff wäre hier falsch.",
            "Die Estrichtemperatur wird nicht gemessen. Zustand und Parameter werden deshalb "
            "gemeinsam geschätzt - und die Summe der Raumverluste muss zum Verlustkoeffizienten "
            "des Hauses passen, was eine laufende Prüfung gegen Messfehler ist.",
        ),
        gleichungen=(
            "CL Ṫi = (TE−Ti)/RE→L − HRaum(Ti−Ta) + Aeff·G + Q̇int + Q̇Ofen,Raum",
            "CE ṪE = Q̇HK(h, TVL) − (TE−Ti)/RE→L",
            "T1 = CE·RE→L,  T2 = CL/(1/RE→L + HRaum)",
        ),
    ),
    Block(
        id="raum_fuehler",
        ebene=0,
        rolle="messglied",
        name="Raumfühler",
        kurz="Ti, Minutenwerte",
        quelle="Einzelraumregelung über die Brücke",
        erklaerung=(
            "Die Platzierung ist Teil des Modells: ein Fühler in der Sonne misst die Sonne und "
            "nicht den Raum. Erkennbar ist das am Vergleich mit dem Estrichzustand des "
            "Beobachters - weicht der Fühler systematisch nur bei Einstrahlung ab, ist nicht der "
            "Raum warm, sondern der Fühler beleuchtet.",
        ),
        gleichungen=("Plausibilität: |Ti − T̂i| > 1,5 K ∧ G > 300 W/m² → Fühler verdächtig",),
    ),
    Block(
        id="weitere_raeume",
        ebene=0,
        rolle="teilkreise",
        name="Neun weitere Räume",
        kurz="je eigener Kreis R0, eigene Parameter",
        erklaerung=(
            "Derselbe Kreisaufbau, eigene Parametersätze: jeder Raum hat seine Kapazität, seinen "
            "Verlust und seine solare Apertur, also auch seine eigene Reglereinstellung.",
            "Die Lernebene schätzt sie getrennt, prüft aber eine Kopplung: die Summe der "
            "Raumverluste muss zum Verlustkoeffizienten des Hauses passen. Tut sie es nicht, ist "
            "einer der Räume falsch vermessen - und das steht dann als Hinweis im Protokoll und "
            "nicht in einem stillen Mittelwert.",
        ),
        gleichungen=("Σi HRaum,i ≈ HHaus   (Prüfung, Toleranz 15 %)",),
    ),
)

_SUMMEN: tuple[Block, ...] = (
    Block(
        id="summe_soc",
        ebene=3,
        rolle="summierstelle",
        name="Regelabweichung Ladestand",
        kurz="e = wSOC − SOCth",
    ),
    Block(
        id="summe_waerme",
        ebene=3,
        rolle="summierstelle",
        name="Wärmezufluss",
        kurz="Q̇zu = Q̇WP + Q̇Ofen",
    ),
    Block(
        id="summe_vl",
        ebene=1,
        rolle="summierstelle",
        name="Regelabweichung Vorlauf",
        kurz="e = TVL,soll − TVL",
    ),
    Block(
        id="summe_raum",
        ebene=0,
        rolle="summierstelle",
        name="Regelabweichung Raum",
        kurz="e = wi − Ti",
    ),
)

BLOECKE: tuple[Block, ...] = (*_E4, *_E3, *_E1, *_E0, *_SUMMEN)

KANTEN: tuple[Kante, ...] = (
    # Ebene 4
    Kante("preis", "kosten_wp", "pel(t)", "stoergroesse"),
    Kante("pv_ist", "kosten_wp", "PPV", "stoergroesse"),
    Kante("speicher", "kosten_wp", "SOCbat", "stoergroesse"),
    Kante("pelletpreis", "kosten_ofen", "ppell", "stoergroesse"),
    Kante("aussen", "bedarf", "Ta", "stoergroesse"),
    Kante("aussen", "cop", "Ta", "stoergroesse"),
    Kante("strahlung", "pv", "G", "stoergroesse"),
    Kante("pv", "bedarf", "G korrigiert"),
    Kante("pv", "fahrplan", "P̂PV(t)"),
    Kante("kosten_wp", "fahrplan", "cWP"),
    Kante("kosten_ofen", "fahrplan", "cOfen"),
    Kante("kosten_wp", "zuordnung", "cWP"),
    Kante("kosten_ofen", "zuordnung", "cOfen"),
    Kante("bedarf", "fahrplan", "Q̇̂(t)"),
    Kante("bedarf", "puffer_regler", "Vorsteuerung Q̇ab"),
    Kante("komfort", "fahrplan", "wi, Grenzen"),
    # Führungsgrößen
    Kante("fahrplan", "summe_soc", "wSOC(t)", "fuehrung", "+"),
    Kante("fahrplan", "zuordnung", "Fahrplan Ofen", "fuehrung"),
    Kante("fahrplan", "kennlinie", "Niveau, wi", "fuehrung"),
    Kante("fahrplan", "summe_raum", "wi(t)", "fuehrung", "+"),
    # Ebene 3 und 2
    Kante("summe_soc", "puffer_regler", "e"),
    Kante("puffer_regler", "zuordnung", "u"),
    Kante("cop", "kosten_wp", "COP", "parameter"),
    Kante("cop", "wp", "KWP = Pel·COP", "parameter"),
    Kante("abtauung", "wp", "Abtauung", "stoergroesse"),
    Kante("zuordnung", "wp", "Anforderung"),
    Kante("zuordnung", "ofen", "Stufe"),
    Kante("wp", "summe_waerme", "Q̇WP", "signal", "+"),
    Kante("ofen", "summe_waerme", "Q̇Ofen", "signal", "+"),
    Kante("summe_waerme", "puffer", "Q̇zu"),
    Kante("warmwasser", "puffer", "Q̇WW", "stoergroesse", "-"),
    Kante("aufstellraum", "puffer", "Tu", "stoergroesse", "-"),
    Kante("heizkreis", "puffer", "Q̇HK (Entnahme)", "signal", "-"),
    Kante("puffer", "beobachter", "T1…T4"),
    Kante("beobachter", "summe_soc", "SOCth, Q̇̂ab", "rueckfuehrung", "-"),
    # Ebene 1
    Kante("aussen", "kennlinie", "Ta", "stoergroesse"),
    Kante("kennlinie", "leitventil", "TVL*"),
    Kante("leitventil", "summe_vl", "TVL,soll", "signal", "+"),
    Kante("summe_vl", "vl_regler", "e"),
    Kante("vl_regler", "heizkreis", "Mischerstellung"),
    Kante("heizkreis", "vl_fuehler", "TVL"),
    Kante("vl_fuehler", "summe_vl", "TVL gemessen", "rueckfuehrung", "-"),
    Kante("heizkreis", "cop", "TVL", "parameter"),
    Kante("heizkreis", "ventil", "TVL"),
    Kante("heizkreis", "weitere_raeume", "TVL, wi", "fuehrung"),
    # Ebene 0
    Kante("summe_raum", "raum_regler", "e"),
    Kante("raum_regler", "ventil", "Hub hi"),
    Kante("raum_regler", "leitventil", "hi", "rueckfuehrung"),
    Kante("weitere_raeume", "leitventil", "hi (9 ×)", "rueckfuehrung"),
    Kante("ventil", "raum", "Q̇Raum"),
    Kante("aussen", "raum", "Ta", "stoergroesse", "-"),
    Kante("strahlung", "raum", "Aeff·G", "stoergroesse", "+"),
    Kante("intern", "raum", "Q̇int", "stoergroesse", "+"),
    Kante("fenster", "raum", "Lüftung", "stoergroesse", "-"),
    Kante("ofen", "raum", "Q̇Ofen,Raum", "stoergroesse", "+"),
    Kante("raum", "raum_fuehler", "Ti"),
    Kante("raum_fuehler", "summe_raum", "Ti gemessen", "rueckfuehrung", "-"),
)

KREISE: tuple[Kreis, ...] = (
    Kreis(
        id="R0",
        name="Einzelraum",
        regelgroesse="Raumlufttemperatur",
        stellgroesse="Ventilhub in %",
        regler="raum_regler",
        messglied="raum_fuehler",
        takt_s=60.0,
        art="stetig",
        erklaerung=(
            "Der langsamste Kreis, weil der Estrich zwischen Stellgröße und Regelgröße liegt. "
            "Zwei Zeitkonstanten, Totzeit, und eine Verstärkung, die von der Ventilautorität "
            "abhängt.",
        ),
    ),
    Kreis(
        id="R1",
        name="Vorlauftemperatur",
        regelgroesse="Vorlauftemperatur",
        stellgroesse="Mischerstellung in %",
        regler="vl_regler",
        messglied="vl_fuehler",
        takt_s=10.0,
        art="stetig",
        erklaerung=(
            "Der schnellste Kreis und der innere Kreis der Kaskade. Hält die schnellen Störungen "
            "von den langsamen Kreisen fern.",
        ),
    ),
    Kreis(
        id="R2",
        name="Pufferladung",
        regelgroesse="Thermischer Ladestand",
        stellgroesse="Anforderung (Kontakt)",
        regler="puffer_regler",
        messglied="beobachter",
        takt_s=10.0,
        art="zweipunkt",
        erklaerung=(
            "Stetig entworfen, als Zweipunktregler ausgeführt. Die Hysteresebreite folgt aus der "
            "Taktzahlgrenze und den gelernten Steigungen - sie wird gerechnet, nicht gewählt.",
        ),
    ),
    Kreis(
        id="R3",
        name="Erzeugerwahl",
        regelgroesse="Zuordnung der Wärmeanforderung",
        stellgroesse="Anforderung und Ofenstufe",
        regler="zuordnung",
        messglied=None,
        takt_s=600.0,
        art="hybrid",
        erklaerung=(
            "Keine Frequenzkennlinie: die Stellgröße ist eine Entscheidung zwischen zwei "
            "Maschinen mit Mindestzeiten. Beurteilt wird sie am Umschaltpunkt und an der "
            "Totzone, nicht an einer Phasenreserve.",
        ),
    ),
    Kreis(
        id="R4",
        name="Ökonomische Führung",
        regelgroesse="Kosten über 48 Stunden",
        stellgroesse="Führungsgrößen der unteren Kreise",
        regler="fahrplan",
        messglied=None,
        takt_s=900.0,
        art="planung",
        erklaerung=(
            "Ein gleitender Horizont und kein Kreis im Sinne der Frequenzbereichsanalyse. "
            "Beurteilt wird er an der Nachbetrachtung in Euro, nicht an einer Reserve.",
        ),
    ),
)

NACH_ID: Mapping[str, Block] = {b.id: b for b in BLOECKE}
KREIS_NACH_ID: Mapping[str, Kreis] = {k.id: k for k in KREISE}


def stoergroessen() -> tuple[Block, ...]:
    """Alle Störgrößen, in der Reihenfolge der Ebenen."""
    return tuple(b for b in BLOECKE if b.rolle == "stoergroesse")


def pruefe_struktur() -> None:
    """Die Karte gegen sich selbst prüfen. Was hier auffliegt, ist ein Fehler im Register.

    Geprüft wird, was beim Zeichnen oder Rechnen sonst still schiefgeht: doppelte Kennungen, Kanten
    ins Leere, Parameter an Blöcken, die es nicht gibt, Regler ohne Kreis und Kreise ohne Regler.
    """
    kennungen = [b.id for b in BLOECKE]
    doppelt = {k for k in kennungen if kennungen.count(k) > 1}
    if doppelt:
        raise ValueError(f"doppelte Blockkennungen: {sorted(doppelt)}")
    for k in KANTEN:
        if k.von not in NACH_ID:
            raise ValueError(f"Kante von unbekanntem Block: {k.von}")
        if k.nach not in NACH_ID:
            raise ValueError(f"Kante zu unbekanntem Block: {k.nach}")
        ziel = NACH_ID[k.nach]
        # Ein Vorzeichen gehört an eine Summierstelle - oder an eine Strecke, deren eigene
        # Bilanzgleichung die Summe bildet. Der Puffer ist dieser Fall: Zufluss, zwei Entnahmen
        # und der Verlust treffen sich in ihm und nicht in einem Kreis davor.
        if k.vorzeichen is not None and ziel.rolle not in ("summierstelle", "strecke"):
            raise ValueError(f"Vorzeichen an {k.nach}, das nicht summiert")
    for pid, p in PARAMETER.items():
        if p.block not in NACH_ID:
            raise ValueError(f"Parameter {pid} hängt an unbekanntem Block {p.block}")
    for kreis in KREISE:
        if kreis.regler not in NACH_ID:
            raise ValueError(f"Kreis {kreis.id}: Regler {kreis.regler} fehlt")
        if NACH_ID[kreis.regler].kreis != kreis.id:
            raise ValueError(f"Kreis {kreis.id}: {kreis.regler} nennt ihn nicht")
        if kreis.messglied is not None and kreis.messglied not in NACH_ID:
            raise ValueError(f"Kreis {kreis.id}: Messglied {kreis.messglied} fehlt")
    for b in BLOECKE:
        if b.kreis is not None and b.kreis not in KREIS_NACH_ID:
            raise ValueError(f"Block {b.id} nennt unbekannten Kreis {b.kreis}")
        if b.rolle == "stoergroesse" and b.behandlung is None:
            raise ValueError(f"Störgröße {b.id} ohne Behandlung")
    for kreis_id, pid in LAMBDA_JE_KREIS.items():
        if kreis_id not in KREIS_NACH_ID:
            raise ValueError(f"λ für unbekannten Kreis {kreis_id}")
        if pid not in PARAMETER:
            raise ValueError(f"λ-Parameter {pid} fehlt im Register")
    ohne_platz = {p.block for p in PARAMETER.values()} - {b.id for b in BLOECKE}
    if ohne_platz:
        raise ValueError(f"Parameter ohne Block: {sorted(ohne_platz)}")
