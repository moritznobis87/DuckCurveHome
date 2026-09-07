import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { guestTtlSeconds, issueSession, roleForToken, verifySession } from "./session";

const SECRET = "x".repeat(48);

beforeEach(() => {
  process.env.DCH_SESSION_SECRET = SECRET;
  process.env.DCH_KIOSK_TOKEN = "kiosk-geheim";
  process.env.DCH_GUEST_TOKEN = "gast-geheim";
  delete process.env.DCH_GUEST_HOURS;
});
afterEach(() => vi.useRealTimers());

describe("Rollen", () => {
  it("erkennt beide Pairing-Token und weist alles andere ab", () => {
    expect(roleForToken("kiosk-geheim")).toBe("owner");
    expect(roleForToken("gast-geheim")).toBe("guest");
    expect(roleForToken("gast-gehei")).toBeNull(); // andere Länge
    expect(roleForToken("falsch-geheim")).toBeNull();
    expect(roleForToken(null)).toBeNull();
  });

  it("führt die Rolle im signierten Cookie mit", () => {
    expect(verifySession(issueSession("gast", "guest") ?? undefined)?.role).toBe("guest");
    expect(verifySession(issueSession("iPad", "owner") ?? undefined)?.role).toBe("owner");
  });

  it("behandelt Sitzungen ohne Rolle als Hausherr", () => {
    // Sie konnten nur mit dem Kiosk-Token entstehen, also vor Einführung der Rollen.
    const alt = issueSession("iPad") ?? "";
    expect(verifySession(alt)?.role).toBe("owner");
  });

  it("erkennt eine gefälschte Rolle nicht an", () => {
    const cookie = issueSession("gast", "guest") ?? "";
    const [payload = "", sig = ""] = cookie.split(".");
    const data = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as { r: string };
    data.r = "owner";
    const forged = `${Buffer.from(JSON.stringify(data), "utf8").toString("base64url")}.${sig}`;
    expect(verifySession(forged)).toBeNull();
  });
});

describe("Gültigkeitsdauer für Gäste", () => {
  it("nimmt die Vorgabe, den Wunsch aus dem Link und deckelt beides", () => {
    expect(guestTtlSeconds(null)).toBe(24 * 3600);
    expect(guestTtlSeconds(8)).toBe(8 * 3600);
    expect(guestTtlSeconds(0)).toBe(24 * 3600);
    expect(guestTtlSeconds(-5)).toBe(24 * 3600);
    expect(guestTtlSeconds(10_000)).toBe(720 * 3600); // höchstens 30 Tage
    process.env.DCH_GUEST_HOURS = "4";
    expect(guestTtlSeconds(null)).toBe(4 * 3600);
  });

  it("läuft nach Ablauf wirklich ab", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-09-07T12:00:00Z"));
    const cookie = issueSession("gast", "guest", 2 * 3600) ?? "";
    expect(verifySession(cookie)?.role).toBe("guest");
    vi.setSystemTime(new Date("2026-09-07T14:00:01Z"));
    expect(verifySession(cookie)).toBeNull();
  });
});
