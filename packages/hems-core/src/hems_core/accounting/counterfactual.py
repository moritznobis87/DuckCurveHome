"""Was das Verschieben gebracht hat: derselbe Tag, aber ohne Preisblick.

**Die Frage.** Duck Curve Home verschiebt die Wärmepumpe in günstige Stunden. Ob das etwas bringt,
stand bisher nirgends - auf der Kostenseite hieß es ausdrücklich, dafür bräuchte es einen
Vergleichslauf, und den gebe es nicht. Hier ist er.

**Was verglichen wird.** Dieselben Stunden, dieselbe Wärmemenge, derselbe Rest des Hauses - nur
läuft die Wärmepumpe im Vergleichslauf dann, wann ein gewöhnlicher Thermostat sie laufen ließe:
nach dem Wärmebedarf der Stunde, nicht nach dem Preis. Die Differenz der Stromrechnung ist, was das
Verschieben gebracht hat.

**Das ist eine Rechnung, keine Messung.** Was wirklich passiert wäre, weiß niemand; es gibt nur
den einen Verlauf, der stattgefunden hat. Darum steht überall „geschätzt", darum sind die Annahmen
unten einzeln aufgezählt, und darum ist die Zahl eher vorsichtig:

* **Gleiche Strommenge, andere Stunden.** Die Tagesmenge der Wärmepumpe ist die gemessene; verteilt
  wird sie nach der *Form* des Bedarfs (Heizlast plus Warmwasserprofil, geteilt durch die
  Arbeitszahl der jeweiligen Stunde). Damit hängt das Ergebnis nicht daran, ob das Bedarfsmodell
  die absolute Höhe trifft - nur die Form zählt, und die Form ist das, worum es geht.
* **Der Rest des Hauses bleibt, wie er war**, der Speicher auch. In Wirklichkeit steuert DCH die
  Batterie mit; dieser Anteil fehlt hier und macht die Zahl kleiner, nicht größer.
* **Die bessere Arbeitszahl am Mittag zählt nicht als Gewinn.** Sie steckt in der Form und
  verschiebt nur, wie viel Strom in welcher Stunde nötig gewesen wäre.
* **Der Pelletofen bleibt außen vor.** Er ersetzt Wärme, die sonst die Wärmepumpe liefern müsste,
  aber er kostet Pellets statt Strom - das gehört auf die Wärmeseite, nicht in eine Stromrechnung.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, replace
from datetime import date, datetime

from hems_core.accounting.heat import cop_at, heat_demand_kw
from hems_core.domain.config import HeatDemandConfig

#: So viele Minuten muss eine Stunde haben, damit sie zählt. Darunter ist sie eine Lücke.
MIN_MINUTEN = 50
#: So viele volle Stunden braucht ein Tag mindestens, sonst wird er nicht gerechnet. Ein Tag, der
#: erst zwei Stunden alt ist, sagt über das Verschieben nichts.
MIN_STUNDEN = 6
#: Und so viel vom gelaufenen Teil des Tages muss belegt sein. Für einen vergangenen Tag sind das
#: rund 19 von 24 Stunden; für den laufenden Tag zählt nur, was schon vorbei ist - sonst wäre die
#: Antwort auf „was hat heute das Verschieben gebracht" bis Mitternacht immer „zu wenige Daten".
ANTEIL_NOETIG = 0.8
#: Darunter lief die Wärmepumpe praktisch nicht, und es gibt nichts zu verschieben.
MIN_WP_KWH = 1.0


@dataclass(frozen=True)
class ShiftHour:
    """Eine Stunde, wie sie wirklich lief. Alles aus der gespeicherten Stundenbilanz."""

    hour_start: datetime
    #: Der Kalendertag vor Ort: Ein Tag ist, was ein Thermostat als Tag erlebt, nicht ein UTC-Tag.
    day: date
    #: Die Stunde vor Ort, für das Warmwasserprofil.
    local_hour: int
    minutes: int
    import_kwh: float
    export_kwh: float
    heat_pump_kwh: float
    price_ct: float | None
    outdoor_c: float | None


@dataclass(frozen=True)
class ShiftDay:
    day: date
    heat_pump_kwh: float
    #: Wie viel Strom der Vergleichslauf in andere Stunden legt. Das Maß der Verschiebung.
    shifted_kwh: float
    actual_eur: float
    naive_eur: float
    saving_eur: float
    #: Leer, wenn gerechnet wurde; sonst der Grund, warum nicht.
    note_de: str = ""


@dataclass(frozen=True)
class ShiftResult:
    days: tuple[ShiftDay, ...]
    actual_eur: float
    naive_eur: float
    saving_eur: float
    heat_pump_kwh: float
    shifted_kwh: float
    #: Tage, die nicht gerechnet werden konnten, mit dem häufigsten Grund.
    skipped: int
    skipped_de: str = ""

    @property
    def saving_ct_per_kwh(self) -> float | None:
        """Was jede verschobene Kilowattstunde gebracht hat. Null verschoben heißt: keine Aussage."""
        if self.shifted_kwh <= 1e-6:
            return None
        return round(self.saving_eur * 100.0 / self.shifted_kwh, 2)


def _r(x: float) -> float:
    return round(x, 4)


def naive_shape(
    hours: Sequence[ShiftHour], cfg: HeatDemandConfig, mean_outdoor_c: float
) -> list[float]:
    """Die Form des Tages ohne Preisblick: Strombedarf je Stunde, normiert auf Summe eins.

    Heizlast und Warmwasser kommen aus demselben Modell wie die Prognose; geteilt wird durch die
    Arbeitszahl der jeweiligen Stunde, weil dieselbe Wärme bei Frost mehr Strom kostet als mittags.
    """
    roh: list[float] = []
    for h in hours:
        t = h.outdoor_c if h.outdoor_c is not None else mean_outdoor_c
        heizen, wasser = heat_demand_kw(t, h.local_hour, cfg)
        cop = cop_at(t, cfg)
        roh.append((heizen + wasser) / cop if cop > 0 else 0.0)
    summe = sum(roh)
    return [w / summe for w in roh] if summe > 1e-9 else []


def spread(total: float, weights: Sequence[float], cap_kwh: float) -> list[float]:
    """Die Tagesmenge auf die Stunden verteilen, ohne die Leistung des Geräts zu überschreiten.

    Ohne Deckel legte der Vergleichslauf in eine einzelne Frostnacht acht Kilowattstunden - eine
    Menge, die diese Wärmepumpe in einer Stunde nicht aufnehmen kann. Was über den Deckel geht,
    wandert nach denselben Gewichten in die Stunden, die noch Platz haben; nach ein paar Durchgängen
    ist nichts mehr übrig oder alles voll.
    """
    anteile = [total * w for w in weights]
    for _ in range(8):
        ueber = sum(max(0.0, a - cap_kwh) for a in anteile)
        if ueber <= 1e-9:
            break
        anteile = [min(cap_kwh, a) for a in anteile]
        frei = [i for i, a in enumerate(anteile) if a < cap_kwh - 1e-9]
        gewicht = sum(weights[i] for i in frei)
        if not frei or gewicht <= 1e-9:
            break
        for i in frei:
            anteile[i] = min(cap_kwh, anteile[i] + ueber * weights[i] / gewicht)
    return anteile


def _kosten(import_kwh: float, export_kwh: float, price_ct: float, feed_in_ct: float) -> float:
    return (import_kwh * price_ct - export_kwh * feed_in_ct) / 100.0


def _netz(import_kwh: float, export_kwh: float, delta_kwh: float) -> tuple[float, float]:
    """Netzbezug und Einspeisung, wenn die Wärmepumpe `delta` mehr (oder weniger) gezogen hätte.

    Mehr Verbrauch zehrt zuerst die Einspeisung auf und wird erst danach zu Bezug; weniger
    Verbrauch senkt zuerst den Bezug und wird erst danach zu Einspeisung. Bei `delta == 0` stehen
    die gemessenen Werte unverändert da - die Rechnung erfindet nichts, wo nichts verschoben wurde.
    """
    if delta_kwh >= 0:
        return import_kwh + max(0.0, delta_kwh - export_kwh), max(0.0, export_kwh - delta_kwh)
    fehlt = -delta_kwh
    return max(0.0, import_kwh - fehlt), export_kwh + max(0.0, fehlt - import_kwh)


def day_value(
    day: date,
    hours: Sequence[ShiftHour],
    cfg: HeatDemandConfig,
    feed_in_ct: float,
    cap_kwh: float,
    erwartet_h: float = 24.0,
) -> ShiftDay:
    """Ein Tag im Vergleich. Was nicht zu rechnen ist, sagt im `note_de`, warum.

    `erwartet_h` ist, wie viel von diesem Tag überhaupt gelaufen ist. Für einen vergangenen Tag
    sind das 24 Stunden, für den laufenden so viele, wie die Uhr zeigt.
    """
    leer = ShiftDay(
        day=day, heat_pump_kwh=0.0, shifted_kwh=0.0, actual_eur=0.0, naive_eur=0.0, saving_eur=0.0
    )
    voll = [h for h in hours if h.minutes >= MIN_MINUTEN]
    noetig = max(MIN_STUNDEN, ANTEIL_NOETIG * max(0.0, erwartet_h))
    if len(voll) < noetig:
        return replace(leer, note_de="zu wenige Stunden mit Daten")
    if any(h.price_ct is None for h in voll):
        return replace(leer, note_de="ohne Preis")
    temps = [h.outdoor_c for h in voll if h.outdoor_c is not None]
    if not temps:
        return replace(leer, note_de="ohne Außentemperatur")
    wp_total = sum(h.heat_pump_kwh for h in voll)
    if wp_total < MIN_WP_KWH:
        return replace(leer, note_de="Wärmepumpe lief nicht")
    gewichte = naive_shape(voll, cfg, sum(temps) / len(temps))
    if not gewichte:
        return replace(leer, note_de="kein Wärmebedarf")

    naiv = spread(wp_total, gewichte, cap_kwh)
    echt_eur = 0.0
    naiv_eur = 0.0
    verschoben = 0.0
    for h, menge in zip(voll, naiv, strict=True):
        preis = h.price_ct or 0.0
        delta = menge - h.heat_pump_kwh
        imp, exp = _netz(h.import_kwh, h.export_kwh, delta)
        echt_eur += _kosten(h.import_kwh, h.export_kwh, preis, feed_in_ct)
        naiv_eur += _kosten(imp, exp, preis, feed_in_ct)
        verschoben += max(0.0, delta)
    return ShiftDay(
        day=day,
        heat_pump_kwh=_r(wp_total),
        shifted_kwh=_r(verschoben),
        actual_eur=_r(echt_eur),
        naive_eur=_r(naiv_eur),
        saving_eur=_r(naiv_eur - echt_eur),
    )


def shift_value(
    hours: Sequence[ShiftHour],
    cfg: HeatDemandConfig,
    feed_in_ct: float,
    cap_kwh: float,
    erwartet: Mapping[date, float] | None = None,
) -> ShiftResult:
    """Der ganze Zeitraum, Tag für Tag. Tage ohne Aussage zählen nicht mit, sie werden genannt.

    `erwartet` sagt je Tag, wie viele Stunden von ihm gelaufen sind; ohne Angabe gilt ein voller
    Tag. Das trennt eine Lücke von einem Tag, der einfach noch läuft.
    """
    nach_tag: dict[date, list[ShiftHour]] = {}
    for h in hours:
        nach_tag.setdefault(h.day, []).append(h)
    tage = [
        day_value(d, nach_tag[d], cfg, feed_in_ct, cap_kwh, (erwartet or {}).get(d, 24.0))
        for d in sorted(nach_tag)
    ]
    gerechnet = [t for t in tage if not t.note_de]
    gruende: dict[str, int] = {}
    for t in tage:
        if t.note_de:
            gruende[t.note_de] = gruende.get(t.note_de, 0) + 1
    haeufigster = max(gruende, key=lambda k: gruende[k]) if gruende else ""
    return ShiftResult(
        days=tuple(tage),
        actual_eur=_r(sum(t.actual_eur for t in gerechnet)),
        naive_eur=_r(sum(t.naive_eur for t in gerechnet)),
        saving_eur=_r(sum(t.saving_eur for t in gerechnet)),
        heat_pump_kwh=_r(sum(t.heat_pump_kwh for t in gerechnet)),
        shifted_kwh=_r(sum(t.shifted_kwh for t in gerechnet)),
        skipped=len(tage) - len(gerechnet),
        skipped_de=haeufigster,
    )
