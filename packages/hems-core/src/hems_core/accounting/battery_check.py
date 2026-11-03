"""Stimmt die Speicherbilanz? Die Leistungsmessung gegen den Ladestand halten.

**Warum es diese Prüfung gibt.** Die Speicherauswertung rechnet alles aus einer einzigen Reihe,
`battery_power_kw`: was negativ ist, ist Ladung, was positiv ist, Entladung. Daraus folgen die
geladene Menge, die Netzladung und der Wirkungsgrad. Stimmt diese eine Reihe nicht, stimmt keine
der Zahlen, und zwar alle im selben Sinn - ohne dass die Auswertung sich dabei widerspricht. Ein
auffälliger Wert lässt sich deshalb aus der Auswertung heraus nicht beurteilen.

**Zwei Zeugen, die bisher niemand gehört hat.** Beide liegen minütlich in derselben Tabelle:

* **Der Ladestand** (`battery_soc`) kommt aus dem Speicher selbst und ist von der Leistungsmessung
  unabhängig. Was geladen wird, muss er sehen. Er ist grob - ein Prozentpunkt ist bei 5 kWh rund
  50 Wh -, aber über Stunden gemittelt wird aus der groben Stufe eine scharfe Schranke: Steht er
  sechs Stunden still, können in dieser Zeit höchstens 50 Wh hineingegangen sein, also keine
  10 W im Mittel.
* **Der Hausverbrauch des Hubs** (`house_power_kw`) wird an anderen Stromwandlern gemessen als die
  Speicherleistung. Die Bilanz `PV + Netz + Speicher = Haus` muss aufgehen. Tut sie es nicht,
  meldet eine der drei Messungen etwas, das die anderen nicht sehen.

**Was die Prüfung damit trennt.** Für eine zu hohe Netzladung gibt es drei Erklärungen, und sie
verlangen völlig verschiedene Antworten:

1. *Der Speicher lädt wirklich aus dem Netz.* Dann steigt der Ladestand dabei. Die Auswertung hat
   recht, und die Frage geht an die Einstellungen des Geräts.
2. *Es fließt wirklich Strom, aber er kommt nie im Speicher an.* Der Ladestand steigt nicht, die
   Leistungsbilanz geht trotzdem auf: Das Gerät verbraucht ihn selbst (Wechselrichter, Standby,
   Kühlung). Dann ist es keine Ladung, sondern ein Verbraucher, und er gehört nicht in die
   Speicherbilanz.
3. *Es fließt gar nichts.* Der Ladestand steigt nicht, und die Leistungsbilanz geht nicht auf: Der
   Stromwandler des Speichers meldet eine Leistung, die kein anderes Messgerät sieht - ein
   Nullpunktfehler.

Reine Rechenlogik über Minutenreihen, kein I/O, keine Zeitzone.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime

#: Unter dieser Leistung gilt der Speicher als ruhend.
RUHE_KW = 0.05
#: So fein meldet der Speicher seinen Ladestand. Daraus folgt die Schranke jeder Ruhe-Aussage.
SOC_STUFE = 0.01
#: So lange muss der Ladestand stillstehen, damit die Strecke etwas aussagt. Eine Stunde macht aus
#: der groben Stufe eine Schranke von 50 Wh/h, also rund 50 W - scharf genug für die Frage.
RUHE_MIN_MINUTEN = 60
#: Ab diesem Ladestand ist Ladung bei stehendem Zeiger normal: ein voller Speicher nimmt noch
#: Ausgleichsladung an, ohne dass die Anzeige weiterzählt. Solche Strecken zählen nicht mit.
VOLL_SOC = 0.98
#: Mindestlänge einer Lade- oder Entladestrecke für die Wirkungsgradschätzung.
EPISODE_MIN_MINUTEN = 15
#: So weit muss sich der Ladestand in einer Strecke bewegen, sonst ist die Stufe größer als das
#: Ergebnis.
EPISODE_MIN_SOC = 0.03
#: Ab diesem Anteil der Ladung ist der Verlust nicht mehr mit Umwandlung zu erklären. Ein
#: LFP-Speicher mit Hybridwechselrichter liegt im Umlauf bei 10 bis 20 Prozent. Die Schwelle stand
#: zuerst bei 25 % und damit über dem, was derselbe Satz als erklärbar ausgibt: Ein Monat mit genau
#: 25 % Verlust bekam „unauffällig" und daneben die Begründung, Umwandlung erkläre höchstens 20.
VERLUST_AUFFAELLIG = 0.20
#: Ab diesem Restglied im Mittel passt die Leistungsbilanz nicht mehr zusammen.
RESTGLIED_AUFFAELLIG_KW = 0.05
#: Bis hierher gilt der Speicher als leer. Darüber ist eine Ladung aus dem Netz eine Entscheidung,
#: darunter ist sie die Selbsterhaltung des Geräts - siehe `hems_core.control.battery_reserve`:
#: Der Libbi holt sich am Ende seiner Entladung rund 6 % aus dem Netz zurück (Fehlercode 233).
TIEF_SOC = 0.15


@dataclass(frozen=True)
class SpeicherProbe:
    """Eine Minute. Jedes Feld darf fehlen; was fehlt, wird nicht geraten."""

    at: datetime
    pv_kw: float | None = None
    grid_kw: float | None = None
    battery_kw: float | None = None
    #: Hausverbrauch, wie ihn der Hub an eigenen Wandlern misst - nicht der gerechnete.
    house_kw: float | None = None
    #: Ladestand 0 bis 1.
    soc: float | None = None


@dataclass(frozen=True)
class Abschnitt:
    """Ein Zeitraum: was die Leistungsmessung sagt, was der Ladestand sagt, was fehlt."""

    von: datetime
    bis: datetime
    minuten: int
    laden_kwh: float
    entladen_kwh: float
    #: Nur Ladung in Minuten ganz ohne Erzeugung - die Zahl, um die es auf der Speicherseite geht.
    laden_dunkel_kwh: float
    soc_von: float | None
    soc_bis: float | None
    #: Was der Ladestand an Inhaltsänderung behauptet, in kWh.
    delta_speicher_kwh: float | None
    #: Mittleres Restglied `PV + Netz + Speicher − Haus` über die Minuten, die alle vier kennen.
    restglied_kw: float | None
    restglied_minuten: int
    #: Minuten, in denen der Speicher nicht ruhte. Ein Wechselrichter, der wach ist, kostet
    #: auch dann etwas, wenn er wenig bewegt - und ohne diese Zahl ließe sich das nicht von
    #: einem Verlust unterscheiden, der am Durchsatz hängt.
    aktiv_minuten: int = 0

    @property
    def verlust_kwh(self) -> float | None:
        """Was hineinging, aber weder herauskam noch im Speicher landete."""
        if self.delta_speicher_kwh is None:
            return None
        return round(self.laden_kwh - self.entladen_kwh - self.delta_speicher_kwh, 3)

    @property
    def verlust_anteil(self) -> float | None:
        """Der Verlust, gemessen an der Ladung. Umwandlung erklärt 0,10 bis 0,20."""
        v = self.verlust_kwh
        if v is None or self.laden_kwh <= 1e-6:
            return None
        return round(v / self.laden_kwh, 4)


@dataclass(frozen=True)
class RuheBefund:
    """Was die Leistungsmessung sagt, während der Ladestand nachweislich stillsteht."""

    minuten: int
    strecken: int
    laden_kwh: float
    entladen_kwh: float

    def plus(self, other: RuheBefund) -> RuheBefund:
        return RuheBefund(
            self.minuten + other.minuten,
            self.strecken + other.strecken,
            round(self.laden_kwh + other.laden_kwh, 3),
            round(self.entladen_kwh + other.entladen_kwh, 3),
        )

    @property
    def stunden(self) -> float:
        return self.minuten / 60.0

    @property
    def mittel_kw(self) -> float | None:
        """Mittlere gemeldete Leistung; positiv heißt, es wurde im Mittel Ladung gemeldet."""
        if self.minuten <= 0:
            return None
        return round((self.laden_kwh - self.entladen_kwh) / self.stunden, 4)

    @property
    def schranke_kw(self) -> float | None:
        """Was in dieser Zeit höchstens geflossen sein kann, ohne den Zeiger zu bewegen.

        Eine Stufe je Strecke: mehr kann sich der Ladestand nicht verschweigen.
        """
        if self.minuten <= 0:
            return None
        return round(self.strecken * SOC_STUFE / self.stunden, 4)


@dataclass(frozen=True)
class Wirkungsgrade:
    """Aus reinen Lade- und Entladestrecken, je gegen den Ladestand gerechnet.

    Gespeichert werden die Summen und nicht die Quotienten: Nur so lassen sich Teilzeiträume
    addieren, ohne Mittelwerte von Mittelwerten zu bilden.
    """

    laden_gemessen_kwh: float = 0.0
    laden_angekommen_kwh: float = 0.0
    laden_strecken: int = 0
    entladen_gemessen_kwh: float = 0.0
    entladen_entnommen_kwh: float = 0.0
    entladen_strecken: int = 0

    @property
    def laden(self) -> float | None:
        """Was ankam, geteilt durch das, was hineinging."""
        if self.laden_gemessen_kwh <= 1e-6 or not self.laden_strecken:
            return None
        return round(self.laden_angekommen_kwh / self.laden_gemessen_kwh, 3)

    @property
    def entladen(self) -> float | None:
        """Was herauskam, geteilt durch das, was der Speicher dabei verlor."""
        if self.entladen_entnommen_kwh <= 1e-6 or not self.entladen_strecken:
            return None
        return round(self.entladen_gemessen_kwh / self.entladen_entnommen_kwh, 3)

    def plus(self, other: Wirkungsgrade) -> Wirkungsgrade:
        return Wirkungsgrade(
            laden_gemessen_kwh=self.laden_gemessen_kwh + other.laden_gemessen_kwh,
            laden_angekommen_kwh=self.laden_angekommen_kwh + other.laden_angekommen_kwh,
            laden_strecken=self.laden_strecken + other.laden_strecken,
            entladen_gemessen_kwh=self.entladen_gemessen_kwh + other.entladen_gemessen_kwh,
            entladen_entnommen_kwh=self.entladen_entnommen_kwh + other.entladen_entnommen_kwh,
            entladen_strecken=self.entladen_strecken + other.entladen_strecken,
        )


@dataclass(frozen=True)
class Aufteilung:
    """Woran der Verlust haengt: an der Zeit oder an der Menge.

    Zwei Ursachen sehen in einer Monatssumme gleich aus und verlangen verschiedene Antworten. Ein
    **Umwandlungsverlust** waechst mit dem Durchsatz: Wer doppelt so viel durch den Speicher
    schickt, verliert doppelt so viel. Ein **Eigenverbrauch des Geraets** waechst mit der Zeit, in
    der es wach ist, und ist an einem ruhigen Tag genauso gross wie an einem geschaeftigen.

    Beides zugleich zu schaetzen geht, weil die Tage sich unterscheiden: An einem Tag mit 12 kWh
    Durchsatz und einem mit 5 kWh ist der zeitabhaengige Teil derselbe, der mengenabhaengige nicht.
    Gefittet wird ohne Achsenabschnitt - ein Speicher, der nicht laeuft, verliert nichts.
    """

    #: Verlust je Stunde, in der der Speicher nicht ruhte, in Watt.
    grundlast_w: float | None
    #: Zusaetzlicher Verlust als Anteil des Durchsatzes (Laden plus Entladen).
    anteil: float | None
    tage: int
    #: Mittlerer Betrag, um den die Schaetzung je Tag danebenliegt, in kWh.
    streuung_kwh: float | None


def aufteilung(tage: Sequence[Abschnitt]) -> Aufteilung:
    """Den Verlust in einen zeit- und einen mengenabhaengigen Teil zerlegen.

    Kleinste Quadrate ueber die Tage: `Verlust = a * aktive Stunden + b * Durchsatz`. Weniger als
    eine Handvoll brauchbarer Tage ergibt keine Gerade, und Tage, die sich im Verhaeltnis von
    aktiver Zeit zu Durchsatz nicht unterscheiden, auch nicht - dann steht hier nichts.
    """
    punkte = [
        (t.aktiv_minuten / 60.0, t.laden_kwh + t.entladen_kwh, t.verlust_kwh)
        for t in tage
        if t.verlust_kwh is not None and t.aktiv_minuten > 0
    ]
    if len(punkte) < 5:
        return Aufteilung(None, None, len(punkte), None)
    s11 = sum(x1 * x1 for x1, _, _ in punkte)
    s12 = sum(x1 * x2 for x1, x2, _ in punkte)
    s22 = sum(x2 * x2 for _, x2, _ in punkte)
    sy1 = sum(x1 * (y or 0.0) for x1, _, y in punkte)
    sy2 = sum(x2 * (y or 0.0) for _, x2, y in punkte)
    det = s11 * s22 - s12 * s12
    if abs(det) < 1e-9:
        return Aufteilung(None, None, len(punkte), None)
    a = (sy1 * s22 - sy2 * s12) / det
    b = (sy2 * s11 - sy1 * s12) / det
    streuung = sum(abs((y or 0.0) - a * x1 - b * x2) for x1, x2, y in punkte) / len(punkte)
    return Aufteilung(round(a * 1000.0, 1), round(b, 4), len(punkte), round(streuung, 3))


@dataclass(frozen=True)
class SpeicherBefund:
    kapazitaet_kwh: float
    gesamt: Abschnitt
    tage: list[Abschnitt]
    ruhe: RuheBefund
    ruhe_voll_minuten: int
    wirkungsgrade: Wirkungsgrade
    tief: TiefBefund
    verlustquelle: Aufteilung = Aufteilung(None, None, 0, None)


def _summe(werte: Sequence[float | None]) -> float:
    return sum(w for w in werte if w is not None)


def abschnitt(proben: Sequence[SpeicherProbe], kapazitaet_kwh: float) -> Abschnitt:
    """Einen Zeitraum zusammenfassen. Jede Probe zählt eine Minute."""
    rows = sorted(proben, key=lambda p: p.at)
    if not rows:
        jetzt = datetime.min
        return Abschnitt(jetzt, jetzt, 0, 0.0, 0.0, 0.0, None, None, None, None, 0)
    laden = entladen = dunkel = 0.0
    aktiv = 0
    rest: list[float] = []
    for p in rows:
        b = p.battery_kw
        if b is not None:
            laden += max(0.0, -b) / 60.0
            entladen += max(0.0, b) / 60.0
            if abs(b) > RUHE_KW:
                aktiv += 1
            # „Dunkel" heißt: keine Erzeugung gemessen. Eine fehlende PV-Messung ist nicht dunkel.
            if b < 0 and p.pv_kw is not None and p.pv_kw <= 1e-9:
                dunkel += -b / 60.0
        if None not in (p.pv_kw, p.grid_kw, p.battery_kw, p.house_kw):
            rest.append(
                (p.pv_kw or 0.0) + (p.grid_kw or 0.0) + (p.battery_kw or 0.0) - (p.house_kw or 0.0)
            )
    mit_soc = [p for p in rows if p.soc is not None]
    soc_von = mit_soc[0].soc if mit_soc else None
    soc_bis = mit_soc[-1].soc if mit_soc else None
    delta = (
        round((soc_bis - soc_von) * kapazitaet_kwh, 4)
        if soc_von is not None and soc_bis is not None
        else None
    )
    return Abschnitt(
        von=rows[0].at,
        bis=rows[-1].at,
        minuten=len(rows),
        laden_kwh=round(laden, 3),
        entladen_kwh=round(entladen, 3),
        laden_dunkel_kwh=round(dunkel, 3),
        soc_von=soc_von,
        soc_bis=soc_bis,
        delta_speicher_kwh=delta,
        restglied_kw=round(sum(rest) / len(rest), 4) if rest else None,
        restglied_minuten=len(rest),
        aktiv_minuten=aktiv,
    )


@dataclass(frozen=True)
class Nachladung:
    """Eine Ladung aus dem Netz, die am leeren Speicher begann."""

    at: datetime
    soc: float
    kwh: float
    minuten: int


@dataclass(frozen=True)
class TiefBefund:
    """Wie oft und wie viel der Speicher sich am unteren Ende aus dem Netz zurückgeholt hat.

    Das ist keine Vermutung, sondern ein am Gerät beobachtetes Verhalten: `battery_reserve` hält
    fest, dass der Libbi nach einer Stunde bei 0 % rund 6 % nachlädt und diese Energie kurz darauf
    wieder verschwunden ist, ohne dass das Haus etwas davon bekommen hat. Jede solche Nachladung
    kostet Netzstrom, Wirkungsgrad und einen Zyklus im ungünstigsten Bereich der Zelle.
    """

    anzahl: int = 0
    kwh: float = 0.0
    beispiele: tuple[Nachladung, ...] = ()

    def plus(self, other: TiefBefund) -> TiefBefund:
        beide = sorted([*self.beispiele, *other.beispiele], key=lambda n: -n.kwh)[:5]
        return TiefBefund(self.anzahl + other.anzahl, round(self.kwh + other.kwh, 3), tuple(beide))


def tief_nachladungen(proben: Sequence[SpeicherProbe], soc_grenze: float = TIEF_SOC) -> TiefBefund:
    """Ladestrecken ohne Erzeugung, die bei leerem Speicher beginnen.

    Ohne Erzeugung, weil es um Netzladung geht; bei leerem Speicher, weil nur dort die
    Selbsterhaltung des Geräts greift. Eine Nachtladung bei halbvollem Speicher wäre etwas
    anderes - eine Einstellung, keine Notmaßnahme - und steht deshalb nicht hier.
    """
    rows = sorted(proben, key=lambda p: p.at)
    dunkel = [
        p if (p.pv_kw is not None and p.pv_kw <= 1e-9) else SpeicherProbe(at=p.at, soc=p.soc)
        for p in rows
    ]
    out: list[Nachladung] = []
    for lauf in _strecken(dunkel, laden=True):
        mit = [p for p in lauf if p.soc is not None]
        if not mit or (mit[0].soc or 1.0) > soc_grenze:
            continue
        kwh = sum(max(0.0, -(p.battery_kw or 0.0)) / 60.0 for p in lauf)
        out.append(
            Nachladung(at=lauf[0].at, soc=mit[0].soc or 0.0, kwh=round(kwh, 4), minuten=len(lauf))
        )
    groesste = tuple(sorted(out, key=lambda n: -n.kwh)[:5])
    return TiefBefund(len(out), round(sum(n.kwh for n in out), 3), groesste)


def summe_abschnitte(teile: Sequence[Abschnitt]) -> Abschnitt:
    """Teilabschnitte zu einem zusammenfassen, ohne alle Minuten noch einmal zu halten.

    Der Ladestand wird nicht gemittelt, sondern an den Rändern genommen: Anfang des ersten Teils,
    Ende des letzten. Das Restglied ist das mit den Minuten gewichtete Mittel; ungewichtet wäre ein
    Tag mit zwanzig brauchbaren Minuten so schwer wie einer mit tausend.
    """
    rows = [t for t in sorted(teile, key=lambda t: t.von) if t.minuten > 0]
    if not rows:
        jetzt = datetime.min
        return Abschnitt(jetzt, jetzt, 0, 0.0, 0.0, 0.0, None, None, None, None, 0)
    mit_soc = [t for t in rows if t.soc_von is not None and t.soc_bis is not None]
    soc_von = mit_soc[0].soc_von if mit_soc else None
    soc_bis = mit_soc[-1].soc_bis if mit_soc else None
    rest_min = sum(t.restglied_minuten for t in rows)
    rest = (
        round(
            sum((t.restglied_kw or 0.0) * t.restglied_minuten for t in rows) / rest_min,
            4,
        )
        if rest_min
        else None
    )
    # Die Kapazität steckt schon in den Teilsummen; sie wird aus einem Teil zurückgerechnet, damit
    # die Summe sie nicht noch einmal übergeben bekommen muss.
    kap = next(
        (
            t.delta_speicher_kwh / (t.soc_bis - t.soc_von)
            for t in mit_soc
            if t.delta_speicher_kwh is not None
            and t.soc_bis is not None
            and t.soc_von is not None
            and abs(t.soc_bis - t.soc_von) > 1e-9
        ),
        None,
    )
    delta = (
        round((soc_bis - soc_von) * kap, 4)
        if soc_von is not None and soc_bis is not None and kap is not None
        else None
    )
    return Abschnitt(
        von=rows[0].von,
        bis=rows[-1].bis,
        minuten=sum(t.minuten for t in rows),
        laden_kwh=round(sum(t.laden_kwh for t in rows), 3),
        entladen_kwh=round(sum(t.entladen_kwh for t in rows), 3),
        laden_dunkel_kwh=round(sum(t.laden_dunkel_kwh for t in rows), 3),
        soc_von=soc_von,
        soc_bis=soc_bis,
        delta_speicher_kwh=delta,
        restglied_kw=rest,
        restglied_minuten=rest_min,
        aktiv_minuten=sum(t.aktiv_minuten for t in rows),
    )


def _laeufe(rows: Sequence[SpeicherProbe]) -> list[list[SpeicherProbe]]:
    """Die Reihe in Strecken mit unverändertem Ladestand zerlegen.

    Eine Lücke von mehr als einer Minute beendet eine Strecke: Was dazwischen geschah, weiß
    niemand, und eine Schranke über eine unbekannte Zeit ist keine Schranke.
    """
    out: list[list[SpeicherProbe]] = []
    for p in rows:
        if p.soc is None:
            continue
        if out and out[-1][-1].soc == p.soc and (p.at - out[-1][-1].at).total_seconds() <= 90:
            out[-1].append(p)
        else:
            out.append([p])
    return out


def ruhe_befund(proben: Sequence[SpeicherProbe]) -> tuple[RuheBefund, int]:
    """Was gemeldet wurde, während der Ladestand stillstand. Zusätzlich: Minuten am vollen Ende.

    Am vollen Speicher ist Ladung bei stehendem Zeiger normal, deshalb zählt sie nicht in den
    Befund - sie wird nur gezählt, damit die Zahl nicht unerklärt fehlt.
    """
    rows = sorted(proben, key=lambda p: p.at)
    minuten = strecken = voll = 0
    laden = entladen = 0.0
    for lauf in _laeufe(rows):
        if len(lauf) < RUHE_MIN_MINUTEN:
            continue
        if (lauf[0].soc or 0.0) >= VOLL_SOC:
            voll += len(lauf)
            continue
        strecken += 1
        minuten += len(lauf)
        for p in lauf:
            if p.battery_kw is None:
                continue
            laden += max(0.0, -p.battery_kw) / 60.0
            entladen += max(0.0, p.battery_kw) / 60.0
    return RuheBefund(minuten, strecken, round(laden, 3), round(entladen, 3)), voll


def _strecken(rows: Sequence[SpeicherProbe], laden: bool) -> list[list[SpeicherProbe]]:
    """Zusammenhängende Minuten, in denen nur geladen (oder nur entladen) wurde."""
    out: list[list[SpeicherProbe]] = []
    offen = False
    for p in rows:
        b = p.battery_kw
        passt = b is not None and (-b > RUHE_KW if laden else b > RUHE_KW)
        if passt and offen and (p.at - out[-1][-1].at).total_seconds() <= 90:
            out[-1].append(p)
        elif passt:
            out.append([p])
            offen = True
        else:
            offen = False
    return out


def wirkungsgrade(proben: Sequence[SpeicherProbe], kapazitaet_kwh: float) -> Wirkungsgrade:
    """Lade- und Entladewirkungsgrad aus reinen Strecken, je gegen den Ladestand.

    Nur Strecken, die lang genug sind und in denen der Ladestand sich weit genug bewegt hat: Bei
    einem Prozentpunkt Auflösung wäre das Ergebnis sonst von der Rundung bestimmt.
    """
    rows = sorted(proben, key=lambda p: p.at)
    summen: dict[bool, tuple[float, float, int]] = {}
    for laden in (True, False):
        gemessen = bewegt = 0.0
        n = 0
        for s in _strecken(rows, laden):
            if len(s) < EPISODE_MIN_MINUTEN:
                continue
            mit = [p for p in s if p.soc is not None]
            if len(mit) < 2:
                continue
            d = (mit[-1].soc or 0.0) - (mit[0].soc or 0.0)
            if (d if laden else -d) < EPISODE_MIN_SOC:
                continue
            gemessen += sum(
                (max(0.0, -(p.battery_kw or 0.0)) if laden else max(0.0, p.battery_kw or 0.0))
                / 60.0
                for p in s
            )
            bewegt += abs(d) * kapazitaet_kwh
            n += 1
        summen[laden] = (round(gemessen, 4), round(bewegt, 4), n)
    gem_l, bew_l, n_l = summen[True]
    gem_e, bew_e, n_e = summen[False]
    return Wirkungsgrade(gem_l, bew_l, n_l, gem_e, bew_e, n_e)


def pruefe_speicher(
    proben: Sequence[SpeicherProbe], kapazitaet_kwh: float, tagesgrenzen: Sequence[datetime] = ()
) -> SpeicherBefund:
    """Den ganzen Befund bilden. `tagesgrenzen` sind aufsteigende Anfänge der Teilabschnitte."""
    rows = sorted(proben, key=lambda p: p.at)
    ruhe, voll = ruhe_befund(rows)
    tage: list[Abschnitt] = []
    grenzen = list(tagesgrenzen)
    for i, start in enumerate(grenzen):
        ende = grenzen[i + 1] if i + 1 < len(grenzen) else None
        teil = [p for p in rows if p.at >= start and (ende is None or p.at < ende)]
        if teil:
            tage.append(abschnitt(teil, kapazitaet_kwh))
    return SpeicherBefund(
        kapazitaet_kwh=kapazitaet_kwh,
        gesamt=abschnitt(rows, kapazitaet_kwh),
        tage=tage,
        ruhe=ruhe,
        ruhe_voll_minuten=voll,
        wirkungsgrade=wirkungsgrade(rows, kapazitaet_kwh),
        tief=tief_nachladungen(rows),
        verlustquelle=aufteilung(tage),
    )


def speicher_urteil(b: SpeicherBefund) -> list[str]:
    """Der Befund in Sätzen: welche der drei Erklärungen die Zahlen tragen.

    Bewusst keine einzelne Diagnose. Die Prüfung kann sagen, welche Erklärungen die Daten
    ausschließen; welche der übrigen zutrifft, entscheidet sich am Gerät.
    """
    g = b.gesamt
    out: list[str] = []
    anteil = g.verlust_anteil
    if anteil is None:
        return [
            "Kein Ladestand im Zeitraum: ohne ihn lässt sich die Leistungsmessung mit nichts "
            "vergleichen, und die Prüfung kann nichts ausschließen."
        ]
    if anteil < VERLUST_AUFFAELLIG:
        out.append(
            f"Unauffällig. Von {g.laden_kwh:.1f} kWh Ladung sind {anteil:.0%} weder herausgekommen "
            "noch im Ladestand sichtbar; Umwandlungsverluste erklären das."
        )
        return out

    out.append(
        f"Auffällig: Von {g.laden_kwh:.1f} kWh gemeldeter Ladung sind {g.verlust_kwh:.1f} kWh "
        f"({anteil:.0%}) weder wieder herausgekommen noch im Ladestand angekommen. "
        "Umwandlung erklärt 10 bis 20 Prozent."
    )
    ruhe_kw = b.ruhe.mittel_kw
    schranke = b.ruhe.schranke_kw
    if ruhe_kw is not None and schranke is not None and b.ruhe.minuten >= RUHE_MIN_MINUTEN:
        if ruhe_kw > max(RUHE_KW, 2 * schranke):
            out.append(
                f"Der Ladestand stand in diesem Zeitraum {b.ruhe.stunden:.0f} Stunden still "
                f"({b.ruhe.strecken} Strecken). In dieser Zeit meldete die Leistungsmessung im "
                f"Mittel {ruhe_kw:.3f} kW Ladung. Mehr als {schranke:.3f} kW kann der Ladestand "
                "nicht verbergen. Diese Ladung ist im Speicher nie angekommen."
            )
        else:
            out.append(
                f"Bei stillstehendem Ladestand ({b.ruhe.stunden:.0f} Stunden) meldet die "
                f"Leistungsmessung im Mittel {ruhe_kw:.3f} kW. Das liegt im Rahmen dessen, was "
                "die Stufe des Ladestands verbergen kann: Hier ist kein Nullpunktfehler zu sehen."
            )
    else:
        out.append(
            "Keine Strecke, in der der Ladestand lange genug stillstand: Ein Nullpunktfehler "
            "lässt sich damit weder zeigen noch ausschließen."
        )

    rest = g.restglied_kw
    if rest is None or g.restglied_minuten < 60:
        out.append(
            "Der Hausverbrauch des Hubs fehlt im Zeitraum. Ohne ihn bleibt offen, ob der Strom "
            "wirklich floss: Dafür müsste `house_power_kw` aufgezeichnet sein."
        )
    elif abs(rest) <= RESTGLIED_AUFFAELLIG_KW:
        out.append(
            f"Die Leistungsbilanz geht auf (Restglied im Mittel {rest:+.3f} kW über "
            f"{g.restglied_minuten} Minuten). Der Strom ist also wirklich geflossen, die anderen "
            "Messgeräte sehen ihn. Er ist nur nicht im Speicher angekommen, sondern im Gerät "
            "geblieben: Das ist ein Verbraucher, keine Ladung."
        )
    else:
        out.append(
            f"Die Leistungsbilanz geht nicht auf: Restglied im Mittel {rest:+.3f} kW über "
            f"{g.restglied_minuten} Minuten. Die Speichermessung meldet damit Leistung, die weder "
            "Zähler noch Hub sehen. Das deutet auf den Stromwandler des Speichers."
        )

    v = b.verlustquelle
    if v.grundlast_w is not None and v.anteil is not None:
        zeit = v.grundlast_w * (g.aktiv_minuten / 60.0) / 1000.0
        menge = v.anteil * (g.laden_kwh + g.entladen_kwh)
        out.append(
            f"Der Verlust haengt ueberwiegend an der Zeit, nicht an der Menge: ueber "
            f"{v.tage} Tage gerechnet {v.grundlast_w:.0f} W, solange der Speicher nicht ruht, "
            f"dazu {v.anteil:.0%} des Durchsatzes. Das macht {zeit:.0f} kWh gegen {menge:.0f} kWh. "
            "Ein Umwandlungsverlust waechst mit dem Durchsatz; was mit der Zeit waechst, ist der "
            "Eigenverbrauch des Geraets und gehoert nicht in die Speicherbilanz."
        )

    t = b.tief
    if t.anzahl:
        anteil_txt = (
            f" Das sind {t.kwh / g.laden_dunkel_kwh:.0%} der Ladung ohne Erzeugung."
            if g.laden_dunkel_kwh > 1e-6
            else ""
        )
        out.append(
            f"{t.anzahl} Ladungen aus dem Netz begannen bei einem Ladestand von höchstens "
            f"{TIEF_SOC:.0%}, zusammen {t.kwh:.1f} kWh.{anteil_txt} Das ist das bekannte "
            "Verhalten des Geräts am leeren Speicher (SoC Recovery, Fehlercode 233): Es holt sich "
            "zurück, was es für die eigene Erhaltung braucht. Dagegen hilft keine Rechnung, "
            "sondern eine Untergrenze, die den Speicher anhält, bevor er dort ankommt."
        )

    w = b.wirkungsgrade
    if w.laden is not None:
        out.append(
            f"Aus {w.laden_strecken} reinen Ladestrecken gegen den Ladestand: "
            f"Ladewirkungsgrad {w.laden:.0%}."
            + (
                f" Aus {w.entladen_strecken} Entladestrecken: {w.entladen:.0%}."
                if w.entladen is not None
                else ""
            )
        )
    return out
