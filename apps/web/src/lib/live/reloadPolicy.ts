/** Wann das Dashboard sich selbst neu lädt.
 *
 * Es läuft als Wandanzeige über Tage hinweg im selben Tab. Ohne diese Regeln bliebe nach einem Deploy
 * für immer die alte Fassung stehen – gemerkt hat man das erst, wenn eine Änderung „nicht ankommt“.
 * Drei Anlässe: eine neue API-Version, ein neuer Web-Build und ein täglicher Neustart um 03:30.
 */
export function startReloadPolicy(getVersion: () => string | null): () => void {
  const seen = { version: null as string | null };
  const own = process.env.NEXT_PUBLIC_BUILD_ID ?? "dev";
  let checking = false;

  const buildChanged = async (): Promise<boolean> => {
    if (own === "dev") return false; // lokal entwickelt der Hot-Reload, kein Neuladen erzwingen
    try {
      const r = await fetch("/api/build", { cache: "no-store", signal: AbortSignal.timeout(5000) });
      if (!r.ok) return false;
      const data: unknown = await r.json();
      const id = typeof data === "object" && data !== null ? (data as { id?: unknown }).id : null;
      return typeof id === "string" && id !== "dev" && id !== own;
    } catch {
      return false; // Netz weg: das ist kein Grund, die laufende Anzeige wegzuwerfen
    }
  };

  const timer = setInterval(() => {
    const now = new Date();
    const berlin = new Intl.DateTimeFormat("de-DE", { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Berlin" }).format(now);
    if (berlin === "03:30" && now.getSeconds() < 30) window.location.reload();
    const v = getVersion();
    if (v && seen.version && v !== seen.version) window.location.reload();
    if (v) seen.version = v;
    if (!checking) {
      checking = true;
      void buildChanged()
        .then((changed) => {
          if (changed) window.location.reload();
        })
        .finally(() => {
          checking = false;
        });
    }
  }, 20_000);
  return () => clearInterval(timer);
}
