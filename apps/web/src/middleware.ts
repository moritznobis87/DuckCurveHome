import { NextResponse, type NextRequest } from "next/server";
import { anmeldungNoetig } from "@/lib/anmeldungAktiv";
import { publicUrl } from "@/lib/publicUrl";

// Der Service Worker gehoert dazu: Seine Registrierung scheitert hart, wenn die Antwort eine
// Umleitung ist ("The script resource is behind a redirect"), und er enthaelt nichts ueber das
// Haus - nur den Umgang mit Mitteilungen.
const OEFFENTLICHE_DATEIEN = new Set(["/manifest.webmanifest", "/apple-touch-icon.png", "/favicon.svg", "/sw.js"]);

// Was ohne Anmeldung erreichbar bleibt: die Anmeldeseite selbst samt dem Weg hinter dem
// Einladungslink (`/anmeldung/einrichten`). Ihre Server Actions laufen unter derselben Adresse,
// also muss der ganze Zweig offen sein.
const OFFEN = ["/anmeldung", "/api/health", "/brand"];

/**
 * Zugangsschutz: Ohne Cookie fuehrt jeder Weg auf die Anmeldeseite.
 *
 * Geprueft wird hier nur die **Praesenz** des Cookies - die Edge-Laufzeit kann nicht rechnen und
 * soll es nicht. Was das Token bedeutet, loest der Dienst auf (lib/zugang.ts, BFF-Route).
 *
 * Seit dem 23.11.2026 gibt es nur noch ein Cookie. Das zweite war die Gerätepaarung, und mit ihr
 * ist der stehende URL-Token verschwunden, der Vollzugriff vergab und sich nicht einzeln
 * widerrufen liess.
 */
export function middleware(req: NextRequest): NextResponse {
  if (!anmeldungNoetig()) return NextResponse.next();
  const { pathname } = req.nextUrl;
  if (OFFEN.some((p) => pathname === p || pathname.startsWith(`${p}/`))) {
    return NextResponse.next();
  }
  // Manifest und App-Icons holt der Browser ohne Cookie ab; sie verraten nichts über das Haus.
  if (OEFFENTLICHE_DATEIEN.has(pathname)) return NextResponse.next();
  if (!req.cookies.get("dch_person")?.value) {
    if (pathname.startsWith("/api/")) {
      return NextResponse.json({ error: { code: "unauthorized", message: "Nicht angemeldet.", details: null } }, { status: 401 });
    }
    return NextResponse.redirect(publicUrl(req, "/anmeldung"));
  }
  return NextResponse.next();
}

export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"] };
