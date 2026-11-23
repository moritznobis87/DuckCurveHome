import "server-only";

import { cookies } from "next/headers";

import { dienstAnfrage } from "@/lib/dienst";
import { SESSION_COOKIE, authRequired, verifySession, type Role } from "@/lib/session";

/**
 * Wer gerade zusieht - Person oder Gerät.
 *
 * Es gibt zwei Cookies, und das ist Absicht (ADR-0002):
 *
 *   `dch_person`   das opake Sitzungstoken einer angemeldeten Person. Die Wahrheit steht in der
 *                  Datenbank des Dienstes; das Cookie ist nur der Schlüssel dazu, und eine
 *                  Sitzung lässt sich einzeln beenden.
 *   `dch_session`  die Paarung eines **Geräts** (Wandanzeige) oder ein Gastlink, signiert mit
 *                  `DCH_SESSION_SECRET` wie bisher. Das iPad im Flur soll sich nicht anmelden
 *                  müssen, und ein Gast soll für acht Stunden Zusehen kein Konto brauchen.
 *
 * Beides gilt nebeneinander. Gefragt wird in dieser Reihenfolge: eine angemeldete Person sticht
 * die Gerätepaarung, denn sie sagt mehr - einen Namen und eine Rolle, die im Protokoll steht.
 */

export const PERSON_COOKIE = "dch_person";
/** Ein halbes Jahr wie beim Gerät wäre zu lang; die Frist der Sitzung setzt der Dienst. */
export const PERSON_MAX_AGE_S = 30 * 24 * 3600;

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

/** Die alte Rolle eines gepaarten Geräts auf die neue Benennung bringen. */
export function rolleAusGeraet(role: Role): Rolle {
  return role === "owner" ? "hausherr" : "gast";
}

/**
 * Wer fragt. `null`, wenn niemand angemeldet ist.
 *
 * Für die Person kostet das eine Anfrage an den Dienst, und die ist der Preis dafür, dass eine
 * Sitzung sofort widerrufbar ist: ein abgeschalteter Zugang ist im nächsten Augenblick draußen
 * und nicht erst in dreißig Tagen.
 */
export async function ausweis(): Promise<Ausweis | null> {
  const token = await personToken();
  if (token) {
    try {
      return await dienstAnfrage<Ausweis>("/auth/wer", { token });
    } catch {
      // Abgelaufen, widerrufen oder Dienst nicht erreichbar: dann gilt nur noch das Gerät.
    }
  }
  if (!authRequired()) {
    return { art: "dienst", rolle: "hausherr", person_id: "", name: "Entwicklung", email: "" };
  }
  const store = await cookies();
  const geraet = verifySession(store.get(SESSION_COOKIE)?.value);
  if (!geraet) return null;
  return {
    art: geraet.role === "guest" ? "gast" : "geraet",
    rolle: rolleAusGeraet(geraet.role),
    person_id: "",
    name: geraet.name,
    email: "",
  };
}

/** Ob überhaupt eine Anmeldung verlangt wird - und ob es schon Personen gibt. */
export async function zustand(): Promise<{
  anmeldung: boolean;
  personen: number;
  rp_id: string;
  versand: { aktiv: boolean; weg: string; fehlt: string[] };
}> {
  try {
    return await dienstAnfrage("/auth/zustand");
  } catch {
    return { anmeldung: false, personen: 0, rp_id: "", versand: { aktiv: false, weg: "", fehlt: [] } };
  }
}
