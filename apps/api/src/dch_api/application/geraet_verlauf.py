"""Der Verlauf des Hausgeräts: Messpunkte sammeln, ausdünnen und in Spannen auswerten.

Das Gerät schreibt jede Minute einen Bericht (`deploy/haus/dch`, `dch zustand`). Ein Bericht ist
ein Augenblick; ob die SSD vollläuft, die Datenbank wächst oder der Rechner im Sommer heißer
wird, zeigt erst der Verlauf. Dieser Teil legt alle fünf Minuten einen Punkt in die Datenbank
(`geraet_messwerte`) und bildet daraus die Reihen der Seite *Hausgerät*.

**Warum in der API und nicht auf dem Gerät.** Die Auswertung (Mittel, Spitzen, Raten aus Zählern,
die nach einem Neustart wieder bei null beginnen, eine Prognose) ist Rechnen, und Rechnen ist hier
in Python testbar; im Shell-Skript wäre es das nicht. Das Gerät liefert nur Rohwerte.

**Wie lange.** Fünf-Minuten-Punkte 30 Tage, danach der zur vollen Stunde zwei Jahre.
"""

from __future__ import annotations

import asyncio
import json
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any, Literal, Protocol

import structlog

log = structlog.get_logger("geraet_verlauf")

RASTER = timedelta(minutes=5)
FEIN_BEHALTEN = timedelta(days=30)
ALLES_BEHALTEN = timedelta(days=730)

Spanne = Literal["tag", "woche", "monat", "jahr"]


@dataclass(frozen=True)
class SpannenArt:
    dauer: timedelta
    schritt: timedelta


#: Je Spanne die Länge und die Breite eines Punkts im Diagramm. Rund 300 Punkte je Kurve: genug
#: für Spitzen, nicht so viele, dass ein Telefon beim Zeichnen ins Stocken kommt.
SPANNEN: dict[str, SpannenArt] = {
    "tag": SpannenArt(timedelta(days=1), timedelta(minutes=5)),
    "woche": SpannenArt(timedelta(days=7), timedelta(minutes=30)),
    "monat": SpannenArt(timedelta(days=30), timedelta(hours=2)),
    "jahr": SpannenArt(timedelta(days=365), timedelta(days=1)),
}

#: Größen, die gemittelt werden; dazu je eine Spitze, wo die Spitze die eigentliche Auskunft ist.
MITTEL = (
    "cpu_prozent",
    "last1",
    "temperatur_c",
    "takt_mhz",
    "eingangsspannung_v",
    "speicher_belegt_mb",
    "swap_belegt_mb",
    "ssd_temperatur_c",
)
SPITZE = ("cpu_prozent", "temperatur_c", "ssd_temperatur_c")
TIEFSTWERT = ("eingangsspannung_v",)
#: Füllstände: Es zählt der Stand am Ende des Abschnitts, nicht ein Mittel.
STAND = (
    "platte_belegt_bytes",
    "platte_gesamt_bytes",
    "speicher_gesamt_mb",
    "datenbank_bytes",
    "sicherung_bytes",
    "docker_bytes",
    "ssd_abnutzung_prozent",
)
#: Zähler seit dem Start des Geräts: Aus ihnen werden Mengen je Abschnitt.
ZAEHLER = ("netz_empfangen_bytes", "netz_gesendet_bytes", "ssd_geschrieben_bytes")


class Ablage(Protocol):
    async def geraet_messwert_speichern(self, zeile: Mapping[str, Any]) -> bool: ...

    async def geraet_messwerte(self, von: datetime, bis: datetime) -> list[dict[str, Any]]: ...

    async def geraet_messwerte_ausduennen(self, fein_vor: datetime, alles_vor: datetime) -> int: ...

    async def datenbank_bytes(self) -> int | None: ...


# ---------------------------------------------------------------------------------- Sammeln


def _zeit(roh: object) -> datetime | None:
    try:
        t = datetime.fromisoformat(str(roh).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=UTC)


def _zahl(wert: object) -> float | None:
    return float(wert) if isinstance(wert, int | float) and not isinstance(wert, bool) else None


def _ganz(wert: object) -> int | None:
    z = _zahl(wert)
    return int(z) if z is not None else None


def _wb(wert: object) -> dict[str, Any]:
    return wert if isinstance(wert, dict) else {}


def auf_raster(t: datetime) -> datetime:
    """Abgerundet auf fünf Minuten: Ein Punkt gilt für sein Raster, gleich wann im Raster er kam."""
    t = t.astimezone(UTC)
    return t.replace(minute=t.minute - t.minute % 5, second=0, microsecond=0)


def messpunkt(
    bericht: Mapping[str, Any], datenbank_bytes: int | None = None
) -> dict[str, Any] | None:
    """Aus einem Bericht des Geräts eine Zeile für `geraet_messwerte`; `None`, wenn er unbrauchbar ist."""
    t = _zeit(bericht.get("erstellt_am"))
    rechner = bericht.get("rechner")
    if t is None or not isinstance(rechner, dict):
        return None
    ts = auf_raster(t)
    last = rechner.get("last") or []
    gesamt = _zahl(rechner.get("speicher_gesamt_mb"))
    frei = _zahl(rechner.get("speicher_frei_mb"))
    swap_g = _zahl(rechner.get("swap_gesamt_mb")) or 0.0
    swap_f = _zahl(rechner.get("swap_frei_mb")) or 0.0
    # Die Platte, auf der das System liegt; die anderen (Sicherung auf einem Stick) stehen im
    # Augenblicksbild, aber nicht im Verlauf.
    platte = next(
        (p for p in rechner.get("platten") or [] if isinstance(p, dict) and p.get("ort") == "/"),
        None,
    )
    platte_gesamt = _ganz(platte.get("gesamt_bytes")) if platte else None
    platte_frei = _ganz(platte.get("frei_bytes")) if platte else None
    belegt = (
        platte_gesamt - platte_frei
        if platte_gesamt is not None and platte_frei is not None
        else None
    )
    ssd = _wb(rechner.get("ssd"))
    netz = _wb(rechner.get("netz"))
    docker = _wb(rechner.get("docker_platz"))
    docker_summe = sum(v for v in docker.values() if isinstance(v, int | float)) or None
    sicherung = _wb(bericht.get("sicherung"))
    try:
        drossel = int(str(rechner.get("drosselung")), 16) if rechner.get("drosselung") else None
    except ValueError:
        drossel = None
    dienste = {
        d["name"]: {
            "cpu_prozent": _zahl(d.get("cpu_prozent")),
            "speicher_mb": _zahl(d.get("speicher_mb")),
            "gesund": d.get("gesundheit") in (None, "healthy") and d.get("zustand") == "running",
        }
        for d in bericht.get("dienste") or []
        if isinstance(d, dict) and isinstance(d.get("name"), str)
    }
    return {
        "ts": ts,
        "stuendlich": ts.minute == 0,
        "cpu_prozent": _zahl(rechner.get("cpu_prozent")),
        "last1": _zahl(last[0]) if last else None,
        "temperatur_c": _zahl(rechner.get("temperatur_c")),
        "takt_mhz": _zahl(rechner.get("takt_mhz")),
        "eingangsspannung_v": _zahl(rechner.get("eingangsspannung_v")),
        "drosselung": drossel,
        "speicher_belegt_mb": gesamt - frei if gesamt is not None and frei is not None else None,
        "speicher_gesamt_mb": gesamt,
        "swap_belegt_mb": swap_g - swap_f if swap_g else None,
        "platte_belegt_bytes": belegt,
        "platte_gesamt_bytes": platte_gesamt,
        "ssd_temperatur_c": _zahl(ssd.get("temperatur_c")),
        "ssd_abnutzung_prozent": _zahl(ssd.get("abnutzung_prozent")),
        "ssd_geschrieben_bytes": _ganz(ssd.get("geschrieben_bytes")),
        "netz_empfangen_bytes": _ganz(netz.get("empfangen_bytes")),
        "netz_gesendet_bytes": _ganz(netz.get("gesendet_bytes")),
        "datenbank_bytes": datenbank_bytes,
        "sicherung_bytes": _ganz(sicherung.get("gesamt_bytes")),
        "docker_bytes": int(docker_summe) if docker_summe else None,
        "dienste": dienste or None,
    }


def bericht_lesen(ordner: Path) -> dict[str, Any] | None:
    try:
        roh = json.loads((ordner / "geraet.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return roh if isinstance(roh, dict) else None


async def sammeln(ablage: Ablage, ordner: Path) -> bool:
    """Einen Punkt aus dem aktuellen Bericht ablegen. Wahr, wenn er neu war."""
    bericht = bericht_lesen(ordner)
    if bericht is None:
        return False
    try:
        db = await ablage.datenbank_bytes()
    except Exception:
        db = None
    zeile = messpunkt(bericht, db)
    if zeile is None:
        return False
    return await ablage.geraet_messwert_speichern(zeile)


async def schleife(
    ablage: Ablage,
    ordner: Path,
    takt_s: float = 60.0,
    jetzt: Callable[[], datetime] = lambda: datetime.now(UTC),
) -> None:
    """Jede Minute nachsehen, einmal am Tag ausdünnen. Läuft, bis sie abgebrochen wird."""
    zuletzt_ausgeduennt: datetime | None = None
    while True:
        try:
            await sammeln(ablage, ordner)
            t = jetzt()
            if zuletzt_ausgeduennt is None or t - zuletzt_ausgeduennt > timedelta(days=1):
                weg = await ablage.geraet_messwerte_ausduennen(
                    t - FEIN_BEHALTEN, t - ALLES_BEHALTEN
                )
                zuletzt_ausgeduennt = t
                if weg:
                    log.info("geraet_messwerte_ausgeduennt", zeilen=weg)
        except asyncio.CancelledError:
            raise
        except Exception as fehler:
            log.warning("geraet_messwert_fehlgeschlagen", fehler=repr(fehler)[:200])
        await asyncio.sleep(takt_s)


# -------------------------------------------------------------------------------- Auswerten


def _mittel(werte: Sequence[float]) -> float | None:
    return round(sum(werte) / len(werte), 3) if werte else None


_NULLPUNKT = datetime(2000, 1, 1, tzinfo=UTC)


def _abschnitt(t: datetime, schritt: timedelta) -> datetime:
    """Der Abschnitt, in den `t` fällt, an runden Zeiten ausgerichtet (:00 und :30, volle zwei
    Stunden, Mitternacht UTC) - nicht am Ende der Spanne, sonst begänne er um 11:05."""
    n = (t - _NULLPUNKT) // schritt
    return _NULLPUNKT + n * schritt


def verlauf(zeilen: Sequence[Mapping[str, Any]], spanne: str, jetzt: datetime) -> dict[str, Any]:
    """Die Reihen einer Spanne: je Abschnitt Mittel, Spitzen, Stände und Mengen aus Zählern.

    Zähler beginnen nach einem Neustart des Geräts wieder bei null. Ein Rückgang ist deshalb kein
    negativer Verkehr, sondern ein Neustart; gezählt wird ab dort der neue Stand.
    """
    art = SPANNEN[spanne]
    ende = auf_raster(jetzt) + RASTER
    beginn = _abschnitt(ende - art.dauer, art.schritt)
    abschnitte: dict[datetime, list[Mapping[str, Any]]] = {}
    mengen: dict[datetime, dict[str, int]] = {}
    vorher: Mapping[str, Any] | None = None
    for z in zeilen:
        ts = z["ts"]
        if ts < beginn or ts >= ende:
            vorher = z
            continue
        a = _abschnitt(ts, art.schritt)
        abschnitte.setdefault(a, []).append(z)
        m = mengen.setdefault(a, dict.fromkeys(ZAEHLER, 0))
        if vorher is not None:
            for k in ZAEHLER:
                neu, alt = z.get(k), vorher.get(k)
                if neu is None:
                    continue
                if alt is None or neu < alt:
                    continue  # erster Punkt oder Neustart: kein Zuwachs bekannt
                m[k] += neu - alt
        vorher = z

    punkte = []
    for a in sorted(abschnitte):
        gruppe = abschnitte[a]
        p: dict[str, Any] = {"t": a}
        for k in MITTEL:
            p[k] = _mittel([g[k] for g in gruppe if g.get(k) is not None])
        for k in SPITZE:
            werte = [g[k] for g in gruppe if g.get(k) is not None]
            p[f"{k}_max"] = max(werte) if werte else None
        for k in TIEFSTWERT:
            werte = [g[k] for g in gruppe if g.get(k) is not None]
            p[f"{k}_min"] = min(werte) if werte else None
        for k in STAND:
            werte = [g[k] for g in gruppe if g.get(k) is not None]
            p[k] = werte[-1] if werte else None
        sekunden = art.schritt.total_seconds()
        p["netz_empfangen_bytes_s"] = round(mengen[a]["netz_empfangen_bytes"] / sekunden, 1)
        p["netz_gesendet_bytes_s"] = round(mengen[a]["netz_gesendet_bytes"] / sekunden, 1)
        p["ssd_geschrieben_bytes"] = mengen[a]["ssd_geschrieben_bytes"]
        p["drosselung_jetzt"] = any((g.get("drosselung") or 0) & 0xF for g in gruppe)
        dienste: dict[str, dict[str, list[float]]] = {}
        for g in gruppe:
            for name, d in (g.get("dienste") or {}).items():
                ziel = dienste.setdefault(name, {"cpu_prozent": [], "speicher_mb": []})
                for k in ("cpu_prozent", "speicher_mb"):
                    if isinstance(d, dict) and d.get(k) is not None:
                        ziel[k].append(float(d[k]))
        p["dienste"] = {
            name: {k: _mittel(v) for k, v in werte.items()} for name, werte in dienste.items()
        }
        punkte.append(p)

    return {
        "spanne": spanne,
        "von": beginn,
        "bis": ende,
        "schritt_min": int(art.schritt.total_seconds() // 60),
        "punkte": punkte,
        "prognose": prognose(zeilen, jetzt),
    }


def _steigung(paare: Sequence[tuple[float, float]]) -> float | None:
    """Kleinste Quadrate: Zuwachs je Einheit von x. `None` mit zu wenig Punkten."""
    if len(paare) < 2:
        return None
    n = len(paare)
    mx = sum(x for x, _ in paare) / n
    my = sum(y for _, y in paare) / n
    nenner = sum((x - mx) ** 2 for x, _ in paare)
    if nenner == 0:
        return None
    return sum((x - mx) * (y - my) for x, y in paare) / nenner


def prognose(zeilen: Sequence[Mapping[str, Any]], jetzt: datetime) -> dict[str, Any]:
    """Wachstum je Tag über die letzten 30 Tage, und wann die SSD bei diesem Tempo voll wäre.

    Eine Gerade durch die Füllstände. Sie überschätzt, wenn gerade ein großes Update geladen
    wurde, und unterschätzt, wenn alte Images aufgeräumt wurden - deshalb erst ab sieben Tagen
    Verlauf, und sie steht als „bei diesem Tempo“ da, nicht als Datum.
    """
    seit = jetzt - timedelta(days=30)
    neu = [z for z in zeilen if z["ts"] >= seit]
    aus: dict[str, Any] = {
        "tage_verlauf": 0.0,
        "platte_bytes_pro_tag": None,
        "platte_voll_in_tagen": None,
        "datenbank_bytes_pro_tag": None,
        "sicherung_bytes_pro_tag": None,
        "ssd_geschrieben_bytes_pro_tag": None,
    }
    if not neu:
        return aus
    tage = (neu[-1]["ts"] - neu[0]["ts"]).total_seconds() / 86_400
    aus["tage_verlauf"] = round(tage, 1)

    def reihe(k: str) -> list[tuple[float, float]]:
        return [
            ((z["ts"] - neu[0]["ts"]).total_seconds() / 86_400, float(z[k]))
            for z in neu
            if z.get(k) is not None
        ]

    if tage >= 7:
        for k, ziel in (
            ("platte_belegt_bytes", "platte_bytes_pro_tag"),
            ("datenbank_bytes", "datenbank_bytes_pro_tag"),
            ("sicherung_bytes", "sicherung_bytes_pro_tag"),
        ):
            s = _steigung(reihe(k))
            aus[ziel] = round(s) if s is not None else None
        rate = aus["platte_bytes_pro_tag"]
        letzte = next((z for z in reversed(neu) if z.get("platte_gesamt_bytes")), None)
        if rate and rate > 0 and letzte and letzte.get("platte_belegt_bytes") is not None:
            frei = letzte["platte_gesamt_bytes"] - letzte["platte_belegt_bytes"]
            aus["platte_voll_in_tagen"] = round(frei / rate)
    if tage >= 1:
        # Geschrieben: Summe der Zuwächse (Neustarts übersprungen) geteilt durch die Tage.
        summe, vorher = 0, None
        for z in neu:
            w = z.get("ssd_geschrieben_bytes")
            if w is not None and vorher is not None and w >= vorher:
                summe += w - vorher
            vorher = w if w is not None else vorher
        aus["ssd_geschrieben_bytes_pro_tag"] = round(summe / tage) if summe else None
    return aus
