"""
Leitfaeden fuer Auswertungsfragen (docs/ALFRED.md).

Ein Leitfaden schreibt fuer eine wiederkehrende Frage fest, welche Werkzeuge sie braucht und was die
Antwort enthalten muss. Er verhindert die plausibel klingende Antwort, der die tragende Zahl fehlt:
Auf "warum war der Oktober teurer?" kann ein Sprachmodell zwei Saetze antworten, die gut klingen und
weder den Bezug noch den Preis nennen.

Abgerufen wird er als Werkzeug und nicht als feste Ablaufsteuerung im Dienst: Es gibt mehr Fragen
als Leitfaeden, und die meisten Fragen sind keine Auswertungsfragen. Das Modell waehlt, der
Leitfaden fuehrt. Er rechnet nicht und urteilt nicht.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Leitfaden:
    name: str
    #: Die beantwortete Frage; danach waehlt das Modell.
    frage: str
    #: Die Werkzeuge in Bearbeitungsreihenfolge. Jedes muss es geben (tests/test_alfred.py).
    werkzeuge: tuple[str, ...]
    #: Die Pflichtbestandteile der Antwort - der eigentliche Zweck.
    bestandteile: tuple[str, ...]
    #: Die typische Fehlleistung bei dieser Frage.
    vorsicht: str


LEITFAEDEN: tuple[Leitfaden, ...] = (
    Leitfaden(
        name="warum_teurer",
        frage="Warum war ein Zeitraum teurer (oder billiger) als ein anderer?",
        werkzeuge=("energiebilanz", "energiebilanz", "waerme", "verschiebung"),
        bestandteile=(
            "Die Kosten beider Zeitraeume mit Zahl.",
            "Der Netzbezug beider Zeitraeume in kWh und der mittlere Bezugspreis in ct/kWh - "
            "teurer kann an der Menge oder am Preis liegen, und die Antwort sagt, woran.",
            "Welcher Verbraucher (Waermepumpe, Wallbox, uebriges Haus) sich am staerksten "
            "veraendert hat.",
            "Die PV-Erzeugung beider Zeitraeume, weil weniger Sonne mehr Bezug bedeutet.",
        ),
        vorsicht=(
            "Zwei Zeitraeume brauchen zwei Aufrufe von energiebilanz mit verschiedenem Stichtag. "
            "Vergleiche keine Woche mit einem Monat. Ein kaelterer Monat erklaert mehr "
            "Waermepumpenstrom, aber nur, wenn die Zahlen es zeigen."
        ),
    ),
    Leitfaden(
        name="lohnt_verschieben",
        frage="Hat sich das Verschieben der Waermepumpe in guenstige Stunden gelohnt?",
        werkzeuge=("verschiebung", "kontaktwirkung"),
        bestandteile=(
            "Die Ersparnis in Euro und der Zeitraum, auf den sie sich bezieht.",
            "Dass es ein Vergleichslauf ist und keine Messung, mit den Annahmen aus dem Ergebnis.",
            "Ob die Waermepumpe der Anforderung ueberhaupt gefolgt ist - ohne Folgen keine Wirkung.",
        ),
        vorsicht=(
            "Sag nicht 'hat sich gelohnt' oder 'hat sich nicht gelohnt'. Nenne die Zahl und "
            "woran sie haengt. Eine kleine Ersparnis in einem sonnigen Monat ist kein Befund "
            "gegen das Verfahren."
        ),
    ),
    Leitfaden(
        name="folgt_waermepumpe",
        frage="Folgt die Waermepumpe der Anforderung? Laeuft sie, wenn sie soll?",
        werkzeuge=("kontaktwirkung", "waermepumpe", "entscheidungen"),
        bestandteile=(
            "Der Anteil der Anforderungen, denen sie gefolgt ist, und der Rueckblick in Tagen.",
            "Die typische Verzoegerung, falls das Ergebnis sie nennt.",
            "Der aktuelle Zustand der Waermepumpe und die letzte Entscheidung des Reglers.",
        ),
        vorsicht=(
            "Die Anforderung ist kein Befehl: Die Maschine darf ablehnen, etwa "
            "wenn der Speicher voll ist. Ein Nichtfolgen ist deshalb erst ein Befund, wenn das "
            "Ergebnis keinen Grund nennt."
        ),
    ),
    Leitfaden(
        name="stimmt_die_rechnung",
        frage="Stimmt die Stromrechnung? Passt sie zu dem, was gemessen wurde?",
        werkzeuge=("rechnungen", "rechnung"),
        bestandteile=(
            "Das Urteil der Pruefung und die Zahl der Befunde.",
            "kWh laut Rechnung gegen kWh gemessen, mit der Abdeckung der Messung.",
            "Den mittleren Preis laut Rechnung gegen den aus den eigenen Tibber-Preisen.",
            "Jeden Befund mit Titel und Wert, nicht nur 'es gibt Befunde'.",
        ),
        vorsicht=(
            "Bei geringer Abdeckung der Messung (unter 90 Prozent) ist ein Unterschied in den "
            "kWh kein Fehler der Rechnung. Sag das dazu."
        ),
    ),
    Leitfaden(
        name="wochenrueckblick",
        frage="Wie war die Woche? Ein Rueckblick auf die letzten sieben Tage.",
        werkzeuge=("wochenrueckblick",),
        bestandteile=(
            "Verbrauch, PV-Erzeugung und Autarkie der Woche.",
            "Die Kosten und der mittlere Bezugspreis.",
            "Was das Verschieben der Waermepumpe gebracht hat, mit dem Hinweis, dass es eine "
            "Rechnung ist.",
            "Eine Auffaelligkeit, falls die Zahlen eine zeigen - etwa eine Waermepumpe, die der "
            "Anforderung selten gefolgt ist.",
        ),
        vorsicht=(
            "Hoechstens sechs Saetze. Keine Bewertung wie 'gute Woche'; die Zahlen sprechen "
            "fuer sich."
        ),
    ),
    Leitfaden(
        name="prognose_daneben",
        frage="Warum lag die PV- oder Verbrauchsprognose daneben?",
        werkzeuge=("prognoseguete", "nachbetrachtung"),
        bestandteile=(
            "Prognose gegen Ist fuer den betroffenen Tag, mit Zahl.",
            "Was die Abweichung laut Nachbetrachtung gekostet hat und welchem Anteil sie "
            "zugeordnet ist (Prognose, Nachfuehren, Maschine).",
            "Die aktuellen Korrekturfaktoren, falls das Ergebnis sie nennt.",
        ),
        vorsicht=(
            "Das Wetter von morgen kennt niemand. Eine einzelne schlechte Prognose ist kein "
            "Befund gegen das Verfahren; ein Muster ueber viele Tage ist einer."
        ),
    ),
)


def leitfaden(name: str) -> Leitfaden | None:
    gesucht = (name or "").strip().lower()
    return next((ll for ll in LEITFAEDEN if ll.name == gesucht), None)
