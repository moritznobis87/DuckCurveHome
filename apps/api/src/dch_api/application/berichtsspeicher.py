"""Was eine Auswertung einmal gerechnet hat, liegt bereit: ein Ergebnis je (Endpunkt, Zeitraum, Anker).

**Der Anlass, gemessen.** Dreimal dieselbe Abfrage hintereinander auf `/energy/waermebilanz`
(Monat, derselbe Anker) brauchte 2,01 s, 2,10 s und 2,20 s - drei Mal dieselbe Rechnung, drei Mal
derselbe Durchlauf durch dieselben 44 640 Minutenzeilen. Es gab keinen Zwischenspeicher.

**Und sie kommt nicht einzeln.** Eine Berichtsseite holt bei jedem Ankerwechsel fünf Abfragen auf
einmal: ihren eigenen Bericht für die gewählte Spanne und daneben die vier Spalten des
Spannenstreifens, Tag, Woche, Monat, Jahr. Die gewählte Spanne ist also **zweimal dieselbe Frage**,
gleichzeitig gestellt - in der Vorlage (`apps/web/src/hooks/useReport.ts`: `useReport` neben
`useMultiPeriod`) wie in der App (`Spannenstand.swift`). Dass sie absichtlich doppelt gestellt wird,
steht dort begründet; hier steht die Gegenleistung: der Dienst rechnet sie einmal.

**Was es bringt, am Vorführstand gemessen** (40 Stunden Minutenbestand, drei gleiche Abfragen
hintereinander): die Tageswärmebilanz 0,215 s / 0,141 s / 0,102 s vorher gegen 0,178 s / 0,000 s /
0,000 s nachher, der Monat 0,427 s / 0,330 s / 0,263 s gegen 0,275 s / 0,000 s / 0,000 s. Ein
abgeschlossener Tag, drei Stunden später noch einmal gefragt: 0,000 s und derselbe Stand. Der
laufende Tag nach 30 Sekunden derselbe Stand, nach 90 Sekunden ein neuer - die Frist wirkt. Beim
Füllen über alle sechs Endpunkte und vier Spannen fielen 24 Treffer auf 48 Rechnungen, ohne dass
eine Seite doppelt gefragt hätte: `/energy/heat` und `/energy/ev` holen ihre Bilanz über
`summary`, und die liegt dann schon da.

## Zwei Fristen, und warum es zwei sind

**Ein abgeschlossener Zeitraum ändert sich nicht mehr.** Der gestrige Tag, der letzte Monat, das
Vorjahr: ihre Minuten sind geschrieben, ihre Stunden gerechnet. Das Ergebnis darf liegenbleiben,
bis der Platz gebraucht wird - es wird nie falsch, weil es nie wieder anders ausfällt.

**Der laufende Zeitraum bekommt 60 Sekunden** (``FRIST``), und die Zahl ist aus dem Haus
begründet, nicht geraten:

* **Der Takt der Daten ist die Minute.** Rohwerte kommen etwa alle zehn Sekunden (Shelly über
  MQTT), der amtliche Zähler alle dreißig; eine Minutenzeile ist nach einer Minute fertig, und
  feiner als minütlich sagt der Bestand nichts Neues. Eine Frist von einer Minute hält also nie
  eine Minute zurück, die es schon gibt.
* **Die Seiten fragen alle fünf Minuten nach** (`useReport.ts`: `REFRESH_MS = 5 * 60_000`, in der
  App ``Berichtstakt.nachladen``). Die Frist ist kürzer als dieser Takt, und das ist der
  entscheidende Punkt: **jedes** Nachladen rechnet neu, der Speicher fängt nur die fünf Abfragen
  eines Ankerwechsels ab. Eine Frist von fünf Minuten wäre genau falsch - dann bekäme ein
  Nachladen die Antwort des vorigen, und auf einer Wandanzeige stünden Zahlen, die bis zu zehn
  Minuten alt sind, ohne dass jemand nachgefragt hätte.

**Der Nachlauf nach dem Ende** (``NACHLAUF``, 15 Minuten) ist die dritte Zahl, und ohne sie wären
die ersten beiden nichts wert. Ein Zeitraum ist nicht in dem Augenblick abgeschlossen, in dem seine
letzte Minute vergangen ist: die Verdichtung der Rohwerte läuft alle fünf Minuten
(`live_runtime._rollup_loop`), die Stundenbilanz ebenfalls (`_accounting_loop`), und
`/energy/summary` liest ausschließlich gespeicherte Stunden. Wer den gestrigen Tag um 00:01 fragt
und die Antwort für dauerhaft erklärt, friert eine Bilanz ein, in der die letzte Stunde noch fehlt
- für immer. Fünfzehn Minuten sind drei Umläufe: einer schreibt, einer bestätigt, einer ist
Reserve für einen Umlauf, der lange braucht oder einmal scheitert.

Entscheidend ist dabei der Zeitpunkt der **Rechnung**, nicht der der Abfrage: ein Ergebnis, das
entstand, während der Zeitraum noch lief, wird nie nachträglich zum dauerhaften (``_legen``).

## Was dieser Speicher nicht darf

**Keine alten Zahlen nach einem Neustart.** Er ist ein Wörterbuch im Prozess und sonst nichts -
keine Datei, keine Tabelle, kein Redis. Ein Neustart beginnt leer, und das ist die einzige
Eigenschaft, die ein Zwischenspeicher für Messdaten geschenkt bekommen sollte: nach einem Absturz
ist der Bestand vielleicht nachgetragen worden, und dann wäre jede überlebende Zahl eine falsche.

**Kein unbegrenztes Wachsen.** Höchstens ``GROESSE`` Einträge, und der am längsten nicht gelesene
fällt heraus. Ohne diese Grenze wäre das Versprechen „abgeschlossene Zeiträume bleiben liegen“ ein
Leck mit Ansage: wer sich durch ein Jahr blättert, legt je Tag bis zu sechs Ergebnisse ab, und das
schwerste davon ist eine Tageswärmebilanz mit 288 Verlaufspunkten - gemessen 430 KB als Objekte.

**Keine fremden Zahlen.** Der Schlüssel hat drei Teile und keinen vierten für eine Person - weil es
hier keine Personen gibt. Der Dienst kennt genau ein Token (`DCH_API_TOKEN`), und wer es hat, darf
alles (`docs/decisions/ADR-0002-identitaet-und-berechtigung.md`). Die beiden Rollen `owner` und
`guest` leben im BFF der Vorlage und wirken **auf Pfaden**, nicht auf Inhalten
(`apps/web/src/app/api/dch/[...path]/route.ts`: `GUEST_FORBIDDEN`): ein Gast kommt an
`/energy/pv` gar nicht heran, und an allem anderen sieht er dieselben Zahlen wie der Hausherr.
Zwei Antworten für denselben Pfad gibt es nicht, also kann der Speicher auch keine verwechseln.
**Kommt das Benutzersystem aus ADR-0002, ändert sich das**, und dann gehört die Kennung dessen, der
fragt, in den Schlüssel - vor der ersten Antwort, die je Benutzer verschieden ausfällt.
"""

from __future__ import annotations

import asyncio
from collections import OrderedDict
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Any, Protocol, TypeVar, cast

#: Wie lange das Ergebnis eines **laufenden** Zeitraums gilt. Begründung oben im Modulkopf.
FRIST = timedelta(seconds=60)

#: Wie lange nach dem Ende eines Zeitraums noch mit Nachträgen gerechnet wird, bevor sein Ergebnis
#: als dauerhaft gilt. Drei Umläufe der Verdichtung; Begründung oben im Modulkopf.
NACHLAUF = timedelta(minutes=15)

#: Höchstzahl der Einträge, und sie ist gemessen, nicht geraten.
#:
#: Ein Anker belegt 24 Plätze: sechs Endpunkte mal vier Spannen. 48 fasst also den gewählten Anker
#: und den davor - genau das, was Blättern erzeugt. Nachgemessen am Vorführstand, einmal rundherum
#: gefüllt: 48 Einträge halten 3,3 MB im Arbeitsspeicher. Der mit Abstand schwerste Eintrag ist die
#: Tageswärmebilanz mit ihren 288 Verlaufspunkten - 64 KB als JSON, 430 KB als Objekte -, und von
#: der Art gibt es je Anker genau eine. Eine Schranke von 480 wäre noch kein Unglück, 4800 wären
#: eines: `measurements_minute` wird nie gelöscht, und wer sich durch drei Jahre blättert, kommt
#: dort vorbei.
GROESSE = 48


class MitStand(Protocol):
    """Alles, was hier abgelegt wird, sagt selbst, wann es gerechnet wurde.

    Das ist keine Formalie des Typprüfers: die Frist wird an diesem Feld gemessen, und dasselbe
    Feld steht in der Antwort. Was der Speicher für sein Alter hält, ist damit genau das, was der
    Fragende zu sehen bekommt - zwei Begriffe von „wie alt ist diese Zahl“ wären einer zu viel.
    """

    generated_at: datetime


Wert = TypeVar("Wert", bound=MitStand)

#: (Endpunkt, Zeitraum, Anker). Der Endpunkt ist der Pfad ohne Präfix, wie ihn die Seite kennt.
Schluessel = tuple[str, str, date]


@dataclass(slots=True)
class _Eintrag:
    wert: Any
    #: Ob der Zeitraum schon abgeschlossen **war**, als dieser Wert entstand. Siehe Modulkopf.
    abgeschlossen: bool


class Berichtsspeicher:
    """Ergebnisse je (Endpunkt, Zeitraum, Anker), mit zwei Fristen und einer Schranke."""

    def __init__(
        self,
        *,
        frist: timedelta = FRIST,
        nachlauf: timedelta = NACHLAUF,
        groesse: int = GROESSE,
    ) -> None:
        self.frist = frist
        self.nachlauf = nachlauf
        self.groesse = groesse
        self._eintraege: OrderedDict[Schluessel, _Eintrag] = OrderedDict()
        self._laufend: dict[Schluessel, asyncio.Task[Any]] = {}
        #: Zählt jedes `leeren`. Eine Rechnung, die über ein Leeren hinweg lief, wird nicht abgelegt.
        self._stand = 0
        # Nur für Prüfungen und die Diagnose: wie oft geantwortet wurde, ohne zu rechnen.
        self.treffer = 0
        self.rechnungen = 0

    async def hole(
        self,
        endpunkt: str,
        period: str,
        anchor: date,
        *,
        now: datetime,
        ende: datetime,
        rechnen: Callable[[], Awaitable[Wert]],
        dauerhaft: bool = True,
    ) -> Wert:
        """Das Ergebnis aus dem Speicher - oder gerechnet, und dann abgelegt.

        `ende` ist das Ende des Zeitraums; daran entscheidet sich mit `now`, ob er abgeschlossen
        ist. `dauerhaft=False` heißt: dieser Endpunkt bekommt **nur** die kurze Frist, nie die
        dauerhafte Ablage - für Antworten, in denen neben dem Zeitraum noch etwas Lebendiges steht
        (`/energy/heat` trägt die 48-Stunden-Prognose mit sich, und die auf einem vergangenen Monat
        einzufrieren hieße, wochenlang das Wetter von damals vorherzusagen).

        **Eine gleichzeitige zweite Abfrage rechnet nicht mit.** Sie hängt sich an die laufende
        (`_laufend`) und bekommt deren Ergebnis. Ohne das liefe die doppelte Abfrage der gewählten
        Spanne zweimal durch denselben Monat: der Speicher wäre erst beim *dritten* Mal nützlich,
        und beim Ankerwechsel kommt es nie zu einem dritten.

        `asyncio.shield` schützt die Rechnung davor, mit dem ersten Fragenden zu verschwinden: legt
        der sein Fenster zu, läuft sie für den zweiten weiter. Bricht der Faden selbst ab, bekommen
        alle Wartenden denselben Fehler - und abgelegt wird nichts.
        """
        schluessel: Schluessel = (endpunkt, period, anchor)
        gemerkt = self._treffer(schluessel, now)
        if gemerkt is not None:
            self.treffer += 1
            return cast("Wert", gemerkt)
        laufend = self._laufend.get(schluessel)
        if laufend is None:
            self.rechnungen += 1
            laufend = asyncio.ensure_future(rechnen())
            self._laufend[schluessel] = laufend

            def _fertig(aufgabe: asyncio.Task[Any]) -> None:
                # Nur die eigene Rechnung austragen. Zwischen dem Ende einer Rechnung und diesem
                # Rückruf kann für denselben Schlüssel schon die nächste eingetragen sein; die
                # pauschal zu entfernen hieße, sie ein zweites Mal rechnen zu lassen.
                if self._laufend.get(schluessel) is aufgabe:
                    del self._laufend[schluessel]
                # Den Fehler abholen, auch wenn ihn niemand mehr erwartet: legt der einzige
                # Fragende sein Fenster zu, während seine Rechnung scheitert, stünde sonst ein
                # „Task exception was never retrieved“ im Protokoll - eine Meldung über uns und
                # nicht über das Haus.
                if not aufgabe.cancelled():
                    aufgabe.exception()

            laufend.add_done_callback(_fertig)
        stand = self._stand
        wert: Wert = await asyncio.shield(laufend)
        self._legen(schluessel, wert, ende=ende, dauerhaft=dauerhaft, stand=stand)
        return wert

    def leeren(self) -> None:
        """Alles verwerfen - nach einer Änderung an den Annahmen oder am Bestand.

        Zwei Dinge machen ein abgelegtes Ergebnis nachträglich falsch, und beide gehen hier durch:
        eine geänderte Konfiguration (`EnergyAccounting.hems`) und nachgetragene Messwerte
        (`EnergyAccounting.recompute`, der Historienimport). Verworfen wird alles und nicht der
        betroffene Zeitraum: ein Backfill darf zwei Monate umfassen, ein Pelletpreis wirkt auf
        jeden Zeitraum überhaupt, und ein zu kleines Besteck wäre hier gefährlicher als ein
        verlorener Zwischenspeicher.

        **Laufende Rechnungen werden nicht abgebrochen, ihr Ergebnis aber nicht abgelegt.** Es ist
        die Antwort, die der Fragende bestellt hat - sie ihm vorzuenthalten hälfe niemandem. Nur
        gerechnet wurde sie mit dem Bestand oder den Annahmen von vorher, und damit gehört sie in
        keinen Speicher. Dafür steht `_stand`: `hole` merkt sich den Zählerstand vor der Rechnung,
        `_legen` vergleicht ihn danach. Ohne diesen Zähler überlebte genau die Antwort das Leeren,
        die der Anlass dafür war.

        **Und ``_laufend`` wird mitgeräumt, sonst hätte der Zähler ein Loch.** Wer erst nach dem
        Leeren fragt, darf sich nicht an eine Rechnung hängen, die noch unter den alten Annahmen
        läuft: er merkte sich den neuen Zählerstand, bekäme den alten Wert und legte ihn ab. Der
        Preis ist eine Rechnung, die einmal doppelt läuft - unmittelbar nach einem Backfill oder
        einer Preisänderung, und dort ist sie zu verschmerzen.
        """
        self._eintraege.clear()
        self._laufend.clear()
        self._stand += 1

    # ------------------------------------------------------------------ innen
    def _treffer(self, schluessel: Schluessel, now: datetime) -> Any | None:
        eintrag = self._eintraege.get(schluessel)
        if eintrag is None:
            return None
        if not eintrag.abgeschlossen and now - eintrag.wert.generated_at >= self.frist:
            del self._eintraege[schluessel]
            return None
        # Gelesen heißt gebraucht: der Eintrag wandert an das junge Ende der Schranke.
        self._eintraege.move_to_end(schluessel)
        return eintrag.wert

    def _legen(
        self, schluessel: Schluessel, wert: Wert, *, ende: datetime, dauerhaft: bool, stand: int
    ) -> None:
        if stand != self._stand:
            return  # zwischendurch geleert: siehe `leeren`
        abgeschlossen = dauerhaft and wert.generated_at >= ende + self.nachlauf
        self._eintraege[schluessel] = _Eintrag(wert=wert, abgeschlossen=abgeschlossen)
        self._eintraege.move_to_end(schluessel)
        while len(self._eintraege) > self.groesse:
            self._eintraege.popitem(last=False)
