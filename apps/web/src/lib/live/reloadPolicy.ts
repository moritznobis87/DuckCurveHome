/** Kiosk-Hygiene: einmal täglich um 03:30 Ortszeit neu laden und bei Backend-Versionswechsel. */
export function startReloadPolicy(getVersion: () => string | null): () => void {
  const seen = { version: null as string | null };
  const timer = setInterval(() => {
    const now = new Date();
    const berlin = new Intl.DateTimeFormat("de-DE", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Berlin" }).format(now);
    if (berlin === "03:30" && now.getSeconds() < 30) window.location.reload();
    const v = getVersion();
    if (v && seen.version && v !== seen.version) window.location.reload();
    if (v) seen.version = v;
  }, 20_000);
  return () => clearInterval(timer);
}
