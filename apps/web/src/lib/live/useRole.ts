"use client";

import { useEffect, useState } from "react";

export type Role = "owner" | "guest";

/** Was die Oberfläche über die Sitzung wissen muss, um keine toten Knöpfe zu zeigen. */
export interface Sitzung {
  /** Darf im Haus stellen: Hausherr und Bewohner. Das alte Feld `role` von `/api/session`. */
  role: Role;
  /** Hat Vollzugriff: sieht die Akten und den Bereich System. */
  hausherr: boolean;
  /** Ist als Person angemeldet und hat damit einen eigenen Zugang (`/konto`). */
  person: boolean;
}

/**
 * Die Sitzung. Bis die Antwort da ist, gilt der Hausherr: die Schaltkacheln sehen für alle gleich
 * aus, und ein Gast, der in der ersten Sekunde tippt, bekommt vom Proxy eine saubere Absage.
 * Umgekehrt wäre es ärgerlicher - der Hausherr sähe kurz „nur Ansicht" an seinen eigenen
 * Schaltern.
 *
 * **Stellen dürfen und Vollzugriff haben sind zweierlei.** Ein Bewohner darf im Haus stellen, die
 * Akten und das System sieht er nicht. Bis zum 24.11.2026 gab es hier nur `role`, und die Leiste
 * zeigte einem Bewohner das Zahnrad und die Seiten des Hausherrn, die ihn dann zurückwarfen.
 */
export function useSitzung(): Sitzung {
  const [sitzung, setSitzung] = useState<Sitzung>({ role: "owner", hausherr: true, person: false });
  useEffect(() => {
    let cancelled = false;
    const ask = () => {
      void fetch("/api/session", { cache: "no-store" })
        .then((r) => (r.ok ? r.json() : { role: "guest" }))
        .then((d: { role?: string; rolle?: string; art?: string | null }) => {
          if (cancelled) return;
          setSitzung({
            role: d.role === "owner" ? "owner" : "guest",
            // Ohne Anmeldung (Demo) gibt es keinen Ausweis und keine Rolle; dann gilt wie bisher,
            // was `role` sagt.
            hausherr: d.art == null ? d.role === "owner" : d.rolle === "hausherr",
            person: d.art === "person",
          });
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
  return sitzung;
}

/** Ob diese Sitzung im Haus stellen darf. Für die Schalter; die Leiste fragt `useSitzung`. */
export function useRole(): Role {
  return useSitzung().role;
}
