"""Was die Wärmepumpe unter welcher Kennzahl ihres Reglers tut.

Der Regler sendet im Rundruf eine Zahl (Kennung c94b). Die fremde Bus-Beschreibung gibt ihr
Wörter, die für diese Anlage nicht stimmen: am 14.11.2026 stand bei der Zahl 20 „Puffer kühlen"
an einer Maschine, die den Puffer heizt. Statt die Wörter zu raten, wird hier ausgezählt, was in
den Minuten geschah, in denen eine Zahl galt: lief die Maschine, mit welchem Vorlauf und welchem
Sollwert, wurde der Speicher oben oder weiter unten wärmer, hatte Duck Curve Home sie
angefordert. Aus dieser Tabelle lässt sich ablesen, welche Zahl Warmwasser ist und welche
Heizbetrieb.

**Bewusst keine automatische Deutung.** Ein kühler Speicher wird im Heizbetrieb auch oben
wärmer, und ein Sollwert sagt allein nichts. Die Zeilen sind die Belege; die Zuordnung in
`waermepumpe.KREIS_DE` und `EINSPEISUNG` trägt ein Mensch ein, der sie gelesen hat.

Reine Rechnung, kein I/O.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta

from dch_api.schemas import ReglerKennzahlenOut, ReglerKennzahlOut

#: Die Minutenreihen, die die Auszählung braucht.
REIHEN = (
    "heat_pump_cycle_code",
    "heat_pump_mode_code",
    "heat_pump_compressor_hz",
    "heat_pump_power_kw",
    "heat_pump_bus_power_kw",
    "flow_temp_c",
    "heat_pump_flow_setpoint_c",
    "buffer_temp_top_c",
    "buffer_temp_mid_bottom_c",
    "hp_release_contact",
)
TAGE_STANDARD = 7
TAGE_HOECHSTENS = 60
#: Eine Minute zählt nur, wenn die Kennzahl in ihr nicht gewechselt hat: das Minutenmittel
#: zweier Zahlen ist keine dritte.
GANZ = 0.01
#: Unter so vielen Minuten Lauf ist die Erwärmungsrate eine Laune, kein Wert.
MIN_LAUF_MIN = 20


@dataclass
class _Summe:
    minuten: int = 0
    lauf: int = 0
    vorlauf: float = 0.0
    vorlauf_n: int = 0
    soll: float = 0.0
    soll_n: int = 0
    angefordert: int = 0
    angefordert_n: int = 0
    oben_k: float = 0.0
    unten_k: float = 0.0
    paar_min: float = 0.0
    zusatz: float = 0.0
    zusatz_n: int = 0
    zuletzt: datetime | None = None


def _zahl(v: object) -> float | None:
    return float(v) if isinstance(v, int | float) and math.isfinite(v) else None


def _laeuft(zeile: dict[str, float | str | None]) -> bool:
    modus = _zahl(zeile.get("heat_pump_mode_code"))
    if modus is not None:
        return round(modus) in (2, 3, 4, 5)
    hz = _zahl(zeile.get("heat_pump_compressor_hz"))
    if hz is not None:
        return hz > 0
    strom = _zahl(zeile.get("heat_pump_power_kw"))
    return strom is not None and strom >= 0.3


def auswerten(zeilen: Sequence[dict[str, float | str | None]]) -> list[ReglerKennzahlOut]:
    """Je Kennzahl eine Zeile, die häufigste zuerst."""
    summen: dict[int, _Summe] = {}
    davor: tuple[datetime, int, bool, float | None, float | None] | None = None
    for zeile in sorted(zeilen, key=lambda z: str(z.get("ts") or "")):
        ts = zeile.get("ts")
        roh = _zahl(zeile.get("heat_pump_cycle_code"))
        if not isinstance(ts, str) or roh is None or abs(roh - round(roh)) > GANZ:
            davor = None
            continue
        at = datetime.fromisoformat(ts)
        code = round(roh)
        s = summen.setdefault(code, _Summe())
        s.minuten += 1
        s.zuletzt = at
        laeuft = _laeuft(zeile)
        oben = _zahl(zeile.get("buffer_temp_top_c"))
        unten = _zahl(zeile.get("buffer_temp_mid_bottom_c"))
        kontakt = _zahl(zeile.get("hp_release_contact"))
        if kontakt is not None:
            s.angefordert_n += 1
            s.angefordert += 1 if kontakt >= 0.5 else 0
        if laeuft:
            s.lauf += 1
            vorlauf = _zahl(zeile.get("flow_temp_c"))
            if vorlauf is not None:
                s.vorlauf += vorlauf
                s.vorlauf_n += 1
            soll = _zahl(zeile.get("heat_pump_flow_setpoint_c"))
            if soll is not None:
                s.soll += soll
                s.soll_n += 1
            # Was der Zähler mehr misst, als die Maschine für sich meldet: daran zeigt sich,
            # unter welcher Kennzahl der Heizstab mitläuft.
            zaehler = _zahl(zeile.get("heat_pump_power_kw"))
            maschine = _zahl(zeile.get("heat_pump_bus_power_kw"))
            if zaehler is not None and maschine is not None:
                s.zusatz += zaehler - maschine
                s.zusatz_n += 1
        # Erwärmung des Speichers: nur zwischen zwei aufeinanderfolgenden Minuten derselben
        # Kennzahl, in denen die Maschine lief. Über eine Lücke hinweg wäre es geraten.
        if davor is not None:
            vor_at, vor_code, vor_lief, vor_oben, vor_unten = davor
            folgt = timedelta(0) < at - vor_at <= timedelta(seconds=90)
            if folgt and vor_code == code and vor_lief and laeuft:
                if oben is not None and vor_oben is not None:
                    s.oben_k += oben - vor_oben
                if unten is not None and vor_unten is not None:
                    s.unten_k += unten - vor_unten
                s.paar_min += (at - vor_at).total_seconds() / 60.0
        davor = (at, code, laeuft, oben, unten)

    def rate(k: float, s: _Summe) -> float | None:
        if s.lauf < MIN_LAUF_MIN or s.paar_min <= 0:
            return None
        return round(k / s.paar_min * 60.0, 1)

    return [
        ReglerKennzahlOut(
            code=code,
            minuten=s.minuten,
            lauf_min=s.lauf,
            vorlauf_c=round(s.vorlauf / s.vorlauf_n, 1) if s.vorlauf_n else None,
            vorlauf_soll_c=round(s.soll / s.soll_n, 1) if s.soll_n else None,
            oben_k_h=rate(s.oben_k, s),
            unten_k_h=rate(s.unten_k, s),
            angefordert_anteil=round(s.angefordert / s.angefordert_n, 2)
            if s.angefordert_n
            else None,
            zusatz_kw=round(s.zusatz / s.zusatz_n, 2) if s.zusatz_n else None,
            zuletzt=s.zuletzt,
        )
        for code, s in sorted(summen.items(), key=lambda kv: -kv[1].minuten)
    ]


def zusammensetzen(
    now: datetime, tage: int, zeilen: Sequence[dict[str, float | str | None]]
) -> ReglerKennzahlenOut:
    return ReglerKennzahlenOut(now=now, tage=tage, zeilen=auswerten(zeilen))


def vorfuehrung(now: datetime) -> list[dict[str, float | str | None]]:
    """Minuten für die Vorführung: drei Stunden Stillstand, eine Stunde Heizbetrieb unter der
    Kennzahl 2 (der Speicher wird unten wärmer), vierzig Minuten unter der 3 (oben)."""
    zeilen: list[dict[str, float | str | None]] = []
    start = now.replace(second=0, microsecond=0) - timedelta(minutes=280)
    oben, unten = 48.0, 34.0
    for i in range(280):
        code, lief = (0.0, False) if i < 180 else (2.0, True) if i < 240 else (3.0, True)
        if code == 2.0:
            unten += 0.07
        elif code == 3.0:
            oben += 0.1
        zeilen.append(
            {
                "ts": (start + timedelta(minutes=i)).isoformat(),
                "heat_pump_cycle_code": code,
                "heat_pump_mode_code": 3.0 if lief else 15.0,
                "flow_temp_c": (38.0 if code == 2.0 else 56.0) if lief else None,
                "heat_pump_flow_setpoint_c": 55.0 if code == 3.0 else 45.0,
                "buffer_temp_top_c": round(oben, 2),
                "buffer_temp_mid_bottom_c": round(unten, 2),
                "hp_release_contact": 1.0 if code == 2.0 else 0.0,
            }
        )
    return zeilen
