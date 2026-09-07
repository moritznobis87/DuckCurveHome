import type { NextRequest } from "next/server";
import { SESSION_COOKIE, authRequired, verifySession } from "@/lib/session";

/** Pfade, die Gästen verschlossen bleiben: die Rechnungen enthalten Name, Adresse, Zählernummer, IBAN. */
const GUEST_FORBIDDEN = [/^import\//, /^config\//];

/** Entfernt Kostenangaben rekursiv – Gäste sehen Energie, nicht was sie gekostet hat. */
function withoutCosts(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(withoutCosts);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([k]) => !/cost/i.test(k))
        .map(([k, v]) => [k, withoutCosts(v)]),
    );
  }
  return value;
}

/**
 * BFF-Proxy zur API. Liest die Ziel-URL zur Laufzeit (nicht zur Build-Zeit wie Rewrites), reicht
 * SSE-Streams ungepuffert durch und ist die Stelle, an der Phase 2 die Session-Prüfung ergänzt.
 */
export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const apiBase = (): string => (process.env.DCH_API_URL ?? "http://localhost:8000").replace(/\/$/, "");

async function proxy(req: NextRequest, ctx: { params: Promise<{ path: string[] }> }): Promise<Response> {
  const session = verifySession(req.cookies.get(SESSION_COOKIE)?.value);
  if (authRequired() && !session) {
    return Response.json({ error: { code: "unauthorized", message: "Nicht angemeldet.", details: null } }, { status: 401 });
  }
  const { path } = await ctx.params;
  // Gäste dürfen ausschließlich lesen. Serverseitig, nicht nur in der Anzeige: eine ausgeblendete Kachel
  // hält niemanden auf, der die Adresse kennt.
  const guest = session?.role === "guest";
  const joined = path.join("/");
  if (guest && (req.method !== "GET" || GUEST_FORBIDDEN.some((re) => re.test(joined)))) {
    return Response.json(
      { error: { code: "forbidden", message: "Gastzugang: nur Ansicht.", details: null } },
      { status: 403 },
    );
  }
  const target = `${apiBase()}/api/v1/${path.map(encodeURIComponent).join("/")}${req.nextUrl.search}`;
  const headers: Record<string, string> = { accept: req.headers.get("accept") ?? "*/*" };
  const apiToken = process.env.DCH_API_TOKEN;
  if (apiToken) headers["authorization"] = `Bearer ${apiToken}`;
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
  const isStream = upstream.headers.get("content-type")?.includes("text/event-stream") ?? false;
  if (isStream) {
    out.set("x-accel-buffering", "no");
    out.set("connection", "keep-alive");
  }
  // Für Gäste die Kosten aus der Antwort nehmen. Streams bleiben unangetastet: der Live-Zustand führt
  // Leistungen und Zustände, keine Beträge.
  if (guest && !isStream && out.get("content-type")?.includes("application/json")) {
    try {
      const body = withoutCosts(await upstream.json());
      return Response.json(body, { status: upstream.status, headers: out });
    } catch {
      return new Response(null, { status: upstream.status, headers: out });
    }
  }
  return new Response(upstream.body, { status: upstream.status, headers: out });
}

export const GET = proxy;
export const POST = proxy;
