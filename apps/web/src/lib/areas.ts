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
      { href: "/haus", label: "Räume" },
      { href: "/waerme/raeume", label: "Über den Tag", dated: true },
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
      { href: "/strom", label: "Strom", dated: true, beschreibung: "Woher der Strom kam und wer ihn verbraucht hat." },
      { href: "/waerme", label: "Wärme", dated: true, beschreibung: "Was die Wärmepumpe gebraucht hat und woher die Wärme kam." },
      { href: "/strom/pv", label: "Photovoltaik", dated: true, beschreibung: "Was die Anlage erzeugt hat und wohin der Sonnenstrom ging." },
      // Die Prognose der Photovoltaik gegen das, was wirklich kam. Sie steht neben ihr und nicht
      // als Ansicht darunter, weil sie keinen Zeitraum kennt und die Photovoltaik einen hat.
      { href: "/system", label: "Prognose", ownerOnly: true, beschreibung: "Wie gut die Vorhersage des Sonnenertrags getroffen hat." },
      { href: "/strom/speicher", label: "Speicher", dated: true, beschreibung: "Wann der Speicher geladen und entladen hat." },
      { href: "/strom/wallbox", label: "Wallbox", dated: true, beschreibung: "Wann das Auto geladen hat und mit welchem Strom." },
      { href: "/strom/jahr", label: "Jahreskarte", beschreibung: "Jede Stunde eines Jahres als Bild." },
    ],
  },
  {
    key: "geld",
    href: "/geld",
    icon: "euro",
    label: "Geld",
    tabs: [
      { href: "/geld", label: "Kosten", dated: true },
      { href: "/geld/pv-abrechnung", label: "PV-Abrechnung", dated: true, ownerOnly: true },
      { href: "/geld/rechnungen", label: "Rechnungen", ownerOnly: true },
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
      {
        href: "/waerme/anlage",
        label: "Anlage",
        gruppe: "Maschine",
        beschreibung: "Speicher, Vorlauf und Heizkreise im Schema, im Augenblick und über einen Tag.",
        // Die Wiedergabe ist die Anlage ueber einen Tag.
        unter: [
          { href: "/waerme/anlage", label: "Jetzt" },
          { href: "/waerme/wiedergabe", label: "Ein Tag" },
        ],
      },
      // Die Wärmepumpe allein, mit allem, was ihr eigener Bus meldet (seit dem 14.11.2026).
      {
        href: "/waerme/waermepumpe",
        label: "Wärmepumpe",
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
      {
        href: "/waerme/fahrplan",
        label: "Fahrplan",
        gruppe: "Regelung",
        beschreibung: "Wann die Wärmepumpe laufen soll und was der Plan von gestern gehalten hat.",
        // Die Nachbetrachtung ist der Fahrplan im Rueckblick.
        unter: [
          { href: "/waerme/fahrplan", label: "Voraus" },
          { href: "/waerme/nachbetrachtung", label: "Rückblick" },
        ],
      },
      {
        href: "/waerme/wirkung",
        label: "Wirkung",
        gruppe: "Regelung",
        beschreibung: "Ob die Wärmepumpe der Anforderung folgt, gemessen an ihren Läufen.",
      },
      // Die Regelung selbst, als Blockschaltbild: fünf Kaskadenebenen, ihre Störgrößen und der
      // Lernstand jedes Parameters. Steht hinter der Wirkung, weil sie deren Zahlen verwendet.
      {
        href: "/waerme/regelkreis",
        label: "Regelkreis",
        gruppe: "Regelung",
        ownerOnly: true,
        beschreibung: "Die Regelung mit ihren Ebenen, Stellgrößen und Parametern.",
      },
      {
        href: "/waerme/annahmen",
        label: "Annahmen",
        gruppe: "Abstimmung",
        ownerOnly: true,
        beschreibung: "Die Werte, mit denen das Modell des Hauses rechnet.",
      },
      // Was am Regler eingestellt ist, gelesen über den Bus. Bis zum 23.11.2026 eine Ansicht
      // der Wärmepumpe; als Stelle zum Einstellen gehört er zur Abstimmung.
      {
        href: "/waerme/waermepumpe/regler",
        label: "Regler",
        gruppe: "Abstimmung",
        beschreibung: "Die Einstellungen am Regler der Wärmepumpe, über den Bus gelesen.",
      },
    ],
  },
  {
    key: "system",
    // Auch das System geht auf seiner Übersicht auf (Vorgabe des Hausherrn vom 24.11.2026). Sie
    // steht unter `/system/uebersicht`, weil `/system` die Adresse der Prognose ist und bleibt.
    href: "/system/uebersicht",
    icon: "gear",
    label: "System",
    ownerOnly: true,
    leiste: false,
    tabs: [
      { href: "/system/mitteilungen", label: "Mitteilungen", ownerOnly: true, beschreibung: "Welche Geräte Mitteilungen bekommen und was im Morgenbrief steht." },
      { href: "/system/haustuer", label: "Haustür", ownerOnly: true, beschreibung: "Wer sich wann an der Haustür erkannt hat." },
      // Der Rechner im Haus selbst: Dienste, Gesundheit, Neustarts, Protokolle, Updates.
      { href: "/system/geraet", label: "Hausgerät", ownerOnly: true, beschreibung: "Wie es dem Rechner im Haus und seinen Diensten geht." },
      { href: "/system/zugang", label: "Zugang und Sicherung", ownerOnly: true, beschreibung: "Wer Zugang hat, wie groß die Datenbank ist und wie man sie sichert." },
      { href: "/system/daten", label: "Daten prüfen", dated: true, ownerOnly: true, beschreibung: "Ob die Messreihen lückenlos angekommen sind und zueinander passen." },
    ],
  },
];

/** Die Bereiche der Leiste, in ihrer Reihenfolge. Das System gehoert nicht dazu. */
export const LEISTE: Area[] = AREAS.filter((a) => a.leiste !== false);

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
