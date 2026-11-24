import type { IconName } from "@/components/ui/Icon";

/**
 * Die Worte der Seite „Mein Zugang“. Dieselben stehen in der App (`Kontoworte.swift`); je ein
 * Test hält beide auf demselben Wortlaut (`kontoworte.test.ts`, `KontowortTests.swift`).
 */

/** Wie die Rollen auf dieser Seite heißen, und was sie dürfen; dieselben in `Kontoworte.swift`. */
export const ROLLE: Record<string, { name: string; satz: string }> = {
  hausherr: { name: "Hausherr", satz: "Sieht alles und darf alles einstellen." },
  bewohner: { name: "Bewohner", satz: "Sieht das Haus und darf dort stellen." },
  service: { name: "Beratung", satz: "Sieht zu und stellt nichts." },
  gast: { name: "Gast", satz: "Sieht zu und stellt nichts." },
};

/** Die Karten der Seite: Zeichen, Titel und der Satz darunter; dieselben in `Kontoworte.swift`. */
export const KARTEN = {
  passkeys: { zeichen: "key", titel: "Passkeys", satz: "Anmelden mit Gesicht oder Finger, ohne Passwort." },
  passwort: { zeichen: "lock", titel: "Passwort", satz: "Der zweite Weg herein, an jedem Gerät." },
  sitzungen: { zeichen: "device", titel: "Sitzungen", satz: "Wo du gerade angemeldet bist." },
} satisfies Record<string, { zeichen: IconName; titel: string; satz: string }>;


/** Die Rückfrage vor dem Löschen eines Passkeys, mit seinem Namen; dieselbe in `Kontoworte.swift`. */
export const loeschfrage = (name: string): string => `„${name}“ löschen?`;
