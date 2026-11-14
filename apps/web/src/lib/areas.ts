/**
 * Die Seitenstruktur: fuenf Bereiche nach Frage, dazu System fuer den Hausherrn.
 *
 * **Warum nach Frage und nicht nach Geraet.** Dreizehn Seiten waren nacheinander entstanden, je
 * eine je Geraet, und jede mit eigener Zeitraumwahl. Wer die Woche in der Photovoltaik ansah und
 * dann zum Speicher ging, stand dort wieder auf heute. Jetzt teilen sich die Reiter eines Bereichs
 * den Zeitraum: er reist als `?period=&anchor=` von Reiter zu Reiter mit.
 *
 * Die alten Adressen leiten in `next.config.ts` auf die neuen um, Lesezeichen bleiben gueltig.
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
};

export type Ansicht = { href: string; label: string };

export type Area = {
  key: "jetzt" | "haus" | "energie" | "geld" | "technik";
  href: string;
  icon: IconName;
  label: string;
  ownerOnly?: boolean;
  tabs: Tab[];
};

/**
 * **Alltag vorn, Technik hinten** (seit dem 11.11.2026).
 *
 * Vorher standen Fahrplan, Wirkung, Annahmen und Prognose gleichberechtigt neben dem, was jemand
 * im Haus täglich braucht, und die Räume lagen zwei Ebenen tief unter Wärme. Die Leiste hat jetzt
 * vier Bereiche für den Alltag und einen für den, der die Anlage betreibt:
 *
 * - **Jetzt**: was gerade ist und was als Nächstes kommt.
 * - **Haus**: die Räume, als Liste zum Stellen oder als Modell. Ohne Reiter.
 * - **Energie**: was verbraucht und erzeugt wurde, Strom und Wärme nebeneinander.
 * - **Geld**: was es gekostet hat.
 * - **Technik**: wie die Anlage arbeitet und woran man sie einstellt.
 *
 * Die Adressen sind dieselben geblieben. Ein Bereich ist deshalb nicht mehr das erste Stück des
 * Pfads: `/waerme` gehört zur Energie, `/waerme/anlage` zur Technik. Was nur der Hausherr sieht,
 * steht am Reiter, nicht mehr am Bereich.
 */
export const AREAS: Area[] = [
  { key: "jetzt", href: "/", icon: "duck", label: "Jetzt", tabs: [] },
  // Das Haus: die Räume als Liste und als Modell, ein Schalter in der Seite und kein Reiter.
  // Die Geometrie kommt von der Bruecke (haus.yaml), die Werte aus Raeumen und Live-Zustand.
  { key: "haus", href: "/haus", icon: "house", label: "Haus", tabs: [] },
  {
    key: "energie",
    href: "/strom",
    icon: "bolt",
    label: "Energie",
    tabs: [
      { href: "/strom", label: "Strom", dated: true },
      { href: "/waerme", label: "Wärme", dated: true },
      { href: "/strom/pv", label: "Photovoltaik", dated: true },
      { href: "/strom/speicher", label: "Speicher", dated: true },
      { href: "/strom/wallbox", label: "Wallbox", dated: true },
      { href: "/strom/jahr", label: "Jahreskarte" },
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
    key: "technik",
    href: "/waerme/anlage",
    icon: "gear",
    label: "Technik",
    // Erst die Anlage und ihr Fahrplan, dann die Auswertungen, dann das Einstellen. Die
    // Wiedergabe ist die Anlage ueber einen Tag, die Nachbetrachtung der Fahrplan im Rueckblick.
    tabs: [
      {
        href: "/waerme/anlage",
        label: "Anlage",
        unter: [
          { href: "/waerme/anlage", label: "Jetzt" },
          { href: "/waerme/wiedergabe", label: "Ein Tag" },
        ],
      },
      // Die Wärmepumpe allein, mit allem, was ihr eigener Bus meldet (seit dem 14.11.2026).
      {
        href: "/waerme/waermepumpe",
        label: "Wärmepumpe",
        // Der Augenblick und die gemessene Kennlinie: dieselbe Maschine, einmal jetzt, einmal
        // über Wochen.
        unter: [
          { href: "/waerme/waermepumpe", label: "Jetzt" },
          { href: "/waerme/waermepumpe/kennlinie", label: "Kennlinie" },
        ],
      },
      {
        href: "/waerme/fahrplan",
        label: "Fahrplan",
        unter: [
          { href: "/waerme/fahrplan", label: "Voraus" },
          { href: "/waerme/nachbetrachtung", label: "Rückblick" },
        ],
      },
      { href: "/waerme/wirkung", label: "Wirkung" },
      { href: "/waerme/raeume", label: "Heizkreise", dated: true },
      { href: "/system", label: "Prognose", ownerOnly: true },
      { href: "/system/daten", label: "Daten prüfen", dated: true, ownerOnly: true },
      { href: "/waerme/annahmen", label: "Annahmen", ownerOnly: true },
      { href: "/system/mitteilungen", label: "Mitteilungen", ownerOnly: true },
      { href: "/system/haustuer", label: "Haustür", ownerOnly: true },
      { href: "/system/zugang", label: "Zugang und Sicherung", ownerOnly: true },
    ],
  },
];

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
