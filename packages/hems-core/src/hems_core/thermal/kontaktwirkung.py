"""Was der Freigabekontakt K1 auslöst: eine Ereignisstudie aus der Minutenreihe.

Schritt 3 des Zwillingsentwurfs, und die älteste offene Frage des Projekts (Plan 25.8, seit
September). K1 ist eine Anforderung, keine Sperre: der Kontakt sagt der Wärmepumpe „erzeuge mehr
Wärme", und ob sie folgt, entscheidet ihre eigene Regelung. Beide Reihen, Kontakt und elektrische
Leistung, liegen minütlich vor. Hier werden sie zum ersten Mal gegeneinandergestellt.

**Die Methode ist eine Ereignisstudie.** Jeder Schließvorgang des Kontakts ist ein Ereignis. Die
Leistung der Maschine wird um jedes Ereignis herum ausgeschnitten, von einer halben Stunde davor
bis zwei Stunden danach, und alle Ausschnitte werden an ihrem Nullpunkt übereinandergelegt. Was
K1 auslöst, steht dann rechts der Null; was ohnehin geschah, steht auch links.

**Ohne Vergleich ist eine Quote keine Antwort.** „Nach dem Schließen läuft sie in 70 Prozent der
Fälle binnen einer halben Stunde an" sagt nichts, wenn sie zu dieser Tageszeit ohnehin alle
vierzig Minuten anläuft. Deshalb steht neben der Folgequote dieselbe Quote für Momente **ohne**
Schließvorgang: die Maschine steht, der Kontakt ist offen und bleibt es. Verglichen wird zur
selben Tageszeit, denn K1 schließt nicht zufällig über den Tag verteilt - es schließt in den
günstigen Stunden, und in denen hat das Haus seinen eigenen Rhythmus.

**Was diese Auswertung nicht kann.** Sie zeigt einen Zusammenhang in der Zeit, keine Ursache. Der
Regler schließt K1, wenn der Puffer Platz hat und der Strom günstig ist; dass die Maschine danach
anläuft, kann auch am leeren Puffer liegen und nicht am Kontakt. Der Vergleich zur selben
Tageszeit nimmt den Tagesrhythmus heraus, nicht den Pufferzustand. Das steht in den Hinweisen der
Antwort und nicht nur hier. Die saubere Antwort wäre ein Versuch: den Kontakt zu zufälligen Zeiten
schließen. Das ist ein Eingriff in den Betrieb und eine Entscheidung des Hausherrn.

Reine Rechenlogik, kein I/O, keine Zeitzonen: die Ortsstunde eines Zeitpunkts gibt der Aufrufer
als Funktion herein.
"""

from __future__ import annotations

import math
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from statistics import median

from pydantic import BaseModel, ConfigDict, Field

#: Wie weit der Ausschnitt vor das Ereignis und hinter es reicht, in Minuten.
VOR_MIN = 30
NACH_MIN = 120
#: Ein Anlauf binnen so vieler Minuten zählt als Folge des Schließens. Die Startverzögerung der
#: Maschine samt Entprellung liegt bei wenigen Minuten; eine halbe Stunde lässt Luft, ohne den
#: nächsten ohnehin fälligen Lauf mitzunehmen.
FOLGE_MIN = 30
#: So lange muss der Kontakt vor einem Schließvorgang offen gewesen sein. Ohne diese Ruhe zählte
#: jedes Flattern als neues Ereignis.
RUHE_MIN = 10
#: Unter so vielen auswertbaren Ereignissen gibt es kein Urteil, nur die Zahlen.
MIN_EREIGNISSE = 8
#: Unter so vielen Vergleichsmomenten ist der Vergleich zu dünn für ein Urteil.
MIN_VERGLEICH = 20
#: Mindestanteil bekannter Minuten im Folgefenster, damit „nicht angelaufen" eine Aussage ist.
MIN_ABDECKUNG = 0.8
#: Unter diesem Anteil bekannter Minuten im ganzen Zeitraum sagt die Antwort, dass sie nur einen
#: Teil sieht. Kein Abbruch: was da ist, wird ausgewertet.
MIN_ABDECKUNG_ZEITRAUM = 0.9


@dataclass(frozen=True)
class Probe:
    """Eine Minute: Kontaktzustand und Leistung. Jedes von beiden darf fehlen."""

    ts: datetime
    kontakt: bool | None
    kw: float | None


class Ereignis(BaseModel):
    """Ein Schließvorgang und was die Maschine um ihn herum tat."""

    model_config = ConfigDict(frozen=True)

    at: datetime
    #: Lief die Maschine schon, als der Kontakt schloss? Dann kann das Ereignis nichts über die
    #: Wirkung sagen und zählt nicht in die Folgequote.
    lief_schon: bool
    #: Ob das Ereignis in die Folgequote eingeht: die Maschine stand, und das Folgefenster ist
    #: ausreichend gemessen.
    auswertbar: bool
    #: Anlauf binnen `FOLGE_MIN`. `None`, wenn nicht auswertbar.
    gefolgt: bool | None
    #: Minuten vom Schließen bis zum Anlauf, im ganzen Ausschnitt gesucht. `None` ohne Anlauf.
    verzoegerung_min: int | None
    #: Wie lange der Kontakt geschlossen blieb, gekappt am Ende des Ausschnitts.
    kontakt_min: int
    #: Die Leistung je Minute von `-VOR_MIN` bis `+NACH_MIN`. `None`, wo nichts gemessen wurde.
    kw: list[float | None]


class Faecher(BaseModel):
    """Alle auswertbaren Ereignisse übereinandergelegt, je Minute relativ zum Schließen."""

    model_config = ConfigDict(frozen=True)

    minuten: list[int]
    #: Die mittlere Leistung über alle Ereignisse. Das ist die Kurve, die gezeichnet wird, und
    #: nicht der Median: die Maschine läuft oder steht, und bei drei laufenden und drei stehenden
    #: läge der Median auf halber Höhe, wo keine einzige Kurve je lag. Das Mittel ist Anteil mal
    #: Leistung, also das, womit ein Planer nach dem Schließen rechnen kann.
    mittel_kw: list[float | None] = Field(default_factory=list)
    median_kw: list[float | None]
    q25_kw: list[float | None]
    q75_kw: list[float | None]
    #: Anteil der Ereignisse, in denen die Maschine in dieser Minute lief, 0 bis 1.
    anteil_laeuft: list[float | None]
    #: Wie viele Ereignisse zu dieser Minute einen Messwert hatten.
    n: list[int]
    #: Anteil der Ereignisse, deren Maschine bis einschließlich dieser Minute angelaufen ist, 0 bis
    #: 1 und nie fallend. Vor dem Schließen `None`: dort gibt es keinen Anlauf zu zählen. Bei
    #: Minute `FOLGE_MIN - 1` steht hier genau die Folgequote.
    anteil_angelaufen: list[float | None] = Field(default_factory=list)


class Vergleich(BaseModel):
    """Dieselbe Quote ohne Schließvorgang: wie oft läuft die Maschine von selbst an?"""

    model_config = ConfigDict(frozen=True)

    #: Vergleichsmomente insgesamt: die Maschine stand, der Kontakt war offen und blieb es.
    n: int
    gefolgt: int
    #: Die Quote über alle Vergleichsmomente.
    quote_gesamt: float | None
    #: Die Quote zur selben Tageszeit wie die Ereignisse, also je Ortsstunde gewichtet mit der
    #: Zahl der Ereignisse in dieser Stunde. Das ist die Zahl, gegen die verglichen wird.
    quote: float | None
    #: Für wie viele der auswertbaren Ereignisse es Vergleichsmomente in derselben Stunde gab.
    ereignisse_gedeckt: int
    #: Vergleichsmomente in den Stunden, in denen auch Ereignisse liegen. Auf dieser Zahl steht
    #: `quote`, und an ihr hängt, ob der Vergleich für ein Urteil reicht.
    n_gleiche_stunde: int = 0
    #: 95-Prozent-Bereich des Vergleichs nach Wilson, über die zusammengelegten Zählungen dieser
    #: Stunden. Die Quote selbst ist nach Ereignisstunden gewichtet; bei ungleich verteilten
    #: Ereignissen liegen beide deshalb leicht auseinander.
    quote_lo: float | None = None
    quote_hi: float | None = None
    #: Dieselbe Kurve wie `Faecher.anteil_angelaufen`, nur ohne Schließvorgang: der Anteil der
    #: Vergleichsmomente, in denen die Maschine bis einschließlich Minute 0, 1, ... angelaufen
    #: ist, gewichtet wie `quote`. Sie reicht bis `FOLGE_MIN - 1`, denn so lang ist ein Block, und
    #: endet auf `quote`. Leer ohne Vergleich zur selben Tageszeit.
    angelaufen_bis: list[float] = Field(default_factory=list)


class Kontaktwirkung(BaseModel):
    """Die ganze Auswertung. Die Oberfläche zeichnet sie; das Urteil steht hier."""

    model_config = ConfigDict(frozen=True)

    #: Der ausgewertete Zeitraum. `None`, wenn es keine einzige Minute gab.
    von: datetime | None
    bis: datetime | None
    schwelle_kw: float
    vor_min: int = VOR_MIN
    nach_min: int = NACH_MIN
    folge_min: int = FOLGE_MIN
    ereignisse: list[Ereignis] = Field(default_factory=list)
    faecher: Faecher
    #: Schließvorgänge insgesamt, davon mit schon laufender Maschine, davon auswertbar.
    n: int = 0
    n_lief_schon: int = 0
    n_auswertbar: int = 0
    gefolgt: int = 0
    quote: float | None = None
    #: 95-Prozent-Bereich der Folgequote nach Wilson. Bei wenigen Ereignissen ist er breit, und
    #: das soll er sein.
    quote_lo: float | None = None
    quote_hi: float | None = None
    vergleich: Vergleich
    verzoegerung_median_min: float | None = None
    #: Nach dem Öffnen: wie lange die Maschine weiterlief, im Median, und über wie viele Fälle.
    nachlauf_median_min: float | None = None
    nachlauf_n: int = 0
    #: In welchem Anteil der Minuten des Zeitraums Kontakt und Leistung bekannt sind, 0 bis 1.
    #: `None` ohne Zeitraum. Wo der Kontakt fehlt, wird kein Schließvorgang gefunden und kein
    #: Vergleich gezogen: eine niedrige Abdeckung heißt, die Auswertung sieht nur einen Teil.
    abdeckung_kontakt: float | None = None
    abdeckung_leistung: float | None = None
    #: `wirkt`, `kein_unterschied`, `seltener` oder `offen` (zu wenig für ein Urteil).
    urteil: str = "offen"
    urteil_de: str = ""
    hinweise_de: list[str] = Field(default_factory=list)


def wilson(treffer: int, n: int, z: float = 1.96) -> tuple[float, float] | None:
    """Der Vertrauensbereich eines Anteils nach Wilson. `None` ohne Beobachtung.

    Wilson und nicht die Schulformel p ± z·sqrt(p(1-p)/n): bei kleinen Zahlen und Anteilen nahe
    null oder eins liefert die Schulformel Grenzen außerhalb von null bis eins oder einen Bereich
    der Breite null bei „7 von 7". Genau diese Fälle kommen hier vor.
    """
    if n <= 0:
        return None
    p = treffer / n
    nenner = 1 + z * z / n
    mitte = (p + z * z / (2 * n)) / nenner
    halb = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / nenner
    return max(0.0, mitte - halb), min(1.0, mitte + halb)


def _quantil(werte: Sequence[float], q: float) -> float:
    """Lineares Quantil über eine sortierte Reihe. Die Reihe darf nicht leer sein."""
    s = sorted(werte)
    pos = q * (len(s) - 1)
    unten = math.floor(pos)
    oben = min(unten + 1, len(s) - 1)
    return s[unten] + (s[oben] - s[unten]) * (pos - unten)


def _minute(t: datetime) -> datetime:
    return t.replace(second=0, microsecond=0)


class _Reihe:
    """Die Minutenreihe mit Zugriff über den Zeitpunkt. Eine fehlende Minute ist `None`."""

    def __init__(self, proben: Sequence[Probe], schwelle_kw: float) -> None:
        self.nach_zeit = {_minute(p.ts): p for p in proben}
        self.schwelle = schwelle_kw

    def kontakt(self, t: datetime) -> bool | None:
        p = self.nach_zeit.get(t)
        return None if p is None else p.kontakt

    def kw(self, t: datetime) -> float | None:
        p = self.nach_zeit.get(t)
        return None if p is None else p.kw

    def laeuft(self, t: datetime) -> bool | None:
        w = self.kw(t)
        return None if w is None else w >= self.schwelle

    def offen_durchgehend(self, von: datetime, minuten: int) -> bool:
        """Ist der Kontakt in jeder der `minuten` ab `von` bekannt und offen?"""
        return all(self.kontakt(von + timedelta(minutes=m)) is False for m in range(minuten))

    def anlauf(self, t0: datetime, fenster: int) -> tuple[int | None, float]:
        """Die erste Minute ab `t0` mit laufender Maschine, und der Anteil bekannter Minuten."""
        bekannt = 0
        for m in range(fenster):
            laeuft = self.laeuft(t0 + timedelta(minutes=m))
            if laeuft is None:
                continue
            bekannt += 1
            if laeuft:
                return m, bekannt / fenster
        return None, bekannt / fenster


def _ereignis(reihe: _Reihe, t0: datetime) -> Ereignis:
    eine = timedelta(minutes=1)
    davor = reihe.laeuft(t0 - eine)
    lief_schon = davor is True
    erster, _ = reihe.anlauf(t0, NACH_MIN + 1)
    folge, abdeckung = reihe.anlauf(t0, FOLGE_MIN)
    # Auswertbar heißt: die Maschine stand nachweislich, und entweder wurde ein Anlauf gesehen
    # oder das Folgefenster ist dicht genug gemessen, dass sein Ausbleiben eine Aussage ist.
    auswertbar = davor is False and (folge is not None or abdeckung >= MIN_ABDECKUNG)
    kontakt_min = 0
    while kontakt_min <= NACH_MIN and reihe.kontakt(t0 + kontakt_min * eine) is True:
        kontakt_min += 1
    kurve = [reihe.kw(t0 + m * eine) for m in range(-VOR_MIN, NACH_MIN + 1)]
    return Ereignis(
        at=t0,
        lief_schon=lief_schon,
        auswertbar=auswertbar,
        gefolgt=(folge is not None) if auswertbar else None,
        verzoegerung_min=None if lief_schon else erster,
        kontakt_min=kontakt_min,
        kw=[None if w is None else round(w, 2) for w in kurve],
    )


def _faecher(ereignisse: Sequence[Ereignis], schwelle_kw: float) -> Faecher:
    minuten = list(range(-VOR_MIN, NACH_MIN + 1))
    med: list[float | None] = []
    mittel: list[float | None] = []
    q25: list[float | None] = []
    q75: list[float | None] = []
    anteil: list[float | None] = []
    n: list[int] = []
    for i in range(len(minuten)):
        werte = [e.kw[i] for e in ereignisse if e.kw[i] is not None]
        zahlen = [float(w) for w in werte if w is not None]
        n.append(len(zahlen))
        if not zahlen:
            med.append(None)
            mittel.append(None)
            q25.append(None)
            q75.append(None)
            anteil.append(None)
            continue
        med.append(round(median(zahlen), 3))
        mittel.append(round(sum(zahlen) / len(zahlen), 3))
        q25.append(round(_quantil(zahlen, 0.25), 3))
        q75.append(round(_quantil(zahlen, 0.75), 3))
        anteil.append(round(sum(1 for w in zahlen if w >= schwelle_kw) / len(zahlen), 3))
    verz = [e.verzoegerung_min for e in ereignisse]
    angelaufen: list[float | None] = [
        None
        if m < 0 or not ereignisse
        else round(sum(1 for v in verz if v is not None and v <= m) / len(ereignisse), 4)
        for m in minuten
    ]
    return Faecher(
        minuten=minuten,
        mittel_kw=mittel,
        median_kw=med,
        q25_kw=q25,
        q75_kw=q75,
        anteil_laeuft=anteil,
        n=n,
        anteil_angelaufen=angelaufen,
    )


def _vergleich(
    reihe: _Reihe,
    von: datetime,
    bis: datetime,
    stunde: Callable[[datetime], int],
    ereignis_stunden: Sequence[int],
) -> Vergleich:
    """Die Anlaufquote ohne Schließvorgang, in Blöcken von `FOLGE_MIN`, die sich nicht überlappen.

    Blöcke und nicht jede Minute: aufeinanderfolgende Minuten sehen fast dasselbe Fenster, und
    zehntausend überlappende Beobachtungen gäben eine Sicherheit vor, die in ihnen nicht steckt.

    Ein Block zählt, wenn die Maschine an seinem Anfang nachweislich steht und der Kontakt von
    `RUHE_MIN` davor bis zum Ende des Blocks durchgehend offen ist. Das zweite schließt die
    Nachwirkung eines früheren Schließens und jedes Schließen im Block selbst aus.
    """
    eine = timedelta(minutes=1)
    je_stunde: dict[int, list[int]] = {}
    # Je Stunde die Minute des Anlaufs in jedem Block, `None` ohne Anlauf: daraus wird die Kurve.
    anlaeufe: dict[int, list[int | None]] = {}
    t = von.replace(minute=(von.minute // FOLGE_MIN) * FOLGE_MIN, second=0, microsecond=0)
    while t + timedelta(minutes=FOLGE_MIN - 1) <= bis:
        steht = reihe.laeuft(t - eine) is False
        if steht and reihe.offen_durchgehend(t - RUHE_MIN * eine, RUHE_MIN + FOLGE_MIN):
            erster, abdeckung = reihe.anlauf(t, FOLGE_MIN)
            if erster is not None or abdeckung >= MIN_ABDECKUNG:
                paar = je_stunde.setdefault(stunde(t), [0, 0])
                paar[0] += 1
                paar[1] += 1 if erster is not None else 0
                anlaeufe.setdefault(stunde(t), []).append(erster)
        t += timedelta(minutes=FOLGE_MIN)
    n = sum(p[0] for p in je_stunde.values())
    gefolgt = sum(p[1] for p in je_stunde.values())
    # Gewichtet nach den Stunden der Ereignisse: schließt K1 zwölfmal um 13 Uhr und dreimal um
    # 2 Uhr, zählt die Vergleichsquote von 13 Uhr viermal so viel wie die von 2 Uhr.
    quoten = [je_stunde[h][1] / je_stunde[h][0] for h in ereignis_stunden if h in je_stunde]
    gleiche = [je_stunde[h] for h in set(ereignis_stunden) if h in je_stunde]
    n_gleiche = sum(p[0] for p in gleiche)
    bereich = wilson(sum(p[1] for p in gleiche), n_gleiche)
    gedeckt = [h for h in ereignis_stunden if h in anlaeufe]
    kurve = [
        round(
            sum(
                sum(1 for a in anlaeufe[h] if a is not None and a <= m) / len(anlaeufe[h])
                for h in gedeckt
            )
            / len(gedeckt),
            4,
        )
        for m in (range(FOLGE_MIN) if gedeckt else ())
    ]
    return Vergleich(
        n=n,
        gefolgt=gefolgt,
        quote_gesamt=round(gefolgt / n, 4) if n else None,
        quote=round(sum(quoten) / len(quoten), 4) if quoten else None,
        ereignisse_gedeckt=len(quoten),
        n_gleiche_stunde=n_gleiche,
        quote_lo=round(bereich[0], 4) if bereich else None,
        quote_hi=round(bereich[1], 4) if bereich else None,
        angelaufen_bis=kurve,
    )


def _nachlauf(reihe: _Reihe, zeiten: Sequence[datetime]) -> list[int]:
    """Nach jedem Öffnen bei laufender Maschine: Minuten bis zum Stillstand, gekappt bei `NACH_MIN`."""
    eine = timedelta(minutes=1)
    out: list[int] = []
    for i in range(1, len(zeiten)):
        t = zeiten[i]
        if not (reihe.kontakt(t - eine) is True and reihe.kontakt(t) is False):
            continue
        if reihe.laeuft(t) is not True:
            continue
        m = 0
        while m < NACH_MIN and reihe.laeuft(t + m * eine) is True:
            m += 1
        out.append(m)
    return out


def _faelle(n: int) -> str:
    return "1 Fall" if n == 1 else f"{n} Fälle"


def _zahl(n: int, einzahl: str, mehrzahl: str) -> str:
    """„1 Schließvorgang ist", „3 Schließvorgänge sind": die Zahl mit dem passenden Wort."""
    return f"1 {einzahl}" if n == 1 else f"{n} {mehrzahl}"


def _prozent(x: float) -> str:
    return f"{x * 100:.0f}".replace(".", ",")


def _urteil(k: Kontaktwirkung) -> tuple[str, str]:
    """Das Urteil als Kennung und als Satz. Die Oberfläche urteilt nicht selbst."""
    if k.n == 0:
        return "offen", (
            "Im Zeitraum hat der Kontakt kein einziges Mal geschlossen. Es gibt nichts auszuwerten; "
            "sobald die Regelung K1 stellt, entstehen die Ereignisse von selbst."
        )
    if (
        k.n_auswertbar < MIN_EREIGNISSE
        or k.quote is None
        or k.quote_lo is None
        or k.quote_hi is None
    ):
        return "offen", (
            f"Zu wenige Ereignisse für ein Urteil: {k.n_auswertbar} Schließvorgänge bei stehender "
            f"Maschine, gebraucht werden mindestens {MIN_EREIGNISSE}. Die Zahlen stehen da, für "
            "eine Aussage reichen sie noch nicht."
        )
    v = k.vergleich
    if v.quote is None or v.n_gleiche_stunde < MIN_VERGLEICH:
        return "offen", (
            f"Nach dem Schließen läuft die Maschine in {_prozent(k.quote)} % der Fälle binnen "
            f"{FOLGE_MIN} Minuten an. Ob das mehr ist als ohne K1, lässt sich nicht sagen: zur "
            f"selben Tageszeit gibt es nur {v.n_gleiche_stunde} Vergleichsmomente, gebraucht "
            f"werden mindestens {MIN_VERGLEICH}."
        )
    kern = (
        f"{_prozent(k.quote)} % der Schließvorgänge führen binnen {FOLGE_MIN} Minuten zum Anlauf "
        f"(95-Prozent-Bereich {_prozent(k.quote_lo)} bis {_prozent(k.quote_hi)} %), ohne K1 sind "
        f"es zur selben Tageszeit {_prozent(v.quote)} %."
    )
    # Die Bereiche dürfen sich nicht überlappen. Das ist strenger als ein üblicher Test auf dem
    # 5-Prozent-Niveau, und das mit Absicht: an diesem Urteil hängt, ob der Planer dem Kontakt
    # etwas zutrauen darf, und ein vorschnelles Ja kostet mehr als ein spätes.
    v_lo = v.quote if v.quote_lo is None else v.quote_lo
    v_hi = v.quote if v.quote_hi is None else v.quote_hi
    if k.quote_lo > v_hi:
        return "wirkt", f"Die Maschine folgt K1: {kern}"
    if k.quote_hi < v_lo:
        return "seltener", f"Nach dem Schließen läuft die Maschine seltener an als sonst: {kern}"
    return "kein_unterschied", f"Kein gesicherter Unterschied: {kern}"


def auswerten(
    proben: Sequence[Probe],
    *,
    schwelle_kw: float,
    stunde: Callable[[datetime], int],
    von: datetime | None = None,
    bis: datetime | None = None,
) -> Kontaktwirkung:
    """Die Ereignisstudie über eine Minutenreihe.

    `proben` sind Minuten in beliebiger Dichte; fehlende Minuten sind erlaubt und bleiben Lücken.
    `von` und `bis` nennen den gefragten Zeitraum für die Antwort; fehlen sie, gilt der gemessene.
    `schwelle_kw` trennt den Verdichter von der Grundlast der Anlage, dieselbe Schwelle wie überall
    (`heat_pump.running_threshold_kw`). `stunde` gibt die Ortsstunde eines Zeitpunkts.

    Ein Schließvorgang ist der Übergang von nachweislich offen zu geschlossen, nach mindestens
    `RUHE_MIN` Minuten durchgehend offenem Kontakt. Über eine Lücke hinweg entsteht kein Ereignis:
    wo der Kontakt unbekannt war, ist auch sein Schließen unbekannt.
    """
    geordnet = sorted(proben, key=lambda p: p.ts)
    reihe = _Reihe(geordnet, schwelle_kw)
    zeiten = [_minute(p.ts) for p in geordnet]
    eine = timedelta(minutes=1)
    ereignisse: list[Ereignis] = []
    for t in zeiten:
        if reihe.kontakt(t) is not True:
            continue
        if not reihe.offen_durchgehend(t - RUHE_MIN * eine, RUHE_MIN):
            continue
        ereignisse.append(_ereignis(reihe, t))

    auswertbar = [e for e in ereignisse if e.auswertbar]
    gefolgt = sum(1 for e in auswertbar if e.gefolgt)
    bereich = wilson(gefolgt, len(auswertbar))
    verz = [e.verzoegerung_min for e in auswertbar if e.gefolgt and e.verzoegerung_min is not None]
    nachlauf = _nachlauf(reihe, zeiten)
    # Der Zeitraum ist der gefragte, wenn der Aufrufer ihn nennt, sonst der gemessene. Der
    # Vergleich läuft immer nur über gemessene Minuten: wo nichts steht, zählt kein Block.
    erste = zeiten[0] if zeiten else None
    letzte = zeiten[-1] if zeiten else None
    anfang = von or erste
    ende = bis or letzte
    # Die Abdeckung zählt gegen den gefragten Zeitraum, nicht gegen den gemessenen: fehlen von
    # dreißig Tagen zwanzig, soll das dastehen und nicht in einem kürzeren Zeitraum verschwinden.
    soll = int((ende - anfang).total_seconds() // 60) + 1 if anfang and ende else 0
    drin = [p for p in geordnet if anfang and ende and anfang <= _minute(p.ts) <= ende]
    roh = Kontaktwirkung(
        von=anfang,
        bis=ende,
        abdeckung_kontakt=(
            round(min(1.0, sum(1 for p in drin if p.kontakt is not None) / soll), 4)
            if soll
            else None
        ),
        abdeckung_leistung=(
            round(min(1.0, sum(1 for p in drin if p.kw is not None) / soll), 4) if soll else None
        ),
        schwelle_kw=schwelle_kw,
        ereignisse=ereignisse,
        faecher=_faecher(auswertbar, schwelle_kw),
        n=len(ereignisse),
        n_lief_schon=sum(1 for e in ereignisse if e.lief_schon),
        n_auswertbar=len(auswertbar),
        gefolgt=gefolgt,
        quote=round(gefolgt / len(auswertbar), 4) if auswertbar else None,
        quote_lo=round(bereich[0], 4) if bereich else None,
        quote_hi=round(bereich[1], 4) if bereich else None,
        vergleich=_vergleich(reihe, erste, letzte, stunde, [stunde(e.at) for e in auswertbar])
        if erste is not None and letzte is not None
        else Vergleich(n=0, gefolgt=0, quote_gesamt=None, quote=None, ereignisse_gedeckt=0),
        verzoegerung_median_min=float(median(verz)) if verz else None,
        nachlauf_median_min=float(median(nachlauf)) if nachlauf else None,
        nachlauf_n=len(nachlauf),
    )
    urteil, satz = _urteil(roh)
    return roh.model_copy(
        update={"urteil": urteil, "urteil_de": satz, "hinweise_de": _hinweise(roh)}
    )


def _hinweise(k: Kontaktwirkung) -> list[str]:
    out = [
        "Die Auswertung zeigt einen Zusammenhang in der Zeit, keine Ursache. Der Regler schließt "
        "K1, wenn der Puffer Platz hat und der Strom günstig ist; ein Anlauf danach kann auch am "
        "leeren Puffer liegen. Der Vergleich zur selben Tageszeit nimmt den Tagesrhythmus heraus, "
        "nicht den Pufferzustand."
    ]
    for name, anteil in (
        ("Der Kontaktzustand", k.abdeckung_kontakt),
        ("Die Leistung der Wärmepumpe", k.abdeckung_leistung),
    ):
        if anteil is not None and anteil < MIN_ABDECKUNG_ZEITRAUM:
            out.append(
                f"{name} ist nur in {_prozent(anteil)} % der Minuten des Zeitraums bekannt. Wo "
                "die Messung fehlt, wird kein Schließvorgang gefunden und kein Vergleich "
                "gezogen; die Auswertung sieht also nur einen Teil des Zeitraums."
            )
    if k.n_lief_schon:
        out.append(
            f"{k.n_lief_schon} von {k.n} Schließvorgängen trafen eine schon laufende Maschine. Sie "
            "stehen im Raster, zählen aber nicht in die Folgequote: an ihnen lässt sich nicht "
            "ablesen, ob der Kontakt etwas auslöst."
        )
    unklar = k.n - k.n_lief_schon - k.n_auswertbar
    if unklar > 0:
        out.append(
            _zahl(
                unklar,
                "Schließvorgang ist nicht auswertbar",
                "Schließvorgänge sind nicht auswertbar",
            )
            + ": davor oder danach fehlt die Messung der Leistung."
        )
    v = k.vergleich
    ohne = k.n_auswertbar - v.ereignisse_gedeckt
    if k.n_auswertbar and ohne > 0:
        out.append(
            "Für "
            + _zahl(ohne, "Ereignis", "Ereignisse")
            + " gibt es zur selben Tageszeit keinen Vergleichsmoment; "
            + ("es geht" if ohne == 1 else "sie gehen")
            + " nicht in die Vergleichsquote ein."
        )
    if k.nachlauf_n:
        out.append(
            f"Nach dem Öffnen lief die Maschine im Median noch {k.nachlauf_median_min:.0f} Minuten "
            f"weiter ({_faelle(k.nachlauf_n)}). Das Öffnen hält sie also nicht an - es ist eine "
            "Anforderung, die endet, keine Sperre, die beginnt."
        )
    return out
