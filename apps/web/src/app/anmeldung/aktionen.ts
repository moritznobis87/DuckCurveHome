"use server";

import { cookies, headers } from "next/headers";

import { DienstFehler, dienstAnfrage } from "@/lib/dienst";
import { PERSON_COOKIE, personCookieOptions } from "@/lib/zugang";

/**
 * Die Anmeldung als Server Actions - nicht über den BFF-Proxy.
 *
 * Der Proxy unter `/api/dch/*` verlangt eine Sitzung, und wer sich anmelden will, hat keine. Die
 * Zeremonie läuft darum so: der Browser holt hier die Optionen, lässt `navigator.credentials`
 * rechnen und reicht die Antwort hier wieder herein. Das **Sitzungstoken sieht der Browser nie** -
 * es kommt vom Dienst zum Server und von dort in ein HttpOnly-Cookie.
 */

export interface Zeremonie {
  schritt?: string;
  optionen?: string;
  fehler?: string;
}

export interface Ergebnis {
  fehler?: string;
  /** Nur beim Einrichten: die zehn Wiederherstellungscodes, einmalig. */
  codes?: string[];
}

interface AngemeldetAntwort {
  token: string;
  laeuft_ab_am: string;
  codes?: string[];
}

const ABGELEHNT = "Die Anmeldung ist nicht möglich.";

/** Der User-Agent des Besuchers - er landet als Herkunft in der Sitzungsliste. */
async function browser(): Promise<string> {
  return (await headers()).get("user-agent") ?? "";
}

function meldung(e: unknown, vorgabe: string): string {
  return e instanceof DienstFehler && e.status !== 500 ? e.message : vorgabe;
}

async function sitzungSetzen(antwort: AngemeldetAntwort): Promise<void> {
  const store = await cookies();
  // Die Frist des Cookies folgt der Frist der Sitzung: ein Cookie, das länger lebt als die
  // Sitzung, schickt den Browser bei jedem Aufruf in eine Absage statt auf die Anmeldeseite.
  const sekunden = Math.max(
    60,
    Math.floor((new Date(antwort.laeuft_ab_am).getTime() - Date.now()) / 1000),
  );
  store.set(PERSON_COOKIE, antwort.token, { ...personCookieOptions, maxAge: sekunden });
}

/** Die Optionen für `navigator.credentials.get`. */
export async function passkeyOptionen(): Promise<Zeremonie> {
  try {
    return await dienstAnfrage<Zeremonie>("/auth/anmeldung/beginnen", { methode: "POST", rumpf: {} });
  } catch (e) {
    return { fehler: meldung(e, "Die Anmeldung ist gerade nicht möglich.") };
  }
}

/** Die Antwort des Geräts prüfen und anmelden. */
export async function passkeyAnmelden(schritt: string, antwort: unknown): Promise<Ergebnis> {
  try {
    const ergebnis = await dienstAnfrage<AngemeldetAntwort>("/auth/anmeldung/abschliessen", {
      methode: "POST",
      rumpf: { schritt, antwort },
      browser: await browser(),
    });
    await sitzungSetzen(ergebnis);
    return {};
  } catch (e) {
    return { fehler: meldung(e, ABGELEHNT) };
  }
}

/** Anmeldung mit E-Mail-Adresse und Wiederherstellungscode. */
export async function wiederherstellen(_vorher: Ergebnis, daten: FormData): Promise<Ergebnis> {
  const email = String(daten.get("email") ?? "");
  const code = String(daten.get("code") ?? "");
  try {
    const ergebnis = await dienstAnfrage<AngemeldetAntwort>("/auth/wiederherstellung", {
      methode: "POST",
      rumpf: { email, code },
      browser: await browser(),
    });
    await sitzungSetzen(ergebnis);
    return {};
  } catch (e) {
    return { fehler: meldung(e, ABGELEHNT) };
  }
}

/** Die Optionen für einen neuen Passkey hinter dem Einladungslink. */
export async function einrichtenOptionen(token: string): Promise<Zeremonie> {
  try {
    return await dienstAnfrage<Zeremonie>("/auth/einladung/passkey/beginnen", {
      methode: "POST",
      rumpf: { token },
    });
  } catch (e) {
    return { fehler: meldung(e, "Dieser Link gilt nicht mehr.") };
  }
}

/**
 * Den Passkey anlegen, den Link einlösen, anmelden - und die Codes zurückgeben.
 *
 * Die zehn Wiederherstellungscodes gehen **einmal** hinaus, hier. Darum leitet diese Aktion nicht
 * weiter: erst muss die Seite sie gezeigt haben.
 */
export async function einrichtenAnlegen(
  token: string,
  schritt: string,
  antwort: unknown,
  name: string,
): Promise<Ergebnis> {
  try {
    const ergebnis = await dienstAnfrage<AngemeldetAntwort>("/auth/einladung/passkey/abschliessen", {
      methode: "POST",
      rumpf: { token, schritt, antwort, name },
      browser: await browser(),
    });
    await sitzungSetzen(ergebnis);
    return { codes: ergebnis.codes ?? [] };
  } catch (e) {
    return { fehler: meldung(e, "Der Passkey ließ sich nicht anlegen.") };
  }
}

/** Abmelden: die Sitzung beim Dienst beenden und das Cookie löschen. */
export async function abmelden(): Promise<void> {
  const store = await cookies();
  const token = store.get(PERSON_COOKIE)?.value;
  if (token) {
    try {
      await dienstAnfrage("/auth/abmelden", { methode: "POST", rumpf: {}, token });
    } catch {
      // Der Dienst ist nicht erreichbar: das Cookie geht trotzdem weg. Der Anwender wollte
      // abgemeldet sein, und das ist er - die Sitzung läuft dann von selbst ab.
    }
  }
  store.delete(PERSON_COOKIE);
}
