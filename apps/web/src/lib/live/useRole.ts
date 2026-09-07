"use client";

import { useEffect, useState } from "react";

export type Role = "owner" | "guest";

/** Rolle der Sitzung. Bis die Antwort da ist, gilt „owner": die Schaltkacheln sehen für alle gleich aus,
 *  und ein Gast, der in der ersten Sekunde tippt, bekommt vom Proxy eine saubere Absage. Umgekehrt wäre
 *  es ärgerlicher - der Hausherr sähe kurz „nur Ansicht" an seinen eigenen Schaltern. */
export function useRole(): Role {
  const [role, setRole] = useState<Role>("owner");
  useEffect(() => {
    let cancelled = false;
    const ask = () => {
      void fetch("/api/session", { cache: "no-store" })
        .then((r) => (r.ok ? r.json() : { role: "guest" }))
        .then((d: { role?: string }) => {
          if (!cancelled) setRole(d.role === "owner" ? "owner" : "guest");
        })
        .catch(() => undefined);
    };
    ask();
    // Alle zwei Minuten erneut: hält zugleich die Anwesenheitsliste aktuell, denn der Live-Zustand
    // läuft über einen einzigen langen SSE-Strom und erzeugt sonst keine weiteren Anfragen.
    const timer = setInterval(ask, 120_000);
    return () => {
      cancelled = true;
      clearInterval(timer);
    };
  }, []);
  return role;
}
