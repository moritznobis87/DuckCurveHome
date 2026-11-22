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
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta, tzinfo

from hems_core.domain.config import BufferConfig, HeatDemandConfig
from hems_core.thermal.heat_balance import HeatPoint, HeatSample, mean_temperature_c
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
    # `n` ist eins: eine Nacht ist **eine** Beobachtung. Ihre Minuten sind nicht unabhängig,
    # und sie als Stützstellen zu zählen hiesse, der Übernahmeprüfung Daten vorzutäuschen.
    return Kandidat(pid="puffer_ua", wert=ua_w_k, sigma=max(0.2, sigma), n=1)


#: Wie viele Minuten einer Stunde auswertbar sein müssen, damit sie als Stützstelle zählt.
MIN_MINUTEN_JE_STUNDE = 45
#: Mehr Wärme als das zieht dieses Haus nicht; darüber ist die Bilanz entgleist.
MAX_BEDARF_KW = 20.0
#: So schnell kühlt ein stehender Speicher nicht ab. Darüber war jemand am Wasser.
MAX_ABKUEHLUNG_K_H = 0.6
#: Unter dieser Leistung läuft die Wärmepumpe nicht.
STEHT_KW = 0.3
#: Grössere Lücken zwischen zwei Minuten trennen zwei Strecken.
MAX_LUECKE_MIN = 5.0


def _loese3(a: list[list[float]], b: list[float]) -> list[float] | None:
    """Drei Gleichungen, drei Unbekannte, Gauß mit Spaltenpivot. Mehr braucht es hier nicht."""
    m = [[*row, b[i]] for i, row in enumerate(a)]
    for i in range(3):
        p = max(range(i, 3), key=lambda r: abs(m[r][i]))
        if abs(m[p][i]) < 1e-12:
            return None
        m[i], m[p] = m[p], m[i]
        for r in range(3):
            if r == i:
                continue
            f = m[r][i] / m[i][i]
            for c in range(i, 4):
                m[r][c] -= f * m[i][c]
    return [m[i][3] / m[i][i] for i in range(3)]


def aus_waermebilanz(
    samples: Sequence[HeatSample],
    punkte: Sequence[HeatPoint],
    *,
    heat: HeatDemandConfig,
    zeitzone: tzinfo,
) -> list[Kandidat]:
    """Verlustkoeffizient, interne Gewinne und Warmwasserbedarf aus der Wärmebilanz.

    **Das Modell, und warum es drei Glieder hat.** Was aus dem Speicher geht, ist Heizung **und**
    Warmwasser; wer nur gegen die Temperaturdifferenz anpasst, schreibt die Zapfungen in den
    Verlustkoeffizienten hinein und bekommt ein zu undichtes Haus. Deshalb:

        Q̇bedarf(h) = H · (Ti − Ta) − Q̇int + Q̇WW,tag · p(h)

    `p(h)` ist das Tagesprofil der Zapfungen aus der Konfiguration, auf eins normiert. Alle drei
    Glieder sind in ihren Parametern linear, also genügt ein Ausgleich - und er trennt, was sonst
    vermischt bliebe: H aus der Steigung über der Temperaturdifferenz, die Gewinne aus dem
    Achsabschnitt, das Warmwasser aus der Form des Tages.

    **Was dazugerechnet wird.** Die Raumwärme des Ofens, denn sie deckt Bedarf, der sonst durch
    den Speicher gegangen wäre. Ohne sie sähe jede Ofenstunde aus wie ein dichteres Haus.

    **Was ausgeschlossen wird.** Stunden über der Heizgrenze (dort ist das Modell nicht gemeint),
    Stunden mit zu wenigen auswertbaren Minuten, und alles, was jenseits dessen liegt, was dieses
    Haus ziehen kann. Die Zeitstempel werden in die übergebene Zeitzone gerechnet, denn das
    Zapfprofil folgt dem Tag der Bewohner und nicht dem von Greenwich.
    """
    if len(samples) != len(punkte):
        raise ValueError("zu jeder Probe gehört ein Punkt der Bilanz")
    profil = list(heat.dhw_profile)
    summe = sum(profil)
    if len(profil) != 24 or summe <= 0:
        return []
    gewicht = [w / summe for w in profil]

    # Stundenmittel bilden: Bedarf, Temperaturdifferenz, Profilwert.
    eimer: dict[datetime, list[tuple[float, float, int]]] = {}
    for s, p in zip(samples, punkte, strict=True):
        if p.unknown or s.outdoor_c is None:
            continue
        ort = s.at.astimezone(zeitzone)
        key = ort.replace(minute=0, second=0, microsecond=0)
        eimer.setdefault(key, []).append((p.draw_kw + p.stove_room_kw, s.outdoor_c, ort.hour))

    x_zeilen: list[list[float]] = []
    y_werte: list[float] = []
    for key in sorted(eimer):
        rows = eimer[key]
        if len(rows) < MIN_MINUTEN_JE_STUNDE:
            continue
        bedarf = sum(r[0] for r in rows) / len(rows)
        aussen = sum(r[1] for r in rows) / len(rows)
        if aussen >= heat.heating_limit_c or not 0.0 <= bedarf <= MAX_BEDARF_KW:
            continue
        x_zeilen.append([heat.indoor_target_c - aussen, 1.0, gewicht[rows[0][2]]])
        y_werte.append(bedarf)

    n = len(x_zeilen)
    if n < 24:
        return []
    # Normalgleichungen: XᵀX θ = Xᵀy. Bei drei Unbekannten ist das die kürzeste ehrliche Lösung.
    xtx = [[sum(x[i] * x[j] for x in x_zeilen) for j in range(3)] for i in range(3)]
    xty = [sum(x[i] * y for x, y in zip(x_zeilen, y_werte, strict=True)) for i in range(3)]
    theta = _loese3(xtx, xty)
    if theta is None:
        return []
    rest = [
        y - sum(t * xi for t, xi in zip(theta, x, strict=True))
        for x, y in zip(x_zeilen, y_werte, strict=True)
    ]
    s2 = sum(r * r for r in rest) / max(1, n - 3)
    rmse = math.sqrt(s2)
    # Die Unsicherheit je Parameter aus der Diagonale von (XᵀX)⁻¹ - gelöst über drei Einheitsvektoren.
    sigma: list[float] = []
    for i in range(3):
        e = [1.0 if j == i else 0.0 for j in range(3)]
        spalte = _loese3([row[:] for row in xtx], e)
        sigma.append(math.sqrt(max(0.0, (spalte[i] if spalte else 0.0) * s2)))

    aus: list[Kandidat] = []
    h, minus_int, ww = theta
    aus.append(Kandidat(pid="h_haus", wert=h, sigma=max(1e-4, sigma[0]), n=n, rmse=rmse))
    aus.append(Kandidat(pid="q_intern", wert=-minus_int, sigma=max(1e-3, sigma[1]), n=n, rmse=rmse))
    # Der Warmwasserbedarf steckt in jeder Stunde nur zu einem Bruchteil; ohne Stunden aus der
    # Morgen- und Abendspitze ist er nicht bestimmt, und dann wird er auch nicht vorgeschlagen.
    spitze = sum(1 for x in x_zeilen if x[2] >= 2.0 / 24.0)
    if spitze >= 6:
        aus.append(Kandidat(pid="ww_tag", wert=ww, sigma=max(0.05, sigma[2]), n=n, rmse=rmse))
    return aus


@dataclass(frozen=True)
class Nacht:
    """Eine Strecke, in der der Speicher nichts tut außer abzukühlen."""

    von: datetime
    bis: datetime
    stunden: float
    kelvin_je_stunde: float
    uebertemperatur_k: float


def stille_strecken(
    samples: Sequence[HeatSample],
    *,
    buffer: BufferConfig,
    heat: HeatDemandConfig,
    mindest_stunden: float = 2.0,
) -> list[Nacht]:
    """Strecken finden, in denen weder erzeugt noch spürbar entnommen wird.

    **Warum diese Strecken so wertvoll sind.** In ihnen ist die einzige Senke die Hülle des
    Speichers; alles andere steht still. Das ist die sauberste Messung, die die Wärmeseite dieses
    Hauses hergibt - sie braucht nur Geduld, denn verwertbare Nächte gibt es wenige.

    **Warum nur ausserhalb der Heizzeit.** Still heisst nicht, dass die Erzeuger stehen - still
    heisst, dass **niemand** etwas entnimmt. Solange das Haus geheizt wird, zieht der Heizkreis
    auch nachts, und zwar um ein Vielfaches mehr als die Hülle des Speichers verliert: ein Kelvin
    je Stunde sind bei tausend Litern 1,2 kW, der Stillstandsverlust dagegen rund 0,2. Wer in der
    Heizzeit misst, schreibt die Heizung in den Verlustbeiwert und bekommt einen Speicher, der
    fünfmal schlechter gedämmt ist, als er ist.

    Verwertbare Strecken liegen deshalb **über der Heizgrenze** - im Sommer, wenn der Speicher nur
    noch das Warmwasser hält. Davon gibt es wenige, und bis zur ersten bleibt der Beiwert eine
    Annahme. Das ist langsamer als eine Schätzung aus Winternächten und das einzige, was trägt.

    **Woran eine Zapfung erkannt wird.** An der Geschwindigkeit. Ein stehender Speicher verliert
    Zehntelgrade je Stunde; wer Wasser zapft, sieht Grade. Strecken, die schneller abkühlen als
    `MAX_ABKUEHLUNG_K_H`, werden verworfen, und ebenso solche, in denen die oberste Schicht
    deutlich schneller fällt als das Mittel - das ist die Handschrift einer Entnahme oben.
    """
    aus: list[Nacht] = []
    lauf: list[HeatSample] = []

    def pruefe(strecke: list[HeatSample]) -> None:
        if len(strecke) < 2:
            return
        stunden = (strecke[-1].at - strecke[0].at).total_seconds() / 3600.0
        if stunden < mindest_stunden:
            return
        temps = [s.buffer_c for s in strecke]
        if any(t is None for t in temps):
            return
        mittel = [mean_temperature_c(list(t), buffer) for t in temps if t is not None]
        oben = [t[0] for t in temps if t is not None]
        fall = (mittel[0] - mittel[-1]) / stunden
        fall_oben = (oben[0] - oben[-1]) / stunden
        if not 0.0 < fall <= MAX_ABKUEHLUNG_K_H:
            return
        if fall_oben > 2.0 * fall + 0.2:
            return
        uebertemperatur = sum(mittel) / len(mittel) - buffer.ambient_c
        aus.append(
            Nacht(
                von=strecke[0].at,
                bis=strecke[-1].at,
                stunden=stunden,
                kelvin_je_stunde=fall,
                uebertemperatur_k=uebertemperatur,
            )
        )

    for s in samples:
        ausserhalb = s.outdoor_c is not None and s.outdoor_c >= heat.heating_limit_c
        still = (
            ausserhalb
            and (s.heat_pump_kw is None or s.heat_pump_kw < STEHT_KW)
            and not s.stove_running
        )
        # Eine Lücke in den Daten unterbricht die Strecke. Ohne das würden zwei stille Nächte mit
        # einem fehlenden Tag dazwischen zu einer Strecke, und die Abkühlung würde über Stunden
        # gerechnet, von denen niemand weiss, was in ihnen geschah.
        lueckig = bool(lauf) and (s.at - lauf[-1].at) > timedelta(minutes=MAX_LUECKE_MIN)
        if still and s.buffer_c and not lueckig:
            lauf.append(s)
        else:
            pruefe(lauf)
            lauf = [s] if still and s.buffer_c else []
    pruefe(lauf)
    return aus


def aus_naechten(
    samples: Sequence[HeatSample],
    *,
    buffer: BufferConfig,
    heat: HeatDemandConfig,
    kapazitaet_kwh_k: float,
) -> Kandidat | None:
    """Der Verlustbeiwert des Speichers aus allen stillen Strecken einer Reihe.

    Jede Strecke liefert einen Punkt; genommen wird ihr Median, denn eine einzelne Nacht mit einer
    unbemerkten Zapfung soll das Ergebnis nicht tragen. Die Unsicherheit ist die Streuung der
    Punkte, durch die Wurzel ihrer Zahl geteilt - und `n` zählt Nächte und nicht Minuten, weil
    zwei Minuten derselben Nacht nichts Unabhängiges sagen.
    """
    werte: list[float] = []
    for nacht in stille_strecken(samples, buffer=buffer, heat=heat):
        k = aus_abkuehlung(
            kelvin_je_stunde=nacht.kelvin_je_stunde,
            uebertemperatur_k=nacht.uebertemperatur_k,
            kapazitaet_kwh_k=kapazitaet_kwh_k,
            stunden=nacht.stunden,
            streuung_k_je_stunde=0.02,
        )
        if k is not None:
            werte.append(k.wert)
    if not werte:
        return None
    mitte = _median(werte)
    mittel = sum(werte) / len(werte)
    streuung = (
        math.sqrt(sum((w - mittel) ** 2 for w in werte) / max(1, len(werte) - 1))
        if len(werte) > 1
        else mitte * 0.3
    )
    return Kandidat(
        pid="puffer_ua",
        wert=mitte,
        sigma=max(0.2, streuung / math.sqrt(len(werte))),
        n=len(werte),
        rmse=streuung,
    )
