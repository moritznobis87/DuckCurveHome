import { NextResponse, type NextRequest } from "next/server";
import { anmeldungNoetig } from "@/lib/anmeldungAktiv";
import { publicUrl } from "@/lib/publicUrl";

// Der Service Worker gehoert dazu: Seine Registrierung scheitert hart, wenn die Antwort eine
// Umleitung ist ("The script resource is behind a redirect"), und er enthaelt nichts ueber das
// Haus - nur den Umgang mit Mitteilungen.
const OEFFENTLICHE_DATEIEN = new Set(["/manifest.webmanifest", "/apple-touch-icon.png", "/favicon.svg", "/sw.js"]);

// Was ohne Anmeldung erreichbar bleibt. `/anmeldung` ist die Anmeldeseite selbst samt dem Weg
// hinter dem Einladungslink (`/anmeldung/einrichten`); ihre Server Actions laufen unter derselben
// Adresse, also muss der ganze Zweig offen sein.
const OFFEN = ["/anmeldung", "/pair", "/api/health", "/locked", "/brand"];

/**
 * Zugangsschutz: Ohne Cookie fuehrt jeder Weg auf die Anmeldeseite.
 *
 * Zwei Cookies gelten (ADR-0002): `dch_person` fuer eine angemeldete Person, `dch_session` fuer
 * ein gepaartes Geraet oder einen Gastlink. Geprueft wird hier nur die **Praesenz** - die Edge-
 * Laufzeit kann nicht rechnen und soll es nicht: die kryptografische Pruefung des Geraetecookies
 * und das Aufloesen des Sitzungstokens passieren in der Node-Laufzeit (lib/zugang.ts, BFF-Route).
 */
export function middleware(req: NextRequest): NextResponse {
  if (!anmeldungNoetig()) return NextResponse.next();
  const { pathname } = req.nextUrl;
  if (OFFEN.some((p) => pathname === p || pathname.startsWith(`${p}/`))) {
    return NextResponse.next();
  }
  // Manifest und App-Icons holt der Browser ohne Cookie ab; sie verraten nichts über das Haus.
  if (OEFFENTLICHE_DATEIEN.has(pathname)) return NextResponse.next();
  if (!req.cookies.get("dch_person")?.value && !req.cookies.get("dch_session")?.value) {
    if (pathname.startsWith("/api/")) {
      return NextResponse.json({ error: { code: "unauthorized", message: "Nicht angemeldet.", details: null } }, { status: 401 });
    }
    return NextResponse.redirect(publicUrl(req, "/anmeldung"));
  }
  return NextResponse.next();
}

export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"] };
