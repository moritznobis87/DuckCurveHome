import type { NextRequest } from "next/server";
import { touch } from "@/lib/presence";
import { SESSION_COOKIE, authRequired, verifySession } from "@/lib/session";

export const dynamic = "force-dynamic";

/**
 * Rolle der laufenden Sitzung. Die Oberfläche blendet danach aus, was ein Gast ohnehin nicht darf -
 * verboten wird es im Proxy, hier geht es nur darum, keine toten Knöpfe zu zeigen.
 *
 * Nebenbei hält der regelmäßige Aufruf die Anwesenheitsliste aktuell.
 */
export function GET(req: NextRequest): Response {
  const s = verifySession(req.cookies.get(SESSION_COOKIE)?.value);
  touch(s, req.headers.get("user-agent"));
  const role = !authRequired() ? "owner" : (s?.role ?? "guest");
  return Response.json({ role, name: s?.name ?? null }, { headers: { "cache-control": "no-store" } });
}
