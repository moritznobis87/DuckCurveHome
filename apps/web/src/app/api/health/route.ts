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
  // Beide Kennungen an einer Stelle: welcher Stand im Web läuft und welcher in der API. Ohne das
  // ist „ist mein Fehler schon behoben?" nur über den Deployment-Verlauf zu beantworten, und die
  // beiden Dienste werden getrennt ausgerollt - sie können auseinanderlaufen.
  const web = process.env.RAILWAY_GIT_COMMIT_SHA?.slice(0, 7) ?? process.env.NEXT_PUBLIC_BUILD_ID ?? "dev";
  try {
    const r = await fetch(`${base}/health`, { cache: "no-store", signal: AbortSignal.timeout(3000) });
    const body: unknown = r.ok ? await r.json().catch(() => null) : null;
    const payload = (typeof body === "object" && body !== null ? body : {}) as { commit?: unknown; energy_rebuild?: unknown };
    const str = (v: unknown) => (typeof v === "string" ? v : "unbekannt");
    return Response.json(
      { status: r.ok ? "ok" : "degraded", api: r.status, web, api_commit: str(payload.commit), energy_rebuild: str(payload.energy_rebuild), target },
      { status: r.ok ? 200 : 503 },
    );
  } catch (err) {
    return Response.json({ status: "degraded", api: "unreachable", web, target, error: errorCode(err) }, { status: 503 });
  }
}
