import type { Role } from "@/lib/session";

/**
 * Wer das Dashboard gerade benutzt.
 *
 * Bewusst nur im Arbeitsspeicher des Web-Dienstes und bewusst schlicht: Es geht um die Frage „wer schaut
 * gerade zu?", nicht um ein Zugriffsprotokoll. Nach einem Neustart ist die Liste leer, und liefen mehrere
 * Instanzen des Web-Dienstes, sähe jede nur ihre eigenen Besucher.
 */
export type Presence = { name: string; role: Role; lastSeen: number; agent: string };

const seen = new Map<string, Presence>();
const MAX_ENTRIES = 200;

/** Kurzform des User-Agent: reicht, um Geräte auseinanderzuhalten, ohne ihn ganz zu speichern. */
function shortAgent(ua: string): string {
  if (/iPad/i.test(ua)) return "iPad";
  if (/iPhone/i.test(ua)) return "iPhone";
  if (/Android/i.test(ua)) return "Android";
  if (/Macintosh/i.test(ua)) return "Mac";
  if (/Windows/i.test(ua)) return "Windows";
  if (/Linux/i.test(ua)) return "Linux";
  return "unbekannt";
}

export function touch(session: { name: string; role: Role } | null, userAgent: string | null): void {
  if (!session) return;
  const agent = shortAgent(userAgent ?? "");
  const key = `${session.role}:${session.name}:${agent}`;
  seen.set(key, { name: session.name, role: session.role, lastSeen: Date.now(), agent });
  if (seen.size > MAX_ENTRIES) {
    // Älteste zuerst entfernen, damit die Liste nicht unbegrenzt wächst
    const oldest = [...seen.entries()].sort((a, b) => a[1].lastSeen - b[1].lastSeen)[0];
    if (oldest) seen.delete(oldest[0]);
  }
}

export function active(withinSeconds = 300): Presence[] {
  const cutoff = Date.now() - withinSeconds * 1000;
  return [...seen.values()].filter((p) => p.lastSeen >= cutoff).sort((a, b) => b.lastSeen - a.lastSeen);
}
