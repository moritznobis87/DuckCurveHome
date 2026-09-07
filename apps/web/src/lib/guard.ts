import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { SESSION_COOKIE, authRequired, verifySession } from "@/lib/session";

/**
 * Seiten, die Gästen verschlossen bleiben. Serverseitig, damit sie gar nicht erst ausgeliefert werden -
 * die Daten dahinter sperrt zwar auch der Proxy, aber eine Seite, die nur Fehlermeldungen zeigt, ist
 * keine gute Antwort auf „das darfst du nicht".
 */
export async function requireOwner(): Promise<void> {
  if (!authRequired()) return;
  const store = await cookies();
  const session = verifySession(store.get(SESSION_COOKIE)?.value);
  if (session?.role !== "owner") redirect("/");
}
