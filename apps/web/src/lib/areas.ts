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
};

export type Area = {
  key: "jetzt" | "haus" | "strom" | "waerme" | "geld" | "system";
  href: string;
  icon: IconName;
  label: string;
  ownerOnly?: boolean;
  tabs: Tab[];
};

export const AREAS: Area[] = [
  { key: "jetzt", href: "/", icon: "duck", label: "Jetzt", tabs: [] },
  // Das Haus als Modell: ein Bereich ohne Reiter und ohne Zeitraum, weil er den Augenblick
  // zeigt. Die Geometrie kommt von der Bruecke (haus.yaml), die Werte aus Raeumen und Live-Zustand.
  { key: "haus", href: "/haus", icon: "house", label: "Haus", tabs: [] },
  {
    key: "strom",
    href: "/strom",
    icon: "bolt",
    label: "Strom",
    tabs: [
      { href: "/strom", label: "Bilanz", dated: true },
      { href: "/strom/pv", label: "Photovoltaik", dated: true },
      { href: "/strom/speicher", label: "Speicher", dated: true },
      { href: "/strom/wallbox", label: "Wallbox", dated: true },
      { href: "/strom/jahr", label: "Jahreskarte" },
    ],
  },
  {
    key: "waerme",
    href: "/waerme",
    icon: "flame",
    label: "Wärme",
    tabs: [
      { href: "/waerme", label: "Erzeuger", dated: true },
      { href: "/waerme/bilanz", label: "Bilanz", dated: true },
      { href: "/waerme/raeume", label: "Räume", dated: true },
      { href: "/waerme/annahmen", label: "Annahmen", ownerOnly: true },
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
    key: "system",
    href: "/system",
    icon: "gear",
    label: "System",
    ownerOnly: true,
    tabs: [
      { href: "/system", label: "Prognose" },
      { href: "/system/daten", label: "Daten prüfen", dated: true },
      { href: "/system/mitteilungen", label: "Mitteilungen" },
      { href: "/system/haustuer", label: "Haustür" },
      { href: "/system/zugang", label: "Zugang und Sicherung" },
    ],
  },
];

/** Der Bereich, zu dem ein Pfad gehoert. `/` ist Jetzt, alles andere nach dem ersten Segment. */
export function areaOf(pathname: string): Area {
  const seg = `/${pathname.split("/")[1] ?? ""}`;
  return AREAS.find((a) => a.href === seg) ?? AREAS[0]!;
}

/** Der aktive Reiter: der laengste Reiterpfad, mit dem der Pfad beginnt. */
export function tabOf(area: Area, pathname: string): Tab | undefined {
  const clean = pathname.replace(/\/+$/, "") || "/";
  return [...area.tabs].sort((a, b) => b.href.length - a.href.length).find((t) => clean === t.href || clean.startsWith(`${t.href}/`));
}
