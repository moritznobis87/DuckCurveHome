import type { NextRequest } from "next/server";

/**
 * BFF-Proxy zur API. Liest die Ziel-URL zur Laufzeit (nicht zur Build-Zeit wie Rewrites), reicht
 * SSE-Streams ungepuffert durch und ist die Stelle, an der Phase 2 die Session-Prüfung ergänzt.
 */
export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const apiBase = (): string => (process.env.DCH_API_URL ?? "http://localhost:8000").replace(/\/$/, "");

async function proxy(req: NextRequest, ctx: { params: Promise<{ path: string[] }> }): Promise<Response> {
  const { path } = await ctx.params;
  const target = `${apiBase()}/api/v1/${path.map(encodeURIComponent).join("/")}${req.nextUrl.search}`;
  const headers: Record<string, string> = { accept: req.headers.get("accept") ?? "*/*" };
  const contentType = req.headers.get("content-type");
  if (contentType) headers["content-type"] = contentType;
  let upstream: Response;
  try {
    upstream = await fetch(target, {
      method: req.method,
      headers,
      body: req.method === "GET" || req.method === "HEAD" ? undefined : await req.text(),
      cache: "no-store",
      signal: req.signal,
    });
  } catch {
    return Response.json({ error: { code: "upstream_unreachable", message: "Backend nicht erreichbar.", details: null } }, { status: 503 });
  }
  const out = new Headers();
  out.set("content-type", upstream.headers.get("content-type") ?? "application/json");
  out.set("cache-control", "no-store");
  if (upstream.headers.get("content-type")?.includes("text/event-stream")) {
    out.set("x-accel-buffering", "no");
    out.set("connection", "keep-alive");
  }
  return new Response(upstream.body, { status: upstream.status, headers: out });
}

export const GET = proxy;
export const POST = proxy;
