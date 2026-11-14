"use client";

import Link from "next/link";
import { useEffect, useRef } from "react";
import { Icon } from "@/components/ui/Icon";

/**
 * Was ein Tipp auf die Wärmepumpe der Startseite öffnet.
 *
 * **Warum eine Auswahl und kein Sprung** (Nutzerwunsch 14.11.2026). Bis dahin führte der Knoten
 * auf die Seite „Wärme". Wer auf die Wärmepumpe tippt, will aber eines von mehreren Dingen
 * wissen, und welches, weiß nur er: wie sie gerade arbeitet, was sie kostet, wann sie laufen
 * soll, wie viel sie verbraucht hat. Vier Ziele, je ein Zeichen und ein Satz.
 *
 * **Nur die Wärmepumpe hat das.** Die anderen Knoten haben ein Ziel und springen weiter direkt.
 *
 * Am Telefon kommt die Auswahl von unten, dort, wo der Daumen ist; auf der Wandanzeige steht sie
 * in der Mitte. Schließen: daneben tippen, „Schließen" oder Escape. Ohne JavaScript bleibt der
 * Knoten ein gewöhnlicher Verweis auf die Technikseite.
 */
export const ZIELE = [
  { href: "/waerme/waermepumpe", zeichen: "gear", titel: "Technik", satz: "Wie sie gerade arbeitet: Außengerät, Innengerät, alle Messwerte" },
  { href: "/waerme/nachbetrachtung", zeichen: "euro", titel: "Kosten", satz: "Was die Wärme gekostet hat, Tag für Tag" },
  { href: "/waerme/fahrplan", zeichen: "calendar", titel: "Fahrplan", satz: "Wann sie laufen soll und warum" },
  { href: "/waerme", zeichen: "chart", titel: "Verbrauch", satz: "Wärme und Strom über Tage und Wochen" },
] as const;

export function WpMenue({ offen, onZu, zeile }: { offen: boolean; onZu: () => void; zeile: string }) {
  const erstes = useRef<HTMLAnchorElement | null>(null);

  useEffect(() => {
    if (!offen) return;
    erstes.current?.focus();
    const taste = (e: KeyboardEvent) => {
      if (e.key === "Escape") onZu();
    };
    document.addEventListener("keydown", taste);
    return () => document.removeEventListener("keydown", taste);
  }, [offen, onZu]);

  if (!offen) return null;
  return (
    <div className="wp-menue-grund" onClick={onZu}>
      <div className="wp-menue" role="dialog" aria-modal="true" aria-label="Wärmepumpe" onClick={(e) => e.stopPropagation()}>
        <div className="wp-menue-kopf">
          <span className="wp-menue-titel">Wärmepumpe</span>
          <span className="wp-menue-zeile">{zeile}</span>
        </div>
        <div className="wp-menue-ziele">
          {ZIELE.map((z, i) => (
            <Link key={z.href} href={z.href} className="wp-menue-ziel" ref={i === 0 ? erstes : undefined} onClick={onZu}>
              <span className="wp-menue-zeichen"><Icon name={z.zeichen} size={24} color="var(--amber)" /></span>
              <span className="wp-menue-text">
                <span className="wp-menue-ziel-titel">{z.titel}</span>
                <span className="wp-menue-ziel-satz">{z.satz}</span>
              </span>
            </Link>
          ))}
        </div>
        <button type="button" className="wp-menue-zu" onClick={onZu}>Schließen</button>
      </div>
    </div>
  );
}
