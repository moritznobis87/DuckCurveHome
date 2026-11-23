"""Ein Fühler, der redet und nichts mehr sagt: derselbe Wert, Minute für Minute.

**Der Anlass.** Die Güte eines Messwerts prüfte bis zum 22.11.2026 ausschließlich den
Zeitstempel (`Measurement.aged` vergleicht `now - observed_at`), nie den Wert. Ausgeführt am
Prüfstand: sechs Stunden im Minutentakt mit festsitzendem `buffer_temp_top_c` - alle vier Fühler
bleiben `ok` und `usable`, der Ladezustand wird gerechnet, die Wandanzeige zeigt eine satte Säule.
Ein toter, aber plappernder Fühler erzeugt genau dasselbe Bild wie ein gesunder. Das Foto vom
22.11.2026 (`40°, 40°, 40°, 39°`, daneben „PUFFER 18 % kalt") beweist keinen Fühlerfehler - es
beweist, dass die Anlage einen dieser Art nicht bemerken könnte.

**Warum nur die Puffertemperaturen.** Eine allgemeine Regel („ein Wert, der sich über N Minuten um
exakt 0,000 nicht bewegt") wäre mächtig und falsch: ein geschlossenes Ventil steht auf 0, eine
Wallbox ohne Auto steht auf 0 kW, ein Raumfühler mit halbem Grad Auflösung steht stundenlang auf
derselben Zahl. Jede dieser Größen bräuchte ihre eigene Begründung, und bis die dasteht, ist eine
Regel über alle Werte eine Quelle von Fehlalarmen - und ein Fehlalarm nimmt der nächsten echten
Meldung den Glauben. Die vier Pufferfühler sind der eine Fall, in dem die Begründung schon da ist
(unten), und zugleich der, an dem am meisten hängt: Ladezustand, Freigabe der Wärmepumpe,
Ofenfahrplan.

**Die Schwelle kommt aus dem Haus, nicht aus dem Gefühl.** Gefragt ist die kleinste Änderung, die
ein lebender Fühler zeigen *muss*, und die Zeit, in der er sie zeigen muss.

* Die kleinste Änderung ist die Auflösung der Fühler: 0,1 K (DS18B20 am Shelly-Temperatur-Add-on;
  die Rohwerte aus dem Vollstand des Geräts haben eine Dezimale, 54,6 / 53,4 / 46,6 / 34,5 °C).
* Die Zeit folgt aus dem langsamsten Vorgang, den der Speicher kennt: Abkühlen ohne Entnahme.
  `loss_kw_per_k · (T - ambient)` gegen die Wärmekapazität `volume_liters · 4,186/3600` ergibt bei
  der Voreinstellung (1000 l, 0,004 kW/K, 17 °C Technikraum) 0,079 K/h bei 40 °C - 0,1 K in
  76 Minuten. Bei 62 °C sind es 39 Minuten, bei 36 °C 92.
* Unter Entnahme ist es ein Vielfaches davon: 4,4 kW aus 1000 l sind 0,063 K/min, also 0,94 K je
  Viertelstunde. Diese Zahl taugt aber nicht als Schwelle, weil die Wärmepumpe pausieren darf -
  die Rechnung oben hält auch bei stehender Anlage.

Mit Sicherheitsfaktor 2 auf die gerechnete Standzeit wird daraus die Frist, nach der ein
unveränderter Wert ein Befund ist: 152 Minuten bei 40 °C. Nach unten bei einer Stunde, damit eine
Konfiguration mit großem Verlustterm nicht Minutenfristen erzeugt, die der Dienst mit seinen
eigenen Lücken selbst füllen könnte.

**Die Obergrenze gilt nur für einen Speicher, aus dem auch entnommen wird.** Sechs Stunden sind
die Frist, nach der in diesem Haus allein das Warmwasser jede echte Temperatur mehrere Stellen
bewegt hätte (ruhigstes Sechsstundenfenster des Profils, 23 bis 5 Uhr, 0,37 kWh = 0,32 K, plus
0,48 K Stillstandsverlust bei 40 °C). Dieses Argument hängt an der Entnahme, und die gibt es
unterhalb von `min_useful_temperature_c` nicht: ein Speicher, der keine nutzbare Wärme mehr
enthält, wird nicht angefahren. Deshalb deckelt die Grenze nur oberhalb dieser Temperatur.

Nachgerechnet am Prüfstand (ruhender Speicher, exakte Abkühlung, Anzeige auf eine Dezimale), und
das war der Anlass für diesen Absatz: mit einer Deckelung über alle Temperaturen meldet ein völlig
gesunder Speicher bei 22 °C nach sechs Stunden einen Alarm, weil er dort 370 Minuten auf derselben
Stelle steht - die Deckelung lag unter der Physik, auf die sie sich beruft. Ein Pufferboden bei
18 bis 22 °C ist im Sommer ohne Heizung kein Sonderfall, und `severity="alarm"` belegt den einen
Platz des Ruhebilds.

**Wo die Physik nichts sagt, sagt die Prüfung nichts.** Ist der Speicher nicht wärmer als sein
Aufstellraum, kühlt er nicht ab; dann gibt es keine Mindeständerung, die ein lebender Fühler
zeigen müsste, und damit keinen Befund. Ein dort eingefrorener Fühler bleibt unsichtbar - das ist
die ehrliche Auskunft und keine Lücke, die sich mit einer geratenen Frist schließen ließe. Es
hängt auch nichts daran: unterhalb der nutzbaren Temperatur ist der Ladezustand null, egal welche
Zahl der Fühler meldet.

**Gemeldet wird nur, was auch gemeldet wurde.** Zwei gleiche Werte drei Stunden auseinander sind
kein stehender Fühler, sondern eine Lücke - und die ist Sache von `silence`. Ein Befund braucht
deshalb mindestens `MELDUNGEN_MIND` Meldungen desselben Werts; bei dreißig Sekunden Takt (MQTT)
oder einer Minute (Home Assistant) ist das nach fünf bis zehn Minuten erfüllt.

Reine Rechnung, kein I/O.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime

from hems_core.domain.config import BufferConfig
from hems_core.thermal.buffer_soc import KWH_PER_LITER_KELVIN, ORTE_DE
from hems_core.watch.silence import Severity, silence_text

#: Auflösung der Pufferfühler in Kelvin - die kleinste Änderung, die überhaupt sichtbar wird.
AUFLOESUNG_K = 0.1
#: Sicherheitsfaktor auf die gerechnete Standzeit. Zwei, nicht eins: die Annahmen über
#: Verlustterm und Aufstellraum sind Schätzungen (siehe `BufferConfig.ambient_c`), und ein
#: Fehlalarm kostet mehr als eine halbe Stunde spätere Meldung.
SICHERHEIT = 2.0
#: Obergrenze der Frist - aber nur für einen Speicher oberhalb von `min_useful_temperature_c`,
#: weil ihr Argument die Warmwasserentnahme ist. Die Begründung steht im Modulkopf.
HOECHSTENS_MIN = 360.0
MINDESTENS_MIN = 60.0
#: So oft muss derselbe Wert gemeldet worden sein, bevor er als eingefroren gilt.
MELDUNGEN_MIND = 10

#: Die vier Schlüssel der Säule, von oben nach unten - dieselbe Reihenfolge wie in der Regel
#: `buffer` des Wächters und wie `BufferTemperatures.as_list()`.
PUFFER_KEYS: tuple[str, ...] = (
    "buffer_temp_top_c",
    "buffer_temp_mid_top_c",
    "buffer_temp_mid_bottom_c",
    "buffer_temp_bottom_c",
)
#: Wo der Fühler sitzt. Die Worte kommen von der Schichtungsprüfung, damit ein Fühler in beiden
#: Sätzen gleich heißt.
FUEHLER_DE: dict[str, str] = dict(zip(PUFFER_KEYS, ORTE_DE, strict=True))


@dataclass(frozen=True)
class Fuehlerstand:
    """Was ein Schlüssel zuletzt meldete, und wie lange schon unverändert.

    `unveraendert_min` ist die *gemeldete* Spanne: von der ersten bis zur letzten Meldung dieses
    Werts. Absichtlich nicht „bis jetzt" - die Zeit seit der letzten Meldung ist Stille, und die
    hat ihre eigene Regel.
    """

    key: str
    wert: float | None
    unveraendert_min: float
    meldungen: int
    seit: datetime | None = None


@dataclass(frozen=True)
class Stillstandsbefund:
    """Dieser Fühler steht. Form wie ein Befund des Wächters, damit er denselben Weg nimmt."""

    name: str
    title_de: str
    severity: Severity
    since: datetime | None
    silent_min: float
    text_de: str


def _zahl(wert: float, stellen: int = 1) -> str:
    return f"{wert:.{stellen}f}".replace(".", ",")


def abkuehlzeit_min(temp_c: float, cfg: BufferConfig) -> float | None:
    """Wie lange der Speicher ohne jede Entnahme braucht, um sich um eine Stelle abzukühlen.

    `loss_kw_per_k · (T - ambient)` gegen `volume_liters · 4,186/3600`: bei der Voreinstellung und
    40 °C sind das 0,079 K/h, also 76 Minuten für 0,1 K. `None`, wenn der Speicher nicht wärmer
    als sein Aufstellraum ist - dann kühlt er nicht ab, und die Physik sagt nichts über eine
    Mindeständerung.
    """
    kapazitaet_kwh_k = cfg.volume_liters * KWH_PER_LITER_KELVIN
    uebertemperatur = temp_c - cfg.ambient_c
    if uebertemperatur <= 0.0 or kapazitaet_kwh_k <= 0.0 or cfg.loss_kw_per_k <= 0.0:
        return None
    kelvin_je_minute = cfg.loss_kw_per_k * uebertemperatur / kapazitaet_kwh_k / 60.0
    return AUFLOESUNG_K / kelvin_je_minute


def standzeit_min(temp_c: float, cfg: BufferConfig) -> float | None:
    """Wie lange eine echte Temperatur höchstens auf derselben Zahl stehen darf.

    Abkühlen ohne Entnahme ist der langsamste Vorgang am Speicher; alles andere ist schneller.
    Darum ist diese Zeit die obere Schranke - und sie hängt von der Temperatur ab, weil der
    Verlust gegen die Übertemperatur rechnet. Ein lauwarmer Speicher bekommt mehr Zeit als ein
    heißer, und das ist keine Nachsicht, sondern Physik.

    `None` heißt: für diese Temperatur gibt es keine Frist, also auch keinen Befund (Modulkopf).
    Die Deckelung auf `HOECHSTENS_MIN` greift nur oberhalb der nutzbaren Temperatur, weil ihr
    Argument die Warmwasserentnahme ist und darunter nicht entnommen wird.
    """
    roh = abkuehlzeit_min(temp_c, cfg)
    if roh is None:
        return None
    frist = max(MINDESTENS_MIN, SICHERHEIT * roh)
    if temp_c <= cfg.min_useful_temperature_c:
        return frist
    return min(HOECHSTENS_MIN, frist)


def eingefroren(staende: Sequence[Fuehlerstand], cfg: BufferConfig) -> list[Stillstandsbefund]:
    """Die Fühler, die zu lange dieselbe Zahl melden - je Fühler ein Befund.

    Je Fühler und nicht einer für die Säule: welcher steht, ist die Auskunft, mit der jemand an
    den Speicher geht. Ein Befund über „die Puffertemperaturen" schickt ihn zu allen vier.
    """
    out: list[Stillstandsbefund] = []
    for stand in staende:
        if stand.wert is None or stand.meldungen < MELDUNGEN_MIND:
            continue
        roh = abkuehlzeit_min(stand.wert, cfg)
        frist = standzeit_min(stand.wert, cfg)
        # Zwei getrennte Gründe, hier nicht zu melden, und der erste ist der inhaltliche: ohne
        # Abkühlzeit ist der Speicher nicht wärmer als sein Aufstellraum, kühlt also nicht ab,
        # und nichts sagt, dass dieser Wert sich bewegen müsste (Modulkopf). Dann gibt es auch
        # keine Frist - `standzeit_min` gibt genau in diesem Fall `None` zurück.
        if roh is None or frist is None:
            continue
        if stand.unveraendert_min < frist:
            continue
        ort = FUEHLER_DE.get(stand.key, stand.key)
        warum = (
            f"Bei dieser Temperatur kühlt der Speicher auch ohne Entnahme um "
            f"{_zahl(AUFLOESUNG_K)} K in {round(roh)} Minuten ab; ein Wert, der sich über "
            f"{round(frist)} Minuten um keine Stelle bewegt, ist eingefroren."
        )
        out.append(
            Stillstandsbefund(
                name=f"frozen:{stand.key}",
                title_de=f"Der Pufferfühler {ort}",
                severity="alarm",
                since=stand.seit,
                silent_min=round(stand.unveraendert_min, 1),
                text_de=(
                    f"Der Pufferfühler {ort} meldet {silence_text(stand.unveraendert_min)} "
                    f"unverändert {_zahl(stand.wert)} °C. {warum} "
                    "Ladezustand und Freigabe der Wärmepumpe rechnen auf ihm weiter."
                ),
            )
        )
    return out
