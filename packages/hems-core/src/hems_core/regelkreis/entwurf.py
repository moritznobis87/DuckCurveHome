"""Reglerentwurf aus den gelernten Streckenparametern, und die Prüfung des Ergebnisses.

**Warum der Regler nicht eingestellt, sondern berechnet wird.** Die Zahlen der Strecke ändern sich:
der Estrich ist träger als angenommen, die Wärmepumpe läuft später an, der Mischer wirkt schwächer.
Wer den Regler einmal von Hand einstellt, hat ihn für den Zustand des Hauses an einem Tag
eingestellt. Hier geht es anders herum - die Lernebene liefert das Modell, und aus dem Modell folgt
der Regler nach einer festen Regel. Das ist ein **indirekter selbsteinstellender Regler**: erst
schätzen, dann entwerfen, und beides getrennt prüfbar.

**Die Regel ist SIMC** (Skogestad). Gewählt aus drei Gründen. Sie braucht nur Verstärkung,
Zeitkonstante und Totzeit, und genau diese drei Zahlen liefert eine Sprungantwort. Sie hat eine
einzige freie Größe, die Ersatzzeitkonstante λ, und die lässt sich einem Menschen erklären: so
schnell soll der Kreis sein. Und sie ist für Strecken mit Totzeit und für Integrierer geschlossen
angegeben - beides kommt in diesem Haus vor, der Puffer ist ein Integrierer, der Vorlauf eine
Strecke erster Ordnung mit Laufzeit.

**Zwei Zeitkonstanten werden zu einer.** Der Raum hat zwei Speicher, Estrich und Luft. Skogestads
Halbregel schlägt die halbe kleinere Zeitkonstante der großen zu und die andere Hälfte der Totzeit.
Das ist nicht hübsch, aber es ist die ehrlichere Näherung als ein gemittelter Wert: die Trägheit
bleibt Trägheit, und die verlorene Phase bleibt verlorene Phase.

**Geprüft wird im Frequenzbereich**, und die Phase wird dabei nicht aus einer Arkustangens-Funktion
mit Vorzeichensprüngen gelesen, sondern aus den Summanden der Glieder gebildet. Die Phase einer
Totzeit wächst ohne Grenze; jede Funktion, die sie auf ±180° zurückfaltet, verliert genau die
Information, um die es hier geht.

Reine Funktionen auf Gleitkommazahlen. Kein I/O, keine Konfiguration, keine Zeitzone.
"""

from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass
from itertools import pairwise
from typing import Literal

#: Art der Strecke. `foptd`: Verstärkung, eine oder zwei Zeitkonstanten, Totzeit.
#: `iptd`: Integrierer mit Totzeit - die Stellgröße ändert die Regelgröße, statt sie zu setzen.
Streckenart = Literal["foptd", "iptd"]

#: Unterhalb dieser Kreisfrequenz wird nicht gesucht (Periode rund 100 Tage).
W_MIN = 1e-5
#: Oberhalb dieser Kreisfrequenz auch nicht (Periode rund 6 Sekunden).
W_MAX = 60.0
#: Stützstellen je Dekade für die Suche nach den Durchtritten.
JE_DEKADE = 48


@dataclass(frozen=True)
class Strecke:
    """Das Streckenmodell eines Kreises, in Minuten.

    `k` ist bei `foptd` die statische Verstärkung (Regelgröße je Stellgröße), bei `iptd` der
    Integrierbeiwert k′ (Änderung der Regelgröße je Stellgröße **und Minute**).
    """

    art: Streckenart
    k: float
    totzeit: float
    t1: float = 0.0
    t2: float = 0.0

    def __post_init__(self) -> None:
        if self.k == 0.0:
            raise ValueError("Strecke ohne Verstärkung")
        if self.totzeit < 0 or self.t1 < 0 or self.t2 < 0:
            raise ValueError("negative Zeiten")

    def halbregel(self) -> Strecke:
        """Skogestads Halbregel: die kleinere Zeitkonstante halb zur großen, halb zur Totzeit.

        Bei einer Strecke ohne zweite Zeitkonstante ändert sie nichts.
        """
        if self.t2 <= 0.0:
            return self
        klein, gross = sorted((self.t1, self.t2))
        return Strecke(
            art=self.art, k=self.k, totzeit=self.totzeit + klein / 2.0, t1=gross + klein / 2.0
        )


@dataclass(frozen=True)
class Regler:
    """Ein PI-Regler, wie ihn der Entwurf liefert."""

    kp: float
    #: Nachstellzeit in Minuten. `None` hieße reiner P-Regler; den gibt es hier nicht.
    tn: float
    #: Die Entwurfsgröße, aus der er folgt.
    lam: float
    regel: str = "SIMC"


def simc(s: Strecke, lam: float) -> Regler:
    """Der PI-Regler nach SIMC für diese Strecke und diese Ersatzzeitkonstante.

    Für die Strecke erster Ordnung mit Totzeit:   Kp = T1 / (K·(λ + Tt)),  Tn = min(T1, 4(λ + Tt)).
    Für den Integrierer mit Totzeit:              Kp = 1 / (k′·(λ + Tt)),  Tn = 4(λ + Tt).

    Die Begrenzung der Nachstellzeit auf das Vierfache von (λ + Tt) ist der Teil der Regel, der
    gegen Störungen hilft: ohne sie wird der Integralanteil bei trägen Strecken so langsam, dass
    eine Laststörung stundenlang stehen bleibt. Beim Estrich dieses Hauses greift genau das.
    """
    if lam <= 0:
        raise ValueError("λ muss positiv sein")
    tau_c = lam + s.totzeit
    if s.art == "iptd":
        return Regler(kp=1.0 / (s.k * tau_c), tn=4.0 * tau_c, lam=lam)
    if s.t2 > 0.0:
        raise ValueError("vor dem Entwurf die Halbregel anwenden")
    return Regler(kp=s.t1 / (s.k * tau_c), tn=min(s.t1, 4.0 * tau_c), lam=lam)


def betrag(r: Regler, s: Strecke, w: float) -> float:
    """Betrag des offenen Kreises |L(jω)| bei ω in rad/min."""
    pi_anteil = r.kp * math.hypot(1.0, 1.0 / (w * r.tn))
    if s.art == "iptd":
        strecke = abs(s.k) / w
    else:
        strecke = abs(s.k) / math.hypot(1.0, w * s.t1)
        if s.t2 > 0.0:
            strecke /= math.hypot(1.0, w * s.t2)
    return pi_anteil * strecke


def phase_grad(r: Regler, s: Strecke, w: float) -> float:
    """Phase des offenen Kreises in Grad, stetig und ohne Rückfaltung.

    Summe der Beiträge: PI zwischen −90° und 0°, jede Zeitkonstante bis −90°, der Integrierer
    genau −90°, und die Totzeit linear mit ω ohne Grenze. Weil hier summiert und nicht ein
    komplexer Zeiger ausgewertet wird, bleibt die Kurve monoton fallend - das ist die Voraussetzung
    dafür, dass die Suche nach dem −180°-Durchtritt eine eindeutige Antwort hat.
    """
    phase = -math.degrees(math.atan2(1.0 / (w * r.tn), 1.0))
    if s.art == "iptd":
        phase -= 90.0
    else:
        phase -= math.degrees(math.atan(w * s.t1))
        if s.t2 > 0.0:
            phase -= math.degrees(math.atan(w * s.t2))
    phase -= math.degrees(w * s.totzeit)
    return phase


@dataclass(frozen=True)
class Reserven:
    """Was der geschlossene Kreis an Sicherheit übrig hat."""

    #: Durchtrittsfrequenz in rad/min: dort ist |L| = 1.
    durchtritt: float | None
    #: Zugehörige Periode in Minuten - die Zahl, die ein Mensch wiedererkennt.
    periode: float | None
    #: Phasenreserve in Grad. Unter 45° wird der Kreis gegen Änderungen der Strecke empfindlich.
    phasenreserve: float | None
    #: Amplitudenreserve als Faktor. `None` heißt: die Phase erreicht −180° nie.
    amplitudenreserve: float | None
    #: Wo die Phase −180° erreicht.
    w_180: float | None

    @property
    def gut(self) -> bool:
        """Faustregel: 45° Phase und Faktor 2,5 in der Amplitude."""
        if self.phasenreserve is None or self.phasenreserve < 45.0:
            return False
        return self.amplitudenreserve is None or self.amplitudenreserve >= 2.5


def _nullstelle(f: Callable[[float], float], lo: float, hi: float) -> float:
    """Bisektion auf der logarithmischen Achse. Der Aufrufer garantiert den Vorzeichenwechsel.

    Logarithmisch, weil die gesuchten Frequenzen über Dekaden liegen: linear halbiert, wäre die
    Suche nach einer Durchtrittsfrequenz von 10⁻³ rad/min eine Suche im Rauschen der Gleitkommazahl.
    """
    a, b = math.log(lo), math.log(hi)
    fa = f(math.exp(a))
    for _ in range(60):
        m = (a + b) / 2.0
        fm = f(math.exp(m))
        if (fm > 0) == (fa > 0):
            a, fa = m, fm
        else:
            b = m
    return math.exp((a + b) / 2.0)


def reserven(r: Regler, s: Strecke) -> Reserven:
    """Durchtritt, Phasen- und Amplitudenreserve, numerisch gesucht.

    Gesucht wird auf einem logarithmischen Raster über acht Dekaden und dann durch Bisektion
    verfeinert. Beide gesuchten Funktionen sind monoton fallend (der Betrag, weil jeder Nenner mit
    ω wächst; die Phase, weil jeder Summand mit ω fällt), deshalb ist der erste Vorzeichenwechsel
    der einzige.
    """
    stufen = int(JE_DEKADE * math.log10(W_MAX / W_MIN))
    gitter = [W_MIN * (W_MAX / W_MIN) ** (i / stufen) for i in range(stufen + 1)]

    wc: float | None = None
    for lo, hi in pairwise(gitter):
        if betrag(r, s, lo) >= 1.0 > betrag(r, s, hi):
            wc = _nullstelle(lambda w: betrag(r, s, w) - 1.0, lo, hi)
            break
    w180: float | None = None
    for lo, hi in pairwise(gitter):
        if phase_grad(r, s, lo) >= -180.0 > phase_grad(r, s, hi):
            w180 = _nullstelle(lambda w: phase_grad(r, s, w) + 180.0, lo, hi)
            break
    return Reserven(
        durchtritt=wc,
        periode=2.0 * math.pi / wc if wc else None,
        phasenreserve=180.0 + phase_grad(r, s, wc) if wc else None,
        amplitudenreserve=1.0 / betrag(r, s, w180) if w180 else None,
        w_180=w180,
    )


@dataclass(frozen=True)
class Punkt:
    """Eine Stützstelle der Frequenzkennlinie, fertig zum Zeichnen."""

    w: float
    db: float
    grad: float


def kennlinie(r: Regler, s: Strecke, von: float, bis: float, punkte: int = 120) -> list[Punkt]:
    """Frequenzkennlinie des offenen Kreises, logarithmisch gleichmäßig."""
    if von <= 0 or bis <= von or punkte < 2:
        raise ValueError("unbrauchbarer Frequenzbereich")
    out: list[Punkt] = []
    for i in range(punkte):
        w = von * (bis / von) ** (i / (punkte - 1))
        out.append(Punkt(w=w, db=20.0 * math.log10(betrag(r, s, w)), grad=phase_grad(r, s, w)))
    return out


# --------------------------------------------------------------------------------------------
# Die Strecken dieses Hauses. Hier steht die Physik, die aus Parametern ein Modell macht.
# --------------------------------------------------------------------------------------------


def puffer_strecke(*, waerme_kw: float, kapazitaet_kwh_k: float, totzeit_min: float) -> Strecke:
    """Der Puffer als Integrierer mit Totzeit.

    **Warum Integrierer und nicht Verzögerungsglied.** Der Speicher verliert über seine Hülle, und
    daraus ließe sich eine Zeitkonstante C/UA bilden - sie liegt bei rund zweihundert Stunden.
    Gegen die Stunden, über die hier geregelt wird, ist das unendlich. Ein Modell, das diese
    Zeitkonstante mitführt, behauptet eine Rückführung, die es nicht gibt: wer die Freigabe stehen
    lässt, kocht den Speicher, er läuft nicht in einen Endwert.

    Der Beiwert ist die Temperaturänderung je Minute bei voller Freigabe.
    """
    if kapazitaet_kwh_k <= 0:
        raise ValueError("Puffer ohne Kapazität")
    return Strecke(art="iptd", k=waerme_kw / kapazitaet_kwh_k / 60.0, totzeit=totzeit_min)


def vorlauf_strecke(*, verstaerkung_k_prozent: float, t1_min: float, totzeit_min: float) -> Strecke:
    """Mischer, Pumpe und Rohrinhalt: Verzögerung erster Ordnung mit Transportzeit."""
    return Strecke(art="foptd", k=verstaerkung_k_prozent, t1=t1_min, totzeit=totzeit_min)


def raum_strecke(
    *,
    c_estrich_kwh_k: float,
    r_estrich_luft_k_kw: float,
    c_luft_kwh_k: float,
    h_raum_kw_k: float,
    q_max_kw: float,
    autoritaet: float,
    totzeit_min: float,
) -> Strecke:
    """Der Raum als Zwei-Knoten-Modell, in die Form des Entwurfs gebracht.

    Die beiden Zeitkonstanten kommen aus den Knoten, nicht aus einer Anpassung:

    * Estrich: ``T1 = CEstrich · RE→L`` - der Speicher gegen den Widerstand, über den er abgibt.
    * Raumluft: ``T2 = CLuft / (1/RE→L + HRaum)`` - der kleine Speicher gegen alles, was an ihm
      hängt, den Estrich und die Hülle.

    Die statische Verstärkung ist die Temperaturerhöhung bei vollem Hub: ``Q̇max · av / HRaum``,
    auf ein Prozent Hub bezogen. Dass die Ventilautorität hier als Faktor steht, ist eine
    Linearisierung - sie gilt im Arbeitsbereich und ist genau der Grund, warum der Hub vorher
    vorverzerrt wird.
    """
    if r_estrich_luft_k_kw <= 0 or h_raum_kw_k <= 0:
        raise ValueError("Raum ohne Widerstand oder ohne Verlust")
    t1 = c_estrich_kwh_k * r_estrich_luft_k_kw * 60.0
    t2 = c_luft_kwh_k / (1.0 / r_estrich_luft_k_kw + h_raum_kw_k) * 60.0
    k = q_max_kw * autoritaet / 100.0 / h_raum_kw_k
    return Strecke(art="foptd", k=k, t1=t1, t2=t2, totzeit=totzeit_min)


def hysterese(
    *, auf_k_min: float, ab_k_min: float, starts_je_tag: int, mindestens_k: float = 1.0
) -> float:
    """Die Hysteresebreite am Kontakt, aus der Taktzahlgrenze gerechnet.

    **Warum die Breite nicht gewählt, sondern abgeleitet wird.** K1 ist ein Kontakt, der Regler
    also ein Zweipunktregler, und dessen Taktzahl folgt aus der Breite seiner Schaltdifferenz und
    den Steigungen davor und danach. Umgekehrt gelesen: wer höchstens acht Starts am Tag erlauben
    will, hat die Breite damit festgelegt und braucht sie nicht zu raten.

        Tzyklus = Δ/ṙauf + Δ/ṙab   →   Δ = Tzyklus / (1/ṙauf + 1/ṙab)

    Beide Steigungen kommen aus gelernten Größen: die Ladesteigung aus Leistung und Kapazität, die
    Entladesteigung aus dem geschätzten Abfluss. Steigt der Verbrauch, wird die Hysterese von
    selbst breiter - und das ist richtig, weil sonst die Taktzahl steigt.

    `mindestens_k` ist die Fühlerauflösung: unter einem Kelvin schaltet man auf Rauschen.
    """
    if starts_je_tag < 1:
        raise ValueError("mindestens ein Start je Tag")
    if auf_k_min <= 0 or ab_k_min <= 0:
        return mindestens_k
    zyklus = 24.0 * 60.0 / starts_je_tag
    return max(mindestens_k, zyklus / (1.0 / auf_k_min + 1.0 / ab_k_min))
