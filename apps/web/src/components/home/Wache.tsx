"use client";

import type { LiveState } from "@/lib/api/models";
import { Icon } from "@/components/ui/Icon";

/**
 * Was gerade schweigt, als Zeile, die man nicht übersehen kann.
 *
 * **Warum das hier oben steht.** Am 23.10.2026 wies der MQTT-Broker die Brücke ab. Zwei Tage lang
 * zeigte diese Seite vier satte Puffertemperaturen von vorgestern, und der fehlende Ladezustand
 * war ein Strich unter einem bunten Tank. Der Dienst wusste es die ganze Zeit. Er sagte es nur
 * niemandem.
 *
 * **Der Satz nennt die Folge, nicht nur den Zustand.** „Die Puffertemperaturen seit 2 Tagen
 * still" ist eine Beobachtung; erst „ohne sie gibt es keinen Ladezustand" sagt, warum es einen
 * stören soll. Der ganze Satz kommt aus dem Dienst (`hems_core.watch`), weil er auch als
 * Mitteilung auf einem Telefon landet, wo niemand etwas zusammensetzen kann.
 */
export type Befund = NonNullable<LiveState["system"]["watch"]>[number];

/** Der schwerste Befund. Der Dienst sortiert: Alarm vor Warnung, bei gleicher Schwere der ältere. */
export function schwerster(befunde: Befund[] | undefined): Befund | null {
  return befunde?.[0] ?? null;
}

export function Wache({ befunde }: { befunde: Befund[] }) {
  if (!befunde.length) return null;
  return (
    <div className="home-wache" role="status">
      {befunde.slice(0, 2).map((b) => (
        <span key={b.name} className="home-wache-zeile" data-schwere={b.severity}>
          <Icon name="alert" size={16} color="currentColor" />
          <span>{b.text_de}</span>
        </span>
      ))}
    </div>
  );
}
