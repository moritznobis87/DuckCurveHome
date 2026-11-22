"""Die Lernebene: schätzen, prüfen, übernehmen - und jede Übernahme begründen.

**Der Aufbau in drei Schritten.** Ein Schätzer läuft ständig mit und liefert einen Kandidaten mit
Unsicherheit. Eine Prüfung entscheidet, ob dieser Kandidat den geltenden Wert ersetzen darf. Erst
dann ändert sich etwas an der Regelung, und es steht mit Datum, Zahlen und Grund im Protokoll.

**Warum nicht einfach der Schätzwert gilt.** Weil die Regelung sonst mit einer zitternden Zahl
arbeitet. Jeder Schätzer rauscht, und ein Regler, dessen Verstärkung minütlich eine andere ist,
ist kein lernender Regler, sondern ein unruhiger. Der geltende Wert springt deshalb nur, wenn sich
der Sprung begründen lässt: die Abweichung ist größer als die eigene Unsicherheit, es sind genug
Daten da, seit der letzten Übernahme ist Zeit vergangen, und der Restfehler ist im Vergleich über
zwei Wochen kleiner geworden. Vier Hürden, und jede hat ihren eigenen deutschen Satz, damit auf der
Oberfläche nicht nur steht, **dass** nichts übernommen wurde, sondern **warum** nicht.

**Die Plausibilitätsgrenzen sind die fünfte Hürde** und die wichtigste. Ein Schätzer, der einen
Verlustkoeffizienten von 2 kW/K ausrechnet, hat keinen Erkenntnisgewinn gehabt, sondern einen
Fühlerausfall gesehen. Was außerhalb der Grenzen liegt, wird abgelehnt und gemeldet, nicht
beschnitten und übernommen.

**Damit kann das Modell nie schlechter werden als sein Startwert.** Das ist die Eigenschaft, die
diesen Aufbau rechtfertigt: Lernen ist hier kein Versprechen auf Verbesserung, sondern eine Reihe
von Prüfungen, die im Zweifel nichts tun.

Reine Rechenlogik. Die Zustände sind serialisierbar, damit sie in `model_calibrations` liegen
können; wo sie liegen, weiß dieses Modul nicht.
"""

from __future__ import annotations

import math
from collections.abc import Sequence
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from hems_core.regelkreis.parameter import PARAMETER, Parameter

#: Vergessensfaktor der rekursiven kleinsten Quadrate. 0,995 je Stützstelle heißt: nach rund
#: 140 Stützstellen zählt eine Beobachtung nur noch halb. Bei Nachtfenstern sind das Monate, bei
#: Minutenwerten Stunden - die Wahl gehört deshalb zum Schätzer und nicht in eine globale Konstante.
VERGESSEN = 0.995
#: So viele Stützstellen mindestens, bevor eine Schätzung überhaupt vorgelegt wird.
MINDEST_N = 30
#: So viele Tage mindestens zwischen zwei Übernahmen desselben Parameters.
MINDEST_TAGE = 14.0
#: Um so viel muss der Kandidat die eigene Unsicherheit überschreiten, um als Änderung zu gelten.
SIGMA_FAKTOR = 1.35
#: Um so viel muss der Restfehler kleiner werden, damit die Übernahme als Gewinn gilt.
MINDEST_GEWINN = 0.02


class Rls(BaseModel):
    """Rekursive kleinste Quadrate mit Vergessensfaktor für ein linear parametriertes Modell.

    Das Modell ist ``y = θᵀx``. Für die Größen dieses Hauses ist das keine Einschränkung, sondern
    die natürliche Form: der Wärmestrom des Hauses ist ``H·ΔT − Q̇int``, linear in H und Q̇int; die
    Arbeitszahl ist ``a + b·Ta + c·TVL``, linear in a, b, c; die Abkühlung des Puffers ist linear
    in UA. Wo das Modell nicht linear ist, steht hier auch kein RLS.

    Mitgeführt wird die Kovarianzmatrix. Sie ist der Grund, diesen Schätzer zu nehmen und nicht
    einen gleitenden Mittelwert: aus ihrer Diagonale kommt die Unsicherheit, und ohne Unsicherheit
    gibt es keine Prüfung, sondern nur einen Glauben.
    """

    model_config = ConfigDict(extra="forbid")

    theta: list[float]
    #: Kovarianz, zeilenweise. Startet groß: am Anfang weiß der Schätzer nichts.
    p: list[list[float]]
    lam: float = VERGESSEN
    n: int = 0
    #: Gewichtete Quadratsumme der Residuen, für den Restfehler.
    quadrate: float = 0.0
    stand: datetime | None = None

    #: Erwartete Streuung der Messung, in der Einheit von y.
    #:
    #: Sie steht hier, weil die Kovarianzmatrix der rekursiven kleinsten Quadrate nicht die
    #: Unsicherheit der Parameter ist, sondern sie nur bis auf den Faktor Rauschvarianz angibt:
    #: Cov(θ) = σv² · P. Ohne eine Angabe über σv ist die Unsicherheit am ersten Tag null - und
    #: das ist die genaue Umkehrung der Wahrheit, denn am ersten Tag weiß der Schätzer nichts.
    rauschen: float = 1.0

    @classmethod
    def start(
        cls,
        theta0: Sequence[float],
        sigma0: Sequence[float],
        rauschen: float = 1.0,
        lam: float = VERGESSEN,
    ) -> Rls:
        """Ein Schätzer, der mit dem Startwert beginnt und ihm nicht traut.

        `sigma0` ist die Unsicherheit des Startwerts, `rauschen` die erwartete Streuung der
        Messung. Beides zusammen setzt die Anfangskovarianz: P₀ = (σ0/σv)². Groß gewählt heißt,
        dass die ersten Beobachtungen den Wert kräftig ziehen und spätere immer weniger.
        """
        if len(theta0) != len(sigma0) or not theta0:
            raise ValueError("Startwert und Unsicherheit müssen gleich lang und nicht leer sein")
        if rauschen <= 0:
            raise ValueError("die erwartete Streuung der Messung muss positiv sein")
        d = len(theta0)
        return cls(
            theta=[float(t) for t in theta0],
            p=[
                [((sigma0[i] / rauschen) ** 2 if i == j else 0.0) for j in range(d)]
                for i in range(d)
            ],
            rauschen=rauschen,
            lam=lam,
        )

    def schritt(self, x: Sequence[float], y: float, at: datetime | None = None) -> float:
        """Eine Beobachtung einarbeiten. Gibt das Residuum vor der Korrektur zurück.

        Das Residuum ist die eigentliche Auskunft: solange es unsystematisch um null streut, passt
        das Modell. Läuft es davon, ist nicht der Parameter falsch, sondern das Modell.
        """
        d = len(self.theta)
        if len(x) != d:
            raise ValueError("Regressor passt nicht zum Parametervektor")
        px = [sum(self.p[i][j] * x[j] for j in range(d)) for i in range(d)]
        nenner = self.lam + sum(x[i] * px[i] for i in range(d))
        if nenner <= 0:
            raise ValueError("Kovarianz entartet")
        k = [px[i] / nenner for i in range(d)]
        rest = y - sum(self.theta[i] * x[i] for i in range(d))
        self.theta = [self.theta[i] + k[i] * rest for i in range(d)]
        self.p = [[(self.p[i][j] - k[i] * px[j]) / self.lam for j in range(d)] for i in range(d)]
        self.n += 1
        self.quadrate = self.lam * self.quadrate + rest * rest
        if at is not None:
            self.stand = at
        return rest

    @property
    def freiheitsgrade(self) -> int:
        return max(1, self.n - len(self.theta))

    @property
    def _wirksam(self) -> float:
        """Wirksame Zahl der Beobachtungen: bei Vergessensfaktor höchstens 1/(1−λ)."""
        if self.lam >= 1.0:
            return float(self.n)
        return min(float(self.n), 1.0 / (1.0 - self.lam))

    @property
    def belegt(self) -> bool:
        """Ob die Residuen für eine eigene Aussage über das Rauschen ausreichen."""
        return self.n >= len(self.theta) + 5

    @property
    def streuung(self) -> float:
        """Varianz des Rauschens: aus den Residuen, solange es genug gibt, sonst die Erwartung."""
        if not self.belegt:
            return self.rauschen**2
        return max(self.quadrate / max(1.0, self._wirksam), 1e-12)

    def sigma(self, i: int) -> float:
        """Unsicherheit (1σ) des i-ten Parameters: Cov(θ) = σv² · P, Wurzel der Diagonale."""
        return math.sqrt(max(0.0, self.p[i][i]) * self.streuung)

    def rmse(self) -> float | None:
        """Mittlerer Restfehler der eingearbeiteten Beobachtungen, oder `None` vor dem Beleg.

        Keine Zahl ist hier besser als eine erfundene: der Restfehler ist das Maß, an dem die
        Übernahmeprüfung entscheidet, und am dritten Tag gibt es ihn noch nicht.
        """
        if not self.belegt:
            return None
        return math.sqrt(max(self.quadrate / max(1.0, self._wirksam), 0.0))


class EwmaVerhaeltnis(BaseModel):
    """Exponentiell gewichtetes Verhältnis Ist zu Erwartung, mit Halbwertszeit in Tagen.

    Für die Prognosekorrektur: kein Modell, nur ein Faktor. Begrenzt wird nicht hier, sondern in
    der Prüfung - ein Faktor, der aus dem Band läuft, ist eine Meldung wert.
    """

    model_config = ConfigDict(extra="forbid")

    wert: float = 1.0
    halbwertszeit_tage: float = 10.0
    n: int = 0
    stand: datetime | None = None

    def schritt(self, ist: float, erwartet: float, at: datetime) -> float:
        if erwartet <= 0:
            return self.wert
        tage = 1.0
        if self.stand is not None:
            tage = max(0.0, (at - self.stand).total_seconds() / 86400.0)
        alpha = (
            1.0 - 0.5 ** (tage / self.halbwertszeit_tage) if self.halbwertszeit_tage > 0 else 1.0
        )
        self.wert = self.wert + alpha * (ist / erwartet - self.wert)
        self.n += 1
        self.stand = at
        return self.wert


#: Warum eine Schätzung übernommen wurde - oder eben nicht.
Pruefcode = Literal[
    "uebernommen",
    "zu_wenig_daten",
    "innerhalb_unsicherheit",
    "zu_frueh",
    "grenzen",
    "nicht_besser",
]


class Pruefung(BaseModel):
    """Das Ergebnis der Übernahmeprüfung, mit Satz für die Oberfläche."""

    model_config = ConfigDict(frozen=True)

    uebernehmen: bool
    code: Pruefcode
    grund: str


def _z(wert: float, stellen: int = 3) -> str:
    """Eine Zahl, wie sie in einem deutschen Satz steht: Komma statt Punkt."""
    return f"{wert:.{stellen}g}".replace(".", ",")


def _satz(code: Pruefcode, p: Parameter, **z: float) -> str:
    """Ein deutscher Satz je Code. Jeder Code hat genau einen, und jeder hat einen Test."""
    einheit = "" if p.einheit == "—" else f" {p.einheit}"
    if code == "uebernommen":
        if z.get("gewinn", 0.0) <= 0.0:
            return (
                f"Abweichung {_z(z['abstand'])}{einheit} über {SIGMA_FAKTOR:g} σ. Ein Gütevergleich "
                f"lag noch nicht vor - der bisherige Wert war nie an Messdaten geprüft worden."
            )
        return (
            f"Abweichung {_z(z['abstand'])}{einheit} über {SIGMA_FAKTOR:g} σ, Restfehler im "
            f"Vergleich über {MINDEST_TAGE:.0f} Tage um {z['gewinn'] * 100:.0f} % kleiner."
        )
    if code == "zu_wenig_daten":
        return (
            f"Erst {z['n']:.0f} von {MINDEST_N} nötigen Stützstellen. Die Schätzung läuft weiter, "
            f"die Regelung arbeitet bis dahin mit dem bisherigen Wert."
        )
    if code == "innerhalb_unsicherheit":
        return (
            f"Abweichung {_z(z['abstand'])}{einheit} liegt innerhalb der eigenen Unsicherheit "
            f"(±{_z(z['schwelle'])}). Kein Grund, den geltenden Wert anzufassen."
        )
    if code == "zu_frueh":
        return (
            f"Letzte Übernahme vor {z['tage']:.0f} Tagen; gewartet wird {MINDEST_TAGE:.0f}. "
            f"So lange braucht der Vergleich, um eine Verbesserung von einer Wetterlage zu trennen."
        )
    if code == "grenzen":
        return (
            f"Kandidat {_z(z['kandidat'])}{einheit} liegt außerhalb der Plausibilitätsgrenzen "
            f"({_z(p.unten)} bis {_z(p.oben)}). Das ist ein Mess- oder Modellfehler und keine "
            f"Erkenntnis; der Wert wird abgelehnt und nicht beschnitten."
        )
    return (
        f"Restfehler wäre {_z(z['rmse_neu'])} statt {_z(z['rmse_alt'])} - keine Verbesserung um "
        f"die nötigen {MINDEST_GEWINN * 100:.0f} %. Der bisherige Wert bleibt."
    )


def pruefe(
    pid: str,
    *,
    geltend: float,
    kandidat: float,
    sigma: float,
    n: int,
    tage_seit_uebernahme: float | None = None,
    rmse_alt: float | None = None,
    rmse_neu: float | None = None,
) -> Pruefung:
    """Darf der Kandidat den geltenden Wert ersetzen?

    Die Reihenfolge der Hürden ist nicht beliebig. Zuerst die Datenmenge, denn ohne Daten ist jede
    weitere Frage sinnlos. Dann die Plausibilität, denn ein unmöglicher Wert soll gemeldet werden,
    auch wenn er sicher wirkt. Dann die eigene Unsicherheit, dann die Wartezeit, und zuletzt der
    Gütevergleich - der ist die teuerste Prüfung und wird nur gestellt, wenn alles andere stimmt.
    """
    p = PARAMETER[pid]
    abstand = abs(kandidat - geltend)
    if n < MINDEST_N:
        return Pruefung(
            uebernehmen=False, code="zu_wenig_daten", grund=_satz("zu_wenig_daten", p, n=n)
        )
    if not (p.unten <= kandidat <= p.oben):
        return Pruefung(
            uebernehmen=False, code="grenzen", grund=_satz("grenzen", p, kandidat=kandidat)
        )
    schwelle = max(SIGMA_FAKTOR * sigma, abs(geltend) * 0.005)
    if abstand <= schwelle:
        return Pruefung(
            uebernehmen=False,
            code="innerhalb_unsicherheit",
            grund=_satz("innerhalb_unsicherheit", p, abstand=abstand, schwelle=schwelle),
        )
    if tage_seit_uebernahme is not None and tage_seit_uebernahme < MINDEST_TAGE:
        return Pruefung(
            uebernehmen=False,
            code="zu_frueh",
            grund=_satz("zu_frueh", p, tage=tage_seit_uebernahme),
        )
    gewinn = 0.0
    if rmse_alt is not None and rmse_neu is not None and rmse_alt > 0:
        gewinn = 1.0 - rmse_neu / rmse_alt
        if gewinn < MINDEST_GEWINN:
            return Pruefung(
                uebernehmen=False,
                code="nicht_besser",
                grund=_satz("nicht_besser", p, rmse_alt=rmse_alt, rmse_neu=rmse_neu),
            )
    return Pruefung(
        uebernehmen=True,
        code="uebernommen",
        grund=_satz("uebernommen", p, abstand=abstand, gewinn=gewinn),
    )


class Uebernahme(BaseModel):
    """Ein Eintrag im Änderungsprotokoll. Was sich geändert hat, und warum."""

    model_config = ConfigDict(frozen=True)

    at: datetime
    alt: float
    neu: float
    sigma: float
    n: int
    rmse_alt: float | None = None
    rmse_neu: float | None = None
    grund: str


class ParameterStand(BaseModel):
    """Der Zustand eines Parameters: was gilt, was geschätzt wird, und was war."""

    model_config = ConfigDict(extra="forbid")

    #: Der Wert, mit dem die Regelung arbeitet.
    geltend: float
    #: Die laufende Schätzung. `None` heißt: noch keine.
    schaetzung: float | None = None
    sigma: float | None = None
    n: int = 0
    stand: datetime | None = None
    #: Restfehler des Teilmodells, aus dem die Schätzung kommt.
    rmse: float | None = None
    #: Jüngste Übernahme zuletzt.
    protokoll: list[Uebernahme] = Field(default_factory=list)
    #: Letzte Prüfung, auch wenn sie abgelehnt hat - das ist die interessantere Hälfte.
    letzte_pruefung: Pruefung | None = None

    @property
    def uebernommen_am(self) -> datetime | None:
        return self.protokoll[-1].at if self.protokoll else None


#: So viele Einträge je Parameter werden behalten. Älteres steht in den Ereignissen der Anlage.
PROTOKOLL_LAENGE = 24


class Schaetzstand(BaseModel):
    """Der ganze Lernzustand, serialisierbar und versioniert.

    Liegt im Betrieb als ein Eintrag in `model_calibrations` unter `regelkreis_v1`. Die Version
    steht mit darin: ein Register, das sich ändert, darf einen alten Zustand nicht stillschweigend
    falsch auslegen.
    """

    model_config = ConfigDict(extra="ignore")

    version: int = 1
    #: Beginn der Aufzeichnung. Der Bezugspunkt für „Betriebstag".
    seit: datetime | None = None
    parameter: dict[str, ParameterStand] = Field(default_factory=dict)
    #: Was ein Mensch überschrieben hat. Gewinnt gegen jede Schätzung, bis er es freigibt.
    uebersteuert: dict[str, float] = Field(default_factory=dict)
    #: Die Schätzerzustände, nach Kennung des Schätzers (nicht des Parameters: ein RLS schätzt
    #: mehrere Parameter gemeinsam, und ihre Kovarianz gehört zusammen).
    rls: dict[str, Rls] = Field(default_factory=dict)
    ewma: dict[str, EwmaVerhaeltnis] = Field(default_factory=dict)

    def tage(self, jetzt: datetime) -> float | None:
        """Betriebstage seit Beginn der Aufzeichnung."""
        if self.seit is None:
            return None
        return max(0.0, (jetzt - self.seit).total_seconds() / 86400.0)

    def wert(self, pid: str, startwert: float) -> float:
        """Der Wert, mit dem die Regelung arbeitet: Übersteuerung, sonst geltender, sonst Start."""
        if pid in self.uebersteuert:
            return self.uebersteuert[pid]
        stand = self.parameter.get(pid)
        return stand.geltend if stand is not None else startwert

    def melde(
        self,
        pid: str,
        *,
        kandidat: float,
        sigma: float,
        n: int,
        jetzt: datetime,
        startwert: float,
        rmse_alt: float | None = None,
        rmse_neu: float | None = None,
    ) -> Pruefung:
        """Eine Schätzung vorlegen, prüfen lassen und bei Erfolg übernehmen.

        Gibt die Prüfung zurück - auch die abgelehnte, denn sie ist die Antwort auf die Frage, die
        auf der Oberfläche steht: warum gilt noch der alte Wert?

        Eine Übersteuerung hält die Übernahme an. Die Schätzung läuft weiter und wird
        mitgeschrieben, damit sichtbar bleibt, was der Schätzer gesagt hätte.
        """
        stand = self.parameter.get(pid) or ParameterStand(geltend=startwert)
        letzte = stand.uebernommen_am
        tage = None if letzte is None else (jetzt - letzte).total_seconds() / 86400.0
        pruefung = pruefe(
            pid,
            geltend=stand.geltend,
            kandidat=kandidat,
            sigma=sigma,
            n=n,
            tage_seit_uebernahme=tage,
            rmse_alt=rmse_alt,
            rmse_neu=rmse_neu,
        )
        protokoll = list(stand.protokoll)
        geltend = stand.geltend
        if pruefung.uebernehmen and pid not in self.uebersteuert:
            protokoll.append(
                Uebernahme(
                    at=jetzt,
                    alt=stand.geltend,
                    neu=kandidat,
                    sigma=sigma,
                    n=n,
                    rmse_alt=rmse_alt,
                    rmse_neu=rmse_neu,
                    grund=pruefung.grund,
                )
            )
            protokoll = protokoll[-PROTOKOLL_LAENGE:]
            geltend = kandidat
        self.parameter[pid] = ParameterStand(
            geltend=geltend,
            schaetzung=kandidat,
            sigma=sigma,
            n=n,
            stand=jetzt,
            rmse=rmse_neu if rmse_neu is not None else stand.rmse,
            protokoll=protokoll,
            letzte_pruefung=pruefung,
        )
        if self.seit is None:
            self.seit = jetzt
        return pruefung

    def uebersteuere(self, pid: str, wert: float) -> None:
        """Einen Wert von Hand setzen. Beschnitten auf die Plausibilitätsgrenzen."""
        p = PARAMETER[pid]
        self.uebersteuert[pid] = min(p.oben, max(p.unten, wert))

    def freigeben(self, pid: str) -> None:
        """Die Übersteuerung aufheben; es gilt wieder, was gelernt wurde."""
        self.uebersteuert.pop(pid, None)
