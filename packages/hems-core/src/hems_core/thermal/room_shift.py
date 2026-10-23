"""Was eine Sollwertänderung kostet - und was das Haus als Wärmespeicher hergibt.

**Die Frage.** Wer in einem Raum den Sollwert um ein halbes Kelvin anhebt, verändert zweierlei:
dauerhaft den Verlust an die Umgebung, und einmalig den Inhalt des Speichers, der Estrich, Wände
und Möbel dieses Raums sind. Das erste kostet jeden Tag, das zweite ist eine Investition, die sich
zurückholen lässt, wenn sie in der billigen Stunde getätigt und in der teuren verzehrt wird.

**Das Modell ist klein und steht auf drei Zahlen**, die das Werkzeug ohnehin führt:

1. `heat_loss_kw_per_k` - der Verlustkoeffizient des ganzen Hauses, eine Annahme aus den
   Wärmeeinstellungen (Voreinstellung 0,22 kW/K), bis ein Wärmemengenzähler sie ersetzt.
2. Der **Anteil eines Raums**, gemessen an seinen Heizkreisen. Ein Raum mit vier von zwanzig
   Kreisen bekommt ein Fünftel. Das ist grob: Kreise werden nach Fläche und Bodenaufbau verlegt,
   nicht nach Verlust. Es ist aber die einzige raumbezogene Größe, die vorliegt, und es ist eine
   bessere Näherung als "alle Räume gleich".
3. Die **Zeitkonstante des Raums**, rund 25 Stunden (Fußboden rund 13). Aus ihr folgt die
   Wärmekapazität, denn eine Zeitkonstante ist nichts anderes als Kapazität durch Verlust:
   `C = tau * H`. Für dieses Haus sind das rund 5,5 kWh je Kelvin, über alle Räume.

**Was das Modell nicht kann.** Es kennt keine Himmelsrichtung, keine Sonne durchs Fenster, keine
offene Tür zum Nachbarraum und keine Vorlauftemperatur. Es sagt eine Größenordnung, und es sagt
sie in Euro, damit die Entscheidung nicht am Bauchgefühl hängt. Jede Zahl, die es ausgibt, ist
geschätzt und muss in der Anzeige auch so heißen.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from hems_core.accounting.heat import cop_at
from hems_core.domain.config import HeatDemandConfig

# Zeitkonstante eines Raums dieses Hauses in Stunden: wie lange eine Anhebung ohne Nachheizen
# vorhält, bis sie auf 37 Prozent abgeklungen ist. Fußbodenheizung mit Estrichspeicher; der
# Fußboden allein liegt bei rund 13 Stunden, der Raum mit Wänden und Einrichtung bei rund 25.
TAU_RAUM_H = 25.0
# Unter dieser Kreiszahl wird nicht geteilt: ein Raum ohne bekannte Kreise bekäme sonst alles oder
# nichts.
MIN_KREISE = 1


@dataclass(frozen=True, slots=True)
class ShiftEffect:
    """Die Wirkung einer dauerhaften Sollwertänderung um `delta_k` in einem Raum."""

    delta_k: float
    share: float
    # Dauerhaft: zusätzlicher Verlust und was er kostet
    loss_kw: float
    daily_kwh_th: float
    daily_kwh_el: float
    daily_eur: float
    # Einmalig: was der Raum an Wärme aufnimmt, bis er die neue Temperatur hat
    store_kwh_th: float
    store_kwh_el: float
    # Verschieben: in der billigen Stunde laden, in der teuren zehren
    shift_saving_eur: float | None
    hold_hours: float
    # Nach dieser Zeit ist die Hälfte der Anhebung an die Umgebung weg. Die eingängigste Zahl für
    # die Frage „wie früh muss ich vorladen".
    half_life_h: float
    cop: float
    note_de: str


def share_of_house(circuits: int, total_circuits: int) -> float:
    """Anteil eines Raums am Haus, nach Heizkreisen. Ohne brauchbare Zahlen: gleich verteilt."""
    if total_circuits <= 0:
        return 0.0
    return max(MIN_KREISE, circuits) / max(MIN_KREISE, total_circuits)


def capacity_kwh_per_k(cfg: HeatDemandConfig, tau_h: float = TAU_RAUM_H) -> float:
    """Wärmekapazität des Hauses aus Zeitkonstante mal Verlustkoeffizient (kWh je Kelvin)."""
    return tau_h * cfg.heat_loss_kw_per_k


def hold_hours(delta_k: float, toleranz_k: float = 0.1, tau_h: float = TAU_RAUM_H) -> float:
    """Wie lange eine Anhebung um `delta_k` vorhält, bis nur noch `toleranz_k` übrig ist.

    Exponentieller Abfall mit der Zeitkonstante. Die Zahl sagt, wie früh vorgeladen werden muss,
    damit die Wärme im Preishoch noch da ist - und sie ist der Grund, warum eine Fußbodenheizung
    als Speicher taugt und eine Luftheizung nicht.
    """
    if delta_k <= 0 or toleranz_k <= 0 or delta_k <= toleranz_k:
        return 0.0
    return round(tau_h * math.log(delta_k / toleranz_k), 1)


def effect(
    *,
    delta_k: float,
    circuits: int,
    total_circuits: int,
    cfg: HeatDemandConfig,
    outdoor_c: float,
    price_ct_kwh: float | None,
    cheap_ct_kwh: float | None = None,
    expensive_ct_kwh: float | None = None,
    shift_hours: float = 6.0,
    tau_h: float = TAU_RAUM_H,
) -> ShiftEffect:
    """Die ganze Rechnung für einen Raum.

    `price_ct_kwh` ist der Preis, zu dem die Dauerkosten bewertet werden - sinnvollerweise der
    mittlere Preis des Tages und nicht der des Augenblicks. `cheap_ct_kwh` und `expensive_ct_kwh`
    sind das günstigste und das teuerste Viertel der nächsten Stunden; aus ihrem Abstand entsteht
    die Ersparnis des Verschiebens.

    **Der Verlust während der Haltezeit wird abgezogen.** Wer sechs Stunden vor dem Preishoch lädt,
    hat bis dahin einen Teil davon an die Umgebung verloren; bei 25 Stunden Zeitkonstante sind das
    rund ein Fünftel. Eine Ersparnis ohne diesen Abzug wäre zu schön.
    """
    anteil = share_of_house(circuits, total_circuits)
    cop = cop_at(outdoor_c, cfg)
    verlust_kw = anteil * cfg.heat_loss_kw_per_k * delta_k
    taeglich_th = verlust_kw * 24.0
    taeglich_el = taeglich_th / cop if cop > 0 else 0.0
    speicher_th = anteil * capacity_kwh_per_k(cfg, tau_h) * delta_k
    speicher_el = speicher_th / cop if cop > 0 else 0.0
    preis = price_ct_kwh if price_ct_kwh is not None else None
    taeglich_eur = round(taeglich_el * preis / 100.0, 2) if preis is not None else 0.0

    ersparnis: float | None = None
    if cheap_ct_kwh is not None and expensive_ct_kwh is not None and speicher_el > 0:
        # Was nach `shift_hours` noch im Speicher steckt.
        rest = math.exp(-max(0.0, shift_hours) / tau_h)
        gewinn = (expensive_ct_kwh - cheap_ct_kwh) / 100.0
        # Geladen wird die volle Menge, genutzt nur der Rest; der Verlust kostet den günstigen Preis.
        ersparnis = round(
            speicher_el * rest * gewinn - speicher_el * (1 - rest) * cheap_ct_kwh / 100.0, 2
        )

    halt = hold_hours(abs(delta_k), tau_h=tau_h)
    richtung = "mehr" if delta_k >= 0 else "weniger"

    def de(x: float, stellen: int = 1) -> str:
        return f"{x:.{stellen}f}".replace(".", ",")

    note = (
        f"Geschätzt: {de(abs(delta_k))} K {richtung} in diesem Raum sind rund "
        f"{de(abs(taeglich_th))} kWh Wärme am Tag, bei Arbeitszahl {de(cop)} also "
        f"{de(abs(taeglich_el), 2)} kWh Strom. Grundlage sind der Verlustkoeffizient des Hauses "
        f"({de(cfg.heat_loss_kw_per_k, 2)} kW je Kelvin), der Anteil dieses Raums an den "
        f"Heizkreisen ({circuits} von {total_circuits}) und eine Zeitkonstante von "
        f"{de(tau_h, 0)} Stunden."
    )
    return ShiftEffect(
        delta_k=delta_k,
        share=round(anteil, 4),
        loss_kw=round(verlust_kw, 4),
        daily_kwh_th=round(taeglich_th, 2),
        daily_kwh_el=round(taeglich_el, 2),
        daily_eur=taeglich_eur,
        store_kwh_th=round(speicher_th, 2),
        store_kwh_el=round(speicher_el, 2),
        shift_saving_eur=ersparnis,
        hold_hours=halt,
        half_life_h=round(tau_h * math.log(2), 1),
        cop=round(cop, 2),
        note_de=note,
    )
