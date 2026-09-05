import { NextResponse, type NextRequest } from "next/server";
import { SESSION_COOKIE, authRequired, cookieOptions, issueSession, pairingTokenValid, publicUrl } from "@/lib/session";

export const dynamic = "force-dynamic";

/** Kiosk-Pairing: /pair?token=<DCH_KIOSK_TOKEN>&name=iPad-Flur setzt das Session-Cookie und leitet zum Dashboard. */
export function GET(req: NextRequest): NextResponse {
  if (!authRequired()) return NextResponse.redirect(publicUrl(req, "/"));
  const token = req.nextUrl.searchParams.get("token");
  const name = req.nextUrl.searchParams.get("name") ?? "kiosk";
  if (!pairingTokenValid(token)) {
    return new NextResponse("Pairing-Token ungültig.", { status: 401, headers: { "content-type": "text/plain; charset=utf-8" } });
  }
  const session = issueSession(name.slice(0, 40));
  const res = NextResponse.redirect(publicUrl(req, "/"));
  if (session) res.cookies.set(SESSION_COOKIE, session, cookieOptions);
  return res;
}
