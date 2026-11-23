import type { NextRequest } from "next/server";

import { anmeldungNoetig } from "@/lib/anmeldungAktiv";
import { PERSON_COOKIE } from "@/lib/zugang";

/**
 * BFF-Proxy zur API. Liest die Ziel-URL zur Laufzeit (nicht zur Build-Zeit wie Rewrites) und
 * reicht SSE-Ströme ungepuffert durch.
 *
 * **Er entscheidet nichts und besitzt nichts.** Vorher stand hier die Liste der Pfade, die ein
 * Gast nicht sehen darf, und das API-Token, mit dem er im Namen eines gepaarten Geräts sprach.
 * Beides ist weg: die Rechte liegen im Dienst (`dch_api/auth/rechte.py`), und der einzige
 * Nachweis, den diese Route weitergibt, ist das Sitzungstoken der angemeldeten Person. Damit ist
 * der Urheber eines Eingriffs keine Behauptung des Proxys mehr, sondern steht in der Datenbank.
 *
 * Kein Token, keine Antwort: 401. Die Oberfläche schickt den Besucher dann zur Anmeldung.
 *
 * Das **API-Token** reicht er nicht mehr weiter - das taten frühere Fassungen, wenn kein
 * Gerätecookie da war, und eine Instanz mit abgeschalteter Anmeldung hätte damit jedem Besucher
 * Vollzugriff gegeben.
 */
export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const apiBase = (): string => (process.env.DCH_API_URL ?? "http://localhost:8000").replace(/\/$/, "");

async function proxy(req: NextRequest, ctx: { params: Promise<{ path: string[] }> }): Promise<Response> {
  const personToken = req.cookies.get(PERSON_COOKIE)?.value ?? "";
  if (!personToken && anmeldungNoetig()) {
    return Response.json({ error: { code: "unauthorized", message: "Nicht angemeldet.", details: null } }, { status: 401 });
  }
  const { path } = await ctx.params;
  const target = `${apiBase()}/api/v1/${path.map(encodeURIComponent).join("/")}${req.nextUrl.search}`;
  const headers: Record<string, string> = { accept: req.headers.get("accept") ?? "*/*" };
  // **Das API-Token geht hier nicht mehr mit.** Vorher hing es an jeder Anfrage, für die kein
  // Gerätecookie da war - und damit hätte eine Instanz mit abgeschalteter Anmeldung jedem
  // Besucher Vollzugriff gereicht. Jetzt reicht der Proxy genau einen Nachweis weiter: das
  // Sitzungstoken der angemeldeten Person. Ohne Anmeldung (Demo) geht er ohne Nachweis weiter -
  // dort läuft der Dienst ohnehin ohne Token.
  if (personToken) headers["authorization"] = `Bearer ${personToken}`;
  // Ein Vorschlag von Alfred, im Panel bestätigt: Das Protokoll soll zeigen, dass ein
  // Sprachmodell den Anstoß gab. Nur dieser eine Wert wird durchgereicht, kein freier Text.
  if (req.headers.get("x-dch-ueber") === "alfred") headers["x-dch-urheber-ueber"] = "alfred";
  const contentType = req.headers.get("content-type");
  if (contentType) headers["content-type"] = contentType;
  let upstream: Response;
  try {
    upstream = await fetch(target, {
      method: req.method,
      headers,
      // Rumpf als Bytes weiterreichen: Rechnungs-PDFs dürfen nicht durch eine Textdekodierung laufen
      body: req.method === "GET" || req.method === "HEAD" ? undefined : await req.arrayBuffer(),
      cache: "no-store",
      signal: req.signal,
    });
  } catch {
    return Response.json({ error: { code: "upstream_unreachable", message: "Backend nicht erreichbar.", details: null } }, { status: 503 });
  }
  const out = new Headers();
  out.set("content-type", upstream.headers.get("content-type") ?? "application/json");
  out.set("cache-control", "no-store");
  // Ohne diesen Kopf landet der Export als „route.gz" im Download-Ordner statt unter seinem Namen.
  const disposition = upstream.headers.get("content-disposition");
  if (disposition) out.set("content-disposition", disposition);
  if (upstream.headers.get("content-type")?.includes("text/event-stream")) {
    out.set("x-accel-buffering", "no");
    out.set("connection", "keep-alive");
  }
  return new Response(upstream.body, { status: upstream.status, headers: out });
}

export const GET = proxy;
export const POST = proxy;
export const PUT = proxy;
