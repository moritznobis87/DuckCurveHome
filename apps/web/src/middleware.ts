import { NextResponse, type NextRequest } from "next/server";
import { publicUrl } from "@/lib/session";

/**
 * Zugangsschutz für den Kiosk: Ohne gültiges Session-Cookie wird eine Hinweisseite gezeigt.
 * Die kryptografische Prüfung passiert in der BFF-Route (Node-Runtime); hier nur die Präsenz.
 */
export function middleware(req: NextRequest): NextResponse {
  const authRequired = (process.env.DCH_SESSION_SECRET ?? "").length >= 32;
  if (!authRequired) return NextResponse.next();
  const { pathname } = req.nextUrl;
  if (pathname.startsWith("/pair") || pathname.startsWith("/api/health") || pathname.startsWith("/locked") || pathname.startsWith("/brand")) {
    return NextResponse.next();
  }
  if (!req.cookies.get("dch_session")?.value) {
    if (pathname.startsWith("/api/")) {
      return NextResponse.json({ error: { code: "unauthorized", message: "Nicht angemeldet.", details: null } }, { status: 401 });
    }
    return NextResponse.redirect(publicUrl(req, "/locked"));
  }
  return NextResponse.next();
}

export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"] };
