"""Kandidaten aus den Auswertungen, die es schon gibt.

**Warum hier nichts neu gemessen wird.** Das Haus hat drei Auswertungen, die seit Monaten über
echten Reihen laufen: die Ausgleichsebene der COP-Kennlinie, die Ereignisstudie der
K1-Schließvorgänge und die Wärmebilanz. Jede davon liefert genau die Zahlen, die der Reglerentwurf
braucht - sie wurden bisher nur nicht dorthin gegeben. Dieses Modul übersetzt: aus einer
Auswertung werden Kandidaten mit Unsicherheit, und über die entscheidet dann die Prüfung in
`schaetzer`.

**Was ein Kandidat mitbringen muss.** Wert, Unsicherheit, Zahl der Stützstellen und, wo es sie
gibt, den Restfehler des Modells. Ohne Unsicherheit gibt es keine Prüfung, und ohne Prüfung kein
Lernen, sondern nur Überschreiben.

Reine Funktionen über bereits gerechneten Ergebnissen. Kein I/O, keine Datenbank.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

from hems_core.thermal.kennlinie import Ausgleich
from hems_core.thermal.kontaktwirkung import Kontaktwirkung

#: Anteil des Endwerts, bei dem die Zeitkonstante einer Verzögerung erster Ordnung erreicht ist.
ANTEIL_T1 = 0.632
#: Weniger Ereignisse als diese lassen keine Aussage über eine Totzeit zu.
MIN_EREIGNISSE = 6


@dataclass(frozen=True)
class Kandidat:
    """Ein Vorschlag an die Lernebene."""

    pid: str
    wert: float
    #: Unsicherheit (1σ) in der Einheit des Parameters.
    sigma: float
    #: Zahl der Stützstellen, auf denen der Vorschlag beruht.
    n: int
    #: Restfehler des Modells, aus dem er kommt. `None`, wenn das Verfahren keinen liefert.
    rmse: float | None = None


def aus_kennlinie(a: Ausgleich) -> list[Kandidat]:
    """Die drei Zahlen der COP-Ebene aus der gemessenen Kennlinie.

    **Die Unsicherheit kommt aus dem Restfehler und der Spanne der Punkte.** Für die Steigung
    einer Ausgleichsgeraden ist sie ``σ_rest / (√n · Spanne/√12)``: je größer der gemessene
    Temperaturbereich, desto sicherer die Steigung. Das ist nicht nur Formelwerk - es ist der
    Grund, warum eine Kennlinie aus einer einzigen Kältewoche die Vorlaufabhängigkeit nicht
    hergibt.

    **Was `art` sagt, wird respektiert.** Ließ sich ein Term aus den Punkten nicht bestimmen, hat
    `ausgleich` ihn auf null gesetzt, statt eine Zahl zu erfinden. Ein solcher Term wird hier
    nicht als Kandidat vorgeschlagen: eine Null ist keine Messung.
    """
    aus: list[Kandidat] = []
    if a.n < 3:
        return aus
    wurzel_n = math.sqrt(a.n)
    aus.append(Kandidat(pid="cop_a", wert=a.a, sigma=a.rmse / wurzel_n, n=a.n, rmse=a.rmse))
    spanne_aussen = a.aussen_bis_c - a.aussen_von_c
    spanne_vorlauf = a.vorlauf_bis_c - a.vorlauf_von_c
    if a.art in ("ebene", "aussen") and spanne_aussen > 1.0:
        streu = spanne_aussen / math.sqrt(12.0)
        aus.append(
            Kandidat(
                pid="cop_b",
                wert=a.b_aussen,
                sigma=a.rmse / (wurzel_n * streu),
                n=a.n,
                rmse=a.rmse,
            )
        )
    if a.art in ("ebene", "vorlauf") and spanne_vorlauf > 1.0:
        streu = spanne_vorlauf / math.sqrt(12.0)
        aus.append(
            Kandidat(
                pid="cop_c",
                wert=a.c_vorlauf,
                sigma=a.rmse / (wurzel_n * streu),
                n=a.n,
                rmse=a.rmse,
            )
        )
    return aus


def _median(werte: list[float]) -> float:
    s = sorted(werte)
    mitte = len(s) // 2
    return s[mitte] if len(s) % 2 else (s[mitte - 1] + s[mitte]) / 2.0


def aus_kontaktwirkung(w: Kontaktwirkung) -> list[Kandidat]:
    """Totzeit und Anlaufzeitkonstante der Wärmepumpe aus der Ereignisstudie zu K1.

    **Die Totzeit ist der Median der Anlaufverzögerungen**, nicht ihr Mittel: einzelne Ereignisse
    laufen weit nach, weil die Maschine aus anderen Gründen gerade nicht wollte, und ein Mittel
    würde von diesen Ausreißern getragen. Die Unsicherheit ist die Streuung der Verzögerungen,
    durch die Wurzel ihrer Zahl geteilt.

    **Die Zeitkonstante kommt aus dem Fächer**, also aus den übereinandergelegten
    Leistungsverläufen. Gesucht wird die Minute, in der der Median 63,2 % seines Endwerts erreicht;
    davon ab die Totzeit, und übrig bleibt T1. Das ist die Auswertung einer Sprungantwort, nur
    über viele Sprünge statt über einen - und damit das Einzige, was in einem bewohnten Haus
    zulässig ist.

    Liefert nur, was die Daten tragen: zu wenige Ereignisse, keine Kandidaten.
    """
    aus: list[Kandidat] = []
    verzug = [
        float(e.verzoegerung_min)
        for e in w.ereignisse
        if e.auswertbar and e.gefolgt and e.verzoegerung_min is not None
    ]
    if len(verzug) < MIN_EREIGNISSE:
        return aus
    # Den Median rechnet die Ereignisstudie selbst; er wird hier nicht zum zweiten Mal gebildet.
    # Gebraucht werden die einzelnen Verzögerungen nur noch für die Streuung.
    tt = w.verzoegerung_median_min if w.verzoegerung_median_min is not None else _median(verzug)
    mittel = sum(verzug) / len(verzug)
    streuung = math.sqrt(sum((v - mittel) ** 2 for v in verzug) / max(1, len(verzug) - 1))
    aus.append(
        Kandidat(
            pid="wp_totzeit",
            wert=max(0.5, tt),
            sigma=max(0.2, streuung / math.sqrt(len(verzug))),
            n=len(verzug),
            rmse=streuung,
        )
    )
    t1 = _zeitkonstante(w, tt)
    if t1 is not None:
        aus.append(
            Kandidat(
                pid="wp_t1",
                wert=t1,
                # Die Zeitkonstante hängt an einer einzigen Schwelle im Median; ihre Unsicherheit
                # ist deshalb grob mit einem Fünftel ihres Werts angesetzt und nicht gerechnet.
                sigma=max(1.0, t1 * 0.2),
                n=len(verzug),
                rmse=streuung,
            )
        )
    return aus


def _zeitkonstante(w: Kontaktwirkung, totzeit_min: float) -> float | None:
    """Die Minute, in der der Median des Fächers 63,2 % seines Endwerts erreicht, minus Totzeit."""
    minuten = w.faecher.minuten
    median = w.faecher.median_kw
    if len(minuten) != len(median) or len(minuten) < 10:
        return None
    nach = [(m, v) for m, v in zip(minuten, median, strict=True) if v is not None and m >= 0]
    vor = [v for m, v in zip(minuten, median, strict=True) if v is not None and m < 0]
    if len(nach) < 10:
        return None
    grund = _median(vor) if vor else 0.0
    spaet = [v for m, v in nach if m >= nach[-1][0] * 0.6]
    if not spaet:
        return None
    endwert = _median(spaet)
    hub = endwert - grund
    if hub < w.schwelle_kw:
        return None
    schwelle = grund + ANTEIL_T1 * hub
    for m, v in nach:
        if v >= schwelle:
            t1 = float(m) - totzeit_min
            return t1 if t1 >= 0.5 else None
    return None


def aus_abkuehlung(
    *,
    kelvin_je_stunde: float,
    uebertemperatur_k: float,
    kapazitaet_kwh_k: float,
    stunden: float,
    streuung_k_je_stunde: float,
) -> Kandidat | None:
    """Der Verlustbeiwert des Puffers aus seiner Abkühlung in einer Nacht ohne Betrieb.

    In einer Nacht, in der weder ein Erzeuger läuft noch gezapft wird, ist die einzige Senke die
    Hülle des Speichers:

        C · dT/dt = −UA · (T̄ − Tu)   →   UA = C · (dT/dt) / (T̄ − Tu)

    Deshalb ist diese Messung so sauber wie keine andere der Wärmeseite: alles andere steht still.
    Sie braucht nur Geduld - verwertbare Nächte gibt es wenige, und jede liefert einen Punkt.

    Gibt `None` zurück, wenn die Nacht nichts hergibt: zu kleine Übertemperatur, zu kurz, oder
    eine Abkühlung, die in die falsche Richtung läuft.
    """
    if uebertemperatur_k < 5.0 or stunden < 2.0 or kelvin_je_stunde <= 0 or kapazitaet_kwh_k <= 0:
        return None
    ua_w_k = kapazitaet_kwh_k * kelvin_je_stunde / uebertemperatur_k * 1000.0
    sigma = kapazitaet_kwh_k * streuung_k_je_stunde / uebertemperatur_k * 1000.0
    return Kandidat(pid="puffer_ua", wert=ua_w_k, sigma=max(0.2, sigma), n=int(stunden * 60))
