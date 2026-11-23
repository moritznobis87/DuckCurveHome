import "server-only";

/**
 * Anfragen an die API **vom Server aus**, am BFF-Proxy vorbei.
 *
 * Gebraucht für genau einen Fall: die Anmeldung. Der Proxy unter `/api/dch/*` verlangt eine
 * Sitzung, und wer sich anmelden will, hat keine - die Durchreiche kann das also nicht leisten.
 * Die Anmeldeseite ruft darum über Server Actions hier herein; der Browser sieht nie eine
 * Adresse der API und nie das API-Token.
 *
 * Alles andere läuft weiter über `lib/api/client.ts` und den Proxy.
 */

const BASE = (): string => (process.env.DCH_API_URL ?? "http://localhost:8000").replace(/\/$/, "");

export class DienstFehler extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

/**
 * Eine Anfrage an die API. `token` wird als Bearer mitgeschickt, wenn angegeben.
 *
 * `browser` reicht den User-Agent des Besuchers durch. Ohne das stünde in der Sitzungsliste
 * „node" - der Agent dieses Servers -, und die Frage „welches Gerät ist das?" wäre für jede
 * Sitzung gleich unbeantwortbar.
 */
export async function dienstAnfrage<T>(
  pfad: string,
  opt: { methode?: "GET" | "POST"; rumpf?: unknown; token?: string; browser?: string } = {},
): Promise<T> {
  const kopf: Record<string, string> = { accept: "application/json" };
  if (opt.rumpf !== undefined) kopf["content-type"] = "application/json";
  if (opt.token) kopf["authorization"] = `Bearer ${opt.token}`;
  if (opt.browser) kopf["user-agent"] = opt.browser;
  let antwort: Response;
  try {
    antwort = await fetch(`${BASE()}/api/v1${pfad}`, {
      method: opt.methode ?? "GET",
      headers: kopf,
      body: opt.rumpf === undefined ? undefined : JSON.stringify(opt.rumpf),
      cache: "no-store",
    });
  } catch {
    throw new DienstFehler("network", "Der Dienst ist nicht erreichbar.", 0);
  }
  if (!antwort.ok) {
    let code = "http_error";
    let meldung = `Fehler ${antwort.status}`;
    try {
      const body = (await antwort.json()) as { error?: { code?: string; message?: string } };
      code = body.error?.code ?? code;
      meldung = body.error?.message ?? meldung;
    } catch {
      /* kein JSON-Envelope */
    }
    throw new DienstFehler(code, meldung, antwort.status);
  }
  return (await antwort.json()) as T;
}
