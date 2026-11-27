"""Thermischer Ladezustand des Pufferspeichers.

Zwei konfigurierbare Methoden:
  layered_energy_v1  - nutzbare Energie je Schicht oberhalb T_min, bezogen auf die Kapazität
                       zwischen T_min und T_max. Schichten unter T_min zählen 0 (Schichtung wird
                       berücksichtigt). Standard.
  weighted_mean_v1   - gewichtete Mitteltemperatur, linear zwischen T_min und T_max.
Beide sind Schätzwerte; die Methode wird im Ergebnis mitgeführt.

`compute_buffer_state` prüft, ob die vier Werte da und frisch sind - nicht, ob sie zueinander
passen. Dafür steht `schichtungsbefund` daneben, und zwar **daneben und nicht darin**: die
Begründung steht an der Funktion.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Literal

from hems_core.domain.buffer import BufferState, BufferStatus
from hems_core.domain.config import BufferConfig
from hems_core.domain.snapshot import BufferTemperatures

KWH_PER_LITER_KELVIN = 4.186 / 3600.0  # Wasser: 4,186 kJ/(kg·K) → kWh/(l·K)

#: Wie weit zwei Pufferfühler auseinanderliegen dürfen, ohne dass es etwas bedeutet.
#:
#: Ein DS18B20 hat nach Datenblatt ±0,5 K im Bereich -10 bis +85 °C. Zwei davon können sich also
#: um 1,0 K unterscheiden, ohne dass einer falsch ist. Deshalb ist eine Inversion von 0,2 K kein
#: Befund, und deshalb heißt „alle vier gleich" hier: alle vier innerhalb eines Kelvins.
FUEHLERGENAUIGKEIT_K = 1.0


def _clamp01(x: float) -> float:
    return max(0.0, min(1.0, x))


def status_for(soc: float, cfg: BufferConfig) -> BufferStatus:
    cold, partial, warm = cfg.status_thresholds
    if soc < cold:
        return BufferStatus.COLD
    if soc < partial:
        return BufferStatus.PARTIAL
    if soc < warm:
        return BufferStatus.WARM
    return BufferStatus.FULL


def capacity_kwh(cfg: BufferConfig) -> float:
    span = cfg.max_temperature_c - cfg.min_useful_temperature_c
    return cfg.volume_liters * KWH_PER_LITER_KELVIN * span


def usable_energy_kwh(temps: Sequence[float], cfg: BufferConfig) -> float:
    """Nutzbare Energie im Puffer oberhalb T_min, aus vier Schichttemperaturen.

    Herausgezogen aus `compute_buffer_state`, damit dieselbe Rechnung auch auf eine Zeitreihe
    angewandt werden kann: die Änderung dieses Werts über die Zeit ist die Netto-Wärmeleistung des
    Speichers - Zufuhr minus Entnahme minus Verluste. Damit lässt sich Fremdwärme beziffern, statt
    sie nur zu vermuten, ganz ohne Wärmemengenzähler.
    """
    if len(temps) != len(cfg.layers):
        raise ValueError("temps und buffer.layers müssen gleich lang sein")
    usable = 0.0
    for share, ti in zip(cfg.layers, temps, strict=True):
        liters = cfg.volume_liters * share
        usable += liters * KWH_PER_LITER_KELVIN * max(0.0, ti - cfg.min_useful_temperature_c)
    return min(usable, capacity_kwh(cfg))


def nutzbarer_inhalt_kwh(temps: Sequence[float], cfg: BufferConfig) -> float:
    """Der nutzbare Inhalt des Puffers aus vier Schichttemperaturen, nach der eingestellten Methode.

    Dieselbe Zahl wie `compute_buffer_state(...).usable_energy_kwh`, nur aus bloßen Temperaturen
    statt aus Messwerten mit Güte. Gebraucht wird sie für eine Zeitreihe: der Fahrplan zeigt
    neben dem geplanten Pufferinhalt den gemessenen der vergangenen Stunden, und beide müssen
    auf derselben Skala liegen. Der Optimierer beginnt mit `usable_energy_kwh` aus
    `compute_buffer_state`; eine zweite Rechnung daneben ergäbe an der Jetzt-Linie einen Sprung.
    """
    if cfg.soc_method == "weighted_mean_v1":
        if len(cfg.weights) != 4 or len(temps) != 4:
            raise ValueError("buffer.weights und die Temperaturen müssen je vier Werte enthalten")
        mittel = sum(w * t for w, t in zip(cfg.weights, temps, strict=True)) / sum(cfg.weights)
        spanne = cfg.max_temperature_c - cfg.min_useful_temperature_c
        return _clamp01((mittel - cfg.min_useful_temperature_c) / spanne) * capacity_kwh(cfg)
    return usable_energy_kwh(temps, cfg)


def compute_buffer_state(temps: BufferTemperatures, cfg: BufferConfig) -> BufferState:
    cap = capacity_kwh(cfg)
    values = [m.value if m.usable else None for m in temps.as_list()]
    if any(v is None for v in values):
        return BufferState(
            soc=None,
            usable_energy_kwh=None,
            capacity_kwh=cap,
            volume_liters=cfg.volume_liters,
            mean_temp_c=None,
            status=BufferStatus.UNKNOWN,
            method=cfg.soc_method,
            headroom_soc=None,
        )
    t = [float(v) for v in values if v is not None]
    if len(cfg.layers) != 4 or abs(sum(cfg.layers) - 1.0) > 1e-6:
        raise ValueError("buffer.layers muss vier Anteile mit Summe 1 enthalten")

    if cfg.soc_method == "weighted_mean_v1":
        if len(cfg.weights) != 4:
            raise ValueError("buffer.weights muss vier Gewichte enthalten")
        wsum = sum(cfg.weights)
        mean = sum(w * ti for w, ti in zip(cfg.weights, t, strict=True)) / wsum
        span = cfg.max_temperature_c - cfg.min_useful_temperature_c
        soc = _clamp01((mean - cfg.min_useful_temperature_c) / span)
        usable = soc * cap
    else:
        usable = usable_energy_kwh(t, cfg)
        soc = _clamp01(usable / cap) if cap > 0 else 0.0
        mean = sum(s * ti for s, ti in zip(cfg.layers, t, strict=True))

    return BufferState(
        soc=round(soc, 4),
        usable_energy_kwh=round(usable, 3),
        capacity_kwh=round(cap, 3),
        volume_liters=cfg.volume_liters,
        mean_temp_c=round(mean, 2),
        status=status_for(soc, cfg),
        method=cfg.soc_method,
        headroom_soc=round(1.0 - soc, 4),
    )


@dataclass(frozen=True)
class Schichtungsbefund:
    """Die Säule ist unplausibel. Form wie ein Befund des Wächters, damit er denselben Weg nimmt."""

    name: str
    title_de: str
    severity: Literal["warn", "alarm"]
    text_de: str


def _grad(wert: float) -> str:
    return f"{wert:.1f}".replace(".", ",") + " °C"


def _kelvin(wert: float) -> str:
    return f"{wert:.1f}".replace(".", ",") + " K"


#: Die vier Fühler von oben nach unten, so wie sie im Satz vorkommen.
ORTE_DE: tuple[str, str, str, str] = ("oben", "Mitte oben", "Mitte unten", "unten")


def schichtungsbefund(
    temps: Sequence[float],
    cfg: BufferConfig,
    orte: Sequence[str] = ORTE_DE,
) -> Schichtungsbefund | None:
    """Passen die vier Temperaturen zueinander? Ein Befund, keine Weigerung.

    **Warum das hier fehlte.** Bis zum 22.11.2026 prüfte der Dienst nur Vollständigkeit und
    Frische. Unten wärmer als oben lief ohne Bemerkung durch - eine Vertauschung zweier Fühler
    hätte niemand gesehen, obwohl die Reihenfolge am Speicher nie geprüft wurde.

    **Was die Säule vom Foto betrifft: sie ist kein Befund, und das ist Absicht.** Auf dem Foto
    vom 22.11.2026 steht `40°, 40°, 40°, 39°`, daneben „PUFFER 18 % kalt". Nachgerechnet passt
    alles zusammen (`usable_energy_kwh([40,40,40,39])` = 5,523 von 31,395 kWh, soc 0,176, und
    0,176 < 0,2 heißt `cold`), und ein Kelvin Spanne ist bei einem leergefahrenen Speicher
    physikalisch möglich. Diese Säule ist in Ordnung; eine Prüfung, die sie anmeckert, hängt eine
    Dauerwarnung für einen gesunden Speicher an die Wand. Die Grenze der flachen Säule liegt
    deshalb bei der Komforttemperatur, nicht bei der nutzbaren (Begründung unten am Kode).

    **Was er tut: eine Bemerkung, und nicht mehr.** Die Rechnung läuft weiter und der Ladestand
    steht weiter da. Eine Anzeige, die bei unplausiblen Werten nichts mehr zeigt, ist schlechter
    als eine, die die Zahl zeigt und danebenschreibt, dass ihr nicht zu trauen ist - der Fall vom
    25.10.2026 (vier satte Temperaturen, als Füllstand ein Strich, kein Wort dazu) ist genau
    dieser Fehler, nur von der anderen Seite.

    **Die Inversion zuerst.** Unten dauerhaft wärmer als oben ist die stärkere Aussage: eingespeist
    und entnommen wird oben, also kann der Speicher das von sich aus nicht. Dass die Säule gar
    keine Schichtung zeigt, ist dagegen ein Zustand, den es wirklich gibt - nur eben einen, in dem
    die vier Zahlen nichts mehr tragen.

    `orte` sind die vier Namen von oben nach unten; sie stehen im Satz.
    """
    if len(temps) != 4 or len(orte) != 4:
        raise ValueError("Die Prüfung erwartet vier Temperaturen von oben nach unten")
    werte = [float(t) for t in temps]

    # Jedes Paar, nicht nur die Nachbarn: oben 45 / unten 48 ist auch dann falsch, wenn die
    # Mitte dazwischen sauber abstuft.
    abstand, oben, unten = max(
        (werte[u] - werte[o], o, u) for o in range(4) for u in range(o + 1, 4)
    )
    if abstand > FUEHLERGENAUIGKEIT_K:
        return Schichtungsbefund(
            name="buffer_inversion",
            title_de="Die Puffersäule",
            severity="warn",
            text_de=(
                f"Die Puffersäule steht auf dem Kopf: {orte[unten]} ({_grad(werte[unten])}) ist "
                f"{_kelvin(abstand)} wärmer als {orte[oben]} ({_grad(werte[oben])}). Eingespeist "
                "und entnommen wird oben, also kann der Speicher das nicht von sich aus. "
                "Wahrscheinlich sind zwei Fühler vertauscht (die Reihenfolge der Fühler ist "
                "angenommen und am Speicher nie geprüft worden). Der Ladezustand rechnet die "
                "Säule weiter, als wäre sie richtig herum."
            ),
        )

    spanne = max(werte) - min(werte)
    if spanne > FUEHLERGENAUIGKEIT_K:
        return None
    # Eine flache Säule ist nur dort ein Befund, wo sie nicht flach sein darf: zwischen der
    # Komforttemperatur und der Zieltemperatur. Darunter und darüber gibt es den Zustand wirklich.
    #
    # **Warum die Grenze hier liegt, und nicht bei der nutzbaren Temperatur.** Oberhalb von
    # `comfort_min_top_c` liefert die Oberkante Komfortwärme, der Speicher ist also in Betrieb;
    # eingespeist und entnommen wird oben, und solange das geschieht, muss oben mehr stehen als
    # unten. Fehlt die Stufe dann trotzdem, tragen die vier Zahlen nichts.
    #
    # Unterhalb davon ist die flache Säule der Normalfall und keine Auffälligkeit: ein
    # leergefahrener Speicher, dessen Oberkante auf die Rücklauftemperatur gesunken ist, steht
    # überall gleich lauwarm, und über Tage im Stillstand gleicht sich auch der Rest aus. Genau so
    # sah die Säule auf dem Foto vom 22.11.2026 aus (`40°, 40°, 40°, 39°`), und sie war in Ordnung:
    # vier verschiedene Fühler, 18 % rechnerisch richtig, ein Kelvin Spanne bei einem entleerten
    # Speicher physikalisch möglich. Eine Prüfung, die sie anmeckert, erzeugt eine Dauerwarnung an
    # der Wand für einen gesunden Speicher - und ob die Säule *stehen bleibt*, statt zu fallen,
    # kann diese Funktion gar nicht wissen: sie sieht eine Momentaufnahme. Genau dafür gibt es
    # `hems_core.watch.stillstand`, das den Verlauf je Fühler führt.
    if min(werte) < cfg.comfort_min_top_c:
        return None
    # Der durchgeladene Speicher muss flach sein: die Wärmepumpe zieht die ganze Säule auf die
    # Zieltemperatur.
    if min(werte) >= cfg.target_temperature_c - FUEHLERGENAUIGKEIT_K:
        return None
    return Schichtungsbefund(
        name="buffer_flat",
        title_de="Die Puffersäule",
        severity="warn",
        text_de=(
            "Die Puffersäule zeigt keine Schichtung: alle vier Fühler liegen innerhalb von "
            f"{_kelvin(spanne)}, und das ist nicht mehr als die Genauigkeit zweier Fühler "
            f"(±0,5 K). Dabei liefert die Oberkante mit {_grad(max(werte))} noch Komfortwärme, "
            "der Speicher ist also in Betrieb, und eingespeist wie entnommen wird oben, es "
            "müsste eine Stufe zu sehen sein. Möglich ist dieses Bild, wenn zwei Fühler an "
            "derselben Stelle sitzen oder am selben Wert hängen; der Ladezustand daneben steht "
            "auf diesen vier Zahlen."
        ),
    )
