/**
 * Die Seitenstruktur: Bereich, Gruppe, Seite.
 *
 * **Warum nach Frage und nicht nach Geraet.** Dreizehn Seiten waren nacheinander entstanden, je
 * eine je Geraet, und jede mit eigener Zeitraumwahl. Wer die Woche in der Photovoltaik ansah und
 * dann zum Speicher ging, stand dort wieder auf heute. Jetzt teilen sich die Reiter eines Bereichs
 * den Zeitraum: er reist als `?period=&anchor=` von Reiter zu Reiter mit.
 *
 * Die alten Adressen leiten in `next.config.ts` auf die neuen um, Lesezeichen bleiben gueltig.
 *
 * **Dieselbe Struktur gilt in der App.** `docs/seitenbaum.json` beschreibt sie einmal;
 * `seitenbaum.test.ts` haelt diese Datei dagegen und `SeitenbaumTests.swift` die App. Wer hier
 * etwas aendert, aendert zuerst die gemeinsame Datei.
 */
import type { IconName } from "@/components/ui/Icon";

export type Tab = {
  href: string;
  label: string;
  /** Der Reiter kennt einen Zeitraum und bekommt ihn in der Adresse mit. */
  dated?: boolean;
  /** Nur mit Vollzugriff sichtbar; die Seite selbst prueft es serverseitig noch einmal. */
  ownerOnly?: boolean;
  /**
   * Die Ansichten eines Reiters, wenn er mehr als eine hat: dieselbe Sache aus zwei Richtungen,
   * etwa der Augenblick und ein ganzer Tag. Sie stehen als Umschalter unter der Reiterzeile und
   * nicht als eigene Reiter daneben. Die erste Ansicht hat die Adresse des Reiters.
   */
  unter?: Ansicht[];
  /** Die Gruppe des Bereichs, zu der der Reiter gehoert. Nur in Bereichen mit Gruppen. */
  gruppe?: string;
  /** Ein Satz fuer die Karte auf der Uebersicht des Bereichs: was die Seite beantwortet. */
  beschreibung?: string;
  /** Das Zeichen der Seite auf ihrer Kachel in der Uebersicht. */
  icon: IconName;
  /**
   * Die Farbe der Sache, von der die Seite handelt: dieselbe, die sie im Energiefluss und in
   * den Diagrammen traegt. `ruhig` heisst: die Seite handelt von keiner der gefaerbten Sachen.
   */
  farbe: Seitenfarbe;
};

/** Die Farben, die eine Seite tragen kann; die Werte stehen in `tokens.css`. */
export type Seitenfarbe = "pv" | "haus" | "waermepumpe" | "speicher" | "wallbox" | "ruhig";

/** Der Farbwert zu einer Seitenfarbe, als CSS-Variable. */
export const SEITENFARBE: Record<Seitenfarbe, string> = {
  pv: "var(--pv)",
  haus: "var(--text-1)",
  waermepumpe: "var(--heat-pump)",
  speicher: "var(--battery)",
  wallbox: "var(--ev)",
  ruhig: "var(--mist)",
};

export type Ansicht = { href: string; label: string };

/** Eine Gruppe innerhalb eines Bereichs, mit einem Halbsatz, der sagt, wovon sie handelt. */
export type Gruppe = { name: string; wort: string };

export type Area = {
  key: "jetzt" | "haus" | "energie" | "geld" | "anlage" | "system";
  href: string;
  icon: IconName;
  label: string;
  ownerOnly?: boolean;
  /**
   * Steht der Bereich in der Leiste? Das System steht nicht darin: es wird selten gebraucht und
   * liegt hinter dem Zahnrad im Kopf der Seite.
   */
  leiste?: boolean;
  /**
   * Die Gruppen des Bereichs. Ein Bereich mit Gruppen hat eine Uebersicht unter seiner eigenen
   * Adresse; seine Reiterzeile zeigt die Gruppen statt einer einzigen langen Reihe.
   */
  gruppen?: Gruppe[];
  tabs: Tab[];
};

/**
 * **Bereich, Gruppe, Seite** (seit dem 23.11.2026).
 *
 * Bis dahin lagen 18 der 29 Ansichten im Bereich Technik, in einer Zeile aus 13 Reitern, und
 * darin drei verschiedene Aufgaben: der Maschine zusehen, die Regelung verstehen, das System
 * verwalten. Geordnet war das nur durch die Reihenfolge.
 *
 * - **Jetzt**: was gerade ist und was als Naechstes kommt.
 * - **Haus**: die Raeume, zum Stellen und ueber den Tag.
 * - **Energie**: was verbraucht und erzeugt wurde, Strom und Waerme nebeneinander.
 * - **Geld**: was es gekostet hat.
 * - **Anlage**: die Heizungsanlage in drei Gruppen. Die Maschine, ihre Regelung und die Werte,
 *   mit denen gerechnet wird.
 * - **System**: die Verwaltung. Hinter dem Zahnrad und nicht in der Leiste.
 *
 * Die Adressen sind dieselben geblieben; neu ist nur `/anlage` fuer die Uebersicht. Ein Bereich
 * ist deshalb nicht das erste Stueck des Pfads: `/waerme` gehoert zur Energie, `/waerme/anlage`
 * zur Anlage, `/system` (die Prognose) zur Energie und `/system/geraet` zum System.
 */
export const AREAS: Area[] = [
  { key: "jetzt", href: "/", icon: "duck", label: "Jetzt", tabs: [] },
  // Die Raeume als Liste und als Modell, dazu ihr Verlauf ueber den Tag. Die Geometrie kommt
  // von der Bruecke (haus.yaml), die Werte aus Raeumen und Live-Zustand.
  {
    key: "haus",
    href: "/haus",
    icon: "house",
    label: "Haus",
    tabs: [
      { href: "/haus", label: "Räume", icon: "house", farbe: "ruhig" },
      { href: "/waerme/raeume", label: "Über den Tag", icon: "thermo", farbe: "ruhig", dated: true },
    ],
  },
  {
    key: "energie",
    // Der Bereich geht auf seiner Übersicht auf (Vorgabe des Hausherrn vom 24.11.2026). Die
    // Seiten behalten ihre Adressen; neu ist nur `/energie`.
    href: "/energie",
    icon: "bolt",
    label: "Energie",
    tabs: [
      { href: "/strom", label: "Strom", icon: "bolt", farbe: "haus", dated: true, beschreibung: "Woher der Strom kam und wer ihn verbraucht hat." },
      { href: "/waerme", label: "Wärme", icon: "flame", farbe: "waermepumpe", dated: true, beschreibung: "Was die Wärmepumpe gebraucht hat und woher die Wärme kam." },
      { href: "/strom/pv", label: "Photovoltaik", icon: "sun", farbe: "pv", dated: true, beschreibung: "Was die Anlage erzeugt hat und wohin der Sonnenstrom ging." },
      // Die Prognose der Photovoltaik gegen das, was wirklich kam. Sie steht neben ihr und nicht
      // als Ansicht darunter, weil sie keinen Zeitraum kennt und die Photovoltaik einen hat.
      { href: "/system", label: "Prognose", icon: "chart", farbe: "ruhig", ownerOnly: true, beschreibung: "Wie gut die Vorhersage des Sonnenertrags getroffen hat." },
      { href: "/strom/speicher", label: "Speicher", icon: "battery", farbe: "speicher", dated: true, beschreibung: "Wann der Speicher geladen und entladen hat." },
      { href: "/strom/wallbox", label: "Wallbox", icon: "car", farbe: "wallbox", dated: true, beschreibung: "Wann das Auto geladen hat und mit welchem Strom." },
      { href: "/strom/jahr", label: "Jahreskarte", icon: "calendar", farbe: "ruhig", beschreibung: "Jede Stunde eines Jahres als Bild." },
    ],
  },
  {
    key: "geld",
    href: "/geld",
    icon: "euro",
    label: "Geld",
    tabs: [
      { href: "/geld", label: "Kosten", icon: "euro", farbe: "ruhig", dated: true },
      { href: "/geld/pv-abrechnung", label: "PV-Abrechnung", icon: "sun", farbe: "pv", dated: true, ownerOnly: true },
      { href: "/geld/rechnungen", label: "Rechnungen", icon: "table", farbe: "ruhig", ownerOnly: true },
    ],
  },
  {
    key: "anlage",
    href: "/anlage",
    icon: "pump",
    label: "Anlage",
    gruppen: [
      { name: "Maschine", wort: "Was sie gerade tut" },
      { name: "Regelung", wort: "Warum sie es tut" },
      { name: "Abstimmung", wort: "Womit gerechnet wird" },
    ],
    tabs: [
      { href: "/waerme/anlage", label: "Anlage", icon: "thermo", farbe: "ruhig",
        gruppe: "Maschine",
        beschreibung: "Speicher, Vorlauf und Heizkreise im Schema, im Augenblick und über einen Tag.",
        // Die Wiedergabe ist die Anlage ueber einen Tag.
        unter: [
          { href: "/waerme/anlage", label: "Jetzt" },
          { href: "/waerme/wiedergabe", label: "Ein Tag" },
        ],
      },
      // Die Wärmepumpe allein, mit allem, was ihr eigener Bus meldet (seit dem 14.11.2026).
      { href: "/waerme/waermepumpe", label: "Wärmepumpe", icon: "pump", farbe: "waermepumpe",
        gruppe: "Maschine",
        beschreibung: "Der Zustand des Geräts, seine Läufe und die gemessene Arbeitszahl.",
        // Der Augenblick, der Betrieb über Tage und die gemessene Kennlinie: dieselbe Maschine,
        // einmal jetzt, einmal als Tagebuch, einmal als Kennlinie über Wochen.
        unter: [
          { href: "/waerme/waermepumpe", label: "Jetzt" },
          { href: "/waerme/waermepumpe/betrieb", label: "Betrieb" },
          { href: "/waerme/waermepumpe/kennlinie", label: "Kennlinie" },
        ],
      },
      { href: "/waerme/fahrplan", label: "Fahrplan", icon: "clock", farbe: "waermepumpe",
        gruppe: "Regelung",
        beschreibung: "Wann die Wärmepumpe laufen soll und was der Plan von gestern gehalten hat.",
        // Die Nachbetrachtung ist der Fahrplan im Rueckblick.
        unter: [
          { href: "/waerme/fahrplan", label: "Voraus" },
          { href: "/waerme/nachbetrachtung", label: "Rückblick" },
        ],
      },
      { href: "/waerme/wirkung", label: "Wirkung", icon: "target", farbe: "ruhig",
        gruppe: "Regelung",
        beschreibung: "Ob die Wärmepumpe der Anforderung folgt, gemessen an ihren Läufen.",
      },
      // Die Regelung selbst, als Blockschaltbild: fünf Kaskadenebenen, ihre Störgrößen und der
      // Lernstand jedes Parameters. Steht hinter der Wirkung, weil sie deren Zahlen verwendet.
      { href: "/waerme/regelkreis", label: "Regelkreis", icon: "loop", farbe: "ruhig",
        gruppe: "Regelung",
        ownerOnly: true,
        beschreibung: "Die Regelung mit ihren Ebenen, Stellgrößen und Parametern.",
      },
      { href: "/waerme/annahmen", label: "Annahmen", icon: "table", farbe: "ruhig",
        gruppe: "Abstimmung",
        ownerOnly: true,
        beschreibung: "Die Werte, mit denen das Modell des Hauses rechnet.",
      },
      // Was am Regler eingestellt ist, gelesen über den Bus. Bis zum 23.11.2026 eine Ansicht
      // der Wärmepumpe; als Stelle zum Einstellen gehört er zur Abstimmung.
      { href: "/waerme/waermepumpe/regler", label: "Regler", icon: "sliders", farbe: "waermepumpe",
        gruppe: "Abstimmung",
        beschreibung: "Die Einstellungen am Regler der Wärmepumpe, über den Bus gelesen.",
      },
    ],
  },
  {
    key: "system",
    // Das Zahnrad öffnet „Einstellen“ (Entscheidung des Hausherrn vom 24.11.2026): oben, was
    // gerade von Hand gestellt ist, dann die Einstellungen in drei Stufen, zuletzt die Seiten des
    // Systems. Der Bereich ist offen für jeden, der im Haus stellen darf; die Systemseiten selbst
    // bleiben dem Hausherrn. Die alte Adresse `/system/uebersicht` leitet hierher weiter.
    href: "/einstellen",
    icon: "gear",
    label: "Einstellen",
    leiste: false,
    tabs: [
      { href: "/system/mitteilungen", label: "Mitteilungen", icon: "bell", farbe: "ruhig", ownerOnly: true, beschreibung: "Welche Geräte Mitteilungen bekommen und was im Morgenbrief steht." },
      { href: "/system/haustuer", label: "Haustür", icon: "door", farbe: "ruhig", ownerOnly: true, beschreibung: "Wer sich wann an der Haustür erkannt hat." },
      // Der Rechner im Haus selbst: Dienste, Gesundheit, Neustarts, Protokolle, Updates.
      { href: "/system/geraet", label: "Hausgerät", icon: "dashboard", farbe: "ruhig", ownerOnly: true, beschreibung: "Wie es dem Rechner im Haus und seinen Diensten geht." },
      { href: "/system/zugang", label: "Zugang und Sicherung", icon: "shield", farbe: "ruhig", ownerOnly: true, beschreibung: "Wer Zugang hat, wie groß die Datenbank ist und wie man sie sichert." },
      { href: "/system/daten", label: "Daten prüfen", icon: "table", farbe: "ruhig", dated: true, ownerOnly: true, beschreibung: "Ob die Messreihen lückenlos angekommen sind und zueinander passen." },
    ],
  },
];

/** Die Bereiche der Leiste, in ihrer Reihenfolge. Das System gehoert nicht dazu. */
export const LEISTE: Area[] = AREAS.filter((a) => a.leiste !== false);

/**
 * Eine Seite außerhalb der sechs Bereiche.
 *
 * Der Hausherr hat am 24.11.2026 entschieden, dass der eigene Zugang eine eigene Seite bekommt,
 * die jede angemeldete Person erreicht. Vorher stand er auf „Zugang und Sicherung“ im Bereich
 * System, den nur der Hausherr sieht: ein Bewohner konnte weder sein Passwort wechseln noch
 * sich abmelden. Die Seite gehört zu keinem Bereich und steht deshalb nicht in `AREAS`; sie
 * steht in `docs/seitenbaum.json` unter `einzelseiten`.
 */
export interface Einzelseite {
  href: string;
  label: string;
  icon: string;
  beschreibung: string;
}

export const EINZELSEITEN: Einzelseite[] = [
  { href: "/konto", label: "Mein Zugang", icon: "person", beschreibung: "Passkeys, Passwort und Sitzungen des eigenen Zugangs." },
];

/** Eine Stufe der Seite „Einstellen“: von leicht nach schwer (`docs/seitenbaum.json`, `stufen`). */
export interface Stufe {
  schluessel: "eingreifen" | "vorgeben" | "abstimmen";
  name: string;
  wort: string;
  nurHausherr: boolean;
}

export const STUFEN: Stufe[] = [
  { schluessel: "eingreifen", name: "Eingreifen", wort: "jetzt und befristet", nurHausherr: false },
  { schluessel: "vorgeben", name: "Vorgeben", wort: "dauerhaft", nurHausherr: false },
  { schluessel: "abstimmen", name: "Abstimmen", wort: "womit die Regelung rechnet", nurHausherr: true },
];

/**
 * Eine Einstellung im Katalog der Seite „Einstellen“. Sie bleibt bei ihrem Gegenstand; hier
 * steht nur, wo man sie findet, damit die Suche sie auch unter einem anderen Wort findet.
 */
export interface Einstellung {
  name: string;
  stufe: Stufe["schluessel"];
  weg: string;
  stichworte: string[];
}

export const EINSTELLUNGEN: Einstellung[] = [
  { name: "Wärmepumpe anfordern oder sperren", stufe: "eingreifen", weg: "/", stichworte: ["Wärmepumpe", "Kontakt", "sperren", "anfordern"] },
  { name: "Ofen an oder aus", stufe: "eingreifen", weg: "/", stichworte: ["Ofen", "Pelletofen", "Pellets"] },
  { name: "Speicher anhalten oder freigeben", stufe: "eingreifen", weg: "/strom/speicher", stichworte: ["Speicher", "Batterie", "Libbi"] },
  { name: "Alarmanlage scharf schalten", stufe: "eingreifen", weg: "/", stichworte: ["Alarm", "Alarmanlage", "scharf"] },
  { name: "Solltemperatur eines Raums", stufe: "vorgeben", weg: "/haus", stichworte: ["Raum", "Temperatur", "Sollwert", "Heizung"] },
  { name: "Raum-Automatik", stufe: "vorgeben", weg: "/haus", stichworte: ["Automatik", "Räume", "Vorheizen"] },
  { name: "Untergrenze des Speichers", stufe: "vorgeben", weg: "/strom/speicher", stichworte: ["Speicher", "Reserve", "Untergrenze"] },
  { name: "Mitteilungen und Morgenbrief", stufe: "vorgeben", weg: "/system/mitteilungen", stichworte: ["Mitteilungen", "Push", "Morgenbrief"] },
  { name: "Annahmen der Wärmerechnung", stufe: "abstimmen", weg: "/waerme/annahmen", stichworte: ["Annahmen", "Wärmebedarf", "Haus", "Modell"] },
  { name: "Parameter des Regelkreises", stufe: "abstimmen", weg: "/waerme/regelkreis", stichworte: ["Regelkreis", "Parameter", "Übersteuern"] },
  { name: "Regler der Wärmepumpe", stufe: "abstimmen", weg: "/waerme/waermepumpe/regler", stichworte: ["Regler", "Heizkurve", "Vorlauf", "Wärmepumpe"] },
];

/** Ob eine Adresse nur dem Hausherrn gehört: ihr Reiter ist es, oder ihr ganzer Bereich. */
export function nurHausherr(weg: string): boolean {
  const area = areaOf(weg);
  const tab = tabOf(area, weg);
  return area.ownerOnly === true || tab?.ownerOnly === true;
}

/**
 * Die Einstellungen, die zu einer Suche passen: im Namen oder in einem Stichwort, ohne Rücksicht
 * auf Groß- und Kleinschreibung. Dieselbe Regel steht in der App (`Bereiche.suche`).
 */
export function sucheEinstellungen(text: string, hausherr: boolean): Einstellung[] {
  const s = text.trim().toLocaleLowerCase("de-DE");
  return EINSTELLUNGEN.filter((e) => hausherr || !nurHausherr(e.weg)).filter(
    (e) => s.length > 0 && [e.name, ...e.stichworte].some((w) => w.toLocaleLowerCase("de-DE").includes(s)),
  );
}

/** Die Einzelseite zu einem Pfad, wenn er auf einer steht. */
export function einzelseiteOf(pathname: string): Einzelseite | undefined {
  const clean = (pathname.split("?")[0] ?? "").replace(/\/+$/, "") || "/";
  return EINZELSEITEN.find((s) => clean === s.href || clean.startsWith(`${s.href}/`));
}

/**
 * Ob ein Bereich eine Übersicht hat. Er hat eine, wenn seine eigene Adresse keine seiner Seiten
 * ist: dann steht dort die Übersicht, und die Reiterzeile führt zu ihr zurück. Ein eigenes Feld
 * braucht es dafür nicht, und der Seitenbaum sagt es so für Dashboard und App zugleich.
 */
export function hatUebersicht(area: Area): boolean {
  return area.tabs.length > 0 && !area.tabs.some((t) => t.href === area.href);
}

/** Die Reiter einer Gruppe, in der Reihenfolge des Bereichs. */
export function tabsDerGruppe(area: Area, gruppe: string): Tab[] {
  return area.tabs.filter((t) => t.gruppe === gruppe);
}

/**
 * Der Bereich, zu dem ein Pfad gehoert: der mit der laengsten passenden Adresse unter seinen
 * Reitern und Ansichten. `/` ist Jetzt, und was niemandem gehoert, auch.
 */
export function areaOf(pathname: string): Area {
  const clean = (pathname.split("?")[0] ?? "").replace(/\/+$/, "") || "/";
  let bester: { area: Area; laenge: number } | null = null;
  for (const area of AREAS) {
    const adressen = [area.href, ...area.tabs.flatMap((t) => [t.href, ...(t.unter ?? []).map((u) => u.href)])];
    for (const href of adressen) {
      if (href === "/") continue;
      if ((clean === href || clean.startsWith(`${href}/`)) && (!bester || href.length > bester.laenge)) bester = { area, laenge: href.length };
    }
  }
  return bester?.area ?? AREAS[0]!;
}

/**
 * Der aktive Reiter: der laengste Pfad, mit dem der Pfad beginnt. Die Ansichten eines Reiters
 * zaehlen mit - auf `/waerme/wiedergabe` ist der Reiter „Anlage" aktiv.
 */
export function tabOf(area: Area, pathname: string): Tab | undefined {
  const clean = pathname.replace(/\/+$/, "") || "/";
  const passt = (href: string) => clean === href || clean.startsWith(`${href}/`);
  const paare = area.tabs.flatMap((t) => [t.href, ...(t.unter ?? []).map((u) => u.href)].map((href) => ({ href, tab: t })));
  return paare.sort((a, b) => b.href.length - a.href.length).find((x) => passt(x.href))?.tab;
}

/** Die aktive Ansicht eines Reiters, oder `undefined`, wenn er nur eine hat. */
export function ansichtOf(tab: Tab | undefined, pathname: string): Ansicht | undefined {
  const clean = pathname.replace(/\/+$/, "") || "/";
  return [...(tab?.unter ?? [])].sort((a, b) => b.href.length - a.href.length).find((u) => clean === u.href || clean.startsWith(`${u.href}/`));
}
