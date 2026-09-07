import { NextResponse, type NextRequest } from "next/server";
import { SESSION_COOKIE, authRequired, cookieOptions, guestTtlSeconds, issueSession, roleForToken } from "@/lib/session";
import { publicUrl } from "@/lib/publicUrl";

export const dynamic = "force-dynamic";

/**
 * Pairing über einen Token in der Adresse.
 *
 *   /pair?token=<DCH_KIOSK_TOKEN>&name=iPad-Flur    → Hausherr, Sitzung hält ein halbes Jahr
 *   /pair?token=<DCH_GUEST_TOKEN>&hours=8           → Gast, nur lesen, Sitzung läuft ab
 *
 * Die Ablaufzeit steht signiert im Cookie und wird bei jeder Anfrage geprüft. Sie begrenzt die Sitzung,
 * nicht den Link: wer ihn kennt, kann sich erneut paaren. Um das zu unterbinden, DCH_GUEST_TOKEN ändern.
 */
export function GET(req: NextRequest): NextResponse {
  if (!authRequired()) return NextResponse.redirect(publicUrl(req, "/"));
  const token = req.nextUrl.searchParams.get("token");
  const role = roleForToken(token);
  if (role === null) {
    return new NextResponse("Pairing-Token ungültig.", { status: 401, headers: { "content-type": "text/plain; charset=utf-8" } });
  }
  const name = req.nextUrl.searchParams.get("name") ?? (role === "guest" ? "gast" : "kiosk");
  const hours = Number(req.nextUrl.searchParams.get("hours"));
  const ttl = role === "guest" ? guestTtlSeconds(Number.isFinite(hours) ? hours : null) : undefined;
  const session = issueSession(name.slice(0, 40), role, ttl);
  const res = NextResponse.redirect(publicUrl(req, "/"));
  if (session) res.cookies.set(SESSION_COOKIE, session, { ...cookieOptions, ...(ttl ? { maxAge: ttl } : {}) });
  return res;
}
