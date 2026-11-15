// Alfreds vorbereitete Texte und das Wissen, das an das Sprachmodell geht.
//
// **Warum die Wegbeschreibung aus `AREAS` entsteht und nicht von Hand.** Im Schwesterprojekt waren
// zwei von vierzehn aus dem Kopf geschriebenen Hilfetexten falsch - links und rechts vertauscht,
// eine Auswahl, die es nicht gab. Beides klang plausibel. Ein Modell täte dasselbe, nur
// überzeugender und öfter. Welcher Reiter in welchem Bereich steht, liest Alfred deshalb aus
// derselben Liste, aus der die Leiste gebaut wird; ein umbenannter Reiter ist dann auch in seiner
// Auskunft umbenannt.
//
// Die Seitentexte sagen, was eine Seite zeigt, und nennen keine Knöpfe darin. Was auf einer Seite
// genau steht, ändert sich öfter als ihre Aufgabe.

import { AREAS, areaOf, tabOf, type Area, type Tab } from "@/lib/areas";

/** Was eine Seite zeigt, je Adresse eines Bereichs oder Reiters. */
export const SEITEN: Record<string, string> = {
  "/":
    "Jetzt ist die Wandanzeige: der Energiefluss im Augenblick (Photovoltaik, Netz, Speicher, Haus, Wärmepumpe, Wallbox), der Pufferspeicher, der Strompreis und der Ausblick auf die nächsten 24 Stunden.",
  "/haus":
    "Haus zeigt die Räume, als Liste zum Stellen der Solltemperatur oder als Modell mit Temperaturen und Kontakten.",
  "/strom":
    "Strom zeigt die Strombilanz des gewählten Zeitraums: Erzeugung, Netzbezug, Einspeisung, Speicher und Verbrauch.",
  "/waerme": "Wärme zeigt, was die Wärmepumpe an Strom gebraucht und gekostet hat, und die Wärmebilanz der Erzeuger.",
  "/strom/pv": "Photovoltaik zeigt Erzeugung, Eigenverbrauch und Einspeisung der Anlage im gewählten Zeitraum.",
  "/strom/speicher": "Speicher zeigt Laden, Entladen und Ladestand des Hausspeichers und was er gebracht hat.",
  "/strom/wallbox": "Wallbox zeigt Ladeenergie, Herkunft des Stroms, Kosten und Ladevorgänge.",
  "/strom/jahr": "Die Jahreskarte zeigt ein Kalenderjahr als Fläche aus Tagen und Stunden.",
  "/geld": "Kosten zeigt, was Strom im gewählten Zeitraum gekostet hat.",
  "/geld/pv-abrechnung":
    "PV-Abrechnung zeigt Einspeisung, Eigenverbrauch und Umsatzsteuer der Anlage. Nur mit Vollzugriff.",
  "/geld/rechnungen":
    "Rechnungen prüft Tibber-Rechnungen: Das PDF wird hochgeladen, nachgerechnet und gegen den eigenen Zähler gehalten. Nur mit Vollzugriff.",
  "/waerme/anlage":
    "Anlage zeigt das Anlagenschema im Augenblick; die Ansicht Ein Tag spielt einen ganzen Tag als Folge von Bildern ab.",
  "/waerme/wiedergabe": "Ein Tag spielt das Anlagenschema über einen ganzen Tag ab.",
  "/waerme/waermepumpe": "Wärmepumpe zeigt die Wärmepumpe allein, mit allem, was ihr eigener Bus meldet.",
  "/waerme/fahrplan":
    "Fahrplan zeigt den Plan voraus: Preisfenster, PV-Überschuss und wann die Wärmepumpe laufen soll. Die Ansicht Rückblick ist die Nachbetrachtung.",
  "/waerme/nachbetrachtung":
    "Rückblick zeigt einen vergangenen Tag in Euro: was der Fahrplan versprochen hat, was gehalten wurde und woran es lag.",
  "/waerme/wirkung": "Wirkung zeigt, ob die Wärmepumpe der Anforderung folgt und was das Verschieben gebracht hat.",
  "/waerme/raeume": "Heizkreise zeigt die Raumtemperaturen und Heizkreise über den gewählten Zeitraum.",
  "/system": "Prognose zeigt, wie gut PV- und Verbrauchsprognosen waren. Nur mit Vollzugriff.",
  "/system/daten": "Daten prüfen zeigt, wie vollständig die Messreihen sind. Nur mit Vollzugriff.",
  "/waerme/annahmen": "Annahmen zeigt die Wärmeannahmen des Modells und lässt sie ändern. Nur mit Vollzugriff.",
  "/system/mitteilungen": "Mitteilungen stellt das Morning Briefing und die angemeldeten Geräte ein. Nur mit Vollzugriff.",
  "/system/haustuer": "Haustür zeigt die Zutritte an der Haustür. Nur mit Vollzugriff.",
  "/system/zugang": "Zugang und Sicherung verwaltet gekoppelte Geräte und die Sicherung. Nur mit Vollzugriff.",
};

/** Die Wegbeschreibung: Bereiche, ihre Reiter und deren Ansichten, aus `AREAS`. */
export function wegweiser(areas: Area[] = AREAS): string {
  return areas
    .map((a) => {
      const reiter = a.tabs.map((t: Tab) => {
        const ansichten = t.unter?.length ? ` (Ansichten: ${t.unter.map((u) => u.label).join(", ")})` : "";
        return `${t.label}${ansichten}${t.ownerOnly ? " [nur Vollzugriff]" : ""}`;
      });
      return reiter.length ? `Bereich ${a.label}: Reiter ${reiter.join(", ")}.` : `Bereich ${a.label}: ohne Reiter.`;
    })
    .join("\n");
}

export type Ort = { bereich: string; reiter: string | null; text: string | null };

/** Wo man steht: Bereich und Reiter aus dem Pfad, dazu der Seitentext. */
export function ortBestimmen(pfad: string): Ort {
  const area = areaOf(pfad);
  const tab = tabOf(area, pfad);
  const sauber = pfad.replace(/\/+$/, "") || "/";
  const text = SEITEN[sauber] ?? (tab ? SEITEN[tab.href] : undefined) ?? SEITEN[area.href] ?? null;
  return { bereich: area.label, reiter: tab?.label ?? null, text };
}

/** Das Wissen für das Modell: wo gefragt wurde, was die Seite zeigt, und die Wegbeschreibung. */
export function wissen(pfad: string): string {
  const ort = ortBestimmen(pfad);
  const wo = ort.reiter ? `Bereich ${ort.bereich}, Reiter ${ort.reiter}` : `Bereich ${ort.bereich}`;
  return [
    `Der Anwender steht gerade hier: ${wo}.`,
    ort.text ?? "",
    "Die Reiter eines Bereichs teilen sich den gewählten Zeitraum.",
    "AUFBAU DER ANWENDUNG:",
    wegweiser(),
  ]
    .filter(Boolean)
    .join("\n");
}

export const TEXTE = {
  name: "Alfred",
  ansprechen: "Alfred fragen",
  schliessen: "Schließen",
  begruessung: "Hallo, ich bin Alfred. Ich erkläre, was du hier siehst, und beantworte Fragen zu deinem Haus.",
  seiteErklaeren: "Was zeigt diese Seite?",
  wasKannAlfred: "Was kannst du?",
  keineSeitenhilfe: "Zu dieser Seite habe ich noch keinen Hilfetext.",
  antwortWasKannAlfredOhneModell:
    "Im Moment kann ich die Seiten erklären und sagen, wo was steht. Sobald ein Sprachmodell eingerichtet ist, beantworte ich auch Fragen zu deinen Daten.",
  antwortWasKannAlfred:
    "Ich beantworte Fragen zu deinen Daten: Verbrauch, Kosten, PV, Wärmepumpe, Speicher, Rechnungen, Prognosen. Ich vergleiche Zeiträume und mache einen Wochenrückblick. Lichter und Raumtemperaturen schlage ich vor, geschaltet wird aber erst, wenn du den Knopf drückst. Außerdem lese ich Stromrechnungen anderer Anbieter und schlage bei der Einrichtung die Zuordnung der Sensoren vor. Ich rechne nichts selbst, die Zahlen kommen aus denselben Auswertungen wie auf den Seiten.",
  beispiele: ["Wie war die Woche?", "Warum war der letzte Monat teurer?", "Folgt die Wärmepumpe der Anforderung?"],
  frageFeld: "Frage an Alfred …",
  frageSenden: "Fragen",
  frageLaeuft: "Ich denke nach …",
  frageFehler: "Das hat nicht geklappt. Versuch es bitte gleich noch einmal.",
  frageTagesgrenze: "Für heute sind genug Fragen gestellt. Morgen geht es weiter.",
  frageOhneModell: "Für Fragen ist noch kein Sprachmodell eingerichtet.",
  kiMarke: "KI-Antwort",
  hinweisOhneModell: "Noch kein KI-Assistent: vorbereitete Texte, nichts verlässt das Haus.",
  hinweisModell:
    "KI-Assistent ({anbieter}). Er kann irren. Für Fragen gehen Zahlen deines Hauses an {anbieter}, keine Alarm-, Tür- oder Standortdaten. Er schaltet nichts ohne deine Bestätigung.",
  mikrofon: "Frage sprechen",
  mikrofonLaeuft: "Ich höre zu …",
  mikrofonHinweis: "Die Spracheingabe übernimmt der Browser; bei Safari wertet Apple die Aufnahme aus.",
  vorschlagTitel: "Vorschläge, noch nicht ausgeführt",
  vorschlagAusfuehren: "Ausführen",
  vorschlagLaeuft: "Läuft …",
  vorschlagFehler: "Das ließ sich nicht ausführen.",
  rechnungKnopf: "Rechnung eines anderen Anbieters prüfen",
  rechnungLaeuft: "Ich lese die Rechnung …",
  rechnungHinweis:
    "An {anbieter} gehen nur Zeilen mit Mengen, Preisen und Zeiträumen, Namen, Anschrift, Kunden- und Zählernummern und IBAN sind geschwärzt. Gespeichert wird nichts.",
  zuordnungKnopf: "Einrichtung: Sensoren zuordnen",
  zuordnungFeld: "Entitätenliste aus Home Assistant einfügen (Entwicklerwerkzeuge → Zustände)",
  zuordnungSenden: "Zuordnung vorschlagen",
  zuordnungLaeuft: "Ich ordne zu …",
  zuordnungKopieren: "YAML kopieren",
  zuordnungKopiert: "Kopiert",
  schritte: {
    jetzt: "Ich schaue auf den Augenblick …",
    energiebilanz: "Ich hole die Strombilanz …",
    waerme: "Ich schaue auf die Wärmepumpe …",
    waermebilanz: "Ich hole die Wärmebilanz …",
    verschiebung: "Ich prüfe, was das Verschieben gebracht hat …",
    wallbox: "Ich schaue auf die Wallbox …",
    pv_abrechnung: "Ich hole die PV-Abrechnung …",
    nachbetrachtung: "Ich lese die Nachbetrachtung …",
    fahrplan: "Ich lese den Fahrplan …",
    waermepumpe: "Ich frage die Wärmepumpe …",
    kontaktwirkung: "Ich prüfe, ob die Wärmepumpe folgt …",
    raeume: "Ich schaue in die Räume …",
    entscheidungen: "Ich lese die Entscheidungen des Reglers …",
    prognoseguete: "Ich prüfe die Prognosen …",
    tagesdiagnose: "Ich schlüssele den Tag auf …",
    rechnungen: "Ich hole die Rechnungen …",
    rechnung: "Ich lese die Rechnung …",
    wochenrueckblick: "Ich stelle die Woche zusammen …",
    leitfaden: "Ich lege mir den Weg zurecht …",
    nachschlagen: "Ich schlage in den Methodenpapieren nach …",
    schalten_vorschlagen: "Ich bereite einen Vorschlag vor …",
    sollwert_vorschlagen: "Ich bereite einen Vorschlag vor …",
  } as Record<string, string>,
  schrittAllgemein: "Ich arbeite daran …",
};

export type Texte = typeof TEXTE;
