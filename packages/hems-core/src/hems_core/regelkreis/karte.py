"""Die Karte: Struktur, geltende Parameter, Entwurf und Lernzustand in einer Antwort.

Hier wird nichts entschieden und nichts geschätzt. Dieses Modul setzt zusammen, was die anderen
liefern, und bringt es in die Form, die eine Oberfläche braucht: je Block seine Parameter mit
Herkunft, je Kreis die Strecke, den daraus entworfenen Regler, seine Reserven und die
Frequenzkennlinie, dazu der Arbeitspunkt, an dem alles gerechnet wurde.

**Der Arbeitspunkt ist nicht Beiwerk, sondern Teil der Antwort.** Die Verstärkung der Wärmepumpe
hängt von Außen- und Vorlauftemperatur ab; ein Regler, der bei 10 °C ausgelegt wurde, ist bei
−5 °C ein anderer. Die Karte sagt deshalb immer, für welchen Punkt sie gilt. Wer sie mit dem
Augenblick aufruft, sieht die Einstellung, mit der die Anlage **jetzt** fährt - das ist
Verstärkungsplanung, und sie wird hier sichtbar.

**Was die Oberfläche nicht bekommt: Koordinaten.** Wo ein Kästchen liegt, ist eine Frage der
Zeichnung und keine Aussage über das Haus. Die Anzeige hält eine Tabelle von Kennung zu Ort; was
verbunden ist, steht in `struktur`.
"""

from __future__ import annotations

import math
from collections.abc import Mapping
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from hems_core.domain.config import HemsConfig
from hems_core.regelkreis import entwurf
from hems_core.regelkreis.glied import GLIEDER
from hems_core.regelkreis.parameter import (
    LAMBDA_JE_KREIS,
    PARAMETER,
    SCHAETZART_TEXT,
    Herkunft,
    Schaetzart,
    startwerte,
)
from hems_core.regelkreis.schaetzer import Messpunkt, Pruefung, Schaetzstand, Uebernahme
from hems_core.regelkreis.struktur import (
    BEHANDLUNG_TEXT,
    BLOECKE,
    KANTEN,
    KREIS_NACH_ID,
    KREISE,
    ROLLE_TEXT,
    Behandlung,
    Ebene,
    Kantenart,
    Kreis,
    Rolle,
)

#: Innerhalb dieser Aussentemperaturen ist ein Umschaltpunkt eine Auskunft. Die Grenzen sind die
#: des Betriebs dieses Hauses, nicht die der Rechnung.
UMSCHALT_VON_C = -15.0
UMSCHALT_BIS_C = 18.0


class Arbeitspunkt(BaseModel):
    """Der Punkt, für den die Karte gerechnet wird."""

    model_config = ConfigDict(frozen=True)

    aussen_c: float
    vorlauf_c: float
    #: Strompreis in €/kWh, wie ihn der Fahrplan gerade ansetzt.
    strompreis_eur_kwh: float
    #: Ob die Außentemperatur gemessen war.
    aussen_gemessen: bool = False
    #: Ob die Vorlauftemperatur gemessen war - oder aus der Heizkennlinie gerechnet.
    #:
    #: Beides getrennt auszuweisen ist nicht Pedanterie. Die Arbeitszahl hängt an beiden
    #: Temperaturen; wer die Reglerwerte dieser Karte für gemessen hält, obwohl die
    #: Vorlauftemperatur aus einer Kennlinie mit geschätzter Steilheit kam, hält eine
    #: Modellrechnung für eine Messung.
    vorlauf_gemessen: bool = False

    @staticmethod
    def aus_konfiguration(cfg: HemsConfig) -> Arbeitspunkt:
        """Der Auslegungspunkt, solange keine Messung vorliegt: kalter Tag, Zielvorlauf."""
        return Arbeitspunkt(
            aussen_c=2.0,
            vorlauf_c=min(cfg.buffer.target_temperature_c, 40.0),
            strompreis_eur_kwh=cfg.tariff.fallback_import_ct_kwh / 100.0,
        )


class ParameterAnsicht(BaseModel):
    """Ein Parameter, wie ihn die Oberfläche zeigt."""

    model_config = ConfigDict(frozen=True)

    id: str
    block: str
    symbol: str
    name: str
    einheit: str
    stellen: int
    #: Der Wert, mit dem die Regelung arbeitet.
    wert: float
    herkunft: Herkunft
    schaetzart: Schaetzart
    schaetzart_text: str
    #: Der Startwert aus Konfiguration oder Datenblatt - der Bezugspunkt jeder Übernahme.
    startwert: float
    #: Die laufende Schätzung, auch wenn sie noch nicht gilt.
    schaetzung: float | None = None
    sigma: float | None = None
    n: int = 0
    stand: datetime | None = None
    rmse: float | None = None
    unten: float
    oben: float
    warum: str
    quelle: str | None = None
    wirkt_auf: list[str] = Field(default_factory=list)
    protokoll: list[Uebernahme] = Field(default_factory=list)
    #: Der Weg der Schätzung über die Zeit, älteste zuerst - das Bild zum Protokoll.
    verlauf: list[Messpunkt] = Field(default_factory=list)
    #: Die letzte Prüfung. Bei einer Ablehnung steht hier, warum noch der alte Wert gilt.
    pruefung: Pruefung | None = None


class StreckeAnsicht(BaseModel):
    """Das Streckenmodell eines Kreises, in Zahlen."""

    model_config = ConfigDict(frozen=True)

    art: Literal["foptd", "iptd"]
    k: float
    t1: float = 0.0
    t2: float = 0.0
    totzeit: float
    #: Nach der Halbregel, wenn zwei Zeitkonstanten zu einer wurden.
    t1_entwurf: float
    totzeit_entwurf: float
    halbregel: bool


class ReglerAnsicht(BaseModel):
    model_config = ConfigDict(frozen=True)

    kp: float
    tn: float
    lam: float
    regel: str


class ReservenAnsicht(BaseModel):
    model_config = ConfigDict(frozen=True)

    durchtritt: float | None
    periode_min: float | None
    phasenreserve_grad: float | None
    amplitudenreserve: float | None
    gut: bool


class KennliniePunkt(BaseModel):
    model_config = ConfigDict(frozen=True)

    w: float
    db: float
    grad: float


class KreisAnsicht(BaseModel):
    """Ein Kreis der Kaskade mit seinem Entwurf."""

    model_config = ConfigDict(frozen=True)

    id: str
    name: str
    regelgroesse: str
    stellgroesse: str
    regler_block: str
    messglied: str | None
    takt_s: float
    art: Literal["stetig", "zweipunkt", "hybrid", "planung"]
    erklaerung: list[str]
    strecke: StreckeAnsicht | None = None
    regler: ReglerAnsicht | None = None
    reserven: ReservenAnsicht | None = None
    kennlinie: list[KennliniePunkt] = Field(default_factory=list)
    #: Nur beim Zweipunktregler: die abgeleitete Schaltdifferenz.
    hysterese_k: float | None = None
    #: Ein Satz, wenn mit dieser Einstellung etwas nicht stimmt.
    hinweis: str | None = None


class BlockAnsicht(BaseModel):
    model_config = ConfigDict(frozen=True)

    id: str
    ebene: Ebene
    rolle: Rolle
    rolle_text: str
    name: str
    kurz: str
    kreis: str | None = None
    erklaerung: list[str] = Field(default_factory=list)
    gleichungen: list[str] = Field(default_factory=list)
    behandlung: Behandlung | None = None
    behandlung_text: str | None = None
    quelle: str | None = None
    marke: str | None = None
    gibt_marke: str | None = None
    parameter: list[str] = Field(default_factory=list)
    #: Kennung des Übertragungsglieds; der Katalog steht einmal in der Antwort.
    glied: str | None = None
    #: Das Glied des Entwurfs, wo es von der Ausführung abweicht.
    glied_entwurf: str | None = None


class KanteAnsicht(BaseModel):
    model_config = ConfigDict(frozen=True)

    von: str
    nach: str
    signal: str
    art: Kantenart
    vorzeichen: Literal["+", "-"] | None = None


class GliedAnsicht(BaseModel):
    """Ein Übertragungsglied mit seinem Bild: Kurzzeichen, Name, Funktion, Sprungantwort.

    Der Katalog steht einmal in der Antwort und nicht an jedem Block. Die Kurven sind auf das
    Einheitsquadrat normiert - Form, keine Messung.
    """

    model_config = ConfigDict(frozen=True)

    id: str
    kurz: str
    name: str
    g_s: str
    art: Literal["sprung", "kennlinie", "takt"]
    kategorie: Literal["strecke", "regler", "messglied", "nichtlinear", "planung", "beobachter"]
    nichtlinear: bool
    erkennen: str
    kurve: list[tuple[float, float]]
    kurve2: list[tuple[float, float]] = Field(default_factory=list)


class GueteAnsicht(BaseModel):
    """Der Restfehler eines Teilmodells gegen die Messung."""

    model_config = ConfigDict(frozen=True)

    modell: str
    block: str
    einheit: str
    rmse: float | None
    n: int
    #: Woraus der Fehler kommt, in einem Satz.
    quelle: str


class Kostenpunkt(BaseModel):
    """Grenzkosten der Wärme an diesem Arbeitspunkt - die Zahl, nach der zugeordnet wird."""

    model_config = ConfigDict(frozen=True)

    cop: float
    waermepumpe_ct_kwh: float
    ofen_ct_kwh: float
    #: Die Arbeitszahl, ab der die Wärmepumpe billiger ist als der Ofen.
    cop_umschalt: float
    #: Die Außentemperatur des Umschaltpunkts, wenn sie im sinnvollen Bereich liegt.
    umschalt_aussen_c: float | None


class Regelkreiskarte(BaseModel):
    """Die ganze Karte in einer Antwort."""

    model_config = ConfigDict(frozen=True)

    stand: datetime
    #: Beginn der Aufzeichnung und Betriebstage - der Bezug für jeden Lernverlauf.
    seit: datetime | None = None
    tage: float | None = None
    arbeitspunkt: Arbeitspunkt
    kosten: Kostenpunkt
    bloecke: list[BlockAnsicht]
    #: Der Katalog der vorkommenden Übertragungsglieder, einmal je Antwort.
    glieder: list[GliedAnsicht]
    kanten: list[KanteAnsicht]
    kreise: list[KreisAnsicht]
    parameter: list[ParameterAnsicht]
    guete: list[GueteAnsicht]
    uebersteuert: list[str] = Field(default_factory=list)
    #: Wie viele Übernahmen es insgesamt gab. Die Zahl, die „es lernt" belegt.
    uebernahmen: int = 0


#: Verfahren, die unmittelbar aus Messwerten ablesen. Alles andere geht durch ein Modell.
MESSEND = frozenset({"ausgleich", "ereignis"})


def _herkunft(pid: str, stand: Schaetzstand) -> Herkunft:
    """Woher der geltende Wert kommt. Die Reihenfolge ist die der Verbindlichkeit."""
    if pid in stand.uebersteuert:
        return "uebersteuert"
    p = PARAMETER[pid]
    if p.schaetzart == "keiner":
        return "entwurf" if pid in LAMBDA_JE_KREIS.values() else "fest"
    eintrag = stand.parameter.get(pid)
    if eintrag is None or not eintrag.protokoll:
        return "annahme"
    # Gemessen heisst: unmittelbar aus Messwerten abgelesen - die Ausgleichsebene aus Wärme und
    # Strom, die Anlaufverzögerung aus dem Abstand zweier Zeitpunkte. Geschätzt heisst: durch ein
    # Modell hindurch, das selbst Annahmen enthält. Der Verlustbeiwert des Speichers gehört in die
    # zweite Gruppe, weil er gegen eine angenommene Aufstellraumtemperatur rechnet.
    return "gemessen" if p.schaetzart in MESSEND else "geschaetzt"


def werte(cfg: HemsConfig, stand: Schaetzstand) -> dict[str, float]:
    """Die geltenden Werte aller Parameter: Übersteuerung, sonst gelernt, sonst Startwert."""
    start = startwerte(cfg)
    return {pid: stand.wert(pid, start[pid]) for pid in PARAMETER}


def cop(w: Mapping[str, float], aussen_c: float, vorlauf_c: float) -> float:
    """Die Arbeitszahl aus dem geltenden Kennfeld, nach unten begrenzt.

    Unter eins kann keine Wärmepumpe arbeiten; eine Ebene, die es behauptet, ist außerhalb ihres
    Gültigkeitsbereichs ausgewertet worden. Begrenzt wird, damit keine Division das Vorzeichen
    wechselt - nicht, damit die Zahl schöner aussieht.
    """
    return max(1.05, w["cop_a"] + w["cop_b"] * aussen_c + w["cop_c"] * vorlauf_c)


def vorlauf_sollwert(cfg: HemsConfig, w: Mapping[str, float], aussen_c: float) -> float:
    """Die Vorlauftemperatur, die die Heizkennlinie bei dieser Außentemperatur verlangt.

    Sie steht hier, weil der Arbeitspunkt der Karte eine Vorlauftemperatur braucht und das Haus
    sie nicht an jeder Stelle messend vorliegen hat. Gerechnet ist sie dieselbe Zahl, die die
    Vorsteuerung dem Mischer vorgibt - also der Punkt, auf den die Anlage gerade zielt, und damit
    der richtige Punkt für eine Auslegung.

    Begrenzt auf das, was der Kreis hergibt: unter 26 °C trägt eine Fußbodenheizung nichts bei,
    über die Höchsttemperatur des Puffers geht nichts hinein.
    """
    soll = cfg.heat_demand.indoor_target_c
    hub = max(0.0, soll - aussen_c)
    roh = soll + w["kl_steil"] * math.pow(hub, 1.1)
    return min(cfg.buffer.max_temperature_c, max(26.0, roh))


def ofen_kosten_eur_kwh(cfg: HemsConfig, w: Mapping[str, float]) -> float:
    """Grenzkosten der Ofenwärme: Preis je Kilogramm durch Heizwert und Wirkungsgrad."""
    je_kg = cfg.stove.pellet_price_eur_per_t / 1000.0
    return je_kg / max(0.1, cfg.stove.pellet_kwh_per_kg * w["ofen_eta"])


def kostenpunkt(cfg: HemsConfig, w: Mapping[str, float], ap: Arbeitspunkt) -> Kostenpunkt:
    """Die Zuordnungsentscheidung als Zahlen: zwei Grenzkosten und der Punkt, an dem sie sich
    schneiden.

    Der Umschaltpunkt in Grad Celsius ist die Zahl, die ein Mensch behalten kann: unterhalb
    dieser Außentemperatur ist der Ofen die billigere Kilowattstunde. Sie wandert mit jeder
    Korrektur des Kennfelds und mit jedem Strompreis - deshalb steht sie in der Karte und nicht
    in einer Dokumentation.
    """
    c_ofen = ofen_kosten_eur_kwh(cfg, w)
    arbeitszahl = cop(w, ap.aussen_c, ap.vorlauf_c)
    cop_umschalt = ap.strompreis_eur_kwh / c_ofen if c_ofen > 0 else 0.0
    aussen: float | None = None
    if abs(w["cop_b"]) > 1e-6:
        aussen = (cop_umschalt - w["cop_a"] - w["cop_c"] * ap.vorlauf_c) / w["cop_b"]
        # Ausserhalb der Temperaturen, die dieses Haus erlebt, ist der Schnittpunkt eine
        # Rechengroesse ohne Aussage: die COP-Ebene gilt dort nicht mehr, und ein Umschaltpunkt
        # bei minus zwanzig Grad liest sich wie eine Auskunft, ist aber keine.
        if not UMSCHALT_VON_C <= aussen <= UMSCHALT_BIS_C:
            aussen = None
    return Kostenpunkt(
        cop=arbeitszahl,
        waermepumpe_ct_kwh=ap.strompreis_eur_kwh / arbeitszahl * 100.0,
        ofen_ct_kwh=c_ofen * 100.0,
        cop_umschalt=cop_umschalt,
        umschalt_aussen_c=aussen,
    )


def strecke(
    kreis_id: str, cfg: HemsConfig, w: Mapping[str, float], ap: Arbeitspunkt
) -> entwurf.Strecke:
    """Das Streckenmodell eines Kreises aus den geltenden Parametern."""
    if kreis_id == "R2":
        return entwurf.puffer_strecke(
            waerme_kw=w["wp_p_el"] * cop(w, ap.aussen_c, ap.vorlauf_c),
            kapazitaet_kwh_k=w["puffer_c"],
            totzeit_min=w["wp_totzeit"],
        )
    if kreis_id == "R1":
        return entwurf.vorlauf_strecke(
            verstaerkung_k_prozent=w["vl_k"], t1_min=w["vl_t1"], totzeit_min=w["vl_totzeit"]
        )
    if kreis_id == "R0":
        return entwurf.raum_strecke(
            c_estrich_kwh_k=w["raum_c_estrich"],
            r_estrich_luft_k_kw=w["raum_r"],
            c_luft_kwh_k=w["raum_c_luft"],
            h_raum_kw_k=w["raum_h"],
            q_max_kw=w["raum_q_max"],
            autoritaet=w["ventil_autoritaet"],
            totzeit_min=w["raum_totzeit"] + w["ventil_stellzeit"] / 60.0 / 2.0,
        )
    raise ValueError(f"Kreis {kreis_id} hat kein stetiges Streckenmodell")


def hysterese_k(cfg: HemsConfig, w: Mapping[str, float], ap: Arbeitspunkt) -> float:
    """Die Schaltdifferenz am Kontakt, aus Taktzahlgrenze und gelernten Steigungen.

    Die Entladesteigung ist der geschätzte Abfluss: Transmission bei diesem Arbeitspunkt plus
    Warmwasser über den Tag verteilt. Steigt der Verbrauch, wird die Hysterese breiter - sonst
    stiege die Taktzahl.
    """
    s = strecke("R2", cfg, w, ap)
    bedarf_kw = max(
        0.0, w["h_haus"] * max(0.0, cfg.heat_demand.indoor_target_c - ap.aussen_c) - w["q_intern"]
    )
    ab = (bedarf_kw + w["ww_tag"] / 24.0) / max(0.01, w["puffer_c"]) / 60.0
    return entwurf.hysterese(
        auf_k_min=s.k - ab, ab_k_min=ab, starts_je_tag=cfg.heat_pump.max_starts_per_day
    )


def _kreis_ansicht(
    kreis: Kreis, cfg: HemsConfig, w: Mapping[str, float], ap: Arbeitspunkt
) -> KreisAnsicht:
    gemein = {
        "id": kreis.id,
        "name": kreis.name,
        "regelgroesse": kreis.regelgroesse,
        "stellgroesse": kreis.stellgroesse,
        "regler_block": kreis.regler,
        "messglied": kreis.messglied,
        "takt_s": kreis.takt_s,
        "art": kreis.art,
        "erklaerung": list(kreis.erklaerung),
    }
    if kreis.art in ("hybrid", "planung"):
        return KreisAnsicht(**gemein)
    s = strecke(kreis.id, cfg, w, ap)
    fuer_entwurf = s.halbregel()
    lam = w[LAMBDA_JE_KREIS[kreis.id]]
    r = entwurf.simc(fuer_entwurf, lam)
    res = entwurf.reserven(r, fuer_entwurf)
    mitte = 1.0 / (lam + fuer_entwurf.totzeit)
    punkte = entwurf.kennlinie(r, fuer_entwurf, mitte / 400.0, mitte * 40.0)
    hinweis: str | None = None
    if res.phasenreserve is not None and res.phasenreserve < 45.0:
        hinweis = (
            f"Phasenreserve {res.phasenreserve:.0f}° liegt unter 45°. Mit dieser Einstellung "
            f"reagiert der Kreis auf eine Änderung der Strecke - einen kälteren Tag, einen "
            f"anderen Volumenstrom - mit Überschwingen bis zur Dauerschwingung. λ vergrößern."
        )
    elif res.durchtritt is None:
        hinweis = (
            "Der Betrag erreicht die Eins nicht; der Kreis ist so langsam, dass er nichts tut."
        )
    return KreisAnsicht(
        **gemein,
        strecke=StreckeAnsicht(
            art=s.art,
            k=s.k,
            t1=s.t1,
            t2=s.t2,
            totzeit=s.totzeit,
            t1_entwurf=fuer_entwurf.t1,
            totzeit_entwurf=fuer_entwurf.totzeit,
            halbregel=s.t2 > 0.0,
        ),
        regler=ReglerAnsicht(kp=r.kp, tn=r.tn, lam=r.lam, regel=r.regel),
        reserven=ReservenAnsicht(
            durchtritt=res.durchtritt,
            periode_min=res.periode,
            phasenreserve_grad=res.phasenreserve,
            amplitudenreserve=res.amplitudenreserve,
            gut=res.gut,
        ),
        kennlinie=[KennliniePunkt(w=p.w, db=p.db, grad=p.grad) for p in punkte],
        hysterese_k=hysterese_k(cfg, w, ap) if kreis.art == "zweipunkt" else None,
        hinweis=hinweis,
    )


#: Die Teilmodelle, deren Restfehler die Lernebene ausweist, und woraus er kommt.
GUETE: tuple[tuple[str, str, str, str, str], ...] = (
    ("COP-Kennfeld", "cop", "—", "cop_a", "Abweichung der Messpunkte von der Ausgleichsebene"),
    ("Wärmebedarf", "bedarf", "kW", "h_haus", "Bilanz gegen Gradstunden"),
    ("Pufferbilanz", "puffer", "kW", "puffer_ua", "Restglied der Wärmebilanz"),
    ("Raummodell", "raum", "K", "raum_c_estrich", "Raumtemperatur gegen Modellvorhersage"),
    ("Ofenleistung", "ofen", "kW", "ofen_eta", "Pelletverbrauch gegen Wärmebilanz"),
    ("PV-Prognose", "pv", "kWh/d", "pv_bias", "Prognose gegen gemessene Tagesenergie"),
)


def aufbauen(
    cfg: HemsConfig,
    stand: Schaetzstand,
    *,
    jetzt: datetime,
    arbeitspunkt: Arbeitspunkt | None = None,
) -> Regelkreiskarte:
    """Die ganze Karte für diesen Arbeitspunkt.

    Ohne Arbeitspunkt wird der Auslegungspunkt genommen; die Antwort sagt mit `gemessen`, was der
    Fall war. Reine Funktion: dieselben Eingaben geben dieselbe Karte.
    """
    ap = arbeitspunkt or Arbeitspunkt.aus_konfiguration(cfg)
    w = werte(cfg, stand)
    gebraucht = {b.glied for b in BLOECKE if b.glied} | {
        b.glied_entwurf for b in BLOECKE if b.glied_entwurf
    }
    start = startwerte(cfg)
    params: list[ParameterAnsicht] = []
    for pid, p in PARAMETER.items():
        eintrag = stand.parameter.get(pid)
        params.append(
            ParameterAnsicht(
                id=pid,
                block=p.block,
                symbol=p.symbol,
                name=p.name,
                einheit=p.einheit,
                stellen=p.stellen,
                wert=w[pid],
                herkunft=_herkunft(pid, stand),
                schaetzart=p.schaetzart,
                schaetzart_text=SCHAETZART_TEXT[p.schaetzart],
                startwert=start[pid],
                schaetzung=eintrag.schaetzung if eintrag else None,
                sigma=eintrag.sigma if eintrag else None,
                n=eintrag.n if eintrag else 0,
                stand=eintrag.stand if eintrag else None,
                rmse=eintrag.rmse if eintrag else None,
                unten=p.unten,
                oben=p.oben,
                warum=p.warum,
                quelle=p.quelle,
                wirkt_auf=list(p.wirkt_auf),
                protokoll=list(eintrag.protokoll) if eintrag else [],
                verlauf=list(eintrag.verlauf) if eintrag else [],
                pruefung=eintrag.letzte_pruefung if eintrag else None,
            )
        )
    guete = []
    for name, block, einheit, leitparameter, quelle in GUETE:
        eintrag = stand.parameter.get(leitparameter)
        guete.append(
            GueteAnsicht(
                modell=name,
                block=block,
                einheit=einheit,
                rmse=eintrag.rmse if eintrag else None,
                n=eintrag.n if eintrag else 0,
                quelle=quelle,
            )
        )
    return Regelkreiskarte(
        stand=jetzt,
        seit=stand.seit,
        tage=stand.tage(jetzt),
        arbeitspunkt=ap,
        kosten=kostenpunkt(cfg, w, ap),
        bloecke=[
            BlockAnsicht(
                id=b.id,
                ebene=b.ebene,
                rolle=b.rolle,
                rolle_text=ROLLE_TEXT[b.rolle],
                name=b.name,
                kurz=b.kurz,
                kreis=b.kreis,
                erklaerung=list(b.erklaerung),
                gleichungen=list(b.gleichungen),
                behandlung=b.behandlung,
                behandlung_text=BEHANDLUNG_TEXT[b.behandlung] if b.behandlung else None,
                quelle=b.quelle,
                marke=b.marke,
                gibt_marke=b.gibt_marke,
                parameter=list(b.parameter),
                glied=b.glied,
                glied_entwurf=b.glied_entwurf,
            )
            for b in BLOECKE
        ],
        glieder=[
            GliedAnsicht(
                id=g.id,
                kurz=g.kurz,
                name=g.name,
                g_s=g.g_s,
                art=g.art,
                kategorie=g.kategorie,
                nichtlinear=g.nichtlinear,
                erkennen=g.erkennen,
                kurve=[(round(x, 4), round(y, 4)) for x, y in g.kurve],
                kurve2=[(round(x, 4), round(y, 4)) for x, y in g.kurve2],
            )
            for g in GLIEDER.values()
            if g.id in gebraucht
        ],
        kanten=[
            KanteAnsicht(
                von=k.von, nach=k.nach, signal=k.signal, art=k.art, vorzeichen=k.vorzeichen
            )
            for k in KANTEN
        ],
        kreise=[_kreis_ansicht(k, cfg, w, ap) for k in KREISE],
        parameter=params,
        guete=guete,
        uebersteuert=sorted(stand.uebersteuert),
        uebernahmen=sum(len(s.protokoll) for s in stand.parameter.values()),
    )


def kreis_von_block(block_id: str) -> str | None:
    """Zu welchem Kreis ein Block gehört, wenn er dessen Regler ist."""
    for k in KREISE:
        if k.regler == block_id:
            return k.id
    return None


__all__ = [
    "KREIS_NACH_ID",
    "Arbeitspunkt",
    "BlockAnsicht",
    "GliedAnsicht",
    "GueteAnsicht",
    "KanteAnsicht",
    "KennliniePunkt",
    "Kostenpunkt",
    "KreisAnsicht",
    "ParameterAnsicht",
    "Regelkreiskarte",
    "ReglerAnsicht",
    "ReservenAnsicht",
    "StreckeAnsicht",
    "aufbauen",
    "cop",
    "hysterese_k",
    "kostenpunkt",
    "kreis_von_block",
    "ofen_kosten_eur_kwh",
    "strecke",
    "vorlauf_sollwert",
    "werte",
]
