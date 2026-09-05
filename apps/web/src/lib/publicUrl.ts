/** Ohne Node-Abhängigkeiten, damit auch die Middleware (Edge-Runtime) es nutzen kann. */
/**
 * Öffentliche Adresse der Anfrage hinter einem Reverse-Proxy (Railway): `req.url` zeigt dort auf die interne
 * Bind-Adresse (z. B. 0.0.0.0:8080). Für Weiterleitungen deshalb X-Forwarded-Host/-Proto bzw. Host verwenden.
 */
export function publicUrl(req: { url: string; headers: Headers }, path: string): URL {
  const host = req.headers.get("x-forwarded-host") ?? req.headers.get("host");
  const proto = req.headers.get("x-forwarded-proto") ?? "https";
  if (host && !host.startsWith("0.0.0.0") && !host.startsWith("[::]")) {
    return new URL(path, `${proto.split(",")[0]!.trim()}://${host.split(",")[0]!.trim()}`);
  }
  return new URL(path, req.url);
}
