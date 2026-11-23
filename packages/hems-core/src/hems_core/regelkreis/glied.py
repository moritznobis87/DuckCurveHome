"""Was für ein Übertragungsglied jeder Block ist - und wie man es an seiner Antwort erkennt.

**Warum die Einordnung in den Kern gehört.** „Der Puffer ist ein Integrierer mit nachgeschalteter
Verzögerungskette" ist keine Beschriftung, sondern eine Behauptung über das Haus, aus der der
Reglerentwurf folgt. Sie ist nachprüfbar und widerlegbar und steht deshalb neben dem Modell, nicht
in der Zeichnung.

**Warum die Sprungantwort mitgeliefert wird.** Im Blockschaltbild trägt jedes Kästchen seit jeher
das Bild seiner Antwort: ein Strich hoch für das P-Glied, eine Gerade für den Integrierer, eine
Exponentialkurve für PT1, ein Knick nach rechts für die Totzeit. Wer das Bild kennt, braucht die
Formel nicht zu lesen - und wer sie liest, prüft das Bild. Die Kurven sind deshalb hier gerechnet
und nicht in der Anzeige gemalt: sie folgen aus der Übertragungsfunktion.

**Statische Glieder zeigen keine Sprungantwort, sondern ihre Kennlinie.** Bei einem
Begrenzungsglied oder einer Division ist die Zeit nicht interessant, die Krümmung aber sehr. Was
ein Bild zeigt, sagt `art`.

Reine Funktionen auf Gleitkommazahlen. Die Kurven sind auf das Einheitsquadrat normiert; ihre
Zahlenwerte sind Form und keine Messung.
"""

from __future__ import annotations

import math
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Literal

#: Was das kleine Bild im Kästchen zeigt.
#:
#: * `sprung` - die Antwort auf einen Sprung am Eingang, über der Zeit.
#: * `kennlinie` - der Zusammenhang Ausgang über Eingang, ohne Zeit.
#: * `takt` - eine abgetastete und gehaltene Größe, als Treppe.
Bildart = Literal["sprung", "kennlinie", "takt"]

#: Wozu das Glied im Kreis gehört.
Kategorie = Literal["strecke", "regler", "messglied", "nichtlinear", "planung", "beobachter"]

#: Anzahl der Stützstellen einer gezeichneten Kurve. Genug für eine glatte Linie bei 40 px Breite.
PUNKTE = 36
#: Wo im Bild der Sprung liegt. Davor ist Ruhe, damit der Sprung als Sprung zu sehen ist.
SPRUNG_BEI = 0.12


@dataclass(frozen=True)
class Glied:
    """Ein Übertragungsglied: Kurzzeichen, Name, Übertragungsfunktion und sein Bild."""

    id: str
    #: Das Kurzzeichen, wie es ins Kästchen passt: „PT1-Tt", „I·PT4", „PI".
    kurz: str
    name: str
    #: Die Übertragungsfunktion in der Schreibweise der Oberfläche.
    g_s: str
    art: Bildart
    kategorie: Kategorie
    #: Ob das Glied nichtlinear ist. Für den Entwurf der entscheidende Vorbehalt: eine
    #: Frequenzkennlinie gilt dann nur im linearisierten Arbeitspunkt.
    nichtlinear: bool
    #: Woran man es erkennt, in einem Satz.
    erkennen: str
    #: Die Kurve, auf das Einheitsquadrat normiert, von links nach rechts.
    kurve: tuple[tuple[float, float], ...]
    #: Eine zweite Kurve, wo eine allein zu wenig sagt (Hysterese: Hin- und Rückweg).
    kurve2: tuple[tuple[float, float], ...] = ()


def _zeit() -> list[float]:
    return [i / (PUNKTE - 1) for i in range(PUNKTE)]


def _nach_sprung(t: float) -> float:
    """Zeit seit dem Sprung, auf die verbleibende Breite bezogen."""
    return max(0.0, (t - SPRUNG_BEI) / (1.0 - SPRUNG_BEI))


def _k_p(hoehe: float = 0.72) -> tuple[tuple[float, float], ...]:
    return ((0.0, 0.0), (SPRUNG_BEI, 0.0), (SPRUNG_BEI, hoehe), (1.0, hoehe))


def _k_tt(totzeit: float = 0.3, hoehe: float = 0.72) -> tuple[tuple[float, float], ...]:
    x = SPRUNG_BEI + totzeit
    return ((0.0, 0.0), (x, 0.0), (x, hoehe), (1.0, hoehe))


def _k_i(steigung: float = 0.92) -> tuple[tuple[float, float], ...]:
    return ((0.0, 0.0), (SPRUNG_BEI, 0.0), (1.0, steigung))


def _k_pt1(
    tau: float = 0.26, hoehe: float = 0.82, totzeit: float = 0.0
) -> tuple[tuple[float, float], ...]:
    out = []
    for t in _zeit():
        s = _nach_sprung(t) - totzeit
        out.append((t, 0.0 if s <= 0 else hoehe * (1.0 - math.exp(-s / tau))))
    return tuple(out)


def _k_ptn(
    n: int = 2, tau: float = 0.2, hoehe: float = 0.82, totzeit: float = 0.0
) -> tuple[tuple[float, float], ...]:
    """Antwort einer Kette aus n gleichen Verzögerungen: der Wendepunkt wandert mit n nach rechts."""
    out = []
    for t in _zeit():
        s = _nach_sprung(t) - totzeit
        if s <= 0:
            out.append((t, 0.0))
            continue
        x = s / tau
        rest = sum(x**k / math.factorial(k) for k in range(n))
        out.append((t, hoehe * (1.0 - math.exp(-x) * rest)))
    return tuple(out)


def _k_itn(
    n: int = 4, tau: float = 0.12, steigung: float = 1.05
) -> tuple[tuple[float, float], ...]:
    """Integrierer hinter einer Verzögerungskette: erst flach, dann gerade."""
    out = []
    for t in _zeit():
        s = _nach_sprung(t)
        if s <= 0:
            out.append((t, 0.0))
            continue
        x = s / tau
        # Sprungantwort des Integrierers minus das, was die Kette noch zurückhält.
        verzug = tau * sum(
            1.0 - math.exp(-x) * sum(x**j / math.factorial(j) for j in range(k + 1))
            for k in range(n)
        )
        out.append((t, max(0.0, min(1.0, steigung * (s - (n * tau - verzug))))))
    return tuple(out)


def _k_pi(sprung: float = 0.34, ende: float = 0.95) -> tuple[tuple[float, float], ...]:
    return ((0.0, 0.0), (SPRUNG_BEI, 0.0), (SPRUNG_BEI, sprung), (1.0, ende))


def _k_zweipunkt(
    perioden: float = 2.2, mitte: float = 0.5, band: float = 0.34
) -> tuple[tuple[float, float], ...]:
    """Der Grenzzyklus: das Kennzeichen des Zweipunktreglers ist, dass er nie stillsteht."""
    out: list[tuple[float, float]] = [(0.0, mitte - band)]
    schritte = int(perioden * 2)
    for i in range(schritte):
        x0 = SPRUNG_BEI + (1.0 - SPRUNG_BEI) * i / schritte
        x1 = SPRUNG_BEI + (1.0 - SPRUNG_BEI) * (i + 1) / schritte
        y = mitte + band if i % 2 == 0 else mitte - band
        out.append((x0, y))
        out.append((x1, y))
    return tuple(out)


def _k_dreipunkt() -> tuple[tuple[float, float], ...]:
    """Drei Stufen: aus, klein, groß - mit Totzone um die Null."""
    return (
        (0.0, 0.5),
        (0.3, 0.5),
        (0.3, 0.78),
        (0.58, 0.78),
        (0.58, 0.5),
        (0.72, 0.5),
        (0.72, 0.22),
        (1.0, 0.22),
    )


def _k_treppe(stufen: int = 5, hoehe: float = 0.9) -> tuple[tuple[float, float], ...]:
    out: list[tuple[float, float]] = [(0.0, 0.08)]
    for i in range(stufen):
        x0 = SPRUNG_BEI + (1.0 - SPRUNG_BEI) * i / stufen
        x1 = SPRUNG_BEI + (1.0 - SPRUNG_BEI) * (i + 1) / stufen
        y = 0.08 + (hoehe - 0.08) * (i + 1) / stufen
        out.append((x0, y))
        out.append((x1, y))
    return tuple(out)


def _k_begrenzung(knick: float = 0.62, hoehe: float = 0.88) -> tuple[tuple[float, float], ...]:
    return ((0.0, 0.06), (knick, hoehe), (1.0, hoehe))


def _k_auswahl() -> tuple[tuple[float, float], ...]:
    """Maximumbildung: der Ausgang folgt dem größten Eingang, der Knick ist die Übernahme."""
    return ((0.0, 0.52), (0.46, 0.52), (1.0, 0.94))


def _k_kennlinie_fallend(
    kruemmung: float = 2.4, hoch: float = 0.94, tief: float = 0.12
) -> tuple[tuple[float, float], ...]:
    out = []
    for i in range(PUNKTE):
        u = i / (PUNKTE - 1)
        out.append((u, tief + (hoch - tief) / (1.0 + kruemmung * u)))
    return tuple(out)


def _k_kennfeld() -> tuple[tuple[float, float], ...]:
    """Eine Schar: dieselbe Verstärkung, zwei Arbeitspunkte. Darum geht es bei der Planung."""
    return tuple((u, 0.18 + 0.62 * u) for u in (i / (PUNKTE - 1) for i in range(PUNKTE)))


def _k_kennfeld2() -> tuple[tuple[float, float], ...]:
    return tuple((u, 0.06 + 0.42 * u) for u in (i / (PUNKTE - 1) for i in range(PUNKTE)))


def _k_hysterese() -> tuple[tuple[float, float], ...]:
    return ((0.1, 0.2), (0.55, 0.2), (0.55, 0.82), (0.95, 0.82))


def _k_hysterese2() -> tuple[tuple[float, float], ...]:
    return ((0.95, 0.82), (0.45, 0.82), (0.45, 0.2), (0.1, 0.2))


def _k_beobachter() -> tuple[tuple[float, float], ...]:
    """Die Schätzung läuft der verrauschten Messung hinterher und glättet sie."""
    out = []
    for t in _zeit():
        s = _nach_sprung(t)
        grund = 0.82 * (1.0 - math.exp(-s / 0.22))
        out.append((t, grund))
    return tuple(out)


def _k_beobachter2() -> tuple[tuple[float, float], ...]:
    out = []
    for i, t in enumerate(_zeit()):
        s = _nach_sprung(t)
        grund = 0.82 * (1.0 - math.exp(-s / 0.22))
        rauschen = 0.0 if s <= 0 else 0.09 * math.sin(i * 1.9) + 0.05 * math.sin(i * 0.7)
        out.append((t, max(0.0, min(1.0, grund + rauschen))))
    return tuple(out)


_KATALOG: tuple[Glied, ...] = (
    Glied(
        id="p",
        kurz="P",
        name="P-Glied",
        g_s="G(s) = K",
        art="sprung",
        kategorie="strecke",
        nichtlinear=False,
        erkennen="Der Ausgang springt mit und bleibt. Keine Zeit im Spiel.",
        kurve=_k_p(),
    ),
    Glied(
        id="p_kennlinie",
        kurz="P ~",
        name="P-Glied mit nichtlinearer Kennlinie",
        g_s="y = f(u),  K = ∂y/∂u im Arbeitspunkt",
        art="kennlinie",
        kategorie="nichtlinear",
        nichtlinear=True,
        erkennen="Keine Gerade: die Verstärkung hängt davon ab, wo man steht.",
        kurve=_k_kennlinie_fallend(),
    ),
    Glied(
        id="p_kennfeld",
        kurz="P(θ)",
        name="P-Glied mit geplanter Verstärkung",
        g_s="K = K(Ta, TVL)  —  Verstärkungsplanung",
        art="kennlinie",
        kategorie="nichtlinear",
        nichtlinear=True,
        erkennen="Eine Schar statt einer Geraden: je Arbeitspunkt eine andere Verstärkung.",
        kurve=_k_kennfeld(),
        kurve2=_k_kennfeld2(),
    ),
    Glied(
        id="pt1",
        kurz="PT1",
        name="Verzögerungsglied erster Ordnung",
        g_s="G(s) = K / (1 + T1 s)",
        art="sprung",
        kategorie="strecke",
        nichtlinear=False,
        erkennen="Steigt sofort am steilsten und läuft in den Endwert - ohne Wendepunkt.",
        kurve=_k_pt1(),
    ),
    Glied(
        id="pt1_tt",
        kurz="PT1-Tt",
        name="Verzögerungsglied erster Ordnung mit Totzeit",
        g_s="G(s) = K · e^(−Tt s) / (1 + T1 s)",
        art="sprung",
        kategorie="strecke",
        nichtlinear=False,
        erkennen="Erst passiert nichts, dann die Exponentialkurve. Die Wartezeit ist die Totzeit.",
        kurve=_k_pt1(totzeit=0.22),
    ),
    Glied(
        id="pt2_tt",
        kurz="PT2-Tt",
        name="Verzögerungsglied zweiter Ordnung mit Totzeit",
        g_s="G(s) = K · e^(−Tt s) / ((1 + T1 s)(1 + T2 s))",
        art="sprung",
        kategorie="strecke",
        nichtlinear=False,
        erkennen="Die Kurve beginnt flach und bekommt einen Wendepunkt: zwei Speicher hintereinander.",
        kurve=_k_ptn(n=2, totzeit=0.14),
    ),
    Glied(
        id="i",
        kurz="I",
        name="Integrierglied",
        g_s="G(s) = KI / s",
        art="sprung",
        kategorie="strecke",
        nichtlinear=False,
        erkennen="Eine Gerade, die nicht aufhört zu steigen. Ohne Gegenmaßnahme läuft sie davon.",
        kurve=_k_i(),
    ),
    Glied(
        id="itn",
        kurz="ITn",
        name="Integrierglied mit Verzögerungskette",
        g_s="G(s) = KI / (s · (1 + Ts s)^n)",
        art="sprung",
        kategorie="strecke",
        nichtlinear=False,
        erkennen="Erst zögerlich, dann eine Gerade: die Kette hält den Anfang auf, der Integrierer "
        "bestimmt den Rest.",
        kurve=_k_itn(),
    ),
    Glied(
        id="tt",
        kurz="Tt",
        name="Totzeitglied",
        g_s="G(s) = e^(−Tt s)",
        art="sprung",
        kategorie="strecke",
        nichtlinear=False,
        erkennen="Dieselbe Form, nur später. Phase geht verloren, Amplitude nicht - das macht es "
        "für den Regler so unangenehm.",
        kurve=_k_tt(),
    ),
    Glied(
        id="pi_regler",
        kurz="PI",
        name="PI-Regler",
        g_s="GR(s) = KR · (1 + 1/(Tn s))",
        art="sprung",
        kategorie="regler",
        nichtlinear=False,
        erkennen="Ein Sprung (der P-Anteil) und darauf eine Gerade (der I-Anteil). Die Gerade holt "
        "die bleibende Abweichung.",
        kurve=_k_pi(),
    ),
    Glied(
        id="zweipunkt",
        kurz="2-Pkt",
        name="Zweipunktregler mit Hysterese",
        g_s="u ∈ {0, 1},  Umschaltung bei w ± Δ/2",
        art="sprung",
        kategorie="regler",
        nichtlinear=True,
        erkennen="Er steht nie still: die Regelgröße pendelt im Band, die Stellgröße kennt nur an "
        "und aus.",
        kurve=_k_zweipunkt(),
    ),
    Glied(
        id="dreipunkt",
        kurz="3-Pkt",
        name="Dreipunktregler mit Totzone",
        g_s="u ∈ {−1, 0, +1},  Totzone um die Abweichung null",
        art="sprung",
        kategorie="regler",
        nichtlinear=True,
        erkennen="Drei Stufen und eine Ruhezone in der Mitte: ohne sie würde zwischen zwei "
        "Zuständen gependelt.",
        kurve=_k_dreipunkt(),
    ),
    Glied(
        id="begrenzung",
        kurz="⊓",
        name="Begrenzungsglied",
        g_s="y = min(max(u, umin), umax)",
        art="kennlinie",
        kategorie="nichtlinear",
        nichtlinear=True,
        erkennen="Eine Gerade, die in die Waagerechte knickt. Oberhalb des Knicks nützt mehr "
        "Eingang nichts mehr.",
        kurve=_k_begrenzung(),
    ),
    Glied(
        id="auswahl",
        kurz="max",
        name="Auswahlglied (Maximumbildung)",
        g_s="y = maxi ui",
        art="kennlinie",
        kategorie="nichtlinear",
        nichtlinear=True,
        erkennen="Der Ausgang folgt dem größten Eingang; am Knick übernimmt ein anderer die "
        "Führung.",
        kurve=_k_auswahl(),
    ),
    Glied(
        id="hysterese",
        kurz="⊐⊏",
        name="Hystereseglied",
        g_s="Umschaltpunkte abhängig von der Richtung",
        art="kennlinie",
        kategorie="nichtlinear",
        nichtlinear=True,
        erkennen="Hin- und Rückweg liegen auseinander. Die Breite dazwischen ist die "
        "Schaltdifferenz.",
        kurve=_k_hysterese(),
        kurve2=_k_hysterese2(),
    ),
    Glied(
        id="beobachter",
        kurz="x̂",
        name="Zustandsbeobachter (Kalman)",
        g_s="x̂̇ = A x̂ + B u + K (y − C x̂)",
        art="sprung",
        kategorie="beobachter",
        nichtlinear=False,
        erkennen="Die glatte Linie ist die Schätzung, die zappelnde die Messung. Der Filter "
        "gewichtet beide mit ihrer Unsicherheit.",
        kurve=_k_beobachter(),
        kurve2=_k_beobachter2(),
    ),
    Glied(
        id="zustandsregler",
        kurz="MPC",
        name="Prädiktiver Zustandsregler mit Abtastung",
        g_s="min Σ c u Δt  u. B. v. Modell und Grenzen,  Takt 15 min",
        art="takt",
        kategorie="planung",
        nichtlinear=True,
        erkennen="Eine Treppe statt einer Kurve: er entscheidet je Intervall und hält bis zum "
        "nächsten.",
        kurve=_k_treppe(),
    ),
)

#: Alle Glieder, nach Kennung.
GLIEDER: Mapping[str, Glied] = {g.id: g for g in _KATALOG}


def glied(gid: str) -> Glied:
    return GLIEDER[gid]
