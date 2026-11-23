import type { NextRequest } from "next/server";

import { touch } from "@/lib/presence";
import { SESSION_COOKIE, anmeldungNoetig, verifySession } from "@/lib/session";
import { PERSON_COOKIE, rolleAusGeraet } from "@/lib/zugang";

/**
 * BFF-Proxy zur API. Liest die Ziel-URL zur Laufzeit (nicht zur Build-Zeit wie Rewrites) und
 * reicht SSE-Ströme ungepuffert durch.
 *
 * **Seit ADR-0002 entscheidet er nichts mehr.** Vorher stand hier die Liste der Pfade, die ein
 * Gast nicht sehen darf - das reichte, solange nur ein Browser mit dem Dienst sprach. Die
 * iOS-App spricht direkt mit ihm, und dort wäre dieselbe Liste nur eine ausgeblendete
 * Schaltfläche. Die Rechte liegen jetzt im Dienst (`dch_api/auth/rechte.py`), und diese Route
 * hat genau eine Aufgabe: den richtigen Nachweis anhängen.
 *
 * Zwei Fälle, und sie sind verschieden:
 *
 *   **Person angemeldet** - das opake Sitzungstoken aus `dch_person` geht als Bearer mit. Der
 *   Dienst kennt daraus Person und Rolle; der Urheber eines Eingriffs ist dann keine Behauptung
 *   des Proxys mehr, sondern steht in der Datenbank.
 *
 *   **Gepaartes Gerät oder Gastlink** - das API-Token geht mit, und der Urheber kommt wie bisher
 *   als Kopfzeile. Wer das Token hat, könnte jeden Namen behaupten; er könnte aber ohnehin alles
 *   (docs/URHEBER.md).
 */
export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const apiBase = (): string => (process.env.DCH_API_URL ?? "http://localhost:8000").replace(/\/$/, "");

async function proxy(req: NextRequest, ctx: { params: Promise<{ path: string[] }> }): Promise<Response> {
  const personToken = req.cookies.get(PERSON_COOKIE)?.value ?? "";
  const geraet = verifySession(req.cookies.get(SESSION_COOKIE)?.value);
  if (anmeldungNoetig() && !personToken && !geraet) {
    return Response.json({ error: { code: "unauthorized", message: "Nicht angemeldet.", details: null } }, { status: 401 });
  }
  if (geraet && !personToken) {
    touch({ name: geraet.name, rolle: rolleAusGeraet(geraet.role) }, req.headers.get("user-agent"));
  }
  const { path } = await ctx.params;
  const target = `${apiBase()}/api/v1/${path.map(encodeURIComponent).join("/")}${req.nextUrl.search}`;
  const headers: Record<string, string> = { accept: req.headers.get("accept") ?? "*/*" };
  if (personToken) {
    headers["authorization"] = `Bearer ${personToken}`;
    // Der Dienst kennt die Person; das Gerät kennt nur dieser Proxy. Beides zusammen ergibt im
    // Protokoll „Moritz, am iPad Flur" - der Dienst nimmt den Gerätenamen nur als Zusatz und
    // niemals die Rolle aus einer Kopfzeile, wenn eine Sitzung dahintersteht.
    if (geraet?.name) headers["x-dch-urheber-geraet"] = geraet.name;
  } else {
    const apiToken = process.env.DCH_API_TOKEN;
    if (apiToken) headers["authorization"] = `Bearer ${apiToken}`;
    if (geraet?.name) {
      headers["x-dch-urheber-art"] = "geraet";
      headers["x-dch-urheber-name"] = geraet.name;
      headers["x-dch-urheber-geraet"] = geraet.name;
      headers["x-dch-urheber-rolle"] = geraet.role;
    }
  }
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
