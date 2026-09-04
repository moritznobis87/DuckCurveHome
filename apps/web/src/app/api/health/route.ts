export const dynamic = "force-dynamic";

/** Gesundheitscheck des Web-Services inkl. Erreichbarkeit der API. */
export async function GET(): Promise<Response> {
  const base = (process.env.DCH_API_URL ?? "http://localhost:8000").replace(/\/$/, "");
  try {
    const r = await fetch(`${base}/health`, { cache: "no-store", signal: AbortSignal.timeout(3000) });
    return Response.json({ status: r.ok ? "ok" : "degraded", api: r.status }, { status: r.ok ? 200 : 503 });
  } catch {
    return Response.json({ status: "degraded", api: "unreachable" }, { status: 503 });
  }
}
