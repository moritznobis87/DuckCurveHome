import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * Kiosk-Session: ein signiertes, langlebiges HttpOnly-Cookie. Gepaart wird einmalig über /pair?token=…
 * mit dem Pairing-Token aus DCH_KIOSK_TOKEN. Ohne DCH_SESSION_SECRET ist die Anmeldung deaktiviert
 * (nur Entwicklung/Demo).
 */
export const SESSION_COOKIE = "dch_session";
const MAX_AGE_S = 180 * 24 * 3600;

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

export function issueSession(name: string): string | null {
  const secret = sessionSecret();
  if (!secret) return null;
  const exp = Math.floor(Date.now() / 1000) + MAX_AGE_S;
  const payload = Buffer.from(JSON.stringify({ n: name, exp }), "utf8").toString("base64url");
  return `${payload}.${sign(payload, secret)}`;
}

export function verifySession(cookie: string | undefined): { name: string } | null {
  const secret = sessionSecret();
  if (!secret || !cookie) return null;
  const [payload, sig] = cookie.split(".");
  if (!payload || !sig) return null;
  const expected = sign(payload, secret);
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  try {
    const data = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as { n: string; exp: number };
    if (data.exp < Date.now() / 1000) return null;
    return { name: data.n };
  } catch {
    return null;
  }
}

export function pairingTokenValid(token: string | null): boolean {
  const expected = process.env.DCH_KIOSK_TOKEN ?? "";
  if (!expected || !token) return false;
  const a = Buffer.from(token);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

export const cookieOptions = {
  httpOnly: true,
  sameSite: "lax" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
  maxAge: MAX_AGE_S,
};
