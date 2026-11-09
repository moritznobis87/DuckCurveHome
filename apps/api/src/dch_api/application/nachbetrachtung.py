"""Die Nachbetrachtung eines Tages: vom Bestand zu den Linien.

Die Bewertung selbst steht in `hems_core.accounting.nachbetrachtung` und kennt weder Zeilen noch
Archiv noch Löser. Hier entsteht, was sie braucht:

* aus den **Minutenzeilen** die Viertelstunden des Tages, so wie sie eintraten;
* aus dem **Fahrplanarchiv** der erste Fahrplan des Tages und der jeweils letzte Stand;
* aus einem **Vergleichslauf** der Fahrplan, den der Optimierer gewählt hätte, wäre ihm der Tag
  im Voraus bekannt gewesen.

**Der Vergleichslauf ruft denselben Planer wie der Betrieb**, `plan_stove`, nur mit den
eingetretenen Werten statt der Prognosen. Ein eigener, vereinfachter Löser für den Rückblick wäre
in einer Woche ein anderes Modell, und der Abstand zwischen Fahrplan und perfekter Voraussicht
mäße dann den Unterschied der Modelle statt den Wert der Prognose.

Alles hier ist synchron und rechnet; der Löser braucht bis zu seiner Zeitgrenze. Der Aufrufer
holt die Daten und ruft `zusammenstellen` in einem Thread.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import date, datetime, timedelta, tzinfo

from dch_api.application import anlage_replay
from dch_api.application.anlage import BUFFER_KEYS
from dch_api.application.stove_planner import BASE_LOAD_KW, STEP_MIN, plan_stove, stove_eur_per_h
from dch_api.schemas import NachbetrachtungOut
from hems_core.accounting.heat import cop_at, heat_demand_kw
from hems_core.accounting.nachbetrachtung import Fahrplan, Viertel, nachbetrachten
from hems_core.domain import HemsConfig
from hems_core.planning import OptimizerConfig
from hems_core.planning.price_windows import PricePoint
from hems_core.thermal import compute_buffer_state

Zeile = dict[str, float | str | None]
#: Abgelegte Punkte einer Größe: Erstellungszeit des Laufs, Zielzeit, Wert.
Punkte = Sequence[tuple[datetime, datetime, float]]

#: Was aus der Minutenreihe gebraucht wird.
REIHEN: tuple[str, ...] = (
    "pv_power_kw",
    "house_power_kw",
    "base_load_kw",
    "heat_pump_power_kw",
    "ev_power_kw",
    "electricity_price_ct_kwh",
    "outdoor_temp_c",
    "stove_running",
    *BUFFER_KEYS,
)
#: Was aus dem Fahrplanarchiv gebraucht wird.
GROESSEN: tuple[str, ...] = ("hp_release", "stove_on", "cost_eur")
#: So weit vor der Ortsmitternacht wird nach Fahrplänen gesucht. Der Planer sieht 36 Stunden weit;
#: ein Lauf vom Vorabend beschreibt den ganzen Tag, einer von vorgestern nicht mehr.
VORLAUF_H = 30
#: So weit über den Tag hinaus werden Minuten geholt: der Vergleichslauf soll wie der Betrieb über
#: die Mitternacht hinaussehen, sonst führe er den Puffer zum Tagesende leer.
NACHLAUF_H = 12
#: So viele der fünfzehn Minuten müssen gemessen sein, damit eine Viertelstunde zählt.
MIN_MINUTEN = 12
SCHRITT = timedelta(minutes=STEP_MIN)


def fenster(day: date, tz: tzinfo, jetzt: datetime) -> tuple[datetime, datetime, datetime]:
    """Der Ortstag, und bis wohin Minuten geholt werden: `(von, bis, daten_bis)`."""
    von, bis = anlage_replay.fenster(day, tz)
    return von, bis, min(bis + timedelta(hours=NACHLAUF_H), jetzt)


def _zahl(zeile: Zeile, key: str) -> float | None:
    wert = zeile.get(key)
    return float(wert) if isinstance(wert, int | float) else None


def _mittel(werte: Sequence[float]) -> float | None:
    return sum(werte) / len(werte) if werte else None


@dataclass(frozen=True)
class Eingetreten:
    """Eine Viertelstunde aus den Minutenzeilen, mit dem, was der Vergleichslauf zusätzlich braucht."""

    ts: datetime
    preis_ct: float | None
    ueberschuss_kw: float | None
    wp_kwh: float | None
    standby_kwh: float | None
    laufmin: float | None
    ofen_anteil: float | None
    aussen_c: float | None
    #: Die erste Minutenzeile der Viertelstunde: aus ihr kommt der Pufferzustand zu Beginn.
    erste: Zeile | None


def _ueberschuss(zeile: Zeile) -> float | None:
    """Der PV-Überschuss vor der Wärmepumpe in einer Minute, nie negativ.

    Sonne minus Haus ohne Wärmepumpe. Die Wallbox zählt zum Haus: was das Auto lädt, steht der
    Wärmepumpe nicht zur Verfügung. Ohne Sonne ist der Überschuss null, auch wenn die Grundlast
    fehlt; mit Sonne und ohne Grundlast ist er unbekannt.
    """
    pv = _zahl(zeile, "pv_power_kw")
    if pv is None:
        return None
    if pv <= 0:
        return 0.0
    grund = _zahl(zeile, "base_load_kw")
    auto = _zahl(zeile, "ev_power_kw") or 0.0
    if grund is None:
        haus, wp = _zahl(zeile, "house_power_kw"), _zahl(zeile, "heat_pump_power_kw")
        if haus is None or wp is None:
            return None
        grund = max(0.0, haus - wp - auto)
    return max(0.0, pv - grund - auto)


def viertelstunden(
    zeilen: Sequence[Zeile], von: datetime, bis: datetime, *, jetzt: datetime, laeuft_ab_kw: float
) -> list[Eingetreten]:
    """Die Minutenzeilen zu Viertelstunden von `von` bis `bis`, auch denen ohne Messung.

    Eine Viertelstunde zählt nur, wenn sie zu Ende ist und mindestens `MIN_MINUTEN` ihrer Minuten
    eine Leistung haben. Die fehlenden Minuten werden hochgerechnet: zwölf gemessene Minuten sind
    zwölf Fünfzehntel der Energie, nicht die ganze.

    **Verdichter und Grundlast getrennt.** Der Strom in Minuten an oder über der Schwelle ist der
    Verdichter und geht in die Bewertung. Der Strom darunter ist die Anlage im Stillstand; er
    steht daneben, weil kein Fahrplan ihn ändert.
    """
    eimer: dict[datetime, list[Zeile]] = {}
    for z in zeilen:
        roh = z.get("ts")
        if roh is None:
            continue
        ts = datetime.fromisoformat(str(roh)).astimezone(von.tzinfo)
        if not von <= ts < bis:
            continue
        k = int((ts - von) // SCHRITT)
        eimer.setdefault(von + k * SCHRITT, []).append(z)
    out: list[Eingetreten] = []
    t = von
    while t < bis:
        fach = sorted(eimer.get(t, []), key=lambda z: str(z["ts"]))
        fertig = t + SCHRITT <= jetzt
        leistung = [w for z in fach if (w := _zahl(z, "heat_pump_power_kw")) is not None]
        gemessen = fertig and len(leistung) >= MIN_MINUTEN
        faktor = STEP_MIN / len(leistung) if leistung else 0.0
        ofen = [w > 0.5 for z in fach if (w := _zahl(z, "stove_running")) is not None]
        ueber = [u for z in fach if (u := _ueberschuss(z)) is not None]
        out.append(
            Eingetreten(
                ts=t,
                preis_ct=_mittel(
                    [w for z in fach if (w := _zahl(z, "electricity_price_ct_kwh")) is not None]
                )
                if fertig
                else None,
                ueberschuss_kw=_mittel(ueber) if fertig and len(ueber) >= MIN_MINUTEN else None,
                wp_kwh=sum(w for w in leistung if w >= laeuft_ab_kw) / 60.0 * faktor
                if gemessen
                else None,
                standby_kwh=sum(max(0.0, w) for w in leistung if w < laeuft_ab_kw) / 60.0 * faktor
                if gemessen
                else None,
                laufmin=sum(1 for w in leistung if w >= laeuft_ab_kw) * faktor
                if gemessen
                else None,
                ofen_anteil=(sum(ofen) / len(ofen)) if fertig and ofen else None,
                aussen_c=_mittel(
                    [w for z in fach if (w := _zahl(z, "outdoor_temp_c")) is not None]
                ),
                erste=fach[0] if fach else None,
            )
        )
        t += SCHRITT
    return out


def _je_lauf(punkte: Punkte) -> dict[datetime, dict[datetime, float]]:
    """Die Punkte einer Größe nach Lauf: Erstellungszeit, darunter Zielzeit und Wert."""
    out: dict[datetime, dict[datetime, float]] = {}
    for erstellt, ziel, wert in punkte:
        out.setdefault(erstellt, {})[ziel] = wert
    return out


def erster_fahrplan(
    punkte: Mapping[str, Punkte], zeiten: Sequence[datetime], von: datetime
) -> Fahrplan | None:
    """Der Fahrplan, mit dem der Tag begann.

    Der letzte Lauf vor der Ortsmitternacht, wenn es einen gibt: mit ihm ging das Haus in den Tag.
    Sonst der erste Lauf des Tages - dann beginnt der Vergleich erst mit ihm, und die Antwort sagt
    das. Ein späterer Lauf wäre kein Ursprung mehr, sondern schon eine Korrektur.
    """
    frei = _je_lauf(punkte.get("hp_release", ()))
    if not frei:
        return None
    vorher = [e for e in frei if e <= von]
    erstellt = max(vorher) if vorher else min(frei)
    ofen = _je_lauf(punkte.get("stove_on", ())).get(erstellt, {})
    kosten = _je_lauf(punkte.get("cost_eur", ())).get(erstellt, {})
    lauf = frei[erstellt]
    return Fahrplan(
        wp=[None if t not in lauf else lauf[t] > 0.5 for t in zeiten],
        ofen=[None if t not in ofen else ofen[t] > 0.5 for t in zeiten],
        versprochen_eur=[kosten.get(t) for t in zeiten],
        erstellt=erstellt,
    )


def letzter_stand(punkte: Mapping[str, Punkte], zeiten: Sequence[datetime]) -> Fahrplan | None:
    """Für jede Viertelstunde der jüngste Fahrplan, der vor ihr entstand.

    Dieselbe Regel wie in der Wiedergabe: nie ein Lauf von danach. Gefragt ist die Absicht, mit
    der man in die Viertelstunde hineinging, nicht die Erkenntnis von später.
    """
    frei = punkte.get("hp_release", ())
    if not frei:
        return None

    def stand(groesse: str, t: datetime) -> float | None:
        bester: tuple[datetime, float] | None = None
        for erstellt, ziel, wert in punkte.get(groesse, ()):
            if ziel == t and erstellt <= t and (bester is None or erstellt > bester[0]):
                bester = (erstellt, wert)
        return None if bester is None else bester[1]

    wp = [stand("hp_release", t) for t in zeiten]
    ofen = [stand("stove_on", t) for t in zeiten]
    return Fahrplan(
        wp=[None if w is None else w > 0.5 for w in wp],
        ofen=[None if w is None else w > 0.5 for w in ofen],
    )


def _auffuellen(werte: Sequence[float | None]) -> tuple[list[float], int]:
    """Lücken mit dem letzten bekannten Wert füllen, am Anfang mit dem ersten. Zählt die Lücken."""
    erster = next((w for w in werte if w is not None), None)
    if erster is None:
        return [], len(werte)
    out: list[float] = []
    letzter = erster
    luecken = 0
    for w in werte:
        if w is None:
            luecken += 1
        else:
            letzter = w
        out.append(letzter)
    return out, luecken


def vergleichslauf(
    eingetreten: Sequence[Eingetreten],
    start: int,
    cfg: HemsConfig,
    tz: tzinfo,
    *,
    laeuft_ab_kw: float,
    opt_cfg: OptimizerConfig | None = None,
) -> tuple[list[bool | None], list[bool | None], str, list[str]]:
    """Der Fahrplan mit perfekter Voraussicht ab der Viertelstunde `start`.

    Rückgabe: Freigabe und Ofen je Viertelstunde von `eingetreten`, ein Grund, falls nicht
    gerechnet wurde, und Hinweise. Der Lauf beginnt mit dem **gemessenen** Pufferzustand jener
    Viertelstunde und sieht so weit, wie Preise gemessen sind - über die Mitternacht hinaus,
    soweit der Bestand reicht.

    Perfekt sind die Eingänge, nicht das Modell: der Wärmebedarf kommt weiter aus dem Bedarfsmodell,
    nur eben mit der eingetretenen Temperatur. Wie gut das Modell ist, sagt dieser Lauf nicht.
    """
    n = len(eingetreten)
    leer: list[bool | None] = [None] * n
    hinweise: list[str] = []
    anfang = eingetreten[start]
    if anfang.erste is None:
        return leer, leer, "Zu Beginn des Vergleichs fehlt die Minute mit dem Pufferzustand.", []
    # Bis zur letzten Viertelstunde mit Preis: weiter sieht auch die perfekte Voraussicht nicht.
    ende = max((i for i in range(start, n) if eingetreten[i].preis_ct is not None), default=start)
    spanne = eingetreten[start : ende + 1]
    preise, preisluecken = _auffuellen([e.preis_ct for e in spanne])
    if not preise:
        return leer, leer, "Für den Vergleichslauf fehlt die Preisreihe.", []
    temps, _ = _auffuellen([e.aussen_c for e in spanne])
    if not temps:
        return leer, leer, "Für den Vergleichslauf fehlt die Außentemperatur.", []
    if preisluecken:
        hinweise.append(
            f"Im Vergleichslauf sind {preisluecken} Viertelstunden ohne gemessenen Preis mit dem "
            "letzten bekannten gefüllt. Bewertet werden sie nicht."
        )
    ueber = {e.ts: e.ueberschuss_kw or 0.0 for e in spanne}

    def sonne(t: datetime) -> float:
        # Der Planer zieht von der Sonne selbst eine feste Grundlast ab. Hier steht der gemessene
        # Überschuss, also wird sie vorher aufgeschlagen: heraus kommt im Modell genau der
        # eingetretene Überschuss, mit der Grundlast, die das Haus wirklich hatte.
        k = int((t - anfang.ts) // SCHRITT)
        u = ueber.get(anfang.ts + k * SCHRITT, 0.0)
        return u + BASE_LOAD_KW if u > 0 else 0.0

    puffer = compute_buffer_state(
        anlage_replay.schnappschuss(anfang.erste, anfang.ts).buffer_temps_c, cfg.buffer
    )
    davor = eingetreten[start - 1] if start > 0 else None
    plan = plan_stove(
        now=anfang.ts,
        tz=tz,
        cfg=cfg,
        prices=[
            PricePoint(start=e.ts, end=e.ts + SCHRITT, ct_kwh=p)
            for e, p in zip(spanne, preise, strict=True)
        ],
        pv_expected=sonne,
        temps=[(e.ts, c) for e, c in zip(spanne, temps, strict=True)],
        buffer=puffer,
        # Lief die Maschine in der Viertelstunde davor mehr als die Hälfte der Zeit, läuft sie
        # für den Planer schon; dann gilt ihre Mindestlaufzeit, wie sie im Betrieb gegolten hat.
        hp_running=bool(davor and (davor.laufmin or 0.0) > STEP_MIN / 2),
        stove_running=bool(davor and (davor.ofen_anteil or 0.0) > 0.5),
        opt_cfg=opt_cfg,
    )
    if not plan.hp_available:
        return leer, leer, plan.note_de or "Der Vergleichslauf ergab keinen Fahrplan.", hinweise
    wp: list[bool | None] = [
        plan.hp_on_at(e.ts) if i >= start else None for i, e in enumerate(eingetreten)
    ]
    # Ohne Ofenfahrplan heißt „kein Lauf vorgesehen", nicht „unbekannt": die Wärmepumpe ist ja
    # geplant, und der Ofen kam in ihrem Fahrplan nicht vor.
    ofen: list[bool | None] = [
        None if w is None else bool(plan.on_at(e.ts)) for w, e in zip(wp, eingetreten, strict=True)
    ]
    # Dieselbe Beurteilung wie im Betrieb: nicht der Abbruch ist die Meldung, sondern der
    # Abstand zum Besten. Der Löser erreicht seine Zeitgrenze fast immer; ein Hinweis, der an
    # jedem Tag dasteht, liest nach einer Woche niemand mehr.
    if plan.warnung_de():
        hinweise.append(
            "Der Vergleichslauf wurde an seiner Zeitgrenze abgebrochen und kann spürbar vom "
            "besten Fahrplan entfernt sein; „noch zu holen“ ist dann eher zu klein. "
            + plan.warnung_de()
        )
    return wp, ofen, "", hinweise


def zusammenstellen(
    zeilen: Sequence[Zeile],
    punkte: Mapping[str, Punkte],
    cfg: HemsConfig,
    day: date,
    tz: tzinfo,
    *,
    jetzt: datetime,
    opt_cfg: OptimizerConfig | None = None,
) -> NachbetrachtungOut:
    """Die Nachbetrachtung eines Ortstages aus Minutenzeilen und abgelegten Fahrplänen."""
    von, bis, daten_bis = fenster(day, tz, jetzt)
    schwelle = cfg.heat_pump.running_threshold_kw
    # Der Tag und, für den Vergleichslauf, was danach schon gemessen ist.
    alles = viertelstunden(
        zeilen, von, max(bis, _aufrunden(daten_bis, von)), jetzt=jetzt, laeuft_ab_kw=schwelle
    )
    n_tag = int((bis - von) // SCHRITT)
    tag = alles[:n_tag]
    zeiten = [e.ts for e in tag]
    erster = erster_fahrplan(punkte, zeiten, von)
    letzter = letzter_stand(punkte, zeiten)

    # Die Außentemperatur für Bedarf und Arbeitszahl: wo sie fehlt, die nächste bekannte.
    temps, templuecken = _auffuellen([e.aussen_c for e in tag])
    viertel: list[Viertel] = []
    for i, e in enumerate(tag):
        aussen = temps[i] if temps else None
        cop = cop_at(aussen, cfg.heat_demand) if aussen is not None else None
        gewicht: float | None = None
        if aussen is not None and cop:
            heizen, warmwasser = heat_demand_kw(aussen, e.ts.astimezone(tz).hour, cfg.heat_demand)
            gewicht = (heizen + warmwasser) / cop
        viertel.append(
            Viertel(
                ts=e.ts,
                preis_ct=e.preis_ct,
                ueberschuss_kw=e.ueberschuss_kw,
                wp_kwh=e.wp_kwh,
                standby_kwh=e.standby_kwh,
                laufmin=e.laufmin,
                ofen_anteil=e.ofen_anteil if cfg.stove.present else None,
                ofen_eur_je_h=stove_eur_per_h(cfg, price_ct_kwh=e.preis_ct, cop=cop)
                if cfg.stove.present and e.preis_ct is not None and cop
                else 0.0,
                gewicht=gewicht,
            )
        )

    # Wo der Vergleich beginnt: die erste Viertelstunde, die gemessen ist und zu der die Fahrpläne
    # etwas sagen. Dieselbe Regel wie in der Bewertung, hier nur für den Startpunkt des Laufs.
    def zaehlt(i: int) -> bool:
        v = viertel[i]
        if v.preis_ct is None or v.ueberschuss_kw is None or v.wp_kwh is None:
            return False
        return all(p is None or (i < len(p.wp) and p.wp[i] is not None) for p in (erster, letzter))

    start = next((i for i in range(n_tag) if zaehlt(i)), None)
    perfekt: Fahrplan | None = None
    grund = "Es gibt keine verglichene Viertelstunde, von der aus zu rechnen wäre."
    extra: list[str] = []
    if start is not None:
        wp, ofen, grund, extra = vergleichslauf(
            alles, start, cfg, tz, laeuft_ab_kw=schwelle, opt_cfg=opt_cfg
        )
        if not grund:
            perfekt = Fahrplan(wp=wp[:n_tag], ofen=ofen[:n_tag])

    laeuft_noch = jetzt < bis
    ergebnis = nachbetrachten(
        viertel,
        erster=erster,
        letzter=letzter,
        perfekt=perfekt,
        perfekt_grund_de=grund,
        wp_kw=cfg.heat_pump.nominal_electric_power_kw,
        verguetung_ct=cfg.tariff.feed_in_ct_kwh,
        hat_ofen=cfg.stove.present,
        schritt_min=STEP_MIN,
        laeuft_noch=laeuft_noch,
    )
    hinweise = [*ergebnis.hinweise_de, *extra]
    if templuecken and temps:
        hinweise.append(
            f"Für {templuecken} Viertelstunden fehlt die Außentemperatur; dort gilt die zuletzt "
            "gemessene. Sie geht in die Nulllinie und in den Wert der Ofenwärme ein."
        )
    if cfg.stove.present:
        hinweise.append(
            "Der Ofen ist mit dem heute eingestellten Pelletpreis bewertet, auch für vergangene "
            "Tage. Wer den Preis ändert, ändert die Nachbetrachtung rückwirkend."
        )
    return NachbetrachtungOut(
        **ergebnis.model_dump(exclude={"hinweise_de"}),
        hinweise_de=hinweise,
        day=day,
        von=von,
        bis=bis,
        laeuft_noch=laeuft_noch,
        wp_kw=cfg.heat_pump.nominal_electric_power_kw,
        verguetung_ct=cfg.tariff.feed_in_ct_kwh,
        hat_ofen=cfg.stove.present,
    )


def _aufrunden(t: datetime, von: datetime) -> datetime:
    """Auf das nächste Viertelstundenraster ab `von` aufrunden."""
    k = -((von - t) // SCHRITT)
    return von + k * SCHRITT
