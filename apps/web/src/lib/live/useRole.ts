"use client";

import { useEffect, useState } from "react";

export type Role = "owner" | "guest";

/** Rolle der Sitzung. Bis die Antwort da ist, gilt „guest": lieber kurz zu wenig anzeigen als einem
 *  Gast einen Knopf hinzustellen, der beim Antippen abgewiesen wird. */
export function useRole(): Role {
  const [role, setRole] = useState<Role>("guest");
  useEffect(() => {
    let cancelled = false;
    void fetch("/api/session", { cache: "no-store" })
      .then((r) => (r.ok ? r.json() : { role: "guest" }))
      .then((d: { role?: string }) => {
        if (!cancelled) setRole(d.role === "owner" ? "owner" : "guest");
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
  }, []);
  return role;
}
