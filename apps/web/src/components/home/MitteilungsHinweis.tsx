"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { api } from "@/lib/api/client";
import { abonnement, anmeldung, pushLage } from "@/lib/push/lage";

/**
 * Auf dem Telefon: sagen, dass dieses Gerät noch keine Mitteilungen bekommt.
 *
 * Anlass (Nutzer am 12.11.2026): „Ich bekomme gar keine Push-Nachrichten auf mein Handy. Da war
 * doch ein Morning Briefing geplant." Der Brief war eingeschaltet, aber jedes Gerät muss sich einzeln
 * anmelden, und die Stelle dafür lag unter Technik. Wer das nicht weiß, wartet auf einen Brief,
 * der an niemanden geht.
 *
 * Der Hinweis steht nur beim Hausherrn (die Seite dahinter ist seine), nur solange das Gerät
 * nicht angemeldet ist, und lässt sich wegtippen. Wer ihn wegtippt, will ihn nicht wiedersehen;
 * gemerkt wird das im Gerät. Hat jemand Mitteilungen abgelehnt, steht nichts da: das war eine
 * Entscheidung.
 *
 * Ist das Gerät angemeldet, meldet es sich hier still noch einmal beim Dienst. Der Browser weiß
 * nicht, ob der Dienst sein Abonnement noch kennt; nach einer neu aufgesetzten Datenbank hieße
 * es sonst auf dem Telefon „angemeldet", und es käme nie etwas an.
 */
const MERKER = "dch-mitteilungen-hinweis";

type Art = "aus" | "ios-browser";

export function MitteilungsHinweis() {
  const [art, setArt] = useState<Art | null>(null);

  useEffect(() => {
    let weg = false;
    void (async () => {
      try {
        const sitzung = (await fetch("/api/session", { cache: "no-store" }).then((r) => (r.ok ? r.json() : null))) as { role?: string } | null;
        if (sitzung?.role !== "owner") return;
        const lage = await pushLage();
        if (lage === "an") {
          const abo = await abonnement();
          if (abo) await api.pushSubscribe(anmeldung(abo));
          return;
        }
        if (lage !== "aus" && lage !== "ios-browser") return;
        let gemerkt: string | null = null;
        try {
          gemerkt = window.localStorage.getItem(MERKER);
        } catch {
          // Ohne Speicher steht der Hinweis eben jedes Mal da.
        }
        if (!weg && gemerkt !== "weg") setArt(lage);
      } catch {
        // Kein Hinweis ist besser als ein falscher.
      }
    })();
    return () => {
      weg = true;
    };
  }, []);

  if (art === null) return null;

  const schliessen = () => {
    setArt(null);
    try {
      window.localStorage.setItem(MERKER, "weg");
    } catch {
      // siehe oben
    }
  };

  return (
    <div className="mitteil-hinweis" role="note">
      <span className="mitteil-hinweis-text">
        {art === "aus"
          ? "Dieses Telefon bekommt noch keine Mitteilungen, auch nicht das Morning Briefing."
          : "Für Mitteilungen und das Morning Briefing muss Duck Curve Home auf den Home-Bildschirm: Teilen, „Zum Home-Bildschirm“, von dort öffnen."}
      </span>
      <span className="mitteil-hinweis-knoepfe">
        <Link href="/system/mitteilungen" className="mitteil-hinweis-los">{art === "aus" ? "Einschalten" : "So geht es"}</Link>
        <button type="button" className="mitteil-hinweis-zu" onClick={schliessen}>Nicht jetzt</button>
      </span>
    </div>
  );
}
