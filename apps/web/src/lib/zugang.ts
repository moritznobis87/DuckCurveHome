import "server-only";

import { cookies } from "next/headers";

import { anmeldungNoetig } from "@/lib/anmeldungAktiv";
import { dienstAnfrage } from "@/lib/dienst";

/**
 * Wer gerade angemeldet ist.
 *
 * **Ein Cookie, eine Wahrheit.** `dch_person` enthält das opake Sitzungstoken; was es bedeutet,
 * weiß allein der Dienst. Bis zum 23.11.2026 stand daneben ein zweites, signiertes Cookie für
 * gepaarte Geräte (`dch_session`) - das ist weg, samt den stehenden URL-Tokens, die es ausstellten
 * (ADR-0002, Nachtrag „Die Gerätepaarung ist ausgebaut").
 *
 * Eine Person kann an beliebig vielen Geräten zugleich angemeldet sein: je Gerät eine Zeile in
 * `person_sitzungen`, einzeln zu beenden. Das Cookie ist nur der Schlüssel dazu.
 */

export const PERSON_COOKIE = "dch_person";
/** Höchstalter des Cookies. Die eigentliche Frist der Sitzung setzt der Dienst. */
export const PERSON_MAX_AGE_S = 180 * 24 * 3600;

export type Rolle = "hausherr" | "bewohner" | "gast" | "service";
export type Art = "person" | "geraet" | "gast" | "dienst";

export interface Ausweis {
  art: Art;
  rolle: Rolle;
  person_id: string;
  name: string;
  email: string;
}

export const personCookieOptions = {
  httpOnly: true,
  sameSite: "lax" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
  maxAge: PERSON_MAX_AGE_S,
};

/** Das Sitzungstoken der Person aus dem Cookie - oder leer. */
export async function personToken(): Promise<string> {
  const store = await cookies();
  return store.get(PERSON_COOKIE)?.value ?? "";
}

/**
 * Wer fragt. `null`, wenn niemand angemeldet ist.
 *
 * Das kostet eine Anfrage an den Dienst, und die ist der Preis dafür, dass eine Sitzung sofort
 * widerrufbar ist: ein abgeschalteter Zugang ist im nächsten Augenblick draußen und nicht erst
 * mit dem Ablauf.
 */
export async function ausweis(): Promise<Ausweis | null> {
  const token = await personToken();
  if (token) {
    try {
      return await dienstAnfrage<Ausweis>("/auth/wer", { token });
    } catch {
      // Abgelaufen, widerrufen oder Dienst nicht erreichbar.
    }
  }
  if (!anmeldungNoetig()) {
    // Demo und Entwicklung: ohne Datenbank gibt es keine Personen, und die Oberfläche soll
    // trotzdem bedienbar sein.
    return { art: "dienst", rolle: "hausherr", person_id: "", name: "Entwicklung", email: "" };
  }
  return null;
}

/** Ob überhaupt eine Anmeldung möglich ist - und ob es schon Personen gibt. */
export async function zustand(): Promise<{
  anmeldung: boolean;
  personen: number;
  rp_id: string;
  versand: { aktiv: boolean; weg: string; fehlt: string[] };
  /** Wie lang ein Passwort mindestens sein muss; die Regel steht beim Dienst. */
  passwort_mindestlaenge: number;
}> {
  try {
    return await dienstAnfrage("/auth/zustand");
  } catch {
    return {
      anmeldung: false,
      personen: 0,
      rp_id: "",
      versand: { aktiv: false, weg: "", fehlt: [] },
      passwort_mindestlaenge: 12,
    };
  }
}
