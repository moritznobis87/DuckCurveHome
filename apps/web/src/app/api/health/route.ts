export const dynamic = "force-dynamic";

/** Kurzform der Fehlerursache aus einem fetch-Fehler (z. B. ENOTFOUND, ECONNREFUSED, TimeoutError). */
function errorCode(err: unknown): string {
  if (err instanceof Error) {
    const cause = (err as Error & { cause?: { code?: string } }).cause;
    return cause?.code ?? err.name;
  }
  return "unknown";
}

/** Gesundheitscheck des Web-Services inkl. Erreichbarkeit der API (Zielhost zur Fehlersuche, ohne Token). */
export async function GET(): Promise<Response> {
  const base = (process.env.DCH_API_URL ?? "http://localhost:8000").replace(/\/$/, "");
  let target = base;
  try {
    target = new URL(base).host;
  } catch {
    return Response.json({ status: "degraded", api: "invalid_url", target: base }, { status: 503 });
  }
  try {
    const r = await fetch(`${base}/health`, { cache: "no-store", signal: AbortSignal.timeout(3000) });
    return Response.json({ status: r.ok ? "ok" : "degraded", api: r.status, target }, { status: r.ok ? 200 : 503 });
  } catch (err) {
    return Response.json({ status: "degraded", api: "unreachable", target, error: errorCode(err) }, { status: 503 });
  }
}
