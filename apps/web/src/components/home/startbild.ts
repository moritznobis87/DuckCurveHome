/**
 * Die zwei Bilder für die Mitte der Startseite.
 *
 * Der Hausherr hat am 25.11.2026 beide bauen lassen, mit einer Umschaltung auf „Einstellen“. Die
 * Wahl gilt je Gerät, so wie der Platz von Alfreds Ente: die Wand kann die Uhr zeigen und das
 * Telefon die Bühne. Die App führt dieselbe Liste in `Startbild.swift`; ein Test hält die Wörter
 * gleich.
 */
export type Startbild = "buehne" | "uhr";

export const STARTBILD_VORGABE: Startbild = "buehne";
/** Unter diesem Namen liegt die Wahl im Browser; die App nimmt denselben für `@AppStorage`. */
export const STARTBILD_MERKER = "dch-startbild";

export const STARTBILDER: ReadonlyArray<{ id: Startbild; name: string; satz: string }> = [
  { id: "buehne", name: "Die Bühne", satz: "Das Haus steht unter seinem Himmel, und der Strom fließt als leuchtendes Band." },
  { id: "uhr", name: "Die Uhr", satz: "Ein Ring über 24 Stunden zeigt den Strompreis, die erwartete Sonne und die Läufe der Wärmepumpe." },
];

export const STARTBILD_TITEL = "Startseite";
export const STARTBILD_FRAGE = "Welches Bild die Mitte der Startseite auf diesem Gerät trägt.";

/** Was im Speicher steht, als Bild. Alles Unbekannte ist die Vorgabe. */
export function startbildAus(wert: string | null | undefined): Startbild {
  return wert === "uhr" || wert === "buehne" ? wert : STARTBILD_VORGABE;
}
