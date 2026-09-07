import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * Kiosk-Session: ein signiertes, langlebiges HttpOnly-Cookie. Gepaart wird einmalig über /pair?token=…
 * mit dem Pairing-Token aus DCH_KIOSK_TOKEN. Ohne DCH_SESSION_SECRET ist die Anmeldung deaktiviert
 * (nur Entwicklung/Demo).
 *
 * Zwei Rollen: `owner` darf alles, `guest` nur zusehen. Gäste werden über DCH_GUEST_TOKEN gepaart.
 * Durchgesetzt wird das im BFF-Proxy, nicht in der Anzeige - eine ausgeblendete Kachel hält niemanden
 * auf, der die Adresse kennt.
 */
export type Role = "owner" | "guest";
export const SESSION_COOKIE = "dch_session";
const MAX_AGE_S = 180 * 24 * 3600; // Wandanzeige: einmal paaren, dann monatelang Ruhe
const GUEST_MAX_HOURS = 720; // 30 Tage - darüber hinaus ist es kein Besuch mehr

/** Gültigkeitsdauer einer Gast-Sitzung in Sekunden; `hours` aus dem Pairing-Link übersteuert die Vorgabe. */
export function guestTtlSeconds(hours?: number | null): number {
  const fallback = Number(process.env.DCH_GUEST_HOURS ?? 24);
  const wanted = hours && Number.isFinite(hours) && hours > 0 ? hours : fallback;
  const clamped = Math.min(Math.max(wanted > 0 ? wanted : 24, 1), GUEST_MAX_HOURS);
  return Math.round(clamped * 3600);
}

export function sessionSecret(): string | null {
  const s = process.env.DCH_SESSION_SECRET ?? "";
  return s.length >= 32 ? s : null;
}

export function authRequired(): boolean {
  return sessionSecret() !== null;
}

function sign(payload: string, secret: string): string {
  return createHmac("sha256", secret).update(payload).digest("base64url");
}

export function issueSession(name: string, role: Role = "owner", ttlSeconds?: number): string | null {
  const secret = sessionSecret();
  if (!secret) return null;
  const exp = Math.floor(Date.now() / 1000) + (ttlSeconds ?? MAX_AGE_S);
  const payload = Buffer.from(JSON.stringify({ n: name, r: role, exp }), "utf8").toString("base64url");
  return `${payload}.${sign(payload, secret)}`;
}

export function verifySession(cookie: string | undefined): { name: string; role: Role } | null {
  const secret = sessionSecret();
  if (!secret || !cookie) return null;
  const [payload, sig] = cookie.split(".");
  if (!payload || !sig) return null;
  const expected = sign(payload, secret);
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  try {
    const data = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as { n: string; r?: Role; exp: number };
    if (data.exp < Date.now() / 1000) return null;
    // Sitzungen aus der Zeit vor den Rollen gehören dem Hausherrn - sie entstanden nur mit dem Kiosk-Token.
    return { name: data.n, role: data.r === "guest" ? "guest" : "owner" };
  } catch {
    return null;
  }
}

function tokenMatches(token: string | null, expected: string): boolean {
  if (!expected || !token) return false;
  const a = Buffer.from(token);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

export function pairingTokenValid(token: string | null): boolean {
  return tokenMatches(token, process.env.DCH_KIOSK_TOKEN ?? "");
}

/** Welche Rolle der Pairing-Token vergibt - null, wenn er zu keinem der beiden passt. */
export function roleForToken(token: string | null): Role | null {
  if (tokenMatches(token, process.env.DCH_KIOSK_TOKEN ?? "")) return "owner";
  if (tokenMatches(token, process.env.DCH_GUEST_TOKEN ?? "")) return "guest";
  return null;
}

export const cookieOptions = {
  httpOnly: true,
  sameSite: "lax" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
  maxAge: MAX_AGE_S,
};
